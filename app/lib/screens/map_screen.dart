import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:provider/provider.dart';
import '../models/convoy.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';
import '../utils/route_geo.dart';
import '../utils/marker_icons.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/walkie_talkie_widget.dart';
import '../widgets/vehicle_dialog.dart';
import '../widgets/drive_mode_hud.dart';
import 'roster_screen.dart';
import 'pings_screen.dart';
import 'route_screen.dart';
import 'expenses_screen.dart';
import '../widgets/convoy_dialog.dart';

/// Live map: shows the locked route, every vehicle's current position, and
/// highlights the stretch of road between the lead car and the last car.
/// Lead/gap *numbers* are computed server-side (server/src/utils/geo.js)
/// and arrive over the socket already ranked; this screen re-derives which
/// stretch of the polyline that corresponds to (route_geo.dart) purely for
/// drawing, and renders vehicles as labelled pins via a generated bitmap
/// (marker_icons.dart), since Mapbox's annotation API takes image bytes
/// rather than a built-in "colored dot with a letter" marker type.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const double _stragglerThresholdM = 7000;

  int _tab = 0;
  MapboxMap? _map;
  PointAnnotationManager? _vehiclePoints;
  PointAnnotationManager? _currentLocationPoints;
  PolylineAnnotationManager? _routeLine;
  PolylineAnnotationManager? _gapLine;

  List<Position> _routePoints = [];
  List<double> _routeCumulative = [];
  bool _cameraFitted = false;
  bool _busy = false;
  bool _isDriveMode = false;

  // Tracks whether we've already shown the "convoy ended" dialog so we don't
  // show it more than once per session.
  bool _endedDialogShown = false;

  // Marker bitmaps are expensive to regenerate every frame, so cache by a
  // key that captures everything that affects how the marker looks.
  final Map<String, Uint8List> _iconCache = {};
  Uint8List? _currentLocationIcon;
  double? _lastDrawnCurrentLat;
  double? _lastDrawnCurrentLng;
  String? _currentPolyline;

  @override
  void initState() {
    super.initState();
    final state = context.read<ConvoyState>();
    state.goLive();
    if (state.currentLat == null || state.currentLng == null) {
      state.location.getLastKnownPosition().then((pos) {
        if (pos != null && mounted) {
          state.currentLat = pos.latitude;
          state.currentLng = pos.longitude;
          _drawCurrentLocation(pos.latitude, pos.longitude);
        }
      });
    }
    if (state.convoy?.routePolyline != null) {
      _currentPolyline = state.convoy!.routePolyline;
      _decodeRoute(_currentPolyline!);
    }
  }

  void _decodeRoute(String encoded) {
    final points = PolylinePoints().decodePolyline(encoded);
    _routePoints = points.map((p) => Position(p.longitude, p.latitude)).toList();
    _routeCumulative = buildCumulativeDistances(_routePoints);
    _drawRoute();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    _routeLine = await map.annotations.createPolylineAnnotationManager();
    _gapLine = await map.annotations.createPolylineAnnotationManager();
    _vehiclePoints = await map.annotations.createPointAnnotationManager();
    _currentLocationPoints = await map.annotations.createPointAnnotationManager();

    await _drawRoute();
    final state = context.read<ConvoyState>();
    final members = state.members;
    final vehicles = state.vehicles;
    await _drawGapSegment(members);
    await _drawVehicles(vehicles);
    await _drawCurrentLocation(state.currentLat, state.currentLng);

    await map.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
      ),
    );
  }

  Future<void> _drawRoute() async {
    final line = _routeLine;
    if (line == null || _routePoints.isEmpty) return;

    await line.deleteAll();
    await line.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: _routePoints),
        lineColor: ConvoyColors.muted.value,
        lineWidth: 4,
      ),
    );

    if (!_cameraFitted && _map != null) {
      _cameraFitted = true;
      _map!.setCamera(
        CameraOptions(center: Point(coordinates: _routePoints.first), zoom: 11),
      );
    }
  }

  /// Redraws the amber sub-segment between the last car and the lead car.
  Future<void> _drawGapSegment(List members) async {
    final gapLine = _gapLine;
    if (gapLine == null || _routePoints.length < 2) return;

    await gapLine.deleteAll();

    final withDist = members.where((m) => m.distanceAlongM != null).toList();
    if (withDist.length < 2) return;

    final sorted = withDist..sort((a, b) => (b.distanceAlongM as double).compareTo(a.distanceAlongM as double));
    final leadM = sorted.first.distanceAlongM as double;
    final lastM = sorted.last.distanceAlongM as double;
    if (leadM - lastM < 1) return;

    final segment = sliceRouteByDistance(_routePoints, _routeCumulative, lastM, leadM);
    if (segment.length < 2) return;

    await gapLine.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: segment),
        lineColor: ConvoyColors.amber.value,
        lineWidth: 5,
      ),
    );
  }

  Future<Uint8List> _iconForVehicle(ConvoyVehicle vehicle) async {
    final stale = vehicle.isStale;
    final key = '${vehicle.name}-${vehicle.isLead}-$stale-${vehicle.passengerCount}';
    final cached = _iconCache[key];
    if (cached != null) return cached;

    final isLead = vehicle.isLead && !stale;
    final bytes = await buildVehicleCarMarker(
      vehicleName: vehicle.name,
      passengerCount: vehicle.passengerCount,
      isLead: isLead,
      isStale: stale,
    );
    _iconCache[key] = bytes;
    return bytes;
  }

  Future<void> _drawVehicles(List<ConvoyVehicle> vehicles) async {
    final manager = _vehiclePoints;
    if (manager == null) return;

    await manager.deleteAll();
    final withFix = vehicles.where((v) => v.lastLat != null && v.lastLng != null).toList();
    if (withFix.isEmpty) return;

    final options = <PointAnnotationOptions>[];
    for (final v in withFix) {
      options.add(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(v.lastLng!, v.lastLat!)),
          image: await _iconForVehicle(v),
          iconSize: v.isLead ? 1.0 : 0.88,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
    }
    await manager.createMulti(options);
  }

  /// Draws the user's live GPS current location marker (glowing pulse puck).
  Future<void> _drawCurrentLocation(double? lat, double? lng) async {
    final manager = _currentLocationPoints;
    if (manager == null) return;

    if (lat == null || lng == null) {
      if (_lastDrawnCurrentLat != null || _lastDrawnCurrentLng != null) {
        await manager.deleteAll();
        _lastDrawnCurrentLat = null;
        _lastDrawnCurrentLng = null;
      }
      return;
    }

    if (_lastDrawnCurrentLat == lat && _lastDrawnCurrentLng == lng) {
      return;
    }

    _lastDrawnCurrentLat = lat;
    _lastDrawnCurrentLng = lng;

    await manager.deleteAll();
    _currentLocationIcon ??= await buildCurrentLocationMarker();

    await manager.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(lng, lat)),
        image: _currentLocationIcon!,
        iconSize: 0.85,
        iconAnchor: IconAnchor.CENTER,
      ),
    );
  }

  // ──────────────────────── exit helpers ────────────────────────

  Future<void> _confirmEnd(BuildContext context) async {
    final confirmed = await ConvoyConfirmDialog.show(
      context,
      icon: Icons.power_settings_new_rounded,
      title: 'End the convoy?',
      message: 'This will end the trip for everyone in the convoy.',
      confirmLabel: 'End Convoy',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<ConvoyState>().endConvoy();
      if (!mounted) return;
      // popUntil keeps RoleSelectScreen (the home/first route) and pops
      // MapScreen off it. pushAndRemoveUntil was wrong — it removed every
      // route including home, leaving the placeholder with nothing to pop to.
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final confirmed = await ConvoyConfirmDialog.show(
      context,
      icon: Icons.exit_to_app_rounded,
      title: 'Leave the convoy?',
      message: 'You\'ll be disconnected. You can rejoin with the same code.',
      confirmLabel: 'Leave',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      context.read<ConvoyState>().leaveConvoy();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showConvoyEndedDialog(BuildContext context) {
    if (_endedDialogShown) return;
    _endedDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: ConvoyColors.panel2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: ConvoyColors.stroke, width: 1),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          titlePadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ConvoyColors.amber.withAlpha(24),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ConvoyColors.amber.withAlpha(45)),
                    ),
                    child: const Icon(Icons.flag_rounded, color: ConvoyColors.amber, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Convoy Ended',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: ConvoyColors.paint,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'The host has ended this convoy. Thanks for riding!',
                style: TextStyle(color: ConvoyColors.muted, fontSize: 13.5, height: 1.45),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ConvoyColors.amber,
                foregroundColor: const Color(0xFF14110A),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    // stopLive() is NOT called here — it is called explicitly by endConvoy()
    // / leaveConvoy() / onConvoyEnded so that navigating between tabs or
    // returning to this screen via back-stack never kills the live session.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ConvoyState>();
    final convoy = state.convoy;
    if (convoy == null) {
      // During an explicit exit (_busy=true) endConvoy() clears convoy before
      // navigation — let the LoadingOverlay handle that frame instead of
      // replacing it with a bare spinner that would get stuck.
      if (_busy) return const Scaffold(body: SizedBox.shrink());
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Show ended dialog for clients when the host ends the convoy.
    if (state.convoyEnded && !state.isHost) {
      _showConvoyEndedDialog(context);
    }

    if (convoy.routePolyline != null && convoy.routePolyline != _currentPolyline) {
      _currentPolyline = convoy.routePolyline;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentPolyline != null) {
          _decodeRoute(_currentPolyline!);
        }
      });
    }

    final members = state.members.isNotEmpty ? state.members : convoy.members;
    final vehicles = state.vehicles;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drawVehicles(vehicles);
      _drawGapSegment(members);
      _drawCurrentLocation(state.currentLat, state.currentLng);
    });

    final lead = members.isNotEmpty ? members.firstWhere((m) => m.isLead, orElse: () => members.first) : null;
    final last = members.isNotEmpty ? members.last : null;
    final gapM = last?.gapToLeadM ?? 0;

    final pages = [
      _buildMapPage(context, state, members, lead, gapM, convoy),
      const RosterScreen(),
      const PingsScreen(),
      const RouteScreen(),
      const ExpensesScreen(isTab: true),
    ];

    return PopScope(
      // Back gesture / hardware back button must NOT exit the trip.
      canPop: false,
      child: LoadingOverlay(
        isLoading: _busy,
        child: Scaffold(
          backgroundColor: ConvoyColors.road,
          appBar: AppBar(
            automaticallyImplyLeading: false, // no back arrow
            backgroundColor: ConvoyColors.road,
            elevation: 0,
            title: Text(
              convoy.name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            actions: [
              if (state.isHost)
                IconButton(
                  icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                  tooltip: 'Show convoy code',
                  onPressed: () => _showCodeDialog(context, convoy.code),
                ),
              IconButton(
                icon: Icon(
                  state.isRadioMuted ? Icons.volume_off_rounded : Icons.radio_rounded,
                  color: state.isRadioMuted ? ConvoyColors.alert : ConvoyColors.amber,
                  size: 20,
                ),
                tooltip: state.isRadioMuted ? 'Radio muted' : 'Radio active',
                onPressed: () => state.toggleRadioMute(),
              ),
              if (!state.isConnected)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ConvoyColors.alert.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('OFFLINE', style: TextStyle(color: ConvoyColors.alert, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                ),
              // Exit button — host ends the convoy, client leaves.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: state.isHost ? ConvoyColors.alert : ConvoyColors.muted,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: (state.isHost ? ConvoyColors.alert : ConvoyColors.muted).withAlpha(50),
                      ),
                    ),
                  ),
                  onPressed: _busy ? null : () => state.isHost ? _confirmEnd(context) : _confirmLeave(context),
                  child: Text(
                    state.isHost ? 'End' : 'Leave',
                    style: TextStyle(
                      color: state.isHost ? ConvoyColors.alert : ConvoyColors.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: pages[_tab],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            backgroundColor: ConvoyColors.road,
            indicatorColor: ConvoyColors.amber.withAlpha(35),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded, color: ConvoyColors.amber), label: 'Map'),
              NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car_rounded, color: ConvoyColors.amber), label: 'Convoy'),
              NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded, color: ConvoyColors.amber), label: 'Pings'),
              NavigationDestination(icon: Icon(Icons.alt_route_rounded), selectedIcon: Icon(Icons.alt_route_rounded, color: ConvoyColors.amber), label: 'Route'),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded, color: ConvoyColors.amber), label: 'Expenses'),
            ],
          ),
        ),
      ),
    );
  }

  void _showCodeDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ConvoyColors.panel2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ConvoyColors.stroke, width: 1),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 14, 0),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: ConvoyColors.amber.withAlpha(24),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ConvoyColors.amber.withAlpha(45)),
              ),
              child: const Icon(Icons.pin_rounded, color: ConvoyColors.amber, size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Convoy Code',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: ConvoyColors.paint,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.close_rounded, size: 20, color: ConvoyColors.muted),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: ConvoyColors.panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ConvoyColors.stroke),
              ),
              child: Center(
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: ConvoyColors.amber,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Share this 6-character code with drivers joining your convoy.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ConvoyColors.muted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: ConvoyColors.muted,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ConvoyColors.amber,
              foregroundColor: const Color(0xFF14110A),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Convoy code copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPage(BuildContext context, ConvoyState state, List members, dynamic lead, double gapM, convoy) {
    if (_isDriveMode) {
      return DriveModeHUD(onExit: () => setState(() => _isDriveMode = false));
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              _routePoints.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Waiting for the route to load…',
                          style: TextStyle(color: ConvoyColors.muted),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : MapWidget(
                      key: const ValueKey('convoy-map'),
                      styleUri: MapboxStyles.DARK,
                      cameraOptions: CameraOptions(center: Point(coordinates: _routePoints.first), zoom: 11),
                      onMapCreated: _onMapCreated,
                    ),

              // Floating Walkie-Talkie on the Map
              const Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Center(
                  child: WalkieTalkieOverlay(),
                ),
              ),

              // Floating Vehicle Switch / Group Bar (Top Left)
              Positioned(
                top: 16,
                left: 16,
                child: GestureDetector(
                  onTap: () => VehicleSwitchDialog.show(context, state),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: ConvoyColors.panel.withAlpha(235),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: ConvoyColors.stroke),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(120),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_car_rounded, size: 16, color: ConvoyColors.amber),
                        const SizedBox(width: 7),
                        Text(
                          state.myVehicle != null
                              ? state.myVehicle!.name
                              : '${state.vehicles.length} Car${state.vehicles.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: ConvoyColors.paint,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ConvoyColors.amber.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${state.myVehicle?.passengerCount ?? members.length} pax',
                            style: const TextStyle(
                              color: ConvoyColors.amber,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.swap_horiz_rounded, size: 15, color: ConvoyColors.muted),
                      ],
                    ),
                  ),
                ),
              ),

              // Floating Map Controls: Drive Mode, Current GPS location & Fit Route
              Positioned(
                top: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFloatingMapButton(
                      icon: Icons.speed_rounded,
                      tooltip: 'In-Car Drive Mode HUD',
                      color: ConvoyColors.amber,
                      onTap: () => setState(() => _isDriveMode = true),
                    ),
                    const SizedBox(height: 8),
                    _buildFloatingMapButton(
                      icon: Icons.my_location_rounded,
                      tooltip: 'My GPS location',
                      color: ConvoyColors.amber,
                      onTap: _recenterToGps,
                    ),
                    const SizedBox(height: 8),
                    _buildFloatingMapButton(
                      icon: Icons.route_rounded,
                      tooltip: 'Fit entire route',
                      color: ConvoyColors.paint,
                      onTap: _fitRoute,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!state.isConnected)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: ConvoyColors.muted.withAlpha(20),
              border: Border.all(color: ConvoyColors.stroke),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              "You're offline — showing last known positions.",
              style: TextStyle(color: ConvoyColors.muted, fontSize: 12.5),
            ),
          ),
        if (state.stragglerGapM != null && state.stragglerGapM! > _stragglerThresholdM)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: ConvoyColors.alert.withAlpha(25),
              border: Border.all(color: ConvoyColors.alert.withAlpha(70)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: ConvoyColors.alert),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A car is falling behind — ${(state.stragglerGapM! / 1000).toStringAsFixed(1)} km back.',
                    style: const TextStyle(color: ConvoyColors.alert, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              _gapStat('${(gapM / 1000).toStringAsFixed(1)}', 'KM LEAD GAP'),
              _gapStat('${(gapM / 900).round().clamp(0, 999)}', 'MIN APART'),
              _gapStat(
                lead != null && lead.distanceAlongM != null
                    ? (lead.distanceAlongM / 1000).round().toString()
                    : '—',
                'OF ${convoy.routeDistanceM != null ? (convoy.routeDistanceM! / 1000).round() : "?"} KM',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gapStat(String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: ConvoyColors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ConvoyColors.stroke),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ConvoyColors.paint)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: ConvoyColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
          ],
        ),
      ),
    );
  }

  Future<void> _recenterToGps() async {
    final state = context.read<ConvoyState>();
    double? lat = state.currentLat;
    double? lng = state.currentLng;

    if (lat == null || lng == null) {
      final pos = await state.location.getCurrentPosition();
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
        state.currentLat = lat;
        state.currentLng = lng;
      }
    }

    if (lat != null && lng != null && _map != null) {
      await _drawCurrentLocation(lat, lng);
      _map!.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          zoom: 15.0,
        ),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acquiring live GPS location…')),
        );
      }
    }
  }

  void _fitRoute() {
    if (_routePoints.isNotEmpty && _map != null) {
      _map!.setCamera(
        CameraOptions(
          center: Point(coordinates: _routePoints.first),
          zoom: 11.0,
        ),
      );
    }
  }

  Widget _buildFloatingMapButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: ConvoyColors.panel,
        borderRadius: BorderRadius.circular(12),
        elevation: 4,
        shadowColor: Colors.black.withAlpha(120),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ConvoyColors.stroke),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}
