import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/decks/data/csv_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
  String? content;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (content == null) return null;
          final bytes = Uint8List.fromList(utf8.encode(content!));
          return [
            {
              'name': 'cards.csv',
              'path': null,
              'size': bytes.length,
              'bytes': bytes,
            },
          ];
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  const service = CsvImportService();
  test(
    'CSV cancellation and valid preview preserve existing capacity',
    () async {
      content = null;
      expect(
        await service.pickAndValidateCsv(
          existingCardCount: 2,
          maxCardsAllowed: 50,
        ),
        isNull,
      );
      content = 'Front,Back\nHello,Hola\nBye,Adios';
      final preview = await service.pickAndValidateCsv(
        existingCardCount: 2,
        maxCardsAllowed: 50,
      );
      expect(preview!.cards.length, 2);
      expect(preview.cards.first.front, 'Hello');
      expect(preview.existingCardCount, 2);
    },
  );
  test(
    'CSV invalid headers, missing answers, and full decks are rejected',
    () async {
      for (final csv in ['Question,Answer\nHello,Hola', 'Front,Back\nHello,']) {
        content = csv;
        await expectLater(
          service.pickAndValidateCsv(existingCardCount: 2, maxCardsAllowed: 50),
          throwsA(isA<CsvImportException>()),
        );
      }
      content = 'Front,Back\nHello,Hola\nBye,Adios';
      await expectLater(
        service.pickAndValidateCsv(existingCardCount: 49, maxCardsAllowed: 50),
        throwsA(isA<CsvImportException>()),
      );
      await expectLater(
        service.pickAndValidateCsv(existingCardCount: 50, maxCardsAllowed: 50),
        throwsA(isA<CsvImportException>()),
      );
    },
  );
}
