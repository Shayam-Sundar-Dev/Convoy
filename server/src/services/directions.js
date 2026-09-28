const axios = require("axios");

const DIRECTIONS_URL = "https://api.mapbox.com/directions/v5/mapbox/driving";

/**
 * Fetch route options through an ordered list of points: start, any
 * intermediate destinations, then the final destination. Returns up to 3
 * alternative routes, each with a single combined polyline spanning every
 * leg, total distance (m), total duration (s), and a summary built from
 * each leg's road names.
 *
 * Mapbox's `geometries=polyline` output uses the same encoding and
 * precision (5 decimal places) as Google's, so it decodes with the exact
 * same decodePolyline() in utils/geo.js — nothing there needed to change,
 * multi-waypoint or not.
 */
async function getRouteOptions({ points, avoidTolls = false }) {
  const token = process.env.MAPBOX_ACCESS_TOKEN;
  if (!token) {
    throw new Error(
      "MAPBOX_ACCESS_TOKEN is not set. Add it to server/.env — see README for how to get one."
    );
  }
  if (!Array.isArray(points) || points.length < 2) {
    throw new Error("getRouteOptions needs at least a start and a destination");
  }

  // Mapbox takes coordinates as lng,lat (reverse of the lat,lng order used
  // everywhere else in this codebase), semicolon-separated for each stop
  // the route must pass through, in order.
  const coordinates = points.map((p) => `${p.lng},${p.lat}`).join(";");

  const { data } = await axios.get(`${DIRECTIONS_URL}/${coordinates}`, {
    params: {
      alternatives: true,
      geometries: "polyline",
      overview: "full", // one combined geometry across all legs, not per-leg
      steps: false,
      exclude: avoidTolls ? "toll" : undefined,
      access_token: token,
    },
  });

  if (data.code !== "Ok") {
    const err = new Error(`Directions API error: ${data.code} ${data.message || ""}`.trim());
    err.status = 502;
    throw err;
  }

  return data.routes.map((route, i) => {
    // One leg per hop between consecutive points (start→wp1, wp1→wp2, …,
    // wpN→destination) — sum them for the trip total, and stitch each
    // leg's road-name summary together so a multi-destination trip reads
    // as e.g. "I-80 W → US-101 N" rather than just the first leg's roads.
    const legSummaries = route.legs.map((leg) => leg.summary).filter(Boolean);
    return {
      index: i,
      summary: legSummaries.length ? legSummaries.join(" → ") : `Route ${i + 1}`,
      polyline: route.geometry,
      distanceM: route.distance,
      durationS: Math.round(route.duration),
      legs: route.legs.map((leg) => ({
        distanceM: leg.distance,
        durationS: Math.round(leg.duration),
        summary: leg.summary,
      })),
    };
  });
}

module.exports = { getRouteOptions };
