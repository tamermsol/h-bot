import 'package:flutter/material.dart';
import '../services/avatar_service.dart';
import '../theme/app_theme.dart';

class AvatarPickerDialog extends StatelessWidget {
  final String? currentAvatarPath;

  const AvatarPickerDialog({super.key, this.currentAvatarPath});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: HBotColors.cardLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HBotRadius.large),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Avatar',
              style: TextStyle(
                color: HBotColors.textPrimaryLight,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),

            // Default avatars grid
            const Text(
              'Default Avatars',
              style: TextStyle(color: HBotColors.textSecondaryLight, fontSize: 14),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    5, // Changed from 3 to 5 to fit 10 avatars in 2 rows
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: AvatarService.defaultAvatars.length,
              itemBuilder: (context, index) {
                final avatarPath = AvatarService.defaultAvatars[index];
                final isSelected = currentAvatarPath == avatarPath;

                return GestureDetector(
                  onTap: () => Navigator.pop(context, avatarPath),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? HBotColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 30, // Reduced from 40 to fit more avatars
                      backgroundImage: AssetImage(avatarPath),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
            Divider(color: HBotColors.textSecondaryLight.withOpacity(0.2)),
            const SizedBox(height: 12),

            // Custom options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOptionButton(
                  context,
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
                _buildOptionButton(
                  context,
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: HBotColors.textSecondaryLight),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HBotRadius.medium),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: HBotColors.surfaceLight,
          borderRadius: BorderRadius.circular(HBotRadius.medium),
        ),
        child: Column(
          children: [
            Icon(icon, color: HBotColors.primary, size: 32),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: HBotColors.textPrimaryLight, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
