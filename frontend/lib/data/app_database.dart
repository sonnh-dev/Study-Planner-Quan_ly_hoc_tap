import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Subjects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get color => text().withDefault(const Constant('#5685F7'))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StudyEvents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 160)();
  TextColumn get details => text().withDefault(const Constant(''))();
  IntColumn get startsAt => integer()();
  IntColumn get endsAt => integer()();
  IntColumn get reminderAt => integer().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class RoadmapNodes extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get title => text().withLength(min: 1, max: 160)();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('planned'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get dueAt => integer().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MindmapNodes extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get title => text().withLength(min: 1, max: 160)();
  TextColumn get content => text().withDefault(const Constant(''))();
  RealColumn get x => real().withDefault(const Constant(100))();
  RealColumn get y => real().withDefault(const Constant(100))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Subjects, StudyEvents, RoadmapNodes, MindmapNodes])
class AppDatabase extends _$AppDatabase {
  AppDatabase()
    : super(
        driftDatabase(
          name: 'study_planner',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );
  @override
  int get schemaVersion => 1;

  Stream<List<Subject>> watchSubjects() => (select(
    subjects,
  )..orderBy([(row) => OrderingTerm.asc(row.name)])).watch();
  Future<List<Subject>> getSubjects() => select(subjects).get();
  Future<void> saveSubject(Subject row) =>
      into(subjects).insertOnConflictUpdate(
        SubjectsCompanion.insert(
          id: row.id,
          name: row.name,
          color: Value(row.color),
          isSynced: Value(row.isSynced),
        ),
      );

  Stream<List<StudyEvent>> watchEvents() => (select(
    studyEvents,
  )..orderBy([(row) => OrderingTerm.asc(row.startsAt)])).watch();
  Future<List<StudyEvent>> getEvents() => select(studyEvents).get();
  Future<void> saveEvent(StudyEvent row) =>
      into(studyEvents).insertOnConflictUpdate(
        StudyEventsCompanion.insert(
          id: row.id,
          title: row.title,
          details: Value(row.details),
          startsAt: row.startsAt,
          endsAt: row.endsAt,
          reminderAt: Value(row.reminderAt),
          isSynced: Value(row.isSynced),
        ),
      );

  Stream<List<RoadmapNode>> watchRoadmap(String subjectId) =>
      (select(roadmapNodes)
            ..where((row) => row.subjectId.equals(subjectId))
            ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
          .watch();
  Future<List<RoadmapNode>> getRoadmap(String subjectId) => (select(
    roadmapNodes,
  )..where((row) => row.subjectId.equals(subjectId))).get();
  Future<void> saveRoadmapNode(RoadmapNode row) =>
      into(roadmapNodes).insertOnConflictUpdate(
        RoadmapNodesCompanion.insert(
          id: row.id,
          subjectId: row.subjectId,
          parentId: Value(row.parentId),
          title: row.title,
          note: Value(row.note),
          status: Value(row.status),
          sortOrder: Value(row.sortOrder),
          dueAt: Value(row.dueAt),
          isSynced: Value(row.isSynced),
        ),
      );

  Stream<List<MindmapNode>> watchMindmap(String subjectId) => (select(
    mindmapNodes,
  )..where((row) => row.subjectId.equals(subjectId))).watch();
  Future<List<MindmapNode>> getMindmap(String subjectId) => (select(
    mindmapNodes,
  )..where((row) => row.subjectId.equals(subjectId))).get();
  Future<void> saveMindmapNode(MindmapNode row) =>
      into(mindmapNodes).insertOnConflictUpdate(
        MindmapNodesCompanion.insert(
          id: row.id,
          subjectId: row.subjectId,
          parentId: Value(row.parentId),
          title: row.title,
          content: Value(row.content),
          x: Value(row.x),
          y: Value(row.y),
          isSynced: Value(row.isSynced),
        ),
      );
}
