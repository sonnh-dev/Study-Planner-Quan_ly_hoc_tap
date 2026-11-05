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
  test('Roadmap sync retries and preserves a newer local edit', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    const subject = Subject(
      id: 'subject-1',
      name: 'Toán',
      color: '#5685F7',
      isSynced: false,
    );
    const parent = RoadmapNode(
      id: 'parent',
      subjectId: 'subject-1',
      parentId: null,
      title: 'Chương 1',
      note: '',
      status: 'planned',
      sortOrder: 0,
      dueAt: null,
      isSynced: false,
    );
    final child = parent.copyWith(
      id: 'child',
      parentId: const Value('parent'),
      title: 'Giới hạn',
      note: 'Bản đầu',
      sortOrder: 1,
    );
    await db.saveSubject(subject);
    await db.saveRoadmapNode(child);
    await db.saveRoadmapNode(parent);

    final newer = child.copyWith(note: 'Bản chỉnh sửa', status: 'done');
    final writes = <String>[];
    final remoteNodes = <String, Map<String, dynamic>>{};
    var childAttempts = 0;
    final httpClient = MockClient((request) async {
      final segments = request.url.pathSegments;
      final id = segments.last;
      if (request.method == 'PUT') {
        writes.add(id);
        if (id != subject.id) {
          if (id == child.id) {
            childAttempts++;
            if (childAttempts == 1) {
              return http.Response('{"errorMessage":"temporary failure"}', 503);
            }
            if (childAttempts == 2) {
              await db.saveRoadmapEdit(newer, create: false);
            }
          }
          remoteNodes[id] = {
            ...jsonDecode(request.body) as Map<String, dynamic>,
            'id': id,
          };
        }
        return http.Response('{}', 200);
      }

      final rows = switch (id) {
        'subjects' => [
          {'id': subject.id, 'name': subject.name, 'color': subject.color},
        ],
        'roadmap' => remoteNodes.values.toList(),
        _ => <Map<String, dynamic>>[],
      };
      return http.Response(
        jsonEncode({'result': rows}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    addTearDown(httpClient.close);
    final sync = SyncService(
      db,
      ApiClient(client: httpClient),
      NotificationService(),
    );

    await expectLater(sync.sync(), throwsA(isA<ApiFailure>()));
    expect(writes, [subject.id, parent.id, child.id]);
    expect((await db.getRoadmapNode(parent.id))!.isSynced, isTrue);
    expect(await db.getRoadmapNode(child.id), child);

    await sync.sync();
    expect(remoteNodes[child.id]!['note'], child.note);
    expect(await db.getRoadmapNode(child.id), newer);

    await sync.sync();
    expect(remoteNodes[child.id]!['note'], newer.note);
    expect(remoteNodes[child.id]!['status'], 'done');
    expect(await db.getRoadmapNode(child.id), newer.copyWith(isSynced: true));
    expect(writes, [subject.id, parent.id, child.id, child.id, child.id]);
  });

  test(
    'Roadmap and subject deletions synchronize without restoring old rows',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      const subject = Subject(
        id: 'subject',
        name: 'Toán',
        color: '#5685F7',
        isSynced: true,
      );
      const parent = RoadmapNode(
        id: 'parent',
        subjectId: 'subject',
        parentId: null,
        title: 'Chương 1',
        note: '',
        status: 'planned',
        sortOrder: 0,
        dueAt: null,
        isSynced: true,
      );
      final child = parent.copyWith(
        id: 'child',
        parentId: const Value('parent'),
      );
      await db.saveSubject(subject);
      await db.saveRoadmapNode(parent);
      await db.saveRoadmapNode(child);
      await db.saveMindmapNode(
        const MindmapNode(
          id: 'mindmap',
          subjectId: 'subject',
          parentId: null,
          title: 'Ý chính',
          content: '',
          x: 100,
          y: 100,
          isSynced: true,
        ),
      );
      await db.deleteRoadmapNode(subject.id, parent.id);
      expect(await db.getRoadmapNode(parent.id), isNull);
      expect((await db.getRoadmapNode(child.id))!.parentId, isNull);

      var branchAttempts = 0;
      var subjectDeleted = false;
      final client = MockClient((request) async {
        if (request.method == 'DELETE') {
          if (request.url.path == '/api/subjects/subject/roadmap/parent') {
            branchAttempts++;
            return http.Response('{}', branchAttempts == 1 ? 503 : 200);
          }
          expect(request.url.path, '/api/subjects/subject');
          subjectDeleted = true;
          return http.Response('{}', 200);
        }
        final rows = switch (request.url.pathSegments.last) {
          'subjects' => [
            {
              'id': subject.id,
              'name': subject.name,
              'color': subject.color,
              'deleted': subjectDeleted,
            },
          ],
          'roadmap' => [
            {'id': parent.id, 'deleted': true},
            {
              'id': child.id,
              'subjectId': child.subjectId,
              'title': child.title,
            },
          ],
          'mindmap' => [
            {'id': 'mindmap', 'subjectId': subject.id, 'title': 'Ý chính'},
          ],
          _ => <Map<String, dynamic>>[],
        };
        return http.Response(
          jsonEncode({'result': rows}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      addTearDown(client.close);
      final sync = SyncService(
        db,
        ApiClient(client: client),
        NotificationService(),
      );
      await expectLater(sync.sync(), throwsA(isA<ApiFailure>()));
      expect(await db.getRoadmapDeletions(), hasLength(1));
      await sync.sync();
      expect(await db.getRoadmapDeletions(), isEmpty);
      expect(await db.getRoadmap(subject.id), [
        child.copyWith(parentId: const Value(null)),
      ]);

      await db.saveRoadmapNode(parent);
      await db.saveRoadmapNode(child);
      await sync.sync();
      expect(await db.getRoadmapNode(parent.id), isNull);
      expect((await db.getRoadmapNode(child.id))!.parentId, isNull);

      await db.deleteSubject(subject.id);
      expect(await db.getSubject(subject.id), isNull);
      expect(await db.getRoadmap(subject.id), isEmpty);
      expect(await db.getMindmap(subject.id), isEmpty);
      expect(await db.getSubjectDeletions(), hasLength(1));
      await sync.sync();
      expect(subjectDeleted, isTrue);
      expect(await db.getSubjectDeletions(), isEmpty);
      expect(await db.getSubjects(), isEmpty);
    },
  );
}
