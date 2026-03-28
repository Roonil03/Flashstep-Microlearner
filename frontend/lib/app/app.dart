import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/decks/presentation/create_deck_page.dart';
import '../features/decks/presentation/deck_detail_page.dart';
import '../features/home/presentation/home_dashboard_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/review/presentation/start_review_page.dart';
import '../features/decks/presentation/browse_decks_page.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.login: (_) => const LoginPage(),
        AppRoutes.register: (_) => const RegisterPage(),
        AppRoutes.home: (_) => const HomeDashboardPage(),
        AppRoutes.analytics: (_) => const _PlaceholderPage(title: 'Analytics Page'),
        AppRoutes.settings: (_) => const SettingsPage(),
        AppRoutes.browseDecks: (_) => const BrowseDecksPage(),
        AppRoutes.review: (_) => const StartReviewPage(),
        AppRoutes.createDeck: (_) => const CreateDeckPage(),
        AppRoutes.deckDetail: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final deckId = args is String ? args : '';
          return DeckDetailPage(deckId: deckId);
        },
      },
      onUnknownRoute: (_) {
        return MaterialPageRoute(
          builder: (_) => const _PlaceholderPage(title: 'Page Not Found'),
        );
      },
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;

  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}