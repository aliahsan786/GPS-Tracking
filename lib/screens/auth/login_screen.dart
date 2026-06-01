import 'package:flutter/foundation.dart' show defaultTargetPlatform, kDebugMode, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/auth_status.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/alert_banner.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/apple_sign_in_button.dart';
import '../../widgets/common/google_sign_in_button.dart';

/// Covers S2 (Login) and S3 (Login + failure banner).
///
/// Pure UI. [LoginScreenHost] supplies state and callbacks.
/// [onDevBypass], when non-null, renders a debug-only skip button
/// below the Google CTA.
class LoginScreen extends StatelessWidget {
  final VoidCallback onGoogleTap;
  final VoidCallback onAppleTap;
  final bool googleLoading;
  final bool appleLoading;
  final String? errorTitle;
  final String? errorSubtitle;
  final VoidCallback? onDevBypass;

  const LoginScreen({
    super.key,
    required this.onGoogleTap,
    required this.onAppleTap,
    this.googleLoading = false,
    this.appleLoading = false,
    this.errorTitle,
    this.errorSubtitle,
    this.onDevBypass,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorTitle != null;
    // While either provider is signing in, both buttons are disabled, but
    // only the tapped one shows its spinner.
    final signingIn = googleLoading || appleLoading;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHPadding,
          ),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const AppLogo(size: 110),
              const SizedBox(height: AppSpacing.xl),
              Text('Sign in', style: AppTextStyles.h1),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Continue to your tracking dashboard',
                style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              if (hasError) ...[
                AlertBanner(
                  icon: Icons.error_outline_rounded,
                  title: errorTitle!,
                  subtitle: errorSubtitle ?? '',
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              GoogleSignInButton(
                onPressed: signingIn ? null : onGoogleTap,
                loading: googleLoading,
              ),
              if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                const SizedBox(height: AppSpacing.sm),
                AppleSignInButton(
                  onPressed: signingIn ? null : onAppleTap,
                  loading: appleLoading,
                ),
              ],
              // if (onDevBypass != null) ...[
              //   const SizedBox(height: AppSpacing.sm),
              //   TextButton(
              //     onPressed: onDevBypass,
              //     style: TextButton.styleFrom(
              //       foregroundColor: AppColors.primaryRed.withValues(alpha: 0.7),
              //     ),
              //     child: const Text(
              //       'Skip sign-in (debug only)',
              //       style: TextStyle(
              //         fontSize: 12,
              //         decoration: TextDecoration.underline,
              //       ),
              //     ),
              //   ),
              // ],
              const Spacer(flex: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// State adapter: drives Google sign-in via [AuthProvider] and
/// navigates to Tracking on success.
class LoginScreenHost extends StatefulWidget {
  const LoginScreenHost({super.key});

  @override
  State<LoginScreenHost> createState() => _LoginScreenHostState();
}

class _LoginScreenHostState extends State<LoginScreenHost> {
  AuthProvider? _auth;
  // Which provider the user tapped, so the spinner shows on that button only.
  _PendingAuth? _pending;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<AuthProvider>();
    if (_auth != next) {
      _auth?.removeListener(_onAuthChanged);
      _auth = next;
      _auth!.addListener(_onAuthChanged);
    }
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (_auth?.status == AuthStatus.authenticated) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.tracking);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        final signingIn = auth.isSigningIn;
        return LoginScreen(
          onGoogleTap: () {
            setState(() => _pending = _PendingAuth.google);
            auth.signInWithGoogle();
          },
          onAppleTap: () {
            setState(() => _pending = _PendingAuth.apple);
            auth.signInWithApple();
          },
          googleLoading: signingIn && _pending == _PendingAuth.google,
          appleLoading: signingIn && _pending == _PendingAuth.apple,
          errorTitle:
              auth.errorMessage != null ? 'Authentication failed' : null,
          errorSubtitle: auth.errorMessage,
          // Debug-only shortcut so the UI can be exercised end-to-end
          // before Google OAuth / the real backend are configured.
          onDevBypass: kDebugMode ? auth.devBypass : null,
        );
      },
    );
  }
}

/// Identifies which sign-in button the user tapped, so the loader is
/// scoped to that button alone.
enum _PendingAuth { google, apple }
