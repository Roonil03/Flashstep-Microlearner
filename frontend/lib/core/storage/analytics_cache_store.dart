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

  AnalyticsCacheStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider;

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
  }) async {
    try {
      final file = await _fileFor(userId, rangeDays);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(
        jsonEncode({
          'cached_at': DateTime.now().toUtc().toIso8601String(),
          'data': data,
        }),
        flush: true,
      );
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
    } catch (_) {
      // A cache is an optimization. A failed write must never block a sync or
      // prevent the freshly fetched dashboard from being shown.
    }
  }

  Future<void> delete({required String userId, required int rangeDays}) async {
    try {
      final file = await _fileFor(userId, rangeDays);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
