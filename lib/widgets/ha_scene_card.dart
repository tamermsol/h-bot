import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/ha_entity.dart';

/// Compact card for activating an HA scene with a single tap.
/// Shows scene name with a play icon and a brief activation animation.
class HaSceneCard extends StatefulWidget {
  final HaEntity scene;
  final VoidCallback onActivate;

  const HaSceneCard({
    super.key,
    required this.scene,
    required this.onActivate,
  });

  @override
  State<HaSceneCard> createState() => _HaSceneCardState();
}

class _HaSceneCardState extends State<HaSceneCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  bool _activating = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.92), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_activating) return;
    setState(() => _activating = true);
    HapticFeedback.mediumImpact();
    _animController.forward(from: 0);
    widget.onActivate();
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _activating = false);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          width: 130,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: context.hSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _activating
                  ? AppTheme.primaryColor.withOpacity(0.5)
                  : context.hBorder,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.palette,
                    size: 20,
                    color: _activating
                        ? AppTheme.primaryColor
                        : Colors.grey,
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _activating
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryColor,
                            ),
                          )
                        : Icon(
                            Icons.play_circle_filled,
                            size: 20,
                            color: AppTheme.primaryColor.withOpacity(0.7),
                          ),
                  ),
                ],
              ),
              Text(
                widget.scene.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.hTextPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
