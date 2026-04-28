# Implementation Guide: Responsive Design Integration

## Step 1: Update main.dart with ResponsiveConstraintWrapper

Replace your current `ScreenUtilInit` configuration in `lib/main.dart`:

### BEFORE (Current):
```dart
return ScreenUtilInit(
  designSize: const Size(375, 812),
  minTextAdapt: true,
  splitScreenMode: true,
  builder: (context, child) {
    return Obx(
      () => MaterialApp(
        // ... rest of config
      ),
    );
  },
);
```

### AFTER (With Constraint Wrapper):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

return ScreenUtilInit(
  designSize: const Size(375, 812),
  minTextAdapt: true,
  splitScreenMode: true,
  builder: (context, child) {
    return _ResponsiveConstraintWrapper(child: child);
  },
  child: Obx(
    () => MaterialApp(
      title: 'Mezaan',
      debugShowCheckedModeBanner: false,
      // ... rest of your config
    ),
  ),
);

/// NEW WRAPPER: Prevents gigantic elements on tablets
class _ResponsiveConstraintWrapper extends StatelessWidget {
  final Widget child;

  const _ResponsiveConstraintWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Max-width constraints per device profile
    double maxWidth = double.infinity;
    
    if (screenWidth > 1024) { // Desktop
      maxWidth = 1024;
    } else if (screenWidth > 768) { // Tablet landscape
      maxWidth = 768;
    }
    
    // Center content if max-width is applied
    if (maxWidth != double.infinity) {
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: maxWidth,
          child: child,
        ),
      );
    }
    
    return child;
  }
}
```

---

## Step 2: Import New Classes in Your Screens

Add these imports to any screen you're refactoring:

```dart
import 'package:mezaan/shared/theme/app_spacing.dart';
import 'package:mezaan/shared/theme/app_typography.dart';
import 'package:mezaan/shared/widgets/responsive_base_layout.dart';
```

---

## Step 3: Refactoring Strategy (Progressive)

### Phase 1: Low-Risk Refactoring (Start Here)
1. Screens with simple layouts (lists, grids)
2. **Target:** `SavedCardsScreen`, `UserCategoriesScreen`
3. **Changes:** Replace padding with `AppSpacing`, replace text styles with `AppTypography`

### Phase 2: Medium-Risk Refactoring
1. Dashboard-style screens with multiple sections
2. **Target:** `UserDashboardScreen`, `UserCasesScreen`
3. **Changes:** Use `ResponsiveBaseLayout`, add adaptive grids

### Phase 3: Complex Refactoring
1. Screens with custom layouts, overlays, animations
2. **Target:** `UserEditProfileScreen`, `UserAIChatScreen`
3. **Changes:** Custom responsive layouts with constraints

---

## Example 1: Simple Card List Screen (SavedCardsScreen)

### Before (Current Approach):
```dart
class SavedCardsScreen extends StatefulWidget {
  @override
  State<SavedCardsScreen> createState() => _SavedCardsScreenState();
}

class _SavedCardsScreenState extends State<SavedCardsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Methods')),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // ❌ Not responsive
        child: ListView(
          children: [
            // Cards here
          ],
        ),
      ),
    );
  }
}
```

### After (Responsive):
```dart
import 'package:mezaan/shared/theme/app_spacing.dart';
import 'package:mezaan/shared/theme/app_typography.dart';
import 'package:mezaan/shared/widgets/responsive_base_layout.dart';

class SavedCardsScreen extends StatefulWidget {
  const SavedCardsScreen({super.key});

  @override
  State<SavedCardsScreen> createState() => _SavedCardsScreenState();
}

