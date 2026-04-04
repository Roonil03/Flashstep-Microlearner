import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'database_manager.dart';

final databaseManagerProvider = ChangeNotifierProvider<DatabaseManager>((ref) {
  throw UnimplementedError();
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return ref.watch(databaseManagerProvider).database;
});
