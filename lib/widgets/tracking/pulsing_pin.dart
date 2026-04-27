import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Animated concentric pulse rings with a centre icon.
///
/// [color] defaults to teal (Idle / Active states).
/// Pass [color] = orange for the Initializing state.
class PulsingPin extends StatefulWidget {
  final double size;
  final Color color;
  final IconData icon;

  const PulsingPin({
    super.key,
    this.size = 120,
    this.color = AppColors.secondaryTeal,
    this.icon = Icons.location_on_rounded,
  });

  @override
  State<PulsingPin> createState() => _PulsingPinState();
}

class _PulsingPinState extends State<PulsingPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.size * 0.22;
    final centerSize = widget.size * 0.28;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Stack(
            alignment: Alignment.center,
            children: [
              _pulse(0.0),
              _pulse(0.33),
              _pulse(0.66),
              // Solid filled circle behind the icon
              Container(
                width: centerSize,
                height: centerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.25),
                ),
                child: Icon(
                  widget.icon,
                  size: iconSize,
                  color: widget.color,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pulse(double offset) {
    final raw = (_ctrl.value + offset) % 1.0;
    final scale = 0.4 + raw * 0.6;
    final opacity = (1.0 - raw).clamp(0.0, 1.0) * 0.35;

    return Container(
      width: widget.size * scale,
      height: widget.size * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withValues(alpha: opacity),
      ),
    );
  }
}
