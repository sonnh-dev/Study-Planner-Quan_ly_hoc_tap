import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyplaner/data/app_database.dart';
import 'package:studyplaner/data/notification_service.dart';
import 'package:studyplaner/screens/mindmap_screen.dart';
import 'package:studyplaner/screens/roadmap_screen.dart';
import 'package:studyplaner/screens/schedule_screen.dart';

const _subject = Subject(
  id: 'subject-1',
  name: 'Toán',
  color: '#5685F7',
  isSynced: false,
);

class _DialogDatabase implements AppDatabase {
  final List<Subject> subjectRows = [];
  final List<RoadmapNode> roadmapRows = [];
  final List<MindmapNode> mindmapRows = [];
  final List<StudyEvent> eventRows = [];

  @override
  Stream<List<Subject>> watchSubjects() =>
      Stream.value(List.unmodifiable(subjectRows));

  @override
  Stream<List<RoadmapNode>> watchRoadmap(String subjectId) => Stream.value(
    roadmapRows.where((row) => row.subjectId == subjectId).toList(),
  );

  @override
  Stream<List<MindmapNode>> watchMindmap(String subjectId) => Stream.value(
    mindmapRows.where((row) => row.subjectId == subjectId).toList(),
  );

  @override
  Stream<List<StudyEvent>> watchEvents() =>
      Stream.value(List.unmodifiable(eventRows));

  @override
  Future<void> saveSubject(Subject row) async => subjectRows.add(row);

  @override
  Future<void> saveRoadmapNode(RoadmapNode row) async => roadmapRows.add(row);

  @override
  Future<void> saveEvent(StudyEvent row) async => eventRows.add(row);

  @override
  Future<void> saveMindmapNode(MindmapNode row) async {
    mindmapRows.removeWhere((existing) => existing.id == row.id);
    mindmapRows.add(row);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DialogNotifications implements NotificationService {
  final List<String> scheduledTitles = [];

  @override
  Future<void> schedule(int id, String title, DateTime when) async {
    scheduledTitles.add(title);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _openScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: screen)));
  await tester.pumpAndSettle();
}

void main() {
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
}
