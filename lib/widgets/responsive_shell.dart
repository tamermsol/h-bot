import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Layout helpers for responsive design
class HBotLayout {
  /// Tablet breakpoint: ≥ 600px
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600;

  /// Large tablet (landscape): ≥ 900px
  static bool isLargeTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  /// Max content width on tablet
  static const double contentMaxWidth = 500;

  /// Screen horizontal padding — larger on tablet
  static EdgeInsets screenPadding(BuildContext context) => EdgeInsets.symmetric(
        horizontal: isTablet(context) ? HBotSpacing.space6 : HBotSpacing.space5,
      );

  /// Device grid column count
  static int deviceGridColumns(BuildContext context) {
    if (isLargeTablet(context)) return 3;
    return 2;
  }

  /// Grid cross-axis spacing
  static double gridSpacing(BuildContext context) =>
      isTablet(context) ? HBotSpacing.space4 : HBotSpacing.space3;
}

/// Wraps content in a centered constrained container on tablet
/// On phone, passes through unchanged
class ResponsiveShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveShell({
    super.key,
    required this.child,
    this.maxWidth = HBotLayout.contentMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (!HBotLayout.isTablet(context)) return child;

    return Container(
      color: context.hBackground,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Wraps a Scaffold body in ResponsiveShell while keeping
/// the scaffold background consistent
class ResponsiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;

  const ResponsiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = HBotLayout.isTablet(context);

    return Scaffold(
      backgroundColor: backgroundColor ?? context.hBackground,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      body: isTablet
          ? Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: HBotLayout.contentMaxWidth),
                child: body,
              ),
            )
          : body,
      bottomNavigationBar: isTablet && bottomNavigationBar != null
          ? Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: HBotLayout.contentMaxWidth),
                child: bottomNavigationBar,
              ),
            )
          : bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}
