import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyplaner/data/api_client.dart';
import 'package:studyplaner/data/app_database.dart';
import 'package:studyplaner/data/notification_service.dart';
import 'package:studyplaner/data/sync_service.dart';

void main() {
  test(
    'Schedule sync preserves newer edits and retries offline deletion',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      const original = StudyEvent(
        id: 'event',
        title: 'Algebra',
        details: 'Draft',
        startsAt: 1793840400000,
        endsAt: 1793844000000,
        reminderAt: null,
        isSynced: false,
      );
      final edited = original.copyWith(details: 'Chapter 2');
      await db.saveEvent(original);
      var remote = <String, dynamic>{};
      var updates = 0;
      var deletions = 0;
      final client = MockClient((request) async {
        switch (request.method) {
          case 'PUT':
            expect(request.url.path, '/api/events/event');
            remote = {
              ...jsonDecode(request.body) as Map<String, dynamic>,
              'id': original.id,
            };
            if (++updates == 1) await db.updateEvent(edited);
            return http.Response('{}', 200);
          case 'DELETE':
            expect(request.url.path, '/api/events/event');
            if (++deletions == 1) return http.Response('{}', 503);
            remote['deleted'] = true;
            return http.Response('{}', 200);
          default:
            if (request.url.path == '/api/events') {
              expect(request.url.queryParameters['includeDeleted'], 'true');
              if (updates == 2 && deletions == 0) {
                await db.deleteEvent(original.id);
              }
              return http.Response(
                jsonEncode({
                  'result': [remote],
                }),
                200,
              );
            }
            return http.Response('{"result":[]}', 200);
        }
      });
      addTearDown(client.close);
      final sync = SyncService(
        db,
        ApiClient(client: client),
        NotificationService(),
      );

      await sync.sync();
      expect(remote['details'], original.details);
      expect(await db.getEvent(original.id), edited);

      await sync.sync();
      expect(remote['details'], edited.details);
      expect(await db.getEvents(), isEmpty);
      expect(await db.hasEventDeletion(original.id), isTrue);

      await expectLater(sync.sync(), throwsA(isA<ApiFailure>()));
      expect(await db.hasEventDeletion(original.id), isTrue);
      await sync.sync();
      expect(await db.hasEventDeletion(original.id), isFalse);
      expect(await db.getEvents(), isEmpty);
      expect(deletions, 2);

      await db.saveEvent(edited.copyWith(isSynced: true));
      await sync.sync();
      expect(await db.getEvents(), isEmpty);
    },
  );
}
