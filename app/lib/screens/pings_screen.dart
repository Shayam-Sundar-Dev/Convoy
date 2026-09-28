import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';

class PingsScreen extends StatefulWidget {
  const PingsScreen({super.key});
  @override
  State<PingsScreen> createState() => _PingsScreenState();
}

class _PingsScreenState extends State<PingsScreen> {
  final _message = TextEditingController();

  static const _quicks = [
    {'label': 'All good', 'icon': Icons.thumb_up_alt_outlined},
    {'label': 'Need fuel', 'icon': Icons.local_gas_station_outlined},
    {'label': 'Pulling over', 'icon': Icons.warning_amber_rounded},
    {'label': 'Falling behind', 'icon': Icons.speed_rounded},
    {'label': 'Regroup here', 'icon': Icons.group_outlined},
    {'label': 'Emergency', 'icon': Icons.emergency_outlined},
  ];

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _sendCurrentText() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    if (!await ConnectivityService.instance.ensureConnected(context: context, action: 'send a ping')) return;
    if (!mounted) return;
    context.read<ConvoyState>().sendPing(text);
    _message.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ConvoyState>();

    return SafeArea(
      child: Column(
        children: [
          // Header & Quick Pings
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pings & Alerts',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: ConvoyColors.paint,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '${state.messages.length} message${state.messages.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: ConvoyColors.muted, fontSize: 12.5),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quicks.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final q = _quicks[i];
                      final label = q['label'] as String;
                      final icon = q['icon'] as IconData;
                      final isEmergency = label == 'Emergency';

                      return InkWell(
                        onTap: () async {
                          if (!await ConnectivityService.instance.ensureConnected(context: context, action: 'send an alert')) return;
                          state.sendPing(label, kind: 'quick_ping');
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: isEmergency ? ConvoyColors.alert.withAlpha(25) : ConvoyColors.panel,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isEmergency ? ConvoyColors.alert.withAlpha(80) : ConvoyColors.stroke,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 14,
                                color: isEmergency ? ConvoyColors.alert : ConvoyColors.amber,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                label,
                                style: TextStyle(
                                  color: isEmergency ? ConvoyColors.alert : ConvoyColors.paint,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: ConvoyColors.stroke),

          // Message Stream
          Expanded(
            child: state.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 38, color: ConvoyColors.muted.withAlpha(100)),
                        const SizedBox(height: 10),
                        const Text(
                          'No pings sent yet.',
                          style: TextStyle(color: ConvoyColors.muted, fontSize: 13.5),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap a quick ping above or send a message below.',
                          style: TextStyle(color: ConvoyColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    itemCount: state.messages.length,
                    itemBuilder: (context, i) {
                      final m = state.messages[i];
                      final isMe = m.userName == state.userName;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? ConvoyColors.amber.withAlpha(35) : ConvoyColors.panel,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMe ? 16 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 16),
                              ),
                              border: Border.all(
                                color: isMe ? ConvoyColors.amber.withAlpha(70) : ConvoyColors.stroke,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text(
                                      m.userName,
                                      style: const TextStyle(
                                        color: ConvoyColors.amber,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                Text(
                                  m.body,
                                  style: const TextStyle(fontSize: 13.5, color: ConvoyColors.paint),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
              color: ConvoyColors.road,
              border: Border(top: BorderSide(color: ConvoyColors.stroke)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _message,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Message everyone in convoy…',
                      fillColor: ConvoyColors.panel,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: ConvoyColors.stroke),
                      ),
                    ),
                    onSubmitted: (_) => _sendCurrentText(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: ConvoyColors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF14110A), size: 22),
                    onPressed: _sendCurrentText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
