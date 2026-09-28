import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';
import 'expense_history_screen.dart';
import '../widgets/add_expense_dialog.dart';
import '../widgets/add_person_dialog.dart';
import '../widgets/manage_categories_dialog.dart';
import '../widgets/complete_expense_dialog.dart';
import '../widgets/convoy_dialog.dart';

class ExpensesScreen extends StatefulWidget {
  final bool isTab;
  const ExpensesScreen({super.key, this.isTab = false});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConvoyState>().fetchExpenses();
    });
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = months[dt.month - 1];
    final d = dt.day;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m $d, $hour:$min $ampm';
  }

  Future<void> _completeTracking() async {
    final session = await CompleteExpenseDialog.show(context);
    if (session != null && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Archived "${session.name}" to history!'),
          action: SnackBarAction(
            label: 'View History',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExpenseHistoryScreen()),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ConvoyState>();
    final expenses = state.expenses;
    final people = state.people;
    final categories = state.categories;
    final totalSpent = state.totalExpenses;
    final peopleCount = state.peopleCount;
    final split = state.splitPerPerson;
    final spentByPerson = state.spentByPerson;
    final spentByCategory = state.spentByCategory;

    final filteredExpenses = _selectedCategoryFilter == null
        ? expenses
        : expenses.where((e) => e.categoryName.toLowerCase() == _selectedCategoryFilter!.toLowerCase()).toList();

    return Scaffold(
      backgroundColor: ConvoyColors.road,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isTab,
        title: const Text('Trip Expenses', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        backgroundColor: ConvoyColors.road,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 22),
            tooltip: 'History',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExpenseHistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20),
            tooltip: 'Categories',
            onPressed: () => ManageCategoriesDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 21),
            tooltip: 'Refresh',
            onPressed: () => state.fetchExpenses(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ConvoyColors.amber,
        foregroundColor: const Color(0xFF14110A),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        onPressed: () => AddExpenseDialog.show(context),
      ),
      body: state.isLoadingExpenses && expenses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: ConvoyColors.amber,
              onRefresh: () => state.fetchExpenses(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
                children: [
                  // 0. Auto-hiding Recently Completed Session Banner (5s timer)
                  if (state.recentlyCompletedSession != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: ConvoyColors.signal.withAlpha(25),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ConvoyColors.signal.withAlpha(90)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: ConvoyColors.signal, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Trip Expenses Completed',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Archived "${state.recentlyCompletedSession!.name}" to history.',
                                  style: const TextStyle(color: ConvoyColors.muted, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: ConvoyColors.signal,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ExpenseHistoryScreen()),
                            ),
                            child: const Text('View History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => state.dismissCompletedSessionBanner(),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.close_rounded, size: 18, color: ConvoyColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 1. Complete Session Banner (if active expenses exist)
                  if (expenses.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: ConvoyColors.signal.withAlpha(20),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ConvoyColors.signal.withAlpha(70)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, color: ConvoyColors.signal, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Trip Completed?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                Text('Archive current expenses to history and reset.', style: TextStyle(color: ConvoyColors.muted, fontSize: 11.5)),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: ConvoyColors.signal,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: _completeTracking,
                            child: const Text('Archive', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 2. Summary Metrics Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: ConvoyColors.panel,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: ConvoyColors.stroke),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL SPENT',
                                style: TextStyle(color: ConvoyColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '\$${totalSpent.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ConvoyColors.paint),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${expenses.length} item${expenses.length == 1 ? '' : 's'} logged',
                                style: const TextStyle(color: ConvoyColors.muted, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 44, color: ConvoyColors.stroke),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PER PERSON',
                                style: TextStyle(color: ConvoyColors.amber, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '\$${split.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ConvoyColors.amber),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$peopleCount ${peopleCount == 1 ? 'person' : 'people'} split',
                                style: const TextStyle(color: ConvoyColors.muted, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. People & Balances Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: ConvoyColors.panel,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: ConvoyColors.stroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'People & Balances',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ConvoyColors.paint),
                            ),
                            InkWell(
                              onTap: () => AddPersonDialog.show(context),
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_rounded, size: 16, color: ConvoyColors.amber),
                                    SizedBox(width: 2),
                                    Text('Add Person', style: TextStyle(color: ConvoyColors.amber, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Builder(
                          builder: (context) {
                            final travelers = <Map<String, dynamic>>[];
                            if (state.userName != null && state.userName!.isNotEmpty) {
                              final myPerson = people.cast<ExpensePerson?>().firstWhere(
                                (p) => p != null && p.name.toLowerCase() == state.userName!.toLowerCase(),
                                orElse: () => null,
                              );
                              travelers.add({
                                'id': myPerson?.id ?? 'me',
                                'name': state.userName!,
                                'isMe': true,
                              });
                            }
                            for (final p in people) {
                              if (!travelers.any((t) => (t['name'] as String).toLowerCase() == p.name.toLowerCase())) {
                                travelers.add({
                                  'id': p.id,
                                  'name': p.name,
                                  'isMe': false,
                                });
                              }
                            }

                            if (travelers.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'No travelers added yet. Tap "+ Add Person" to add people.',
                                  style: TextStyle(color: ConvoyColors.muted, fontSize: 12.5),
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: travelers.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, indent: 44, color: ConvoyColors.stroke),
                              itemBuilder: (context, i) {
                                final t = travelers[i];
                                final name = t['name'] as String;
                                final isMe = t['isMe'] as bool;
                                final id = t['id'] as String;

                                final spent = spentByPerson[name] ?? 0.0;
                                final balance = spent - split;
                                final isReceiving = balance > 0.01;
                                final isOwing = balance < -0.01;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: isMe ? ConvoyColors.amber.withAlpha(25) : ConvoyColors.panel2,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: isMe ? ConvoyColors.amber.withAlpha(120) : ConvoyColors.stroke),
                                        ),
                                        child: Center(
                                          child: Text(
                                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: isMe ? ConvoyColors.amber : ConvoyColors.paint,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    name,
                                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isMe) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: ConvoyColors.amber.withAlpha(25),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: ConvoyColors.amber.withAlpha(80)),
                                                    ),
                                                    child: const Text(
                                                      'You',
                                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ConvoyColors.amber),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text('Paid \$${spent.toStringAsFixed(2)}', style: const TextStyle(color: ConvoyColors.muted, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isReceiving
                                              ? ConvoyColors.signal.withAlpha(20)
                                              : (isOwing ? ConvoyColors.alert.withAlpha(20) : ConvoyColors.panel2),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isReceiving
                                                ? ConvoyColors.signal.withAlpha(70)
                                                : (isOwing ? ConvoyColors.alert.withAlpha(70) : ConvoyColors.stroke),
                                          ),
                                        ),
                                        child: Text(
                                          isReceiving
                                              ? '+\$${balance.abs().toStringAsFixed(2)} back'
                                              : (isOwing ? '-\$${balance.abs().toStringAsFixed(2)} owes' : 'Settled'),
                                          style: TextStyle(
                                            color: isReceiving
                                                ? ConvoyColors.signal
                                                : (isOwing ? ConvoyColors.alert : ConvoyColors.muted),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (!isMe)
                                        InkWell(
                                          onTap: () async {
                                            final confirm = await ConvoyConfirmDialog.show(
                                              context,
                                              icon: Icons.person_remove_outlined,
                                              title: 'Remove Traveler?',
                                              message: 'Remove "$name" from active trip expenses?',
                                              confirmLabel: 'Remove',
                                              isDestructive: true,
                                            );
                                            if (confirm == true && context.mounted) {
                                              context.read<ConvoyState>().deletePerson(id);
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(12),
                                          child: const Padding(
                                            padding: EdgeInsets.only(left: 8, top: 4, bottom: 4),
                                            child: Icon(Icons.close_rounded, size: 16, color: ConvoyColors.muted),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill(
                          label: 'All',
                          isSelected: _selectedCategoryFilter == null,
                          onTap: () => setState(() => _selectedCategoryFilter = null),
                        ),
                        const SizedBox(width: 8),
                        ...categories.map((cat) {
                          final isSelected = _selectedCategoryFilter?.toLowerCase() == cat.name.toLowerCase();
                          final catSpent = spentByCategory[cat.name] ?? 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildFilterPill(
                              label: '${cat.name} (\$${catSpent.toStringAsFixed(0)})',
                              icon: cat.iconData,
                              accentColor: cat.color,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  _selectedCategoryFilter = isSelected ? null : cat.name;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 5. Itemized Expense List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedCategoryFilter == null ? 'Itemized Expenses' : '$_selectedCategoryFilter',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ConvoyColors.paint),
                      ),
                      Text(
                        '${filteredExpenses.length} record${filteredExpenses.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: ConvoyColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (filteredExpenses.isEmpty)
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
                            Icon(Icons.receipt_long_outlined, size: 36, color: ConvoyColors.muted),
                            SizedBox(height: 10),
                            Text('No expenses in this category.', style: TextStyle(color: ConvoyColors.muted, fontSize: 13.5)),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredExpenses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final expense = filteredExpenses[i];
                        final cat = categories.cast<ExpenseCategoryItem?>().firstWhere(
                          (c) => c != null && c.name.toLowerCase() == expense.categoryName.toLowerCase(),
                          orElse: () => null,
                        );

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            color: ConvoyColors.panel,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ConvoyColors.stroke),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: (cat?.color ?? ConvoyColors.amber).withAlpha(25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  cat?.iconData ?? Icons.receipt_rounded,
                                  color: cat?.color ?? ConvoyColors.amber,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      expense.title,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: ConvoyColors.paint),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${expense.paidByName} • ${expense.categoryName} • ${_formatDate(expense.createdAt)}',
                                      style: const TextStyle(color: ConvoyColors.muted, fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${expense.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: ConvoyColors.amber),
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      final confirm = await ConvoyConfirmDialog.show(
                                        context,
                                        icon: Icons.delete_outline_rounded,
                                        title: 'Delete Expense?',
                                        message: 'Delete "${expense.title}" (\$${expense.amount.toStringAsFixed(2)})?',
                                        confirmLabel: 'Delete',
                                        isDestructive: true,
                                      );
                                      if (confirm == true && context.mounted) {
                                        context.read<ConvoyState>().deleteExpense(expense.id);
                                      }
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 2),
                                      child: Icon(Icons.delete_outline_rounded, size: 16, color: ConvoyColors.muted),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
    Color? accentColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? ConvoyColors.amber : ConvoyColors.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? ConvoyColors.amber : ConvoyColors.stroke,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? const Color(0xFF14110A) : (accentColor ?? ConvoyColors.muted),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? const Color(0xFF14110A) : ConvoyColors.paint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
