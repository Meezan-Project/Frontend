import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mezaan/shared/localization/localization_controller.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/theme/theme_controller.dart';
import 'package:mezaan/user/screens/government_map_screen.dart';
import 'package:mezaan/user/widgets/user_bottom_nav_bar.dart';
import 'package:mezaan/user/widgets/user_profile_side_panel.dart';
import 'package:mezaan/user/widgets/user_top_header.dart';
import 'dart:typed_data';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ImagePicker _imagePicker = ImagePicker();
  late final Future<_UserDashboardPayload> _payloadFuture;
  late final AnimationController _sosPulseController;
  Uint8List? _profileImageBytes;
  final String _userDisplayName = 'Mezaan User';
  int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    _payloadFuture = _UserDashboardRepository.load();
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

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label ${'coming soon'.translate()}')),
    );
  }

  void _openProfilePanel() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _openGovernmentMap() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const GovernmentMapScreen(),
      ),
    );
  }

  Future<void> _changeProfilePhoto() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1200,
    );

    if (pickedFile == null) {
      return;
    }

    final bytes = await pickedFile.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() => _profileImageBytes = bytes);
  }

  Future<void> _showLanguageSheet() async {
    final localizationController = LocalizationController.instance;
    final selectedLanguage = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Language'.translate(),
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: const Icon(Icons.language_rounded),
                  title: const Text('English'),
                  trailing: localizationController.currentLanguage.value == 'en'
                      ? const Icon(Icons.check_rounded, color: Colors.green)
                      : null,
                  onTap: () => Navigator.of(context).pop('en'),
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: const Icon(Icons.language_rounded),
                  title: const Text('العربية'),
                  trailing: localizationController.currentLanguage.value == 'ar'
                      ? const Icon(Icons.check_rounded, color: Colors.green)
                      : null,
                  onTap: () => Navigator.of(context).pop('ar'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedLanguage == null) {
      return;
    }

    localizationController.setLanguage(selectedLanguage);
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildDashboardView(_UserDashboardPayload payload) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
      children: [
        const _HeroCard(),
        SizedBox(height: 16.h),
        _SectionHeader(
          title: 'Categories'.translate(),
          subtitle: 'Browse legal services from the database'.translate(),
        ),
        SizedBox(height: 10.h),
        _CategoryGrid(categories: payload.categories),
        SizedBox(height: 12.h),
        _LegalAIAssistantCard(
          onStartChat: () {
            _showComingSoon('AI Chat'.translate());
          },
        ),
        SizedBox(height: 12.h),
        _NearbyGovernmentMapCard(
          onOpenMap: () {
            _openGovernmentMap();
          },
        ),
        SizedBox(height: 16.h),
        _SectionHeader(
          title: 'Top Lawyers'.translate(),
          subtitle: 'Sorted by rating, availability, and specialization'
              .translate(),
        ),
        SizedBox(height: 10.h),
        ...payload.topLawyers.map(_LawyerCard.new),
        SizedBox(height: 16.h),
        _SectionHeader(
          title: 'Featured Services'.translate(),
          subtitle: 'Database-driven legal offers and consultations'
              .translate(),
        ),
        SizedBox(height: 10.h),
        ...payload.services.map(_ServiceCard.new),
      ],
    );
  }

  Widget _buildCurrentView(_UserDashboardPayload payload) {
    return _buildDashboardView(payload);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      endDrawer: UserProfileSidePanel(
        userName: _userDisplayName,
        profileImageBytes: _profileImageBytes,
        isDarkMode: ThemeController.instance.isDarkMode.value,
        onDarkModeChanged: (value) {
          ThemeController.instance.setDarkMode(value);
          if (mounted) {
            setState(() {});
          }
        },
        onChangePhoto: _changeProfilePhoto,
        onEditProfile: () => _showComingSoon('Edit profile'.translate()),
        onLanguage: _showLanguageSheet,
        onSavedCards: () => _showComingSoon('Saved cards'.translate()),
        onSettings: () => _showComingSoon('Settings'.translate()),
        onEmergencyContacts: () =>
            _showComingSoon('Emergency contacts'.translate()),
        onPrivacy: () => _showComingSoon('Privacy & security'.translate()),
        onHelp: () => _showComingSoon('Help center'.translate()),
        onLogout: () => _showComingSoon('Logout'.translate()),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF0B1220), Color(0xFF131C2C)]
                : const [Color(0xFFF8FAFE), Color(0xFFF1F6FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            FutureBuilder<_UserDashboardPayload>(
              future: _payloadFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                final payload = snapshot.data ?? _UserDashboardPayload.empty();
                return SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
                        child: UserTopHeader(balance: payload.balance),
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          child: KeyedSubtree(
                            key: ValueKey(_selectedIndex),
                            child: _buildCurrentView(payload),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              right: 18.w,
              bottom: 10.h,
              child: SafeArea(
                child: _SosFloatingButton(
                  pulse: _sosPulseController,
                  onTap: () {
                    _showComingSoon('SOS'.translate());
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: UserBottomNavBar(
        currentIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index == 4) {
            setState(() => _selectedIndex = 2);
            _openProfilePanel();
            return;
          }

          setState(() => _selectedIndex = index);
          if (index == 2) {
            return;
          }

          if (index == 0) {
            _showComingSoon('Urgent Rescue'.translate());
          } else if (index == 1) {
            _showComingSoon('Cases'.translate());
          } else if (index == 3) {
            _showComingSoon('Messages'.translate());
          }
        },
        onCenterButtonTap: () => setState(() => _selectedIndex = 2),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 19.sp,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          subtitle,
          style: TextStyle(
            color: textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        gradient: const LinearGradient(
          colors: [Color(0xFF042A52), Color(0xFF0B5E55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D2345).withValues(alpha: 0.22),
            blurRadius: 22,
            offset: Offset(0, 12.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, User'.translate(),
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Your dashboard is powered by live database content'.translate(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.35,
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: Colors.white),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Search lawyers, categories, cases...'.translate(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<_UserCategory> categories;

  const _CategoryGrid({required this.categories});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF223149)
        : Theme.of(context).cardColor;
    final textColor = isDark
        ? Colors.white
        : Theme.of(context).textTheme.bodyMedium?.color;
    final borderColor = isDark
        ? const Color(0xFF2A3550)
        : const Color(0xFFE7EDF7);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 112.h,
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
      ),
      itemBuilder: (context, index) {
        final category = categories[index];
        return Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D2345).withValues(alpha: 0.06),
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
                style: GoogleFonts.cairo(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SosFloatingButton extends StatelessWidget {
  final Animation<double> pulse;
  final VoidCallback onTap;

  const _SosFloatingButton({required this.pulse, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final animatedValue = Curves.easeOut.transform(pulse.value);
        return Transform.scale(
          scale: 1.0 + (animatedValue * 0.07),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 74.w,
                height: 74.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(
                    0xFFFF5D5D,
                  ).withValues(alpha: 0.18 * (1 - animatedValue)),
                ),
              ),
              Container(
                width: 56.w,
                height: 56.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFE53935)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE53935).withValues(alpha: 0.38),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    customBorder: const CircleBorder(),
                    child: Center(
                      child: Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LegalAIAssistantCard extends StatelessWidget {
  final VoidCallback onStartChat;

  const _LegalAIAssistantCard({required this.onStartChat});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onStartChat,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 14.h),
          decoration: BoxDecoration(
            color: const Color(0xFFD9BF84),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.psychology_alt_outlined,
                    color: Color(0xFF0D2345),
                    size: 22.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Legal AI Assistant'.translate(),
                      style: GoogleFonts.cairo(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0D2345),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: const Color(0xFF0D2345).withValues(alpha: 0.28),
                    size: 36.sp,
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                'Get instant answers to your legal questions'.translate(),
                style: TextStyle(
                  color: const Color(0xFF0D2345).withValues(alpha: 0.86),
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 14.h),
              SizedBox(
                height: 36.h,
                child: ElevatedButton(
                  onPressed: onStartChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D2345),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                  ),
                  child: Text(
                    'Start Chat'.translate(),
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyGovernmentMapCard extends StatelessWidget {
  final VoidCallback onOpenMap;

  const _NearbyGovernmentMapCard({required this.onOpenMap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenMap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF8FBFF), Color(0xFFE8F0FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: const Color(0xFFCFDBF4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: Offset(0, 6.h),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42.w,
                    height: 42.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D2345).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: const Icon(
                      Icons.map_outlined,
                      color: Color(0xFF0D2345),
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nearby Government Services'.translate(),
                          style: GoogleFonts.cairo(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0D2345),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Find government offices, courts, and service centers nearby'
                              .translate(),
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.64),
                            fontSize: 13.sp,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.place_outlined,
                    color: Color(0xFF9AAAC8),
                    size: 28,
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: const Color(0xFFD8E3F7)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.near_me_outlined,
                      color: Color(0xFF0B5E55),
                      size: 18,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Open map to see the closest places'.translate(),
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.72),
                          fontSize: 12.5.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    SizedBox(
                      height: 34.h,
                      child: ElevatedButton(
                        onPressed: onOpenMap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D2345),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(horizontal: 14.w),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        child: Text(
                          'Open Map'.translate(),
                          style: GoogleFonts.cairo(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LawyerCard extends StatelessWidget {
  final _LawyerProfile lawyer;

  const _LawyerCard(this.lawyer);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF223149)
        : Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final borderColor = isDark
        ? const Color(0xFF2A3550)
        : const Color(0xFFE7EDF7);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D2345).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: Image.network(
              lawyer.imageUrl,
              width: 84.w,
              height: 84.h,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 84.w,
                  height: 84.h,
                  color: AppColors.navyBlue.withValues(alpha: 0.08),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.navyBlue,
                  ),
                );
              },
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lawyer.name,
                  style: GoogleFonts.cairo(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  lawyer.specialization.translate(),
                  style: TextStyle(color: textColor?.withValues(alpha: 0.75)),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 18,
                    ),
                    SizedBox(width: 4.w),
                    Text(lawyer.rating),
                    SizedBox(width: 12.w),
                    const Icon(Icons.work_outline_rounded, size: 18),
                    SizedBox(width: 4.w),
                    Text(lawyer.experience.translate()),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Column(
            children: [
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyBlue,
                  foregroundColor: Colors.white,
                  minimumSize: Size(78.w, 36.h),
                ),
                child: Text('View'.translate()),
              ),
              SizedBox(height: 8.h),
              Text(
                lawyer.onlineStatus.translate(),
                style: TextStyle(
                  color: lawyer.isOnline ? Colors.green : Colors.grey,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final _ServiceItem service;

  const _ServiceCard(this.service);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF223149)
        : Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final borderColor = isDark
        ? const Color(0xFF2A3550)
        : const Color(0xFFE7EDF7);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D2345).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20.r,
            backgroundColor: service.color.withValues(alpha: 0.12),
            child: Icon(service.icon, color: service.color, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title.translate(),
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4.h),
                Text(
                  service.subtitle.translate(),
                  style: TextStyle(
                    color: textColor?.withValues(alpha: 0.72),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserDashboardRepository {
  static Future<_UserDashboardPayload> load() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _UserDashboardPayload.sample();
  }
}

class _UserDashboardPayload {
  final List<_UserCategory> categories;
  final List<_LawyerProfile> topLawyers;
  final List<_ServiceItem> services;
  final String balance;

  const _UserDashboardPayload({
    required this.categories,
    required this.topLawyers,
    required this.services,
    required this.balance,
  });

  factory _UserDashboardPayload.sample() {
    return const _UserDashboardPayload(
      categories: [
        _UserCategory(
          'Family Law',
          Icons.family_restroom_rounded,
          Color(0xFF0B5E55),
        ),
        _UserCategory(
          'Civil Law',
          Icons.account_balance_rounded,
          Color(0xFF042A52),
        ),
        _UserCategory('Criminal Law', Icons.gavel_rounded, Color(0xFFB91C1C)),
        _UserCategory(
          'Labor Law',
          Icons.work_history_rounded,
          Color(0xFF7A4B00),
        ),
        _UserCategory(
          'Contracts',
          Icons.description_rounded,
          Color(0xFF4B5563),
        ),
        _UserCategory('Companies', Icons.apartment_rounded, Color(0xFF1D4ED8)),
      ],
      topLawyers: [
        _LawyerProfile(
          name: 'Maha El-Sayed',
          specialization: 'Family Law',
          rating: '4.9',
          experience: '12 years experience',
          onlineStatus: 'Online now',
          isOnline: true,
          imageUrl:
              'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=600',
        ),
        _LawyerProfile(
          name: 'Ahmed Mostafa',
          specialization: 'Civil Law',
          rating: '4.8',
          experience: '9 years experience',
          onlineStatus: 'Available later',
          isOnline: false,
          imageUrl:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600',
        ),
      ],
      services: [
        _ServiceItem(
          'Video Consultation',
          'Book a secure live session',
          Icons.videocam_rounded,
          Color(0xFF0B5E55),
        ),
        _ServiceItem(
          'Document Review',
          'Send contracts and legal files',
          Icons.description_rounded,
          Color(0xFF7A4B00),
        ),
      ],
      balance: 'EGP 12,450',
    );
  }

  factory _UserDashboardPayload.empty() => _UserDashboardPayload.sample();
}

class _UserCategory {
  final String title;
  final IconData icon;
  final Color color;

  const _UserCategory(this.title, this.icon, this.color);
}

class _LawyerProfile {
  final String name;
  final String specialization;
  final String rating;
  final String experience;
  final String onlineStatus;
  final bool isOnline;
  final String imageUrl;

  const _LawyerProfile({
    required this.name,
    required this.specialization,
    required this.rating,
    required this.experience,
    required this.onlineStatus,
    required this.isOnline,
    required this.imageUrl,
  });
}

class _ServiceItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ServiceItem(this.title, this.subtitle, this.icon, this.color);
}
