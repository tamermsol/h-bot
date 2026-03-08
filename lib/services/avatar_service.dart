import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AvatarService {
  static const String _avatarPathKey = 'user_avatar_path';
  final ImagePicker _picker = ImagePicker();

  // Default avatar paths (bundled with app)
  static const List<String> defaultAvatars = [
    'assets/images/avatars/avatar_1.png',
    'assets/images/avatars/avatar_2.png',
    'assets/images/avatars/avatar_3.png',
    'assets/images/avatars/avatar_4.png',
    'assets/images/avatars/avatar_5.png',
    'assets/images/avatars/avatar_6.png',
    'assets/images/avatars/avatar_7.png',
    'assets/images/avatars/avatar_8.png',
    'assets/images/avatars/avatar_9.png',
    'assets/images/avatars/avatar_10.png',
  ];

  /// Get the current avatar path (either default or custom)
  Future<String?> getCurrentAvatarPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarPathKey);
  }

  /// Set a default avatar
  Future<void> setDefaultAvatar(String assetPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarPathKey, assetPath);
  }

  /// Pick image from gallery
  Future<String?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        return await _saveCustomAvatar(image.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Take photo with camera
  Future<String?> pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        return await _saveCustomAvatar(image.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error taking photo: $e');
      return null;
    }
  }

  /// Save custom avatar to app directory
  Future<String> _saveCustomAvatar(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${appDir.path}/avatars');

    // Create directory if it doesn't exist
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }

    // Copy file to app directory
    final fileName =
        'custom_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final targetPath = '${avatarDir.path}/$fileName';
    final sourceFile = File(sourcePath);
    await sourceFile.copy(targetPath);

    // Save path to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarPathKey, targetPath);

    return targetPath;
  }

  /// Check if avatar is a custom (local file) or default (asset)
  bool isCustomAvatar(String? path) {
    if (path == null) return false;
    return !path.startsWith('assets/');
  }

  /// Delete custom avatar
  Future<void> deleteCustomAvatar() async {
    final path = await getCurrentAvatarPath();
    if (path != null && isCustomAvatar(path)) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting custom avatar: $e');
      }
    }

    // Clear from preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_avatarPathKey);
  }
}
