import 'package:flutter/material.dart';

class ExpenseCategoryItem {
  final String id;
  final String name;
  final String icon;

  const ExpenseCategoryItem({
    required this.id,
    required this.name,
    required this.icon,
  });

  factory ExpenseCategoryItem.fromJson(Map<String, dynamic> j) => ExpenseCategoryItem(
        id: j['id'] as String,
        name: j['name'] as String,
        icon: (j['icon'] as String?) ?? 'category',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
      };

  IconData get iconData {
    switch (icon.toLowerCase()) {
      case 'fuel':
      case 'gas':
        return Icons.local_gas_station_rounded;
      case 'food':
      case 'drinks':
      case 'restaurant':
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
        return Icons.category_rounded;
    }
  }

  Color get color {
    switch (icon.toLowerCase()) {
      case 'fuel':
      case 'gas':
        return const Color(0xFFFFB300); // Amber
      case 'food':
      case 'drinks':
      case 'restaurant':
        return const Color(0xFFFF7043); // Orange
      case 'tolls':
      case 'toll':
        return const Color(0xFF42A5F5); // Blue
      case 'lodging':
      case 'hotel':
      case 'stay':
        return const Color(0xFFAB47BC); // Purple
      case 'parking':
        return const Color(0xFF26A69A); // Teal
      case 'groceries':
      case 'shopping':
        return const Color(0xFF66BB6A); // Green
      default:
        return const Color(0xFF90A4AE); // Blue grey
    }
  }
}

class ExpensePerson {
  final String id;
  final String name;
  final String? userId;

  const ExpensePerson({
    required this.id,
    required this.name,
    this.userId,
  });

  factory ExpensePerson.fromJson(Map<String, dynamic> j) => ExpensePerson(
        id: j['id'] as String,
        name: j['name'] as String,
        userId: j['userId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (userId != null) 'userId': userId,
      };
}

class Expense {
  final String id;
  final String title;
  final double amount;
  final String categoryName;
  final String? categoryId;
  final String paidByName;
  final String? personId;
  final String? convoyId;
  final String? sessionId;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryName,
    this.categoryId,
    required this.paidByName,
    this.personId,
    this.convoyId,
    this.sessionId,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        title: j['title'] as String,
        amount: (j['amount'] as num).toDouble(),
        categoryName: (j['categoryName'] as String?) ?? 'Other',
        categoryId: j['categoryId'] as String?,
        paidByName: (j['paidByName'] as String?) ?? 'Someone',
        personId: j['personId'] as String?,
        convoyId: j['convoyId'] as String?,
        sessionId: j['sessionId'] as String?,
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'categoryName': categoryName,
        if (categoryId != null) 'categoryId': categoryId,
        'paidByName': paidByName,
        if (personId != null) 'personId': personId,
        if (convoyId != null) 'convoyId': convoyId,
        if (sessionId != null) 'sessionId': sessionId,
        'createdAt': createdAt.toIso8601String(),
      };
}

class ExpenseSessionParticipant {
  final String name;
  final double paid;
  final double balance; // paid - splitAmount (+ = gets back, - = owes)

  const ExpenseSessionParticipant({
    required this.name,
    required this.paid,
    required this.balance,
  });

  factory ExpenseSessionParticipant.fromJson(Map<String, dynamic> j) => ExpenseSessionParticipant(
        name: (j['name'] as String?) ?? 'Unknown',
        paid: (j['paid'] as num?)?.toDouble() ?? 0.0,
        balance: (j['balance'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'paid': paid,
        'balance': balance,
      };
}

class ExpenseSession {
  final String id;
  final String name;
  final double totalAmount;
  final int peopleCount;
  final double splitAmount;
  final String? convoyId;
  final DateTime completedAt;
  final List<Expense> expenses;
  final List<ExpenseSessionParticipant> participants;

  const ExpenseSession({
    required this.id,
    required this.name,
    required this.totalAmount,
    required this.peopleCount,
    required this.splitAmount,
    this.convoyId,
    required this.completedAt,
    required this.expenses,
    this.participants = const [],
  });

  factory ExpenseSession.fromJson(Map<String, dynamic> j) {
    final rawExpenses = j['expenses'] != null
        ? (j['expenses'] as List).map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList()
        : <Expense>[];

    final split = (j['splitAmount'] as num?)?.toDouble() ?? 0.0;

    List<ExpenseSessionParticipant> parsedParticipants = [];
    if (j['participants'] != null) {
      try {
        final dynamic raw = j['participants'];
        if (raw is List) {
          parsedParticipants = raw.map((item) => ExpenseSessionParticipant.fromJson(item as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }

    // Fallback: If participants were not explicitly recorded, compute dynamically from expenses
    final creatorName = j['user'] is Map ? (j['user']['name'] as String?) : null;
    if (parsedParticipants.isEmpty && rawExpenses.isNotEmpty) {
      final Map<String, double> paidMap = {};
      if (creatorName != null && creatorName.trim().isNotEmpty) {
        paidMap[creatorName.trim()] = 0.0;
      }
      for (final exp in rawExpenses) {
        final payer = exp.paidByName.trim();
        paidMap[payer] = (paidMap[payer] ?? 0.0) + exp.amount;
      }
      parsedParticipants = paidMap.entries.map((entry) {
        final paid = entry.value;
        final balance = paid - split;
        return ExpenseSessionParticipant(
          name: entry.key,
          paid: paid,
          balance: balance,
        );
      }).toList();
    }

    return ExpenseSession(
      id: j['id'] as String,
      name: j['name'] as String,
      totalAmount: (j['totalAmount'] as num?)?.toDouble() ?? 0.0,
      peopleCount: (j['peopleCount'] as num?)?.toInt() ?? 1,
      splitAmount: split,
      convoyId: j['convoyId'] as String?,
      completedAt: j['completedAt'] != null
          ? DateTime.tryParse(j['completedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      expenses: rawExpenses,
      participants: parsedParticipants,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'totalAmount': totalAmount,
        'peopleCount': peopleCount,
        'splitAmount': splitAmount,
        if (convoyId != null) 'convoyId': convoyId,
        'completedAt': completedAt.toIso8601String(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'participants': participants.map((p) => p.toJson()).toList(),
      };
}
