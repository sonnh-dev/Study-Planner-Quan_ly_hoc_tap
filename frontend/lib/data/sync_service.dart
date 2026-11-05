import 'package:studyplaner/data/api_client.dart';
import 'package:studyplaner/data/app_database.dart';
import 'package:studyplaner/data/notification_service.dart';

class SyncService {
  SyncService(this.db, this.api, this.notifications);
  final AppDatabase db;
  final ApiClient api;
  final NotificationService notifications;

  Future<void> sync() async {
    await _pushSubjects();
    await _pullSubjects();
    await syncEvents(refreshReminders: true);
    await _pushRoadmap();
    await _pullRoadmap();
    await _pushMindmap();
    await _pullMindmap();
  }

  Future<void> syncEvents({bool refreshReminders = false}) async {
    final token = api.token;
    await _pushEvents(token);
    if (api.token != token) return;
    await _pullEvents(token, refreshReminders: refreshReminders);
  }

  Future<void> _pushSubjects() async {
    for (final row in await db.getSubjects()) {
      if (row.isSynced) continue;
      try {
        await api.put('/subjects/${row.id}', {
          'name': row.name,
          'color': row.color,
        });
        await db.transaction(() async {
          if (await db.getSubject(row.id) == row) {
            await db.updateSubject(row.copyWith(isSynced: true));
          }
        });
      } on ApiFailure catch (error) {
        if (error.statusCode != 410) rethrow;
        await db.deleteSubject(row.id, queue: false);
      }
    }
    for (final deletion in await db.getSubjectDeletions()) {
      await api.delete('/subjects/${deletion.id}');
      await db.acknowledgeSubjectDeletion(deletion.id);
    }
  }

  Future<void> _pullSubjects() async {
    final remote = _resultList(await api.get('/subjects?includeDeleted=true'));
    await db.transaction(() async {
      final deleted = (await db.getSubjectDeletions())
          .map((deletion) => deletion.id)
          .toSet();
      final local = {for (final row in await db.getSubjects()) row.id: row};
      for (final item in remote) {
        final id = item['id'] as String;
        if (item['deleted'] == true) {
          if (local.containsKey(id)) await db.deleteSubject(id, queue: false);
          continue;
        }
        if (deleted.contains(id) || local[id]?.isSynced == false) continue;
        final row = Subject(
          id: id,
          name: item['name'] as String,
          color: item['color'] as String? ?? '#5685F7',
          isSynced: true,
        );
        if (local[id] != row) await db.saveSubject(row);
      }
    });
  }

  Future<void> _pushEvents(String? token) async {
    for (final row in await db.getEvents()) {
      if (api.token != token) return;
      if (row.isSynced) continue;
      try {
        await api.put('/events/${row.id}', {
          'title': row.title,
          'details': row.details,
          'startsAt': DateTime.fromMillisecondsSinceEpoch(row.startsAt)
              .toUtc()
              .toIso8601String(),
          'endsAt': DateTime.fromMillisecondsSinceEpoch(row.endsAt)
              .toUtc()
              .toIso8601String(),
          'reminderAt': row.reminderAt == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(row.reminderAt!)
                    .toUtc()
                    .toIso8601String(),
        });
        await db.transaction(() async {
          final local = await db.getEvent(row.id);
          if (api.token == token && local == row) {
            await db.updateEvent(row.copyWith(isSynced: true));
          }
        });
      } on ApiFailure catch (error) {
        if (api.token != token) return;
        if (error.statusCode != 410) rethrow;
        await _removeRemoteEvent(row.id, token);
      }
    }
    for (final deletion in await db.getEventDeletions()) {
      if (api.token != token) return;
      await api.delete('/events/${deletion.id}');
      if (api.token != token) return;
      await db.acknowledgeEventDeletion(deletion.id);
    }
  }

