import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';

class AddPersonDialog extends StatefulWidget {
  const AddPersonDialog({super.key});

  static Future<String?> show(BuildContext context) async {
    if (!await ConnectivityService.instance.ensureConnected(context: context, action: 'add a person')) {
      return null;
    }
    if (!context.mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (_) => const AddPersonDialog(),
    );
  }

  @override
  State<AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<AddPersonDialog> {
  final _nameController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final person = await context.read<ConvoyState>().addPerson(name);
      if (!mounted) return;
      Navigator.of(context).pop(person.name);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
            child: const Icon(Icons.person_add_rounded, color: ConvoyColors.amber, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Add Traveler',
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add a group member to track their expenses and split costs fairly.',
            style: TextStyle(color: ConvoyColors.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 13.5, color: ConvoyColors.paint),
            decoration: InputDecoration(
              hintText: 'Traveler Name (e.g. Sarah, Alex)',
              prefixIcon: const Icon(Icons.person_outline, size: 18, color: ConvoyColors.muted),
              isDense: true,
              filled: true,
              fillColor: ConvoyColors.panel,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: ConvoyColors.stroke),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: ConvoyColors.stroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: ConvoyColors.amber),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ConvoyColors.alert.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ConvoyColors.alert.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: ConvoyColors.alert),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: ConvoyColors.alert, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
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
          onPressed: _busy ? null : _submit,
          child: Text(
            _busy ? 'Adding…' : 'Add',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
