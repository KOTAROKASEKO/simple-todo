import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SuperImportantAlarmPage extends StatefulWidget {
  const SuperImportantAlarmPage({
    super.key,
    required this.title,
    this.scheduledAtMillis,
  });

  final String title;
  final int? scheduledAtMillis;

  @override
  State<SuperImportantAlarmPage> createState() =>
      _SuperImportantAlarmPageState();
}

class _SuperImportantAlarmPageState extends State<SuperImportantAlarmPage> {
  final AudioPlayer _player = AudioPlayer();
  Timer? _hapticTicker;
  bool _audioStarted = false;

  @override
  void initState() {
    super.initState();
    // Keep the alarm audible by the user regardless of device ringer, and
    // loop until they dismiss. Using the alarm audio context routes through
    // the alarm stream on Android, so it bypasses media/notification volume
    // in DND / silent scenarios.
    unawaited(_startAlarmAudio());
    _startHapticLoop();
  }

  Future<void> _startAlarmAudio() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const <AVAudioSessionOptions>{
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sound/timer_end.mp3'));
      _audioStarted = true;
    } catch (e) {
      debugPrint('[SuperImportantAlarm] audio failed: $e');
    }
  }

  void _startHapticLoop() {
    // Pulse haptics roughly twice a second while the alarm is showing,
    // mirroring the OS alarm clock feel.
    _hapticTicker = Timer.periodic(const Duration(milliseconds: 700), (_) {
      HapticFeedback.heavyImpact();
    });
  }

  Future<void> _stopAll() async {
    _hapticTicker?.cancel();
    _hapticTicker = null;
    if (_audioStarted) {
      try {
        await _player.stop();
      } catch (_) {}
    }
    try {
      await _player.release();
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_stopAll());
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final when = widget.scheduledAtMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(widget.scheduledAtMillis!)
            .toLocal();
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          unawaited(_stopAll());
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF101015),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.alarm_rounded,
                        color: Colors.red.shade300, size: 28),
                    const SizedBox(width: 10),
                    const Text(
                      'Super Important Alarm',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                if (when != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Scheduled: ${TimeOfDay.fromDateTime(when).format(context)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                ],
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  onPressed: () async {
                    await _stopAll();
                    if (!mounted) return;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
