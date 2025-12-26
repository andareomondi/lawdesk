// File: lib/services/camera_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lawdesk/widgets/delightful_toast.dart';
import 'package:lawdesk/services/connectivity_service.dart';

class CameraService {
  static final ImagePicker _picker = ImagePicker();

  /// Show options to take photo or pick from gallery
  static Future<File?> showImageSourceOptions(BuildContext context) async {
    // Check if online
    if (!connectivityService.isConnected) {
      AppToast.showWarning(
        context: context,
        title: "Offline",
        message: "Cannot upload documents while offline",
      );
      return null;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Add Document',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Camera Option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFF1E3A8A),
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Take Photo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  subtitle: const Text(
                    'Use your camera to capture a document',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  onTap: () => Navigator.pop(context, 'camera'),
                ),

                const Divider(height: 1),

                // Gallery Option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: Color(0xFF10B981),
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  subtitle: const Text(
                    'Select an existing photo',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),

                const Divider(height: 1),

                // File Picker Option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.insert_drive_file_outlined,
                      color: Color(0xFF8B5CF6),
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Upload File',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  subtitle: const Text(
                    'Select a PDF or document file',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  onTap: () => Navigator.pop(context, 'file'),
                ),

                const SizedBox(height: 16),

                // Cancel Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) return null;

    if (result == 'camera') {
      return await _capturePhoto(context);
    } else if (result == 'gallery') {
      return await _pickFromGallery(context);
    } else {
      // Return null for 'file' - let the calling code handle file picker
      return null;
    }
  }

  /// Capture photo using camera
  static Future<File?> _capturePhoto(BuildContext context) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // Compress to reduce file size
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image == null) return null;

      return File(image.path);
    } catch (e) {
      print('Error capturing photo: $e');
      if (context.mounted) {
        AppToast.showError(
          context: context,
          title: "Camera Error",
          message: "Failed to capture photo: ${e.toString()}",
        );
      }
      return null;
    }
  }

  /// Pick image from gallery
  static Future<File?> _pickFromGallery(BuildContext context) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image == null) return null;

      return File(image.path);
    } catch (e) {
      print('Error picking from gallery: $e');
      if (context.mounted) {
        AppToast.showError(
          context: context,
          title: "Gallery Error",
          message: "Failed to pick image: ${e.toString()}",
        );
      }
      return null;
    }
  }

  /// Get file size
  static Future<int> getFileSize(File file) async {
    return await file.length();
  }

  /// Get file name from path
  static String getFileName(File file) {
    return file.path.split('/').last;
  }

  /// Generate a unique filename for captured images
  static String generateFileName(String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'IMG_$timestamp.$extension';
  }
}
