import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/screens/lawyers_list_screen.dart';

class UserCategoriesScreen extends StatefulWidget {
  const UserCategoriesScreen({super.key});

  @override
  State<UserCategoriesScreen> createState() => _UserCategoriesScreenState();
}

class _UserCategoriesScreenState extends State<UserCategoriesScreen> {
  bool _isLoading = true;
  final List<_CategoryData> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('lawyer_specializations')
          .get();

      final loaded = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final title =
                data['title']?.toString().trim() ??
                data['name']?.toString().trim() ??
                '';
            if (title.isEmpty) return null;

            final style = _getCategoryStyle(title);
            return _CategoryData(title, style.icon, style.color);
          })
          .whereType<_CategoryData>()
          .toList();

      if (mounted) {
        setState(() {
          _categories.addAll(loaded);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static ({IconData icon, Color color}) _getCategoryStyle(String name) {
    final lowerName = name.toLowerCase();

    if (lowerName.contains('family') ||
        lowerName.contains('أسرة') ||
        lowerName.contains('احوال') ||
        lowerName.contains('أحوال')) {
      return (
        icon: Icons.family_restroom_rounded,
        color: const Color(0xFFE91E63),
      );
    }
    if (lowerName.contains('criminal') || lowerName.contains('جنائي')) {
      return (icon: Icons.local_police_rounded, color: const Color(0xFF424242));
    }
    if (lowerName.contains('corporate') ||
        lowerName.contains('business') ||
        lowerName.contains('شركات') ||
        lowerName.contains('تجاري')) {
      return (
        icon: Icons.business_center_rounded,
        color: const Color(0xFF1976D2),
      );
    }
    if (lowerName.contains('labor') ||
        lowerName.contains('employment') ||
        lowerName.contains('عمال')) {
      return (icon: Icons.engineering_rounded, color: const Color(0xFFFF9800));
    }
    if (lowerName.contains('real estate') ||
        lowerName.contains('property') ||
        lowerName.contains('عقار')) {
      return (icon: Icons.apartment_rounded, color: const Color(0xFF4CAF50));
    }
    if (lowerName.contains('civil') || lowerName.contains('مدني')) {
      return (icon: Icons.groups_rounded, color: const Color(0xFF009688));
    }
    if (lowerName.contains('tax') || lowerName.contains('ضريب')) {
      return (
        icon: Icons.request_quote_rounded,
        color: const Color(0xFFF44336),
      );
    }
    if (lowerName.contains('intellectual') || lowerName.contains('فكرية')) {
      return (icon: Icons.lightbulb_rounded, color: const Color(0xFF673AB7));
    }
    if (lowerName.contains('administrative') ||
        lowerName.contains('إداري') ||
        lowerName.contains('اداري')) {
      return (
        icon: Icons.account_balance_rounded,
        color: const Color(0xFF607D8B),
      );
    }

    return (icon: Icons.gavel_rounded, color: const Color(0xFF0D2345));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : AppColors.navyBlue,
        title: Text(
          'All Categories'.translate(),
          style: GoogleFonts.cairo(
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
          ? Center(child: Text('No categories found'.translate()))
          : GridView.builder(
              padding: EdgeInsets.all(16.r),
              itemCount: _categories.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: 112.h,
                crossAxisSpacing: 10.w,
                mainAxisSpacing: 10.h,
              ),
              itemBuilder: (context, index) {
                final category = _categories[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            LawyersListScreen(categoryName: category.title),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF223149)
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2A3550)
                            : const Color(0xFFE7EDF7),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF0D2345,
                          ).withValues(alpha: 0.06),
                          blurRadius: 14,
                          offset: Offset(0, 6.h),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 24.r,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.14)
                              : category.color.withValues(alpha: 0.12),
                          child: Icon(
                            category.icon,
                            color: isDark ? Colors.white : category.color,
                            size: 28.sp,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          category.title.translate(),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _CategoryData {
  final String title;
  final IconData icon;
  final Color color;

  const _CategoryData(this.title, this.icon, this.color);
}
