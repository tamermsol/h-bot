import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/background_image_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_strings.dart';

class BackgroundImagePicker extends StatelessWidget {
  final String? currentImageUrl;
  final Function(String?) onImageSelected;
  final String userId;
  final String type; // 'home' or 'room'
  final String entityId;

  const BackgroundImagePicker({
    super.key,
    required this.currentImageUrl,
    required this.onImageSelected,
    required this.userId,
    required this.type,
    required this.entityId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (currentImageUrl != null && currentImageUrl!.isNotEmpty)
          Container(
            height: 150,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildPreviewImage(currentImageUrl!),
            ),
          ),

        // Default backgrounds gallery
        const Text(
          'Choose a Default Background',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: BackgroundImageService.defaultBackgrounds.length,
            itemBuilder: (context, index) {
              final bgPath = BackgroundImageService.defaultBackgrounds[index];
              final isSelected = currentImageUrl == bgPath;

              return GestureDetector(
                onTap: () => onImageSelected(bgPath),
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? HBotColors.primary : Colors.grey,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      bgPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(Icons.image, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Custom image options
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'Or Use Your Own Image',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickFromGallery(context),
                icon: const Icon(Icons.photo_library),
                label: Text(AppStrings.get('background_image_picker_gallery')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HBotColors.primaryLight,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickFromCamera(context),
                icon: const Icon(Icons.camera_alt),
                label: Text(AppStrings.get('background_image_picker_camera')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HBotColors.primaryLight,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Remove background button (only if a background is selected)
        if (currentImageUrl != null && currentImageUrl!.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _removeImage(context),
              icon: const Icon(Icons.delete),
              label: Text(AppStrings.get('background_image_picker_remove_background')),
              style: ElevatedButton.styleFrom(
                backgroundColor: HBotColors.error,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewImage(String imageUrl) {
    // Default background (asset)
    if (BackgroundImageService.isDefaultBackground(imageUrl)) {
      return Image.asset(imageUrl, fit: BoxFit.cover);
    }

    // Local file
    if (BackgroundImageService.isLocalFile(imageUrl)) {
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[800],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
            ),
          );
        },
      );
    }

    // Network image
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[800],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
          ),
        );
      },
    );
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    await _pickAndSaveImage(context, ImageSource.gallery);
  }

  Future<void> _pickFromCamera(BuildContext context) async {
    await _pickAndSaveImage(context, ImageSource.camera);
  }

  Future<void> _pickAndSaveImage(
    BuildContext context,
    ImageSource source,
  ) async {
    final service = BackgroundImageService();

    try {
      // Show loading
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
      }

      // Pick image
      final XFile? image;
      if (source == ImageSource.gallery) {
        image = await service.pickImageFromGallery();
      } else {
        image = await service.pickImageFromCamera();
      }

      if (image == null) {
        if (context.mounted) Navigator.pop(context);
        return;
      }

      // Delete old image if exists and it's a local file
      if (currentImageUrl != null && currentImageUrl!.isNotEmpty) {
        await service.removeBackgroundImage(currentImageUrl);
      }

      // Save image locally
      final imagePath = await service.saveImageLocally(
        image.path,
        userId,
        type,
        entityId,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        onImageSelected(imagePath);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('background_image_picker_background_image_updated_successfully')),
            backgroundColor: HBotColors.primary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('background_image_picker_failed_to_save_image_e')),
            backgroundColor: HBotColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeImage(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.get('background_image_picker_remove_background_2')),
        content: const Text(
          'Are you sure you want to remove the background image?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.get('background_image_picker_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: HBotColors.error,
            ),
            child: Text(AppStrings.get('background_image_picker_remove')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Simply remove the background (set to null)
    // No need to delete from storage since we're only using local assets
    if (context.mounted) {
      onImageSelected(null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('background_image_picker_background_removed_successfully')),
          backgroundColor: HBotColors.primary,
        ),
      );
    }
  }
}
