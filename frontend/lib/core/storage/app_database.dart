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
  int get schemaVersion => 2;

  Future<void> clearAllLocalData() async {
    await transaction(() async {
      await delete(reviewLogs).go();
      await delete(syncQueueItems).go();
      await delete(cards).go();
      await delete(decks).go();
      await delete(users).go();
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
