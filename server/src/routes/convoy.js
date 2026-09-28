const express = require("express");
const { z } = require("zod");
const { prisma } = require("../config/db");
const { requireAuth } = require("../middleware/auth");
const { getRouteOptions } = require("../services/directions");
const { rankConvoy } = require("../utils/geo");

const router = express.Router();
router.use(requireAuth);

function makeJoinCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no 0/O/1/I
  let code = "";
  for (let i = 0; i < 6; i++) code += alphabet[Math.floor(Math.random() * alphabet.length)];
  return code;
}

/** Builds the ordered [start, ...waypoints, destination] point list that
 *  getRouteOptions() routes through, from a convoy row plus its waypoints. */
function routePoints(convoy, waypoints) {
  return [
    { lat: convoy.startLat, lng: convoy.startLng },
    ...waypoints.map((w) => ({ lat: w.lat, lng: w.lng })),
    { lat: convoy.destLat, lng: convoy.destLng },
  ];
}

const waypointSchema = z.object({
  label: z.string().min(1),
  lat: z.number(),
  lng: z.number(),
});

/** POST /convoys — host creates a convoy (planning stage, route not yet locked). */
const createSchema = z.object({
  name: z.string().min(1).max(80),
  startLabel: z.string().min(1),
  startLat: z.number(),
  startLng: z.number(),
  destLabel: z.string().min(1),
  destLat: z.number(),
  destLng: z.number(),
  // Intermediate destinations the route should pass through, in order,
  // between the start and the final destination. Optional — an empty or
  // omitted list is just a normal point-to-point trip.
  waypoints: z.array(waypointSchema).max(8).default([]),
  vehicleName: z.string().min(1),
  passengers: z.number().int().min(1).max(12).default(1),
});

router.post("/", async (req, res) => {
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const d = parsed.data;

  let code;
  do {
    code = makeJoinCode();
  } while (await prisma.convoy.findUnique({ where: { code } }));

  const convoy = await prisma.convoy.create({
    data: {
      code,
      name: d.name,
      hostId: req.userId,
      startLabel: d.startLabel,
      startLat: d.startLat,
      startLng: d.startLng,
      destLabel: d.destLabel,
      destLat: d.destLat,
      destLng: d.destLng,
      waypoints: {
        create: d.waypoints.map((w, i) => ({ ...w, order: i })),
      },
      members: {
        create: {
          userId: req.userId,
          role: "host",
          vehicleName: d.vehicleName,
          passengers: d.passengers,
        },
      },
    },
    include: { members: true, waypoints: { orderBy: { order: "asc" } } },
  });

  res.status(201).json(convoy);
});

/**
 * PUT /convoys/:code/waypoints — host replaces the full ordered waypoint
 * list before locking (planning stage only; waypoints are fixed once the
 * route is locked, same as the start/destination). Sending an empty array
 * removes all intermediate destinations, leaving a plain point-to-point trip.
 */
const waypointsUpdateSchema = z.object({ waypoints: z.array(waypointSchema).max(8) });

router.put("/:code/waypoints", async (req, res) => {
  const convoy = await requireHost(req, res);
  if (!convoy) return;
  if (convoy.routeLocked) {
    return res.status(409).json({ error: "Route is already locked — waypoints can't change now" });
  }

  const parsed = waypointsUpdateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const updated = await prisma.$transaction(async (tx) => {
    await tx.waypoint.deleteMany({ where: { convoyId: convoy.id } });
    if (parsed.data.waypoints.length) {
      await tx.waypoint.createMany({
        data: parsed.data.waypoints.map((w, i) => ({ ...w, convoyId: convoy.id, order: i })),
      });
    }
    return tx.waypoint.findMany({ where: { convoyId: convoy.id }, orderBy: { order: "asc" } });
  });

  res.json({ waypoints: updated });
});

/** GET /convoys/:code/route-options — fetch route alternatives for the host to choose from. */
router.get("/:code/route-options", async (req, res) => {
  const convoy = await requireHost(req, res);
  if (!convoy) return;

  const waypoints = await prisma.waypoint.findMany({
    where: { convoyId: convoy.id },
    orderBy: { order: "asc" },
  });

  try {
    const options = await getRouteOptions({ points: routePoints(convoy, waypoints) });
    res.json({ options });
  } catch (err) {
    res.status(err.status || 500).json({ error: err.message });
  }
});

