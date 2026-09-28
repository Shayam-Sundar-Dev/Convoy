import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/places_service.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/place_autocomplete_field.dart';
import '../main.dart' show mapboxPublicToken;

class _WaypointItem {
  final String id;
  PlaceDetails? place;
  _WaypointItem(this.id, {this.place});
}

class EditRouteScreen extends StatefulWidget {
  const EditRouteScreen({super.key});

  @override
  State<EditRouteScreen> createState() => _EditRouteScreenState();
}

class _EditRouteScreenState extends State<EditRouteScreen> {
  final _places = PlacesService(mapboxPublicToken);
  PlaceDetails? _destination;
  final List<_WaypointItem> _waypoints = [];
  int _counter = 0;
  bool _busy = false;
  String? _error;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final convoy = context.read<ConvoyState>().convoy;
      if (convoy != null) {
        _destination = PlaceDetails(
          label: convoy.destLabel,
          lat: convoy.destLat,
          lng: convoy.destLng,
        );
        for (final w in convoy.waypoints) {
          _waypoints.add(
            _WaypointItem(
              'wp_${_counter++}',
              place: PlaceDetails(label: w.label, lat: w.lat, lng: w.lng),
            ),
          );
        }
      }
    }
  }

  void _addWaypoint() {
    if (_waypoints.length >= 8) return;
    setState(() {
      _waypoints.add(_WaypointItem('wp_${_counter++}'));
    });
  }

  void _removeWaypoint(String id) {
    setState(() {
      _waypoints.removeWhere((w) => w.id == id);
    });
  }

  Future<void> _applyNewRoute() async {
    if (_destination == null) {
      setState(() => _error = 'Please set a destination.');
      return;
    }
    final missingPlace = _waypoints.any((w) => w.place == null);
    if (missingPlace) {
      setState(() => _error = 'Please choose a place for all stops or remove empty ones.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final state = context.read<ConvoyState>();
      final waypointPlaces = _waypoints.map((w) => w.place!).toList();
      await state.updateActiveRoute(
        destLabel: _destination!.label,
        destLat: _destination!.lat,
        destLng: _destination!.lng,
        waypoints: waypointPlaces,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ConvoyState>();
    final convoy = state.convoy;

    if (convoy == null) {
      return const Scaffold(body: Center(child: Text('No active convoy')));
    }

    return Scaffold(
      backgroundColor: ConvoyColors.road,
      appBar: AppBar(
        title: const Text('Edit Trip Route', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: ConvoyColors.road,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _busy,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info notice
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ConvoyColors.amber.withAlpha(20),
                    border: Border.all(color: ConvoyColors.amber.withAlpha(70)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: ConvoyColors.amber),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Updating recalculates the route live for all vehicles in this convoy.',
                          style: TextStyle(color: ConvoyColors.paint, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Start Location container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ConvoyColors.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ConvoyColors.stroke),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('START LOCATION (FIXED)', style: TextStyle(color: ConvoyColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.my_location_rounded, size: 18, color: ConvoyColors.signal),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              convoy.startLabel,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Stops & Destination container
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: ConvoyColors.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ConvoyColors.stroke),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('INTERMEDIATE STOPS', style: TextStyle(color: ConvoyColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                          if (_waypoints.length < 8)
                            TextButton.icon(
                              onPressed: _addWaypoint,
                              icon: const Icon(Icons.add_rounded, size: 16, color: ConvoyColors.amber),
                              label: const Text('Add stop', style: TextStyle(color: ConvoyColors.amber, fontSize: 12)),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_waypoints.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('No intermediate stops added.', style: TextStyle(color: ConvoyColors.muted, fontSize: 12.5)),
                        ),
                      for (int i = 0; i < _waypoints.length; i++) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: PlaceAutocompleteField(
                                  key: ValueKey(_waypoints[i].id),
                                  places: _places,
                                  initialText: _waypoints[i].place?.label ?? '',
                                  hintText: 'Stop ${i + 1}',
                                  onPicked: (p) => setState(() => _waypoints[i].place = p),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: ConvoyColors.alert),
                                tooltip: 'Remove stop',
                                onPressed: () => _removeWaypoint(_waypoints[i].id),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      const Text('FINAL DESTINATION', style: TextStyle(color: ConvoyColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                      const SizedBox(height: 6),
                      PlaceAutocompleteField(
                        places: _places,
                        initialText: _destination?.label ?? '',
                        hintText: 'Search new destination',
                        onPicked: (p) => setState(() => _destination = p),
                      ),
                    ],
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ConvoyColors.alert.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ConvoyColors.alert.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 16, color: ConvoyColors.alert),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: ConvoyColors.alert, fontSize: 12.5))),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _applyNewRoute,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_busy ? 'Recalculating Route…' : 'Apply & Re-lock Route'),
                        if (!_busy) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_rounded, size: 18),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
