import 'dart:io';
import 'package:flutter/material.dart';
import '../services/background_image_service.dart';

/// A container that displays a background image with optional overlay
class BackgroundContainer extends StatelessWidget {
  final String? backgroundImageUrl;
  final Widget child;
  final Color? overlayColor;
  final double overlayOpacity;

  const BackgroundContainer({
    super.key,
    this.backgroundImageUrl,
    required this.child,
    this.overlayColor,
    this.overlayOpacity = 0.3,
  });

  @override
  Widget build(BuildContext context) {
    if (backgroundImageUrl == null || backgroundImageUrl!.isEmpty) {
      return child;
    }

    return Stack(
      children: [
        // Background image
        Positioned.fill(child: _buildBackgroundImage()),
        // Overlay for better readability
        if (overlayColor != null)
          Positioned.fill(
            child: Container(
              color: overlayColor!.withOpacity(overlayOpacity),
            ),
          ),
        // Content
        child,
      ],
    );
  }

  Widget _buildBackgroundImage() {
    // Check if it's a default background (asset image)
    if (BackgroundImageService.isDefaultBackground(backgroundImageUrl)) {
      return Image.asset(
        backgroundImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox.shrink();
        },
      );
    }

    // Check if it's a local file
    if (BackgroundImageService.isLocalFile(backgroundImageUrl)) {
      return Image.file(
        File(backgroundImageUrl!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox.shrink();
        },
      );
    }

    // Otherwise, load from network
    return Image.network(
      backgroundImageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const SizedBox.shrink();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
