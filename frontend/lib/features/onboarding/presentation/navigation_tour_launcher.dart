import 'package:flutter/material.dart';
import '../../../core/storage/session_storage.dart';
import '../data/navigation_tour_storage.dart';
import 'navigation_tour_page.dart';

bool _tourOpen = false;

Future<void> launchNavigationTour(
  BuildContext context,
  SessionStorage storage, {
  bool replay = false,
}) async {
  if (_tourOpen) return;
  _tourOpen = true;
  try {
    String? userId;
    try {
      userId = await storage.readUserId();
    } catch (_) {}
    if (!context.mounted) return;
    final tourStorage = NavigationTourStorage(storage);
    final scene = replay ? 0 : await tourStorage.pendingScene(userId ?? '');
    if (!context.mounted ||
        scene == null ||
        ModalRoute.of(context)?.isCurrent != true)
      return;
    if (replay) await tourStorage.saveProgress(userId ?? '', 0);
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/navigation-tour'),
        builder:
            (_) => NavigationTourPage(
              initialScene: scene,
              onProgress:
                  (scene) => tourStorage.saveProgress(userId ?? '', scene),
              onDismiss: () => tourStorage.dismiss(userId ?? ''),
            ),
      ),
    );
  } finally {
    _tourOpen = false;
  }
}
