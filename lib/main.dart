import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gps_tracking/firebase_options.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/events/auth_events_bus.dart';
import 'core/router/app_routes.dart';
import 'core/theme/app_assets.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/tracking_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/location_repository.dart';
import 'repositories/tracking_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/tracking/tracking_screen_host.dart';
import 'services/apple_sign_in_service.dart';
import 'services/api_client.dart';
import 'services/connectivity_service.dart';
import 'services/google_sign_in_service.dart';
import 'services/local_queue_service.dart';
import 'services/location_service.dart';
import 'services/secure_storage_service.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Hive must be ready before the offline queue *and* the theme cache.
  await Hive.initFlutter();

  // Fetch the remote brand theme (colors + logo + background) and apply it
  // before the first frame, so the whole app renders themed. Best-effort:
  // falls back to the cached or baked-in defaults on any failure.
  final theme = await ThemeServiceImpl().load();
  AppColors.applyTheme(
    primary: theme.primary,
    secondary: theme.secondary,
    accent: theme.accent,
    background: theme.background,
    text: theme.text,
  );
  AppRemoteAssets.applyTheme(
    logoUrl: theme.logoUrl,
    backgroundUrl: theme.backgroundUrl,
  );

  // Warm chrome so system bars blend with the (themed) app background.
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.backgroundCream,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Persistent queue for offline location points. Must be ready before
  // anything can enqueue.
  final queueService = LocalQueueServiceImpl();
  await queueService.init();

  // Cross-cutting bus that lets the ApiClient signal 401s to
  // AuthProvider without creating a direct dependency.
  final authEvents = AuthEventsBus();

  // Construct services once and hand them to the provider tree as
  // `.value` providers so they're genuinely singletons.
  final storage = SecureStorageServiceImpl();
  final apiClient = ApiClient(storage: storage, authEvents: authEvents);
  final googleSignIn = GoogleSignInServiceImpl();
  final appleSignIn = AppleSignInServiceImpl();
  final locationService = LocationServiceImpl();
  final connectivityService = ConnectivityServiceImpl();

  runApp(
    FanthrofitApp(
      storage: storage,
      apiClient: apiClient,
      googleSignIn: googleSignIn,
      appleSignIn: appleSignIn,
      locationService: locationService,
      connectivityService: connectivityService,
      queueService: queueService,
      authEvents: authEvents,
    ),
  );
}

class FanthrofitApp extends StatelessWidget {
  final SecureStorageService storage;
  final ApiClient apiClient;
  final GoogleSignInService googleSignIn;
  final AppleSignInService appleSignIn;
  final LocationService locationService;
  final ConnectivityService connectivityService;
  final LocalQueueService queueService;
  final AuthEventsBus authEvents;

  const FanthrofitApp({
    super.key,
    required this.storage,
    required this.apiClient,
    required this.googleSignIn,
    required this.appleSignIn,
    required this.locationService,
    required this.connectivityService,
    required this.queueService,
    required this.authEvents,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // --- Services (pre-built singletons) -------------------------
        Provider<SecureStorageService>.value(value: storage),
        Provider<ApiClient>.value(value: apiClient),
        Provider<GoogleSignInService>.value(value: googleSignIn),
        Provider<AppleSignInService>.value(value: appleSignIn),
        Provider<LocationService>.value(value: locationService),
        Provider<ConnectivityService>.value(value: connectivityService),
        Provider<LocalQueueService>.value(value: queueService),
        Provider<AuthEventsBus>.value(value: authEvents),

        // --- Repositories (stateless wrappers) -----------------------
        ProxyProvider<ApiClient, AuthRepository>(
          update: (_, api, __) => AuthRepositoryImpl(api),
        ),
        ProxyProvider<ApiClient, TrackingRepository>(
          update: (_, api, __) => TrackingRepositoryImpl(api),
        ),
        ProxyProvider2<ApiClient, LocalQueueService, LocationRepository>(
          update: (_, api, queue, __) => LocationRepositoryImpl(api, queue),
        ),

        // --- State providers (order = creation order) ----------------
        // Connectivity first so Auth/Tracking can read it in their
        // constructors via ctx.read.
        ChangeNotifierProvider<ConnectivityProvider>(
          create: (ctx) =>
              ConnectivityProvider(ctx.read<ConnectivityService>()),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) => AuthProvider(
            repo: ctx.read<AuthRepository>(),
            google: ctx.read<GoogleSignInService>(),
            apple: ctx.read<AppleSignInService>(),
            storage: ctx.read<SecureStorageService>(),
            bus: ctx.read<AuthEventsBus>(),
          ),
        ),
        ChangeNotifierProvider<TrackingProvider>(
          create: (ctx) => TrackingProvider(
            trackingRepo: ctx.read<TrackingRepository>(),
            locationRepo: ctx.read<LocationRepository>(),
            locationService: ctx.read<LocationService>(),
            auth: ctx.read<AuthProvider>(),
            connectivity: ctx.read<ConnectivityProvider>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Fanthrofit GPS Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: AppRoutes.splash,
        routes: {
          AppRoutes.splash: (_) => const SplashScreen(),
          AppRoutes.login: (_) => const LoginScreenHost(),
          AppRoutes.tracking: (_) => const TrackingScreenHost(),
        },
      ),
    );
  }
}
