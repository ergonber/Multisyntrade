import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/screens/splash/splash_screen.dart';
import '../../../presentation/screens/auth/login_screen.dart';
import '../../../presentation/screens/auth/register_screen.dart';
import '../../../presentation/screens/auth/forgot_password_screen.dart';
import '../../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../../presentation/screens/home/home_screen.dart';
import '../../../presentation/screens/signals/signals_screen.dart';
import '../../../presentation/screens/stats/stats_screen.dart';
import '../../../presentation/screens/more/more_screen.dart';
import '../../../presentation/screens/home/home_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      name: 'forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => HomeShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: HomeScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/signals',
              name: 'signals',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SignalsScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/stats',
              name: 'stats',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: StatsScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/more',
              name: 'more',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: MoreScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
  redirect: (context, state) {
    final auth = context.read<AuthProvider>();
    final isLoggedIn = auth.isAuthenticated;
    final isAuthRoute = state.matchedLocation == '/login' ||
        state.matchedLocation == '/register' ||
        state.matchedLocation == '/forgot-password';
    final isSplash = state.matchedLocation == '/splash';

    if (isSplash) return null;

    if (!isLoggedIn && !isAuthRoute) return '/login';
    if (isLoggedIn && isAuthRoute) return '/home';

    return null;
  },
);
