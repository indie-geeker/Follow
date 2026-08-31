import 'package:flutter/material.dart';

/// A reusable control button used in player controls.
/// Wraps an icon in a styled container with tap handling.
class PlayerControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;
  final bool isActive;
  final String? tooltip;

  const PlayerControlButton({
    super.key,
    required this.icon,
    required this.size,
    required this.onPressed,
    this.isActive = false,
    this.tooltip,
  });

  Color _foregroundColor(BuildContext context, {double alpha = 1.0}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : Colors.black87;
    return alpha < 1.0 ? baseColor.withValues(alpha: alpha) : baseColor;
  }

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive
              ? _foregroundColor(context, alpha: 0.2)
              : _foregroundColor(context, alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isActive
              ? _foregroundColor(context)
              : _foregroundColor(context, alpha: 0.8),
          size: size,
        ),
      ),
    );

    final message = tooltip;
    if (message == null) return button;

    return Tooltip(
      message: message,
      child: Semantics(button: true, label: message, child: button),
    );
  }
}
