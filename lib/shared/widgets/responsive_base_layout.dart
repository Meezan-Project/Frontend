import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mezaan/shared/theme/app_spacing.dart';
import 'package:mezaan/shared/theme/responsive_profile.dart';

/// Foundation widget for all responsive screens
///
/// This widget handles:
/// - Responsive padding based on device profile
/// - Max-width constraints for tablets/desktop (prevents gigantic UI)
/// - Proper SafeArea handling
/// - Consistent layout structure
///
/// Usage:
/// ```dart
/// ResponsiveBaseLayout(
///   title: 'My Screen',
///   child: Column(
///     children: [
///       Text('Content'),
///     ],
///   ),
/// )
/// ```
class ResponsiveBaseLayout extends StatelessWidget {
  /// Main content widget - required
  final Widget child;

  /// Optional AppBar title - creates default AppBar if provided
  final String? title;

  /// Whether to show an AppBar (uses title or custom appBar)
  final bool showAppBar;

  /// Custom AppBar - overrides default title-based AppBar
  final PreferredSizeWidget? appBar;

  /// Floating action button
  final Widget? floatingActionButton;

  /// Custom padding - overrides default responsive padding
  final EdgeInsetsGeometry? customPadding;

  /// Background color of the scaffold
  final Color? backgroundColor;

  /// Whether to use SafeArea (usually true for mobile)
  final bool useSafeArea;

  /// Whether to make content scrollable
  /// If true, wraps child in SingleChildScrollView
  final bool scrollable;

  /// Custom scroll physics
  final ScrollPhysics? scrollPhysics;

  /// Resizeble bottom insets
  /// Set to false if your keyboard should overlap the content
  final bool resizeToAvoidBottomInset;

  const ResponsiveBaseLayout({
    super.key,
    required this.child,
    this.title,
    this.showAppBar = true,
    this.appBar,
    this.floatingActionButton,
    this.customPadding,
    this.backgroundColor,
    this.useSafeArea = true,
    this.scrollable = true,
    this.scrollPhysics,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    final padding = customPadding ?? AppSpacing.screenPadding(context);

    return Scaffold(
      backgroundColor: backgroundColor ?? Colors.white,
      appBar: showAppBar
          ? appBar ??
                AppBar(
                  title: title != null ? Text(title!) : null,
                  centerTitle: true,
                  elevation: 0,
                )
          : null,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: useSafeArea
          ? SafeArea(child: _buildContent(context, padding))
          : _buildContent(context, padding),
    );
  }

  Widget _buildContent(BuildContext context, EdgeInsetsGeometry padding) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Detect if we should apply max-width constraint
    final shouldConstrain = screenWidth > 768;
    final maxWidth = switch (screenWidth) {
      > 1024 => 1024.0, // Desktop
      > 768 => 768.0, // Tablet landscape
      _ => double.infinity, // Phone
    };

    Widget content = scrollable
        ? SingleChildScrollView(
            physics: scrollPhysics ?? const ClampingScrollPhysics(),
            padding: padding,
            child: child,
          )
        : Padding(padding: padding, child: child);

    // Apply max-width constraint if needed
    if (shouldConstrain) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// Responsive grid layout widget
///
/// Automatically adapts column count based on screen size
///
/// Usage:
/// ```dart
/// ResponsiveGridLayout(
///   children: [
///     Text('Card 1'),
///     Text('Card 2'),
///     Text('Card 3'),
///   ],
/// )
/// ```
class ResponsiveGridLayout extends StatelessWidget {
  /// Child widgets to display in grid
  final List<Widget> children;

  /// Custom cross axis count - overrides default adaptive behavior
  final int? crossAxisCount;

  /// Spacing between items
  final double? mainAxisSpacing;
  final double? crossAxisSpacing;

  /// Aspect ratio of grid items
  final double childAspectRatio;

  /// Whether the grid is shrinkwrapped (non-scrollable)
  final bool shrinkWrap;

  /// Scroll physics if not shrinkwrapped
  final ScrollPhysics? scrollPhysics;

  const ResponsiveGridLayout({
    super.key,
    required this.children,
    this.crossAxisCount,
    this.mainAxisSpacing,
    this.crossAxisSpacing,
    this.childAspectRatio = 1.0,
    this.shrinkWrap = true,
    this.scrollPhysics,
  });

  @override
  Widget build(BuildContext context) {
    final profile = context.deviceProfile;

    // Adaptive column count
    final colCount =
        crossAxisCount ??
        switch (profile) {
          DeviceProfile.compactPhone => 1,
          DeviceProfile.phone => 1,
          DeviceProfile.tablet => 2,
          DeviceProfile.desktop => 3,
        };

    // Adaptive spacing
    final mainSpacing =
        mainAxisSpacing ?? AppSpacing.adaptive(context, xs: 12, sm: 12, md: 16);

    final crossSpacing =
        crossAxisSpacing ??
        AppSpacing.adaptive(context, xs: 12, sm: 12, md: 16);

    return GridView.count(
      crossAxisCount: colCount,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : scrollPhysics,
      mainAxisSpacing: mainSpacing,
      crossAxisSpacing: crossSpacing,
      childAspectRatio: childAspectRatio,
      children: children,
    );
  }
}

/// Responsive row layout that wraps on smaller screens
///
/// Automatically stacks items vertically on phones
/// and horizontally on tablets
///
/// Usage:
/// ```dart
/// ResponsiveRowLayout(
///   children: [
///     Button(label: 'Save'),
///     Button(label: 'Cancel'),
///   ],
/// )
/// ```
class ResponsiveRowLayout extends StatelessWidget {
  /// Child widgets
  final List<Widget> children;

  /// Spacing between items
  final double spacing;

  /// Run spacing (vertical space when wrapped)
  final double runSpacing;

  /// Alignment of children
  final WrapAlignment alignment;

  /// Run alignment (affects how wrapped items are aligned)
  final WrapAlignment runAlignment;

  /// Cross axis alignment
  final WrapCrossAlignment crossAxisAlignment;

  const ResponsiveRowLayout({
    super.key,
    required this.children,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
    this.alignment = WrapAlignment.start,
    this.runAlignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      runAlignment: runAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }
}

/// Responsive card widget with adaptive padding and shadows
///
/// Handles responsive styling for card-like containers
///
/// Usage:
/// ```dart
/// ResponsiveCard(
///   title: 'Card Title',
///   child: Text('Card content'),
/// )
/// ```
class ResponsiveCard extends StatelessWidget {
  /// Main content of the card
  final Widget child;

  /// Optional title displayed at top of card
  final String? title;

  /// Custom padding - uses AppSpacing.cardPadding if null
  final EdgeInsetsGeometry? padding;

  /// Background color
  final Color? backgroundColor;

  /// Border color
  final Color? borderColor;

  /// Border radius
  final double borderRadius;

  /// Whether to show shadow
  final bool showShadow;

  /// Shadow elevation
  final double elevation;

  /// On tap callback
  final VoidCallback? onTap;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.title,
    this.padding,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 12,
    this.showShadow = true,
    this.elevation = 1,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardPadding = padding ?? AppSpacing.cardPadding(context);
    final bgColor = backgroundColor ?? Colors.white;
    final borderCol = borderColor ?? Colors.grey[200]!;

    Widget cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!, style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 12.h),
        ],
        child,
      ],
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius.r),
          border: Border.all(color: borderCol),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05 * elevation),
                    blurRadius: 8.r * elevation,
                    offset: Offset(0, 2 * elevation),
                  ),
                ]
              : [],
        ),
        padding: cardPadding,
        child: cardContent,
      ),
    );
  }
}

