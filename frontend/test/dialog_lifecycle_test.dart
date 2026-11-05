import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyplaner/data/api_client.dart';
import 'package:studyplaner/data/app_database.dart';
import 'package:studyplaner/data/notification_service.dart';
import 'package:studyplaner/data/session_store.dart';
import 'package:studyplaner/data/sync_service.dart';
import 'package:studyplaner/screens/app_shell.dart';
import 'package:studyplaner/screens/focus_screen.dart';
import 'package:studyplaner/screens/mindmap_screen.dart';
import 'package:studyplaner/screens/roadmap_screen.dart';
import 'package:studyplaner/screens/schedule_screen.dart';
import 'package:studyplaner/study_app.dart';

const _subject = Subject(
  id: 'subject-1',
  name: 'Toán',
  color: '#5685F7',
  isSynced: false,
);

class _UnavailableSessionStore implements SessionStore {
  @override
  Future<String?> readToken() async => throw StateError('Storage unavailable');

  @override
  Future<String?> readEmail() async => null;

  @override
  Future<void> save(String token, String email) async =>
      throw StateError('Storage unavailable');

  @override
  Future<void> clear() async => throw StateError('Storage unavailable');
}

class _RestoredSessionStore extends _UnavailableSessionStore {
  @override
  Future<String?> readToken() async => 'test-token';

  @override
  Future<String?> readEmail() async => 'student@example.com';

  @override
  Future<void> clear() async {}
}

class _DialogDatabase implements AppDatabase {
  final List<Subject> subjectRows = [];
  final List<RoadmapNode> roadmapRows = [];
  final List<MindmapNode> mindmapRows = [];
  final List<StudyEvent> eventRows = [];
  final _subjectChanges = StreamController<List<Subject>>.broadcast();
  final _roadmapChanges = StreamController<void>.broadcast();
  final _eventChanges = StreamController<List<StudyEvent>>.broadcast();

  @override
  Stream<List<Subject>> watchSubjects() async* {
    yield List.unmodifiable(subjectRows);
    yield* _subjectChanges.stream;
  }

  @override
  Stream<Subject?> watchSubject(String id) => watchSubjects().map(
    (rows) => rows.where((row) => row.id == id).firstOrNull,
  );

  @override
  Stream<List<RoadmapNode>> watchRoadmap(String subjectId) async* {
    List<RoadmapNode> rows() =>
        roadmapRows.where((row) => row.subjectId == subjectId).toList();
    yield rows();
    yield* _roadmapChanges.stream.map((_) => rows());
  }

  @override
  Stream<List<MindmapNode>> watchMindmap(String subjectId) => Stream.value(
    mindmapRows.where((row) => row.subjectId == subjectId).toList(),
  );

  @override
  Stream<List<StudyEvent>> watchEvents() async* {
    yield List.unmodifiable(eventRows);
    yield* _eventChanges.stream;
  }

  @override
  Future<List<StudyEvent>> getEvents() async => List.of(eventRows);

  @override
  Future<StudyEvent?> getEvent(String id) async =>
      eventRows.where((event) => event.id == id).firstOrNull;

  @override
  Future<List<StudyEventDeletion>> getEventDeletions() async => [];

