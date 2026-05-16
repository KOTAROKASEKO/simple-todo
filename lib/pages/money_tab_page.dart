import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MoneyTabPage extends StatefulWidget {
  const MoneyTabPage({super.key, required this.userId});

  final String userId;

  @override
  State<MoneyTabPage> createState() => _MoneyTabPageState();
}

class _ExpenseEntry {
  const _ExpenseEntry({
    required this.id,
    required this.amount,
    required this.memo,
    required this.createdAt,
  });

  final String id;
  final double amount;
  final String memo;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'amount': amount,
      'memo': memo,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static _ExpenseEntry? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final amountNum = json['amount'];
    final createdAtRaw = json['createdAt'];
    if (id.isEmpty || amountNum is! num || createdAtRaw is! String) {
      return null;
    }
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) return null;
    return _ExpenseEntry(
      id: id,
      amount: amountNum.toDouble(),
      memo: (json['memo'] as String?)?.trim() ?? '',
      createdAt: createdAt,
    );
  }
}

class _MoneyTabPageState extends State<MoneyTabPage> {
  static const String _budgetKey = 'money_tab_monthly_budget_rm';
  static const String _expensesKey = 'money_tab_expenses';
  static const String _updatedAtKey = 'money_tab_updated_at_ms';
  static const String _periodDaysKey = 'money_tab_period_days';
  static const String _periodStartIsoKey = 'money_tab_period_start_iso';
  static const String _moneyBoxName = 'money_tab';

  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _expenseAmountController = TextEditingController();
  final TextEditingController _expenseMemoController = TextEditingController();

  bool _loading = true;
  double _monthlyBudget = 0;
  int _periodDays = 30;
  DateTime _periodStart = DateTime.now();
  List<_ExpenseEntry> _expenses = const [];
  double _graphZoom = 1.0;
  int _localUpdatedAtMs = 0;
  Box<dynamic>? _moneyBox;

  late final DocumentReference<Map<String, dynamic>> _moneyStateRef;

