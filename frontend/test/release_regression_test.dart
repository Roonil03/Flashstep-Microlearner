import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/providers.dart';
import 'package:frontend/core/storage/database_manager.dart';
import 'package:frontend/core/storage/app_database.dart' as db;
import 'package:frontend/features/auth/data/auth_api.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/decks/data/deck_repository.dart';
import 'package:frontend/features/decks/data/data_sync_service.dart';
import 'package:frontend/features/decks/presentation/create_deck_page.dart';
import 'package:frontend/features/decks/presentation/deck_detail_page.dart';
import 'package:frontend/features/decks/presentation/browse_public_decks_page.dart';
import 'package:frontend/features/onboarding/data/navigation_tour_storage.dart';
import 'package:frontend/features/home/presentation/home_dashboard_page.dart';
import 'package:frontend/features/home/domain/home_dashboard_models.dart';
import 'navigation_tour_storage_test.dart' show MemorySessionStorage;

class FakeDeckRepository extends Fake implements DeckRepository {
  int creates = 0;
  int cardsCreated = 0;
  int downloads = 0;
  bool fail = false;
  String? front;
  String? back;
  @override
  Future<String> createDeckOffline({
    required String title,
    String? description,
    bool isPublic = false,
  }) async {
    creates++;
    if (fail) throw StateError('Save failed');
    return 'new-deck';
  }

  @override
  Future<String> createCardOffline({
    required String deckId,
    required String front,
    required String back,
  }) async {
    cardsCreated++;
    this.front = front;
    this.back = back;
    if (fail) throw StateError('Save failed');
    return 'new-card';
  }

  final deck = db.Deck(
    id: 'new-deck',
    userId: 'new-user',
    title: 'Test deck',
    isPublic: false,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    version: 1,
    isDeleted: false,
  );
  late final deckStream = Stream<db.Deck?>.value(deck).asBroadcastStream();
  late final cardStream = Stream<List<db.Card>>.value([]).asBroadcastStream();
  @override
  Stream<db.Deck?> watchDeckById(String deckId) => deckStream;
  @override
  Stream<List<db.Card>> watchCardsByDeck(String deckId) => cardStream;
  @override
  Future<List<PublicDeckSummary>> fetchPublicDecks([String? query]) async => [
    PublicDeckSummary(
      id: 'source',
      userId: 'owner',
      title: 'Shared deck',
      description: 'A public example',
      ownerUsername: 'Teacher',
      cardCount: 2,
      updatedAt: DateTime.utc(2026),
      version: 1,
    ),
  ];
  @override
  Future<String> downloadPublicDeck(String sourceDeckId) async {
    downloads++;
    return 'my-copy';
  }
}

class FakeSync extends Fake implements DeckSyncService {
  @override
  Future<SyncResult> syncNow() async => const SyncResult.success('Synced');
}

Widget deckApp(
  FakeDeckRepository repo,
  Widget home, {
  Map<String, WidgetBuilder>? routes,
}) => ProviderScope(
  overrides: [
    deckRepositoryProvider.overrideWithValue(repo),
    deckSyncServiceProvider.overrideWithValue(FakeSync()),
  ],
  child: MaterialApp(home: home, routes: routes ?? {}),
);

