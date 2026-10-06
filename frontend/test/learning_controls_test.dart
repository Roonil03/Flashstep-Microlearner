import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/learning_controls.dart';
import 'package:frontend/features/auth/presentation/register_page.dart';
import 'package:frontend/app/theme/app_theme.dart';

void main() {
  testWidgets(
    'Navigation action is focusable and has a generous touch target',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningAction(
              icon: Icons.add,
              label: 'Create deck',
              onPressed: () => calls++,
            ),
          ),
        ),
      );
      final button = find.byType(OutlinedButton);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      expect(calls, 1);
      expect(find.byType(InkWell), findsWidgets);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'Registration follows app theme and validates without submitting ($dark)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              home: const RegisterPage(),
            ),
          ),
        );
        expect(
          Theme.of(tester.element(find.byType(Form))).brightness,
          dark ? Brightness.dark : Brightness.light,
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
        await tester.pump();
        expect(find.text('Enter email'), findsOneWidget);
        expect(find.text('Enter username'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Analytics range supports selection without changing the available ranges',
    (tester) async {
      var selected = 30;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder:
                  (context, setState) => AnalyticsRangeControl(
                    currentValue: selected,
                    onChanged: (value) => setState(() => selected = value),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('7 days'));
      await tester.pump();
      expect(selected, 7);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '7 days'))
            .selected,
        isTrue,
      );
      expect(find.text('90 days'), findsOneWidget);
    },
  );
}
