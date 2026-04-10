class CsvCardDraft {
  final String front;
  final String back;
  final int sourceRow;

  const CsvCardDraft({
    required this.front,
    required this.back,
    required this.sourceRow,
  });
}

class CsvImportPreview {
  final String fileName;
  final List<CsvCardDraft> cards;
  final int existingCardCount;
  final int maxCardsAllowed;

  const CsvImportPreview({
    required this.fileName,
    required this.cards,
    required this.existingCardCount,
    required this.maxCardsAllowed,
  });

  int get importedCount => cards.length;

  int get remainingSlotsAfterImport =>
      maxCardsAllowed - existingCardCount - importedCount;
}

class CsvImportSuccessResult {
  final int importedCount;
  final bool syncedNow;
  final String message;

  const CsvImportSuccessResult({
    required this.importedCount,
    required this.syncedNow,
    required this.message,
  });
}