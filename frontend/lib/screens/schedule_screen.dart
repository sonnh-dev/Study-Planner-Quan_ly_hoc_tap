import 'package:flutter/material.dart';
import 'package:studyplaner/data/app_database.dart';
import 'package:studyplaner/data/notification_service.dart';
import 'package:studyplaner/util/id.dart';
import 'package:studyplaner/data/sync_service.dart';

const _weekdays = [
  'Thứ hai',
  'Thứ ba',
  'Thứ tư',
  'Thứ năm',
  'Thứ sáu',
  'Thứ bảy',
  'Chủ nhật',
];
const _shortWeekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

DateTime _dayOffset(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

String _dateLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';

String _dayLabel(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${_dateLabel(date)}';

String _timeLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

bool _overlapsDay(StudyEvent event, DateTime day) =>
    event.startsAt < _dayOffset(day, 1).millisecondsSinceEpoch &&
    event.endsAt > day.millisecondsSinceEpoch;

Future<DateTime?> _pickDate(BuildContext context, DateTime initial) {
  final day = DateUtils.dateOnly(initial);
  final first = DateTime(1900);
  final last = DateTime(2100, 12, 31);
  return showDatePicker(
    context: context,
    initialDate: day,
    firstDate: day.isBefore(first) ? day : first,
    lastDate: day.isAfter(last) ? day : last,
  );
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    super.key,
    required this.database,
    required this.notifications,
  });

  final AppDatabase database;
  final NotificationService notifications;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late Stream<List<StudyEvent>> _events = widget.database.watchEvents();
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  bool _saving = false;

  @override
  void didUpdateWidget(covariant ScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.database != oldWidget.database) {
      _events = widget.database.watchEvents();
    }
  }

  void _selectDay(DateTime day) => setState(() => _day = day);

  Future<void> _chooseDay() async {
    final picked = await _pickDate(context, _day);
    if (mounted && picked != null) _selectDay(picked);
  }

  Future<void> _edit([StudyEvent? previous]) async {
    final event = await showDialog<StudyEvent>(
      context: context,
      builder: (_) => _EventDialog(day: _day, event: previous),
    );
    if (mounted && event != null) await _applyChange(previous, event);
  }

  Future<void> _delete(StudyEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lịch học?'),
        content: Text('Bạn muốn xóa “${event.title}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa lịch'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) await _applyChange(event, null);
  }

  Future<void> _applyChange(StudyEvent? previous, StudyEvent? event) async {
    setState(() => _saving = true);
    final database = widget.database;
    final notifications = widget.notifications;
    final id = (event ?? previous!).id;
    final notificationId = id.hashCode & 0x7fffffff;
    var message = event == null ? 'Đã xóa lịch học.' : 'Đã lưu lịch học.';
    try {
      await database.transaction(() async {
        if (event == null) {
          await SyncService.database.deleteEvent(id);
        } else if (previous == null) {
          await database.saveEvent(event);
        } else {
          await database.updateEvent(event);
        }
        try {
          if (previous != null) await notifications.cancel(notificationId);
          final reminderAt = event?.reminderAt;
          if (event != null && reminderAt != null) {
            await notifications.schedule(
              notificationId,
              event.title,
              DateTime.fromMillisecondsSinceEpoch(reminderAt),
            );
          }
        } catch (_) {
          message += ' Chưa cập nhật được thông báo nhắc học.';
        }
      });
      if (mounted && event != null && !_overlapsDay(event, _day)) {
        _selectDay(
          DateUtils.dateOnly(
            DateTime.fromMillisecondsSinceEpoch(event.startsAt),
          ),
        );
      }
    } catch (_) {
      message = event == null
          ? 'Chưa xóa được lịch học.'
          : 'Chưa lưu được lịch học.';
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = Theme.of(context).textTheme;
    final today = DateUtils.dateOnly(DateTime.now());
    final isToday = today == _day;

    return StreamBuilder<List<StudyEvent>>(
      stream: _events,
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <StudyEvent>[];
        final dailyEvents = events
            .where((event) => _overlapsDay(event, _day))
            .toList();
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            return ListView(
              padding: EdgeInsets.all(compact ? 12 : 24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isToday
                                      ? Icons.wb_sunny_outlined
                                      : Icons.event_outlined,
                                  color: colors.primary,
                                  size: 30,
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isToday
                                            ? 'Ngày của tôi'
                                            : 'Lịch trong ngày',
                                        style: styles.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: colors.primary,
                                        ),
                                      ),
                                      Text(
                                        _dayLabel(_day),
                                        style: styles.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            FilledButton.icon(
                              onPressed: _saving ? null : () => _edit(),
                              icon: const Icon(Icons.add),
                              label: const Text('Thêm lịch'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton(
                              onPressed: isToday
                                  ? null
                                  : () => _selectDay(today),
                              child: const Text('Hôm nay'),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Ngày trước',
                                  onPressed: () =>
                                      _selectDay(_dayOffset(_day, -1)),
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                IconButton(
                                  tooltip: 'Chọn ngày',
                                  onPressed: _chooseDay,
                                  icon: const Icon(
                                    Icons.calendar_month_outlined,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Ngày sau',
                                  onPressed: () =>
                                      _selectDay(_dayOffset(_day, 1)),
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                          ],
                        ),
                        _WeekStrip(
                          day: _day,
                          events: events,
                          onSelect: _selectDay,
                        ),
                        const SizedBox(height: 24),
                        if (snapshot.hasError)
                          const Text('Chưa tải được lịch học.')
                        else if (!snapshot.hasData)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          Text(
                            '${dailyEvents.length} buổi học',
                            style: styles.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          _DayTable(
                            day: _day,
                            events: dailyEvents,
                            compact: compact,
                            onEdit: _saving ? null : (event) => _edit(event),
                            onDelete: _saving ? null : _delete,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.day,
    required this.events,
    required this.onSelect,
  });

  final DateTime day;
  final List<StudyEvent> events;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final weekStart = _dayOffset(day, 1 - day.weekday);
    final radius = BorderRadius.circular(12);
    return Row(
      children: List.generate(7, (index) {
        final date = _dayOffset(weekStart, index);
        final selected = date == day;
        final hasEvents = events.any((event) => _overlapsDay(event, date));
        final color = selected ? colors.onPrimaryContainer : colors.onSurface;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Semantics(
              selected: selected,
              button: true,
              child: Tooltip(
                message: _dayLabel(date),
                child: Material(
                  color: selected ? colors.primaryContainer : colors.surface,
                  borderRadius: radius,
                  child: InkWell(
                    borderRadius: radius,
                    onTap: () => onSelect(date),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Text(
                            _shortWeekdays[index],
                            style: TextStyle(color: color),
                          ),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            Icons.circle,
                            size: 5,
                            color: hasEvents
                                ? colors.primary
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

enum _EventAction { edit, delete }

class _DayTable extends StatelessWidget {
  const _DayTable({
    required this.day,
    required this.events,
    required this.compact,
    required this.onEdit,
    required this.onDelete,
  });

  final DateTime day;
  final List<StudyEvent> events;
  final bool compact;
  final ValueChanged<StudyEvent>? onEdit;
  final ValueChanged<StudyEvent>? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = Theme.of(context).textTheme;
    final timeWidth = compact ? 76.0 : 144.0;
    final actionWidth = compact ? 48.0 : 96.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: colors.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
              child: DefaultTextStyle(
                style: styles.labelLarge!.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                child: Row(
                  children: [
                    SizedBox(width: timeWidth, child: const Text('Khung giờ')),
                    const Expanded(child: Text('Buổi học')),
                    if (!compact)
                      SizedBox(
                        width: actionWidth,
                        child: const Text(
                          'Thao tác',
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: 32,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chưa có lịch học trong ngày này.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          for (final event in events) ...[
            const Divider(height: 1),
            InkWell(
              onTap: onEdit == null ? null : () => onEdit!(event),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: timeWidth,
                      child: _timeRange(context, event),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.title, style: styles.titleSmall),
                          if (event.details.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              event.details,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: styles.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (event.reminderAt != null) ...[
                            const SizedBox(height: 4),
                            Tooltip(
                              message: 'Có nhắc giờ học',
                              child: Icon(
                                Icons.notifications_outlined,
                                size: 16,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (compact)
                      PopupMenuButton<_EventAction>(
                        tooltip: 'Thao tác lịch học',
                        enabled: onEdit != null,
                        onSelected: (action) {
                          switch (action) {
                            case _EventAction.edit:
                              onEdit?.call(event);
                            case _EventAction.delete:
                              onDelete?.call(event);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: _EventAction.edit,
                            child: Text('Sửa lịch'),
                          ),
                          PopupMenuItem(
                            value: _EventAction.delete,
                            child: Text('Xóa lịch'),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: actionWidth,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Sửa lịch',
                              onPressed: onEdit == null
                                  ? null
                                  : () => onEdit!(event),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Xóa lịch',
                              onPressed: onDelete == null
                                  ? null
                                  : () => onDelete!(event),
                              icon: Icon(
                                Icons.delete_outline,
                                color: onDelete == null ? null : colors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeRange(BuildContext context, StudyEvent event) {
    final start = DateTime.fromMillisecondsSinceEpoch(event.startsAt);
    final end = DateTime.fromMillisecondsSinceEpoch(event.endsAt);
    final from = start.isBefore(day) ? '00:00' : _timeLabel(start);
    final to = end.isBefore(_dayOffset(day, 1)) ? _timeLabel(end) : '24:00';
    final theme = Theme.of(context);

    return Tooltip(
      message:
          '${_dateLabel(start)} ${_timeLabel(start)} → ${_dateLabel(end)} ${_timeLabel(end)}',
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(
          compact ? '$from\n– $to' : '$from – $to',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _EventDialog extends StatefulWidget {
  const _EventDialog({required this.day, this.event});

  final DateTime day;
  final StudyEvent? event;

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  late final _title = TextEditingController(text: widget.event?.title);
  late final _details = TextEditingController(text: widget.event?.details);
  late DateTime _starts;
  late DateTime _ends;
  late bool _reminder;
  String? _error;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event != null) {
      _starts = DateTime.fromMillisecondsSinceEpoch(event.startsAt);
      _ends = DateTime.fromMillisecondsSinceEpoch(event.endsAt);
      _reminder = event.reminderAt != null;
      return;
    }
    final now = DateTime.now();
    final day = widget.day;
    _starts = DateTime(day.year, day.month, day.day, 9);
    if (DateUtils.isSameDay(day, now)) {
      final nextHour = DateTime(day.year, day.month, day.day, now.hour + 1);
      _starts = DateUtils.isSameDay(nextHour, day)
          ? nextHour
          : DateTime(day.year, day.month, day.day, now.hour, now.minute);
    }
    _ends = _starts.add(const Duration(hours: 1));
    _reminder = true;
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  void _changeStart(DateTime value) {
    final duration = _ends.difference(_starts);
    final dateChanged = !DateUtils.isSameDay(value, _starts);
    setState(() {
      _starts = value;
      if (dateChanged || !_ends.isAfter(value)) {
        _ends = value.add(
          duration > Duration.zero ? duration : const Duration(hours: 1),
        );
      }
      _error = null;
    });
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Nhập tên lịch học.');
      return;
    }
    if (!_ends.isAfter(_starts)) {
      setState(() => _error = 'Giờ kết thúc phải sau giờ bắt đầu.');
      return;
    }
    final original = widget.event;
    final previousReminder = original?.reminderAt;
    final leadTime = previousReminder == null
        ? const Duration(minutes: 10).inMilliseconds
        : original!.startsAt - previousReminder;
    Navigator.pop(
      context,
      StudyEvent(
        id: original?.id ?? newId(),
        title: title,
        details: _details.text.trim(),
        startsAt: _starts.millisecondsSinceEpoch,
        endsAt: _ends.millisecondsSinceEpoch,
        reminderAt: _reminder
            ? _starts.millisecondsSinceEpoch - leadTime
            : null,
        isSynced: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.event == null ? 'Thêm lịch học' : 'Sửa lịch học'),
    scrollable: true,
    content: SizedBox(
      width: 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            maxLength: 160,
            decoration: const InputDecoration(
              labelText: 'Tên lịch',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _details,
            maxLines: 2,
            maxLength: 5000,
            decoration: const InputDecoration(
              labelText: 'Ghi chú (tùy chọn)',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          _DateTimeFields(
            label: 'Bắt đầu',
            value: _starts,
            onChanged: _changeStart,
          ),
          const SizedBox(height: 8),
          _DateTimeFields(
            label: 'Kết thúc',
            value: _ends,
            onChanged: (value) => setState(() {
              _ends = value;
              _error = null;
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _reminder,
            onChanged: (value) => setState(() => _reminder = value),
            title: Text(
              widget.event?.reminderAt == null
                  ? 'Nhắc trước 10 phút'
                  : 'Nhắc giờ học',
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _save, child: const Text('Lưu lịch')),
    ],
  );
}

class _DateTimeFields extends StatelessWidget {
  const _DateTimeFields({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      Wrap(
        spacing: 8,
        children: [
          Tooltip(
            message: 'Chọn ngày ${label.toLowerCase()}',
            child: OutlinedButton.icon(
              onPressed: () async {
                final day = await _pickDate(context, value);
                if (context.mounted && day != null) {
                  onChanged(
                    DateTime(
                      day.year,
                      day.month,
                      day.day,
                      value.hour,
                      value.minute,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(_dateLabel(value)),
            ),
          ),
          Tooltip(
            message: 'Chọn giờ ${label.toLowerCase()}',
            child: OutlinedButton.icon(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(value),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(alwaysUse24HourFormat: true),
                    child: child!,
                  ),
                );
                if (context.mounted && time != null) {
                  onChanged(
                    DateTime(
                      value.year,
                      value.month,
                      value.day,
                      time.hour,
                      time.minute,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.schedule, size: 16),
              label: Text(_timeLabel(value)),
            ),
          ),
        ],
      ),
    ],
  );
}
