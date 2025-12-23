// File: lib/utils/offline_action_helper.dart

import 'package:flutter/material.dart';
import 'package:lawdesk/services/connectivity_service.dart';
import 'package:lawdesk/widgets/delightful_toast.dart';

class OfflineActionHelper {
  /// Check if action can be performed (requires internet)
  /// Returns true if online, false if offline (and shows warning)
  static bool canPerformAction(BuildContext context, {String? actionName}) {
    if (!connectivityService.isConnected) {
      _showOfflineWarning(context, actionName: actionName);
      return false;
    }
    return true;
  }

  /// Show offline warning dialog
  static void _showOfflineWarning(BuildContext context, {String? actionName}) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off,
                  color: Color(0xFFF59E0B),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Internet Connection',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                actionName != null
                    ? 'You cannot $actionName while offline. Please connect to the internet and try again.'
                    : 'This action requires an internet connection. Please connect and try again.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Got It',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Show a simple toast for offline actions
  static void showOfflineToast(BuildContext context, {String? actionName}) {
    AppToast.showWarning(
      context: context,
      title: "No Internet",
      message: actionName != null
          ? "Cannot $actionName while offline"
          : "This action requires internet connection",
    );
  }

  /// Wrap a callback with offline check
  static VoidCallback? wrapAction(
    BuildContext context,
    VoidCallback action, {
    String? actionName,
    bool showToast = false,
  }) {
    return () {
      if (connectivityService.isConnected) {
        action();
      } else {
        if (showToast) {
          showOfflineToast(context, actionName: actionName);
        } else {
          _showOfflineWarning(context, actionName: actionName);
        }
      }
    };
  }
}