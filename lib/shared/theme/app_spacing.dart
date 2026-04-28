import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mezaan/shared/theme/responsive_profile.dart';

/// Professional modular spacing system following Material Design 3
/// Scales proportionally with screen size and device profile
///
/// Usage:
/// ```dart
/// // Using predefined scales
/// padding: EdgeInsets.all(AppSpacing.md_compact);
///
/// // Using adaptive helper
/// spacing: AppSpacing.adaptive(context, xs: 8, sm: 12, md: 16),
///
/// // Using predefined adaptive padding
/// padding: AppSpacing.screenPadding(context),
/// ```
class AppSpacing {
  const AppSpacing._();

  // ============================================
  // COMPACT SCALE (Phones: < 600px width)
  // ============================================
  /// Extra small: 4dp - Use for very tight spacing between related elements
  static double xs = 4.w;

  /// Small: 8dp - Use for spacing between compact groups
  static double sm = 8.w;

  /// Medium: 12dp - Use for general section spacing
  static double md = 12.w;

  /// Large: 16dp - Use for between major sections
  static double lg = 16.w;

  /// Extra large: 24dp - Use for large gaps
  static double xl = 24.w;

  /// Extra extra large: 32dp - Use for screen top/bottom padding
  static double xxl = 32.w;

  // ============================================
  // RESPONSIVE HELPERS
  // ============================================

  /// Adaptive spacing that responds to device profile
  ///
  /// Example:
  /// ```dart
  /// SizedBox(
  ///   height: AppSpacing.adaptive(
  ///     context,
  ///     xs: 8,    // 8dp on compact phones
  ///     sm: 12,   // 12dp on regular phones
  ///     md: 16,   // 16dp on tablets
  ///   ),
  /// )
  /// ```
  static double adaptive(
    BuildContext context, {
    required double xs,
    required double sm,
    required double md,
  }) {
    final profile = context.deviceProfile;

    switch (profile) {
      case DeviceProfile.compactPhone:
        return xs.w;
      case DeviceProfile.phone:
        return sm.w;
      case DeviceProfile.tablet:
        return md.w;
      case DeviceProfile.desktop:
        return md.w; // Desktop uses tablet scale (capped)
    }
  }

  /// Screen-level padding that adapts to device profile
  /// Use this for the main padding of full-screen layouts
  ///
  /// Returns:
  /// - compactPhone: 12.w horizontal, 8.h vertical
  /// - phone: 16.w horizontal, 12.h vertical
  /// - tablet: 24.w horizontal, 16.h vertical
  /// - desktop: 32.w horizontal, 20.h vertical
  static EdgeInsets screenPadding(BuildContext context) {
    final profile = context.deviceProfile;

    switch (profile) {
      case DeviceProfile.compactPhone:
        return EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h);
      case DeviceProfile.phone:
        return EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h);
      case DeviceProfile.tablet:
        return EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h);
      case DeviceProfile.desktop:
        return EdgeInsets.symmetric(horizontal: 32.w, vertical: 20.h);
    }
  }

  /// Card/Container padding - consistent padding for card-like elements
  ///
  /// Returns:
  /// - compactPhone: 12.w on all sides
  /// - phone: 16.w on all sides
  /// - tablet: 20.w on all sides
  /// - desktop: 24.w on all sides
  static EdgeInsets cardPadding(BuildContext context) {
    final profile = context.deviceProfile;

    switch (profile) {
      case DeviceProfile.compactPhone:
        return EdgeInsets.all(12.w);
      case DeviceProfile.phone:
        return EdgeInsets.all(16.w);
      case DeviceProfile.tablet:
        return EdgeInsets.all(20.w);
      case DeviceProfile.desktop:
        return EdgeInsets.all(24.w);
    }
  }

  /// Horizontal padding - for horizontal spacing
  static double horizontalPadding(BuildContext context) {
    return AppSpacing.screenPadding(context).left;
  }

  /// Vertical padding - for vertical spacing
  static double verticalPadding(BuildContext context) {
    return AppSpacing.screenPadding(context).top;
  }

  /// Input field padding - proper padding for TextField and form elements
  static EdgeInsets inputPadding(BuildContext context) {
    final profile = context.deviceProfile;

    switch (profile) {
      case DeviceProfile.compactPhone:
        return EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h);
      case DeviceProfile.phone:
        return EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h);
      case DeviceProfile.tablet:
        return EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h);
      case DeviceProfile.desktop:
        return EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h);
    }
  }

  /// Button padding - proper padding for button content
  static EdgeInsets buttonPadding(BuildContext context) {
    final profile = context.deviceProfile;

    switch (profile) {
      case DeviceProfile.compactPhone:
        return EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h);
      case DeviceProfile.phone:
        return EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h);
      case DeviceProfile.tablet:
        return EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h);
      case DeviceProfile.desktop:
        return EdgeInsets.symmetric(horizontal: 28.w, vertical: 14.h);
    }
  }

  /// List item padding - padding for items in a ListView/GridView
  static EdgeInsets listItemPadding(BuildContext context) {
    final profile = context.deviceProfile;

    switch (profile) {
      case DeviceProfile.compactPhone:
        return EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h);
      case DeviceProfile.phone:
        return EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h);
      case DeviceProfile.tablet:
        return EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h);
      case DeviceProfile.desktop:
        return EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h);
    }
  }

  // ============================================
  // TOUCH TARGET SPECIFICATIONS
  // ============================================

  /// Minimum touch target size according to Material Design 3
  /// Should be used for all interactive elements
  static double touchTargetSize(BuildContext context) {
    return 48.h; // 48 x 48 dp is material standard
  }

  /// Minimum spacing between interactive elements
  /// Prevents accidental taps on adjacent targets
  static double touchTargetSpacing = 8.w;
}
