import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class BackgroundImageService {
  final ImagePicker _picker = ImagePicker();

  /// List of default background images bundled with the app
  static const List<String> defaultBackgrounds = [
    'assets/images/backgrounds/default_1.jpg',
    'assets/images/backgrounds/default_2.jpg',
    'assets/images/backgrounds/default_3.jpg',
    'assets/images/backgrounds/default_4.jpg',
    'assets/images/backgrounds/default_5.jpg',
  ];

  /// Check if a URL is a default background
  static bool isDefaultBackground(String? url) {
    if (url == null) return false;
    return defaultBackgrounds.contains(url);
  }

  /// Check if a URL is a local file path
  static bool isLocalFile(String? url) {
    if (url == null) return false;
    return url.startsWith('/') || url.startsWith('file://');
  }

  /// Pick an image from gallery
  Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      throw 'Failed to pick image from gallery: $e';
    }
  }

  /// Pick an image from camera
  Future<XFile?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      throw 'Failed to take photo: $e';
    }
  }

  /// Save image to local storage and return the file path
  Future<String> saveImageLocally(
    String sourcePath,
    String userId,
    String type, // 'home' or 'room'
    String entityId,
  ) async {
    try {
      // Get the app's documents directory
      final directory = await getApplicationDocumentsDirectory();

      // Create a subdirectory for background images
      final backgroundsDir = Directory(
        '${directory.path}/backgrounds/$userId/$type/$entityId',
      );
      if (!await backgroundsDir.exists()) {
        await backgroundsDir.create(recursive: true);
      }

      // Generate a unique filename
      final fileExt = path.extension(sourcePath);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final destinationPath = '${backgroundsDir.path}/$fileName';

      // Copy the file to the app's directory
      final sourceFile = File(sourcePath);
      await sourceFile.copy(destinationPath);

      return destinationPath;
    } catch (e) {
      throw 'Failed to save image locally: $e';
    }
  }

  /// Delete local background image file
  Future<void> deleteLocalImage(String imagePath) async {
    // Don't delete default backgrounds
    if (isDefaultBackground(imagePath)) {
      return;
    }

    // Don't delete if it's not a local file
    if (!isLocalFile(imagePath)) {
      return;
    }

    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Log error but don't throw
      // ignore: avoid_print
      print('Warning: Failed to delete local image: $e');
    }
  }

  /// Remove background image (delete local file if applicable)
  Future<void> removeBackgroundImage(String? currentImageUrl) async {
    if (currentImageUrl != null && currentImageUrl.isNotEmpty) {
      // Don't delete default backgrounds
      if (isDefaultBackground(currentImageUrl)) {
        return;
      }

      // Delete local file if it's a local path
      if (isLocalFile(currentImageUrl)) {
        try {
          await deleteLocalImage(currentImageUrl);
        } catch (e) {
          // Log error but don't throw
          // ignore: avoid_print
          print('Warning: Failed to delete old background image: $e');
        }
      }
    }
  }
}