/** POST /convoys/:code/lock — host confirms a route option; it becomes immutable for clients. */
const lockSchema = z.object({
  summary: z.string(),
  polyline: z.string(),
  distanceM: z.number(),
  durationS: z.number(),
  stops: z
    .array(
      z.object({
        label: z.string(),
        lat: z.number(),
        lng: z.number(),
        distanceAlongM: z.number(),
        kind: z.enum(["fuel", "food", "rest", "waypoint"]).default("waypoint"),
      })
    )
    .default([]),
});

router.post("/:code/lock", async (req, res) => {
  const convoy = await requireHost(req, res);
  if (!convoy) return;

  const parsed = lockSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const d = parsed.data;

  const updated = await prisma.$transaction(async (tx) => {
    await tx.stop.deleteMany({ where: { convoyId: convoy.id } });
    if (d.stops.length) {
      await tx.stop.createMany({
        data: d.stops.map((s, i) => ({ ...s, convoyId: convoy.id, order: i })),
      });
    }
    return tx.convoy.update({
      where: { id: convoy.id },
      data: {
        routeLocked: true,
        routePolyline: d.polyline,
        routeDistanceM: d.distanceM,
        routeDurationS: d.durationS,
        routeSummary: d.summary,
        status: "active",
        lockedAt: new Date(),
      },
      include: { stops: true, members: true, waypoints: { orderBy: { order: "asc" } } },
    });
  });

  const io = req.app.get("io");
  io.to(`convoy:${convoy.code}`).emit("route:locked", updated);

  res.json(updated);
});

/** POST /convoys/:code/end — host ends the convoy. */
router.post("/:code/end", async (req, res) => {
  const convoy = await requireHost(req, res);
  if (!convoy) return;

  await prisma.convoy.update({
    where: { id: convoy.id },
    data: { status: "ended" },
  });

  // Notify every connected client that the convoy is over.
  const io = req.app.get("io");
  io.to(`convoy:${convoy.code}`).emit("convoy:ended", { code: convoy.code });

  res.json({ ok: true });
});

/** POST /convoys/:code/reroute — host modifies route/destination while convoy is active. */
const rerouteSchema = z.object({
  destLabel: z.string().optional(),
  destLat: z.number().optional(),
  destLng: z.number().optional(),
  waypoints: z.array(waypointSchema).max(8).optional(),
});

router.post("/:code/reroute", async (req, res) => {
  const convoy = await requireHost(req, res);
  if (!convoy) return;

  const parsed = rerouteSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const d = parsed.data;

  const destLat = d.destLat ?? convoy.destLat;
  const destLng = d.destLng ?? convoy.destLng;
  const destLabel = d.destLabel ?? convoy.destLabel;

  let currentWaypoints = d.waypoints;
  if (!currentWaypoints) {
    currentWaypoints = await prisma.waypoint.findMany({
      where: { convoyId: convoy.id },
      orderBy: { order: "asc" },
    });
  }

  // Use the host's latest reported location as start if available, else convoy start
  const hostMember = await prisma.convoyMember.findFirst({
    where: { convoyId: convoy.id, userId: req.userId },
  });
  const startPoint = (hostMember && hostMember.lastLat != null && hostMember.lastLng != null)
    ? { lat: hostMember.lastLat, lng: hostMember.lastLng }
    : { lat: convoy.startLat, lng: convoy.startLng };

  const points = [
    startPoint,
    ...currentWaypoints.map((w) => ({ lat: w.lat, lng: w.lng })),
    { lat: destLat, lng: destLng },
  ];

  let options;
  try {
    options = await getRouteOptions({ points });
  } catch (err) {
    return res.status(err.status || 500).json({ error: "Route generation failed: " + err.message });
  }

  const chosen = options[0];

  const updated = await prisma.$transaction(async (tx) => {
    if (d.waypoints !== undefined) {
      await tx.waypoint.deleteMany({ where: { convoyId: convoy.id } });
      if (d.waypoints.length) {
        await tx.waypoint.createMany({
          data: d.waypoints.map((w, i) => ({ ...w, convoyId: convoy.id, order: i })),
        });
      }
    }
    await tx.stop.deleteMany({ where: { convoyId: convoy.id } });
    return tx.convoy.update({
      where: { id: convoy.id },
      data: {
        destLabel,
        destLat,
        destLng,
        routePolyline: chosen.polyline,
        routeDistanceM: chosen.distanceM,
        routeDurationS: chosen.durationS,
        routeSummary: chosen.summary,
        routeLocked: true,
        lockedAt: new Date(),
      },
      include: { stops: true, members: true, waypoints: { orderBy: { order: "asc" } } },
    });
  });

  const io = req.app.get("io");
  io.to(`convoy:${convoy.code}`).emit("route:locked", updated);

  res.json(updated);
});

