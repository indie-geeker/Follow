import 'package:flutter/material.dart';

/// Helper functions for showing styled SnackBars
class SnackBarHelper {
  SnackBarHelper._();

  /// Shows a success SnackBar with green background
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Shows an error SnackBar with theme error color
  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: theme.colorScheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Shows an info SnackBar with default styling
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
