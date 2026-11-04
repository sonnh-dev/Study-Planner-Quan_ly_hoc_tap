import 'dart:math' as math;

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

  bool _isDesktop(BuildContext context) =>
      defaultTargetPlatform == TargetPlatform.windows ||
      (kIsWeb && MediaQuery.sizeOf(context).width >= 760);

  static const _webEditorUrl = String.fromEnvironment(
    'WEB_EDITOR_URL',
    defaultValue: 'http://localhost:5000',
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
    stream: widget.database.watchSubjects(),
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
              stream: widget.database.watchMindmap(subjectId),
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
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: current?.title ?? '',
                onChanged: (value) => title = value,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Tiêu đề'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: current?.content ?? '',
                onChanged: (value) => content = value,
                maxLines: 5,
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
    final node = current == null
        ? MindmapNode(
            id: newId(),
            subjectId: subjectId,
            parentId: parent?.id,
            title: result.$1,
            content: result.$2,
            x: parent == null ? 100 + nodes.length * 24 : parent.x + 210,
            y: parent == null ? 100 + nodes.length * 24 : parent.y + 110,
            isSynced: false,
          )
        : current.copyWith(
            title: result.$1,
            content: result.$2,
            isSynced: false,
          );
    await widget.database.saveMindmapNode(node);
    if (mounted) setState(() => _selectedNodeId = node.id);
  }

  MindmapNode? _nodeAt(Offset position, List<MindmapNode> nodes) {
    for (final node in nodes.reversed) {
      if (Rect.fromLTWH(node.x, node.y, 170, 76).contains(position)) {
        return node;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop(context)) return _buildMobileMindmap();
    return StreamBuilder<List<Subject>>(
      stream: widget.database.watchSubjects(),
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
          stream: widget.database.watchMindmap(subjectId),
          builder: (context, nodeSnapshot) {
            final nodes = nodeSnapshot.data ?? [];
            return Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bản đồ tư duy',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text('Kéo thả các thẻ để sắp xếp ý tưởng.'),
                          ],
                        ),
                      ),
                      DropdownButton<String>(
                        value: subjectId,
                        items: subjects
                            .map(
                              (subject) => DropdownMenuItem(
                                value: subject.id,
                                child: Text(subject.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          _subjectId = value;
                          _selectedNodeId = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _addSubject,
                        icon: const Icon(Icons.library_add_outlined),
                        label: const Text('Môn học'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => _editNode(
                          nodes,
                          subjectId,
                          parent: _findNode(nodes, _selectedNodeId),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(
                          _selectedNodeId == null
                              ? 'Thêm ý chính'
                              : 'Thêm nhánh',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(color: Colors.white),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (details) {
                                final found = _nodeAt(
                                  details.localPosition,
                                  nodes,
                                );
                                setState(() => _selectedNodeId = found?.id);
                                if (found != null) {
                                  _editNode(nodes, subjectId, editing: found);
                                }
                              },
                              onPanStart: (details) {
                                _draggingNode = _nodeAt(
                                  details.localPosition,
                                  nodes,
                                );
                              },
                              onPanUpdate: (details) async {
                                final row = _draggingNode;
                                if (row != null) {
                                  final moved = row.copyWith(
                                    x: math.max(0.0, row.x + details.delta.dx),
                                    y: math.max(0.0, row.y + details.delta.dy),
                                    isSynced: false,
                                  );
                                  _draggingNode = moved;
                                  await widget.database.saveMindmapNode(moved);
                                }
                              },
                              onPanEnd: (_) => _draggingNode = null,
                              child: CustomPaint(
                                size: Size(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                ),
                                painter: _MindmapPainter(
                                  nodes: nodes,
                                  selectedId: _selectedNodeId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
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
