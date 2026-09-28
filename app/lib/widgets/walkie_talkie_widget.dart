import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';

/// Floating Walkie-Talkie widget designed for use while driving.
/// Can be docked on the MapScreen. Allows Push-to-Talk voice broadcast
/// to all convoy members, displays who is currently transmitting, and
/// provides a quick radio mute toggle.
class WalkieTalkieOverlay extends StatefulWidget {
  const WalkieTalkieOverlay({super.key});

  @override
  State<WalkieTalkieOverlay> createState() => _WalkieTalkieOverlayState();
}

class _WalkieTalkieOverlayState extends State<WalkieTalkieOverlay>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onPressStart() {
    HapticFeedback.heavyImpact();
    context.read<ConvoyState>().startPushToTalk();
  }

  void _onPressEnd() {
    HapticFeedback.mediumImpact();
    context.read<ConvoyState>().stopPushToTalk();
  }

  void _onPressCancel() {
    context.read<ConvoyState>().cancelPushToTalk();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ConvoyState>();
    final isTransmitting = state.isWalkieTalkieTransmitting;
    final activeSpeaker = state.activeTransmitterName;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Incoming Transmission Alert Banner ──────────────────────────────
        if (activeSpeaker != null)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: ConvoyColors.signal.withValues(
                  alpha: 0.2 + (_pulseController.value * 0.15),
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: ConvoyColors.signal,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ConvoyColors.signal.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.radio, size: 20, color: ConvoyColors.signal),
                  const SizedBox(width: 8),
                  Text(
                    '📻 $activeSpeaker transmitting…',
                    style: const TextStyle(
                      color: ConvoyColors.paint,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Main Walkie-Talkie Control Panel ────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: ConvoyColors.panel2.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isTransmitting
                  ? ConvoyColors.signal
                  : ConvoyColors.stroke,
              width: isTransmitting ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: _expanded
              ? _buildExpandedPanel(context, state, isTransmitting)
              : _buildCompactBar(context, state, isTransmitting),
        ),
      ],
    );
  }

  Widget _buildCompactBar(
      BuildContext context, ConvoyState state, bool isTransmitting) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              state.isRadioMuted ? Icons.volume_off : Icons.volume_up,
              size: 20,
              color: state.isRadioMuted ? ConvoyColors.alert : ConvoyColors.muted,
            ),
            tooltip: state.isRadioMuted ? 'Unmute radio' : 'Mute radio',
            onPressed: () => state.toggleRadioMute(),
          ),
          const SizedBox(width: 4),

          // PTT Button
          GestureDetector(
            onLongPressStart: (_) => _onPressStart(),
            onLongPressEnd: (_) => _onPressEnd(),
            onLongPressCancel: _onPressCancel,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isTransmitting ? ConvoyColors.signal : ConvoyColors.amber,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isTransmitting
                    ? [
                        BoxShadow(
                          color: ConvoyColors.signal.withValues(alpha: 0.5),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isTransmitting ? Icons.record_voice_over : Icons.mic,
                    size: 18,
                    color: const Color(0xFF14110A),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isTransmitting ? 'TRANSMITTING…' : 'HOLD TO TALK',
                    style: const TextStyle(
                      color: Color(0xFF14110A),
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.expand_less, size: 20, color: ConvoyColors.muted),
            tooltip: 'Expand controls',
            onPressed: () => setState(() => _expanded = true),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedPanel(
      BuildContext context, ConvoyState state, bool isTransmitting) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.radio, size: 18, color: ConvoyColors.amber),
                  SizedBox(width: 8),
                  Text(
                    'Walkie-Talkie',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      state.isRadioMuted ? Icons.volume_off : Icons.volume_up,
                      size: 20,
                      color: state.isRadioMuted
                          ? ConvoyColors.alert
                          : ConvoyColors.muted,
                    ),
                    onPressed: () => state.toggleRadioMute(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: ConvoyColors.muted),
                    onPressed: () => setState(() => _expanded = false),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Big PTT Circle Button
          GestureDetector(
            onLongPressStart: (_) => _onPressStart(),
            onLongPressEnd: (_) => _onPressEnd(),
            onLongPressCancel: _onPressCancel,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isTransmitting ? ConvoyColors.signal : ConvoyColors.amber,
                boxShadow: [
                  BoxShadow(
                    color: (isTransmitting ? ConvoyColors.signal : ConvoyColors.amber)
                        .withValues(alpha: isTransmitting ? 0.6 : 0.25),
                    blurRadius: isTransmitting ? 24 : 12,
                    spreadRadius: isTransmitting ? 4 : 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isTransmitting ? Icons.record_voice_over : Icons.mic,
                    size: 34,
                    color: const Color(0xFF14110A),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isTransmitting ? 'SPEAKING' : 'PUSH',
                    style: const TextStyle(
                      color: Color(0xFF14110A),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            isTransmitting
                ? 'Broadcasting live to all convoy cars…'
                : 'Press & hold button to talk to the convoy',
            style: TextStyle(
              color: isTransmitting ? ConvoyColors.signal : ConvoyColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

