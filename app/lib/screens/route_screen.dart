import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/convoy.dart';
import '../services/connectivity_service.dart';
import '../services/places_service.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';
import '../widgets/place_autocomplete_field.dart';
import '../main.dart' show mapboxPublicToken;
import '../utils/external_maps.dart';
import 'edit_route_screen.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});
  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final _proposal = TextEditingController();
  final _places = PlacesService(mapboxPublicToken);
  PlaceDetails? _newDest;
  bool _sending = false;
  String? _sent;
  final Set<String> _resolving = {};

  @override
  void dispose() {
    _proposal.dispose();
    super.dispose();
  }

  Future<void> _sendProposal() async {
    if (_proposal.text.trim().isEmpty) return;
    if (!await ConnectivityService.instance.ensureConnected(context: context, action: 'submit route proposal')) return;

    setState(() => _sending = true);
    try {
      await context.read<ConvoyState>().proposeChange(
            _proposal.text.trim(),
            destLabel: _newDest?.label,
            destLat: _newDest?.lat,
            destLng: _newDest?.lng,
          );
      setState(() {
        _sent = _newDest != null
            ? 'Sent to host with suggested destination.'
            : 'Sent to host.';
        _proposal.clear();
        _newDest = null;
      });
    } catch (e) {
      setState(() => _sent = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _resolve(RouteProposal proposal, bool accept) async {
    if (!await ConnectivityService.instance.ensureConnected(context: context, action: accept ? 'accept proposal' : 'decline proposal')) return;

    setState(() => _resolving.add(proposal.id));
    try {
      await context.read<ConvoyState>().resolveProposal(proposal, accept: accept);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _resolving.remove(proposal.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ConvoyState>();
    final convoy = state.convoy!;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trip Route',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: ConvoyColors.paint,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text('Locked navigation path', style: TextStyle(color: ConvoyColors.muted, fontSize: 13)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ConvoyColors.signal.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ConvoyColors.signal.withAlpha(80)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 12, color: ConvoyColors.signal),
                    SizedBox(width: 4),
                    Text('LOCKED', style: TextStyle(color: ConvoyColors.signal, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Route Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ExternalMaps.showChooser(context, convoy),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open in Maps', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (state.isHost) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final changed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => const EditRouteScreen()),
                      );
                      if (changed == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Route updated for all convoy members!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                    label: const Text('Edit Route', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),

          // Route Stepper Card
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
                const Text(
                  'ITINERARY',
                  style: TextStyle(color: ConvoyColors.muted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.0),
                ),
                const SizedBox(height: 14),

                // Start
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: ConvoyColors.signal, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(convoy.startLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const Text('Starting Point', style: TextStyle(color: ConvoyColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),

                // Waypoints
                for (final w in convoy.waypoints) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                    child: Container(width: 2, height: 16, color: ConvoyColors.stroke),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: ConvoyColors.amber, borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(w.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            const Text('Stop along route', style: TextStyle(color: ConvoyColors.amber, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                // Stops
                for (final s in convoy.stops) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                    child: Container(width: 2, height: 16, color: ConvoyColors.stroke),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: ConvoyColors.muted, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                            Text('${(s.distanceAlongM / 1000).toStringAsFixed(0)} km along • ${s.kind}',
                                style: const TextStyle(color: ConvoyColors.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                // Destination
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                  child: Container(width: 2, height: 16, color: ConvoyColors.stroke),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: ConvoyColors.alert, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(convoy.destLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          Text(
                            convoy.routeDistanceM != null
                                ? '${(convoy.routeDistanceM! / 1000).toStringAsFixed(0)} km total distance'
                                : 'Destination',
                            style: const TextStyle(color: ConvoyColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Proposals Section
          if (state.isHost) ...[
            const Text(
              'ROUTE PROPOSALS',
              style: TextStyle(color: ConvoyColors.muted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.0),
            ),
            const SizedBox(height: 10),
            if (state.pendingProposals.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ConvoyColors.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ConvoyColors.stroke),
                ),
                child: const Text(
                  'No pending proposals from vehicles.',
                  style: TextStyle(color: ConvoyColors.muted, fontSize: 13),
                ),
              )
            else
              for (final p in state.pendingProposals)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ConvoyColors.panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ConvoyColors.amber.withAlpha(80)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.summary, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      if (p.destLabel != null) ...[
                        const SizedBox(height: 4),
                        Text('Suggested: ${p.destLabel}', style: const TextStyle(color: ConvoyColors.muted, fontSize: 12)),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _resolving.contains(p.id) ? null : () => _resolve(p, true),
                              child: Text(p.destLat != null ? 'Accept & Re-lock' : 'Accept', style: const TextStyle(fontSize: 12.5)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _resolving.contains(p.id) ? null : () => _resolve(p, false),
                              child: const Text('Decline', style: TextStyle(fontSize: 12.5)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ] else ...[
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
                  const Text('Suggest Route Change', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 3),
                  const Text('Your suggestion will be sent privately to the convoy host.', style: TextStyle(color: ConvoyColors.muted, fontSize: 12)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _proposal,
                    decoration: InputDecoration(
                      hintText: 'e.g. Stop for coffee before the pass',
                      fillColor: ConvoyColors.panel2,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ConvoyColors.stroke)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('NEW DESTINATION (OPTIONAL)', style: TextStyle(color: ConvoyColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  PlaceAutocompleteField(
                    places: _places,
                    hintText: 'Search alternative destination',
                    onPicked: (p) => setState(() => _newDest = p),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _sendProposal,
                      child: Text(_sending ? 'Sending Proposal…' : 'Submit Suggestion to Host'),
                    ),
                  ),
                  if (_sent != null) ...[
                    const SizedBox(height: 10),
                    Text(_sent!, style: const TextStyle(color: ConvoyColors.signal, fontSize: 12.5)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