  @override
  void initState() {
    super.initState();
    _budgetController.addListener(_onBudgetInputChanged);
    _moneyStateRef = FirebaseFirestore.instance
        .collection('todo')
        .doc(widget.userId)
        .collection('app_state')
        .doc('money_tab')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        );
    _loadState();
  }

  @override
  void dispose() {
    _budgetController.removeListener(_onBudgetInputChanged);
    _budgetController.dispose();
    _expenseAmountController.dispose();
    _expenseMemoController.dispose();
    super.dispose();
  }

  void _onBudgetInputChanged() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _hasPendingBudgetChanges {
    final trimmed = _budgetController.text.trim();
    if (trimmed.isEmpty) {
      return _monthlyBudget > 0;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) return true;
    return (parsed - _monthlyBudget).abs() > 0.0001;
  }

  Future<void> _loadState() async {
    final budget = await _readBudget();
    final raw = await _readExpensesRaw();
    final updatedAtMs = await _readUpdatedAtMs();
    final periodDays = await _readPeriodDays();
    final periodStart = await _readPeriodStart();
    final decoded = raw == null ? null : jsonDecode(raw);
    final loaded = <_ExpenseEntry>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final parsed = _ExpenseEntry.fromJson(item);
          if (parsed != null) loaded.add(parsed);
        } else if (item is Map) {
          final parsed = _ExpenseEntry.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v)),
          );
          if (parsed != null) loaded.add(parsed);
        }
      }
    }
    loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!mounted) return;
    setState(() {
      _monthlyBudget = budget;
      _localUpdatedAtMs = updatedAtMs;
      _periodDays = periodDays;
      _periodStart = periodStart;
      _budgetController.text = budget > 0 ? budget.toStringAsFixed(0) : '';
      _expenses = loaded;
      _loading = false;
    });
    unawaited(_syncFromFirestore());
  }

  Future<double> _readBudget() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_budgetKey) ?? 0;
    }
    final box = await _openMoneyBox();
    return (box.get(_budgetKey) as num?)?.toDouble() ?? 0;
  }

  Future<String?> _readExpensesRaw() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_expensesKey);
    }
    final box = await _openMoneyBox();
    return box.get(_expensesKey) as String?;
  }

  Future<Box<dynamic>> _openMoneyBox() async {
    final existing = _moneyBox;
    if (existing != null && existing.isOpen) return existing;
    final box = await Hive.openBox<dynamic>(_moneyBoxName);
    _moneyBox = box;
    return box;
  }

  Future<int> _readUpdatedAtMs() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_updatedAtKey) ?? 0;
    }
    final box = await _openMoneyBox();
    return (box.get(_updatedAtKey) as num?)?.toInt() ?? 0;
  }

  Future<int> _readPeriodDays() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getInt(_periodDaysKey) ?? 30).clamp(1, 3650);
    }
    final box = await _openMoneyBox();
    return ((box.get(_periodDaysKey) as num?)?.toInt() ?? 30).clamp(1, 3650);
  }

  Future<DateTime> _readPeriodStart() async {
    final fallbackNow = DateTime.now();
    final fallback =
        DateTime(fallbackNow.year, fallbackNow.month, fallbackNow.day);
    String? raw;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_periodStartIsoKey);
    } else {
      final box = await _openMoneyBox();
      raw = box.get(_periodStartIsoKey) as String?;
    }
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    if (parsed == null) return fallback;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  Future<void> _persistLocalState({required int updatedAtMs}) async {
    _localUpdatedAtMs = updatedAtMs;
    final encoded = jsonEncode(_expenses.map((e) => e.toJson()).toList());
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_budgetKey, _monthlyBudget);
      await prefs.setString(_expensesKey, encoded);
      await prefs.setInt(_updatedAtKey, updatedAtMs);
      await prefs.setInt(_periodDaysKey, _periodDays);
      await prefs.setString(_periodStartIsoKey, _periodStart.toIso8601String());
      return;
    }
    final box = await _openMoneyBox();
    await box.put(_budgetKey, _monthlyBudget);
    await box.put(_expensesKey, encoded);
    await box.put(_updatedAtKey, updatedAtMs);
    await box.put(_periodDaysKey, _periodDays);
    await box.put(_periodStartIsoKey, _periodStart.toIso8601String());
  }

  Future<void> _syncFromFirestore() async {
    try {
      final snap = await _moneyStateRef.get();
      final data = snap.data();
      if (data == null || data.isEmpty) return;
      final remoteUpdatedAtMs = (data['updatedAtMs'] as num?)?.toInt() ?? 0;
      if (remoteUpdatedAtMs <= _localUpdatedAtMs) return;
      final remoteBudget = (data['monthlyBudget'] as num?)?.toDouble() ?? 0;
      final remotePeriodDays =
          ((data['periodDays'] as num?)?.toInt() ?? 30).clamp(1, 3650);
      final remotePeriodStartRaw = data['periodStartIso'] as String?;
      final remotePeriodStart = DateTime.tryParse(remotePeriodStartRaw ?? '');
      final loaded = <_ExpenseEntry>[];
      final rawExpenses = data['expenses'];
      if (rawExpenses is List) {
        for (final item in rawExpenses) {
          if (item is Map<String, dynamic>) {
            final parsed = _ExpenseEntry.fromJson(item);
            if (parsed != null) loaded.add(parsed);
          } else if (item is Map) {
            final parsed = _ExpenseEntry.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            );
            if (parsed != null) loaded.add(parsed);
          }
        }
      }
      loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _monthlyBudget = remoteBudget;
      _periodDays = remotePeriodDays;
      if (remotePeriodStart != null) {
        _periodStart = DateTime(
          remotePeriodStart.year,
          remotePeriodStart.month,
          remotePeriodStart.day,
        );
      }
      _expenses = loaded;
      await _persistLocalState(updatedAtMs: remoteUpdatedAtMs);
      if (!mounted) return;
      setState(() {
        _budgetController.text = _monthlyBudget > 0
            ? _monthlyBudget.toStringAsFixed(0)
            : '';
      });
    } catch (_) {}
  }

  Future<void> _pushToFirestore({required int updatedAtMs}) async {
    try {
      await _moneyStateRef.set(<String, dynamic>{
        'monthlyBudget': _monthlyBudget,
        'periodDays': _periodDays,
        'periodStartIso': _periodStart.toIso8601String(),
        'expenses': _expenses.map((e) => e.toJson()).toList(),
        'updatedAtMs': updatedAtMs,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _persistBudget() async {
    final value = double.tryParse(_budgetController.text.trim());
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a monthly budget greater than 0.'),
        ),
      );
      return;
    }
    final updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    setState(() {
      _monthlyBudget = value;
      _periodStart = todayStart;
    });
    await _persistLocalState(updatedAtMs: updatedAtMs);
    unawaited(_pushToFirestore(updatedAtMs: updatedAtMs));
    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickPeriodEndDate() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final firstDate = todayStart;
    final lastDate = DateTime(now.year + 5, 12, 31);
    final currentEnd = todayStart.add(Duration(days: _periodDays - 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: currentEnd,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select budget end date',
    );
    if (picked == null || !mounted) return;
    final normalizedEnd = DateTime(picked.year, picked.month, picked.day);
    final days = normalizedEnd.difference(todayStart).inDays + 1;
    if (days <= 0) return;
    final updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _periodStart = todayStart;
      _periodDays = days;
    });
    await _persistLocalState(updatedAtMs: updatedAtMs);
    unawaited(_pushToFirestore(updatedAtMs: updatedAtMs));
  }

  Future<void> _persistExpenses() async {
    final updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    await _persistLocalState(updatedAtMs: updatedAtMs);
    unawaited(_pushToFirestore(updatedAtMs: updatedAtMs));
  }

  Future<void> _addExpense() async {
    final amount = double.tryParse(_expenseAmountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an expense amount greater than 0.'),
        ),
      );
      return;
    }
    final now = DateTime.now();
    final entry = _ExpenseEntry(
      id: now.microsecondsSinceEpoch.toString(),
      amount: amount,
      memo: _expenseMemoController.text.trim(),
      createdAt: now,
    );
    setState(() {
      _expenses = [entry, ..._expenses];
      _expenseAmountController.clear();
      _expenseMemoController.clear();
    });
    await _persistExpenses();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  Future<void> _deleteExpense(String id) async {
    setState(() {
      _expenses = _expenses.where((e) => e.id != id).toList();
    });
    await _persistExpenses();
  }

  void _updateGraphZoom(DragUpdateDetails details) {
    setState(() {
      _graphZoom = (_graphZoom - (details.delta.dx * 0.01)).clamp(1.0, 3.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final periodStart = todayStart;
    final periodEndInclusive = periodStart.add(Duration(days: _periodDays - 1));
    final periodEndExclusive = periodEndInclusive.add(const Duration(days: 1));
    final totalDays = periodEndInclusive.difference(periodStart).inDays + 1;
    final periodExpenses = _expenses.where((e) {
      return !e.createdAt.isBefore(periodStart) &&
          e.createdAt.isBefore(periodEndExclusive);
    });
    final spentInPeriod = periodExpenses.fold<double>(
      0.0,
      (total, e) => total + e.amount,
    );
    final elapsedDays = todayStart.isBefore(periodStart)
        ? 0
        : (todayStart.difference(periodStart).inDays + 1).clamp(0, totalDays);
    final budgetRemainingThisMonth = _monthlyBudget - spentInPeriod;
    final expectedSpendByToday = _monthlyBudget <= 0
        ? 0.0
        : _monthlyBudget * (elapsedDays / totalDays);

    String money(double value) => '${value.toStringAsFixed(2)} RM';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Budget Plan',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 180,
              child: TextField(
                controller: _budgetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Budget (RM)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 170,
              child: OutlinedButton.icon(
                onPressed: _pickPeriodEndDate,
                icon: const Icon(Icons.event),
                label: Text(
                  'Until ${periodEndInclusive.month}/${periodEndInclusive.day}',
                ),
              ),
            ),
            if (_hasPendingBudgetChanges)
              FilledButton(
                onPressed: _persistBudget,
                child: const Text('Save'),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Budget Progress',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 10,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Expected expense: ${money(expectedSpendByToday)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2563EB),
                          ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: spentInPeriod > expectedSpendByToday
                          ? Theme.of(context).colorScheme.error
                          : const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Actual expense: ${money(spentInPeriod)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: spentInPeriod > expectedSpendByToday
                                ? Theme.of(context).colorScheme.error
                                : Colors.green.shade700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onHorizontalDragUpdate: _updateGraphZoom,
                  onDoubleTap: () => setState(() => _graphZoom = 1.0),
                  behavior: HitTestBehavior.opaque,
                  child: _BudgetProgressLine(
                    budget: _monthlyBudget,
                    expected: expectedSpendByToday,
                    actual: spentInPeriod,
                    startLabel: '${periodStart.month}/${periodStart.day}',
                    endLabel:
                        '${periodEndInclusive.month}/${periodEndInclusive.day}',
                    zoom: _graphZoom,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Remaining budget: ${money(budgetRemainingThisMonth)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Add Expense',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _expenseAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount (RM)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _expenseMemoController,
          decoration: const InputDecoration(
            labelText: 'Memo (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _addExpense,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add expense'),
        ),
        const SizedBox(height: 16),
        Text(
          'Expense history (this period)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        if (periodExpenses.isEmpty)
          Text(
            'No expenses yet.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...periodExpenses.map((e) {
            final dateText =
                '${e.createdAt.month}/${e.createdAt.day} ${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}';
            return Card(
              child: ListTile(
                title: Text(money(e.amount)),
                subtitle: Text(
                  e.memo.isEmpty ? dateText : '$dateText  ·  ${e.memo}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteExpense(e.id),
                ),
              ),
            );
          }),
      ],
    );
  }

}

class _BudgetProgressLine extends StatelessWidget {
  const _BudgetProgressLine({
    required this.budget,
    required this.expected,
    required this.actual,
    required this.startLabel,
    required this.endLabel,
    this.zoom = 1.0,
  });

  final double budget;
  final double expected;
  final double actual;
  final String startLabel;
  final String endLabel;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final safeBudget = budget <= 0 ? 1.0 : budget;
    final expectedRemaining = (budget - expected).clamp(0.0, safeBudget);
    final actualRemaining = (budget - actual).clamp(0.0, safeBudget);
    final expectedProgress = 1 - (expectedRemaining / safeBudget).clamp(0.0, 1.0);
    final actualProgress = 1 - (actualRemaining / safeBudget).clamp(0.0, 1.0);
    final overBudget = actual > budget && budget > 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double zoomPoint(double progress) {
          final centered = 0.5 + ((progress - 0.5) * zoom);
          return (width * centered).clamp(0.0, width);
        }

        final expectedX = zoomPoint(expectedProgress);
        final actualX = zoomPoint(actualProgress);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 72,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 34,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 34,
                    child: Container(
                      width: 2,
                      height: 22,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 34,
                    child: Container(
                      width: 2,
                      height: 22,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  Positioned(
                    left: expectedX - 6,
                    top: 28,
                    child: _MarkerDot(
                      color: const Color(0xFF2563EB),
                      label: 'Expected',
                    ),
                  ),
                  Positioned(
                    left: expectedX - 1,
                    top: 14,
                    child: Container(
                      width: 2,
                      height: 14,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  Positioned(
                    left: (expectedX - 70).clamp(0.0, width - 140),
                    top: 0,
                    child: SizedBox(
                      width: 70,
                      child: Text(
                        ' ${expected.toStringAsFixed(2)} RM',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF2563EB),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: actualX - 6,
                    top: 28,
                    child: _MarkerDot(
                      color: overBudget
                          ? Theme.of(context).colorScheme.error
                          : const Color(0xFF16A34A),
                      label: 'Actual',
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  budget > 0
                      ? '${budget.toStringAsFixed(0)} RM ($startLabel)'
                      : startLabel,
                ),
                Text('0 ($endLabel)'),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _MarkerDot extends StatelessWidget {
  const _MarkerDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
