import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/convoy.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';
import '../widgets/vehicle_dialog.dart';

class RosterScreen extends StatelessWidget {
  const RosterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ConvoyState>();
    final vehicles = state.vehicles;
    final members = state.members.isNotEmpty ? state.members : (state.convoy?.members ?? []);
    final currentUserId = state.userId;
    final currentUserName = state.userName;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Convoy Order',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: ConvoyColors.paint,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${vehicles.length} vehicle${vehicles.length == 1 ? '' : 's'} • ${members.length} people in sync',
                    style: const TextStyle(color: ConvoyColors.muted, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => VehicleSwitchDialog.show(context, state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: ConvoyColors.amber.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ConvoyColors.amber.withAlpha(80)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_road_rounded, size: 13, color: ConvoyColors.amber),
                          SizedBox(width: 4),
                          Text(
                            'My Car',
                            style: TextStyle(
                              color: ConvoyColors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ConvoyColors.signal.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ConvoyColors.signal.withAlpha(80)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sensors_rounded, size: 13, color: ConvoyColors.signal),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: ConvoyColors.signal,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (vehicles.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: ConvoyColors.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ConvoyColors.stroke),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.directions_car_outlined, size: 36, color: ConvoyColors.muted),
                    SizedBox(height: 12),
                    Text(
                      'No vehicles connected yet.',
                      style: TextStyle(color: ConvoyColors.muted, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vehicles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final v = vehicles[i];
                final isLead = v.isLead;
                final isMyVehicle = v.containsUser(currentUserId) ||
                    v.passengerNames.any((n) => n.toLowerCase() == currentUserName?.toLowerCase());

                return Container(
                  decoration: BoxDecoration(
                    color: ConvoyColors.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isMyVehicle ? ConvoyColors.amber.withAlpha(120) : ConvoyColors.stroke,
                      width: isMyVehicle ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header Row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        child: Row(
                          children: [
                            // Position Pill
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isLead ? ConvoyColors.amber : ConvoyColors.panel2,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isLead ? ConvoyColors.amber : ConvoyColors.stroke,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${v.position ?? (i + 1)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isLead ? const Color(0xFF14110A) : ConvoyColors.paint,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Vehicle Name & Meta
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.directions_car_rounded,
                                        size: 16,
                                        color: isLead ? ConvoyColors.amber : ConvoyColors.paint,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          v.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: ConvoyColors.paint,
                                            letterSpacing: -0.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isMyVehicle) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: ConvoyColors.amber.withAlpha(25),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: ConvoyColors.amber.withAlpha(60)),
                                          ),
                                          child: const Text(
                                            'YOUR CAR',
                                            style: TextStyle(
                                              color: ConvoyColors.amber,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Text(
                                        '${v.passengerCount} passenger${v.passengerCount == 1 ? '' : 's'}',
                                        style: const TextStyle(color: ConvoyColors.muted, fontSize: 12),
                                      ),
                                      if (v.isStale) ...[
                                        const Text(' • ', style: TextStyle(color: ConvoyColors.muted, fontSize: 12)),
                                        Text(
                                          'Last seen ${v.lastSeenLabel}',
                                          style: const TextStyle(color: ConvoyColors.alert, fontSize: 11),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Status Tag
                            _vehicleStatusTag(v),
                          ],
                        ),
                      ),

                      const Divider(height: 1, color: ConvoyColors.stroke),

                      // People in this Vehicle List
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        color: ConvoyColors.panel2.withAlpha(90),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PEOPLE IN THIS CAR',
                              style: TextStyle(
                                color: ConvoyColors.muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: v.members.map((m) {
                                final isMe = (currentUserId != null && m.userId == currentUserId) ||
                                    (currentUserName != null &&
                                        m.userName.toLowerCase() == currentUserName.toLowerCase());
                                final isHost = m.role == 'host' || (state.convoy?.hostId == m.userId);

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isMe ? ConvoyColors.amber.withAlpha(20) : ConvoyColors.panel,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isMe ? ConvoyColors.amber.withAlpha(80) : ConvoyColors.stroke,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.person_rounded,
                                        size: 13,
                                        color: isMe ? ConvoyColors.amber : ConvoyColors.muted,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        isMe ? '${m.userName} (You)' : m.userName,
                                        style: TextStyle(
                                          color: isMe ? ConvoyColors.amber : ConvoyColors.paint,
                                          fontSize: 12,
                                          fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                      if (isHost) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: ConvoyColors.amber.withAlpha(30),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: const Text(
                                            'HOST',
                                            style: TextStyle(
                                              color: ConvoyColors.amber,
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      // Join / Switch Action Footer (if not already in this vehicle)
                      if (!isMyVehicle)
                        InkWell(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                          onTap: () async {
                            await state.updateMyVehicle(v.name);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Joined ${v.name}')),
                              );
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: ConvoyColors.road.withAlpha(120),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                              border: const Border(top: BorderSide(color: ConvoyColors.stroke)),
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.group_add_rounded, size: 14, color: ConvoyColors.amber),
                                  SizedBox(width: 6),
                                  Text(
                                    'Join this car',
                                    style: TextStyle(
                                      color: ConvoyColors.amber,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _vehicleStatusTag(ConvoyVehicle v) {
    if (v.isStale) {
      return _tag('STALE', ConvoyColors.muted.withAlpha(120), ConvoyColors.muted);
    }
    if (v.isLead) {
      return _tag('LEAD', ConvoyColors.amber.withAlpha(30), ConvoyColors.amber);
    }
    final gapKm = (v.gapToLeadM / 1000).toStringAsFixed(1);
    final isBehind = v.gapToLeadM > 1000;
    final color = isBehind ? ConvoyColors.alert : ConvoyColors.signal;
    return _tag('$gapKm km', color.withAlpha(25), color);
  }

  Widget _tag(String text, Color bg, Color textCol) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: textCol.withAlpha(80)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(color: textCol, fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
      );
}

