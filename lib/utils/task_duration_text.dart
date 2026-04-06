// Detects time hints in task titles (minutes) for showing a timer affordance.

final List<RegExp> _minutePatterns = <RegExp>[
  RegExp(r'(\d+)\s*(?:min|mins|minute|minutes)\b', caseSensitive: false),
  RegExp(r'(\d+)\s*min\b', caseSensitive: false),
  RegExp(r'(\d+)分'),
];

/// Returns a positive minute count if [text] contains a supported expression, else null.
int? parseMinutesFromTaskTitle(String text) {
  if (text.trim().isEmpty) return null;
  for (final re in _minutePatterns) {
    final m = re.firstMatch(text);
    if (m == null) continue;
    final n = int.tryParse(m.group(1) ?? '');
    if (n == null || n <= 0) continue;
    if (n > 24 * 60) continue;
    return n;
  }
  return null;
}

/// Whether [title] looks like it mentions a duration in minutes.
bool taskTitleSuggestsDuration(String title) =>
    parseMinutesFromTaskTitle(title) != null;
