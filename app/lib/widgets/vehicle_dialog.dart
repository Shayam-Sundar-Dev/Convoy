import 'package:flutter/material.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';

/// A sleek, minimalistic dialog allowing users to switch or assign their vehicle group.
class VehicleSwitchDialog extends StatefulWidget {
  final ConvoyState state;

  const VehicleSwitchDialog({super.key, required this.state});

  static Future<void> show(BuildContext context, ConvoyState state) {
    return showDialog(
      context: context,
      builder: (_) => VehicleSwitchDialog(state: state),
    );
  }

  @override
  State<VehicleSwitchDialog> createState() => _VehicleSwitchDialogState();
}

class _VehicleSwitchDialogState extends State<VehicleSwitchDialog> {
  final TextEditingController _customController = TextEditingController();
  String? _selectedVehicle;
  bool _isCustom = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final current = widget.state.myVehicle?.name ?? '';
    _selectedVehicle = current.isNotEmpty ? current : null;
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final vehicleToSet = _isCustom
        ? _customController.text.trim()
        : (_selectedVehicle?.trim() ?? '');

    if (vehicleToSet.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or select a vehicle name')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.state.updateMyVehicle(vehicleToSet);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update vehicle: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = widget.state.vehicles;
    final currentName = widget.state.myVehicle?.name ?? '';

    return AlertDialog(
      backgroundColor: ConvoyColors.panel2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: ConvoyColors.stroke, width: 1),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      titlePadding: EdgeInsets.zero,
      content: SingleChildScrollView(
        child: Column(
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
                  child: const Icon(Icons.directions_car_rounded, color: ConvoyColors.amber, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Vehicle Group',
                    style: TextStyle(
                      fontSize: 16.5,
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
            const SizedBox(height: 10),
            const Text(
              'Select an existing car to share tracking with passengers, or create a new vehicle.',
              style: TextStyle(color: ConvoyColors.muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),

            // Existing Vehicles List
            if (vehicles.isNotEmpty) ...[
              const Text(
                'EXISTING CARS IN CONVOY',
                style: TextStyle(
                  color: ConvoyColors.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              ...vehicles.map((v) {
                final isCurrent = v.name.toLowerCase() == currentName.toLowerCase();
                final isSelected = !_isCustom && _selectedVehicle?.toLowerCase() == v.name.toLowerCase();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _isCustom = false;
                        _selectedVehicle = v.name;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: isSelected ? ConvoyColors.amber.withAlpha(20) : ConvoyColors.panel,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? ConvoyColors.amber : ConvoyColors.stroke,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.directions_car_rounded,
                            size: 18,
                            color: isSelected ? ConvoyColors.amber : (v.isLead ? ConvoyColors.amber : ConvoyColors.paint),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      v.name,
                                      style: TextStyle(
                                        color: isSelected ? ConvoyColors.amber : ConvoyColors.paint,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (v.isLead) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: ConvoyColors.amber.withAlpha(30),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'LEAD',
                                          style: TextStyle(color: ConvoyColors.amber, fontSize: 9.5, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ],
                                    if (isCurrent) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: ConvoyColors.signal.withAlpha(30),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'CURRENT',
                                          style: TextStyle(color: ConvoyColors.signal, fontSize: 9.5, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${v.passengerNames.join(", ")} (${v.passengerCount} pax)',
                                  style: const TextStyle(color: ConvoyColors.muted, fontSize: 11.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: ConvoyColors.amber, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],

            // Custom Vehicle Option
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() => _isCustom = true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: _isCustom ? ConvoyColors.amber.withAlpha(20) : ConvoyColors.panel,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isCustom ? ConvoyColors.amber : ConvoyColors.stroke,
                      width: _isCustom ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: 18,
                        color: _isCustom ? ConvoyColors.amber : ConvoyColors.muted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Add / Drive another vehicle',
                          style: TextStyle(
                            color: _isCustom ? ConvoyColors.amber : ConvoyColors.paint,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (_isCustom)
                        const Icon(Icons.check_circle_rounded, color: ConvoyColors.amber, size: 18),
                    ],
                  ),
                ),
              ),
            ),

            if (_isCustom) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _customController,
                autofocus: true,
                style: const TextStyle(color: ConvoyColors.paint, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Blue Tacoma, Car 2, Tesla Model 3',
                  hintStyle: const TextStyle(color: ConvoyColors.muted, fontSize: 13),
                  filled: true,
                  fillColor: ConvoyColors.panel,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: ConvoyColors.stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: ConvoyColors.stroke),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: ConvoyColors.amber, width: 1.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: ConvoyColors.muted,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ConvoyColors.amber,
            foregroundColor: const Color(0xFF14110A),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF14110A)),
                )
              : const Text('Save Vehicle', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    );
  }
}

