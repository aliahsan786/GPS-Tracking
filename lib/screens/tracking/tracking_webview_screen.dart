import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/common/primary_button.dart';

/// The web portal shown while tracking is active (and after it stops).
///
/// Reached by pushing on top of the tracking screen right after
/// `startTracking()` succeeds. The user stays inside this screen and
/// toggles tracking with the bottom button:
///
///  - **Stop Tracking** → runs the real stop flow, then loads [stopUrl]
///    in the same WebView and flips the button to "Start Tracking".
///  - **Start Tracking** → runs the real start flow, then loads [startUrl]
///    and flips the button back to "Stop Tracking".
///
/// A top-left back button returns to the native tracking screen without
/// changing the tracking state.
class TrackingWebViewScreen extends StatefulWidget {
  /// Portal page for an active session (session token already appended).
  final String startUrl;

  /// Portal page shown after stopping (session token already appended).
  /// Null falls back to staying on [startUrl].
  final String? stopUrl;

  /// Runs the real start flow. Returns true if a session actually became
  /// active (false e.g. when permission was denied).
  final Future<bool> Function() onStart;

  /// Runs the real stop flow (upload remaining points + close session).
  final Future<void> Function() onStop;

  const TrackingWebViewScreen({
    super.key,
    required this.startUrl,
    required this.stopUrl,
    required this.onStart,
    required this.onStop,
  });

  @override
  State<TrackingWebViewScreen> createState() => _TrackingWebViewScreenState();
}

class _TrackingWebViewScreenState extends State<TrackingWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _busy = false; // start/stop in flight
  bool _tracking = true; // we arrive here right after a successful start

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
      ..loadRequest(Uri.parse(widget.startUrl));
  }

  Future<void> _handleStop() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.onStop();
    if (!mounted) return;
    // Stay in the WebView: load the stop page and flip to "Start".
    final next = widget.stopUrl ?? widget.startUrl;
    await _controller.loadRequest(Uri.parse(next));
    if (!mounted) return;
    setState(() {
      _tracking = false;
      _busy = false;
    });
  }

  Future<void> _handleStart() async {
    if (_busy) return;
    setState(() => _busy = true);
    final started = await widget.onStart();
    if (!mounted) return;
    if (!started) {
      // Permission denied / failed — stay on the stop page.
      setState(() => _busy = false);
      return;
    }
    await _controller.loadRequest(Uri.parse(widget.startUrl));
    if (!mounted) return;
    setState(() {
      _tracking = true;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundCream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.primaryRed),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Fanthrofit', style: AppTextStyles.h4),
      ),
      body: SafeArea(
        top: false,
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
              child: _tracking
                  ? PrimaryButton(
                      label: 'Stop Tracking',
                      loading: _busy,
                      onPressed: _busy ? null : _handleStop,
                    )
                  : PrimaryButton(
                      label: 'Start Tracking',
                      loading: _busy,
                      onPressed: _busy ? null : _handleStart,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
