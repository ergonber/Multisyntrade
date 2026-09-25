import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_theme.dart';
import 'data/datasources/remote/supabase/supabase_client.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/signals_provider.dart';
import 'presentation/providers/profile_provider.dart';
import 'presentation/providers/deriv_provider.dart';
import 'presentation/providers/goals_provider.dart';
import 'presentation/providers/simulator_provider.dart';
import 'presentation/providers/subscription_provider.dart';
import 'presentation/providers/admin/admin_dashboard_provider.dart';
import 'presentation/providers/admin/admin_users_provider.dart';
import 'presentation/providers/admin/admin_signals_provider.dart';
import 'presentation/providers/admin/admin_operations_provider.dart';
import 'presentation/providers/admin/admin_announcements_provider.dart';
import 'presentation/providers/admin/admin_finance_provider.dart';
import 'presentation/providers/admin/admin_config_provider.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/admin/admin_shell.dart';
import 'presentation/screens/auth/new_password_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Ruta inicial oculta: si la URL trae /admin (hash `#/admin` o path `/admin`),
/// arranca en el panel; si no, en el splash normal.
String _resolveInitialRoute() {
  final uri = Uri.base;
  final defaultRoute = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  if (uri.fragment.startsWith('/admin') ||
      uri.path.startsWith('/admin') ||
      defaultRoute.startsWith('/admin')) {
    return '/admin';
  }
  return '/';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await SupabaseService.init();

  if (kIsWeb) {
    await _handleWebEmailConfirmation();
    _handleWebDerivCallback();
  } else {
    _setupMobileDeepLinks();
  }

  runApp(const SynTradeApp());
}

Future<void> _handleWebEmailConfirmation() async {
  final uri = Uri.base;
  final code = uri.queryParameters['code'];
  final errorDescription = uri.queryParameters['error_description'];
  final type = uri.queryParameters['type'];

  if (errorDescription != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text('Error: $errorDescription'),
            backgroundColor: const Color(0xFFFF4444),
          ),
        );
      }
      _cleanWebUrl('${uri.origin}${uri.path}');
    });
    return;
  }

  if (code != null) {
    try {
      await Supabase.instance.client.auth.exchangeCodeForSession(code);

      if (type == 'recovery') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (navigatorKey.currentContext != null) {
            Navigator.of(navigatorKey.currentContext!).push(
              MaterialPageRoute(builder: (_) => const NewPasswordScreen()),
            );
          }
          _cleanWebUrl('${uri.origin}${uri.path}');
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (navigatorKey.currentContext != null) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              const SnackBar(
                content: Text('Correo confirmado. Sesión iniciada.'),
                backgroundColor: Color(0xFF00D9A6),
              ),
            );
          }
          _cleanWebUrl('${uri.origin}${uri.path}');
        });
      }
    } catch (e) {
      debugPrint('[EmailConfirm] Error exchanging code: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text('Error al confirmar correo: $e'),
              backgroundColor: const Color(0xFFFF4444),
            ),
          );
        }
        _cleanWebUrl('${uri.origin}${uri.path}');
      });
    }
    return;
  }

  final accessToken = uri.fragment.contains('access_token=');
  if (accessToken) {
    debugPrint('[EmailConfirm] Detected tokens in URL fragment');
  }
}

void _handleWebDerivCallback() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final uri = Uri.base;
    final status = uri.queryParameters['status'];

    if (status != null) {
      debugPrint('[WebCallback] Deriv status: $status');

      final derivProvider = navigatorKey.currentContext?.read<DerivProvider>();
      derivProvider?.refreshConnectionStatus();

      if (navigatorKey.currentContext != null) {
        final messenger = ScaffoldMessenger.of(navigatorKey.currentContext!);
        messenger.showSnackBar(SnackBar(
          content: Text(
            status == 'ok'
                ? 'Cuenta de Deriv conectada exitosamente'
                : 'Error al conectar: ${uri.queryParameters['message'] ?? "desconocido"}',
          ),
          backgroundColor: status == 'ok' ? const Color(0xFF00D9A6) : const Color(0xFFFF4444),
        ));
      }

      final cleanUrl = Uri.parse('${uri.origin}${uri.path}');
      _cleanWebUrl(cleanUrl.toString());
    }
  });
}

