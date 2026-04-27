import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
// import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/auth_status.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/alert_banner.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/google_sign_in_button.dart';

/// Covers S2 (Login) and S3 (Login + failure banner).
///
/// Pure UI. [LoginScreenHost] supplies state and callbacks.
/// [onDevBypass], when non-null, renders a debug-only skip button
/// below the Google CTA.
class LoginScreen extends StatelessWidget {
  final VoidCallback onGoogleTap;
  final bool loading;
  final String? errorTitle;
  final String? errorSubtitle;
  final VoidCallback? onDevBypass;

  const LoginScreen({
    super.key,
    required this.onGoogleTap,
    this.loading = false,
    this.errorTitle,
    this.errorSubtitle,
    this.onDevBypass,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorTitle != null;
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
                onPressed: onGoogleTap,
                loading: loading,
              ),
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
      builder: (_, auth, __) => LoginScreen(
        onGoogleTap: auth.signInWithGoogle,
        loading: auth.isSigningIn,
        errorTitle:
            auth.errorMessage != null ? 'Authentication failed' : null,
        errorSubtitle: auth.errorMessage,
        // Debug-only shortcut so the UI can be exercised end-to-end
        // before Google OAuth / the real backend are configured.
        onDevBypass: kDebugMode ? auth.devBypass : null,
      ),
    );
  }
}
