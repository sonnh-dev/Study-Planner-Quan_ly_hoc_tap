import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:studyplaner/data/notification_service.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, required this.notifications});
  final NotificationService notifications;
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  static const _notificationId = 817291;
  Timer? _timer;
  int _seconds = 25 * 60;
  int _duration = 25;
  bool _running = false;
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _choose(int minutes) {
    if (_running) return;
    setState(() {
      _duration = minutes;
      _seconds = minutes * 60;
    });
  }

  Future<void> _start() async {
    if (_seconds <= 0) setState(() => _seconds = _duration * 60);
    setState(() => _running = true);
    await widget.notifications.schedule(
      _notificationId,
      'Hẹn giờ tập trung đã kết thúc',
      DateTime.now().add(Duration(seconds: _seconds)),
    );
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds <= 1) {
        timer.cancel();
        setState(() {
          _seconds = 0;
          _running = false;
        });
        return;
      }
      setState(() => _seconds--);
    });
  }

  void _pause() {
    _timer?.cancel();
    widget.notifications.cancel(_notificationId);
    setState(() => _running = false);
  }

  String get _clock =>
      '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.spa_outlined,
                size: 40,
                color: Color(0xFF5678E8),
              ),
              const SizedBox(height: 12),
              Text(
                'Phiên tập trung',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Hẹn giờ chạy ngay trên thiết bị, không cần mạng.'),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                children: [25, 45, 60]
                    .map(
                      (minutes) => ChoiceChip(
                        label: Text('$minutes phút'),
                        selected: _duration == minutes,
                        onSelected: (_) => _choose(minutes),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              Text(
                _clock,
                style: const TextStyle(
                  fontSize: 78,
                  height: 1,
                  fontWeight: FontWeight.w300,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _running ? _pause : _start,
                icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                label: Text(_running ? 'Tạm dừng' : 'Bắt đầu'),
              ),
              TextButton(
                onPressed: () {
                  _timer?.cancel();
                  widget.notifications.cancel(_notificationId);
                  setState(() {
                    _seconds = _duration * 60;
                    _running = false;
                  });
                },
                child: const Text('Đặt lại'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