  Future<void> _pullEvents(
    String? token, {
    required bool refreshReminders,
  }) async {
    final response = await api.get('/events?includeDeleted=true');
    for (final item in _resultList(response)) {
      if (api.token != token) return;
      final id = item['id'] as String;
      if (item['deleted'] == true) {
        await _removeRemoteEvent(id, token);
        continue;
      }
      final event = StudyEvent(
        id: id,
        title: item['title'] as String,
        details: item['details'] as String? ?? '',
        startsAt: DateTime.parse(item['startsAt'] as String)
            .millisecondsSinceEpoch,
        endsAt: DateTime.parse(item['endsAt'] as String).millisecondsSinceEpoch,
        reminderAt: item['reminderAt'] == null
            ? null
            : DateTime.parse(item['reminderAt'] as String)
                  .millisecondsSinceEpoch,
        isSynced: true,
      );
      await db.transaction(() async {
        final local = await db.getEvent(id);
        if (local?.isSynced == false || await db.hasEventDeletion(id)) return;
        if (api.token != token || (local == event && !refreshReminders)) return;
        if (local != event) await db.saveEvent(event);
        final notificationId = id.hashCode & 0x7fffffff;
        try {
          if (local?.reminderAt != null && local != event) {
            await notifications.cancel(notificationId);
          }
          if (event.reminderAt != null) {
            await notifications.schedule(
              notificationId,
              event.title,
              DateTime.fromMillisecondsSinceEpoch(event.reminderAt!),
            );
          }
        } catch (_) {
          // Data sync should still succeed if the OS denies notifications.
        }
      });
    }
  }

  Future<void> _removeRemoteEvent(String id, String? token) =>
      db.transaction(() async {
        final event = await db.getEvent(id);
        if (event == null || api.token != token) return;
        await db.deleteEvent(id, queue: false);
        if (event.reminderAt != null) {
          try {
            await notifications.cancel(id.hashCode & 0x7fffffff);
          } catch (_) {
            // The deletion still applies if notifications are unavailable.
          }
        }
      });

  Future<void> _pushRoadmap() async {
    for (final deletion in await db.getRoadmapDeletions()) {
      await api.delete(
        '/subjects/${deletion.subjectId}/roadmap/${deletion.id}',
      );
      await db.acknowledgeRoadmapDeletion(deletion.id);
    }
    for (final subject in await db.getSubjects()) {
      final rows = await db.getRoadmap(subject.id);
      if (rows.every((row) => row.isSynced)) continue;
      final ids = rows.map((row) => row.id).toSet();
      final children = <String, List<RoadmapNode>>{};
      final ordered = <RoadmapNode>[];
      for (final row in rows) {
        final parentId = row.parentId;
        if (parentId == null || !ids.contains(parentId)) {
          ordered.add(row);
        } else {
          (children[parentId] ??= []).add(row);
        }
      }
      for (var index = 0; index < ordered.length; index++) {
        ordered.addAll(children[ordered[index].id] ?? const []);
      }
      if (ordered.length != rows.length) {
        final visited = ordered.map((row) => row.id).toSet();
        if (rows.any((row) => !row.isSynced && !visited.contains(row.id))) {
          throw StateError(
            'Roadmap contains a cycle. Change the parent and sync again.',
          );
        }
      }
      for (final row in ordered) {
        if (row.isSynced || await db.getRoadmapNode(row.id) != row) continue;
        try {
          await api.put('/roadmap/${row.id}', {
            'subjectId': row.subjectId,
            'parentId': row.parentId,
            'title': row.title,
            'note': row.note,
            'status': row.status,
            'sortOrder': row.sortOrder,
            'dueAt': row.dueAt == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(row.dueAt!)
                      .toUtc()
                      .toIso8601String(),
          });
          await db.transaction(() async {
            if (await db.getRoadmapNode(row.id) == row) {
              await db.saveRoadmapNode(row.copyWith(isSynced: true));
            }
          });
        } on ApiFailure catch (error) {
          if (error.statusCode != 410) rethrow;
          await db.deleteRoadmapNode(subject.id, row.id, queue: false);
        }
      }
    }
  }

