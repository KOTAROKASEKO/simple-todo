import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TaskTimerPage extends StatefulWidget {
  const TaskTimerPage({
    super.key,
    required this.taskTitle,
    required this.initialDuration,
  });

  final String taskTitle;
  final Duration initialDuration;

  @override
  State<TaskTimerPage> createState() => _TaskTimerPageState();
}

class _TaskTimerPageState extends State<TaskTimerPage> {
  // Keep the interactive range focused on realistic task sessions, so the
  // slider feels precise (small drags don't jump huge durations).
  static const int _kMaxMinutes = 180; // up to 3 hours

  late int _targetMinutes;
  late int _remainingSeconds;
  Timer? _ticker;
  bool _running = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    final m = widget.initialDuration.inMinutes;
    _targetMinutes = m.clamp(1, _kMaxMinutes);
    _remainingSeconds = _targetMinutes * 60;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setTargetMinutes(int minutes) {
    if (_running) return;
    final m = minutes.clamp(1, _kMaxMinutes);
    setState(() {
      _targetMinutes = m;
      _remainingSeconds = m * 60;
    });
  }

  void _nudgeMinutes(int delta) {
    _setTargetMinutes(_targetMinutes + delta);
  }

  void _start() {
    if (_remainingSeconds <= 0) {
      _remainingSeconds = _targetMinutes * 60;
    }
    setState(() => _running = true);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        _ticker?.cancel();
        _ticker = null;
        setState(() {
          _remainingSeconds = 0;
          _running = false;
        });
        unawaited(
          _audioPlayer.play(AssetSource('sound/timer_end.mp3')).catchError((_) {
            SystemSound.play(SystemSoundType.alert);
          }),
        );
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time is up')),
        );
        return;
      }
      setState(() {
        _remainingSeconds -= 1;
      });
    });
  }

  void _pause() {
    _ticker?.cancel();
    _ticker = null;
    setState(() => _running = false);
  }

  void _reset() {
    _ticker?.cancel();
    _ticker = null;
    setState(() {
      _remainingSeconds = _targetMinutes * 60;
      _running = false;
    });
  }

  String _formatSeconds(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:$mm:$ss';
    }
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final canAdjust = !_running;
    final totalTargetSeconds = _targetMinutes * 60;
    final bool canResume =
        !_running && _remainingSeconds > 0 && _remainingSeconds < totalTargetSeconds;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleColor = scheme.onSurface;
    final bodyMuted = scheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Timer',
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: titleColor),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                widget.taskTitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  _formatSeconds(_remainingSeconds),
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: titleColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                canAdjust
                    ? '$_targetMinutes min — drag slider or use steppers'
                    : 'Running — pause to change length',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: bodyMuted,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    onPressed: canAdjust && _targetMinutes > 1
                        ? () => _nudgeMinutes(-1)
                        : null,
                    icon: const Icon(Icons.remove),
                    tooltip: '-1 min',
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: canAdjust && _targetMinutes < _kMaxMinutes
                        ? () => _nudgeMinutes(1)
                        : null,
                    icon: const Icon(Icons.add),
                    tooltip: '+1 min',
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: canAdjust && _targetMinutes > 5
                        ? () => _nudgeMinutes(-5)
                        : null,
                    icon: const Text(
                      '−5',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    tooltip: '-5 min',
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: canAdjust && _targetMinutes <= _kMaxMinutes - 5
                        ? () => _nudgeMinutes(5)
                        : null,
                    icon: const Text(
                      '+5',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    tooltip: '+5 min',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  showValueIndicator: ShowValueIndicator.onlyForContinuous,
                ),
                child: Slider(
                  min: 1,
                  max: _kMaxMinutes.toDouble(),
                  divisions: _kMaxMinutes - 1,
                  label: '$_targetMinutes min',
                  value: _targetMinutes.toDouble().clamp(1, _kMaxMinutes.toDouble()),
                  onChanged: canAdjust
                      ? (v) => _setTargetMinutes(v.round())
                      : null,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _running
                        ? _pause
                        : _start,
                    icon: Icon(
                      _running
                          ? Icons.pause
                          : (canResume ? Icons.play_arrow_rounded : Icons.play_arrow),
                    ),
                    label: Text(
                      _running
                          ? 'Pause'
                          : (canResume ? 'Resume' : 'Start'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Stop'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
