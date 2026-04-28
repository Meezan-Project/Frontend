import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/responsive_profile.dart';

/// Professional typography scaling system
///
/// Ensures readable, proportional text across all device profiles.
/// Uses EB Garamond for headings (legal, trustworthy)
/// and Lato for body text (readable, modern)
///
/// All text sizes are responsive using `flutter_screenutil.sp`
///
/// Usage:
/// ```dart
/// Text('Heading', style: AppTypography.headline2(context))
/// Text('Body text', style: AppTypography.bodyLarge(context))
/// ```
class AppTypography {
  const AppTypography._();

  // ============================================
  // DISPLAY / HEADLINE STYLES (EB GARAMOND)
  // ============================================

  /// Extra large heading - Page titles, modal titles
  /// Font: EB Garamond Bold
  /// Device Sizes: 28-40 sp
  /// Line Height: 1.2 (tight)
  static TextStyle headline1(BuildContext context) {
    final profile = context.deviceProfile;
    final baseSize = switch (profile) {
      DeviceProfile.compactPhone => 28.0,
      DeviceProfile.phone => 32.0,
      DeviceProfile.tablet => 36.0,
      DeviceProfile.desktop => 40.0,
    };

    return GoogleFonts.ebGaramond(
      fontSize: baseSize.sp,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: Colors.black87,
    );
  }

  /// Large heading - Section titles, card headers
  /// Font: EB Garamond SemiBold
  /// Device Sizes: 24-36 sp
  /// Line Height: 1.3
  static TextStyle headline2(BuildContext context) {
    final profile = context.deviceProfile;
    final baseSize = switch (profile) {
      DeviceProfile.compactPhone => 24.0,
      DeviceProfile.phone => 28.0,
      DeviceProfile.tablet => 32.0,
      DeviceProfile.desktop => 36.0,
    };

    return GoogleFonts.ebGaramond(
      fontSize: baseSize.sp,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: Colors.black87,
    );
  }

  /// Medium heading - Subsection titles, form labels
  /// Font: EB Garamond SemiBold
  /// Device Sizes: 20-32 sp
  /// Line Height: 1.35
  static TextStyle headline3(BuildContext context) {
    final profile = context.deviceProfile;
    final baseSize = switch (profile) {
      DeviceProfile.compactPhone => 20.0,
      DeviceProfile.phone => 24.0,
      DeviceProfile.tablet => 28.0,
      DeviceProfile.desktop => 32.0,
    };

    return GoogleFonts.ebGaramond(
      fontSize: baseSize.sp,
      fontWeight: FontWeight.w600,
      height: 1.35,
      color: Colors.black87,
    );
  }

  /// Small heading - Widget titles
  /// Font: EB Garamond Medium
  /// Device Sizes: 18-26 sp
  /// Line Height: 1.4
  static TextStyle headline4(BuildContext context) {
    final profile = context.deviceProfile;
    final baseSize = switch (profile) {
      DeviceProfile.compactPhone => 18.0,
      DeviceProfile.phone => 20.0,
      DeviceProfile.tablet => 24.0,
      DeviceProfile.desktop => 26.0,
    };

    return GoogleFonts.ebGaramond(
      fontSize: baseSize.sp,
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: Colors.black87,
    );
  }

  // ============================================
  // BODY STYLES (LATO)
  // ============================================

  /// Large body text - Long-form content, descriptions
  /// Font: Lato Regular
  /// Device Sizes: 14-18 sp
  /// Line Height: 1.5 (readable)
  /// Letter Spacing: 0.5
  static TextStyle bodyLarge(BuildContext context) {
    final profile = context.deviceProfile;
    final baseSize = switch (profile) {
      DeviceProfile.compactPhone => 14.0,
      DeviceProfile.phone => 16.0,
      DeviceProfile.tablet => 17.0,
      DeviceProfile.desktop => 18.0,
    };

    return GoogleFonts.lato(
      fontSize: baseSize.sp,
      fontWeight: FontWeight.w400,
      height: 1.5,
      letterSpacing: 0.5,
      color: Colors.black87,
    );
  }

  /// Medium body text - Default text throughout the app
  /// Font: Lato Regular
  /// Device Sizes: 13-16 sp
  /// Line Height: 1.5
  static TextStyle bodyMedium(BuildContext context) {
    final profile = context.deviceProfile;
    final baseSize = switch (profile) {
      DeviceProfile.compactPhone => 13.0,
      DeviceProfile.phone => 14.0,
      DeviceProfile.tablet => 15.0,
      DeviceProfile.desktop => 16.0,
    };

    return GoogleFonts.lato(
      fontSize: baseSize.sp,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: Colors.black87,
    );
  }

  /// Small body text - Secondary text, smaller descriptions
  /// Font: Lato Regular
  /// Device Sizes: 12-15 sp
  /// Line Height: 1.5
  static TextStyle bodySmall(BuildContext context) {
    final profile = context.deviceProfile;
    final baseSize = switch (profile) {
      DeviceProfile.compactPhone => 12.0,
      DeviceProfile.phone => 13.0,
      DeviceProfile.tablet => 14.0,
      DeviceProfile.desktop => 15.0,
    };

    return GoogleFonts.lato(
      fontSize: baseSize.sp,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: Colors.black87,
    );
  }

  // ============================================
  // LABEL & CAPTION STYLES
  // ============================================

