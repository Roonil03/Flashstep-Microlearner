import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/storage/session_storage.dart';
import 'package:frontend/features/onboarding/data/navigation_tour_storage.dart';
import 'package:frontend/features/onboarding/presentation/navigation_tour_launcher.dart';

class MemorySessionStorage extends SessionStorage {
  final states = <String, String>{};
  String userId = 'new-user';
  bool fail = false;
  @override
  Future<String?> readUserId() async => userId;
  @override
  Future<String?> readNavigationTour(String id) async {
    if (fail) throw StateError('Read failed');
    return states[id];
  }

  @override
  Future<void> writeNavigationTour(String id, String value) async {
    if (fail) throw StateError('Write failed');
    states[id] = value;
  }

  @override
  Future<void> clearNavigationTour(String id) async {
    states.remove(id);
  }
}

void main() {
  test(
    'Only enrolled accounts start; interrupted progress resumes; dismissal suppresses',
    () async {
      final storage = MemorySessionStorage();
      final tour = NavigationTourStorage(storage);
      expect(await tour.pendingScene('existing-user'), isNull);
      await tour.markEligible('new-user');
      expect(await tour.pendingScene('new-user'), 0);
      expect(await tour.pendingScene('existing-user'), isNull);
      await tour.saveProgress('new-user', 5);
      expect(await NavigationTourStorage(storage).pendingScene('new-user'), 5);
      await tour.dismiss('new-user');
      expect(await tour.pendingScene('new-user'), isNull);
      await tour.saveProgress('new-user', 0);
      expect(await tour.pendingScene('new-user'), 0);
      await tour.clear('new-user');
      expect(await tour.pendingScene('new-user'), isNull);
    },
  );
  test(
    'Storage errors and malformed progress never block normal use',
    () async {
      final storage = MemorySessionStorage();
      final tour = NavigationTourStorage(storage);
      for (final state in [
        'bad json',
        '{}',
        '{"scene":99,"dismissed":false}',
        '{"scene":-1,"dismissed":false}',
      ]) {
        storage.states['new-user'] = state;
        expect(await tour.pendingScene('new-user'), isNull);
      }
      storage.fail = true;
      await tour.markEligible('new-user');
      await tour.saveProgress('new-user', 4);
      await tour.dismiss('new-user');
      expect(await tour.pendingScene('new-user'), isNull);
    },
  );
  testWidgets(
    'Automatic eligibility, resume, exit, duplicate launch and replay return to caller',
    (tester) async {
      final storage = MemorySessionStorage();
      final tour = NavigationTourStorage(storage);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Column(
                    children: [
                      TextButton(
                        onPressed: () {
                          launchNavigationTour(context, storage);
                          launchNavigationTour(context, storage);
                        },
                        child: const Text('Automatic'),
                      ),
                      TextButton(
                        onPressed:
                            () => launchNavigationTour(
                              context,
                              storage,
                              replay: true,
                            ),
                        child: const Text('Relearn app navigation'),
                      ),
                    ],
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Automatic'));
      await tester.pumpAndSettle();
      expect(find.text('App navigation guide'), findsNothing);
      await tour.markEligible(storage.userId);
      await tour.saveProgress(storage.userId, 6);
      await tester.tap(find.text('Automatic'));
      await tester.pumpAndSettle();
      expect(find.text('App navigation guide'), findsOneWidget);
      expect(
        find.text('Step 6 of 9: Customize your personal copy'),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(await tour.pendingScene(storage.userId), isNull);
      await tester.tap(find.text('Automatic'));
      await tester.pumpAndSettle();
      expect(find.text('App navigation guide'), findsNothing);
      await tester.tap(find.text('Relearn app navigation'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 9: Create a new deck'), findsOneWidget);
      await tester.tap(find.text('Skip tour'));
      await tester.pumpAndSettle();
      expect(find.text('Relearn app navigation'), findsOneWidget);
      expect(await tour.pendingScene(storage.userId), isNull);
    },
  );
}
