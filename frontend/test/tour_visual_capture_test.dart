import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/features/onboarding/presentation/navigation_tour_page.dart';

// Optional local visual QA; outputs belong outside the repository.
const captureDirectory = String.fromEnvironment('TOUR_CAPTURE_DIR');
const fontFile = String.fromEnvironment('TOUR_FONT_FILE');
const symbolFontFile = String.fromEnvironment('TOUR_SYMBOL_FONT_FILE');
void main() {
  testWidgets(
    'Capture all tour scenes for visual QA',
    (tester) async {
      final loader = FontLoader('Roboto');
      await tester.runAsync(() async {
        loader.addFont(
          Future.value(
            ByteData.sublistView(await File(fontFile).readAsBytes()),
          ),
        );
        await loader.load();
        final icons = FontLoader('MaterialIcons');
        icons.addFont(
          Future.value(
            ByteData.sublistView(
              await File(
                '${File(fontFile).parent.path}/materialicons-regular.otf',
              ).readAsBytes(),
            ),
          ),
        );
        await icons.load();
        if (symbolFontFile.isNotEmpty) {
          final symbols = FontLoader('Symbols');
          symbols.addFont(
            Future.value(
              ByteData.sublistView(await File(symbolFontFile).readAsBytes()),
            ),
          );
          await symbols.load();
        }
      });
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final boundaryKey = GlobalKey();
      for (final dark in [false, true]) {
        for (var scene = 0; scene < navigationTourScenes.length; scene++) {
          tester.view.physicalSize = const Size(390, 844);
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                  textTheme: (dark ? AppTheme.dark() : AppTheme.light())
                      .textTheme
                      .apply(
                        fontFamily: 'Roboto',
                        fontFamilyFallback: ['Symbols'],
                      ),
                ),
                home: NavigationTourPage(
                  key: ValueKey('$dark-$scene'),
                  initialScene: scene,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = Directory(captureDirectory);
            await directory.create(recursive: true);
            await File(
              '${directory.path}/${dark ? "dark" : "light"}-$scene.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    },
    skip: captureDirectory.isEmpty || fontFile.isEmpty,
  );
}
