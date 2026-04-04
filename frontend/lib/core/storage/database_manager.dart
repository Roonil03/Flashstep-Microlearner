import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';
import 'session_storage.dart';

class DatabaseManager extends ChangeNotifier {
  DatabaseManager({required SessionStorage storage}) : _storage = storage;

  final SessionStorage _storage;
  AppDatabase? _database;

  AppDatabase get database {
    final db = _database;
    if (db == null) {
      throw StateError('DatabaseManager has not been initialized.');
    }
    return db;
  }

  Future<void> initialize() async {
    if (_database != null) return;
    final currentUserId = await _storage.readUserId();
    _database = AppDatabase.forUser(userId: currentUserId);
  }

  Future<void> switchToUser(String? userId) async {
    final nextFileName = AppDatabase.fileNameForUser(userId);
    if (_database?.databaseFileName == nextFileName) {
      return;
    }

    final previous = _database;
    _database = AppDatabase.forUser(userId: userId);
    notifyListeners();
    if (previous != null) {
      await previous.close();
    }
  }

  Future<void> switchToAnonymous() => switchToUser(null);

  Future<void> deleteDatabaseForUser(String userId) async {
    final targetFileName = AppDatabase.fileNameForUser(userId);

    if (_database?.databaseFileName == targetFileName) {
      final previous = _database;
      _database = AppDatabase.forUser(userId: null);
      notifyListeners();
      if (previous != null) {
        await previous.close();
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, targetFileName));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
