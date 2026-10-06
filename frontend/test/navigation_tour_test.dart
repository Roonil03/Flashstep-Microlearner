import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/onboarding/presentation/navigation_tour_page.dart';
import 'package:frontend/app/theme/app_theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'All nine steps and public substeps are safe in ${dark ? "dark" : "light"} mode',
      (tester) async {
        final scenes = <int>[];
        var dismissed = 0;
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => NavigationTourPage(
                                    onProgress: (scene) async {
                                      scenes.add(scene);
                                    },
                                    onDismiss: () async {
                                      dismissed++;
                                    },
                                  ),
                            ),
                          ),
                      child: const Text('Open guide'),
                    ),
                  ),
            ),
          ),
        );
        await tester.tap(find.text('Open guide'));
        await tester.pumpAndSettle();
        for (var index = 0; index < navigationTourScenes.length; index++) {
          final scene = navigationTourScenes[index];
          expect(
            find.text('Step ${scene.step} of 9: ${scene.title}'),
            findsOneWidget,
          );
          expect(
            find.byType(TourArrowPainter),
            findsNothing,
          ); // painter is mounted on CustomPaint, not a widget.
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is CustomPaint && widget.painter is TourArrowPainter,
            ),
            findsOneWidget,
          );
          expect(
            find.text('Safe preview • Examples are never saved'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(
            find.widgetWithText(
              FilledButton,
              index == navigationTourScenes.length - 1 ? 'Finish' : 'Next',
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(
          scenes,
          List.generate(navigationTourScenes.length - 1, (index) => index + 1),
        );
        expect(dismissed, 1);
        expect(find.text('Open guide'), findsOneWidget);
        semantics.dispose();
      },
    );
  }
  testWidgets(
    'Small landscape and enlarged text can scroll; keyboard and exit work',
    (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var dismissed = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: child!,
              ),
          home: NavigationTourPage(
            initialScene: 8,
            onProgress: (_) async {
              throw StateError('Storage unavailable');
            },
            onDismiss: () async {
              dismissed++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('Step 7 of 9: Review your decks'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(dismissed, 1);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Guide has no repository, network, file-picker, or review dependencies',
    () {
      final source =
          File(
            'lib/features/onboarding/presentation/navigation_tour_page.dart',
          ).readAsStringSync();
      for (final prohibited in [
        'deck_repository.dart',
        'data_sync_service.dart',
        'file_picker',
        'review_repository.dart',
        'package:http',
        'network/providers.dart',
      ]) {
        expect(source.contains(prohibited), isFalse, reason: prohibited);
      }
    },
  );
}
