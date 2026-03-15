import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Wizard step indicator — dots connected by lines
/// Design: 03-COMPONENT-LIBRARY.md §11.1
class StepIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep; // 0-based index

  const StepIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space7),
      child: Row(
        children: List.generate(totalSteps * 2 - 1, (i) {
          if (i.isOdd) {
            // Line between dots
            final stepBefore = i ~/ 2;
            final isComplete = stepBefore < currentStep;
            return Expanded(
              child: Container(
                height: 2,
                color: isComplete ? HBotColors.primary : HBotColors.neutral300,
              ),
            );
          } else {
            // Dot
            final step = i ~/ 2;
            final isComplete = step < currentStep;
            final isCurrent = step == currentStep;
            final dotSize = isCurrent ? 12.0 : 10.0;

            return Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: (isComplete || isCurrent)
                    ? HBotColors.primary
                    : HBotColors.neutral300,
                shape: BoxShape.circle,
                boxShadow: isCurrent ? HBotShadows.glow : null,
              ),
            );
          }
        }),
      ),
    );
  }
}
