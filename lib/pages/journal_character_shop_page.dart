import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:simpletodo/journal_ai_character_assets.dart';
import 'package:simpletodo/journal_ai_unlock.dart';
import 'package:simpletodo/services/journal_character_unlock.dart';
import 'package:simpletodo/widgets/journal_ai_character_avatar.dart';

/// Spend task points to unlock journal AI voices. Opened from the home coin chip.
class JournalCharacterShopPage extends StatefulWidget {
  const JournalCharacterShopPage({super.key});

  @override
  State<JournalCharacterShopPage> createState() =>
      _JournalCharacterShopPageState();
}

class _JournalCharacterShopPageState extends State<JournalCharacterShopPage> {
  String? _unlockingId;

  static String _characterLabel(String id) {
    switch (id) {
      case 'gyaru':
        return 'Gyaru';
      case 'kopitiam_uncle':
        return 'Kopitiam Uncle';
      case 'chinese_auntie':
        return 'Chinese Auntie';
      default:
        return 'Default';
    }
  }

  Future<void> _unlock(String characterId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _unlockingId = characterId);
    try {
      final r = await unlockJournalCharacterWithCoins(
        uid: uid,
        characterId: characterId,
      );
      if (!mounted) return;
      switch (r) {
        case JournalUnlockResult.notEnoughCoins:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not enough task points.')),
          );
        case JournalUnlockResult.error:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not unlock. Try again.')),
          );
        case JournalUnlockResult.ok:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_characterLabel(characterId)} unlocked.'),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _unlockingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final scheme = Theme.of(context).colorScheme;
    final coinAccent = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFD66A)
        : const Color(0xFFE65100);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'AI characters',
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      body: uid == null
          ? Center(
              child: Text(
                'Sign in to unlock voices.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('todo')
                  .doc(uid)
                  .snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data() ?? <String, dynamic>{};
                final coins = (data['taskCoins'] as num?)?.toInt() ?? 0;
                final unlocked = parseUnlockedJournalCharacters(
                  data['unlockedJournalAiCharacters'],
                );
                final cardFill = scheme.surfaceContainerHighest;
                final borderCol = scheme.outline;
                final positive = const Color(0xFF2E7D32);
                final positiveMuted = scheme.onSurfaceVariant;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.toll_rounded,
                          color: coinAccent,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Your balance: $coins',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: coinAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Complete tasks to earn task points. Spend them to unlock '
                      'extra journal AI voices.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...kJournalAiCharacterIds.map((id) {
                      final cost = unlockCostForJournalCharacter(id);
                      final isFree = isJournalCharacterFree(id);
                      final locked = !isJournalCharacterUnlockedForList(
                        id,
                        unlocked,
                      );
                      final busy = _unlockingId == id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: cardFill,
                          borderRadius: BorderRadius.circular(16),
                          elevation: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderCol),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                JournalAiCharacterAvatar(
                                  characterId: id,
                                  size: 56,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _characterLabel(id),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isFree
                                            ? 'Free'
                                            : locked
                                                ? '$cost task points'
                                                : 'Unlocked',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isFree
                                              ? positive
                                              : locked
                                                  ? coinAccent
                                                  : positiveMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isFree)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: positive,
                                    size: 28,
                                  )
                                else if (locked)
                                  FilledButton(
                                    onPressed: busy || coins < cost
                                        ? null
                                        : () => _unlock(id),
                                    child: busy
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: scheme.onPrimary,
                                            ),
                                          )
                                        : const Text('Unlock'),
                                  )
                                else
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: positive,
                                    size: 28,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
    );
  }
}
