import 'package:flutter/material.dart';
import 'package:studyplaner/data/app_database.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({
    super.key,
    required this.database,
    required this.onOpenSchedule,
  });
  final AppDatabase database;
  final VoidCallback onOpenSchedule;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<StudyEvent>>(
    stream: database.watchEvents(),
    builder: (context, snapshot) {
      final now = DateTime.now();
      final events = (snapshot.data ?? [])
          .where((event) => event.endsAt >= now.millisecondsSinceEpoch)
          .toList();
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF3456C7), Color(0xFF7895F0)],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chào bạn 👋',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Học có kế hoạch.\nTiến bộ mỗi ngày.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Lên lịch, theo dõi lộ trình và gom ghi chú môn học.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _StatCard(
                icon: Icons.event_note_outlined,
                label: 'Lịch sắp tới',
                value: '${events.length}',
                color: const Color(0xFF5678E8),
              ),
              _StatCard(
                icon: Icons.account_tree_outlined,
                label: 'Môn học',
                valueWidget: StreamBuilder<List<Subject>>(
                  stream: database.watchSubjects(),
                  builder: (_, s) => Text(
                    '${s.data?.length ?? 0}',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                color: const Color(0xFF22A790),
              ),
              _StatCard(
                icon: Icons.offline_bolt_outlined,
                label: 'Lưu cục bộ',
                value: 'Đang bật',
                color: const Color(0xFFF09B3D),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lịch gần nhất',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: onOpenSchedule,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Mở lịch'),
              ),
            ],
          ),
          if (events.isEmpty)
            const _EmptyCard(
              icon: Icons.event_available_outlined,
              title: 'Chưa có lịch học',
              subtitle: 'Thêm lịch học đầu tiên để bắt đầu kế hoạch của bạn.',
            )
          else
            ...events.take(4).map((event) => _EventTile(event: event)),
        ],
      );
    },
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.color,
    this.value,
    this.valueWidget,
  });
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 225,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .12),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 5),
                valueWidget ??
                    Text(
                      value ?? '',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final StudyEvent event;
  @override
  Widget build(BuildContext context) {
    final starts = DateTime.fromMillisecondsSinceEpoch(event.startsAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.menu_book_outlined)),
        title: Text(
          event.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${starts.day}/${starts.month} · ${starts.hour.toString().padLeft(2, '0')}:${starts.minute.toString().padLeft(2, '0')}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Row(
        children: [
          Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
