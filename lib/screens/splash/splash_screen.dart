import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../models/auth_status.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_logo.dart';

/// Splash (S1).
///
/// Waits for [AuthProvider] to leave [AuthStatus.unknown], then routes
/// to Tracking (if a session exists) or Login. Also enforces a minimum
/// visible duration so the logo isn't a flash.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _minShowDuration = Duration(milliseconds: 800);
  DateTime? _shownAt;
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    _shownAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      auth.addListener(_maybeRoute);
      // In case auth resolved before we subscribed.
      _maybeRoute();
    });
  }

  Future<void> _maybeRoute() async {
    if (_routed || !mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.status == AuthStatus.unknown) return;
    _routed = true;
    auth.removeListener(_maybeRoute);

    final elapsed = DateTime.now().difference(_shownAt!);
    if (elapsed < _minShowDuration) {
      await Future<void>.delayed(_minShowDuration - elapsed);
    }
    if (!mounted) return;

    final target = auth.status == AuthStatus.authenticated
        ? AppRoutes.tracking
        : AppRoutes.login;
    Navigator.of(context).pushReplacementNamed(target);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: AppLogo(size: 140)),
    );
  }
}
