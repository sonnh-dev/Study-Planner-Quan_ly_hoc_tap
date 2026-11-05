import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:studyplaner/data/app_database.dart';
import 'package:studyplaner/util/id.dart';

const _statuses = {
  'planned': 'Chưa bắt đầu',
  'in_progress': 'Đang học',
  'done': 'Hoàn thành',
};

enum _SubjectAction { rename, delete }

enum _BranchAction { edit, addChild, delete }

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

  Future<void> _editSubject([Subject? subject]) async {
    final formKey = GlobalKey<FormState>();
    var name = subject?.name ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(subject == null ? 'Thêm môn học' : 'Đổi tên môn học'),
        scrollable: true,
        content: Form(
          key: formKey,
          child: TextFormField(
            initialValue: name,
            onChanged: (value) => name = value.trim(),
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Tên môn học'),
            validator: (value) =>
                _validateTitle(value, 'Nhập tên môn học.', 120),
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
                Navigator.pop(context, name);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (!mounted || result == null || result == subject?.name) return;
    try {
      if (subject == null) {
        final created = Subject(
          id: newId(),
          name: result,
          color: '#5685F7',
          isSynced: false,
        );
        await widget.database.saveSubject(created);
        if (mounted) _openSubject(created);
      } else {
        await widget.database.updateSubject(
          subject.copyWith(name: result, isSynced: false),
        );
      }
    } catch (_) {
      if (mounted) _showError(context, 'Không thể lưu môn học. Hãy thử lại.');
    }
  }

  Future<void> _deleteSubject(Subject subject) async {
    final confirmed = await _confirmDelete(
      context,
      title: 'Xóa môn học?',
      description: 'Lộ trình và Mindmap của “${subject.name}” cũng sẽ bị xóa.',
    );
    if (!mounted || !confirmed) return;
    try {
      await widget.database.deleteSubject(subject.id);
    } catch (_) {
      if (mounted) _showError(context, 'Không thể xóa môn học. Hãy thử lại.');
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
      return _RoadmapList(
        count: subjects.length,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RoadmapHeader(
              title: 'Môn học',
              subtitle: 'Chọn môn để mở lộ trình và theo dõi tiến độ.',
              action: FilledButton.icon(
                onPressed: _editSubject,
                icon: const Icon(Icons.add),
                label: Text(subjects.isEmpty ? 'Tạo môn học' : 'Thêm môn học'),
              ),
            ),
            if (subjects.isEmpty)
              const _RoadmapEmpty(
                icon: Icons.menu_book_outlined,
                message: 'Chưa có môn học. Tạo môn để bắt đầu.',
              ),
          ],
        ),
        itemBuilder: (context, index) {
          final subject = subjects[index];
          final rgb = int.tryParse(
            subject.color.replaceFirst('#', ''),
            radix: 16,
          );
          return Card(
            key: ValueKey(subject.id),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(0xFF000000 | (rgb ?? 0x5685F7)),
                foregroundColor: Colors.white,
                child: const Icon(Icons.menu_book_outlined, size: 20),
              ),
              title: Text(subject.name),
              onTap: () => _openSubject(subject),
              trailing: PopupMenuButton<_SubjectAction>(
                tooltip: 'Thao tác môn học',
                onSelected: (action) {
                  switch (action) {
                    case _SubjectAction.rename:
                      _editSubject(subject);
                    case _SubjectAction.delete:
                      _deleteSubject(subject);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _SubjectAction.rename,
                    child: Text('Đổi tên môn học'),
                  ),
                  PopupMenuItem(
                    value: _SubjectAction.delete,
                    child: Text('Xóa môn học'),
                  ),
                ],
              ),
            ),
          );
        },
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
  late final _subject = widget.database.watchSubject(widget.subject.id);
  late final _nodes = widget.database.watchRoadmap(widget.subject.id);
  final _collapsed = <String>{};

  Future<void> _editNode(
    List<RoadmapNode> nodes, {
    RoadmapNode? node,
    String? parentId,
  }) async {
    final result = await showDialog<RoadmapNode>(
      context: context,
      builder: (_) => _RoadmapNodeDialog(
        subjectId: widget.subject.id,
        nodes: nodes,
        node: node,
        parentId: node?.parentId ?? parentId,
      ),
    );
    if (!mounted || result == null || result == node) return;
    try {
      await widget.database.saveRoadmapEdit(result, create: node == null);
      final parent = result.parentId;
      if (mounted && parent != null && _collapsed.remove(parent)) {
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        _showError(
          context,
          'Không thể lưu nhánh. Kiểm tra nhánh cha rồi thử lại.',
        );
      }
    }
  }

  Future<void> _deleteNode(RoadmapNode node, bool hasChildren) async {
    final confirmed = await _confirmDelete(
      context,
      title: 'Xóa nhánh lộ trình?',
      description: hasChildren
          ? 'Các nhánh con trực tiếp của “${node.title}” sẽ được đưa lên gốc.'
          : 'Bạn muốn xóa “${node.title}”?',
    );
    if (!mounted || !confirmed) return;
    try {
      await widget.database.deleteRoadmapNode(node.subjectId, node.id);
      if (mounted && _collapsed.remove(node.id)) setState(() {});
    } catch (_) {
      if (mounted) _showError(context, 'Không thể xóa nhánh. Hãy thử lại.');
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Subject?>(
    stream: _subject,
    initialData: widget.subject,
    builder: (context, subjectSnapshot) {
      final subject = subjectSnapshot.data;
      return Scaffold(
        appBar: AppBar(title: Text(subject?.name ?? 'Lộ trình')),
        body: subjectSnapshot.hasError
            ? const Center(child: Text('Không thể đọc môn học.'))
            : subject == null
            ? const Center(child: Text('Môn học đã được xóa.'))
            : StreamBuilder<List<RoadmapNode>>(
                stream: _nodes,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Không thể đọc lộ trình môn học.'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final nodes = snapshot.data!;
                  final branches = _visibleBranches(nodes);
                  return _RoadmapList(
                    count: branches.length,
                    header: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RoadmapHeader(
                          title: 'Lộ trình môn học',
                          subtitle: 'Chia mục tiêu thành từng nhánh học.',
                          action: FilledButton.icon(
                            onPressed: () => _editNode(nodes),
                            icon: const Icon(Icons.add),
                            label: const Text('Thêm nhánh'),
                          ),
                        ),
                        _RoadmapProgress(nodes: nodes),
                        if (nodes.isEmpty) ...[
                          const SizedBox(height: 12),
                          const _RoadmapEmpty(
                            icon: Icons.account_tree_outlined,
                            message:
                                'Chưa có nhánh nào. Hãy thêm chủ đề đầu tiên.',
                          ),
                        ],
                      ],
                    ),
                    itemBuilder: (context, index) {
                      final (node, depth, hasChildren) = branches[index];
                      final expanded = !_collapsed.contains(node.id);
                      return _RoadmapBranchTile(
                        key: ValueKey(node.id),
                        node: node,
                        depth: depth,
                        expanded: expanded,
                        onToggle: hasChildren
                            ? () => setState(() {
                                if (!_collapsed.remove(node.id)) {
                                  _collapsed.add(node.id);
                                }
                              })
                            : null,
                        onEdit: () => _editNode(nodes, node: node),
                        onAddChild: () => _editNode(nodes, parentId: node.id),
                        onDelete: () => _deleteNode(node, hasChildren),
                      );
                    },
                  );
                },
              ),
      );
    },
  );

  List<(RoadmapNode, int, bool)> _visibleBranches(List<RoadmapNode> nodes) {
    final ids = nodes.map((node) => node.id).toSet();
    final children = <String?, List<RoadmapNode>>{};
    for (final node in nodes) {
      final parent = ids.contains(node.parentId) ? node.parentId : null;
      (children[parent] ??= []).add(node);
    }
    final result = <(RoadmapNode, int, bool)>[];
    final visited = <String>{};

    void visit(Iterable<RoadmapNode> roots) {
      final stack = <({bool hidden, int depth, RoadmapNode node})>[];
      for (final root in roots) {
        stack.add((hidden: false, depth: 0, node: root));
      }
      while (stack.isNotEmpty) {
        final entry = stack.removeLast();
        final node = entry.node;
        if (!visited.add(node.id)) continue;
        final descendants = children[node.id] ?? const <RoadmapNode>[];
        if (!entry.hidden) {
          result.add((node, entry.depth, descendants.isNotEmpty));
        }
        final hidden = entry.hidden || _collapsed.contains(node.id);
        for (final child in descendants.reversed) {
          stack.add((hidden: hidden, depth: entry.depth + 1, node: child));
        }
      }
    }

    visit((children[null] ?? const <RoadmapNode>[]).reversed);
    for (final node in nodes) {
      // Older data can contain cycles. Keep those nodes reachable for repair.
      if (!visited.contains(node.id)) visit([node]);
    }
    return result;
  }
}

