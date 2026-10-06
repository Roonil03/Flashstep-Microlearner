import 'dart:convert';
import '../../../core/storage/session_storage.dart';

/// Device-local and account-scoped. A missing state never enrolls existing users.
class NavigationTourStorage {
  final SessionStorage storage;
  static const int sceneCount = 10;
  const NavigationTourStorage(this.storage);

  Future<void> markEligible(String userId) async {
    if (userId.isEmpty) return;
    try {
      await storage.writeNavigationTour(
        userId,
        jsonEncode({'scene': 0, 'dismissed': false}),
      );
    } catch (_) {}
  }

  Future<int?> pendingScene(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final value = await storage.readNavigationTour(userId);
      if (value == null) return null;
      final state = jsonDecode(value);
      if (state is! Map<String, dynamic> || state['dismissed'] != false)
        return null;
      final scene = state['scene'];
      if (scene is! int || scene < 0 || scene >= sceneCount) return null;
      return scene;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProgress(String userId, int scene) async {
    if (userId.isEmpty) return;
    try {
      await storage.writeNavigationTour(
        userId,
        jsonEncode({
          'scene': scene.clamp(0, sceneCount - 1),
          'dismissed': false,
        }),
      );
    } catch (_) {}
  }

  Future<void> dismiss(String userId) async {
    if (userId.isEmpty) return;
    try {
      await storage.writeNavigationTour(
        userId,
        jsonEncode({'scene': 0, 'dismissed': true}),
      );
    } catch (_) {}
  }

  Future<void> clear(String userId) async {
    try {
      await storage.clearNavigationTour(userId);
    } catch (_) {}
  }
}