  @override
  Future<bool> hasEventDeletion(String id) async => false;

  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) => action();

  @override
  Future<void> saveSubject(Subject row) async {
    subjectRows.add(row);
    _subjectChanges.add(List.unmodifiable(subjectRows));
  }

  @override
  Future<void> updateSubject(Subject row) async {
    subjectRows[subjectRows.indexWhere((existing) => existing.id == row.id)] =
        row;
    _subjectChanges.add(List.unmodifiable(subjectRows));
  }

  @override
  Future<void> deleteSubject(String id, {bool queue = true}) async {
    subjectRows.removeWhere((row) => row.id == id);
    roadmapRows.removeWhere((row) => row.subjectId == id);
    _subjectChanges.add(List.unmodifiable(subjectRows));
    _roadmapChanges.add(null);
  }

  @override
  Future<void> saveRoadmapEdit(RoadmapNode row, {required bool create}) async {
    roadmapRows.removeWhere((existing) => existing.id == row.id);
    roadmapRows.add(row.copyWith(isSynced: false));
    _roadmapChanges.add(null);
  }

  @override
  Future<void> deleteRoadmapNode(
    String subjectId,
    String id, {
    bool queue = true,
  }) async {
    roadmapRows.removeWhere((row) => row.id == id);
    for (var index = 0; index < roadmapRows.length; index++) {
      if (roadmapRows[index].parentId == id) {
        final row = roadmapRows[index];
        roadmapRows[index] = RoadmapNode(
          id: row.id,
          subjectId: row.subjectId,
          parentId: null,
          title: row.title,
          note: row.note,
          status: row.status,
          sortOrder: row.sortOrder,
          dueAt: row.dueAt,
          isSynced: row.isSynced,
        );
      }
    }
    _roadmapChanges.add(null);
  }

  @override
  Future<void> saveEvent(StudyEvent row) async {
    eventRows.add(row);
    _eventChanges.add(List.unmodifiable(eventRows));
  }

  @override
  Future<void> updateEvent(StudyEvent row) async {
    final index = eventRows.indexWhere((existing) => existing.id == row.id);
    eventRows[index] = row;
    _eventChanges.add(List.unmodifiable(eventRows));
  }

  @override
  Future<void> deleteEvent(String id, {bool queue = true}) async {
    eventRows.removeWhere((row) => row.id == id);
    _eventChanges.add(List.unmodifiable(eventRows));
  }

  @override
  Future<void> saveMindmapNode(MindmapNode row) async {
    mindmapRows.removeWhere((existing) => existing.id == row.id);
    mindmapRows.add(row);
  }

  @override
  Future<void> updateMindmapNode(String id, MindmapNodesCompanion changes) =>
      saveMindmapNode(
        mindmapRows
            .singleWhere((row) => row.id == id)
            .copyWith(
              title: changes.title.value,
              content: changes.content.value,
              isSynced: false,
            ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DialogNotifications implements NotificationService {
  final List<String> scheduledTitles = [];
  final List<int> canceledIds = [];

  @override
  Future<void> schedule(int id, String title, DateTime when) async {
    scheduledTitles.add(title);
  }

  @override
  Future<void> cancel(int id) async => canceledIds.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _openScreen(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(1400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: screen)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Hẹn giờ tập trung dùng mốc nhanh và thời lượng tùy chỉnh', (
    tester,
  ) async {
    final notifications = _DialogNotifications();
    await _openScreen(
      tester,
      FocusScreen(notifications: notifications),
      size: const Size(320, 500),
    );
    for (final label in ['10 phút', '15 phút', '20 phút', '30 phút', '1 giờ']) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
    }
    await tester.tap(find.text('1 giờ'));
    await tester.pumpAndSettle();
    expect(find.text('01:00:00'), findsOneWidget);
    await tester.tap(find.text('15 phút'));
    await tester.pumpAndSettle();
    final clock = find.text('00:15:00');
    await tester.ensureVisible(clock);
    await tester.pumpAndSettle();
    await tester.tap(clock);
    await tester.pumpAndSettle();

    final wheels = tester
        .widgetList<CupertinoPicker>(find.byType(CupertinoPicker))
        .toList();
    expect(wheels, hasLength(3));
    wheels[1].scrollController!.jumpToItem(0);
    await tester.pumpAndSettle();
    final apply = find.widgetWithText(FilledButton, 'Áp dụng');
    expect(tester.widget<FilledButton>(apply).onPressed, isNull);
    wheels[0].scrollController!.jumpToItem(1);
    wheels[1].scrollController!.jumpToItem(2);
    wheels[2].scrollController!.jumpToItem(5);
    await tester.pumpAndSettle();
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(find.text('01:02:05'), findsOneWidget);

    final start = find.text('Bắt đầu');
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('01:02:03'), findsOneWidget);
    expect(find.text('Chỉnh thời lượng'), findsNothing);
    final pause = find.text('Tạm dừng');
    await tester.ensureVisible(pause);
    await tester.pump();
    await tester.tap(pause);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('01:02:03'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsOneWidget);
    final reset = find.text('Đặt lại');
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.text('01:02:05'), findsOneWidget);
    expect(notifications.scheduledTitles, ['Hẹn giờ tập trung đã kết thúc']);
    expect(notifications.canceledIds, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Registration opens the app when secure storage is unavailable', (
    tester,
  ) async {
    final database = _DialogDatabase();
    final notifications = _DialogNotifications();
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/auth/register');
        return http.Response(
          '{"result":{"token":"test-token","email":"student@example.com"}}',
          200,
        );
      }),
    );
    await tester.pumpWidget(
      StudyPlannerApp(
        database: database,
        api: api,
        session: _UnavailableSessionStore(),
        sync: SyncService(database, api, notifications),
        notifications: notifications,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'student@example.com');
    await tester.enterText(find.byType(TextField).last, 'test-password');
    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(api.token, 'test-token');
    expect(find.textContaining('Phiên chỉ dùng lần này'), findsOneWidget);
    await tester.tap(find.byTooltip('student@example.com'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsNothing);
    expect(api.token, isNull);
  });

  testWidgets('Lịch tự đồng bộ mỗi phút trong phiên đăng nhập', (tester) async {
    const eventResponse =
        '{"result":[{"id":"event-1","title":"Học Toán",'
        '"startsAt":"2026-11-05T12:00:00Z","endsAt":"2026-11-05T13:00:00Z",'
        '"reminderAt":"2026-11-05T11:50:00Z"}]}';
    const jsonHeaders = {'content-type': 'application/json; charset=utf-8'};
    final database = _DialogDatabase();
    final notifications = _DialogNotifications();
    final firstRequest = Completer<http.Response>();
    final lateRequest = Completer<http.Response>();
    var polls = 0;
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/events');
      expect(request.url.queryParameters['includeDeleted'], 'true');
      expect(request.headers['Authorization'], 'Bearer test-token');
      return switch (++polls) {
        1 => firstRequest.future,
        4 => lateRequest.future,
        _ => http.Response(eventResponse, 200, headers: jsonHeaders),
      };
    });
    addTearDown(client.close);
    final api = ApiClient(client: client);
    await tester.pumpWidget(
      StudyPlannerApp(
        database: database,
        api: api,
        session: _RestoredSessionStore(),
        sync: SyncService(database, api, notifications),
        notifications: notifications,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 59));
    expect(polls, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(polls, 1);
    await tester.pump(const Duration(minutes: 1));
    expect(polls, 1);
    final syncButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Đồng bộ dữ liệu',
    );
    expect(tester.widget<IconButton>(syncButton).onPressed, isNull);

    firstRequest.complete(http.Response('{}', 503));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(polls, 2);
    expect(database.eventRows.single.title, 'Học Toán');
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(polls, 3);
    expect(notifications.scheduledTitles, ['Học Toán']);

    await tester.pump(const Duration(minutes: 1));
    expect(polls, 4);
    await tester.tap(find.byTooltip('student@example.com'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(api.token, isNull);
    lateRequest.complete(
      http.Response(
        eventResponse.replaceFirst('event-1', 'late-event'),
        200,
        headers: jsonHeaders,
      ),
    );
    await tester.pump(const Duration(minutes: 2));
    expect(database.eventRows.single.id, 'event-1');
    expect(polls, 4);
  });

  for (final mindmap in [false, true]) {
    for (final save in [false, true]) {
      testWidgets(
        '${mindmap ? 'Mindmap' : 'Roadmap'} subject dialog closes safely on ${save ? 'save' : 'cancel'}',
        (tester) async {
          final database = _DialogDatabase();
          await _openScreen(
            tester,
            mindmap
                ? MindmapScreen(database: database)
                : RoadmapScreen(database: database),
          );
          await tester.tap(find.text('Tạo môn học'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '  Toán  ');
          await tester.tap(find.text(save ? 'Lưu' : 'Hủy'));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(AlertDialog), findsNothing);
          expect(
            database.subjectRows.map((row) => row.name),
            save ? ['Toán'] : isEmpty,
          );
        },
        variant: TargetPlatformVariant.only(
          mindmap ? TargetPlatform.windows : TargetPlatform.android,
        ),
      );
    }
  }

  for (final save in [false, true]) {
    testWidgets(
      'Roadmap node dialog keeps text through parent selection and closes on ${save ? 'save' : 'cancel'}',
      (tester) async {
        final database = _DialogDatabase()
          ..subjectRows.add(_subject)
          ..roadmapRows.add(
            const RoadmapNode(
              id: 'parent',
              subjectId: 'subject-1',
              parentId: null,
              title: 'Chủ đề cha',
              note: '',
              status: 'planned',
              sortOrder: 0,
              dueAt: null,
              isSynced: false,
            ),
          );
        await _openScreen(tester, RoadmapScreen(database: database));
        await tester.tap(find.text(_subject.name));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Thêm nhánh'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(0), '  Giới hạn  ');
        await tester.enterText(find.byType(TextField).at(1), '  Ôn chương 1  ');
        await tester.tap(find.byType(DropdownButtonFormField<String?>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chủ đề cha').last);
        await tester.pumpAndSettle();
        expect(find.text('  Giới hạn  '), findsOneWidget);
        await tester.tap(find.text(save ? 'Thêm' : 'Hủy'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(AlertDialog), findsNothing);
        expect(database.roadmapRows, hasLength(save ? 2 : 1));
        if (save) {
          expect(database.roadmapRows.last.title, 'Giới hạn');
          expect(database.roadmapRows.last.note, 'Ôn chương 1');
          expect(database.roadmapRows.last.parentId, 'parent');
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'Mindmap node dialog closes safely on ${save ? 'save' : 'cancel'}',
      (tester) async {
        final database = _DialogDatabase()..subjectRows.add(_subject);
        await _openScreen(tester, MindmapScreen(database: database));
        await tester.tap(find.text('Thêm ý chính'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(0), '  Đại số  ');
        await tester.enterText(
          find.byType(TextField).at(1),
          '  Ôn phương trình  ',
        );
        await tester.tap(find.text(save ? 'Lưu' : 'Hủy'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(AlertDialog), findsNothing);
        expect(database.mindmapRows, hasLength(save ? 1 : 0));
        if (save) {
          expect(database.mindmapRows.single.title, 'Đại số');
          expect(database.mindmapRows.single.content, 'Ôn phương trình');
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets(
      'Editing a mindmap node preserves existing content on ${save ? 'save' : 'cancel'}',
      (tester) async {
        final database = _DialogDatabase()
          ..subjectRows.add(_subject)
          ..mindmapRows.add(
            const MindmapNode(
              id: 'node-1',
              subjectId: 'subject-1',
              parentId: null,
              title: 'Tiêu đề cũ',
              content: 'Ghi chú cũ',
              x: 100,
              y: 100,
              isSynced: false,
            ),
          );
        await _openScreen(tester, MindmapScreen(database: database));
        final canvas = find.descendant(
          of: find.byType(MindmapScreen),
          matching: find.byType(ClipRRect),
        );
        await tester.tapAt(tester.getTopLeft(canvas) + const Offset(120, 120));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        await tester.tap(find.text('Chi tiết / Sửa'));
        await tester.pumpAndSettle();
        expect(find.text('Chỉnh sửa ghi chú'), findsOneWidget);
        expect(find.text('Ghi chú cũ'), findsOneWidget);
        await tester.enterText(find.byType(TextField).at(0), 'Tiêu đề mới');
        await tester.tap(find.text(save ? 'Lưu' : 'Hủy'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(AlertDialog), findsNothing);
        expect(database.mindmapRows, hasLength(1));
        expect(database.mindmapRows.single.id, 'node-1');
        expect(
          database.mindmapRows.single.title,
          save ? 'Tiêu đề mới' : 'Tiêu đề cũ',
        );
        expect(database.mindmapRows.single.content, 'Ghi chú cũ');
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets(
      'Schedule dialog closes safely on ${save ? 'save' : 'cancel'}',
      (tester) async {
        final database = _DialogDatabase();
        final notifications = _DialogNotifications();
        await _openScreen(
          tester,
          ScheduleScreen(database: database, notifications: notifications),
        );
        await tester.tap(find.text('Thêm lịch'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(0), '  Học Toán  ');
        await tester.enterText(find.byType(TextField).at(1), '  Làm bài tập  ');
        await tester.tap(find.text(save ? 'Lưu lịch' : 'Hủy'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(AlertDialog), findsNothing);
        expect(database.eventRows, hasLength(save ? 1 : 0));
        expect(notifications.scheduledTitles, save ? ['Học Toán'] : isEmpty);
        if (save) {
          expect(database.eventRows.single.title, 'Học Toán');
          expect(database.eventRows.single.details, 'Làm bài tập');
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets('Lịch ngày trên điện thoại cho phép đổi giờ và xóa buổi học', (
    tester,
  ) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 9);
    final end = start.add(const Duration(hours: 2));
    final event = StudyEvent(
      id: 'event-1',
      title: 'Học Toán',
      details: 'Ôn bài cũ',
      startsAt: start.millisecondsSinceEpoch,
      endsAt: end.millisecondsSinceEpoch,
      reminderAt: start
          .subtract(const Duration(minutes: 10))
          .millisecondsSinceEpoch,
      isSynced: true,
    );
    final database = _DialogDatabase()..eventRows.add(event);
    final notifications = _DialogNotifications();
    await _openScreen(
      tester,
      ScheduleScreen(database: database, notifications: notifications),
      size: const Size(360, 740),
    );
    expect(find.text('09:00\n– 11:00'), findsOneWidget);
    await tester.tap(find.byTooltip('Ngày sau'));
    await tester.pumpAndSettle();
    expect(find.text(event.title), findsNothing);
    await tester.tap(find.text('Hôm nay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(event.title));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(event.details),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Chọn giờ bắt đầu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to text input mode'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '10');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu lịch'));
    await tester.pumpAndSettle();
    expect(find.text('10:00\n– 11:00'), findsOneWidget);
    expect(database.eventRows.single.id, event.id);
    expect(database.eventRows.single.isSynced, isFalse);
    expect(notifications.scheduledTitles, [event.title]);

    await tester.tap(find.byTooltip('Thao tác lịch học'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa lịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(database.eventRows, hasLength(1));

    await tester.tap(find.byTooltip('Thao tác lịch học'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa lịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa lịch'));
    await tester.pumpAndSettle();
    expect(database.eventRows, isEmpty);
    expect(find.text('Chưa có lịch học trong ngày này.'), findsOneWidget);
    expect(
      notifications.canceledIds,
      List.filled(2, event.id.hashCode & 0x7fffffff),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mở đúng môn, thu gọn cây và sửa ghi chú, trạng thái nhánh', (
    tester,
  ) async {
    const other = Subject(
      id: 'subject-2',
      name: 'Lập trình',
      color: '#5685F7',
      isSynced: true,
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
      isSynced: true,
    );
    const child = RoadmapNode(
      id: 'child',
      subjectId: 'subject-1',
      parentId: 'parent',
      title: 'Giới hạn',
      note: 'Ghi chú cũ',
      status: 'planned',
      sortOrder: 1,
      dueAt: 1789992000000,
      isSynced: true,
    );
    final database = _DialogDatabase()
      ..subjectRows.addAll([_subject, other])
      ..roadmapRows.addAll([parent, child]);

    await _openScreen(
      tester,
      RoadmapScreen(database: database),
      size: const Size(360, 740),
    );
    await tester.tap(find.text(other.name));
    await tester.pumpAndSettle();
    expect(find.text('0/0 nhánh hoàn thành'), findsOneWidget);
    expect(find.text(child.title), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text(_subject.name));
    await tester.pumpAndSettle();
    expect(find.text('0/2 nhánh hoàn thành'), findsOneWidget);
    await tester.tap(find.byTooltip('Thu gọn nhánh'));
    await tester.pumpAndSettle();
    expect(find.text(child.title), findsNothing);
    await tester.tap(find.byTooltip('Mở rộng nhánh'));
    await tester.pumpAndSettle();
    expect(find.text(child.title), findsOneWidget);

    await tester.tap(find.text(child.title));
    await tester.pumpAndSettle();
    expect(find.text(child.note), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), 'Bỏ thay đổi');
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(database.roadmapRows.last, child);

    await tester.tap(find.text(child.title));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      '  Giới hạn dãy số  ',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      '  Làm lại bài 3  ',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoàn thành').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      database.roadmapRows.last,
      child.copyWith(
        title: 'Giới hạn dãy số',
        note: 'Làm lại bài 3',
        status: 'done',
        isSynced: false,
      ),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text(_subject.name));
    await tester.pumpAndSettle();
    expect(find.text('1/2 nhánh hoàn thành'), findsOneWidget);
    expect(find.text('Giới hạn dãy số'), findsOneWidget);
    expect(find.textContaining('Làm lại bài 3'), findsOneWidget);

    final parentTile = find.ancestor(
      of: find.text(parent.title),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: parentTile,
        matching: find.byTooltip('Thao tác nhánh'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa nhánh'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sẽ được đưa lên gốc'), findsOneWidget);
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(find.text(parent.title), findsNothing);
    expect(find.text('Giới hạn dãy số'), findsOneWidget);
    expect(database.roadmapRows.single.parentId, isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    final subjectTile = find.ancestor(
      of: find.text(_subject.name),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: subjectTile,
        matching: find.byTooltip('Thao tác môn học'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi tên môn học'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Toán giải tích');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Toán giải tích'), findsOneWidget);
    expect(database.subjectRows.first.id, _subject.id);

    final renamedTile = find.ancestor(
      of: find.text('Toán giải tích'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: renamedTile,
        matching: find.byTooltip('Thao tác môn học'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa môn học'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mindmap'), findsOneWidget);
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(database.subjectRows, [other]);
    expect(database.roadmapRows, isEmpty);
  });
}
