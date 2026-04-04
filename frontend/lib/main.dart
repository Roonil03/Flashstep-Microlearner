import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/network/providers.dart';
import 'core/storage/database_manager.dart';
import 'core/storage/database_provider.dart';
import 'core/storage/session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const storage = SessionStorage();
  final databaseManager = DatabaseManager(storage: storage);
  await databaseManager.initialize();

  runApp(
    ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        databaseManagerProvider.overrideWith((ref) => databaseManager),
      ],
      child: const App(),
    ),
  );
}