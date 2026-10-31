import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Screen breakpoint categories
enum ScreenDeviceType {
  compact, // Small phones (< 360dp width)
  phone, // Standard phones (360dp - 599dp width)
  foldable, // Foldable / phablet unfolded (600dp - 839dp)
  tablet, // Tablets / desktop screens (>= 840dp)
}

/// Helper extension on [BuildContext] for responsive layout design.
extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;
  EdgeInsets get screenPadding => MediaQuery.paddingOf(this);
  EdgeInsets get screenViewInsets => MediaQuery.viewInsetsOf(this);
  Orientation get orientation => MediaQuery.orientationOf(this);
  bool get isLandscape => orientation == Orientation.landscape;

  ScreenDeviceType get deviceType {
    final width = screenWidth;
    if (width < 360) return ScreenDeviceType.compact;
    if (width < 600) return ScreenDeviceType.phone;
    if (width < 840) return ScreenDeviceType.foldable;
    return ScreenDeviceType.tablet;
  }

  bool get isTabletOrWider =>
      deviceType == ScreenDeviceType.foldable ||
      deviceType == ScreenDeviceType.tablet;

  /// Clamps a proportional dimension between a minimum and maximum pixel constraint.
  double clampWidth(double factor, {double min = 0.0, double max = double.infinity}) {
    return (screenWidth * factor).clamp(min, max);
  }

  /// Clamps a proportional height.
  double clampHeight(double factor, {double min = 0.0, double max = double.infinity}) {
    return (screenHeight * factor).clamp(min, max);
  }

  /// Responsive font sizing with bounds to avoid unreadable text or pixel overflow.
  double responsiveFontSize(double baseSize) {
    final scaleFactor = (screenWidth / 390.0).clamp(0.85, 1.25);
    return (baseSize * scaleFactor).roundToDouble();
  }

  /// Dynamic horizontal margin based on screen width
  double get horizontalMargin {
    switch (deviceType) {
      case ScreenDeviceType.compact:
        return 12.0;
      case ScreenDeviceType.phone:
        return 16.0;
      case ScreenDeviceType.foldable:
        return 24.0;
      case ScreenDeviceType.tablet:
        return math.max(32.0, (screenWidth - 720.0) / 2.0);
    }
  }

  /// Max content width for readable forms and tables on tablets/foldables
  double get maxContentWidth => 720.0;
}

/// A container that constrains content to a comfortable reading width on tablets & desktop
class ResponsiveContentContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContentContainer({
    super.key,
    required this.child,
    this.maxWidth = 720.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.symmetric(horizontal: context.horizontalMargin),
          child: child,
        ),
      ),
    );
  }
}