class _RoadmapList extends StatelessWidget {
  const _RoadmapList({
    required this.header,
    required this.count,
    required this.itemBuilder,
  });

  final Widget header;
  final int count;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: count + 1,
        itemBuilder: (context, index) => index == 0
            ? Padding(padding: const EdgeInsets.only(bottom: 12), child: header)
            : itemBuilder(context, index - 1),
      ),
    ),
  );
}

class _RoadmapHeader extends StatelessWidget {
  const _RoadmapHeader({
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final String title;
  final String subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            action,
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class _RoadmapEmpty extends StatelessWidget {
  const _RoadmapEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class _RoadmapProgress extends StatelessWidget {
  const _RoadmapProgress({required this.nodes});

  final List<RoadmapNode> nodes;

  @override
  Widget build(BuildContext context) {
    final done = nodes.where((node) => node.status == 'done').length;
    final active = nodes.where((node) => node.status == 'in_progress').length;
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$done/${nodes.length} nhánh hoàn thành',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: colors.onPrimaryContainer),
            ),
            if (nodes.isNotEmpty) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: done / nodes.length,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                '$active đang học · ${nodes.length - done - active} chưa bắt đầu',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoadmapBranchTile extends StatelessWidget {
  const _RoadmapBranchTile({
    super.key,
    required this.node,
    required this.depth,
    required this.expanded,
    required this.onToggle,
    required this.onEdit,
    required this.onAddChild,
    required this.onDelete,
  });

  final RoadmapNode node;
  final int depth;
  final bool expanded;
  final VoidCallback? onToggle;
  final VoidCallback onEdit;
  final VoidCallback onAddChild;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsetsDirectional.only(
        start: 12.0 * depth.clamp(0, 4),
        bottom: 6,
      ),
      child: ListTile(
        leading: Icon(
          switch (node.status) {
            'done' => Icons.check_circle_outline,
            'in_progress' => Icons.play_circle_outline,
            _ => Icons.circle_outlined,
          },
          color: node.status == 'planned'
              ? colors.onSurfaceVariant
              : colors.primary,
        ),
        title: Text(node.title),
        subtitle: Text(
          [
            _statuses[node.status] ?? _statuses['planned']!,
            if (node.dueAt != null) 'Hạn ${_dateLabel(node.dueAt!)}',
            if (node.note.isNotEmpty) node.note,
          ].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onEdit,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onToggle != null)
              IconButton(
                tooltip: expanded ? 'Thu gọn nhánh' : 'Mở rộng nhánh',
                onPressed: onToggle,
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ),
            PopupMenuButton<_BranchAction>(
              tooltip: 'Thao tác nhánh',
              onSelected: (action) {
                switch (action) {
                  case _BranchAction.edit:
                    onEdit();
                  case _BranchAction.addChild:
                    onAddChild();
                  case _BranchAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _BranchAction.edit,
                  child: Text('Sửa nhánh'),
                ),
                PopupMenuItem(
                  value: _BranchAction.addChild,
                  child: Text('Thêm nhánh con'),
                ),
                PopupMenuItem(
                  value: _BranchAction.delete,
                  child: Text('Xóa nhánh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoadmapNodeDialog extends StatefulWidget {
  const _RoadmapNodeDialog({
    required this.subjectId,
    required this.nodes,
    this.node,
    this.parentId,
  });

  final String subjectId;
  final List<RoadmapNode> nodes;
  final RoadmapNode? node;
  final String? parentId;

  @override
  State<_RoadmapNodeDialog> createState() => _RoadmapNodeDialogState();
}

class _RoadmapNodeDialogState extends State<_RoadmapNodeDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _title = widget.node?.title ?? '';
  late String _note = widget.node?.note ?? '';
  late String _status = _statuses.containsKey(widget.node?.status)
      ? widget.node!.status
      : 'planned';
  late int? _dueAt = widget.node?.dueAt;
  late final _parents = _availableParents();
  late String? _parentId =
      _parents.any((parent) => parent.id == widget.parentId)
      ? widget.parentId
      : null;

  List<RoadmapNode> _availableParents() {
    final node = widget.node;
    if (node == null) return widget.nodes;
    final children = <String, List<String>>{};
    for (final candidate in widget.nodes) {
      final parent = candidate.parentId;
      if (parent != null) (children[parent] ??= []).add(candidate.id);
    }
    final excluded = <String>{};
    final pending = [node.id];
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (excluded.add(id)) pending.addAll(children[id] ?? const []);
    }
    return widget.nodes
        .where((candidate) => !excluded.contains(candidate.id))
        .toList();
  }

  Future<void> _pickDueDate() async {
    final initial = _dueAt == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(_dueAt!);
    final first = DateTime(1900);
    final last = DateTime(2100, 12, 31);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial.isBefore(first) ? initial : first,
      lastDate: initial.isAfter(last) ? initial : last,
    );
    if (mounted && date != null) {
      setState(() => _dueAt = date.millisecondsSinceEpoch);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final node = widget.node;
    final order = widget.nodes.fold(
      -1,
      (max, row) => row.sortOrder > max ? row.sortOrder : max,
    );
    Navigator.pop(
      context,
      node?.copyWith(
            title: _title.trim(),
            note: _note.trim(),
            parentId: Value(_parentId),
            status: _status,
            dueAt: Value(_dueAt),
          ) ??
          RoadmapNode(
            id: newId(),
            subjectId: widget.subjectId,
            parentId: _parentId,
            title: _title.trim(),
            note: _note.trim(),
            status: _status,
            sortOrder: order + 1,
            dueAt: _dueAt,
            isSynced: false,
          ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.node == null ? 'Thêm nhánh lộ trình' : 'Sửa nhánh lộ trình',
    ),
    scrollable: true,
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: _title,
              onChanged: (value) => _title = value,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tên chủ đề'),
              validator: (value) =>
                  _validateTitle(value, 'Nhập tên chủ đề.', 160),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _note,
              onChanged: (value) => _note = value,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  _note.trim().length > 5000 ? 'Tối đa 5.000 ký tự.' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _parentId,
              isExpanded: true,
              hint: const Text('Chủ đề gốc'),
              decoration: const InputDecoration(labelText: 'Nhánh cha'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Chủ đề gốc'),
                ),
                for (final parent in _parents)
                  DropdownMenuItem<String?>(
                    value: parent.id,
                    child: Text(parent.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => _parentId = value,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Trạng thái'),
              items: [
                for (final status in _statuses.entries)
                  DropdownMenuItem(
                    value: status.key,
                    child: Text(status.value),
                  ),
              ],
              onChanged: (value) => _status = value ?? _status,
            ),
            const SizedBox(height: 12),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDueDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _dueAt == null
                        ? 'Đặt hạn học'
                        : 'Hạn ${_dateLabel(_dueAt!)}',
                  ),
                ),
                if (_dueAt != null)
                  IconButton(
                    tooltip: 'Bỏ hạn học',
                    onPressed: () => setState(() => _dueAt = null),
                    icon: const Icon(Icons.close),
                  ),
              ],
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
        onPressed: _save,
        child: Text(widget.node == null ? 'Thêm' : 'Lưu'),
      ),
    ],
  );
}

String _dateLabel(int milliseconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  return '${date.day}/${date.month}/${date.year}';
}

String? _validateTitle(String? value, String requiredMessage, int maxLength) {
  final title = value?.trim() ?? '';
  if (title.isEmpty) return requiredMessage;
  if (title.length > maxLength) return 'Tối đa $maxLength ký tự.';
  return null;
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> _confirmDelete(
  BuildContext context, {
  required String title,
  required String description,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
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
            child: const Text('Xóa'),
          ),
        ],
      ),
    ) ??
    false;
