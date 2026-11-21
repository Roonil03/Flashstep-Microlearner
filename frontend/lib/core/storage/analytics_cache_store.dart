import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AnalyticsCacheEntry {
  final DateTime cachedAt;
  final Map<String, dynamic> data;

  const AnalyticsCacheEntry({required this.cachedAt, required this.data});
}

/// Stores server analytics snapshots outside the database so cache data can be
/// replaced without changing the local schema. Cache failures are intentionally
/// non-fatal; analytics can always fall back to a live request.
class AnalyticsCacheStore {
  final Future<Directory> Function()? _directoryProvider;
  static final Map<String, int> _accountRevisions = {};
  static final Map<String, Future<void>> _pendingOperations = {};

  AnalyticsCacheStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider;

  static int revisionFor(String userId) => _accountRevisions[userId] ?? 0;

  Future<void> _serialize(String userId, Future<void> Function() action) async {
    final previous = _pendingOperations[userId] ?? Future<void>.value();
    final next = previous.catchError((_) {}).then((_) => action());
    _pendingOperations[userId] = next;
    try {
      await next;
    } finally {
      if (identical(_pendingOperations[userId], next)) {
        _pendingOperations.remove(userId);
      }
    }
  }

  Future<Directory> _cacheDirectory() async {
    final root =
        await (_directoryProvider?.call() ??
            getApplicationDocumentsDirectory());
    final directory = Directory(p.join(root.path, 'analytics_cache'));
    await directory.create(recursive: true);
    return directory;
  }

  String _fileName(String userId, int rangeDays) {
    final encoded = base64Url.encode(utf8.encode(userId)).replaceAll('=', '');
    return '${encoded}_$rangeDays.json';
  }

  Future<File> _fileFor(String userId, int rangeDays) async {
    final directory = await _cacheDirectory();
    return File(p.join(directory.path, _fileName(userId, rangeDays)));
  }

  Future<AnalyticsCacheEntry?> read({
    required String userId,
    required int rangeDays,
  }) async {
    try {
      final pending = _pendingOperations[userId];
      if (pending != null) await pending.catchError((Object _) {});
      final file = await _fileFor(userId, rangeDays);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final cachedAt = DateTime.tryParse(
        decoded['cached_at']?.toString() ?? '',
      );
      final data = decoded['data'];
      if (cachedAt == null || data is! Map) return null;
      return AnalyticsCacheEntry(
        cachedAt: cachedAt.toUtc(),
        data: Map<String, dynamic>.from(data),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write({
    required String userId,
    required int rangeDays,
    required Map<String, dynamic> data,
    int? expectedRevision,
  }) async {
    final revision = expectedRevision ?? revisionFor(userId);
    await _serialize(userId, () async {
      try {
        if (revisionFor(userId) != revision) return;
        final file = await _fileFor(userId, rangeDays);
        if (revisionFor(userId) != revision) return;
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(
          jsonEncode({
            'cached_at': DateTime.now().toUtc().toIso8601String(),
            'data': data,
          }),
          flush: true,
        );
        if (revisionFor(userId) != revision) {
          if (await temporary.exists()) await temporary.delete();
          return;
        }
        await temporary.rename(file.path);
      } catch (_) {
        // A cache is an optimization. A failed write must never block a sync or
        // prevent the freshly fetched dashboard from being shown.
      }
    });
  }

  Future<void> delete({required String userId, required int rangeDays}) async {
    await _serialize(userId, () async {
      try {
        final file = await _fileFor(userId, rangeDays);
        if (await file.exists()) await file.delete();
        final temporary = File('${file.path}.tmp');
        if (await temporary.exists()) await temporary.delete();
      } catch (_) {}
    });
  }

  /// Invalidate in-flight requests before waiting for disk writes to finish.
  Future<void> deleteForUser(String userId) async {
    _accountRevisions[userId] = revisionFor(userId) + 1;
    await _serialize(userId, () async {
      final directory = await _cacheDirectory();
      final encoded = base64Url.encode(utf8.encode(userId)).replaceAll('=', '');
      final accountFile = RegExp(
        '^${RegExp.escape(encoded)}_[0-9]+\\.json(?:\\.tmp)?\$',
      );
      await for (final entry in directory.list()) {
        if (entry is File && accountFile.hasMatch(p.basename(entry.path))) {
          await entry.delete();
        }
      }
    });
  }
}
