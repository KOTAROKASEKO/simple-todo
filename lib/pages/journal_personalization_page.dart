import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:simpletodo/journal_ai_unlock.dart';
import 'package:simpletodo/push_notification_service.dart';
import 'package:simpletodo/services/journal_character_unlock.dart';
import 'dart:convert';

const int _kJournalPersonalizationMaxChars = 10000;
const int _kJournalImportantProfileMaxChars = 10000;
const int _kJournalReminderGreetingMaxChars = 40;
const Map<String, String> _kJournalAiCharacterLabels = {
  'default': 'Default assistant',
  'gyaru': '美咲 · 元気なギャル AI',
  'kopitiam_uncle': 'Wong · Kopitiam おじさん AI',
  'chinese_auntie': 'Yin · 元気なおばちゃん AI',
};

/// Free-form notes stored on `todo/{uid}` as [journalPersonalization] for journal AI.
class JournalPersonalizationPage extends StatefulWidget {
  const JournalPersonalizationPage({super.key});

  @override
  State<JournalPersonalizationPage> createState() =>
      _JournalPersonalizationPageState();
}

class _JournalPersonalizationPageState extends State<JournalPersonalizationPage> {
  final _personalizationController = TextEditingController();
  final _importantProfileController = TextEditingController();
  final _reminderGreetingController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String _character = 'default';
  /// Snapshot of [ _character ] after load; used to detect an explicit AI change + save.
  String _characterAtLoad = 'default';
  bool _dailyJournalReminderEnabled = false;
  bool _dailyReminderEnabledAtLoad = false;
  bool _sendingTestReminder = false;
  List<String> _unlockedCharacters = [kJournalAiDefaultCharacterId];
  int _taskCoins = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _personalizationController.dispose();
    _importantProfileController.dispose();
    _reminderGreetingController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _characterAtLoad = _character;
          _loading = false;
        });
      }
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('todo')
          .doc(uid)
          .get();
      final data = snap.data() ?? <String, dynamic>{};
      final raw = data['journalPersonalization'];
      if (raw is String && mounted) {
        _personalizationController.text = raw;
      }
      final profileRaw = data['journalImportantProfile'];
      if (profileRaw is Map && mounted) {
        const encoder = JsonEncoder.withIndent('  ');
        _importantProfileController.text = encoder.convert(
          Map<String, dynamic>.from(profileRaw),
        );
      }
      final unlockedRaw = data['unlockedJournalAiCharacters'];
      if (mounted) {
        _unlockedCharacters =
            parseUnlockedJournalCharacters(unlockedRaw);
      }
      final coinRaw = data['taskCoins'];
      if (coinRaw is num && mounted) {
        _taskCoins = coinRaw.toInt();
      }
      final characterRaw = data['journalAiCharacter'];
      if (characterRaw is String &&
          _kJournalAiCharacterLabels.containsKey(characterRaw) &&
          mounted) {
        _character = characterRaw;
      }
      if (mounted &&
          !isJournalCharacterUnlockedForList(_character, _unlockedCharacters)) {
        _character = kJournalAiDefaultCharacterId;
      }
      final reminderEn = data['journalDailyReminderEnabled'];
      if (reminderEn is bool && mounted) {
        _dailyJournalReminderEnabled = reminderEn;
        _dailyReminderEnabledAtLoad = reminderEn;
      }
      final greet = data['journalDailyReminderGreetingName'];
      if (greet is String && mounted) {
        _reminderGreetingController.text = greet;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _characterAtLoad = _character;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final text = _personalizationController.text;
    final profileText = _importantProfileController.text.trim();
    if (text.length > _kJournalPersonalizationMaxChars) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum $_kJournalPersonalizationMaxChars characters.',
          ),
        ),
      );
      return;
    }
    if (profileText.length > _kJournalImportantProfileMaxChars) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Important profile JSON must be <= $_kJournalImportantProfileMaxChars characters.',
          ),
        ),
      );
      return;
    }
    Map<String, dynamic> profileMap = <String, dynamic>{};
    if (profileText.isNotEmpty) {
      try {
        final parsed = jsonDecode(profileText);
        if (parsed is! Map) {
          throw const FormatException('JSON must be an object');
        }
        profileMap = Map<String, dynamic>.from(parsed);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Important profile must be valid JSON object: $e'),
          ),
        );
        return;
      }
    }
    final greeting = _reminderGreetingController.text.trim();
    if (greeting.length > _kJournalReminderGreetingMaxChars) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notification name must be <= $_kJournalReminderGreetingMaxChars characters.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (!kIsWeb && mounted && _character != _characterAtLoad) {
        await PushNotificationService.instance.showRationaleAndRequestPush(
          context,
          title: 'Journal AI',
          message:
              'Allow notifications so we can alert you when your journal AI has a surprise reply ready.',
        );
      }
      if (!kIsWeb &&
          mounted &&
          _dailyJournalReminderEnabled &&
          !_dailyReminderEnabledAtLoad) {
        await PushNotificationService.instance.showRationaleAndRequestPush(
          context,
          title: 'Journal reminder',
          message:
              'Allow notifications for your daily 8 PM journal nudge in your AI character’s voice.',
        );
      }
      if (!mounted) return;
      await FirebaseFirestore.instance.collection('todo').doc(uid).set(
        <String, dynamic>{
          'journalPersonalization': text,
          'journalImportantProfile': profileMap,
          'journalAiCharacter': _character,
          'journalDailyReminderEnabled': _dailyJournalReminderEnabled,
          'journalDailyReminderTimeZoneOffsetMinutes':
              DateTime.now().timeZoneOffset.inMinutes,
          'journalDailyReminderGreetingName': greeting,
        },
        SetOptions(merge: true),
      );
      if (!mounted) return;
      setState(() {
        _dailyReminderEnabledAtLoad = _dailyJournalReminderEnabled;
        _characterAtLoad = _character;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendTestJournalReminder() async {
    if (kIsWeb) return;
    setState(() => _sendingTestReminder = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('sendTestJournalDailyReminder');
      await callable.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test reminder sent. Check your device.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is FirebaseFunctionsException
          ? (e.message ?? 'Failed to send test.')
          : 'Failed: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _sendingTestReminder = false);
    }
  }

  Future<void> _onCharacterDropdownChanged(String? value) async {
    if (value == null || _saving) return;
    if (isJournalCharacterUnlockedForList(value, _unlockedCharacters)) {
      setState(() => _character = value);
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final cost = unlockCostForJournalCharacter(value);
    final label = _kJournalAiCharacterLabels[value] ?? value;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unlock $label?'),
        content: Text(
          'Spend $cost coins to unlock this voice. You currently have $_taskCoins.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final r = await unlockJournalCharacterWithCoins(
      uid: uid,
      characterId: value,
    );
    if (!mounted) return;
    switch (r) {
      case JournalUnlockResult.notEnoughCoins:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough coins.')),
        );
      case JournalUnlockResult.error:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not unlock. Try again.')),
        );
      case JournalUnlockResult.ok:
        setState(() {
          if (!_unlockedCharacters.contains(value)) {
            _unlockedCharacters = [..._unlockedCharacters, value]..sort();
          }
          _taskCoins = (_taskCoins - cost).clamp(0, 2000000);
          _character = value;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Journal AI notes',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.grey.shade700),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.indigo.shade600,
                      ),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.indigo.shade700,
                      ),
                    ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text(
                    'トーンや、知っておいてほしいこと、避けてほしいことなど、文章で自由に書けます。'
                    'ジャーナルへのサプライズ返信の参考にします。',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _personalizationController,
                    maxLines: null,
                    minLines: 8,
                    maxLength: _kJournalPersonalizationMaxChars,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: '例：ユーモア多めで。短めが好き。仕事のジャーナルでは実務寄りで…',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'AI character',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Earn coins by completing tasks. Extra voices cost coins to unlock.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your balance: $_taskCoins coins',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(_character),
                    initialValue: _character,
                    items: _kJournalAiCharacterLabels.entries.map((e) {
                      final locked = !isJournalCharacterUnlockedForList(
                        e.key,
                        _unlockedCharacters,
                      );
                      final cost = unlockCostForJournalCharacter(e.key);
                      return DropdownMenuItem<String>(
                        value: e.key,
                        child: Row(
                          children: [
                            if (locked)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(
                                  Icons.lock_outline_rounded,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                locked && cost > 0
                                    ? '${e.value} ($cost coins)'
                                    : e.value,
                                style: TextStyle(
                                  color: locked
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: _loading || _saving ? null : _onCharacterDropdownChanged,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Daily journal reminder (8 PM)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    kIsWeb
                        ? 'Push reminders are not available on web.'
                        : 'One notification per day around 8 PM in your time zone. '
                            'The message matches your AI character (fixed phrases — no extra AI cost).',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      title: Text(
                        'Remind me to write',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      value: kIsWeb ? false : _dailyJournalReminderEnabled,
                      onChanged: kIsWeb || _saving
                          ? null
                          : (v) {
                              setState(() => _dailyJournalReminderEnabled = v);
                            },
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reminderGreetingController,
                    maxLength: _kJournalReminderGreetingMaxChars,
                    enabled: !kIsWeb && _dailyJournalReminderEnabled,
                    decoration: InputDecoration(
                      labelText:
                          '呼ばれたい名前（通知・AI返信。ジャーナル保存時のキャラ選択でも設定可）',
                      hintText: '例：ねね',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: (_saving || _sendingTestReminder)
                          ? null
                          : _sendTestJournalReminder,
                      icon: _sendingTestReminder
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.notifications_active_outlined,
                              size: 20),
                      label: Text(
                        _sendingTestReminder ? 'Sending…' : 'Send test reminder',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Important profile JSON',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'AI が毎回参照する重要情報を JSON で保存します（例: goals, preferences, constraints）。',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _importantProfileController,
                    maxLines: null,
                    minLines: 8,
                    maxLength: _kJournalImportantProfileMaxChars,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: '{\n  "goals": ["..."],\n  "preferences": {"tone": "short"}\n}',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