void main() {
  test(
    'Registration enrolls the returned account ID without saving a login token',
    () async {
      final storage = MemorySessionStorage();
      final repo = AuthRepository(
        api: AuthApi(ApiClient(baseUrl: 'https://example.invalid/api/v1')),
        storage: storage,
        databaseManager: DatabaseManager(storage: storage),
      );
      await http.runWithClient(
        () => repo.register(
          email: 'new@example.invalid',
          username: 'Learner',
          password: 'password123',
        ),
        () => MockClient((request) async {
          expect(jsonDecode(request.body)['username'], 'Learner');
          return http.Response(
            jsonEncode({
              'user': {
                'id': 'registered-account',
                'email': 'new@example.invalid',
                'username': 'Learner',
              },
              'token': 'unused-signup-token',
            }),
            201,
          );
        }),
      );
      expect(
        await NavigationTourStorage(storage).pendingScene('registered-account'),
        0,
      );
      expect(
        await NavigationTourStorage(storage).pendingScene(storage.userId),
        isNull,
      );
      storage.fail = true;
      await http.runWithClient(
        () => repo.register(
          email: 'new@example.invalid',
          username: 'Learner',
          password: 'password123',
        ),
        () => MockClient(
          (_) async => http.Response('{"user":{"id":"another-account"}}', 201),
        ),
      );
      await http.runWithClient(
        () => repo.register(
          email: 'new@example.invalid',
          username: 'Learner',
          password: 'password123',
        ),
        () => MockClient(
          (_) async => http.Response('Unexpected successful body', 201),
        ),
      );
      await expectLater(
        http.runWithClient(
          () => repo.register(
            email: 'new@example.invalid',
            username: 'Learner',
            password: 'password123',
          ),
          () => MockClient(
            (_) async => http.Response('{"error":"Already registered"}', 409),
          ),
        ),
        throwsA(isA<AuthApiException>()),
      );
    },
  );
  testWidgets(
    'Deck title validation prevents submission and failure keeps input',
    (tester) async {
      final repo = FakeDeckRepository()..fail = true;
      await tester.pumpWidget(deckApp(repo, const CreateDeckPage()));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create deck'));
      await tester.pump();
      expect(repo.creates, 0);
      expect(find.text('Enter a deck title'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'My deck');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create deck'));
      await tester.pumpAndSettle();
      expect(repo.creates, 1);
      expect(find.text('My deck'), findsOneWidget);
      expect(find.textContaining('Failed to create deck'), findsOneWidget);
    },
  );
  testWidgets('Card form validates and keeps answers after a failed save', (
    tester,
  ) async {
    final repo = FakeDeckRepository()..fail = true;
    await tester.pumpWidget(
      deckApp(repo, const DeckDetailPage(deckId: 'new-deck')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save card'));
    await tester.tap(find.text('Save card'));
    await tester.pump();
    expect(repo.cardsCreated, 0);
    await tester.enterText(find.byType(TextFormField).first, 'Question');
    await tester.enterText(find.byType(TextFormField).last, 'Answer');
    await tester.ensureVisible(find.text('Save card'));
    await tester.tap(find.text('Save card'));
    await tester.pumpAndSettle();
    expect(repo.cardsCreated, 1);
    expect(repo.front, 'Question');
    expect(repo.back, 'Answer');
    expect(find.text('Question'), findsOneWidget);
    expect(find.text('Answer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Public copy is explicit and needs confirmation', (tester) async {
    final repo = FakeDeckRepository();
    await tester.pumpWidget(deckApp(repo, const BrowsePublicDecksPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add to my decks'));
    await tester.pumpAndSettle();
    expect(repo.downloads, 0);
    expect(
      find.textContaining('without changing the original'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.downloads, 0);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add to my decks'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add to my decks'));
    await tester.pumpAndSettle();
    expect(repo.downloads, 1);
    expect(find.textContaining('was added to your decks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Dashboard actions stay accessible on a small display without tour listeners',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = MemorySessionStorage();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStorageProvider.overrideWithValue(storage),
            homeDashboardProvider.overrideWith(
              (ref) async => const HomeDashboardData(
                displayName: 'Learner',
                decksCount: 0,
                dueToday: 0,
                reviewedToday: 0,
                streak: 0,
                retentionRate: 0,
                isOffline: true,
                isSyncing: false,
                lastSyncedAt: null,
                deckOfTheDay: null,
                decks: [],
              ),
            ),
          ],
          child: MaterialApp(
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!,
                ),
            home: const HomeDashboardPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, 'Browse decks'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.widgetWithText(OutlinedButton, 'Browse decks')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(OutlinedButton, 'Browse decks').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('App navigation guide'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
