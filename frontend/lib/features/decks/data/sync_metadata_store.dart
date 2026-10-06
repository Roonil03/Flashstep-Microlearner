import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Rebuildable reconciliation metadata. It is separate from the learning schema.
class SyncMetadataStore {
  final Directory? directory;
  const SyncMetadataStore({this.directory});

  Future<File> _file(String userId) async {
    final dir = directory ?? await getApplicationDocumentsDirectory();
    final account = base64Url.encode(utf8.encode(userId)).replaceAll('=', '');
    return File(p.join(dir.path, 'sync_manifest_v1_$account.json'));
  }

  Future<Map<String, String>> read(String userId) async {
    try {
      final file = await _file(userId);
      final value = jsonDecode(await file.readAsString());
      if (value is! Map ||
          value['user_id'] != userId ||
          value['version'] != 1 ||
          value['decks'] is! Map)
        return {};
      final entries = value['decks'] as Map;
      if (entries.keys.any((key) => key is! String) ||
          entries.values.any((value) => value is! String))
        return {};
      return Map<String, String>.from(entries);
    } catch (_) {
      return {};
    }
  }

  Future<void> write(String userId, Map<String, String> decks) async {
    final file = await _file(userId);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({'version': 1, 'user_id': userId, 'decks': decks}),
      flush: true,
    );
    await temporary.rename(file.path);
  }
}