  /// Caption text - Hints, meta information, timestamps
  /// Font: Lato Regular
  /// Device Sizes: 11-14 sp
  /// Line Height: 1.4
  /// Color: Muted gray
  static TextStyle caption(BuildContext context) {
    final profile = context.deviceProfile;
    final baseSize = switch (profile) {
      DeviceProfile.compactPhone => 11.0,
      DeviceProfile.phone => 12.0,
      DeviceProfile.tablet => 13.0,
      DeviceProfile.desktop => 14.0,
    };

    return GoogleFonts.lato(
      fontSize: baseSize.sp,
      fontWeight: FontWeight.w400,
      color: Colors.grey[600],
      height: 1.4,
    );
  }

  /// Overline text - Labels, category tags
  /// Font: Lato Bold
  /// Device Sizes: 10-12 sp
  /// Letter Spacing: 1.5
  /// Transform: Uppercase (apply manually with .toUpperCase())
  static TextStyle overline(BuildContext context) {
    final profile = context.deviceProfile;
    final baseSize = switch (profile) {
      DeviceProfile.compactPhone => 10.0,
      DeviceProfile.phone => 11.0,
      DeviceProfile.tablet => 12.0,
      DeviceProfile.desktop => 13.0,
    };

    return GoogleFonts.lato(
      fontSize: baseSize.sp,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
      color: Colors.black87,
      height: 1.3,
    );
  }

  // ============================================
  // INTERACTIVE STYLES
  // ============================================

  /// Button text - Interactive element labels
  /// Font: Lato Bold
  /// Device Sizes: 13-16 sp
  /// Letter Spacing: 0.5
  /// Usually white or contrasting color
  static TextStyle buttonText(BuildContext context) {
    final profile = context.deviceProfile;
    final baseSize = switch (profile) {
      DeviceProfile.compactPhone => 13.0,
      DeviceProfile.phone => 14.0,
      DeviceProfile.tablet => 15.0,
      DeviceProfile.desktop => 16.0,
    };

    return GoogleFonts.lato(
      fontSize: baseSize.sp,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );
  }

  /// Link text - Clickable inline text
  /// Font: Lato SemiBold
  /// Includes text decoration and color
  static TextStyle linkText(BuildContext context, {Color? color}) {
    final profile = context.deviceProfile;
    final baseSize = switch (profile) {
      DeviceProfile.compactPhone => 13.0,
      DeviceProfile.phone => 14.0,
      DeviceProfile.tablet => 15.0,
      DeviceProfile.desktop => 16.0,
    };

    return GoogleFonts.lato(
      fontSize: baseSize.sp,
      fontWeight: FontWeight.w600,
      color: color ?? Colors.blue,
      decoration: TextDecoration.underline,
      height: 1.5,
    );
  }

  /// Form input text - Text inside TextFields
  /// Font: Lato Regular
  /// Device Sizes: 14-16 sp
  static TextStyle inputText(BuildContext context) {
    final profile = context.deviceProfile;
    final baseSize = switch (profile) {
      DeviceProfile.compactPhone => 14.0,
      DeviceProfile.phone => 15.0,
      DeviceProfile.tablet => 16.0,
      DeviceProfile.desktop => 17.0,
    };

    return GoogleFonts.lato(
      fontSize: baseSize.sp,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: Colors.black87,
    );
  }

  /// Form label text - Labels above input fields
  /// Font: Lato Medium
  /// Device Sizes: 12-14 sp
  static TextStyle inputLabel(BuildContext context) {
    final profile = context.deviceProfile;
    final baseSize = switch (profile) {
      DeviceProfile.compactPhone => 12.0,
      DeviceProfile.phone => 13.0,
      DeviceProfile.tablet => 14.0,
      DeviceProfile.desktop => 15.0,
    };

    return GoogleFonts.lato(
      fontSize: baseSize.sp,
      fontWeight: FontWeight.w500,
      color: Colors.black87,
      height: 1.4,
    );
  }

  // ============================================
  // SPECIAL STYLES
  // ============================================

  /// Code/Monospace text - For displaying code, logs, or monospace content
  /// Font: Courier Prime (monospace)
  /// Device Sizes: 12-14 sp
  static TextStyle monoText(BuildContext context) {
    final profile = context.deviceProfile;
    final baseSize = switch (profile) {
      DeviceProfile.compactPhone => 12.0,
      DeviceProfile.phone => 13.0,
      DeviceProfile.tablet => 14.0,
      DeviceProfile.desktop => 15.0,
    };

    return GoogleFonts.courierPrime(
      fontSize: baseSize.sp,
      fontWeight: FontWeight.w400,
      color: Colors.black87,
      height: 1.4,
    );
  }

  /// Error text - Error messages and validation feedback
  /// Font: Lato Regular
  /// Color: Error red
  static TextStyle errorText(BuildContext context) {
    return bodySmall(
      context,
    ).copyWith(color: Colors.red[600], fontWeight: FontWeight.w500);
  }

  /// Success text - Success messages and positive feedback
  /// Font: Lato Regular
  /// Color: Success green
  static TextStyle successText(BuildContext context) {
    return bodySmall(
      context,
    ).copyWith(color: Colors.green[600], fontWeight: FontWeight.w500);
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Create a custom text style with automatic scaling
  /// Useful for one-off text styles that need to scale
  static TextStyle custom({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color color = Colors.black87,
    double lineHeight = 1.5,
    double letterSpacing = 0,
    TextDecoration decoration = TextDecoration.none,
    TextDecorationStyle decorationStyle = TextDecorationStyle.solid,
  }) {
    return TextStyle(
      fontSize: fontSize.sp,
      fontWeight: fontWeight,
      color: color,
      height: lineHeight,
      letterSpacing: letterSpacing,
      decoration: decoration,
      decorationStyle: decorationStyle,
    );
  }
}
