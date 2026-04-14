import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:simpletodo/journal_ai_unlock.dart';

class NotEnoughCoinsException implements Exception {}

/// Unlocks a journal AI character if the user has enough [taskCoins].
Future<JournalUnlockResult> unlockJournalCharacterWithCoins({
  required String uid,
  required String characterId,
}) async {
  if (isJournalCharacterFree(characterId)) {
    return JournalUnlockResult.ok;
  }
  final cost = unlockCostForJournalCharacter(characterId);
  if (cost <= 0) {
    return JournalUnlockResult.ok;
  }
  final userRef = FirebaseFirestore.instance.collection('todo').doc(uid);
  try {
    final pre = await userRef.get();
    final preData = pre.data() ?? <String, dynamic>{};
    final already = parseUnlockedJournalCharacters(
      preData['unlockedJournalAiCharacters'],
    ).contains(characterId);
    if (already) {
      return JournalUnlockResult.ok;
    }
    final preCoins = (preData['taskCoins'] as num?)?.toInt() ?? 0;
    if (preCoins < cost) {
      return JournalUnlockResult.notEnoughCoins;
    }

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final data = snap.data() ?? <String, dynamic>{};
      final unlocked = parseUnlockedJournalCharacters(
        data['unlockedJournalAiCharacters'],
      );
      if (unlocked.contains(characterId)) {
        return;
      }
      final coins = (data['taskCoins'] as num?)?.toInt() ?? 0;
      if (coins < cost) {
        throw NotEnoughCoinsException();
      }
      tx.set(
        userRef,
        <String, dynamic>{
          'taskCoins': FieldValue.increment(-cost),
          'unlockedJournalAiCharacters': FieldValue.arrayUnion([characterId]),
        },
        SetOptions(merge: true),
      );
    });
    return JournalUnlockResult.ok;
  } on NotEnoughCoinsException {
    return JournalUnlockResult.notEnoughCoins;
  } catch (_) {
    return JournalUnlockResult.error;
  }
}

enum JournalUnlockResult {
  ok,
  notEnoughCoins,
  error,
}
