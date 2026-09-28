import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/convoy_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _editingName = false;
  final _nameCtrl = TextEditingController();
  bool _savingName = false;

  bool _locationAlerts = true;
  bool _pingVibration = true;
  bool _keepScreenOn = true;
  String _distanceUnit = 'km';
  bool _loadingPrefs = true;
  bool _busyLogout = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _locationAlerts = prefs.getBool('pref_locationAlerts') ?? true;
      _pingVibration = prefs.getBool('pref_pingVibration') ?? true;
      _keepScreenOn = prefs.getBool('pref_keepScreenOn') ?? true;
      _distanceUnit = prefs.getString('pref_distanceUnit') ?? 'km';
      _loadingPrefs = false;
    });
  }

  Future<void> _savePref<T>(String key, T value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await ConvoyConfirmDialog.show(
      context,
      icon: Icons.logout_rounded,
      title: 'Sign out?',
      message: 'You will need to sign in again to host or join a convoy.',
      confirmLabel: 'Sign out',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyLogout = true);
    try {
      await context.read<ConvoyState>().logout();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } finally {
      if (mounted) setState(() => _busyLogout = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ConvoyState>();
    final initial = (state.userName ?? '?').isNotEmpty ? (state.userName ?? '?')[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: ConvoyColors.road,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: ConvoyColors.road,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _busyLogout || _loadingPrefs,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // 1. Profile Panel
            _buildSectionHeader('PROFILE'),
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
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: ConvoyColors.amber.withAlpha(30),
                          shape: BoxShape.circle,
                          border: Border.all(color: ConvoyColors.amber.withAlpha(80)),
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: ConvoyColors.amber,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.userName ?? 'Driver',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: ConvoyColors.paint,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              state.userEmail ?? 'No email',
                              style: const TextStyle(
                                color: ConvoyColors.muted,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _editingName ? Icons.close_rounded : Icons.edit_outlined,
                          size: 19,
                          color: ConvoyColors.muted,
                        ),
                        tooltip: _editingName ? 'Cancel' : 'Edit name',
                        onPressed: () {
                          setState(() {
                            _editingName = !_editingName;
                            if (_editingName) {
                              _nameCtrl.text = state.userName ?? '';
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  if (_editingName) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Display name',
                        fillColor: ConvoyColors.panel2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: ConvoyColors.stroke),
                        ),
                      ),
                      textCapitalization: TextCapitalization.words,
                      autofocus: true,
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          minimumSize: Size.zero,
                        ),
                        onPressed: _savingName
                            ? null
                            : () async {
                                final newName = _nameCtrl.text.trim();
                                if (newName.isEmpty) return;
                                setState(() => _savingName = true);
                                try {
                                  await context.read<ConvoyState>().updateName(newName);
                                  if (mounted) setState(() => _editingName = false);
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _savingName = false);
                                }
                              },
                        child: Text(_savingName ? 'Saving…' : 'Save Name', style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 2. Alerts Panel
            _buildSectionHeader('ALERTS & NOTIFICATIONS'),
            Container(
              decoration: BoxDecoration(
                color: ConvoyColors.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ConvoyColors.stroke),
              ),
              child: Column(
                children: [
                  _buildToggleTile(
                    icon: Icons.warning_amber_rounded,
                    iconColor: ConvoyColors.amber,
                    title: 'Straggler & gap alerts',
                    subtitle: 'Alert when a car falls > 7 km behind',
                    value: _locationAlerts,
                    onChanged: (v) {
                      setState(() => _locationAlerts = v);
                      _savePref('pref_locationAlerts', v);
                    },
                  ),
                  const Divider(height: 1, indent: 52, color: ConvoyColors.stroke),
                  _buildToggleTile(
                    icon: Icons.vibration_rounded,
                    iconColor: ConvoyColors.signal,
                    title: 'Haptic feedback on ping',
                    subtitle: 'Vibrate when a teammate sends a message',
                    value: _pingVibration,
                    onChanged: (v) {
                      setState(() => _pingVibration = v);
                      _savePref('pref_pingVibration', v);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 3. Display & Unit Preferences Panel
            _buildSectionHeader('DISPLAY & UNITS'),
            Container(
              decoration: BoxDecoration(
                color: ConvoyColors.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ConvoyColors.stroke),
              ),
              child: Column(
                children: [
                  _buildToggleTile(
                    icon: Icons.light_mode_outlined,
                    iconColor: ConvoyColors.paint,
                    title: 'Keep screen awake',
                    subtitle: 'Prevent sleep while on an active convoy',
                    value: _keepScreenOn,
                    onChanged: (v) {
                      setState(() => _keepScreenOn = v);
                      _savePref('pref_keepScreenOn', v);
                    },
                  ),
                  const Divider(height: 1, indent: 52, color: ConvoyColors.stroke),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.straighten_rounded, size: 20, color: ConvoyColors.muted),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Distance Unit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text('Used for odometer & gap metrics', style: TextStyle(color: ConvoyColors.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        _buildSegmentedPicker(
                          options: const ['km', 'mi'],
                          selected: _distanceUnit,
                          onSelected: (v) {
                            setState(() => _distanceUnit = v);
                            _savePref('pref_distanceUnit', v);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 4. About & Version
            _buildSectionHeader('ABOUT'),
            Container(
              decoration: BoxDecoration(
                color: ConvoyColors.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ConvoyColors.stroke),
              ),
              child: const Column(
                children: [
                  _SettingsInfoRow(
                    icon: Icons.directions_car_outlined,
                    title: 'Convoy App',
                    value: 'v1.0.0',
                  ),
                  Divider(height: 1, indent: 52, color: ConvoyColors.stroke),
                  _SettingsInfoRow(
                    icon: Icons.map_outlined,
                    title: 'Maps & Navigation',
                    value: 'Mapbox Directions',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 5. Sign Out
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _busyLogout ? null : () => _logout(context),
                icon: const Icon(Icons.logout_rounded, size: 18, color: ConvoyColors.alert),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(color: ConvoyColors.alert, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: ConvoyColors.alert.withAlpha(60)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: ConvoyColors.muted,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, size: 20, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: ConvoyColors.muted, fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeColor: ConvoyColors.amber,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  Widget _buildSegmentedPicker({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ConvoyColors.panel2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ConvoyColors.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = opt == selected;
          return GestureDetector(
            onTap: () => onSelected(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? ConvoyColors.amber : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                opt.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? const Color(0xFF14110A) : ConvoyColors.muted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SettingsInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ConvoyColors.muted),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: ConvoyColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
