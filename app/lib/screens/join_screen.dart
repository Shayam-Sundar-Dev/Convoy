import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';
import '../widgets/loading_overlay.dart';
import 'map_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});
  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _code = TextEditingController();
  final _vehicleName = TextEditingController(text: 'My vehicle');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _vehicleName.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _error = 'Please enter a valid convoy code.');
      return;
    }

    if (!await ConnectivityService.instance.ensureConnected(context: context, action: 'join the convoy')) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final state = context.read<ConvoyState>();
    try {
      await state.joinConvoy(code, vehicleName: _vehicleName.text.trim(), passengers: 1);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MapScreen()));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ConvoyColors.road,
      appBar: AppBar(
        title: const Text('Join Convoy', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: ConvoyColors.road,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _busy,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Icon Badge
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF64B5F6).withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFF64B5F6),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter Trip Code',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: ConvoyColors.paint,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ask the convoy host for the 6-character code on their screen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ConvoyColors.muted, fontSize: 13.5),
                ),
                const SizedBox(height: 28),

                // Card Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ConvoyColors.panel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: ConvoyColors.stroke),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CONVOY CODE',
                        style: TextStyle(
                          color: ConvoyColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        style: const TextStyle(
                          fontSize: 26,
                          letterSpacing: 8,
                          fontWeight: FontWeight.w800,
                          color: ConvoyColors.amber,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'K7R2M4',
                          hintStyle: TextStyle(
                            letterSpacing: 8,
                            color: ConvoyColors.muted.withAlpha(80),
                            fontSize: 24,
                          ),
                          fillColor: ConvoyColors.panel2,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ConvoyColors.stroke),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'YOUR VEHICLE NAME',
                        style: TextStyle(
                          color: ConvoyColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _vehicleName,
                        decoration: InputDecoration(
                          hintText: 'e.g. Blue Tacoma or Mini Cooper',
                          prefixIcon: const Icon(Icons.directions_car_outlined, size: 20, color: ConvoyColors.muted),
                          fillColor: ConvoyColors.panel2,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ConvoyColors.stroke),
                          ),
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
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: ConvoyColors.alert, fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _join,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_busy ? 'Connecting…' : 'Join Convoy'),
                              if (!_busy) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded, size: 16),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
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