/// Responsive section divider with optional title
///
/// Usage:
/// ```dart
/// ResponsiveSectionDivider(title: 'Section Title')
/// ```
class ResponsiveSectionDivider extends StatelessWidget {
  final String? title;
  final double height;
  final Color? color;
  final EdgeInsetsGeometry? margin;

  const ResponsiveSectionDivider({
    super.key,
    this.title,
    this.height = 1,
    this.color,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = color ?? Colors.grey[300]!;
    final dividerMargin = margin ?? EdgeInsets.symmetric(vertical: 16.h);

    if (title == null) {
      return Padding(
        padding: dividerMargin,
        child: Divider(height: height, color: dividerColor),
      );
    }

    return Padding(
      padding: dividerMargin,
      child: Row(
        children: [
          Expanded(
            child: Divider(height: height, color: dividerColor),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Text(title!, style: Theme.of(context).textTheme.labelSmall),
          ),
          Expanded(
            child: Divider(height: height, color: dividerColor),
          ),
        ],
      ),
    );
  }
}

/// Responsive spacing widget
///
/// Usage:
/// ```dart
/// ResponsiveSpacing.md() // Uses AppSpacing.md
/// ResponsiveSpacing.xs()
/// ResponsiveSpacing.sm()
/// ```
class ResponsiveSpacing extends SizedBox {
  const ResponsiveSpacing.custom({
    super.key,
    required double size,
    bool vertical = true,
  }) : super(height: vertical ? size : 0, width: vertical ? 0 : size);

  factory ResponsiveSpacing.xs({Key? key, bool vertical = true}) {
    return ResponsiveSpacing.custom(key: key, size: 4.0, vertical: vertical);
  }

  factory ResponsiveSpacing.sm({Key? key, bool vertical = true}) {
    return ResponsiveSpacing.custom(key: key, size: 8.0, vertical: vertical);
  }

  factory ResponsiveSpacing.md({Key? key, bool vertical = true}) {
    return ResponsiveSpacing.custom(key: key, size: 12.0, vertical: vertical);
  }

  factory ResponsiveSpacing.lg({Key? key, bool vertical = true}) {
    return ResponsiveSpacing.custom(key: key, size: 16.0, vertical: vertical);
  }

  factory ResponsiveSpacing.xl({Key? key, bool vertical = true}) {
    return ResponsiveSpacing.custom(key: key, size: 24.0, vertical: vertical);
  }

  factory ResponsiveSpacing.xxl({Key? key, bool vertical = true}) {
    return ResponsiveSpacing.custom(key: key, size: 32.0, vertical: vertical);
  }
}
