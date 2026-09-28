/**
 * Geometry helpers for placing a vehicle's raw GPS fix onto the convoy's
 * locked route, so "who is leading" and "how big is the gap" are measured
 * as distance travelled along the road — not straight-line distance.
 */

const EARTH_RADIUS_M = 6371000;

function toRad(deg) {
  return (deg * Math.PI) / 180;
}

/** Haversine distance between two lat/lng points, in meters. */
function haversineMeters(a, b) {
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
}

/**
 * Decode a Google Maps encoded polyline into an array of {lat, lng} points.
 * Standard algorithm — see Google's Encoded Polyline Algorithm Format.
 */
function decodePolyline(encoded) {
  const points = [];
  let index = 0,
    lat = 0,
    lng = 0;

  while (index < encoded.length) {
    let result = 1,
      shift = 0,
      b;
    do {
      b = encoded.charCodeAt(index++) - 63 - 1;
      result += b << shift;
      shift += 5;
    } while (b >= 0x1f);
    lat += result & 1 ? ~(result >> 1) : result >> 1;

    result = 1;
    shift = 0;
    do {
      b = encoded.charCodeAt(index++) - 63 - 1;
      result += b << shift;
      shift += 5;
    } while (b >= 0x1f);
    lng += result & 1 ? ~(result >> 1) : result >> 1;

    points.push({ lat: lat * 1e-5, lng: lng * 1e-5 });
  }
  return points;
}

/**
 * Build a cumulative-distance lookup table for a decoded route: for each
 * vertex, how many meters along the route it sits at. O(n) once per route.
 */
function buildRouteTable(points) {
  const cumulative = [0];
  for (let i = 1; i < points.length; i++) {
    cumulative.push(cumulative[i - 1] + haversineMeters(points[i - 1], points[i]));
  }
  return { points, cumulative, totalM: cumulative[cumulative.length - 1] };
}

/**
 * Project a raw GPS fix onto the route table and return the distance
 * travelled along the route (meters) at the closest point.
 *
 * For each segment of the route we find the nearest point to `fix` (clamped
 * projection onto the segment), take the globally closest one, and return
 * that segment's cumulative distance plus the distance into the segment.
 * This is O(n) in route vertices, which is fine for typical routes
 * (hundreds to low thousands of points) on every location ping.
 */
function distanceAlongRoute(routeTable, fix) {
  const { points, cumulative } = routeTable;
  let best = { distM: Infinity, alongM: 0 };

  for (let i = 0; i < points.length - 1; i++) {
    const a = points[i];
    const b = points[i + 1];

    // Project fix onto segment a->b in a simple equirectangular local frame
    // (fine at road-segment scale) to find the nearest point and the
    // fractional position t along the segment.
    const ax = a.lng, ay = a.lat;
    const bx = b.lng, by = b.lat;
    const fx = fix.lng, fy = fix.lat;

    const dx = bx - ax, dy = by - ay;
    const lenSq = dx * dx + dy * dy;
    let t = lenSq === 0 ? 0 : ((fx - ax) * dx + (fy - ay) * dy) / lenSq;
    t = Math.max(0, Math.min(1, t));

    const projLat = ay + t * dy;
    const projLng = ax + t * dx;
    const d = haversineMeters(fix, { lat: projLat, lng: projLng });

    if (d < best.distM) {
      const segLenM = cumulative[i + 1] - cumulative[i];
      best = { distM: d, alongM: cumulative[i] + t * segLenM };
    }
  }
  return best.alongM;
}

/**
 * Rank convoy members by distance travelled along the route (descending).
 * Returns members annotated with `gapToLeadM`, sorted lead-first.
 */
function rankConvoy(members) {
  const withDist = members.filter((m) => typeof m.distanceAlongM === "number");
  const sorted = withDist.slice().sort((a, b) => b.distanceAlongM - a.distanceAlongM);
  const leadDist = sorted.length ? sorted[0].distanceAlongM : 0;
  return sorted.map((m, i) => ({
    ...m,
    position: i + 1,
    isLead: i === 0,
    gapToLeadM: leadDist - m.distanceAlongM,
  }));
}

module.exports = {
  haversineMeters,
  decodePolyline,
  buildRouteTable,
  distanceAlongRoute,
  rankConvoy,
};
