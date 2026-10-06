import 'dart:io';
import 'package:frontend/app/app_version.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/settings/presentation/settings_page.dart';
import 'package:frontend/core/network/providers.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'navigation_tour_storage_test.dart' show MemorySessionStorage;

void main() {
  test('Settings release version matches Flutter package version', () {
    final match = RegExp(
      r'^version: (.+)$',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(match!.group(1)!.trim(), '${AppVersion.name}+2');
  });
  testWidgets('Settings can replay the tour and return without a database', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(MemorySessionStorage()),
        ],
        child: MaterialApp(home: const SettingsPage()),
      ),
    );
    await tester.tap(find.text('Relearn app navigation'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 9: Create a new deck'), findsOneWidget);
    await tester.tap(find.text('Skip tour'));
    await tester.pumpAndSettle();
    expect(find.text('Relearn app navigation'), findsOneWidget);
  });
  testWidgets(
    'System settings stay scrollable on a small screen with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.dark(),
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!,
                ),
            home: const SettingsPage(),
          ),
        ),
      );
      await tester.tap(find.text('System Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Review all cards'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Review all cards').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Review preferences persist and bypass explains its effect', (
    tester,
  ) async {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final values = <String, String>{
      'daily_review_limit': '25',
      'bypass_srs': 'false',
    };
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      final args = call.arguments as Map;
      if (call.method == 'read') return values[args['key']];
      if (call.method == 'write') {
        values[args['key'] as String] = args['value'] as String;
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsPage())),
    );
    await tester.tap(find.text('System Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Daily review limit'));
    await tester.tap(find.text('Daily review limit'));
    await tester.pumpAndSettle();
    final picker = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    picker.scrollController!.jumpToItem(29);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(values['daily_review_limit'], '30');
    await tester.ensureVisible(find.text('Review all cards'));
    await tester.tap(find.text('Review all cards'));
    await tester.pumpAndSettle();
    expect(values['bypass_srs'], 'true');
    expect(
      find.text('Ignores daily limits and due dates. All cards are available.'),
      findsOneWidget,
    );
    expect(values['daily_review_limit'], '30');
    expect(tester.takeException(), isNull);
  });
}
