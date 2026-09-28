import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';
import '../widgets/convoy_dialog.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConvoyState>().fetchExpenseHistory();
    });
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = months[dt.month - 1];
    final d = dt.day;
    final y = dt.year;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m $d, $y • $hour:$min $ampm';
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'fuel':
      case 'gas':
        return Icons.local_gas_station_rounded;
      case 'food':
      case 'drinks':
      case 'restaurant':
      case 'food & drinks':
        return Icons.restaurant_rounded;
      case 'tolls':
      case 'toll':
        return Icons.toll_rounded;
      case 'lodging':
      case 'hotel':
      case 'stay':
        return Icons.hotel_rounded;
      case 'parking':
        return Icons.local_parking_rounded;
      case 'groceries':
      case 'shopping':
        return Icons.shopping_cart_rounded;
      case 'activities':
      case 'tickets':
        return Icons.confirmation_number_rounded;
      case 'repairs':
        return Icons.build_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }

  Color _getCategoryColor(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'fuel':
      case 'gas':
        return const Color(0xFFFFB300);
      case 'food':
      case 'drinks':
      case 'restaurant':
      case 'food & drinks':
        return const Color(0xFFFF7043);
      case 'tolls':
      case 'toll':
        return const Color(0xFF42A5F5);
      case 'lodging':
      case 'hotel':
      case 'stay':
        return const Color(0xFFAB47BC);
      case 'parking':
        return const Color(0xFF26A69A);
      case 'groceries':
      case 'shopping':
        return const Color(0xFF66BB6A);
      default:
        return ConvoyColors.amber;
    }
  }

  void _showSessionDetails(ExpenseSession session) {
    final state = context.read<ConvoyState>();
    final currentUserName = state.userName;

    // Ensure current user is in participants list if not already there
    final participantsList = List<ExpenseSessionParticipant>.from(session.participants);
    if (currentUserName != null &&
        currentUserName.isNotEmpty &&
        !participantsList.any((p) => p.name.trim().toLowerCase() == currentUserName.trim().toLowerCase())) {
      final myPaid = session.expenses
          .where((e) => e.paidByName.trim().toLowerCase() == currentUserName.trim().toLowerCase())
          .fold(0.0, (sum, e) => sum + e.amount);
      final myBalance = myPaid - session.splitAmount;
      participantsList.insert(
        0,
        ExpenseSessionParticipant(
          name: currentUserName,
          paid: myPaid,
          balance: myBalance,
        ),
      );
    }

    // Ensure we match session.peopleCount by filling missing traveler placeholders if names were lost in legacy records
    int travelerIdx = 2;
    while (participantsList.length < session.peopleCount) {
      final placeholderName = 'Traveler $travelerIdx';
      if (!participantsList.any((p) => p.name.toLowerCase() == placeholderName.toLowerCase())) {
        participantsList.add(
          ExpenseSessionParticipant(
            name: placeholderName,
            paid: 0.0,
            balance: -session.splitAmount,
          ),
        );
      }
      travelerIdx++;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: ConvoyColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ConvoyColors.muted.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ConvoyColors.paint),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Completed on ${_formatDate(session.completedAt)}',
                        style: const TextStyle(color: ConvoyColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${session.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ConvoyColors.paint),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Metrics Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: ConvoyColors.panel2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ConvoyColors.stroke),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PER PERSON', style: TextStyle(color: ConvoyColors.amber, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                        const SizedBox(height: 4),
                        Text(
                          '\$${session.splitAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ConvoyColors.amber),
                        ),
                        const SizedBox(height: 2),
                        const Text('Fair share', style: TextStyle(color: ConvoyColors.muted, fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 38, color: ConvoyColors.stroke),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TRAVELERS', style: TextStyle(color: ConvoyColors.muted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                        const SizedBox(height: 4),
                        Text(
                          '${participantsList.isNotEmpty ? participantsList.length : session.peopleCount}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ConvoyColors.paint),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${participantsList.length == 1 ? 'Person' : 'People'} split',
                          style: const TextStyle(color: ConvoyColors.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 38, color: ConvoyColors.stroke),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL ITEMS', style: TextStyle(color: ConvoyColors.muted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                        const SizedBox(height: 4),
                        Text(
                          '${session.expenses.length}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ConvoyColors.paint),
                        ),
                        const SizedBox(height: 2),
                        const Text('Recorded', style: TextStyle(color: ConvoyColors.muted, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 1. PERSONS LIST & AMOUNT FOR EACH PERSON
            Row(
              children: [
                const Icon(Icons.people_alt_outlined, size: 16, color: ConvoyColors.amber),
                const SizedBox(width: 8),
                const Text(
                  'PERSONS & BALANCES',
                  style: TextStyle(color: ConvoyColors.paint, fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                ),
                const Spacer(),
                Text(
                  '${participantsList.length} traveler${participantsList.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: ConvoyColors.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (participantsList.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ConvoyColors.panel2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ConvoyColors.stroke),
                ),
                child: const Text('No individual participant records found.', style: TextStyle(color: ConvoyColors.muted, fontSize: 13)),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: ConvoyColors.panel2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ConvoyColors.stroke),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: participantsList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 52, color: ConvoyColors.stroke),
                  itemBuilder: (ctx, i) {
                    final p = participantsList[i];
                    final isMe = currentUserName != null &&
                        p.name.trim().toLowerCase() == currentUserName.trim().toLowerCase();
                    final isReceiving = p.balance > 0.01;
                    final isOwing = p.balance < -0.01;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isMe ? ConvoyColors.amber.withAlpha(25) : ConvoyColors.panel,
                              shape: BoxShape.circle,
                              border: Border.all(color: isMe ? ConvoyColors.amber.withAlpha(120) : ConvoyColors.stroke),
                            ),
                            child: Center(
                              child: Text(
                                p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
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
                                        p.name,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: ConvoyColors.paint),
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
                                const SizedBox(height: 1),
                                Text(
                                  'Paid \$${p.paid.toStringAsFixed(2)}',
                                  style: const TextStyle(color: ConvoyColors.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: isReceiving
                                  ? ConvoyColors.signal.withAlpha(20)
                                  : (isOwing ? ConvoyColors.alert.withAlpha(20) : ConvoyColors.panel),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isReceiving
                                    ? ConvoyColors.signal.withAlpha(70)
                                    : (isOwing ? ConvoyColors.alert.withAlpha(70) : ConvoyColors.stroke),
                              ),
                            ),
                            child: Text(
                              isReceiving
                                  ? '+\$${p.balance.abs().toStringAsFixed(2)} back'
                                  : (isOwing ? '-\$${p.balance.abs().toStringAsFixed(2)} owes' : 'Settled'),
                              style: TextStyle(
                                color: isReceiving
                                    ? ConvoyColors.signal
                                    : (isOwing ? ConvoyColors.alert : ConvoyColors.muted),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            // 2. EXPENSES LIST
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined, size: 16, color: ConvoyColors.amber),
                const SizedBox(width: 8),
                const Text(
                  'EXPENSES LIST',
                  style: TextStyle(color: ConvoyColors.paint, fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                ),
                const Spacer(),
                Text(
                  '${session.expenses.length} item${session.expenses.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: ConvoyColors.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (session.expenses.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ConvoyColors.panel2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ConvoyColors.stroke),
                ),
                child: const Text('No itemized expenses recorded in this session.', style: TextStyle(color: ConvoyColors.muted, fontSize: 13)),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: ConvoyColors.panel2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ConvoyColors.stroke),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: session.expenses.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 52, color: ConvoyColors.stroke),
                  itemBuilder: (ctx, i) {
                    final item = session.expenses[i];
                    final isPayerMe = currentUserName != null &&
                        item.paidByName.trim().toLowerCase() == currentUserName.trim().toLowerCase();
                    final catColor = _getCategoryColor(item.categoryName);
                    final catIcon = _getCategoryIcon(item.categoryName);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: catColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(catIcon, size: 18, color: catColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: ConvoyColors.paint),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.categoryName} • Paid by ${item.paidByName}${isPayerMe ? ' (You)' : ''}',
                                  style: const TextStyle(fontSize: 12, color: ConvoyColors.muted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${item.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ConvoyColors.paint),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSession(ExpenseSession session) async {
    final confirm = await ConvoyConfirmDialog.show(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Delete History Record?',
      message: 'Delete "${session.name}" permanently from expense history?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirm == true && mounted) {
      context.read<ConvoyState>().deleteHistorySession(session.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ConvoyState>();
    final history = state.historySessions;

    return Scaffold(
      backgroundColor: ConvoyColors.road,
      appBar: AppBar(
        title: const Text('Trip History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        backgroundColor: ConvoyColors.road,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 21),
            tooltip: 'Refresh',
            onPressed: () => state.fetchExpenseHistory(),
          ),
        ],
      ),
      body: state.isLoadingHistory && history.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: ConvoyColors.amber,
              onRefresh: () => state.fetchExpenseHistory(),
              child: history.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.28),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_rounded, size: 48, color: ConvoyColors.muted.withAlpha(80)),
                              const SizedBox(height: 14),
                              const Text('No Past Sessions Found', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              const SizedBox(height: 4),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  'When you finish an active expense tracking session, it will be saved here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: ConvoyColors.muted, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final session = history[index];
                        return Material(
                          color: ConvoyColors.panel,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => _showSessionDetails(session),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: ConvoyColors.stroke),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(Icons.bookmark_rounded, color: ConvoyColors.amber, size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                session.name,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: ConvoyColors.paint),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: ConvoyColors.muted),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Delete',
                                        onPressed: () => _deleteSession(session),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatDate(session.completedAt),
                                    style: const TextStyle(color: ConvoyColors.muted, fontSize: 12),
                                  ),
                                  const SizedBox(height: 14),

                                  // Split details
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: ConvoyColors.panel2,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('TOTAL SPENT', style: TextStyle(color: ConvoyColors.muted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                                              const SizedBox(height: 2),
                                              Text(
                                                '\$${session.totalAmount.toStringAsFixed(2)}',
                                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ConvoyColors.paint),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(width: 1, height: 28, color: ConvoyColors.stroke),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('PER PERSON', style: TextStyle(color: ConvoyColors.amber, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                                              const SizedBox(height: 2),
                                              Text(
                                                '\$${session.splitAmount.toStringAsFixed(2)}',
                                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ConvoyColors.amber),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${session.expenses.length} item${session.expenses.length == 1 ? '' : 's'} • ${session.peopleCount} people',
                                        style: const TextStyle(color: ConvoyColors.muted, fontSize: 12),
                                      ),
                                      const Row(
                                        children: [
                                          Text('Details', style: TextStyle(color: ConvoyColors.amber, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                          SizedBox(width: 2),
                                          Icon(Icons.chevron_right_rounded, size: 16, color: ConvoyColors.amber),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
