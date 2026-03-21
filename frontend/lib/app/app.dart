MaterialApp(
  debugShowCheckedModeBanner: false,
  initialRoute: AppRoutes.splash,
  routes: {
    AppRoutes.splash: (_) => const SplashScreen(),
    AppRoutes.login: (_) => const LoginPage(),
    AppRoutes.register: (_) => const RegisterPage(),
    AppRoutes.home: (_) => const HomeDashboardPage(),
    AppRoutes.analytics: (_) => const AnalyticsPage(),
    AppRoutes.settings: (_) => const SettingsPage(),
    AppRoutes.createDeck: (_) => const CreateDeckPage(),
    AppRoutes.browseDecks: (_) => const BrowseDecksPage(),
    AppRoutes.review: (_) => const StartReviewPage(),
  },
);