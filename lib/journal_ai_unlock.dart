/// Spend [taskCoins] to unlock extra journal AI voices (Firestore: `unlockedJournalAiCharacters`).
const String kJournalAiDefaultCharacterId = 'default';

const Map<String, int> kJournalAiCharacterUnlockCosts = {
  'gyaru': 10,
  'kopitiam_uncle': 10,
  'chinese_auntie': 10,
};

const Set<String> kJournalAiAllCharacterIds = {
  kJournalAiDefaultCharacterId,
  'gyaru',
  'kopitiam_uncle',
  'chinese_auntie',
};

int unlockCostForJournalCharacter(String id) =>
    kJournalAiCharacterUnlockCosts[id] ?? 0;

bool isJournalCharacterFree(String id) =>
    id == kJournalAiDefaultCharacterId || unlockCostForJournalCharacter(id) <= 0;

List<String> parseUnlockedJournalCharacters(dynamic raw) {
  if (raw is! List) {
    return [kJournalAiDefaultCharacterId];
  }
  final out = <String>{kJournalAiDefaultCharacterId};
  for (final e in raw) {
    if (e is String && kJournalAiAllCharacterIds.contains(e)) {
      out.add(e);
    }
  }
  return out.toList()..sort();
}

bool isJournalCharacterUnlockedForList(String id, List<String> unlocked) {
  if (isJournalCharacterFree(id)) return true;
  return unlocked.contains(id);
}
