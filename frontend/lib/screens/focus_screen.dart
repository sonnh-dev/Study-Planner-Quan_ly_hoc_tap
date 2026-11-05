import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/cupertino.dart' show CupertinoPicker;
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
  static const _presets = [10, 15, 20, 30, 60];

  Timer? _timer;
  Future<void> _notificationUpdate = Future.value();
  int _duration = 30 * 60;
  int _remaining = 30 * 60;
  bool _running = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _choose(int seconds) {
    if (_running) return;
    setState(() {
      _duration = seconds;
      _remaining = seconds;
    });
  }

  Future<void> _editDuration() async {
    final seconds = await showDialog<int>(
      context: context,
      builder: (_) => _FocusDurationDialog(seconds: _duration),
    );
    if (mounted && seconds != null) _choose(seconds);
  }

  void _start() {
    if (_running) return;
    final seconds = _remaining == 0 ? _duration : _remaining;
    setState(() {
      _remaining = seconds;
      _running = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = (seconds - timer.tick).clamp(0, seconds);
      if (left == 0) timer.cancel();
      setState(() {
        _remaining = left;
        _running = left > 0;
      });
    });
    _updateNotification(DateTime.now().add(Duration(seconds: seconds)));
  }

  void _stop({bool reset = false}) {
    _timer?.cancel();
    setState(() {
      _running = false;
      if (reset) _remaining = _duration;
    });
    _updateNotification(null);
  }

  void _updateNotification(DateTime? end) {
    final notifications = widget.notifications;
    _notificationUpdate = _notificationUpdate.then((_) async {
      try {
        if (end == null) {
          await notifications.cancel(_notificationId);
        } else {
          await notifications.schedule(
            _notificationId,
            'Hẹn giờ tập trung đã kết thúc',
            end,
          );
        }
      } catch (_) {
        // The countdown still works if device notifications are unavailable.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clock = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        _clockLabel(_remaining),
        style: const TextStyle(
          fontSize: 68,
          height: 1.1,
          fontWeight: FontWeight.w300,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
    final paused = _remaining > 0 && _remaining < _duration;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.spa_outlined,
                    size: 36,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text('Phiên tập trung', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(
                    'Chạm đồng hồ để đặt thời lượng.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final minutes in _presets)
                        ChoiceChip(
                          label: Text(
                            minutes == 60 ? '1 giờ' : '$minutes phút',
                          ),
                          selected: _duration == minutes * 60,
                          onSelected: _running
                              ? null
                              : (_) => _choose(minutes * 60),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_running)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: clock,
                    )
                  else
                    TextButton(
                      onPressed: _editDuration,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          clock,
                          const SizedBox(height: 4),
                          const Text('Chỉnh thời lượng'),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: _running ? _stop : _start,
                        icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                        label: Text(
                          _running
                              ? 'Tạm dừng'
                              : paused
                              ? 'Tiếp tục'
                              : 'Bắt đầu',
                        ),
                      ),
                      TextButton(
                        onPressed: () => _stop(reset: true),
                        child: const Text('Đặt lại'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusDurationDialog extends StatefulWidget {
  const _FocusDurationDialog({required this.seconds});

  final int seconds;

  @override
  State<_FocusDurationDialog> createState() => _FocusDurationDialogState();
}

class _FocusDurationDialogState extends State<_FocusDurationDialog> {
  late int _hours = widget.seconds ~/ 3600;
  late int _minutes = widget.seconds ~/ 60 % 60;
  late int _seconds = widget.seconds % 60;
  late final _hourController = FixedExtentScrollController(initialItem: _hours);
  late final _minuteController = FixedExtentScrollController(
    initialItem: _minutes,
  );
  late final _secondController = FixedExtentScrollController(
    initialItem: _seconds,
  );

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = _hours * 3600 + _minutes * 60 + _seconds;
    return AlertDialog(
      title: const Text('Chỉnh thời lượng'),
      scrollable: true,
      content: SizedBox(
        width: 320,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              ...ScrollConfiguration.of(context).dragDevices,
              PointerDeviceKind.mouse,
            },
          ),
          child: Row(
            children: [
              Expanded(
                child: _DurationWheel(
                  label: 'Giờ',
                  count: 24,
                  controller: _hourController,
                  onChanged: (value) => setState(() => _hours = value),
                ),
              ),
              Expanded(
                child: _DurationWheel(
                  label: 'Phút',
                  count: 60,
                  controller: _minuteController,
                  onChanged: (value) => setState(() => _minutes = value),
                ),
              ),
              Expanded(
                child: _DurationWheel(
                  label: 'Giây',
                  count: 60,
                  controller: _secondController,
                  onChanged: (value) => setState(() => _seconds = value),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: duration == 0
              ? null
              : () => Navigator.pop(context, duration),
          child: const Text('Áp dụng'),
        ),
      ],
    );
  }
}

class _DurationWheel extends StatelessWidget {
  const _DurationWheel({
    required this.label,
    required this.count,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final int count;
  final FixedExtentScrollController controller;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      SizedBox(
        height: 150,
        child: Semantics(
          label: label,
          child: CupertinoPicker.builder(
            scrollController: controller,
            itemExtent: 36,
            childCount: count,
            onSelectedItemChanged: onChanged,
            itemBuilder: (context, index) => Center(
              child: Text(
                _twoDigits(index),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _clockLabel(int seconds) =>
    '${_twoDigits(seconds ~/ 3600)}:${_twoDigits(seconds ~/ 60 % 60)}:${_twoDigits(seconds % 60)}';
