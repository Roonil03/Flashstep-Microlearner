import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';


class ReviewLogs extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get cardId => text()();

  TextColumn get rating => text()();
  RealColumn get previousInterval => real()();
  RealColumn get newInterval => real()();

  DateTimeColumn get reviewedAt => dateTime()();
  TextColumn get deviceId => text()();

  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueueItems extends Table {
  TextColumn get operationId => text()();
  TextColumn get type => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {operationId};
}

@DriftDatabase(tables: [ReviewLogs, SyncQueueItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<void> insertReviewLog(ReviewLogsCompanion entry) =>
      into(reviewLogs).insert(entry);

  Future<List<ReviewLog>> getAllReviewLogs() =>
      select(reviewLogs).get();

  Future<void> insertSyncItem(SyncQueueItemsCompanion entry) =>
      into(syncQueueItems).insert(entry);

  Future<List<SyncQueueItem>> getPendingSyncItems() =>
      (select(syncQueueItems)..where((tbl) => tbl.synced.equals(false))).get();

  Future<void> markSynced(String id) {
    return (update(syncQueueItems)
          ..where((tbl) => tbl.operationId.equals(id)))
        .write(const SyncQueueItemsCompanion(synced: Value(true)));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.sqlite'));
    return NativeDatabase(file);
  });
}