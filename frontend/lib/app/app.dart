import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider).maybeWhen(
          data: (mode) => mode,
          orElse: () => ThemeMode.light,
        );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.login: (_) => const LoginPage(),
        AppRoutes.register: (_) => const _PlaceholderPage(title: 'Register Page'),
        AppRoutes.home: (_) => const _PlaceholderPage(title: 'Home Dashboard'),
        AppRoutes.analytics: (_) => const _PlaceholderPage(title: 'Analytics Page'),
        AppRoutes.settings: (_) => const _PlaceholderPage(title: 'Settings Page'),
        AppRoutes.createDeck: (_) => const _PlaceholderPage(title: 'Create Deck Page'),
        AppRoutes.browseDecks: (_) => const _PlaceholderPage(title: 'Browse Decks Page'),
        AppRoutes.review: (_) => const _PlaceholderPage(title: 'Start Review Page'),
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