import 'package:flutter/material.dart';
import 'package:studyplaner/data/app_database.dart';
import 'package:studyplaner/data/notification_service.dart';
import 'package:studyplaner/util/id.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({
    super.key,
    required this.database,
    required this.notifications,
  });
  final AppDatabase database;
  final NotificationService notifications;
  Future<void> _add(BuildContext context) async {
    final row = await showDialog<StudyEvent>(
      context: context,
      builder: (_) => const _EventDialog(),
    );
    if (row == null) return;
    await database.saveEvent(row);
    if (row.reminderAt != null) {
      await notifications.schedule(
        row.id.hashCode & 0x7fffffff,
        row.title,
        DateTime.fromMillisecondsSinceEpoch(row.reminderAt!),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: StreamBuilder<List<StudyEvent>>(
      stream: database.watchEvents(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lịch của bạn',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Lịch được lưu trên thiết bị và đồng bộ khi có mạng.',
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () => _add(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm lịch'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (rows.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Chưa có lịch. Thêm lịch học hoặc buổi tự học đầu tiên.',
                  ),
                ),
              )
            else
              ...rows.map((row) => _ScheduleCard(row: row)),
          ],
        );
      },
    ),
    floatingActionButton: MediaQuery.sizeOf(context).width < 650
        ? FloatingActionButton.extended(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Text('Thêm lịch'),
          )
        : null,
  );
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.row});
  final StudyEvent row;
  @override
  Widget build(BuildContext context) {
    final start = DateTime.fromMillisecondsSinceEpoch(row.startsAt);
    final end = DateTime.fromMillisecondsSinceEpoch(row.endsAt);
    final date = '${start.day}/${start.month}/${start.year}';
    String time(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.menu_book_outlined),
        ),
        title: Text(
          row.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '$date · ${time(start)}–${time(end)}${row.details.isEmpty ? '' : '\n${row.details}'}',
          ),
        ),
        trailing: Icon(
          row.reminderAt == null
              ? Icons.notifications_none
              : Icons.notifications_active_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _EventDialog extends StatefulWidget {
  const _EventDialog();
  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  final _title = TextEditingController();
  final _details = TextEditingController();
  DateTime _starts = DateTime.now().add(const Duration(hours: 1));
  DateTime _ends = DateTime.now().add(const Duration(hours: 2));
  bool _reminder = true;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Nhập tên lịch học.');
      return;
    }
    if (!_ends.isAfter(_starts)) {
      setState(() => _error = 'Giờ kết thúc phải sau giờ bắt đầu.');
      return;
    }
    final reminderAt = _reminder
        ? _starts.subtract(const Duration(minutes: 10))
        : null;
    Navigator.pop(
      context,
      StudyEvent(
        id: newId(),
        title: _title.text.trim(),
        details: _details.text.trim(),
        startsAt: _starts.millisecondsSinceEpoch,
        endsAt: _ends.millisecondsSinceEpoch,
        reminderAt: reminderAt?.millisecondsSinceEpoch,
        isSynced: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Thêm lịch học'),
    content: SizedBox(
      width: 430,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Tên lịch',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _details,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _DateButton(
              label: 'Bắt đầu',
              value: _starts,
              onTap: () async {
                final picked = await _pick(_starts);
                if (picked != null)
                  setState(() {
                    _starts = picked;
                    if (!_ends.isAfter(picked))
                      _ends = picked.add(const Duration(hours: 1));
                  });
              },
            ),
            _DateButton(
              label: 'Kết thúc',
              value: _ends,
              onTap: () async {
                final picked = await _pick(_ends);
                if (picked != null) setState(() => _ends = picked);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _reminder,
              onChanged: (value) => setState(() => _reminder = value),
              title: const Text('Nhắc trước 10 phút'),
            ),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
      FilledButton(onPressed: _save, child: const Text('Lưu lịch')),
    ],
  );
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(
      '${value.day}/${value.month}/${value.year}  ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
    ),
    trailing: const Icon(Icons.edit_calendar_outlined),
    onTap: onTap,
  );
}
