import 'package:flutter/material.dart';
import 'package:delightful_toast/delight_toast.dart';
import 'package:delightful_toast/toast/components/toast_card.dart';

class AppToast {
  // Success Toast
  static void showSuccess({
    required BuildContext context,
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    DelightToastBar(
      autoDismiss: true,
      snackbarDuration: duration,
      builder: (context) => ToastCard(
        leading: const Icon(
          Icons.check_circle,
          size: 28,
          color: Color(0xFF10B981),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          message,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ).show(context);
  }

  // Error Toast
  static void showError({
    required BuildContext context,
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    DelightToastBar(
      autoDismiss: true,
      snackbarDuration: duration,
      builder: (context) => ToastCard(
        leading: const Icon(
          Icons.error_outline,
          size: 28,
          color: Color(0xFFEF4444),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          message,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ).show(context);
  }

  // Warning Toast
  static void showWarning({
    required BuildContext context,
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    DelightToastBar(
      autoDismiss: true,
      snackbarDuration: duration,
      builder: (context) => ToastCard(
        leading: const Icon(
          Icons.warning_amber_rounded,
          size: 28,
          color: Color(0xFFF59E0B),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          message,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ).show(context);
  }

  // Info Toast
  static void showInfo({
    required BuildContext context,
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    DelightToastBar(
      autoDismiss: true,
      snackbarDuration: duration,
      builder: (context) => ToastCard(
        leading: const Icon(
          Icons.info_outline,
          size: 28,
          color: Color(0xFF3B82F6),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          message,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ).show(context);
  }
}
