import 'package:flutter/material.dart';
import 'package:studyplaner/data/app_database.dart';
import 'package:studyplaner/util/id.dart';

const _statuses = {
  'planned': 'Chưa bắt đầu',
  'in_progress': 'Đang học',
  'done': 'Hoàn thành',
};

class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  late final _subjects = widget.database.watchSubjects();

  void _openSubject(Subject subject) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            _SubjectRoadmap(database: widget.database, subject: subject),
      ),
    );
  }

  Future<void> _addSubject() async {
    final formKey = GlobalKey<FormState>();
    var subjectName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm môn học'),
        scrollable: true,
        content: Form(
          key: formKey,
          child: TextFormField(
            onChanged: (value) => subjectName = value.trim(),
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Tên môn học'),
            validator: (value) {
              if (subjectName.isEmpty) return 'Nhập tên môn học.';
              if (subjectName.length > 120) return 'Tối đa 120 ký tự.';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, subjectName);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    final subject = Subject(
      id: newId(),
      name: name,
      color: '#5685F7',
      isSynced: false,
    );
    try {
      await widget.database.saveSubject(subject);
      if (mounted) _openSubject(subject);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể lưu môn học. Hãy thử lại.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Subject>>(
    stream: _subjects,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Không thể đọc danh sách môn học.'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final subjects = snapshot.data!;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Môn học', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text('Chọn một môn để mở lộ trình và theo dõi tiến độ.'),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: _addSubject,
              icon: const Icon(Icons.add),
              label: Text(subjects.isEmpty ? 'Tạo môn học' : 'Thêm môn học'),
            ),
          ),
          const SizedBox(height: 16),
          if (subjects.isEmpty) const Text('Bạn chưa có môn học nào.'),
          for (final subject in subjects)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(subject.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openSubject(subject),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _SubjectRoadmap extends StatefulWidget {
  const _SubjectRoadmap({required this.database, required this.subject});

  final AppDatabase database;
  final Subject subject;

  @override
  State<_SubjectRoadmap> createState() => _SubjectRoadmapState();
}

class _SubjectRoadmapState extends State<_SubjectRoadmap> {
  late final _nodes = widget.database.watchRoadmap(widget.subject.id);
  final _collapsed = <String>{};

  Future<void> _editNode(List<RoadmapNode> nodes, {RoadmapNode? node}) async {
    final formKey = GlobalKey<FormState>();
    var title = node?.title ?? '';
    var note = node?.note ?? '';
    var status = node?.status ?? 'planned';
    if (!_statuses.containsKey(status)) status = 'planned';
    String? parentId;
    final result = await showDialog<RoadmapNode>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(node == null ? 'Thêm nhánh lộ trình' : node.title),
        scrollable: true,
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (node == null) ...[
                  TextFormField(
                    onChanged: (value) => title = value.trim(),
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Tên chủ đề'),
                    validator: (value) {
                      if (title.isEmpty) return 'Nhập tên chủ đề.';
                      if (title.length > 160) return 'Tối đa 160 ký tự.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  initialValue: note,
                  onChanged: (value) => note = value,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      note.trim().length > 5000 ? 'Tối đa 5.000 ký tự.' : null,
                ),
                const SizedBox(height: 12),
                if (node == null)
                  DropdownButtonFormField<String?>(
                    initialValue: parentId,
                    isExpanded: true,
                    hint: const Text('Chủ đề gốc'),
                    decoration: const InputDecoration(labelText: 'Nhánh cha'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Chủ đề gốc'),
                      ),
                      for (final candidate in nodes)
                        DropdownMenuItem<String?>(
                          value: candidate.id,
                          child: Text(
                            candidate.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => parentId = value,
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Trạng thái'),
                    items: [
                      for (final entry in _statuses.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (value) => status = value ?? status,
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
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                node?.copyWith(
                      note: note.trim(),
                      status: status,
                      isSynced: false,
                    ) ??
                    RoadmapNode(
                      id: newId(),
                      subjectId: widget.subject.id,
                      parentId: parentId,
                      title: title,
                      note: note.trim(),
                      status: 'planned',
                      sortOrder: nodes.isEmpty ? 0 : nodes.last.sortOrder + 1,
                      dueAt: null,
                      isSynced: false,
                    ),
              );
            },
            child: Text(node == null ? 'Thêm' : 'Lưu'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    if (node != null &&
        node.note == result.note &&
        node.status == result.status) {
      return;
    }
    try {
      if (node == null) {
        await widget.database.saveRoadmapNode(result);
        if (mounted && parentId != null) {
          setState(() => _collapsed.remove(parentId));
        }
      } else {
        await widget.database.updateRoadmapProgress(
          result.id,
          note: result.note,
          status: result.status,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể lưu nhánh. Hãy thử lại.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.subject.name)),
    body: StreamBuilder<List<RoadmapNode>>(
      stream: _nodes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Không thể đọc lộ trình môn học.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final nodes = snapshot.data!;
        final completed = nodes.where((node) => node.status == 'done').length;
        final children = <String?, List<RoadmapNode>>{};
        for (final node in nodes) {
          (children[node.parentId] ??= []).add(node);
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Lộ trình môn học',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('$completed/${nodes.length} nhánh hoàn thành'),
            if (nodes.isNotEmpty) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: completed / nodes.length),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: () => _editNode(nodes),
                icon: const Icon(Icons.add),
                label: const Text('Thêm nhánh'),
              ),
            ),
            const SizedBox(height: 16),
            if (nodes.isEmpty)
              const Text('Chưa có nhánh nào. Hãy thêm chủ đề đầu tiên.'),
            ..._branches(nodes, children, null, 0),
          ],
        );
      },
    ),
  );

  Iterable<Widget> _branches(
    List<RoadmapNode> nodes,
    Map<String?, List<RoadmapNode>> children,
    String? parentId,
    int depth,
  ) sync* {
    for (final node in children[parentId] ?? const <RoadmapNode>[]) {
      final expanded = !_collapsed.contains(node.id);
      final hasChildren = children.containsKey(node.id);
      yield Card(
        key: ValueKey(node.id),
        margin: EdgeInsetsDirectional.only(
          start: 12.0 * depth.clamp(0, 4),
          bottom: 6,
        ),
        child: ListTile(
          leading: Icon(switch (node.status) {
            'done' => Icons.check_circle_outline,
            'in_progress' => Icons.play_circle_outline,
            _ => Icons.circle_outlined,
          }),
          title: Text(node.title),
          subtitle: Text(
            [
              _statuses[node.status] ?? _statuses['planned']!,
              if (node.note.isNotEmpty) node.note,
            ].join('\n'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _editNode(nodes, node: node),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Sửa ghi chú và trạng thái',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editNode(nodes, node: node),
              ),
              if (hasChildren)
                IconButton(
                  tooltip: expanded ? 'Thu gọn nhánh' : 'Mở rộng nhánh',
                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() {
                    if (expanded) {
                      _collapsed.add(node.id);
                    } else {
                      _collapsed.remove(node.id);
                    }
                  }),
                ),
            ],
          ),
        ),
      );
      if (expanded && hasChildren) {
        yield* _branches(nodes, children, node.id, depth + 1);
      }
    }
  }
}
