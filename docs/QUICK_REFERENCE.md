# Quick Reference: Responsive Design Classes

## Import These in Your Screens

```dart
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mezaan/shared/theme/app_spacing.dart';
import 'package:mezaan/shared/theme/app_typography.dart';
import 'package:mezaan/shared/widgets/responsive_base_layout.dart';
import 'package:mezaan/shared/theme/responsive_profile.dart';
```

---

## AppSpacing - Modular Spacing System

### Basic Spacing (Same on all devices, uses .w for width-relative scaling)
```dart
AppSpacing.xs    // 4.w
AppSpacing.sm    // 8.w
AppSpacing.md    // 12.w (most common)
AppSpacing.lg    // 16.w
AppSpacing.xl    // 24.w
AppSpacing.xxl   // 32.w
```

### Common Usage Patterns
```dart
// Spacing between widgets
SizedBox(height: AppSpacing.md.h)
SizedBox(width: AppSpacing.lg.w)

// Padding
Padding(padding: AppSpacing.screenPadding(context))
Container(padding: AppSpacing.cardPadding(context))
TextField(
  decoration: InputDecoration(
    contentPadding: AppSpacing.inputPadding(context),
  ),
)

// Adaptive spacing (changes with device profile)
SizedBox(
  height: AppSpacing.adaptive(
    context,
    xs: 8,   // compact phones
    sm: 12,  // regular phones
    md: 16,  // tablets
  ),
)

// Touch target sizing (Material Design: 48×48 dp)
SizedBox(
  height: AppSpacing.touchTargetSize(context),
  width: double.infinity,
  child: ElevatedButton(...)
)
```

---

## AppTypography - Responsive Text Styles

### Headings (EB Garamond - Legal, Trustworthy)
```dart
Text('Page Title', style: AppTypography.headline1(context))
Text('Section Title', style: AppTypography.headline2(context))
Text('Subsection', style: AppTypography.headline3(context))
Text('Widget Title', style: AppTypography.headline4(context))
```

### Body Text (Lato - Readable, Modern)
```dart
Text('Long paragraph...', style: AppTypography.bodyLarge(context))
Text('Normal body text', style: AppTypography.bodyMedium(context))
Text('Smaller text', style: AppTypography.bodySmall(context))
```

### Special Text
```dart
Text('Hint text', style: AppTypography.caption(context))
Text('LABEL', style: AppTypography.overline(context))
Text('Click here', style: AppTypography.linkText(context))
Text('Error!', style: AppTypography.errorText(context))
Text('Success!', style: AppTypography.successText(context))
Text('Code', style: AppTypography.monoText(context))
```

### Button Labels
```dart
ElevatedButton(
  child: Text('Save', style: AppTypography.buttonText(context)),
)
```

---

## ResponsiveBaseLayout - Foundation Widget

### Simple Usage
```dart
ResponsiveBaseLayout(
  title: 'My Screen',
  child: Column(children: [...]),
)
```

### With Custom Options
```dart
ResponsiveBaseLayout(
  title: 'Payment Methods',
  backgroundColor: Colors.grey[50],
  customPadding: EdgeInsets.all(20.w),
  scrollable: true,
  useSafeArea: true,
  showAppBar: true,
  floatingActionButton: FloatingActionButton(...),
  child: Column(
    children: [
      Text('Content'),
    ],
  ),
)
```

---

## Other Responsive Widgets

### ResponsiveGridLayout - Auto-adapting grid
```dart
ResponsiveGridLayout(
  crossAxisCount: 2, // Optional - auto-adapts if not specified
  children: [
    Card1(),
    Card2(),
    Card3(),
  ],
)
// Results:
// Compact phone: 1 column
// Phone: 1 column
// Tablet: 2 columns
// Desktop: 3 columns
```

### ResponsiveRowLayout - Wrapping row
```dart
ResponsiveRowLayout(
  spacing: AppSpacing.md.w,
  children: [
    ElevatedButton(child: Text('Save')),
    TextButton(child: Text('Cancel')),
  ],
)
```

### ResponsiveCard - Adaptive card container
```dart
ResponsiveCard(
  title: 'Card Title',
  onTap: () {},
  child: Text('Card content'),
)
```

### ResponsiveSpacing - Convenience spacing
```dart
ResponsiveSpacing.xs()        // Extra small spacing
ResponsiveSpacing.sm()        // Small
ResponsiveSpacing.md()        // Medium (default)
ResponsiveSpacing.lg()        // Large
ResponsiveSpacing.xl()        // Extra large
ResponsiveSpacing.xxl()       // Extra extra large

// Horizontal vs vertical
ResponsiveSpacing.md(vertical: false) // Horizontal spacing
```

### ResponsiveSectionDivider - Section separator
```dart
ResponsiveSectionDivider()  // Simple line
ResponsiveSectionDivider(title: 'Section Name')  // With title
```

---

## Device Profile Detection

### Checking Device Profile
```dart
final profile = context.deviceProfile;

// Or use convenience getters:
context.isCompactPhone  // < 360px
context.isPhone         // 360-600px
context.isTablet        // 600-1024px
context.isDesktop       // > 1024px
```

### Conditional Rendering
```dart
Widget _buildContent(BuildContext context) {
  final profile = context.deviceProfile;
  
  return switch (profile) {
    DeviceProfile.compactPhone => _buildCompactLayout(),
    DeviceProfile.phone => _buildPhoneLayout(),
    DeviceProfile.tablet => _buildTabletLayout(),
    DeviceProfile.desktop => _buildDesktopLayout(),
  };
}
```

