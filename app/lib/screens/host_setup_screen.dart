import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import '../models/convoy.dart';
import '../services/connectivity_service.dart';
import '../services/places_service.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/place_autocomplete_field.dart';
import '../main.dart' show mapboxPublicToken;
import 'map_screen.dart';

class _WaypointRow {
  final String id;
  PlaceDetails? place;
  _WaypointRow(this.id);
}

class HostSetupScreen extends StatefulWidget {
  const HostSetupScreen({super.key});
  @override
  State<HostSetupScreen> createState() => _HostSetupScreenState();
}

class _HostSetupScreenState extends State<HostSetupScreen> {
  final _tripName = TextEditingController(text: 'Weekend run');
  final _vehicleName = TextEditingController(text: 'My vehicle');
  final _places = PlacesService(mapboxPublicToken);

  PlaceDetails? _start;
  PlaceDetails? _dest;
  final List<_WaypointRow> _waypoints = [];
  int _waypointCounter = 0;

  List<RouteOption>? _options;
  int _selectedOption = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _tripName.dispose();
    _vehicleName.dispose();
    super.dispose();
  }

  void _addWaypoint() {
    setState(() => _waypoints.add(_WaypointRow('wp${_waypointCounter++}')));
  }

  void _removeWaypoint(String id) {
    setState(() => _waypoints.removeWhere((w) => w.id == id));
  }

  Future<void> _createAndFetchOptions() async {
    if (_start == null || _dest == null) {
      setState(() => _error = 'Please pick a starting point and destination from suggestions.');
      return;
    }
    final incompleteWaypoint = _waypoints.any((w) => w.place == null);
    if (incompleteWaypoint) {
      setState(() => _error = 'Please select a place for each stop, or remove unused stops.');
      return;
    }

    if (!await ConnectivityService.instance.ensureConnected(context: context, action: 'plan and host a convoy')) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final state = context.read<ConvoyState>();
    try {
      await state.hostConvoy(
        name: _tripName.text.trim(),
        startLabel: _start!.label,
        startLat: _start!.lat,
        startLng: _start!.lng,
        destLabel: _dest!.label,
        destLat: _dest!.lat,
        destLng: _dest!.lng,
        vehicleName: _vehicleName.text.trim(),
        passengers: 1,
        waypoints: _waypoints.map((w) => w.place!).toList(),
      );
      final options = await state.fetchRouteOptions();
      setState(() => _options = options);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndLock() async {
    if (_options == null) return;
    if (!await ConnectivityService.instance.ensureConnected(context: context, action: 'lock route')) return;
    setState(() => _busy = true);
    final state = context.read<ConvoyState>();
    try {
      await state.lockRoute(_options![_selectedOption], const []);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MapScreen()),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ConvoyState>();

    return Scaffold(
      backgroundColor: ConvoyColors.road,
      appBar: AppBar(
        title: const Text('Plan the Run', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
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
                // 1. Trip & Vehicle Information Panel
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
                      const Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 18, color: ConvoyColors.amber),
                          SizedBox(width: 8),
                          Text('Trip Details', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'TRIP NAME',
                        style: TextStyle(color: ConvoyColors.muted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _tripName,
                        decoration: InputDecoration(
                          hintText: 'e.g. Pacific Coast Run',
                          fillColor: ConvoyColors.panel2,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: ConvoyColors.stroke),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'YOUR VEHICLE NAME',
                        style: TextStyle(color: ConvoyColors.muted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _vehicleName,
                        decoration: InputDecoration(
                          hintText: 'e.g. Lead Audi or Lead Jeep',
                          prefixIcon: const Icon(Icons.directions_car_outlined, size: 18, color: ConvoyColors.muted),
                          fillColor: ConvoyColors.panel2,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: ConvoyColors.stroke),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Route Itinerary Panel
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
                      const Row(
                        children: [
                          Icon(Icons.alt_route_rounded, size: 18, color: ConvoyColors.amber),
                          SizedBox(width: 8),
                          Text('Route Itinerary', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Starting Point
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 14),
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: ConvoyColors.signal,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('START POINT', style: TextStyle(color: ConvoyColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                                const SizedBox(height: 6),
                                PlaceAutocompleteField(
                                  places: _places,
                                  hintText: 'Search start address or landmark',
                                  onPicked: (p) => setState(() => _start = p),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Intermediate Waypoints
                      for (var i = 0; i < _waypoints.length; i++) ...[
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 14),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: ConvoyColors.amber,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('STOP ${i + 1}', style: const TextStyle(color: ConvoyColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                                      InkWell(
                                        onTap: () => _removeWaypoint(_waypoints[i].id),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Text('Remove', style: TextStyle(color: ConvoyColors.alert, fontSize: 11, fontWeight: FontWeight.w600)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  PlaceAutocompleteField(
                                    key: ValueKey(_waypoints[i].id),
                                    places: _places,
                                    hintText: 'Search waypoint address or landmark',
                                    onPicked: (p) => setState(() => _waypoints[i].place = p),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Add Stop Button
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 22),
                        child: TextButton.icon(
                          onPressed: _waypoints.length >= 8 ? null : _addWaypoint,
                          icon: const Icon(Icons.add_rounded, size: 16, color: ConvoyColors.amber),
                          label: Text(
                            _waypoints.isEmpty ? '+ Add stop along route' : '+ Add another stop',
                            style: const TextStyle(color: ConvoyColors.amber, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Final Destination
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 14),
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: ConvoyColors.alert,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('FINAL DESTINATION', style: TextStyle(color: ConvoyColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                                const SizedBox(height: 6),
                                PlaceAutocompleteField(
                                  places: _places,
                                  hintText: 'Search final destination',
                                  onPicked: (p) => setState(() => _dest = p),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Convoy Code Banner (if active)
                if (state.convoy != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: ConvoyColors.amber.withAlpha(20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ConvoyColors.amber.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_2_rounded, color: ConvoyColors.amber, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('CONVOY TRIP CODE', style: TextStyle(color: ConvoyColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                              Text(
                                state.convoy!.code,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 4, color: ConvoyColors.amber),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 20, color: ConvoyColors.paint),
                          tooltip: 'Copy Code',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: state.convoy!.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Convoy code copied to clipboard')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 4. Route Alternatives or Fetch Button
                if (_options == null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _createAndFetchOptions,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_busy ? 'Calculating Routes…' : 'Find Routes'),
                          if (!_busy) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ],
                      ),
                    ),
                  )
                else ...[
                  const Text('SELECT ROUTE ALTERNATIVE', style: TextStyle(color: ConvoyColors.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  const SizedBox(height: 10),
                  ..._options!.asMap().entries.map((entry) {
                    final i = entry.key;
                    final opt = entry.value;
                    final selected = i == _selectedOption;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: selected ? ConvoyColors.amber.withAlpha(20) : ConvoyColors.panel,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => setState(() => _selectedOption = i),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected ? ConvoyColors.amber : ConvoyColors.stroke,
                                width: selected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(opt.summary, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${(opt.distanceM / 1000).toStringAsFixed(0)} km • ${(opt.durationS / 60).round()} min',
                                        style: const TextStyle(color: ConvoyColors.muted, fontSize: 12.5),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  const Icon(Icons.check_circle_rounded, color: ConvoyColors.amber, size: 22)
                                else
                                  Icon(Icons.radio_button_unchecked_rounded, color: ConvoyColors.muted.withAlpha(100), size: 22),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _confirmAndLock,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_busy ? 'Locking Route…' : 'Confirm & Lock Route'),
                          if (!_busy) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.lock_outline_rounded, size: 16),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