/** POST /convoys/:code/join — a client joins with the convoy code. */
const joinSchema = z.object({
  vehicleName: z.string().min(1),
  passengers: z.number().int().min(1).max(12).default(1),
});

router.post("/:code/join", async (req, res) => {
  const convoy = await prisma.convoy.findUnique({ where: { code: req.params.code.toUpperCase() } });
  if (!convoy) return res.status(404).json({ error: "No convoy with that code" });

  const parsed = joinSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const member = await prisma.convoyMember.upsert({
    where: { convoyId_userId: { convoyId: convoy.id, userId: req.userId } },
    update: { vehicleName: parsed.data.vehicleName, passengers: parsed.data.passengers },
    create: {
      convoyId: convoy.id,
      userId: req.userId,
      role: "client",
      vehicleName: parsed.data.vehicleName,
      passengers: parsed.data.passengers,
    },
  });

  const full = await prisma.convoy.findUnique({
    where: { id: convoy.id },
    include: {
      members: { include: { user: { select: { id: true, name: true } } } },
      stops: true,
      waypoints: { orderBy: { order: "asc" } },
    },
  });

  const io = req.app.get("io");
  io.to(`convoy:${convoy.code}`).emit("member:joined", member);

  res.status(201).json(full);
});

/** PATCH /convoys/:code/vehicle — update current user's vehicle name in the convoy */
router.patch("/:code/vehicle", async (req, res) => {
  const convoy = await prisma.convoy.findUnique({ where: { code: req.params.code.toUpperCase() } });
  if (!convoy) return res.status(404).json({ error: "No convoy with that code" });

  const vehicleName = req.body.vehicleName?.trim();
  if (!vehicleName) return res.status(400).json({ error: "Vehicle name is required" });

  // If another member in the target vehicle already has an active location, adopt it
  const targetMember = await prisma.convoyMember.findFirst({
    where: {
      convoyId: convoy.id,
      vehicleName: { equals: vehicleName, mode: "insensitive" },
      lastLat: { not: null },
    },
  });

  const updateData = { vehicleName };
  if (targetMember && targetMember.lastLat != null) {
    updateData.lastLat = targetMember.lastLat;
    updateData.lastLng = targetMember.lastLng;
    updateData.distanceAlongM = targetMember.distanceAlongM;
    updateData.lastPingAt = targetMember.lastPingAt;
  }

  const updatedMember = await prisma.convoyMember.update({
    where: { convoyId_userId: { convoyId: convoy.id, userId: req.userId } },
    data: updateData,
    include: { user: { select: { id: true, name: true } } },
  });

  const allMembers = await prisma.convoyMember.findMany({
    where: { convoyId: convoy.id },
    include: { user: { select: { id: true, name: true } } },
  });

  const ranked = rankConvoy(allMembers);
  const io = req.app.get("io");
  io.to(`convoy:${convoy.code}`).emit("convoy:ranked", {
    updatedMemberId: updatedMember.id,
    members: ranked,
  });

  res.json({ member: updatedMember, members: ranked });
});

/** GET /convoys/:code — full convoy state, including a live-ranked roster. */
router.get("/:code", async (req, res) => {
  const convoy = await prisma.convoy.findUnique({
    where: { code: req.params.code.toUpperCase() },
    include: {
      members: { include: { user: { select: { id: true, name: true } } } },
      stops: { orderBy: { order: "asc" } },
      waypoints: { orderBy: { order: "asc" } },
      messages: { orderBy: { createdAt: "asc" }, take: 100, include: { user: { select: { name: true } } } },
    },
  });
  if (!convoy) return res.status(404).json({ error: "No convoy with that code" });

  const ranked = rankConvoy(convoy.members);
  res.json({ ...convoy, ranked });
});

/** POST /convoys/:code/proposals — a client proposes a route/destination change. */
const proposalSchema = z.object({
  summary: z.string().min(1).max(280),
  destLabel: z.string().optional(),
  destLat: z.number().optional(),
  destLng: z.number().optional(),
});