### Adaptive Grid Columns
```dart
final colCount = switch (context.deviceProfile) {
  DeviceProfile.compactPhone => 1,
  DeviceProfile.phone => 1,
  DeviceProfile.tablet => 2,
  DeviceProfile.desktop => 3,
};
```

---

## ScreenUtil Extensions Quick Reference

### Size Scaling (.w, .h, .sp, .r)
```dart
// Width scaling (based on design width 375)
Container(width: 100.w)  // Scales with screen width

// Height scaling (based on design height 812)
Container(height: 50.h)  // Scales with screen height

// Font size scaling
Text('Test', style: TextStyle(fontSize: 14.sp))  // Scales with screen

// Border radius
BorderRadius.circular(8.r)  // Scales responsively
```

### Device Information
```dart
double screenWidth = MediaQuery.of(context).size.width;
double screenHeight = MediaQuery.of(context).size.height;
double statusBarHeight = MediaQuery.of(context).padding.top;
double bottomPadding = MediaQuery.of(context).padding.bottom;
```

---

## Best Practices Checklist

✅ **Always use AppSpacing** - Never hardcode padding/margin  
✅ **Always use AppTypography** - Never hardcode font sizes  
✅ **Use ResponsiveBaseLayout** - Foundation for all screens  
✅ **Check device profile** - Adapt layouts for tablets  
✅ **Use .w, .h, .sp, .r** - Always use ScreenUtil extensions  
✅ **Min touch target 48×48** - Use `AppSpacing.touchTargetSize()`  
✅ **Min spacing 8px** - Use `AppSpacing.touchTargetSpacing`  
✅ **Constrain max-width** - Prevent giant UI on tablets  
✅ **Test on real devices** - Emulators can be misleading  
✅ **Test text scaling** - System accessibility settings  

---

## Pro Tips

### Tip 1: Limiting Expansion on Tablets
```dart
// Instead of letting content expand infinitely:
Container(
  width: double.infinity,  // ❌ Too wide on tablet
  child: child,
)

// Do this:
ConstrainedBox(
  constraints: BoxConstraints(
    maxWidth: context.isTablet ? 400.w : double.infinity,
  ),
  child: child,
)
```

### Tip 2: Conditional Padding
```dart
// Don't repeat code:
final padding = AppSpacing.screenPadding(context);

padding: EdgeInsets.symmetric(
  horizontal: padding.left,
  vertical: padding.top,
)
```

### Tip 3: Debugging Layout Issues
```dart
// Temporarily add borders to see layout boundaries:
Container(
  decoration: BoxDecoration(
    border: Border.all(color: Colors.red, width: 2),
  ),
  child: child,
)
```

### Tip 4: Custom Responsive Values
```dart
// Create project-specific responsive helpers:
class AppDimensions {
  static double cardHeight(BuildContext context) {
    return context.isTablet ? 300.h : 250.h;
  }
  
  static int gridColumns(BuildContext context) {
    return switch (context.deviceProfile) {
      DeviceProfile.phone => 1,
      DeviceProfile.tablet => 2,
      _ => 3,
    };
  }
}
```

---

## Common Patterns

### Pattern 1: Responsive List with Cards
```dart
ListView.separated(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: items.length,
  separatorBuilder: (_, __) => SizedBox(height: AppSpacing.md.h),
  itemBuilder: (context, index) => ResponsiveCard(
    child: Text(items[index]),
  ),
)
```

### Pattern 2: Adaptive Form Layout
```dart
Column(
  children: [
    TextField(
      decoration: InputDecoration(
        labelText: 'Name',
        contentPadding: AppSpacing.inputPadding(context),
      ),
    ),
    SizedBox(height: AppSpacing.lg.h),
    SizedBox(
      width: double.infinity,
      height: AppSpacing.touchTargetSize(context),
      child: ElevatedButton(
        onPressed: () {},
        child: Text('Submit', style: AppTypography.buttonText(context)),
      ),
    ),
  ],
)
```

### Pattern 3: Two-Column Layout on Tablet
```dart
context.isTablet
    ? Row(
        children: [
          Expanded(child: Sidebar()),
          Expanded(child: MainContent()),
        ],
      )
    : SingleChildScrollView(
        child: Column(
          children: [
            Sidebar(),
            MainContent(),
          ],
        ),
      )
```

### Pattern 4: Centered Content with Max-Width
```dart
Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: 600.w),
    child: Padding(
      padding: AppSpacing.screenPadding(context),
      child: Column(children: [...]),
    ),
  ),
)
```

---

## Next Steps

1. ✅ Create AppSpacing, AppTypography, ResponsiveBaseLayout (done)
2. ⏭️ Update main.dart with _ResponsiveConstraintWrapper
3. ⏭️ Refactor 1-2 simple screens (SavedCardsScreen, UserCategoriesScreen)
4. ⏭️ Test on multiple devices
5. ⏭️ Gradually migrate remaining screens

---

**For full implementation details, see:**
- `docs/RESPONSIVE_DESIGN_STRATEGY.md` - Complete design system
- `docs/IMPLEMENTATION_GUIDE.md` - Step-by-step migration guide

**Created:** April 26, 2026  
**Framework:** Mezaan Pro Max Responsive Design v1.0
