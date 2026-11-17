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
  TextColumn get entity => text()();
  TextColumn get payload => text()();

  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {operationId};
}

class Users extends Table {
  TextColumn get userId => text()();
  TextColumn get username => text()();
  TextColumn get email => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {userId};
}

class Decks extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isPublic => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Cards extends Table {
  TextColumn get id => text()();
  TextColumn get deckId => text()();
  TextColumn get front => text()();
  TextColumn get back => text()();

  TextColumn get state => text().withDefault(const Constant('new'))();
  RealColumn get interval => real().withDefault(const Constant(0))();
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get repetitionCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get dueTimestamp => dateTime().nullable()();
  DateTimeColumn get lastReviewedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ReviewLogs, SyncQueueItems, Users, Decks, Cards])
class AppDatabase extends _$AppDatabase {
  // A visible Undo action can outlive the normal timeout for accessibility.
  // Keep its changes local until the action is used or dismissed.
  final Set<String> heldDeckDeletions = {};
  final Set<String> heldCardDeletions = {};

  AppDatabase.forTesting(super.executor) : databaseFileName = ':memory:';

  AppDatabase._({required this.databaseFileName})
    : super(_openConnection(databaseFileName));

  factory AppDatabase.forUser({String? userId}) {
    final fileName = fileNameForUser(userId);
    return AppDatabase._(databaseFileName: fileName);
  }

  final String databaseFileName;

  static String fileNameForUser(String? userId) {
    final trimmed = userId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'app_guest_v2.sqlite';
    }

    final safeUserId = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'app_user_${safeUserId}_v2.sqlite';
  }

  @override
  int get schemaVersion => 3;

  // Checkpoints live in the SQLite file they describe. Recreating or clearing
  // that file cannot leave a cursor that skips deletions on a fresh database.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createReceiptTables();
    },
    onUpgrade: (m, from, to) async {
      if (from < 3) await _createReceiptTables();
    },
  );

  Future<void> _createReceiptTables() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS local_purged_entities (user_id TEXT NOT NULL, entity TEXT NOT NULL, entity_id TEXT NOT NULL, PRIMARY KEY(user_id,entity,entity_id))',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS sync_receipt_checkpoints (user_id TEXT PRIMARY KEY, cursor TEXT NOT NULL)',
    );
  }

  Future<String> receiptCursor(String userId) async {
    final rows =
        await customSelect(
          'SELECT cursor FROM sync_receipt_checkpoints WHERE user_id=?',
          variables: [Variable(userId)],
        ).get();
    return rows.isEmpty ? '0' : rows.single.read<String>('cursor');
  }

  Future<void> saveReceiptCursor(String userId, String cursor) async {
    await customStatement(
      'INSERT INTO sync_receipt_checkpoints(user_id,cursor) VALUES(?,?) ON CONFLICT(user_id) DO UPDATE SET cursor=excluded.cursor WHERE CAST(excluded.cursor AS INTEGER)>CAST(cursor AS INTEGER)',
      [userId, cursor],
    );
  }

  Future<void> rememberPurged(
    String userId,
    String entity,
    Iterable<String> ids,
  ) async {
    for (final id in ids) {
      await customStatement(
        'INSERT OR IGNORE INTO local_purged_entities(user_id,entity,entity_id) VALUES(?,?,?)',
        [userId, entity, id],
      );
    }
  }

  Future<Set<String>> purgedIds(
    String userId,
    String entity,
    Iterable<String> ids,
  ) async {
    final values = ids.toSet().toList();
    final result = <String>{};
    for (var offset = 0; offset < values.length; offset += 400) {
      final chunk = values.skip(offset).take(400).toList();
      final rows =
          await customSelect(
            'SELECT entity_id FROM local_purged_entities WHERE user_id=? AND entity=? AND entity_id IN (${List.filled(chunk.length, '?').join(',')})',
            variables: [
              Variable(userId),
              Variable(entity),
              ...chunk.map(Variable.new),
            ],
          ).get();
      result.addAll(rows.map((r) => r.read<String>('entity_id')));
    }
    return result;
  }

  Future<void> clearAllLocalData() async {
    await transaction(() async {
      await delete(reviewLogs).go();
      await delete(syncQueueItems).go();
      await delete(cards).go();
      await delete(decks).go();
      await delete(users).go();
      await customStatement('DELETE FROM local_purged_entities');
      await customStatement('DELETE FROM sync_receipt_checkpoints');
    });
  }
}

LazyDatabase _openConnection(String databaseFileName) {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, databaseFileName));
    return NativeDatabase(file);
  });
}