  Future<void> _pullRoadmap() async {
    for (final subject in await db.getSubjects()) {
      final remote = _resultList(
        await api.get('/subjects/${subject.id}/roadmap?includeDeleted=true'),
      );
      await db.transaction(() async {
        if (await db.getSubject(subject.id) == null) return;
        final deleted = (await db.getRoadmapDeletions())
            .map((deletion) => deletion.id)
            .toSet();
        for (final item in remote.where((item) => item['deleted'] == true)) {
          final id = item['id'] as String;
          if (deleted.add(id)) {
            await db.deleteRoadmapNode(subject.id, id, queue: false);
          }
        }
        final local = {
          for (final row in await db.getRoadmap(subject.id)) row.id: row,
        };
        for (final item in remote) {
          final id = item['id'] as String;
          if (deleted.contains(id) || local[id]?.isSynced == false) continue;
          final parentId = item['parentId'] as String?;
          final row = RoadmapNode(
            id: id,
            subjectId: item['subjectId'] as String,
            parentId: deleted.contains(parentId) ? null : parentId,
            title: item['title'] as String,
            note: item['note'] as String? ?? '',
            status: item['status'] as String? ?? 'planned',
            sortOrder: item['sortOrder'] as int? ?? 0,
            dueAt: item['dueAt'] == null
                ? null
                : DateTime.parse(item['dueAt'] as String)
                      .millisecondsSinceEpoch,
            isSynced: true,
          );
          if (local[id] != row) await db.saveRoadmapNode(row);
        }
      });
    }
  }

  Future<void> _pushMindmap() async {
    for (final deletion in await db.getMindmapDeletions()) {
      await api.delete(
        '/subjects/${deletion.subjectId}/mindmap/${deletion.id}',
      );
      await db.acknowledgeMindmapDeletion(deletion.id);
    }
    for (final subject in await db.getSubjects()) {
      final pending = (await db.getMindmap(subject.id))
          .where((row) => !row.isSynced)
          .toList();
      while (pending.isNotEmpty) {
        final pendingIds = pending.map((row) => row.id).toSet();
        final ready = pending
            .where(
              (row) =>
                  row.parentId == null || !pendingIds.contains(row.parentId),
            )
            .toList();
        if (ready.isEmpty) {
          throw StateError('Mindmap contains a cycle or a missing parent.');
        }
        for (final row in ready) {
          try {
            await api.put('/mindmap/${row.id}', {
              'subjectId': row.subjectId,
              'parentId': row.parentId,
              'title': row.title,
              'content': row.content,
              'x': row.x,
              'y': row.y,
            });
            await db.transaction(() async {
              if (await db.getMindmapNode(row.id) == row) {
                await db.saveMindmapNode(row.copyWith(isSynced: true));
              }
            });
          } on ApiFailure catch (error) {
            if (error.statusCode != 410) rethrow;
            await db.deleteMindmapNode(row, queue: false);
          }
          pending.remove(row);
        }
      }
    }
  }

  Future<void> _pullMindmap() async {
    for (final subject in await db.getSubjects()) {
      final response = await api.get('/subjects/${subject.id}/mindmap');
      final remote = (response['result'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      await db.transaction(() async {
        if (await db.getSubject(subject.id) == null) return;
        final remoteIds = remote.map((item) => item['id']).toSet();
        final deletions = (await db.getMindmapDeletions())
            .map((deletion) => deletion.id)
            .toSet();
        final local = {
          for (final row in await db.getMindmap(subject.id)) row.id: row,
        };
        for (final row in local.values) {
          if (row.isSynced && !remoteIds.contains(row.id)) {
            await db.deleteMindmapNode(row, queue: false);
          }
        }
        for (final item in remote) {
          final id = item['id'] as String;
          if (deletions.contains(id) || local[id]?.isSynced == false) continue;
          await db.saveMindmapNode(
            MindmapNode(
              id: id,
              subjectId: item['subjectId'] as String,
              parentId: item['parentId'] as String?,
              title: item['title'] as String,
              content: item['content'] as String? ?? '',
              x: (item['x'] as num?)?.toDouble() ?? 100,
              y: (item['y'] as num?)?.toDouble() ?? 100,
              isSynced: true,
            ),
          );
        }
      });
    }
  }

  List<Map<String, dynamic>> _resultList(Map<String, dynamic> response) =>
      (response['result'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
}
