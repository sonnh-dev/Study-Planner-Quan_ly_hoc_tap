import 'package:flutter/material.dart';
import 'package:studyplaner/data/app_database.dart';
import 'package:studyplaner/util/id.dart';

class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key, required this.database});
  final AppDatabase database;
  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  String? _subjectId;

  Future<void> _addSubject() async {
    var subjectName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm môn học'),
        content: TextField(
          onChanged: (value) => subjectName = value,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên môn học'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, subjectName.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final id = newId();
    await widget.database.saveSubject(
      Subject(id: id, name: name, color: '#5685F7', isSynced: false),
    );
    if (mounted) setState(() => _subjectId = id);
  }

  Future<void> _addNode(List<RoadmapNode> existing, String subjectId) async {
    var title = '';
    var note = '';
    String? parentId;
    final result = await showDialog<RoadmapNode>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm nhánh lộ trình'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  onChanged: (value) => title = value,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Tên chủ đề'),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) => note = value,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: parentId,
                  decoration: const InputDecoration(
                    labelText: 'Nhánh cha',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Chủ đề gốc'),
                    ),
                    ...existing.map(
                      (node) => DropdownMenuItem<String?>(
                        value: node.id,
                        child: Text(
                          node.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => parentId = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (title.trim().isEmpty) return;
                Navigator.pop(
                  context,
                  RoadmapNode(
                    id: newId(),
                    subjectId: subjectId,
                    parentId: parentId,
                    title: title.trim(),
                    note: note.trim(),
                    status: 'planned',
                    sortOrder: existing.length,
                    dueAt: null,
                    isSynced: false,
                  ),
                );
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
    if (result != null) await widget.database.saveRoadmapNode(result);
  }

  Future<void> _changeStatus(RoadmapNode node, String status) => widget.database
      .saveRoadmapNode(node.copyWith(status: status, isSynced: false));

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Subject>>(
    stream: widget.database.watchSubjects(),
    builder: (context, subjectSnapshot) {
      final subjects = subjectSnapshot.data ?? [];
      if (subjects.isEmpty) return _emptySubjects(context);
      _subjectId ??= subjects.first.id;
      if (!subjects.any((subject) => subject.id == _subjectId)) {
        _subjectId = subjects.first.id;
      }
      final selected = _subjectId!;
      return StreamBuilder<List<RoadmapNode>>(
        stream: widget.database.watchRoadmap(selected),
        builder: (context, nodeSnapshot) {
          final nodes = nodeSnapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lộ trình môn học',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Chia mục tiêu lớn thành những nhánh nhỏ có thể theo dõi.',
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      DropdownButton<String>(
                        value: selected,
                        items: subjects
                            .map(
                              (subject) => DropdownMenuItem(
                                value: subject.id,
                                child: Text(subject.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _subjectId = value),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addSubject,
                        icon: const Icon(Icons.library_add_outlined),
                        label: const Text('Môn học'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _addNode(nodes, selected),
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm nhánh'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (nodes.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      'Chưa có nhánh nào. Hãy thêm chủ đề đầu tiên vào lộ trình.',
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: nodes
                          .where((node) => node.parentId == null)
                          .map((node) => _buildBranch(node, nodes, 0))
                          .toList(),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    },
  );

  Widget _emptySubjects(BuildContext context) => Center(
    child: FilledButton.icon(
      onPressed: _addSubject,
      icon: const Icon(Icons.add),
      label: const Text('Tạo môn học'),
    ),
  );

  Widget _buildBranch(RoadmapNode node, List<RoadmapNode> all, int depth) {
    final children = all.where((child) => child.parentId == node.id).toList();
    final icon = switch (node.status) {
      'done' => Icons.check_circle,
      'in_progress' => Icons.play_circle_fill,
      _ => Icons.circle_outlined,
    };
    final color = switch (node.status) {
      'done' => const Color(0xFF26A27D),
      'in_progress' => const Color(0xFFE39A2F),
      _ => const Color(0xFF6482DB),
    };
    return Padding(
      padding: EdgeInsets.only(left: 16 + depth * 28, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 2,
                height: 24,
                color: color.withValues(alpha: .35),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  initiallyExpanded: true,
                  title: Text(
                    node.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: node.note.isEmpty
                      ? null
                      : Text(
                          node.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Đổi trạng thái',
                    onSelected: (status) => _changeStatus(node, status),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'planned',
                        child: Text('Chưa bắt đầu'),
                      ),
                      PopupMenuItem(
                        value: 'in_progress',
                        child: Text('Đang học'),
                      ),
                      PopupMenuItem(value: 'done', child: Text('Hoàn thành')),
                    ],
                    icon: const Icon(Icons.more_horiz),
                  ),
                  children: children
                      .map((child) => _buildBranch(child, all, depth + 1))
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
