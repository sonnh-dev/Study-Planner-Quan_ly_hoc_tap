import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyplaner/data/api_client.dart';
import 'package:studyplaner/data/app_database.dart';
import 'package:studyplaner/data/notification_service.dart';
import 'package:studyplaner/data/sync_service.dart';

void main() {
  test('Mindmap deletion retries and keeps the child as a root', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    const subject = Subject(
      id: 'subject',
      name: 'Toán',
      color: '#5685F7',
      isSynced: true,
    );
    const parent = MindmapNode(
      id: 'parent',
      subjectId: 'subject',
      parentId: null,
      title: 'Đại số',
      content: '',
      x: 24,
      y: 24,
      isSynced: true,
    );
    final child = parent.copyWith(
      id: 'child',
      parentId: const Value('parent'),
      title: 'Phương trình',
      content: 'Ôn bài 2',
    );
    await db.saveSubject(subject);
    await db.saveMindmapNode(parent);
    await db.saveMindmapNode(child);
    await db.deleteMindmapNode(parent);

    expect(await db.getMindmapNode(parent.id), isNull);
    expect(
      await db.getMindmapNode(child.id),
      child.copyWith(parentId: const Value(null)),
    );

    var deletionAttempts = 0;
    final client = ApiClient(
      client: MockClient((request) async {
        final lastSegment = request.url.pathSegments.last;
        if (request.method == 'DELETE') {
          expect(request.url.path, '/api/subjects/subject/mindmap/parent');
          deletionAttempts++;
          return http.Response('{}', deletionAttempts == 1 ? 503 : 200);
        }
        final rows = switch (lastSegment) {
          'subjects' => [
            {'id': subject.id, 'name': subject.name, 'color': subject.color},
          ],
          'mindmap' => [
            {
              'id': child.id,
              'subjectId': subject.id,
              'title': child.title,
              'content': child.content,
              'x': child.x,
              'y': child.y,
            },
          ],
          _ => [],
        };
        return http.Response(
          jsonEncode({'result': rows}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final sync = SyncService(db, client, NotificationService());

    await expectLater(sync.sync(), throwsA(isA<ApiFailure>()));
    expect(await db.getMindmapDeletions(), hasLength(1));
    await sync.sync();
    expect(await db.getMindmapDeletions(), isEmpty);
    expect(await db.getMindmap(subject.id), [
      child.copyWith(parentId: const Value(null)),
    ]);
    expect(deletionAttempts, 2);
  });
}
