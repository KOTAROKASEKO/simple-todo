import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:simpletodo/notification_service.dart';

/// Page to set the three daily "check your todo list" notification times.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  List<TimeOfDay> _times = [
    const TimeOfDay(hour: 7, minute: 0),
    const TimeOfDay(hour: 12, minute: 0),
    const TimeOfDay(hour: 21, minute: 0),
  ];
  bool _loading = true;
  bool _saving = false;
  bool _sendingTest = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (kIsWeb) {
      setState(() => _loading = false);
      return;
    }
    final times = await NotificationService.instance.getDailyReminderTimes();
    if (mounted) {
      setState(() {
      _times = times.length >= 3 ? times : _times;
      _loading = false;
    });
    }
  }

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
    );
    if (picked == null || !mounted) return;
    setState(() {
      _times = List<TimeOfDay>.from(_times);
      if (_times.length <= index) {
        while (_times.length <= index) {
          _times.add(const TimeOfDay(hour: 12, minute: 0));
        }
      }
      _times[index] = picked;
    });
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  Future<void> _sendTestNotification() async {
    if (kIsWeb) return;
    setState(() => _sendingTest = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('sendTestDailyCheckNotification');
      await callable.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification sent. Check your device.')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is FirebaseFunctionsException
          ? (e.message ?? 'Failed to send test notification.')
          : 'Failed: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }

  Future<void> _save() async {
    if (kIsWeb) return;
    setState(() => _saving = true);
    try {
      await NotificationService.instance.setDailyReminderTimes(_times);
      // Schedule local daily check reminders on supported platforms (Android).
      await NotificationService.instance.scheduleDailyCheckReminders();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('dailyCheckSettings')
            .doc(uid)
            .set({
          'reminderHours': _times.map((t) => t.hour).toList(),
          'timeZoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        }, SetOptions(merge: true));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification times saved.')),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification times')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification times')),
        body: Center(
          child: Text(
            'Daily reminders are not available on web.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Notification times',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.grey.shade700),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set when you want to be reminded to check your todo list (up to 3 times per day).',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              for (int i = 0; i < 3; i++) ...[
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    title: Text(
                      'Reminder ${i + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    trailing: Text(
                      _formatTime(_times[i]),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    onTap: () => _pickTime(i),
                  ),
                ),
                if (i < 2) const SizedBox(height: 12),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: (_saving || _sendingTest) ? null : _sendTestNotification,
                icon: _sendingTest
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.notifications_active_outlined, size: 20),
                label: Text(_sendingTest ? 'Sending...' : 'Send test notification'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
