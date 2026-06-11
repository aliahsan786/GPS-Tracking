import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/common/primary_button.dart';

/// Shown while a tracking session is active.
///
/// Reached by pushing on top of the tracking screen right after
/// `startTracking()` succeeds. GPS continues recording in the background
/// (the TrackingProvider owns that); this screen only displays the
/// company web portal and the Stop control.
///
/// [onStop] runs the normal stop logic (drain queue, close session, etc).
/// After it completes this screen pops, returning to the tracking screen
/// which then reflects the post-stop state (Idle / Syncing).
class TrackingWebViewScreen extends StatefulWidget {
  final String url;
  final Future<void> Function() onStop;

  const TrackingWebViewScreen({
    super.key,
    required this.url,
    required this.onStop,
  });

  @override
  State<TrackingWebViewScreen> createState() => _TrackingWebViewScreenState();
}

class _TrackingWebViewScreenState extends State<TrackingWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.backgroundCream)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _handleStop() {
    if (_stopping) return;
    setState(() => _stopping = true);

    // Return to the tracking screen *first*, then run the normal stop +
    // upload flow on the provider. This way the tracking screen is visible
    // while the queued points drain, so its "Syncing data..." progress
    // screen shows — exactly as before the web portal was added. The
    // provider runs independently of this (now-disposed) screen.
    Navigator.of(context).pop();
    unawaited(widget.onStop());
  }

  @override
  Widget build(BuildContext context) {
    // Block the back gesture/button: the session must end via Stop so the
    // tracking screen returns in a consistent post-stop state.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.backgroundCream,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    WebViewWidget(controller: _controller),
                    if (_loading)
                      Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryRed,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHPadding,
                  AppSpacing.md,
                  AppSpacing.screenHPadding,
                  AppSpacing.lg,
                ),
                child: PrimaryButton(
                  label: 'Stop Tracking',
                  loading: _stopping,
                  onPressed: _stopping ? null : _handleStop,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
