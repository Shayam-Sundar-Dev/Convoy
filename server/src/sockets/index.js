const jwt = require("jsonwebtoken");
const { prisma } = require("../config/db");
const { decodePolyline, buildRouteTable, distanceAlongRoute, rankConvoy } = require("../utils/geo");

// Route tables are expensive-ish to build (O(n) over polyline points) and
// don't change once a route is locked, so cache one per convoy code.
const routeTableCache = new Map(); // code -> { table, polyline }

async function getRouteTable(convoy) {
  if (!convoy.routePolyline) return null;
  const cached = routeTableCache.get(convoy.code);
  if (cached && cached.polyline === convoy.routePolyline) return cached.table;

  const points = decodePolyline(convoy.routePolyline);
  const table = buildRouteTable(points);
  routeTableCache.set(convoy.code, { table, polyline: convoy.routePolyline });
  return table;
}

function attachSockets(io) {
  io.use((socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      const payload = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId = payload.sub;
      next();
    } catch {
      next(new Error("unauthorized"));
    }
  });

  io.on("connection", (socket) => {
    /**
     * Client joins the room for a convoy right after opening the map screen.
     * Hosts also join a second, host-only room so route proposals can be
     * sent to just them instead of the whole convoy.
     */
    socket.on("convoy:enter", async ({ code }) => {
      const convoy = await prisma.convoy.findUnique({ where: { code: code.toUpperCase() } });
      if (!convoy) return socket.emit("error", { error: "No convoy with that code" });

      socket.join(`convoy:${convoy.code}`);
      if (convoy.hostId === socket.userId) socket.join(`convoy:${convoy.code}:host`);
      socket.data.convoyCode = convoy.code;
    });

    /**
     * Core live-tracking event. A vehicle reports its raw GPS fix; the
     * server projects it onto the locked route, stores the distance
     * travelled, re-ranks the whole convoy, and broadcasts the result to
     * everyone in the room — this is what drives the map's lead pin and
     * gap bar on every connected device.
     */
    socket.on("location:ping", async ({ code, lat, lng }) => {
      const convoy = await prisma.convoy.findUnique({
        where: { code: code.toUpperCase() },
        include: { members: true },
      });
      if (!convoy) return;

      const member = convoy.members.find((m) => m.userId === socket.userId);
      if (!member) return;

      let distanceAlongM = null;
      if (convoy.routeLocked) {
        const table = await getRouteTable(convoy);
        if (table) distanceAlongM = distanceAlongRoute(table, { lat, lng });
      }

      const updated = await prisma.convoyMember.update({
        where: { id: member.id },
        data: { lastLat: lat, lastLng: lng, distanceAlongM, lastPingAt: new Date() },
      });

      // Synchronize location to any other people sharing the same vehicle
      const vName = member.vehicleName?.trim().toLowerCase();
      if (vName) {
        await prisma.convoyMember.updateMany({
          where: {
            convoyId: convoy.id,
            vehicleName: { equals: member.vehicleName, mode: "insensitive" },
            id: { not: member.id },
          },
          data: { lastLat: lat, lastLng: lng, distanceAlongM, lastPingAt: new Date() },
        });
      }

      const allMembers = convoy.members.map((m) => {
        const mVName = m.vehicleName?.trim().toLowerCase();
        if (m.id === updated.id || (vName && mVName === vName)) {
          return { ...m, lastLat: lat, lastLng: lng, distanceAlongM, lastPingAt: new Date() };
        }
        return m;
      });
      const ranked = rankConvoy(allMembers);

      // Flag stragglers against the convoy's configured threshold and mark
      // status so the roster and straggler alert both reflect it.
      const withStatus = ranked.map((m) => ({
        ...m,
        status: m.gapToLeadM > convoy.staggerAlertM ? "behind" : "ok",
      }));

      io.to(`convoy:${convoy.code}`).emit("convoy:ranked", {
        updatedMemberId: updated.id,
        members: withStatus,
      });

      const straggler = withStatus.find((m) => m.status === "behind" && !m.isLead);
      if (straggler) {
        io.to(`convoy:${convoy.code}`).emit("convoy:straggler-alert", {
          memberId: straggler.id,
          gapToLeadM: straggler.gapToLeadM,
        });
      }
    });

    /** Allow members to update their assigned vehicle name in real-time */
    socket.on("member:update-vehicle", async ({ code, vehicleName }) => {
      const vName = vehicleName?.trim();
      if (!vName) return;

      const convoy = await prisma.convoy.findUnique({
        where: { code: code.toUpperCase() },
        include: { members: { include: { user: { select: { id: true, name: true } } } } },
      });
      if (!convoy) return;

      const member = convoy.members.find((m) => m.userId === socket.userId);
      if (!member) return;

      // If another member in the target vehicle already has an active location, adopt it
      const targetVehicleMember = convoy.members.find(
        (m) => m.id !== member.id && m.vehicleName.trim().toLowerCase() === vName.toLowerCase() && m.lastLat != null
      );

      const updateData = {
        vehicleName: vName,
      };
      if (targetVehicleMember && targetVehicleMember.lastLat != null) {
        updateData.lastLat = targetVehicleMember.lastLat;
        updateData.lastLng = targetVehicleMember.lastLng;
        updateData.distanceAlongM = targetVehicleMember.distanceAlongM;
        updateData.lastPingAt = targetVehicleMember.lastPingAt;
      }

      const updated = await prisma.convoyMember.update({
        where: { id: member.id },
        data: updateData,
        include: { user: { select: { id: true, name: true } } },
      });

      const freshMembers = await prisma.convoyMember.findMany({
        where: { convoyId: convoy.id },
        include: { user: { select: { id: true, name: true } } },
      });

      const ranked = rankConvoy(freshMembers);
      io.to(`convoy:${convoy.code}`).emit("convoy:ranked", {
        updatedMemberId: updated.id,
        members: ranked,
      });
    });

    /** Quick pings and free-text chat, broadcast to the whole convoy. */
    socket.on("ping:send", async ({ code, body, kind }) => {
      const convoy = await prisma.convoy.findUnique({ where: { code: code.toUpperCase() } });
      if (!convoy) return;

      const message = await prisma.message.create({
        data: { convoyId: convoy.id, userId: socket.userId, body, kind: kind || "text" },
        include: { user: { select: { name: true } } },
      });

      io.to(`convoy:${convoy.code}`).emit("ping:new", message);
    });

    /** Walkie-Talkie Push-to-Talk status (user started or stopped speaking). */
    socket.on("voice:status", async ({ code, isTransmitting }) => {
      const user = await prisma.user.findUnique({
        where: { id: socket.userId },
        select: { name: true },
      });
      socket.to(`convoy:${code.toUpperCase()}`).emit("voice:status", {
        userId: socket.userId,
        userName: user ? user.name : "Driver",
        isTransmitting: Boolean(isTransmitting),
      });
    });

    /** Walkie-Talkie voice transmission broadcast to all cars in the convoy. */
    socket.on("voice:transmit", async ({ code, audioBase64, durationMs }) => {
      const convoy = await prisma.convoy.findUnique({ where: { code: code.toUpperCase() } });
      if (!convoy) return;
      const user = await prisma.user.findUnique({
        where: { id: socket.userId },
        select: { name: true },
      });

      socket.to(`convoy:${convoy.code}`).emit("voice:receive", {
        senderId: socket.userId,
        senderName: user ? user.name : "Driver",
        audioBase64,
        durationMs: durationMs || 0,
        timestamp: new Date().toISOString(),
      });
    });

    socket.on("disconnect", () => {
      // Presence/"last seen" handling can hook in here if needed later.
    });
  });
}

module.exports = { attachSockets };

