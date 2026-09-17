import 'package:flutter/material.dart';
import '../utills/app_colors.dart';

/// Convenience helpers for consistent snackbar coloring.
///
/// Convention (project-wide):
///   - [showServerError]  → red  (kErrorRed): API/server failures.
///   - [showInfo]         → blue (kRailwayBlue): informational/validation messages.
///   - [showSuccess]      → green (kSuccessGreen): successful actions.
class AppSnackbar {
  static void showServerError(BuildContext context, String message, {int? statusCode, dynamic error}) {
    _show(context, message, kErrorRed);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, kRailwayBlue);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, kSuccessGreen);
  }

  static void _show(BuildContext context, String message, Color color) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }
}