router.post("/:code/proposals", async (req, res) => {
  const convoy = await prisma.convoy.findUnique({ where: { code: req.params.code.toUpperCase() } });
  if (!convoy) return res.status(404).json({ error: "No convoy with that code" });

  const parsed = proposalSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const proposal = await prisma.routeProposal.create({
    data: { convoyId: convoy.id, proposedById: req.userId, ...parsed.data },
  });

  // Proposals are visible to the host only — not broadcast to the whole convoy.
  const io = req.app.get("io");
  io.to(`convoy:${convoy.code}:host`).emit("proposal:new", proposal);

  res.status(201).json(proposal);
});

/**
 * POST /convoys/:code/proposals/:id/resolve — host accepts or declines a
 * proposal. Accepting a proposal that carries a new destination re-runs
 * the route flow automatically: fetch fresh route options through the
 * convoy's existing waypoints (unchanged) to the *new* final destination,
 * take the top one, and re-lock. A proposal with no destination (e.g.
 * "let's skip the lunch stop") is just recorded as accepted with no route
 * change. Proposals only ever change the final destination, not the
 * waypoint list — a client wanting to add/reorder intermediate stops would
 * need a richer proposal shape than exists today (see README).
 */
const resolveSchema = z.object({ decision: z.enum(["accepted", "declined"]) });

router.post("/:code/proposals/:id/resolve", async (req, res) => {
  const convoy = await requireHost(req, res);
  if (!convoy) return;

  const parsed = resolveSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const existing = await prisma.routeProposal.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.convoyId !== convoy.id) {
    return res.status(404).json({ error: "No such proposal on this convoy" });
  }

  const proposal = await prisma.routeProposal.update({
    where: { id: req.params.id },
    data: { status: parsed.data.decision },
  });

  const io = req.app.get("io");
  let updatedConvoy = null;

  const hasNewDestination =
    parsed.data.decision === "accepted" &&
    proposal.destLat != null &&
    proposal.destLng != null;

  if (hasNewDestination) {
    const waypoints = await prisma.waypoint.findMany({
      where: { convoyId: convoy.id },
      orderBy: { order: "asc" },
    });
    const points = [
      { lat: convoy.startLat, lng: convoy.startLng },
      ...waypoints.map((w) => ({ lat: w.lat, lng: w.lng })),
      { lat: proposal.destLat, lng: proposal.destLng },
    ];
    const options = await getRouteOptions({ points });
    const chosen = options[0]; // top Directions result; host isn't prompted again on accept

    updatedConvoy = await prisma.$transaction(async (tx) => {
      // Stops were plotted against the old route's distances, so they no
      // longer make sense once the destination changes.
      await tx.stop.deleteMany({ where: { convoyId: convoy.id } });
      return tx.convoy.update({
        where: { id: convoy.id },
        data: {
          destLabel: proposal.destLabel || convoy.destLabel,
          destLat: proposal.destLat,
          destLng: proposal.destLng,
          routePolyline: chosen.polyline,
          routeDistanceM: chosen.distanceM,
          routeDurationS: chosen.durationS,
          routeSummary: chosen.summary,
          routeLocked: true,
          lockedAt: new Date(),
        },
        include: { stops: true, members: true, waypoints: { orderBy: { order: "asc" } } },
      });
    });

    io.to(`convoy:${convoy.code}`).emit("route:locked", updatedConvoy);
  }

  io.to(`convoy:${convoy.code}`).emit("proposal:resolved", proposal);

  res.json({ proposal, convoy: updatedConvoy });
});

/** GET /convoys/:code/proposals — pending proposals, for the host inbox. */
router.get("/:code/proposals", async (req, res) => {
  const convoy = await requireHost(req, res);
  if (!convoy) return;

  const proposals = await prisma.routeProposal.findMany({
    where: { convoyId: convoy.id, status: "pending" },
    orderBy: { createdAt: "asc" },
  });
  res.json({ proposals });
});

/** Shared guard: loads the convoy by code and 403s if req.userId isn't its host. */
async function requireHost(req, res) {
  const convoy = await prisma.convoy.findUnique({ where: { code: req.params.code.toUpperCase() } });
  if (!convoy) {
    res.status(404).json({ error: "No convoy with that code" });
    return null;
  }
  if (convoy.hostId !== req.userId) {
    res.status(403).json({ error: "Only the host can do that" });
    return null;
  }
  return convoy;
}

module.exports = router;