class _SavedCardsScreenState extends State<SavedCardsScreen> {
  @override
  Widget build(BuildContext context) {
    // ✅ NEW: Use ResponsiveBaseLayout foundation
    return ResponsiveBaseLayout(
      title: 'Payment Methods',
      backgroundColor: Colors.grey[50],
      customPadding: AppSpacing.screenPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Your Cards',
            style: AppTypography.headline2(context), // ✅ Responsive typography
          ),
          SizedBox(height: AppSpacing.lg.h), // ✅ Responsive spacing
          
          // Card list
          _buildCardsList(context),
          
          SizedBox(height: AppSpacing.xl.h),
          
          // Add card button
          _buildAddCardButton(context),
        ],
      ),
    );
  }

  Widget _buildCardsList(BuildContext context) {
    final cards = _getPaymentCards(); // Your data source

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      separatorBuilder: (_, __) => SizedBox(height: AppSpacing.md.h),
      itemBuilder: (context, index) => _buildCardItem(context, cards[index]),
    );
  }

  Widget _buildCardItem(BuildContext context, SavedPaymentCard card) {
    final profile = context.deviceProfile;
    
    // Constrain card width on tablets
    final maxCardWidth = profile == DeviceProfile.tablet ? 400.w : double.infinity;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxCardWidth),
      child: ResponsiveCard(
        onTap: () => _editCard(card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset(
                  _networkLogoAsset(card.network),
                  width: 40.w,
                  height: 24.h,
                ),
                if (card.isDefault)
                  _buildDefaultBadge(context),
              ],
            ),
            SizedBox(height: AppSpacing.lg.h),
            Text(
              card.maskedNumber,
              style: AppTypography.monoText(context).copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppSpacing.md.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Card Holder',
                      style: AppTypography.caption(context),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      card.holderName,
                      style: AppTypography.bodyMedium(context).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Expires',
                      style: AppTypography.caption(context),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      card.expiry,
                      style: AppTypography.bodyMedium(context).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultBadge(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm.w,
        vertical: 4.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.legalGold,
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        'Default',
        style: AppTypography.caption(context).copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAddCardButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.touchTargetSize(context),
      child: ElevatedButton.icon(
        onPressed: () => _addNewCard(),
        icon: const Icon(Icons.add),
        label: Text(
          'Add Payment Method',
          style: AppTypography.buttonText(context),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navyBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      ),
    );
  }

  String _networkLogoAsset(CardNetwork network) {
    return switch (network) {
      CardNetwork.visa => 'assets/logos/visa.png',
      CardNetwork.mastercard => 'assets/logos/mastercard.png',
      CardNetwork.meeza => 'assets/logos/meeza.png',
      _ => 'assets/logos/card.png',
    };
  }

  void _editCard(SavedPaymentCard card) {
    // Navigate to card editor
  }

  void _addNewCard() {
    // Navigate to add card screen
  }

  List<SavedPaymentCard> _getPaymentCards() {
    // Fetch from your state/provider
    return [];
  }
}
```

---

## Example 2: Dashboard Screen (Complex Layout)

### Before (Current Approach - Problematic on Tablets):
```dart
class UserDashboardScreen extends StatefulWidget {
  @override
  State<UserDashboardScreenState> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), // ❌ Same on all devices
        child: Column(
          children: [
            // Header
            GridView.count( // ❌ No adaptive columns
              crossAxisCount: 1,
              children: [...],
            ),
          ],
        ),
      ),
    );
  }
}
```

### After (Fully Responsive):
```dart
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mezaan/shared/theme/app_spacing.dart';
import 'package:mezaan/shared/theme/app_typography.dart';
import 'package:mezaan/shared/widgets/responsive_base_layout.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _sosPulseController;

  @override
  void initState() {
    super.initState();
    _sosPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _sosPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ NEW: Foundation layout with responsive padding
    return ResponsiveBaseLayout(
      showAppBar: false,
      useSafeArea: true,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header with responsive spacing
          _buildWelcomeHeader(context),
          SizedBox(height: AppSpacing.lg.h),

          // Responsive dashboard cards
          _buildDashboardCards(context),
          SizedBox(height: AppSpacing.lg.h),

          // Quick actions
          _buildQuickActions(context),
          SizedBox(height: AppSpacing.xl.h),

          // Recent cases
          _buildRecentCases(context),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome Back',
          style: AppTypography.headline1(context),
        ),
        SizedBox(height: 8.h),
        Text(
          'Your legal profile and cases at a glance',
          style: AppTypography.bodyMedium(context).copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardCards(BuildContext context) {
    // ✅ NEW: Adaptive grid that changes columns based on device
    return ResponsiveGridLayout(
      children: [
        _buildDashboardCard(
          context,
          title: 'Active Cases',
          value: '3',
          icon: Icons.folder,
          color: Colors.blue,
        ),
        _buildDashboardCard(
          context,
          title: 'Messages',
          value: '5',
          icon: Icons.mail,
          color: Colors.amber,
        ),
        _buildDashboardCard(
          context,
          title: 'Appointments',
          value: '2',
          icon: Icons.calendar_today,
          color: Colors.teal,
        ),
      ],
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return ResponsiveCard(
      backgroundColor: Colors.white,
      showShadow: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32.w, color: color),
          SizedBox(height: 12.h),
          Text(
            value,
            style: AppTypography.headline2(context).copyWith(color: color),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            title,
            style: AppTypography.caption(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final profile = context.deviceProfile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTypography.headline3(context),
        ),
        SizedBox(height: AppSpacing.md.h),
        ResponsiveRowLayout(
          spacing: AppSpacing.touchTargetSpacing,
          runSpacing: AppSpacing.md.w,
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                label: 'View Cases',
                onPressed: () {},
                isPrimary: true,
              ),
            ),
            Expanded(
              child: _buildActionButton(
                context,
                label: 'Message Lawyer',
                onPressed: () {},
              ),
            ),
            if (profile == DeviceProfile.tablet)
              Expanded(
                child: _buildActionButton(
                  context,
                  label: 'Schedule',
                  onPressed: () {},
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return SizedBox(
      height: AppSpacing.touchTargetSize(context),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? AppColors.navyBlue : Colors.grey[200],
          foregroundColor: isPrimary ? Colors.white : AppColors.textDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.buttonText(context),
        ),
      ),
    );
  }

  Widget _buildRecentCases(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Cases',
          style: AppTypography.headline3(context),
        ),
        SizedBox(height: AppSpacing.md.h),
        // Your recent cases list here
      ],
    );
  }
}
```

---

## Step 4: Testing Checklist

### Test on Physical Devices
- [ ] iPhone SE (375px width) - Should look compact and readable
- [ ] iPhone 14 (390px width) - Smooth scaling
- [ ] iPhone 14 Pro Max (430px width) - Larger scaling
- [ ] iPad Air (768px width) - 2-column grids, proper spacing
- [ ] iPad Pro 12.9" (1024px width) - Max-width constraint prevents gigantic UI

### Test Orientations
- [ ] Portrait mode on all devices
- [ ] Landscape mode on phones
- [ ] Split screen on tablets

### Test Accessibility
- [ ] System text scale 100% → Should be readable
- [ ] System text scale 150% → Should still fit on screen
- [ ] Dark mode → All text must have contrast
- [ ] Screen reader (TalkBack/VoiceOver) → All elements labeled

### Test Features
- [ ] Touch targets are ≥ 48×48 dp
- [ ] No horizontal scroll on any device
- [ ] All padding uses AppSpacing
- [ ] All text uses AppTypography
- [ ] No hardcoded color values (use AppColors)

---

## Migration Order (Recommended)

1. **Week 1: Foundation**
   - Create AppSpacing, AppTypography, ResponsiveBaseLayout
   - Update main.dart with _ResponsiveConstraintWrapper
   - Test on different devices

2. **Week 2: Simple Screens** (Low risk)
   - SavedCardsScreen
   - UserCategoriesScreen
   - UserEmergencyContactsScreen

3. **Week 3: Medium Screens** (Medium risk)
   - UserDashboardScreen
   - UserCasesScreen
   - LawyersListScreen

4. **Week 4: Complex Screens** (Higher risk)
   - UserEditProfileScreen
   - UserAIChatScreen
   - CaseDetailsScreen

---

## Common Mistakes to Avoid

❌ **Using fixed padding like `EdgeInsets.all(16.0)`**
- ✅ Use `AppSpacing.screenPadding(context)` instead

❌ **Hardcoding text sizes like `fontSize: 14`**
- ✅ Use `AppTypography.bodyMedium(context)` instead

❌ **Not constraining max-width on tablets**
- ✅ Use `ConstrainedBox(constraints: BoxConstraints(maxWidth: 400.w))`

❌ **Ignoring device profile in layouts**
- ✅ Use `context.deviceProfile` to adapt columns, spacing, etc.

❌ **Touch targets smaller than 48×48 dp**
- ✅ Use `AppSpacing.touchTargetSize(context)` for buttons

❌ **Mixing responsive and fixed sizes**
- ✅ Use responsive extensions (`.w`, `.h`, `.sp`, `.r`) consistently

---

## Debugging Tips

### Check Device Profile
```dart
print('Device: ${context.deviceProfile}');
print('Width: ${MediaQuery.of(context).size.width}');
print('Height: ${MediaQuery.of(context).size.height}');
```

### Check Typography Sizing
```dart
Text('Test', style: AppTypography.headline2(context))
// Check Flutter DevTools to see actual computed font size
```

### Check Spacing
```dart
// Temporarily add visual borders
Container(
  padding: AppSpacing.screenPadding(context),
  decoration: BoxDecoration(border: Border.all(color: Colors.red)),
  child: child,
)
```

---

## Resources

- [flutter_screenutil Documentation](https://pub.dev/packages/flutter_screenutil)
- [Material Design 3 - Touch targets](https://material.io/design/usability/accessibility.html)
- [Flutter Responsive Design](https://flutter.dev/docs/development/ui/layout/responsive)
- [Safe Area Widgets](https://api.flutter.dev/flutter/widgets/SafeArea-class.html)

---

**Last Updated:** April 26, 2026  
**Framework Version:** Mezaan Pro Max v1.0
