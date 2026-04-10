import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/csv_import_models.dart';

final csvImportServiceProvider = Provider<CsvImportService>((ref) {
  return const CsvImportService();
});

class CsvImportException implements Exception {
  final String message;

  const CsvImportException(this.message);

  @override
  String toString() => message;
}

class CsvImportService {
  const CsvImportService();

  Future<CsvImportPreview?> pickAndValidateCsv({
    required int existingCardCount,
    required int maxCardsAllowed,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      allowMultiple: false,
      withData: true,
      dialogTitle: 'Select a flashcards CSV',
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final fileName = file.name.trim();

    if (!_looksLikeCsv(file)) {
      throw const CsvImportException(
        'Please select a valid .csv file.',
      );
    }

    final bytes = await _readBytes(file);
    if (bytes.isEmpty) {
      throw const CsvImportException('The selected CSV file is empty.');
    }

    final rawText = utf8.decode(bytes, allowMalformed: true);
    final content = rawText.replaceFirst('\uFEFF', '').trim();

    if (content.isEmpty) {
      throw const CsvImportException('The selected CSV file is empty.');
    }

    final rows = _decodeCsv(content);
    if (rows.isEmpty) {
      throw const CsvImportException('The CSV file does not contain any rows.');
    }

    final header = rows.first;
    if (header.length != 2) {
      throw const CsvImportException(
        'The CSV header must contain exactly 2 columns: Front and Back.',
      );
    }

    final firstHeader = _normalizedCell(header[0]).toLowerCase();
    final secondHeader = _normalizedCell(header[1]).toLowerCase();

    if (firstHeader != 'front' || secondHeader != 'back') {
      throw const CsvImportException(
        'The first row must be exactly: Front,Back',
      );
    }

    final cards = <CsvCardDraft>[];

    for (var index = 1; index < rows.length; index++) {
      final row = rows[index];
      final csvRowNumber = index + 1;

      if (_isBlankRow(row)) {
        continue;
      }

      if (row.length != 2) {
        throw CsvImportException(
          'Row $csvRowNumber must contain exactly 2 columns.',
        );
      }

      final front = _normalizedCell(row[0]);
      final back = _normalizedCell(row[1]);

      if (front.isEmpty || back.isEmpty) {
        throw CsvImportException(
          'Row $csvRowNumber must have both Front and Back filled.',
        );
      }

      cards.add(
        CsvCardDraft(
          front: front,
          back: back,
          sourceRow: csvRowNumber,
        ),
      );
    }

    if (cards.isEmpty) {
      throw const CsvImportException(
        'No valid card rows were found in the CSV.',
      );
    }

    if (cards.length > 50) {
      throw const CsvImportException(
        'A CSV import can contain at most 50 card rows, excluding the header.',
      );
    }

    final remainingCapacity = maxCardsAllowed - existingCardCount;
    if (remainingCapacity <= 0) {
      throw const CsvImportException(
        'This deck is already full and cannot accept more cards.',
      );
    }

    if (cards.length > remainingCapacity) {
      throw CsvImportException(
        'This deck only has room for $remainingCapacity more card'
        '${remainingCapacity == 1 ? '' : 's'}.',
      );
    }

    return CsvImportPreview(
      fileName: fileName,
      cards: cards,
      existingCardCount: existingCardCount,
      maxCardsAllowed: maxCardsAllowed,
    );
  }

  bool _looksLikeCsv(PlatformFile file) {
    final extension = (file.extension ?? '').trim().toLowerCase();
    final name = file.name.toLowerCase();
    return extension == 'csv' || name.endsWith('.csv');
  }

  Future<Uint8List> _readBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes!;
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      throw const CsvImportException(
        'Could not read the selected file.',
      );
    }

    return File(path).readAsBytes();
  }

  List<List<dynamic>> _decodeCsv(String content) {
    try {
      return csv.decode(content);
    } catch (_) {
      throw const CsvImportException(
        'The file could not be parsed as CSV. Make sure it is a real CSV with Front and Back columns.',
      );
    }
  }

  bool _isBlankRow(List<dynamic> row) {
    if (row.isEmpty) return true;
    return row.every((cell) => _normalizedCell(cell).isEmpty);
  }

  String _normalizedCell(dynamic value) {
    return value?.toString().trim() ?? '';
  }
}