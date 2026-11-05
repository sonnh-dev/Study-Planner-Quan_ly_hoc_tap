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
    await _pushEvents();
    await _pullEvents();
    await _pushRoadmap();
    await _pullRoadmap();
    await _pushMindmap();
    await _pullMindmap();
  }

  Future<void> _pushSubjects() async {
    for (final row in await db.getSubjects()) {
      if (row.isSynced) continue;
      await api.put('/subjects/${row.id}', {
        'name': row.name,
        'color': row.color,
      });
      await db.saveSubject(row.copyWith(isSynced: true));
    }
  }

  Future<void> _pullSubjects() async {
    for (final item in _resultList(await api.get('/subjects'))) {
      await db.saveSubject(
        Subject(
          id: item['id'] as String,
          name: item['name'] as String,
          color: item['color'] as String? ?? '#5685F7',
          isSynced: true,
        ),
      );
    }
  }

  Future<void> _pushEvents() async {
    for (final row in await db.getEvents()) {
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
          if (await db.getEvent(row.id) == row) {
            await db.updateEvent(row.copyWith(isSynced: true));
          }
        });
      } on ApiFailure catch (error) {
        if (error.statusCode != 410) rethrow;
        await _removeRemoteEvent(row.id);
      }
    }
    for (final deletion in await db.getEventDeletions()) {
      await api.delete('/events/${deletion.id}');
      await db.acknowledgeEventDeletion(deletion.id);
    }
  }

  Future<void> _pullEvents() async {
    final response = await api.get('/events?includeDeleted=true');
    for (final item in _resultList(response)) {
      final id = item['id'] as String;
      if (item['deleted'] == true) {
        await _removeRemoteEvent(id);
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

  Future<void> _removeRemoteEvent(String id) => db.transaction(() async {
    final event = await db.getEvent(id);
    if (event == null) return;
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
    for (final subject in await db.getSubjects()) {
      final pending = (await db.getRoadmap(subject.id))
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
          throw StateError('Roadmap contains a cycle or a missing parent.');
        }
        for (final row in ready) {
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
          pending.remove(row);
        }
      }
    }
  }

  Future<void> _pullRoadmap() async {
    for (final subject in await db.getSubjects()) {
      for (final item in _resultList(
        await api.get('/subjects/${subject.id}/roadmap'),
      )) {
        final row = RoadmapNode(
          id: item['id'] as String,
          subjectId: item['subjectId'] as String,
          parentId: item['parentId'] as String?,
          title: item['title'] as String,
          note: item['note'] as String? ?? '',
          status: item['status'] as String? ?? 'planned',
          sortOrder: item['sortOrder'] as int? ?? 0,
          dueAt: item['dueAt'] == null
              ? null
              : DateTime.parse(item['dueAt'] as String).millisecondsSinceEpoch,
          isSynced: true,
        );
        await db.transaction(() async {
          final local = await db.getRoadmapNode(row.id);
          if (local == null || local.isSynced) {
            await db.saveRoadmapNode(row);
          }
        });
      }
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
