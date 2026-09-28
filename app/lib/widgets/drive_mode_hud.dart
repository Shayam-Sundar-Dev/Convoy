import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';
import '../services/screen_wakelock_service.dart';

/// A high-visibility, distraction-free in-car HUD designed for phone dash mounts.
/// Supports both portrait and landscape orientation with jumbo touch targets.
class DriveModeHUD extends StatefulWidget {
  final VoidCallback onExit;

  const DriveModeHUD({super.key, required this.onExit});

  @override
  State<DriveModeHUD> createState() => _DriveModeHUDState();
}

class _DriveModeHUDState extends State<DriveModeHUD> {
  @override
  void initState() {
    super.initState();
    ScreenWakelockService.enable();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ConvoyState>();
    final convoy = state.convoy;
    final myVehicle = state.myVehicle;
    final vehicles = state.vehicles;

    final myPos = myVehicle?.position ?? 1;
    final totalVehicles = vehicles.isNotEmpty ? vehicles.length : 1;
    final isLead = myVehicle?.isLead ?? (state.isHost);
    final gapM = myVehicle?.gapToLeadM ?? 0;
    final gapKm = (gapM / 1000).toStringAsFixed(1);

    Color gapColor;
    String gapStatusText;
    if (isLead) {
      gapColor = ConvoyColors.amber;
      gapStatusText = 'PACING THE CONVOY';
    } else if (gapM <= 1000) {
      gapColor = ConvoyColors.signal;
      gapStatusText = 'OPTIMAL CONVOY DISTANCE';
    } else if (gapM <= 3000) {
      gapColor = ConvoyColors.amber;
      gapStatusText = 'GAP IS STRETCHING';
    } else {
      gapColor = ConvoyColors.alert;
      gapStatusText = 'FALLING BEHIND LEAD';
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      color: const Color(0xFF0C0E12), // Deep road matte black
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(context, state, convoy?.name ?? 'Convoy', convoy?.code ?? '', myVehicle?.name ?? 'Car'),

              // Straggler Alert if present
              if (state.stragglerGapM != null && state.stragglerGapM! > 5000) ...[
                const SizedBox(height: 8),
                _buildStragglerAlert(state.stragglerGapM!),
              ],

              const SizedBox(height: 12),

              // Main Center Area (Responsive for Portrait vs Landscape)
              Expanded(
                child: isLandscape
                    ? Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: _buildMetricsCard(
                              isLead: isLead,
                              gapKm: gapKm,
                              gapStatusText: gapStatusText,
                              gapColor: gapColor,
                              myPos: myPos,
                              totalVehicles: totalVehicles,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 4,
                            child: _buildControlsColumn(state),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: _buildMetricsCard(
                              isLead: isLead,
                              gapKm: gapKm,
                              gapStatusText: gapStatusText,
                              gapColor: gapColor,
                              myPos: myPos,
                              totalVehicles: totalVehicles,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildControlsRow(state),
                        ],
                      ),
              ),

              // Active voice transmission banner
              if (state.activeTransmitterName != null) ...[
                const SizedBox(height: 10),
                _buildIncomingVoiceBanner(state.activeTransmitterName!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ConvoyState state, String convoyName, String code, String vehicleName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ConvoyColors.amber.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ConvoyColors.amber.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.speed_rounded, size: 16, color: ConvoyColors.amber),
                  const SizedBox(width: 6),
                  Text(
                    'DRIVE MODE',
                    style: const TextStyle(
                      color: ConvoyColors.amber,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              vehicleName,
              style: const TextStyle(
                color: ConvoyColors.paint,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
        Row(
          children: [
            // Screen keep awake indicator
            IconButton(
              icon: Icon(
                ScreenWakelockService.isEnabled ? Icons.screen_lock_portrait_rounded : Icons.screen_lock_rotation_rounded,
                color: ScreenWakelockService.isEnabled ? ConvoyColors.signal : ConvoyColors.muted,
                size: 20,
              ),
              tooltip: 'Keep screen awake',
              onPressed: () {
                setState(() => ScreenWakelockService.toggle());
              },
            ),
            const SizedBox(width: 4),
            // Exit Drive Mode Button
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onExit,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: ConvoyColors.panel,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ConvoyColors.stroke),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_rounded, size: 14, color: ConvoyColors.paint),
                    SizedBox(width: 6),
                    Text(
                      'Map View',
                      style: TextStyle(
                        color: ConvoyColors.paint,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStragglerAlert(double gapM) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ConvoyColors.alert.withAlpha(35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ConvoyColors.alert),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: ConvoyColors.alert),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'STRAGGLER ALERT: Car behind is ${(gapM / 1000).toStringAsFixed(1)} km back',
              style: const TextStyle(
                color: ConvoyColors.alert,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard({
    required bool isLead,
    required String gapKm,
    required String gapStatusText,
    required Color gapColor,
    required int myPos,
    required int totalVehicles,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ConvoyColors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: gapColor.withAlpha(80), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: gapColor.withAlpha(20),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Convoy position badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: ConvoyColors.panel2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ConvoyColors.stroke),
            ),
            child: Text(
              isLead ? '★ CONVOY LEAD VEHICLE' : 'CAR #$myPos OF $totalVehicles IN CONVOY',
              style: TextStyle(
                color: isLead ? ConvoyColors.amber : ConvoyColors.muted,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Huge Metric Readout
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  isLead ? 'LEAD' : gapKm,
                  style: TextStyle(
                    fontSize: isLead ? 68 : 88,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    color: isLead ? ConvoyColors.amber : gapColor,
                    height: 1.0,
                  ),
                ),
                if (!isLead) ...[
                  const SizedBox(width: 8),
                  const Text(
                    'KM',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: ConvoyColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Status label
          Text(
            gapStatusText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: gapColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildControlsRow(ConvoyState state) {
    return Row(
      children: [
        // Radio Mute / Unmute Button
        Expanded(
          flex: 3,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.lightImpact();
              state.toggleRadioMute();
            },
            child: Container(
              height: 84,
              decoration: BoxDecoration(
                color: state.isRadioMuted ? ConvoyColors.alert.withAlpha(25) : ConvoyColors.panel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: state.isRadioMuted ? ConvoyColors.alert : ConvoyColors.stroke,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    state.isRadioMuted ? Icons.volume_off_rounded : Icons.radio_rounded,
                    color: state.isRadioMuted ? ConvoyColors.alert : ConvoyColors.amber,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.isRadioMuted ? 'RADIO MUTED' : 'RADIO ON',
                    style: TextStyle(
                      color: state.isRadioMuted ? ConvoyColors.alert : ConvoyColors.paint,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Jumbo Push-To-Talk Button
        Expanded(
          flex: 7,
          child: _buildJumboPTTButton(state),
        ),
      ],
    );
  }

  Widget _buildControlsColumn(ConvoyState state) {
    return Column(
      children: [
        Expanded(
          child: _buildJumboPTTButton(state),
        ),
        const SizedBox(height: 14),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            state.toggleRadioMute();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: state.isRadioMuted ? ConvoyColors.alert.withAlpha(25) : ConvoyColors.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: state.isRadioMuted ? ConvoyColors.alert : ConvoyColors.stroke,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  state.isRadioMuted ? Icons.volume_off_rounded : Icons.radio_rounded,
                  color: state.isRadioMuted ? ConvoyColors.alert : ConvoyColors.amber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  state.isRadioMuted ? 'RADIO MUTED' : 'RADIO ACTIVE',
                  style: TextStyle(
                    color: state.isRadioMuted ? ConvoyColors.alert : ConvoyColors.paint,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJumboPTTButton(ConvoyState state) {
    final isTransmitting = state.isWalkieTalkieTransmitting;

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.heavyImpact();
        state.startPushToTalk();
      },
      onTapUp: (_) {
        HapticFeedback.mediumImpact();
        state.stopPushToTalk();
      },
      onTapCancel: () {
        state.cancelPushToTalk();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 84,
        decoration: BoxDecoration(
          color: isTransmitting ? ConvoyColors.amber : ConvoyColors.amber.withAlpha(35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ConvoyColors.amber,
            width: isTransmitting ? 3.0 : 1.5,
          ),
          boxShadow: isTransmitting
              ? [
                  BoxShadow(
                    color: ConvoyColors.amber.withAlpha(150),
                    blurRadius: 25,
                    spreadRadius: 4,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isTransmitting ? Icons.record_voice_over_rounded : Icons.mic_rounded,
              color: isTransmitting ? const Color(0xFF14110A) : ConvoyColors.amber,
              size: 36,
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTransmitting ? 'TRANSMITTING...' : 'PUSH TO TALK',
                  style: TextStyle(
                    color: isTransmitting ? const Color(0xFF14110A) : ConvoyColors.paint,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  isTransmitting ? 'Release to send' : 'Hold to speak to convoy',
                  style: TextStyle(
                    color: isTransmitting ? const Color(0xFF14110A).withAlpha(180) : ConvoyColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingVoiceBanner(String speakerName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: ConvoyColors.signal.withAlpha(25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ConvoyColors.signal.withAlpha(90)),
      ),
      child: Row(
        children: [
          const Icon(Icons.volume_up_rounded, color: ConvoyColors.signal, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'INCOMING RADIO: $speakerName is speaking...',
              style: const TextStyle(
                color: ConvoyColors.signal,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
