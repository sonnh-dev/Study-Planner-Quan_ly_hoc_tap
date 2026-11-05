import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studyplaner/data/app_database.dart';
import 'package:studyplaner/util/id.dart';

class MindmapScreen extends StatefulWidget {
  const MindmapScreen({super.key, required this.database});
  final AppDatabase database;
  @override
  State<MindmapScreen> createState() => _MindmapScreenState();
}

class _MindmapScreenState extends State<MindmapScreen> {
  String? _subjectId;
  String? _selectedNodeId;
  MindmapNode? _draggingNode;
  late final _subjects = widget.database.watchSubjects();
  final _streams = <String, Stream<List<MindmapNode>>>{};

  Stream<List<MindmapNode>> _watchMindmap(String subjectId) => _streams
      .putIfAbsent(subjectId, () => widget.database.watchMindmap(subjectId));

  bool _isDesktop(BuildContext context) =>
      defaultTargetPlatform == TargetPlatform.windows ||
      (kIsWeb && MediaQuery.sizeOf(context).width >= 760);

  static const _webEditorUrl = String.fromEnvironment(
    'WEB_EDITOR_URL',
    defaultValue: 'http://localhost:8386',
  );

  Future<void> _showWebEditorInstructions() => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Chỉnh sửa trên máy tính'),
      content: const SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mở địa chỉ sau bằng trình duyệt trên máy tính:'),
              SizedBox(height: 12),
              SelectableText(_webEditorUrl),
              SizedBox(height: 16),
              Text(
                '1. Đăng nhập và bấm Đồng bộ trên điện thoại.\n\n'
                '2. Trên máy tính, mở Web editor, đăng nhập cùng tài khoản '
                'và bấm Đồng bộ trước khi chỉnh sửa.\n\n'
                '3. Mở mục Mindmap, chọn môn và chỉnh sửa. '
                'Bấm Đồng bộ sau khi hoàn tất.\n\n'
                '4. Trở lại điện thoại, bấm Đồng bộ để xem dữ liệu mới.',
              ),
              SizedBox(height: 16),
              Text(
                'Web editor cần đang chạy. Với địa chỉ localhost, '
                'hãy mở trên máy tính đang chạy Web editor. '
                'Chế độ offline không đồng bộ giữa các thiết bị.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Đóng'),
        ),
        FilledButton.icon(
          onPressed: () async {
            try {
              await Clipboard.setData(const ClipboardData(text: _webEditorUrl));
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã sao chép địa chỉ Web editor')),
              );
            } catch (_) {
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Chưa sao chép được. Hãy chọn địa chỉ để sao chép.',
                  ),
                ),
              );
            }
          },
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Sao chép địa chỉ'),
        ),
      ],
    ),
  );

  Widget _buildMobileMindmap() => StreamBuilder<List<Subject>>(
    stream: _subjects,
    builder: (context, subjectSnapshot) {
      final subjects = subjectSnapshot.data ?? [];
      final subjectId = subjects.any((row) => row.id == _subjectId)
          ? _subjectId
          : subjects.firstOrNull?.id;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.desktop_windows_outlined, size: 48),
          const SizedBox(height: 16),
          Text(
            'Chỉnh sửa Mindmap trên máy tính',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Xem nội dung trên điện thoại. Mở Web editor trên máy tính '
            'để tạo và sắp xếp các nhánh.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _showWebEditorInstructions,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Chỉnh sửa trên máy tính'),
          ),
          const SizedBox(height: 24),
          if (subjectSnapshot.hasError)
            const Text('Không tải được môn học. Hãy mở lại mục Mindmap.')
          else if (subjectSnapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator())
          else if (subjectId == null)
            const Text(
              'Chưa có môn học. Đăng nhập cùng tài khoản và bấm Đồng bộ '
              'để tải dữ liệu từ máy tính.',
            )
          else ...[
            DropdownButtonFormField<String>(
              key: ValueKey(subjectId),
              initialValue: subjectId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Môn học'),
              items: subjects
                  .map(
                    (row) =>
                        DropdownMenuItem(value: row.id, child: Text(row.name)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _subjectId = value),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<MindmapNode>>(
              key: ValueKey('mobile-mindmap-$subjectId'),
              stream: _watchMindmap(subjectId),
              builder: (context, nodeSnapshot) {
                if (nodeSnapshot.hasError) {
                  return const Text('Không tải được Mindmap. Hãy thử lại.');
                }
                if (nodeSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final nodes = nodeSnapshot.data ?? [];
                if (nodes.isEmpty) {
                  return const Text(
                    'Môn này chưa có Mindmap. '
                    'Tạo trên Web editor rồi đồng bộ ở cả máy tính và điện thoại.',
                  );
                }
                final byId = {for (final node in nodes) node.id: node};
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${nodes.length} node · Chỉ xem'),
                    const SizedBox(height: 8),
                    for (final node in nodes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  node.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                if (byId[node.parentId] case final parent?) ...[
                                  const SizedBox(height: 4),
                                  Text('Thuộc nhánh: ${parent.title}'),
                                ],
                                if (node.content.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(node.content),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      );
    },
  );

  MindmapNode? _findNode(List<MindmapNode> nodes, String? id) {
    if (id == null) return null;
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

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

  Future<void> _editNode(
    List<MindmapNode> nodes,
    String subjectId, {
    MindmapNode? parent,
    MindmapNode? editing,
  }) async {
    final current = editing;
    var title = current?.title ?? '';
    var content = current?.content ?? '';
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          current == null ? 'Thêm ghi chú mindmap' : 'Chỉnh sửa ghi chú',
        ),
        scrollable: true,
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: current?.title ?? '',
                onChanged: (value) => title = value,
                autofocus: true,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Tiêu đề'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: current?.content ?? '',
                onChanged: (value) => content = value,
                maxLines: 5,
                maxLength: 5000,
                decoration: const InputDecoration(
                  labelText: 'Nội dung ghi chú',
                  border: OutlineInputBorder(),
                ),
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
              if (title.trim().isNotEmpty) {
                Navigator.pop(context, (title.trim(), content.trim()));
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (current != null) {
      await widget.database.updateMindmapNode(
        current.id,
        MindmapNodesCompanion(
          title: Value(result.$1),
          content: Value(result.$2),
        ),
      );
      return;
    }
    final x = parent == null ? 24.0 : parent.x + 210;
    var y = parent?.y ?? 24.0;
    while (nodes.any(
      (node) => (node.x - x).abs() < 190 && (node.y - y).abs() < 96,
    )) {
      y += 100;
    }
    final node = MindmapNode(
      id: newId(),
      subjectId: subjectId,
      parentId: parent?.id,
      title: result.$1,
      content: result.$2,
      x: x,
      y: y,
      isSynced: false,
    );
    await widget.database.saveMindmapNode(node);
    if (mounted) setState(() => _selectedNodeId = node.id);
  }

  Future<void> _connectNode(MindmapNode node, List<MindmapNode> nodes) async {
    final byId = {for (final item in nodes) item.id: item};
    final parents = nodes.where((candidate) {
      final seen = {node.id};
      for (String? id = candidate.id; id != null; id = byId[id]?.parentId) {
        if (!seen.add(id)) return false;
      }
      return candidate.id != node.parentId;
    }).toList()..sort((a, b) => a.title.compareTo(b.title));
    final parentId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Nối “${node.title}” vào thẻ'),
        children: [
          if (parents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text('Chưa có thẻ phù hợp để nối.'),
            ),
          for (final parent in parents)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, parent.id),
              child: Text(parent.title),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
    if (parentId != null) {
      await widget.database.updateMindmapNode(
        node.id,
        MindmapNodesCompanion(parentId: Value(parentId)),
      );
    }
  }

  Future<void> _deleteNode(MindmapNode node) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thẻ?'),
        content: Text(
          'Xóa “${node.title}”. Các nhánh con sẽ trở thành ý chính.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa thẻ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.database.deleteMindmapNode(node);
    if (mounted) setState(() => _selectedNodeId = null);
  }

  Future<void> _finishDrag() async {
    final node = _draggingNode;
    setState(() => _draggingNode = null);
    if (node != null) {
      await widget.database.updateMindmapNode(
        node.id,
        MindmapNodesCompanion(x: Value(node.x), y: Value(node.y)),
      );
    }
  }

  Widget _canvas(String subjectId, List<MindmapNode> nodes) {
    final visible = [
      for (final node in nodes)
        if (node.id == _draggingNode?.id) _draggingNode! else node,
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = visible.fold(
            constraints.maxWidth,
            (width, node) => math.max(width, node.x + 210),
          );
          final height = visible.fold(
            constraints.maxHeight,
            (height, node) => math.max(height, node.y + 116),
          );
          return InteractiveViewer(
            key: ValueKey(subjectId),
            constrained: false,
            minScale: 0.35,
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selectedNodeId = null),
                      child: CustomPaint(
                        painter: _MindmapPainter(
                          nodes: visible,
                          selectedId: _selectedNodeId,
                        ),
                      ),
                    ),
                  ),
                  for (final node in visible)
                    Positioned(
                      key: ValueKey(node.id),
                      left: node.x,
                      top: node.y,
                      width: 170,
                      height: 76,
                      child: Semantics(
                        label: node.title,
                        button: true,
                        selected: _selectedNodeId == node.id,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              setState(() => _selectedNodeId = node.id),
                          onPanStart: (_) => setState(() {
                            _selectedNodeId = node.id;
                            _draggingNode = node;
                          }),
                          onPanUpdate: (details) => setState(() {
                            final row = _draggingNode!;
                            _draggingNode = row.copyWith(
                              x: math.max(0, row.x + details.delta.dx),
                              y: math.max(0, row.y + details.delta.dy),
                            );
                          }),
                          onPanEnd: (_) => _finishDrag(),
                          onPanCancel: () =>
                              setState(() => _draggingNode = null),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop(context)) return _buildMobileMindmap();
    return StreamBuilder<List<Subject>>(
      stream: _subjects,
      builder: (context, subjectSnapshot) {
        final subjects = subjectSnapshot.data ?? [];
        if (subjects.isEmpty) {
          return Center(
            child: FilledButton.icon(
              onPressed: _addSubject,
              icon: const Icon(Icons.add),
              label: const Text('Tạo môn học'),
            ),
          );
        }
        _subjectId ??= subjects.first.id;
        if (!subjects.any((subject) => subject.id == _subjectId)) {
          _subjectId = subjects.first.id;
        }
        final subjectId = _subjectId!;
        return StreamBuilder<List<MindmapNode>>(
          key: ValueKey(subjectId),
          stream: _watchMindmap(subjectId),
          builder: (context, nodeSnapshot) {
            final nodes = nodeSnapshot.data ?? [];
            final selected = _findNode(nodes, _selectedNodeId);
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<String>(
                        value: subjectId,
                        items: [
                          for (final subject in subjects)
                            DropdownMenuItem(
                              value: subject.id,
                              child: Text(subject.name),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _subjectId = value;
                          _selectedNodeId = null;
                          _draggingNode = null;
                        }),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addSubject,
                        icon: const Icon(Icons.library_add_outlined),
                        label: const Text('Thêm môn'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _editNode(nodes, subjectId),
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm ý chính'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selected == null
                        ? 'Bấm vào thẻ để chọn. Kéo nền để di chuyển bản đồ.'
                        : 'Đang chọn: ${selected.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: selected == null
                            ? null
                            : () =>
                                  _editNode(nodes, subjectId, parent: selected),
                        child: const Text('Thêm nhánh'),
                      ),
                      TextButton(
                        onPressed: selected == null
                            ? null
                            : () => _editNode(
                                nodes,
                                subjectId,
                                editing: selected,
                              ),
                        child: const Text('Chi tiết / Sửa'),
                      ),
                      TextButton(
                        onPressed: selected == null
                            ? null
                            : () => _connectNode(selected, nodes),
                        child: const Text('Nối vào…'),
                      ),
                      TextButton(
                        onPressed: selected == null || selected.parentId == null
                            ? null
                            : () => widget.database.updateMindmapNode(
                                selected.id,
                                const MindmapNodesCompanion(
                                  parentId: Value(null),
                                ),
                              ),
                        child: const Text('Gỡ kết nối'),
                      ),
                      TextButton(
                        onPressed: selected == null
                            ? null
                            : () => _deleteNode(selected),
                        child: const Text('Xóa thẻ'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: _canvas(subjectId, nodes)),
                  const SizedBox(height: 8),
                  Text(
                    '${nodes.length} thẻ · Lưu tự động trên thiết bị',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MindmapPainter extends CustomPainter {
  _MindmapPainter({required this.nodes, required this.selectedId});
  final List<MindmapNode> nodes;
  final String? selectedId;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFDFEFF),
    );
    final gridPaint = Paint()..color = const Color(0xFFE8ECF5);
    for (double x = 0; x < size.width; x += 28) {
      for (double y = 0; y < size.height; y += 28) {
        canvas.drawCircle(Offset(x, y), 1, gridPaint);
      }
    }
    final byId = {for (final node in nodes) node.id: node};
    final edgePaint = Paint()
      ..color = const Color(0xFF9AA9D0)
      ..strokeWidth = 2;
    for (final node in nodes.where((node) => node.parentId != null)) {
      final parent = byId[node.parentId];
      if (parent == null) continue;
      final start = Offset(parent.x + 170, parent.y + 38);
      final end = Offset(node.x, node.y + 38);
      final path = Path()..moveTo(start.dx, start.dy);
      final control = (start.dx + end.dx) / 2;
      path.cubicTo(control, start.dy, control, end.dy, end.dx, end.dy);
      canvas.drawPath(path, edgePaint);
    }
    for (final node in nodes) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(node.x, node.y, 170, 76),
        const Radius.circular(15),
      );
      final fill = Paint()
        ..color = node.id == selectedId
            ? const Color(0xFFE8EEFF)
            : Colors.white;
      final outline = Paint()
        ..color = node.id == selectedId
            ? const Color(0xFF5274E8)
            : const Color(0xFFD9E0EF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = node.id == selectedId ? 2 : 1;
      canvas.drawRRect(
        rect.shift(const Offset(0, 3)),
        Paint()..color = const Color(0x140D1A39),
      );
      canvas.drawRRect(rect, fill);
      canvas.drawRRect(rect, outline);
      final text = TextPainter(
        text: TextSpan(
          text: node.title,
          style: const TextStyle(
            color: Color(0xFF24304D),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: 138);
      text.paint(canvas, Offset(node.x + 16, node.y + 16));
      if (node.content.isNotEmpty) {
        final note = TextPainter(
          text: const TextSpan(
            text: 'Ghi chú',
            style: TextStyle(color: Color(0xFF70809E), fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        note.paint(canvas, Offset(node.x + 16, node.y + 52));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MindmapPainter oldDelegate) =>
      oldDelegate.nodes != nodes || oldDelegate.selectedId != selectedId;
}
