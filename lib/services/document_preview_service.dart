// File: lib/services/document_preview_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:lawdesk/widgets/document_preview_modal.dart';
import 'package:lawdesk/widgets/delightful_toast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DocumentPreviewService {
  static final _supabase = Supabase.instance.client;

  /// Check if file type is previewable
  static bool isPreviewable(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return ['pdf', 'jpg', 'jpeg', 'png', 'gif'].contains(extension);
  }

  /// Get file extension
  static String getFileExtension(String fileName) {
    return fileName.split('.').last.toLowerCase();
  }

  /// Download file to temporary directory
  static Future<File?> downloadFile(
    BuildContext context,
    String bucketName,
    String filePath,
  ) async {
    try {
      // Show loading
      AppToast.showInfo(
        context: context,
        title: "Loading",
        message: "Preparing document...",
      );

      // Download from Supabase Storage
      final bytes = await _supabase.storage
          .from(bucketName)
          .download(filePath);

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = filePath.split('/').last;
      final file = File('${tempDir.path}/$fileName');

      // Write bytes to file
      await file.writeAsBytes(bytes);

      return file;
    } catch (e) {
      print('Error downloading file: $e');
      if (context.mounted) {
        AppToast.showError(
          context: context,
          title: "Error",
          message: "Failed to load document: ${e.toString()}",
        );
      }
      return null;
    }
  }

  /// Show preview modal
  static Future<void> showPreview(
    BuildContext context, {
    required String fileName,
    required String bucketName,
    required String filePath,
  }) async {
    // Check if file is previewable
    if (!isPreviewable(fileName)) {
      AppToast.showWarning(
        context: context,
        title: "Preview Not Available",
        message: "This file type cannot be previewed. Only PDF and images are supported.",
      );
      return;
    }

    // Download the file
    final file = await downloadFile(context, bucketName, filePath);

    if (file == null || !context.mounted) return;

    // Show preview modal
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DocumentPreviewModal(
        file: file,
        fileName: fileName,
      ),
    );

    // Clean up temporary file after modal closes
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting temp file: $e');
    }
  }
}
