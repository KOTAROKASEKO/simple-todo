/// Coins for completing a recurring daily task on streak day 1 … 7 (day 7 is the jackpot).
const List<int> kRecurringStreakCoinsByDay = [1, 1, 2, 2, 3, 4, 15];

/// One-time task completion reward.
const int kOneTimeTaskCoinReward = 1;

String taskRewardDayKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String taskRewardYesterdayKey(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  return taskRewardDayKey(local.subtract(const Duration(days: 1)));
}

/// Extra fields merged into the task document when a reward is granted.
class TaskCompletionReward {
  const TaskCompletionReward({required this.coins, required this.taskPatches});

  final int coins;
  final Map<String, dynamic> taskPatches;
}

/// When the task becomes done for [selectedDate] and was not done before for that day.
TaskCompletionReward computeTaskCompletionReward({
  required Map<String, dynamic> data,
  required DateTime selectedDate,
  required bool wasDoneForDay,
  required bool nowDoneForDay,
}) {
  if (!nowDoneForDay || wasDoneForDay) {
    return const TaskCompletionReward(coins: 0, taskPatches: {});
  }
  final selectedKey = taskRewardDayKey(selectedDate);
  final lastReward = data['lastTaskRewardDayKey'] as String?;
  if (lastReward == selectedKey) {
    return const TaskCompletionReward(coins: 0, taskPatches: {});
  }

  final isRecurring = (data['isRecurringDaily'] as bool?) ?? false;
  if (!isRecurring) {
    return TaskCompletionReward(
      coins: kOneTimeTaskCoinReward,
      taskPatches: <String, dynamic>{'lastTaskRewardDayKey': selectedKey},
    );
  }

  var tier = ((data['recurringStreakRewardDay'] as num?)?.toInt() ?? 1).clamp(1, 7);
  final lastPaid = data['recurringStreakLastPaidDayKey'] as String?;
  final yesterday = taskRewardYesterdayKey(selectedDate);
  if (lastPaid != null && lastPaid != yesterday) {
    tier = 1;
  }

  final coins = kRecurringStreakCoinsByDay[tier - 1];
  final newNextTier = tier >= 7 ? 1 : tier + 1;

  return TaskCompletionReward(
    coins: coins,
    taskPatches: <String, dynamic>{
      'lastTaskRewardDayKey': selectedKey,
      'recurringStreakRewardDay': newNextTier,
      'recurringStreakLastPaidDayKey': selectedKey,
    },
  );
}
