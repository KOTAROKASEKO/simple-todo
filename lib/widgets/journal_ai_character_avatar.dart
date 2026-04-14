import 'package:flutter/material.dart';
import 'package:simpletodo/journal_ai_character_assets.dart';

/// Rec. 709 luma weights — desaturates for locked / unavailable characters.
const List<double> _kGreyscaleColorMatrix = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Avatar for a journal AI character: bundled [Image.asset] or fallback icon.
class JournalAiCharacterAvatar extends StatelessWidget {
  const JournalAiCharacterAvatar({
    super.key,
    required this.characterId,
    required this.size,
    this.iconColor,
    this.muted = false,
  });

  final String characterId;
  final double size;
  final Color? iconColor;

  /// Greyed-out look (e.g. not yet unlocked).
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final path = kJournalAiCharacterImageAssets[characterId];
    final icon =
        kJournalAiCharacterIcons[characterId] ?? Icons.smart_toy_outlined;
    final color = iconColor ?? Colors.grey.shade700;
    final iconSize = size * 0.55;

    late final Widget core;
    if (path != null) {
      core = ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Icon(
              icon,
              size: iconSize,
              color: color,
            ),
          ),
        ),
      );
    } else {
      core = Icon(
        icon,
        size: iconSize,
        color: color,
      );
    }

    if (!muted) return core;

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(_kGreyscaleColorMatrix),
      child: Opacity(
        opacity: 0.55,
        child: core,
      ),
    );
  }
}
