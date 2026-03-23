import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../storage/session_storage.dart';
import 'api_client.dart';
import '../../features/auth/data/auth_api.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/decks/data/deck_repository.dart';
import '../storage/database_provider.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final sessionStorageProvider =
    Provider<SessionStorage>((ref) => const SessionStorage());

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.read(apiClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    api: ref.read(authApiProvider),
    storage: ref.read(sessionStorageProvider),
  ),
);

// final deckRepositoryProvider = Provider<DeckRepository>((ref) {
//   return DeckRepository();
// });