void _cleanWebUrl(String url) {
  if (kIsWeb) {
    try {
      debugPrint('[URL] Clean: $url');
    } catch (_) {}
  }
}

void _setupMobileDeepLinks() {
  _initMobileLinks();
}

Future<void> _initMobileLinks() async {
  try {
    final appLinks = AppLinks();

    final initialLink = await appLinks.getInitialLink();
    if (initialLink != null) _handleMobileDeepLink(initialLink);

    appLinks.uriLinkStream.listen((uri) {
      _handleMobileDeepLink(uri);
    });
  } catch (e) {
    debugPrint('[DeepLink] Failed to init: $e');
  }
}

void _handleMobileDeepLink(Uri uri) {
  debugPrint('[DeepLink] Received: $uri');

  if (uri.host == 'deriv-callback') {
    final status = uri.queryParameters['status'];
    debugPrint('[DeepLink] Deriv callback status: $status');

    final derivProvider = navigatorKey.currentContext?.read<DerivProvider>();
    derivProvider?.refreshConnectionStatus();

    if (navigatorKey.currentContext != null) {
      final messenger = ScaffoldMessenger.of(navigatorKey.currentContext!);
      messenger.showSnackBar(SnackBar(
        content: Text(
          status == 'ok'
              ? 'Cuenta de Deriv conectada exitosamente'
              : 'Error al conectar: ${uri.queryParameters['message'] ?? "desconocido"}',
        ),
        backgroundColor: status == 'ok' ? const Color(0xFF00D9A6) : const Color(0xFFFF4444),
      ));
    }
  }

  if (uri.host == 'auth-callback') {
    final code = uri.queryParameters['code'];
    debugPrint('[DeepLink] Auth callback code: $code');
    if (code != null) {
      _exchangeAndNavigateToNewPassword(code);
    }
  }
}

Future<void> _exchangeAndNavigateToNewPassword(String code) async {
  try {
    await Supabase.instance.client.auth.exchangeCodeForSession(code);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext != null) {
        Navigator.of(navigatorKey.currentContext!).push(
          MaterialPageRoute(builder: (_) => const NewPasswordScreen()),
        );
      }
    });
  } catch (e) {
    debugPrint('[DeepLink] Error exchanging code: $e');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text('Error al procesar el enlace: $e'),
            backgroundColor: const Color(0xFFFF4444),
          ),
        );
      }
    });
  }
}

class SynTradeApp extends StatefulWidget {
  const SynTradeApp({super.key});

  @override
  State<SynTradeApp> createState() => _SynTradeAppState();
}

class _SynTradeAppState extends State<SynTradeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final auth = navigatorKey.currentContext?.read<AuthProvider>();
      auth?.checkDeviceOnResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => SignalsProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => DerivProvider()..init()),
        ChangeNotifierProvider(create: (_) => GoalsProvider()),
        ChangeNotifierProvider(create: (_) => SimulatorProvider()),
        ChangeNotifierProvider(create: (_) => AdminDashboardProvider()),
        ChangeNotifierProvider(create: (_) => AdminUsersProvider()),
        ChangeNotifierProvider(create: (_) => AdminSignalsProvider()),
        ChangeNotifierProvider(create: (_) => AdminOperationsProvider()),
        ChangeNotifierProvider(create: (_) => AdminAnnouncementsProvider()),
        ChangeNotifierProvider(create: (_) => AdminFinanceProvider()),
        ChangeNotifierProvider(create: (_) => AdminConfigProvider()),
      ],
      child: MaterialApp(
        title: 'SynTrade',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        initialRoute: _resolveInitialRoute(),
        onGenerateRoute: (settings) {
          final name = settings.name ?? '/';
          if (name == '/admin' || name.startsWith('/admin/')) {
            return MaterialPageRoute(builder: (_) => const AdminShell());
          }
          return MaterialPageRoute(builder: (_) => const SplashScreen());
        },
      ),
    );
  }
}
