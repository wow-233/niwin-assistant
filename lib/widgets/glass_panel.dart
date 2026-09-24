import 'dart:ui';

import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.enabled = true,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool enabled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final panelColor =
        color ??
        (brightness == Brightness.dark
            ? const Color(0xB31B2430)
            : const Color(0xBDFBFDFF));
    final decoration = BoxDecoration(
      color: panelColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.82),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.07),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    );
    final content = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );
    if (!enabled) return content;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: content,
      ),
    );
  }
}

class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF101820), Color(0xFF132A2B), Color(0xFF172133)]
              : const [Color(0xFFF1FAF7), Color(0xFFEAF4FF), Color(0xFFF9F5FF)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: _Glow(
              size: 240,
              color: const Color(0xFF7BDCB5).withValues(alpha: 0.28),
            ),
          ),
          Positioned(
            top: 260,
            left: -100,
            child: _Glow(
              size: 260,
              color: const Color(0xFF8BB9FF).withValues(alpha: 0.22),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
