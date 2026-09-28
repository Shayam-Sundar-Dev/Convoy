import 'dart:math';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show Position;

/// Mirrors the cumulative-distance approach in server/src/utils/geo.js, but
/// for drawing a sub-segment of the route client-side rather than ranking
/// vehicles. Kept deliberately separate from the server's copy — this one
/// only needs to slice a polyline, not project arbitrary GPS fixes onto it.
const double _earthRadiusM = 6371000;

double _toRad(double deg) => deg * pi / 180;

double haversineMeters(Position a, Position b) {
  final dLat = _toRad(b.lat.toDouble() - a.lat.toDouble());
  final dLng = _toRad(b.lng.toDouble() - a.lng.toDouble());
  final lat1 = _toRad(a.lat.toDouble());
  final lat2 = _toRad(b.lat.toDouble());
  final h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
  return 2 * _earthRadiusM * asin(min(1, sqrt(h)));
}

/// Cumulative distance (meters) at each vertex of a decoded route.
List<double> buildCumulativeDistances(List<Position> points) {
  final cumulative = <double>[0];
  for (var i = 1; i < points.length; i++) {
    cumulative.add(cumulative[i - 1] + haversineMeters(points[i - 1], points[i]));
  }
  return cumulative;
}

/// Slice out the portion of [points] between [fromM] and [toM] (meters
/// along the route), interpolating the two cut endpoints so the segment
/// starts and ends exactly at the requested distances rather than snapping
/// to the nearest existing vertex. Used to redraw just the lead-to-last
/// stretch of road in amber.
List<Position> sliceRouteByDistance(
  List<Position> points,
  List<double> cumulative,
  double fromM,
  double toM,
) {
  if (points.length < 2 || toM <= fromM) return [];
  final total = cumulative.last;
  final start = fromM.clamp(0, total).toDouble();
  final end = toM.clamp(0, total).toDouble();

  final result = <Position>[];
  for (var i = 0; i < points.length - 1; i++) {
    final segStart = cumulative[i];
    final segEnd = cumulative[i + 1];
    if (segEnd < start || segStart > end) continue;

    // Entering the window on this segment — interpolate the exact cut point.
    if (result.isEmpty) {
      final t = segEnd == segStart ? 0.0 : (start - segStart) / (segEnd - segStart);
      result.add(_lerp(points[i], points[i + 1], t.clamp(0, 1)));
    }
    // Leaving the window on this segment — interpolate and stop.
    if (segEnd >= end) {
      final t = segEnd == segStart ? 0.0 : (end - segStart) / (segEnd - segStart);
      result.add(_lerp(points[i], points[i + 1], t.clamp(0, 1)));
      break;
    }
    result.add(points[i + 1]);
  }
  return result;
}

Position _lerp(Position a, Position b, double t) => Position(
      a.lng + (b.lng - a.lng) * t,
      a.lat + (b.lat - a.lat) * t,
    );
