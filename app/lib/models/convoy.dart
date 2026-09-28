class LatLngPoint {
  final double lat;
  final double lng;
  const LatLngPoint(this.lat, this.lng);

  factory LatLngPoint.fromJson(Map<String, dynamic> j) =>
      LatLngPoint((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble());
}

class Waypoint {
  final String id;
  final String label;
  final double lat;
  final double lng;

  Waypoint({required this.id, required this.label, required this.lat, required this.lng});

  factory Waypoint.fromJson(Map<String, dynamic> j) => Waypoint(
        id: j['id'],
        label: j['label'],
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
      );
}

class Stop {
  final String id;
  final String label;
  final double lat;
  final double lng;
  final double distanceAlongM;
  final String kind; // fuel | food | rest | waypoint

  Stop({
    required this.id,
    required this.label,
    required this.lat,
    required this.lng,
    required this.distanceAlongM,
    required this.kind,
  });

  factory Stop.fromJson(Map<String, dynamic> j) => Stop(
        id: j['id'],
        label: j['label'],
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        distanceAlongM: (j['distanceAlongM'] as num).toDouble(),
        kind: j['kind'] ?? 'waypoint',
      );
}

/// A single vehicle's live state within a convoy, plus the server-computed
/// ranking fields (position/isLead/gapToLeadM) once locations start coming in.
class ConvoyMember {
  final String id;
  final String userId;
  final String userName;
  final String role; // host | client
  final String vehicleName;
  final int passengers;
  final double? lastLat;
  final double? lastLng;
  final double? distanceAlongM;
  final String status; // ok | behind | stopped | emergency
  final int? position;
  final bool isLead;
  final double? gapToLeadM;
  final DateTime? lastPingAt;

  ConvoyMember({
    required this.id,
    required this.userId,
    required this.userName,
    required this.role,
    required this.vehicleName,
    required this.passengers,
    this.lastLat,
    this.lastLng,
    this.distanceAlongM,
    this.status = 'ok',
    this.position,
    this.isLead = false,
    this.gapToLeadM,
    this.lastPingAt,
  });

  /// True once a member's last position update is old enough that it
  /// shouldn't be trusted as "where they are right now" — a dead zone, the
  /// app backgrounded without foreground tracking working, airplane mode,
  /// etc. The map/roster show "last seen" instead of treating a stale dot
  /// as live.
  bool get isStale {
    if (lastPingAt == null) return true;
    return DateTime.now().difference(lastPingAt!) > const Duration(seconds: 25);
  }

  String get lastSeenLabel {
    if (lastPingAt == null) return 'no position yet';
    final seconds = DateTime.now().difference(lastPingAt!).inSeconds;
    if (seconds < 5) return 'just now';
    if (seconds < 60) return '${seconds}s ago';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m ago';
    return '${minutes ~/ 60}h ago';
  }

  factory ConvoyMember.fromJson(Map<String, dynamic> j) => ConvoyMember(
        id: j['id'],
        userId: j['userId'],
        userName: j['user']?['name'] ?? 'Unknown',
        role: j['role'] ?? 'client',
        vehicleName: j['vehicleName'] ?? '',
        passengers: j['passengers'] ?? 1,
        lastLat: (j['lastLat'] as num?)?.toDouble(),
        lastLng: (j['lastLng'] as num?)?.toDouble(),
        distanceAlongM: (j['distanceAlongM'] as num?)?.toDouble(),
        status: j['status'] ?? 'ok',
        position: j['position'],
        isLead: j['isLead'] ?? false,
        gapToLeadM: (j['gapToLeadM'] as num?)?.toDouble(),
        lastPingAt: j['lastPingAt'] != null ? DateTime.tryParse(j['lastPingAt']) : null,
      );

  ConvoyMember copyWithRank(Map<String, dynamic> j) => ConvoyMember(
        id: id,
        userId: userId,
        userName: userName,
        role: role,
        vehicleName: vehicleName,
        passengers: passengers,
        lastLat: (j['lastLat'] as num?)?.toDouble() ?? lastLat,
        lastLng: (j['lastLng'] as num?)?.toDouble() ?? lastLng,
        distanceAlongM: (j['distanceAlongM'] as num?)?.toDouble() ?? distanceAlongM,
        status: j['status'] ?? status,
        position: j['position'] ?? position,
        isLead: j['isLead'] ?? isLead,
        gapToLeadM: (j['gapToLeadM'] as num?)?.toDouble() ?? gapToLeadM,
        lastPingAt: j['lastPingAt'] != null ? DateTime.tryParse(j['lastPingAt']) : lastPingAt,
      );
}

/// Represents a vehicle in the convoy, grouping all people/passengers traveling in it.
class ConvoyVehicle {
  final String name;
  final List<ConvoyMember> members;
  final bool isLead;
  final bool isStale;
  final double? lastLat;
  final double? lastLng;
  final double? distanceAlongM;
  final double gapToLeadM;
  final int? position;

  ConvoyVehicle({
    required this.name,
    required this.members,
    required this.isLead,
    required this.isStale,
    this.lastLat,
    this.lastLng,
    this.distanceAlongM,
    this.gapToLeadM = 0,
    this.position,
  });

  List<String> get passengerNames => members.map((m) => m.userName).toList();
  int get passengerCount => members.fold<int>(0, (sum, m) => sum + (m.passengers > 0 ? m.passengers : 1));

  bool containsUser(String? userId) {
    if (userId == null) return false;
    return members.any((m) => m.userId == userId);
  }

  String get lastSeenLabel {
    final validPings = members.map((m) => m.lastPingAt).whereType<DateTime>().toList();
    if (validPings.isEmpty) return 'no position yet';
    validPings.sort((a, b) => b.compareTo(a));
    final latest = validPings.first;
    final seconds = DateTime.now().difference(latest).inSeconds;
    if (seconds < 5) return 'just now';
    if (seconds < 60) return '${seconds}s ago';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m ago';
    return '${minutes ~/ 60}h ago';
  }
}

/// Groups flat convoy members by vehicleName into distinct vehicles for tracking & display.
List<ConvoyVehicle> groupMembersByVehicle(List<ConvoyMember> members) {
  if (members.isEmpty) return [];

  final Map<String, List<ConvoyMember>> groups = {};
  for (final m in members) {
    final key = m.vehicleName.trim().isNotEmpty ? m.vehicleName.trim() : 'Vehicle';
    groups.putIfAbsent(key, () => []).add(m);
  }

  final result = <ConvoyVehicle>[];
  int autoPos = 1;
  for (final entry in groups.entries) {
    final vName = entry.key;
    final vMembers = entry.value;

    ConvoyMember? bestFix;
    for (final m in vMembers) {
      if (m.lastLat != null && m.lastLng != null) {
        if (bestFix == null) {
          bestFix = m;
        } else {
          final tM = m.lastPingAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final tB = bestFix.lastPingAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          if (tM.isAfter(tB)) {
            bestFix = m;
          }
        }
      }
    }

    final isLead = vMembers.any((m) => m.isLead);
    final isStale = vMembers.every((m) => m.isStale);
    final minGap = vMembers.map((m) => m.gapToLeadM ?? double.infinity).fold<double>(double.infinity, (prev, val) => val < prev ? val : prev);

    result.add(ConvoyVehicle(
      name: vName,
      members: vMembers,
      isLead: isLead,
      isStale: isStale,
      lastLat: bestFix?.lastLat,
      lastLng: bestFix?.lastLng,
      distanceAlongM: bestFix?.distanceAlongM,
      gapToLeadM: minGap.isFinite ? minGap : 0,
      position: vMembers.map((m) => m.position).whereType<int>().firstOrNull ?? autoPos,
    ));
    autoPos++;
  }

  result.sort((a, b) {
    if (a.isLead && !b.isLead) return -1;
    if (!a.isLead && b.isLead) return 1;
    final distA = a.distanceAlongM ?? -1;
    final distB = b.distanceAlongM ?? -1;
    return distB.compareTo(distA);
  });

  return result;
}


class ConvoyMessage {
  final String id;
  final String userName;
  final String body;
  final String kind;
  final DateTime createdAt;

  ConvoyMessage({
    required this.id,
    required this.userName,
    required this.body,
    required this.kind,
    required this.createdAt,
  });

  factory ConvoyMessage.fromJson(Map<String, dynamic> j) => ConvoyMessage(
        id: j['id'],
        userName: j['user']?['name'] ?? 'Someone',
        body: j['body'],
        kind: j['kind'] ?? 'text',
        createdAt: DateTime.parse(j['createdAt']),
      );
}

class Convoy {
  final String id;
  final String code;
  final String name;
  final String hostId;
  final String status;
  final String startLabel;
  final double startLat;
  final double startLng;
  final String destLabel;
  final double destLat;
  final double destLng;
  final bool routeLocked;
  final String? routePolyline;
  final double? routeDistanceM;
  final int? routeDurationS;
  final String? routeSummary;
  final List<Stop> stops;
  final List<Waypoint> waypoints;
  final List<ConvoyMember> members;
  final List<ConvoyMessage> messages;

  Convoy({
    required this.id,
    required this.code,
    required this.name,
    required this.hostId,
    required this.status,
    required this.startLabel,
    required this.startLat,
    required this.startLng,
    required this.destLabel,
    required this.destLat,
    required this.destLng,
    required this.routeLocked,
    this.routePolyline,
    this.routeDistanceM,
    this.routeDurationS,
    this.routeSummary,
    this.stops = const [],
    this.waypoints = const [],
    this.members = const [],
    this.messages = const [],
  });

  bool isHost(String userId) => hostId == userId;

  factory Convoy.fromJson(Map<String, dynamic> j) => Convoy(
        id: j['id'],
        code: j['code'],
        name: j['name'],
        hostId: j['hostId'],
        status: j['status'],
        startLabel: j['startLabel'],
        startLat: (j['startLat'] as num).toDouble(),
        startLng: (j['startLng'] as num).toDouble(),
        destLabel: j['destLabel'],
        destLat: (j['destLat'] as num).toDouble(),
        destLng: (j['destLng'] as num).toDouble(),
        routeLocked: j['routeLocked'] ?? false,
        routePolyline: j['routePolyline'],
        routeDistanceM: (j['routeDistanceM'] as num?)?.toDouble(),
        routeDurationS: j['routeDurationS'],
        routeSummary: j['routeSummary'],
        stops: (j['stops'] as List? ?? []).map((s) => Stop.fromJson(s)).toList(),
        waypoints: (j['waypoints'] as List? ?? []).map((w) => Waypoint.fromJson(w)).toList(),
        members: (j['members'] as List? ?? j['ranked'] as List? ?? [])
            .map((m) => ConvoyMember.fromJson(m))
            .toList(),
        messages: (j['messages'] as List? ?? []).map((m) => ConvoyMessage.fromJson(m)).toList(),
      );
}

class RouteProposal {
  final String id;
  final String proposedById;
  final String summary;
  final String? destLabel;
  final double? destLat;
  final double? destLng;
  final String status; // pending | accepted | declined

  RouteProposal({
    required this.id,
    required this.proposedById,
    required this.summary,
    this.destLabel,
    this.destLat,
    this.destLng,
    required this.status,
  });

  factory RouteProposal.fromJson(Map<String, dynamic> j) => RouteProposal(
        id: j['id'],
        proposedById: j['proposedById'],
        summary: j['summary'],
        destLabel: j['destLabel'],
        destLat: (j['destLat'] as num?)?.toDouble(),
        destLng: (j['destLng'] as num?)?.toDouble(),
        status: j['status'] ?? 'pending',
      );
}

class RouteOption {
  final int index;
  final String summary;
  final String polyline;
  final double distanceM;
  final int durationS;

  RouteOption({
    required this.index,
    required this.summary,
    required this.polyline,
    required this.distanceM,
    required this.durationS,
  });

  factory RouteOption.fromJson(Map<String, dynamic> j) => RouteOption(
        index: j['index'],
        summary: j['summary'],
        polyline: j['polyline'],
        distanceM: (j['distanceM'] as num).toDouble(),
        durationS: j['durationS'],
      );
}
