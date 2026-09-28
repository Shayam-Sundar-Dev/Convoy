import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../services/connectivity_service.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';

class CompleteExpenseDialog extends StatefulWidget {
  const CompleteExpenseDialog({super.key});

  static Future<ExpenseSession?> show(BuildContext context) async {
    if (!await ConnectivityService.instance.ensureConnected(context: context, action: 'complete trip expenses')) {
      return null;
    }
    if (!context.mounted) return null;
    return showDialog<ExpenseSession>(
      context: context,
      builder: (_) => const CompleteExpenseDialog(),
    );
  }

  @override
  State<CompleteExpenseDialog> createState() => _CompleteExpenseDialogState();
}

class _CompleteExpenseDialogState extends State<CompleteExpenseDialog> {
  late final TextEditingController _nameController;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = context.read<ConvoyState>();
    final convoyName = state.convoy?.name;
    final defaultName = convoyName != null && convoyName.isNotEmpty
        ? '$convoyName Trip'
        : 'Trip - ${_formatToday()}';
    _nameController = TextEditingController(text: defaultName);
  }

  String _formatToday() {
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name for this trip/session.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final state = context.read<ConvoyState>();
      final session = await state.completeExpenseSession(name);
      if (!mounted) return;
      Navigator.of(context).pop(session);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ConvoyState>();
    final total = state.totalExpenses;
    final count = state.expenses.length;
    final split = state.splitPerPerson;
    final peopleCount = state.peopleCount;

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
              color: ConvoyColors.signal.withAlpha(24),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ConvoyColors.signal.withAlpha(45)),
            ),
            child: const Icon(Icons.check_circle_outline_rounded, color: ConvoyColors.signal, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Complete Tracking',
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
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Archive current expenses into History and reset travelers for your next journey.',
                style: TextStyle(color: ConvoyColors.muted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 13.5, color: ConvoyColors.paint),
                decoration: InputDecoration(
                  labelText: 'Record Name',
                  hintText: 'e.g. Tahoe Ski Trip, Highway 1',
                  prefixIcon: const Icon(Icons.bookmark_outline_rounded, size: 18, color: ConvoyColors.muted),
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
                    borderSide: const BorderSide(color: ConvoyColors.signal),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Summary card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ConvoyColors.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ConvoyColors.stroke),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount', style: TextStyle(color: ConvoyColors.muted, fontSize: 12.5)),
                        Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: ConvoyColors.paint)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Entries', style: TextStyle(color: ConvoyColors.muted, fontSize: 12.5)),
                        Text('$count item${count == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ConvoyColors.paint)),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: ConvoyColors.stroke),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Fair Share', style: TextStyle(color: ConvoyColors.amber, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        Text(
                          '\$${split.toStringAsFixed(2)} / person ($peopleCount)',
                          style: const TextStyle(color: ConvoyColors.amber, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
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
        ),
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
            backgroundColor: ConvoyColors.signal,
            foregroundColor: Colors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _busy ? null : _submit,
          child: Text(
            _busy ? 'Archiving…' : 'Archive & Reset',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
