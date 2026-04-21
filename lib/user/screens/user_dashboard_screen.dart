import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mezaan/shared/auth/auth_state.dart';
import 'package:mezaan/shared/auth/firebase_session_service.dart';
import 'package:mezaan/shared/localization/localization_controller.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/theme/theme_controller.dart';
import 'package:mezaan/user/screens/government_map_screen.dart';
import 'package:mezaan/user/screens/messages_screen.dart';
import 'package:mezaan/user/screens/user_edit_profile_screen.dart';
import 'package:mezaan/user/widgets/user_bottom_nav_bar.dart';
import 'package:mezaan/user/widgets/user_profile_side_panel.dart';
import 'package:mezaan/user/widgets/user_top_header.dart';
import 'dart:async';
import 'dart:typed_data';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  String? _payloadUserUid;
  Future<_UserDashboardPayload>? _payloadFuture;
  late final AnimationController _sosPulseController;
  Uint8List? _profileImageBytes;
  int _selectedIndex = 2;
  OverlayEntry? _profilePanelOverlayEntry;

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
    _profilePanelOverlayEntry?.remove();
    _profilePanelOverlayEntry = null;
    _sosPulseController.dispose();
    super.dispose();
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label ${'coming soon'.translate()}')),
    );
  }

  Future<void> _runPanelAction(FutureOr<void> Function() action) async {
    _closeProfilePanel();
    await action();
  }

  void _openProfilePanel({required String userName}) {
    if (_profilePanelOverlayEntry != null) {
      return;
    }

    final overlay = Overlay.of(context, rootOverlay: true);

    _profilePanelOverlayEntry = OverlayEntry(
      builder: (_) {
        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeProfilePanel,
                  child: Container(color: Colors.black.withValues(alpha: 0.35)),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: SafeArea(
                  child: UserProfileSidePanel(
                    userName: userName,
                    profileImageBytes: _profileImageBytes,
                    isDarkMode: ThemeController.instance.isDarkMode.value,
                    onDarkModeChanged: (value) {
                      ThemeController.instance.setDarkMode(value);
                      _profilePanelOverlayEntry?.markNeedsBuild();
                    },
                    onClose: _closeProfilePanel,
                    onChangePhoto: _changeProfilePhoto,
                    onEditProfile: () => _runPanelAction(
                      () => Get.to(
                        () => const UserEditProfileScreen(),
                        transition: Transition.rightToLeft,
                      ),
                    ),
                    onLanguage: () => _runPanelAction(_showLanguageSheet),
                    onSavedCards: () => _runPanelAction(
                      () => _showComingSoon('Saved cards'.translate()),
                    ),
                    onSettings: () => _runPanelAction(
                      () => _showComingSoon('Settings'.translate()),
                    ),
                    onEmergencyContacts: () => _runPanelAction(
                      () => _showComingSoon('Emergency contacts'.translate()),
                    ),
                    onPrivacy: () => _runPanelAction(
                      () => _showComingSoon('Privacy & security'.translate()),
                    ),
                    onHelp: () => _runPanelAction(
                      () => _showComingSoon('Help center'.translate()),
                    ),
                    onLogout: () => _runPanelAction(_handleLogout),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    overlay.insert(_profilePanelOverlayEntry!);
  }

  void _closeProfilePanel() {
    _profilePanelOverlayEntry?.remove();
    _profilePanelOverlayEntry = null;
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

    _profileImageBytes = bytes;
    if (_profilePanelOverlayEntry != null) {
      _profilePanelOverlayEntry?.markNeedsBuild();
      return;
    }

    setState(() {});
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Logout'.translate()),
          content: Text('Are you sure you want to logout?'.translate()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'.translate()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Logout'.translate()),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;
    await FirebaseSessionService.signOutAll();
    authState.logout();
    if (!mounted) return;
    LoadingNavigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
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
        _HeroCard(userName: payload.userName),
        SizedBox(height: 16.h),
        _SectionHeader(
          title: 'Categories'.translate(),
          subtitle: 'Browse legal services from the database'.translate(),
        ),
        SizedBox(height: 10.h),
        if (payload.categories.isEmpty)
          const _DataEmptyHint(message: 'No categories found in Firebase yet.')
        else
          _CategoryGrid(categories: payload.categories),
        SizedBox(height: 12.h),
        _LegalAIAssistantCard(
          onStartChat: () {
            LoadingNavigator.pushNamed(context, AppRoutes.userAiChat);
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
        if (payload.topLawyers.isEmpty)
          const _DataEmptyHint(message: 'No lawyers found in Firebase yet.')
        else
          ...payload.topLawyers.map(_LawyerCard.new),
        SizedBox(height: 16.h),
        _SectionHeader(
          title: 'Featured Services'.translate(),
          subtitle: 'Database-driven legal offers and consultations'
              .translate(),
        ),
        SizedBox(height: 10.h),
        if (payload.services.isEmpty)
          const _DataEmptyHint(message: 'No services found in Firebase yet.')
        else
          ...payload.services.map(_ServiceCard.new),
      ],
    );
  }

  Widget _buildCurrentView(_UserDashboardPayload payload) {
    return _buildDashboardView(payload);
  }

  Future<_UserDashboardPayload> _loadPayloadForCurrentUser(User user) {
    if (_payloadFuture == null || _payloadUserUid != user.uid) {
      _payloadUserUid = user.uid;
      _payloadFuture = _UserDashboardRepository.loadForUser(user: user);
    }
    return _payloadFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final currentUser = authSnapshot.data;

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (currentUser == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(20.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 54.sp),
                    SizedBox(height: 10.h),
                    Text(
                      'You need to login first'.translate(),
                      style: GoogleFonts.cairo(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    ElevatedButton(
                      onPressed: () {
                        LoadingNavigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.login,
                          (route) => false,
                        );
                      },
                      child: Text('Go to Login'.translate()),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return FutureBuilder<_UserDashboardPayload>(
          future: _loadPayloadForCurrentUser(currentUser),
          builder: (context, snapshot) {
            final payload =
                snapshot.data ??
                _UserDashboardPayload.empty(
                  fallbackName:
                      currentUser.displayName ?? currentUser.email ?? 'User',
                );

            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                    if (snapshot.connectionState != ConnectionState.done)
                      const Center(child: CircularProgressIndicator())
                    else
                      SafeArea(
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                16.w,
                                10.h,
                                16.w,
                                6.h,
                              ),
                              child: UserTopHeader(
                                balance: payload.balance,
                                onNotificationTap: () {
                                  _openProfilePanel(userName: payload.userName);
                                },
                              ),
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
                      ),
                    Positioned(
                      right: 18.w,
                      bottom: 52.h,
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
                  if (index != 4 && _profilePanelOverlayEntry != null) {
                    _closeProfilePanel();
                  }

                  if (index == 4) {
                    if (_selectedIndex != 2) {
                      setState(() => _selectedIndex = 2);
                    }
                    _openProfilePanel(
                      userName:
                          currentUser.displayName ??
                          currentUser.email ??
                          'User',
                    );
                    return;
                  }

                  if (_selectedIndex != index) {
                    setState(() => _selectedIndex = index);
                  }
                  if (index == 2) {
                    return;
                  }

                  if (index == 0) {
                    _showComingSoon('Urgent Rescue'.translate());
                  } else if (index == 1) {
                    _showComingSoon('Cases'.translate());
                  } else if (index == 3) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const MessagesScreen(),
                      ),
                    );
                  }
                },
                onCenterButtonTap: () {
                  if (_profilePanelOverlayEntry != null) {
                    _closeProfilePanel();
                  }
                  if (_selectedIndex != 2) {
                    setState(() => _selectedIndex = 2);
                  }
                },
              ),
            );
          },
        );
      },
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
  final String userName;

  const _HeroCard({required this.userName});

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
            '${'Welcome back,'.translate()} $userName',
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
  static Future<_UserDashboardPayload> loadForUser({required User user}) async {
    final firestore = FirebaseFirestore.instance;

    Map<String, dynamic> userData = <String, dynamic>{};
    try {
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      userData = userDoc.data() ?? <String, dynamic>{};

      if (userData.isEmpty && user.email != null) {
        final byEmail = await firestore
            .collection('users')
            .where('email', isEqualTo: user.email!.trim())
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          userData = byEmail.docs.first.data();
        }
      }
    } catch (_) {}

    final categories = await _loadCategories(firestore);
    final topLawyers = await _loadTopLawyers(firestore);
    final services = await _loadServices(firestore);

    final firstName = userData['firstName']?.toString().trim() ?? '';
    final secondName = userData['secondName']?.toString().trim() ?? '';
    final fullName = '$firstName $secondName'.trim();
    final resolvedName = fullName.isNotEmpty
        ? fullName
        : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : (user.email?.split('@').first ?? 'User'));

    return _UserDashboardPayload(
      userName: resolvedName,
      categories: categories,
      topLawyers: topLawyers,
      services: services,
      balance: _formatBalance(userData['balance']),
    );
  }

  static Future<List<_UserCategory>> _loadCategories(
    FirebaseFirestore firestore,
  ) async {
    try {
      final snapshot = await firestore
          .collection('legal_categories')
          .orderBy('order')
          .limit(12)
          .get();

      final loaded = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final title =
                data['title']?.toString().trim() ??
                data['name']?.toString().trim() ??
                '';
            if (title.isEmpty) {
              return null;
            }

            return _UserCategory(
              title,
              _iconFromName(data['icon']?.toString()),
              _colorFromDynamic(data['color']),
            );
          })
          .whereType<_UserCategory>()
          .toList(growable: false);

      if (loaded.isNotEmpty) {
        return loaded;
      }
    } catch (_) {}

    return const <_UserCategory>[];
  }

  static Future<List<_LawyerProfile>> _loadTopLawyers(
    FirebaseFirestore firestore,
  ) async {
    try {
      final snapshot = await firestore.collection('lawyers').limit(8).get();

      final loaded = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final firstName = data['firstName']?.toString().trim() ?? '';
            final secondName = data['secondName']?.toString().trim() ?? '';
            final fullName = '$firstName $secondName'.trim();

            if (fullName.isEmpty) {
              return null;
            }

            final specialization = data['specialization']?.toString().trim();
            final rating = data['rating']?.toString().trim();
            final years = data['yearsExperience']?.toString().trim();

            return _LawyerProfile(
              name: fullName,
              specialization: specialization == null || specialization.isEmpty
                  ? 'General Law'
                  : specialization,
              rating: (rating == null || rating.isEmpty) ? '4.5' : rating,
              experience: (years == null || years.isEmpty)
                  ? 'Experienced'
                  : '$years years experience',
              onlineStatus: (data['isOnline'] == true)
                  ? 'Online now'
                  : 'Available later',
              isOnline: data['isOnline'] == true,
              imageUrl: data['photoUrl']?.toString().trim().isNotEmpty == true
                  ? data['photoUrl'].toString().trim()
                  : (data['imageUrl']?.toString().trim().isNotEmpty == true
                        ? data['imageUrl'].toString().trim()
                        : ''),
            );
          })
          .whereType<_LawyerProfile>()
          .toList(growable: false);

      if (loaded.isNotEmpty) {
        return loaded;
      }
    } catch (_) {}

    return const <_LawyerProfile>[];
  }

  static Future<List<_ServiceItem>> _loadServices(
    FirebaseFirestore firestore,
  ) async {
    try {
      final snapshot = await firestore
          .collection('legal_services')
          .limit(12)
          .get();

      final loaded = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final title = data['title']?.toString().trim() ?? '';
            if (title.isEmpty) {
              return null;
            }
            final subtitle =
                data['subtitle']?.toString().trim() ??
                data['description']?.toString().trim() ??
                '';
            return _ServiceItem(
              title,
              subtitle.isEmpty ? 'Legal support service' : subtitle,
              _iconFromName(data['icon']?.toString()),
              _colorFromDynamic(data['color']),
            );
          })
          .whereType<_ServiceItem>()
          .toList(growable: false);

      if (loaded.isNotEmpty) {
        return loaded;
      }
    } catch (_) {}

    return const <_ServiceItem>[];
  }

  static String _formatBalance(dynamic value) {
    if (value == null) {
      return 'EGP 0';
    }

    if (value is num) {
      return 'EGP ${value.toStringAsFixed(0)}';
    }

    final asString = value.toString().trim();
    if (asString.isEmpty) {
      return 'EGP 0';
    }

    if (asString.toUpperCase().startsWith('EGP')) {
      return asString;
    }

    return 'EGP $asString';
  }

  static IconData _iconFromName(String? name) {
    final icon = name?.toLowerCase().trim() ?? '';
    switch (icon) {
      case 'gavel':
      case 'gavel_rounded':
        return Icons.gavel_rounded;
      case 'family':
      case 'family_restroom_rounded':
        return Icons.family_restroom_rounded;
      case 'work':
      case 'work_history_rounded':
        return Icons.work_history_rounded;
      case 'apartment':
      case 'apartment_rounded':
        return Icons.apartment_rounded;
      case 'videocam':
      case 'videocam_rounded':
        return Icons.videocam_rounded;
      case 'description':
      case 'description_rounded':
        return Icons.description_rounded;
      case 'account_balance':
      case 'account_balance_rounded':
        return Icons.account_balance_rounded;
      default:
        return Icons.balance_rounded;
    }
  }

  static Color _colorFromDynamic(dynamic value) {
    if (value is int) {
      return Color(value);
    }

    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return const Color(0xFF0D2345);
    }

    final normalized = raw.replaceAll('#', '').toUpperCase();
    final withAlpha = normalized.length == 6 ? 'FF$normalized' : normalized;
    final parsed = int.tryParse(withAlpha, radix: 16);
    if (parsed == null) {
      return const Color(0xFF0D2345);
    }
    return Color(parsed);
  }
}

class _UserDashboardPayload {
  final String userName;
  final List<_UserCategory> categories;
  final List<_LawyerProfile> topLawyers;
  final List<_ServiceItem> services;
  final String balance;

  const _UserDashboardPayload({
    required this.userName,
    required this.categories,
    required this.topLawyers,
    required this.services,
    required this.balance,
  });

  factory _UserDashboardPayload.empty({required String fallbackName}) {
    return _UserDashboardPayload(
      userName: fallbackName,
      categories: const <_UserCategory>[],
      topLawyers: const <_LawyerProfile>[],
      services: const <_ServiceItem>[],
      balance: 'EGP 0',
    );
  }
}

class _DataEmptyHint extends StatelessWidget {
  final String message;

  const _DataEmptyHint({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        message.translate(),
        style: TextStyle(
          color: Theme.of(
            context,
          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
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
