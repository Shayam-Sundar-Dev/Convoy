import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../services/connectivity_service.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';
import 'add_person_dialog.dart';
import 'manage_categories_dialog.dart';

class AddExpenseDialog extends StatefulWidget {
  const AddExpenseDialog({super.key});

  static Future<Expense?> show(BuildContext context) async {
    if (!await ConnectivityService.instance.ensureConnected(context: context, action: 'add an expense')) {
      return null;
    }
    if (!context.mounted) return null;
    return showDialog<Expense>(
      context: context,
      builder: (_) => const AddExpenseDialog(),
    );
  }

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedCategoryName;
  String? _selectedPersonName;
  String? _selectedPersonId;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<ConvoyState>();
      // Pre-select current user by default!
      if (state.userName != null && state.userName!.isNotEmpty) {
        final myPerson = state.people.cast<ExpensePerson?>().firstWhere(
          (p) => p != null && p.name.toLowerCase() == state.userName!.toLowerCase(),
          orElse: () => null,
        );
        setState(() {
          _selectedPersonName = state.userName;
          _selectedPersonId = myPerson?.id;
        });
      } else if (state.people.isNotEmpty) {
        setState(() {
          _selectedPersonName = state.people.first.name;
          _selectedPersonId = state.people.first.id;
        });
      }

      // Pre-select first category if available
      if (state.categories.isNotEmpty) {
        setState(() {
          _selectedCategoryId = state.categories.first.id;
          _selectedCategoryName = state.categories.first.name;
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (title.isEmpty) {
      setState(() => _error = 'Please enter an expense description.');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount.');
      return;
    }
    final paidBy = _selectedPersonName ?? context.read<ConvoyState>().userName ?? 'Someone';
    final catName = _selectedCategoryName ?? 'Other';

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final state = context.read<ConvoyState>();
      final exp = await state.addExpense(
        title: title,
        amount: amount,
        categoryName: catName,
        categoryId: _selectedCategoryId,
        paidByName: paidBy,
        personId: _selectedPersonId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(exp);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAddPerson() async {
    final newName = await AddPersonDialog.show(context);
    if (newName != null && mounted) {
      final state = context.read<ConvoyState>();
      final person = state.people.cast<ExpensePerson?>().firstWhere(
        (p) => p != null && p.name.toLowerCase() == newName.toLowerCase(),
        orElse: () => null,
      );
      setState(() {
        _selectedPersonName = newName;
        _selectedPersonId = person?.id;
      });
    }
  }

  Future<void> _openManageCategories() async {
    await ManageCategoriesDialog.show(context);
    if (mounted) {
      final state = context.read<ConvoyState>();
      if (_selectedCategoryId == null && state.categories.isNotEmpty) {
        setState(() {
          _selectedCategoryId = state.categories.first.id;
          _selectedCategoryName = state.categories.first.name;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ConvoyState>();
    final categories = state.categories;
    final people = state.people;

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
            child: const Icon(Icons.add_shopping_cart_rounded, color: ConvoyColors.amber, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Add Expense',
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
              // Minimalist Amount Card Input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: ConvoyColors.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ConvoyColors.stroke),
                ),
                child: Row(
                  children: [
                    const Text(
                      '\$',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ConvoyColors.amber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: ConvoyColors.paint,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: '0.00',
                          hintStyle: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A5568),
                          ),
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Description input
              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 13.5, color: ConvoyColors.paint),
                decoration: InputDecoration(
                  hintText: 'Description (e.g. Fuel, Dinner, Toll)',
                  prefixIcon: const Icon(Icons.receipt_long_outlined, size: 18, color: ConvoyColors.muted),
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
              ),
              const SizedBox(height: 16),

              // Who Paid Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'WHO PAID',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: ConvoyColors.muted,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openAddPerson,
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add Person', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      foregroundColor: ConvoyColors.amber,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Payer Choice Chips
              Builder(
                builder: (context) {
                  final candidatePayers = <Map<String, dynamic>>[];
                  if (state.userName != null && state.userName!.isNotEmpty) {
                    final myPerson = state.people.cast<ExpensePerson?>().firstWhere(
                      (p) => p != null && p.name.toLowerCase() == state.userName!.toLowerCase(),
                      orElse: () => null,
                    );
                    candidatePayers.add({
                      'name': state.userName!,
                      'label': '${state.userName!} (You)',
                      'id': myPerson?.id,
                      'isMe': true,
                    });
                  }
                  for (final p in people) {
                    if (!candidatePayers.any((c) => (c['name'] as String).toLowerCase() == p.name.toLowerCase())) {
                      candidatePayers.add({
                        'name': p.name,
                        'label': p.name,
                        'id': p.id,
                        'isMe': false,
                      });
                    }
                  }

                  if (candidatePayers.isEmpty) {
                    return OutlinedButton.icon(
                      onPressed: _openAddPerson,
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Add a person first', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    );
                  }

                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: candidatePayers.map((p) {
                      final name = p['name'] as String;
                      final label = p['label'] as String;
                      final id = p['id'] as String?;
                      final isSel = _selectedPersonName?.toLowerCase() == name.toLowerCase();

                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            _selectedPersonName = name;
                            _selectedPersonId = id;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSel ? ConvoyColors.amber.withAlpha(28) : ConvoyColors.panel,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSel ? ConvoyColors.amber : ConvoyColors.stroke,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 9,
                                backgroundColor: isSel ? ConvoyColors.amber : ConvoyColors.stroke,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: isSel ? Colors.black : ConvoyColors.paint,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                                  color: isSel ? ConvoyColors.paint : ConvoyColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Category Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CATEGORY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: ConvoyColors.muted,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openManageCategories,
                    icon: const Icon(Icons.tune_rounded, size: 14),
                    label: const Text('Manage', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      foregroundColor: ConvoyColors.amber,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Category Choice Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: categories.map((cat) {
                  final isSel = _selectedCategoryId == cat.id ||
                      (_selectedCategoryId == null && _selectedCategoryName?.toLowerCase() == cat.name.toLowerCase());

                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = cat.id;
                        _selectedCategoryName = cat.name;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? cat.color.withAlpha(28) : ConvoyColors.panel,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSel ? cat.color : ConvoyColors.stroke,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat.iconData, size: 13, color: isSel ? cat.color : ConvoyColors.muted),
                          const SizedBox(width: 6),
                          Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                              color: isSel ? ConvoyColors.paint : ConvoyColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
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
            backgroundColor: ConvoyColors.amber,
            foregroundColor: const Color(0xFF14110A),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _busy ? null : _submit,
          child: Text(
            _busy ? 'Saving…' : 'Add Expense',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
