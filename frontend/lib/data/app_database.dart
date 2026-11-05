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

class StudyEventDeletions extends Table {
  TextColumn get id => text()();
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

class MindmapDeletions extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SubjectDeletions extends Table {
  TextColumn get id => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class RoadmapDeletions extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Subjects,
    StudyEvents,
    RoadmapNodes,
    MindmapNodes,
    MindmapDeletions,
    StudyEventDeletions,
    SubjectDeletions,
    RoadmapDeletions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'study_planner',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await migrator.createTable(mindmapDeletions);
      if (from < 3) await migrator.createTable(studyEventDeletions);
      if (from < 4) {
        await migrator.createTable(subjectDeletions);
        await migrator.createTable(roadmapDeletions);
      }
    },
  );

  Stream<List<Subject>> watchSubjects() => (select(
    subjects,
  )..orderBy([(row) => OrderingTerm.asc(row.name)])).watch();
  Future<List<Subject>> getSubjects() => select(subjects).get();
  Stream<Subject?> watchSubject(String id) =>
      (select(subjects)..where((row) => row.id.equals(id))).watchSingleOrNull();
  Future<Subject?> getSubject(String id) =>
      (select(subjects)..where((row) => row.id.equals(id))).getSingleOrNull();
  Future<void> saveSubject(Subject row) =>
      into(subjects).insertOnConflictUpdate(
        SubjectsCompanion.insert(
          id: row.id,
          name: row.name,
          color: Value(row.color),
          isSynced: Value(row.isSynced),
        ),
      );

  Future<void> updateSubject(Subject row) async {
    if (!await update(subjects).replace(row)) {
      throw StateError('Subject no longer exists.');
    }
  }

  Future<List<SubjectDeletion>> getSubjectDeletions() =>
      select(subjectDeletions).get();

  Future<void> acknowledgeSubjectDeletion(String id) async {
    await (delete(subjectDeletions)..where((row) => row.id.equals(id))).go();
  }

  Future<void> deleteSubject(
    String id, {
    bool queue = true,
  }) => transaction(() async {
    if (queue) {
      await into(subjectDeletions)
          .insertOnConflictUpdate(SubjectDeletionsCompanion.insert(id: id));
    }
    await (delete(
      roadmapDeletions,
    )..where((row) => row.subjectId.equals(id))).go();
    await (delete(
      mindmapDeletions,
    )..where((row) => row.subjectId.equals(id))).go();
    await (delete(roadmapNodes)..where((row) => row.subjectId.equals(id))).go();
    await (delete(mindmapNodes)..where((row) => row.subjectId.equals(id))).go();
    await (delete(subjects)..where((row) => row.id.equals(id))).go();
  });

  Stream<List<StudyEvent>> watchEvents() => (select(
    studyEvents,
  )..orderBy([(row) => OrderingTerm.asc(row.startsAt)])).watch();
  Future<List<StudyEvent>> getEvents() => select(studyEvents).get();
  Future<StudyEvent?> getEvent(String id) => (select(
    studyEvents,
  )..where((row) => row.id.equals(id))).getSingleOrNull();

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

  Future<void> updateEvent(StudyEvent row) async {
    if (!await update(studyEvents).replace(row)) {
      throw StateError('Study event no longer exists.');
    }
  }

  Future<List<StudyEventDeletion>> getEventDeletions() =>
      select(studyEventDeletions).get();

  Future<bool> hasEventDeletion(String id) async =>
      await (select(
        studyEventDeletions,
      )..where((row) => row.id.equals(id))).getSingleOrNull() !=
      null;

  Future<void> acknowledgeEventDeletion(String id) async {
    await (delete(studyEventDeletions)..where((row) => row.id.equals(id))).go();
  }

  Future<void> deleteEvent(String id, {bool queue = true}) =>
      transaction(() async {
        if (queue) {
          await into(
            studyEventDeletions,
          ).insertOnConflictUpdate(StudyEventDeletionsCompanion.insert(id: id));
        }
        await (delete(studyEvents)..where((row) => row.id.equals(id))).go();
      });

  Stream<List<RoadmapNode>> watchRoadmap(String subjectId) =>
      (select(roadmapNodes)
            ..where((row) => row.subjectId.equals(subjectId))
            ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
          .watch();
  Future<List<RoadmapNode>> getRoadmap(String subjectId) => (select(
    roadmapNodes,
  )..where((row) => row.subjectId.equals(subjectId))).get();
  Future<RoadmapNode?> getRoadmapNode(String id) => (select(
    roadmapNodes,
  )..where((row) => row.id.equals(id))).getSingleOrNull();
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

  Future<void> saveRoadmapEdit(RoadmapNode row, {required bool create}) =>
      transaction(() async {
        if (await getSubject(row.subjectId) == null) {
          throw StateError('Subject no longer exists.');
        }
        final visited = {row.id};
        var parentId = row.parentId;
        while (parentId != null) {
          if (!visited.add(parentId)) {
            throw StateError('Roadmap connection would form a cycle.');
          }
          final parent = await getRoadmapNode(parentId);
          if (parent == null || parent.subjectId != row.subjectId) {
            throw StateError('Roadmap parent is unavailable.');
          }
          parentId = parent.parentId;
        }
        final pending = row.copyWith(isSynced: false);
        if (create) {
          await into(roadmapNodes).insert(pending);
        } else if (!await update(roadmapNodes).replace(pending)) {
          throw StateError('Roadmap node no longer exists.');
        }
      });

  Future<List<RoadmapDeletion>> getRoadmapDeletions() =>
      select(roadmapDeletions).get();

  Future<void> acknowledgeRoadmapDeletion(String id) async {
    await (delete(roadmapDeletions)..where((row) => row.id.equals(id))).go();
  }

  Future<void> deleteRoadmapNode(
    String subjectId,
    String id, {
    bool queue = true,
  }) => transaction(() async {
    if (queue && await getSubject(subjectId) != null) {
      await into(roadmapDeletions).insertOnConflictUpdate(
        RoadmapDeletionsCompanion.insert(id: id, subjectId: subjectId),
      );
    }
    await (update(roadmapNodes)..where(
          (row) => row.subjectId.equals(subjectId) & row.parentId.equals(id),
        ))
        .write(const RoadmapNodesCompanion(parentId: Value(null)));
    await (delete(roadmapNodes)
          ..where((row) => row.subjectId.equals(subjectId) & row.id.equals(id)))
        .go();
  });

  Stream<List<MindmapNode>> watchMindmap(String subjectId) => (select(
    mindmapNodes,
  )..where((row) => row.subjectId.equals(subjectId))).watch();
  Future<List<MindmapNode>> getMindmap(String subjectId) => (select(
    mindmapNodes,
  )..where((row) => row.subjectId.equals(subjectId))).get();
  Future<MindmapNode?> getMindmapNode(String id) => (select(
    mindmapNodes,
  )..where((row) => row.id.equals(id))).getSingleOrNull();

  Future<List<MindmapDeletion>> getMindmapDeletions() =>
      select(mindmapDeletions).get();

  Future<void> acknowledgeMindmapDeletion(String id) async {
    await (delete(mindmapDeletions)..where((row) => row.id.equals(id))).go();
  }

  Future<void> deleteMindmapNode(MindmapNode node, {bool queue = true}) =>
      transaction(() async {
        if (queue && await getSubject(node.subjectId) != null) {
          await into(mindmapDeletions).insertOnConflictUpdate(
            MindmapDeletionsCompanion.insert(
              id: node.id,
              subjectId: node.subjectId,
            ),
          );
        }
        await (update(mindmapNodes)..where(
              (row) =>
                  row.subjectId.equals(node.subjectId) &
                  row.parentId.equals(node.id),
            ))
            .write(const MindmapNodesCompanion(parentId: Value(null)));
        await (delete(
          mindmapNodes,
        )..where((row) => row.id.equals(node.id))).go();
      });

  Future<void> updateMindmapNode(
    String id,
    MindmapNodesCompanion changes,
  ) async {
    await (update(mindmapNodes)..where((row) => row.id.equals(id))).write(
      changes.copyWith(isSynced: const Value(false)),
    );
  }

  Future<void> saveMindmapNode(MindmapNode row) => transaction(() async {
    if (await getSubject(row.subjectId) == null) return;
    await into(mindmapNodes).insertOnConflictUpdate(
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
  });
}
