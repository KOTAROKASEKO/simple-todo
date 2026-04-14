import 'package:flutter/material.dart';

/// Ordered ids for journal AI characters (matches Firestore `journalAiCharacter`).
const List<String> kJournalAiCharacterIds = [
  'default',
  'gyaru',
  'kopitiam_uncle',
  'chinese_auntie',
];

/// Icons when no bundled avatar is defined.
const Map<String, IconData> kJournalAiCharacterIcons = {
  'default': Icons.smart_toy_outlined,
  'gyaru': Icons.bolt_rounded,
  'kopitiam_uncle': Icons.coffee_rounded,
  'chinese_auntie': Icons.local_dining_rounded,
};

/// Bundled avatar images under [assets/images/].
const Map<String, String> kJournalAiCharacterImageAssets = {
  'gyaru': 'assets/images/gyaru.png',
  'kopitiam_uncle': 'assets/images/ojisan.png',
  'chinese_auntie': 'assets/images/obachan.png',
};
