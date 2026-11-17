import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Rebuildable reconciliation metadata. It is separate from the learning schema.
class SyncMetadataStore {
  static final _revisions = <String, int>{};
  static final _pending = <String, Future<void>>{};
  final Directory? directory;
  const SyncMetadataStore({this.directory});

  int revision(String userId) => _revisions[userId] ?? 0;

  Future<void> _serialized(
    String userId,
    Future<void> Function() action,
  ) async {
    final previous = _pending[userId] ?? Future<void>.value();
    final work = previous.catchError((Object _) {}).then((_) => action());
    _pending[userId] = work;
    try {
      await work;
    } finally {
      if (identical(_pending[userId], work)) _pending.remove(userId);
    }
  }

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
          value['version'] != 2 ||
          value['decks'] is! Map) {
        return {};
      }
      final entries = value['decks'] as Map;
      if (entries.keys.any((key) => key is! String) ||
          entries.values.any((value) => value is! String)) {
        return {};
      }
      return Map<String, String>.from(entries);
    } catch (_) {
      return {};
    }
  }

  Future<void> write(
    String userId,
    Map<String, String> decks, {
    int? expectedRevision,
  }) {
    final generation = expectedRevision ?? revision(userId);
    final snapshot = Map<String, String>.from(decks);
    return _serialized(userId, () async {
      if (revision(userId) != generation) return;
      final file = await _file(userId);
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(
        jsonEncode({'version': 2, 'user_id': userId, 'decks': snapshot}),
        flush: true,
      );
      if (revision(userId) != generation) {
        if (await temporary.exists()) await temporary.delete();
        return;
      }
      await temporary.rename(file.path);
    });
  }

  Future<void> delete(String userId) {
    _revisions[userId] = revision(userId) + 1;
    return _serialized(userId, () async {
      final file = await _file(userId);
      for (final target in [file, File('${file.path}.tmp')]) {
        if (await target.exists()) await target.delete();
      }
    });
  }
}
