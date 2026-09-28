import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class PlaceSuggestion {
  final String mapboxId;
  final String name;
  final String? fullAddress;

  PlaceSuggestion({required this.mapboxId, required this.name, this.fullAddress});

  factory PlaceSuggestion.fromJson(Map<String, dynamic> j) => PlaceSuggestion(
        mapboxId: j['mapbox_id'],
        name: j['name'] ?? j['place_formatted'] ?? 'Unnamed place',
        fullAddress: j['place_formatted'],
      );

  String get label => fullAddress != null && fullAddress!.isNotEmpty ? '$name, $fullAddress' : name;
}

class PlaceDetails {
  final String label;
  final double lat;
  final double lng;
  PlaceDetails({required this.label, required this.lat, required this.lng});
}

/// Thin client for Mapbox's Search Box API — used for the start/destination
/// autocomplete fields on the host setup screen. Uses the "suggest then
/// retrieve" two-step flow Mapbox requires: /suggest returns lightweight
/// candidates (no coordinates), /retrieve resolves one candidate to a full
/// address + lat/lng, keyed by a session token so Mapbox can bill the pair
/// as a single search session rather than per-keystroke.
///
/// Docs: https://docs.mapbox.com/api/search/search-box/
class PlacesService {
  static const String _base = 'https://api.mapbox.com/search/searchbox/v1';

  final String accessToken;
  final _uuid = const Uuid();
  late String _sessionToken = _uuid.v4();

  PlacesService(this.accessToken);

  /// Call once when a search field first gains focus / is cleared, so a new
  /// billed session starts. Keep reusing the same token across keystrokes
  /// until a place is picked.
  void newSession() => _sessionToken = _uuid.v4();

  Future<List<PlaceSuggestion>> suggest(String query) async {
    if (query.trim().length < 2) return [];

    final uri = Uri.parse('$_base/suggest').replace(queryParameters: {
      'q': query,
      'access_token': accessToken,
      'session_token': _sessionToken,
      'limit': '6',
    });

    final res = await http.get(uri);
    if (res.statusCode >= 400) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final suggestions = (body['suggestions'] as List? ?? []);
    return suggestions.map((s) => PlaceSuggestion.fromJson(s)).toList();
  }

  Future<PlaceDetails?> retrieve(PlaceSuggestion suggestion) async {
    final uri = Uri.parse('$_base/retrieve/${suggestion.mapboxId}').replace(queryParameters: {
      'access_token': accessToken,
      'session_token': _sessionToken,
    });

    final res = await http.get(uri);
    if (res.statusCode >= 400) return null;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final features = body['features'] as List?;
    if (features == null || features.isEmpty) return null;

    final feature = features.first as Map<String, dynamic>;
    final coords = feature['geometry']['coordinates'] as List; // [lng, lat]
    final props = feature['properties'] as Map<String, dynamic>;

    return PlaceDetails(
      label: props['full_address'] ?? props['name'] ?? suggestion.label,
      lng: (coords[0] as num).toDouble(),
      lat: (coords[1] as num).toDouble(),
    );
  }
}
