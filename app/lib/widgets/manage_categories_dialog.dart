import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';
import 'convoy_dialog.dart';

class ManageCategoriesDialog extends StatefulWidget {
  const ManageCategoriesDialog({super.key});

  static Future<ExpenseCategoryItem?> show(BuildContext context) {
    return showDialog<ExpenseCategoryItem>(
      context: context,
      builder: (_) => const ManageCategoriesDialog(),
    );
  }

  @override
  State<ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<ManageCategoriesDialog> {
  final _addNameController = TextEditingController();
  String _selectedIcon = 'category';
  bool _busy = false;
  String? _error;

  static const List<Map<String, dynamic>> _availableIcons = [
    {'key': 'fuel', 'label': 'Fuel', 'icon': Icons.local_gas_station_rounded},
    {'key': 'food', 'label': 'Food', 'icon': Icons.restaurant_rounded},
    {'key': 'tolls', 'label': 'Tolls', 'icon': Icons.toll_rounded},
    {'key': 'lodging', 'label': 'Lodging', 'icon': Icons.hotel_rounded},
    {'key': 'parking', 'label': 'Parking', 'icon': Icons.local_parking_rounded},
    {'key': 'groceries', 'label': 'Groceries', 'icon': Icons.shopping_cart_rounded},
    {'key': 'activities', 'label': 'Activities', 'icon': Icons.confirmation_number_rounded},
    {'key': 'repairs', 'label': 'Repairs', 'icon': Icons.build_rounded},
    {'key': 'category', 'label': 'Other', 'icon': Icons.category_rounded},
  ];

  @override
  void dispose() {
    _addNameController.dispose();
    super.dispose();
  }

  Future<void> _addNewCategory() async {
    final name = _addNameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final state = context.read<ConvoyState>();
      await state.addCategory(name, _selectedIcon);
      _addNameController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added category "$name"')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editCategory(ExpenseCategoryItem cat) async {
    final editController = TextEditingController(text: cat.name);
    String editIcon = cat.icon;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
                child: const Icon(Icons.edit_outlined, color: ConvoyColors.amber, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Edit Category',
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
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: editController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 13.5, color: ConvoyColors.paint),
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  prefixIcon: const Icon(Icons.label_outline, size: 18, color: ConvoyColors.muted),
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
              const Text(
                'CHOOSE ICON',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: ConvoyColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _availableIcons.map((item) {
                  final isSel = editIcon.toLowerCase() == item['key'];
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setDialogState(() => editIcon = item['key'] as String),
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
                          Icon(item['icon'] as IconData, size: 14, color: isSel ? ConvoyColors.amber : ConvoyColors.muted),
                          const SizedBox(width: 5),
                          Text(
                            item['label'] as String,
                            style: TextStyle(
                              fontSize: 11.5,
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
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
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
      ),
    );

    if (updated == true && editController.text.trim().isNotEmpty && mounted) {
      try {
        final state = context.read<ConvoyState>();
        await state.editCategory(cat.id, editController.text.trim(), icon: editIcon);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update category: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(ExpenseCategoryItem cat) async {
    final confirm = await ConvoyConfirmDialog.show(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Delete Category?',
      message: 'Are you sure you want to delete "${cat.name}"?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirm == true && mounted) {
      try {
        final state = context.read<ConvoyState>();
        await state.deleteCategory(cat.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ConvoyState>().categories;

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
            child: const Icon(Icons.category_outlined, color: ConvoyColors.amber, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Categories',
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
                'EXISTING CATEGORIES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: ConvoyColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              if (categories.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No categories available.', style: TextStyle(color: ConvoyColors.muted, fontSize: 13)),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: ConvoyColors.panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ConvoyColors.stroke),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: ConvoyColors.stroke),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        leading: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: cat.color.withAlpha(35),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(cat.iconData, size: 16, color: cat.color),
                        ),
                        title: Text(
                          cat.name,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ConvoyColors.paint),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16, color: ConvoyColors.muted),
                              tooltip: 'Edit Category',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _busy ? null : () => _editCategory(cat),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: ConvoyColors.alert),
                              tooltip: 'Delete Category',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _busy ? null : () => _deleteCategory(cat),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 18),
              const Text(
                'NEW CATEGORY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: ConvoyColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _addNameController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 13.5, color: ConvoyColors.paint),
                decoration: InputDecoration(
                  hintText: 'Category Name (e.g. Snacks, Camping)',
                  prefixIcon: const Icon(Icons.label_outline, size: 18, color: ConvoyColors.muted),
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
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _availableIcons.map((item) {
                  final isSel = _selectedIcon.toLowerCase() == item['key'];
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _selectedIcon = item['key'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
                          Icon(item['icon'] as IconData, size: 13, color: isSel ? ConvoyColors.amber : ConvoyColors.muted),
                          const SizedBox(width: 4),
                          Text(
                            item['label'] as String,
                            style: TextStyle(
                              fontSize: 11,
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ConvoyColors.amber,
                    foregroundColor: const Color(0xFF14110A),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _busy ? null : _addNewCategory,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(_busy ? 'Adding…' : 'Add Category', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: ConvoyColors.muted,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
