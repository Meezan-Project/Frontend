import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:collection';
import 'package:mezaan/shared/auth/auth_state.dart';
import 'package:mezaan/shared/auth/firebase_session_service.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/theme/theme_controller.dart';
import 'package:mezaan/user/screens/government_map_screen.dart';
import 'package:mezaan/lawyer/widgets/lawyer_bottom_nav_bar.dart';
import 'package:mezaan/lawyer/screens/lawyer_onboarding_screen.dart';
import 'package:mezaan/lawyer/widgets/lawyer_profile_side_panel.dart';
import 'package:mezaan/lawyer/widgets/lawyer_top_header.dart';
import 'dart:async';

class LawyerDashboardScreen extends StatefulWidget {
  const LawyerDashboardScreen({super.key});

  @override
  State<LawyerDashboardScreen> createState() => _LawyerDashboardScreenState();
}

class _LawyerDashboardScreenState extends State<LawyerDashboardScreen>
    with SingleTickerProviderStateMixin {
  String? _payloadLawyerUid;
  Future<_LawyerDashboardPayload>? _payloadFuture;
  late final AnimationController _sosPulseController;
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

  void _openProfilePanel({
    required String lawyerName,
    required String specialization,
    required String rating,
    String? profileImageUrl,
  }) {
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
                  child: LawyerProfileSidePanel(
                    lawyerName: lawyerName,
                    specialization: specialization,
                    rating: rating,
                    profileImageBytes: null,
                    profileImageUrl: profileImageUrl,
                    isDarkMode: ThemeController.instance.isDarkMode.value,
                    onDarkModeChanged: (value) {
                      ThemeController.instance.setDarkMode(value);
                      _profilePanelOverlayEntry?.markNeedsBuild();
                    },
                    onClose: _closeProfilePanel,
                    onEditProfile: () => _runPanelAction(() {
                      _showComingSoon('Edit Profile');
                    }),
                    onLanguage: () => _runPanelAction(() {
                      _showComingSoon('Language'.translate());
                    }),
                    onSchedule: () => _runPanelAction(() {
                      _showComingSoon('Schedule'.translate());
                    }),
                    onSettings: () => _runPanelAction(() {
                      _showComingSoon('Settings'.translate());
                    }),
                    onPrivacy: () => _runPanelAction(() {
                      _showComingSoon('Privacy Policy'.translate());
                    }),
                    onHelp: () => _runPanelAction(() {
                      _showComingSoon('Help'.translate());
                    }),
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

  Widget _buildDashboardView(_LawyerDashboardPayload payload) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
      children: [
        _LawyerHeroCard(lawyerName: payload.lawyerName),
        SizedBox(height: 16.h),
        _SectionHeader(
          title: 'Upcoming Schedule'.translate(),
          subtitle: 'Manage your appointments'.translate(),
        ),
        SizedBox(height: 10.h),
        if (payload.scheduledAppointments.isEmpty)
          const _DataEmptyHint(message: 'No scheduled appointments.')
        else
          _ScheduleCard(appointments: payload.scheduledAppointments),
        SizedBox(height: 12.h),
        _AIAssistantCard(
          onStartChat: () {
            LoadingNavigator.pushNamed(context, AppRoutes.userAiChat);
          },
        ),
        SizedBox(height: 12.h),
        _ServiceMapCard(
          onOpenMap: () {
            _openGovernmentMap();
          },
        ),
        SizedBox(height: 16.h),
        _SectionHeader(
          title: 'Active Cases'.translate(),
          subtitle: 'Your current case load'.translate(),
        ),
        SizedBox(height: 10.h),
        if (payload.activeCases.isEmpty)
          const _DataEmptyHint(message: 'No active cases.')
        else
          ...payload.activeCases.map((caseData) {
            return _CaseCard(caseTitle: caseData);
          }),
        SizedBox(height: 16.h),
        _SectionHeader(
          title: 'Statistics'.translate(),
          subtitle: 'Your performance metrics'.translate(),
        ),
        SizedBox(height: 10.h),
        _StatsCard(payload: payload),
      ],
    );
  }

  Widget _buildCurrentView(_LawyerDashboardPayload payload) {
    switch (_selectedIndex) {
      case 0:
        return _ScheduleView(appointments: payload.scheduledAppointments);
      case 1:
        return _CasesView(cases: payload.activeCases);
      case 3:
        return const _ChatView();
      case 2:
      default:
        return _buildDashboardView(payload);
    }
  }

  Future<_LawyerDashboardPayload> _loadPayloadForCurrentUser(User user) {
    if (_payloadFuture == null || _payloadLawyerUid != user.uid) {
      _payloadLawyerUid = user.uid;
      _payloadFuture = _LawyerDashboardRepository.loadForLawyer(user: user);
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

        return FutureBuilder<_LawyerDashboardPayload>(
          future: _loadPayloadForCurrentUser(currentUser),
          builder: (context, snapshot) {
            final payload =
                snapshot.data ??
                _LawyerDashboardPayload.empty(
                  fallbackName: currentUser.displayName ?? 'Lawyer',
                );

            if (snapshot.connectionState == ConnectionState.done &&
                !payload.onboardingCompleted) {
              return const LawyerOnboardingScreen();
            }

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
                              child: LawyerTopHeader(
                                rating: payload.rating,
                                pendingCases: payload.pendingCases,
                                onNotificationTap: () {
                                  _openProfilePanel(
                                    lawyerName: payload.lawyerName,
                                    specialization: payload.specialization,
                                    rating: payload.rating,
                                    profileImageUrl: payload.profilePhotoUrl,
                                  );
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
                  ],
                ),
              ),
              bottomNavigationBar:
                  snapshot.connectionState != ConnectionState.done
                  ? null
                  : LawyerBottomNavBar(
                      currentIndex: _selectedIndex,
                      onDestinationSelected: (index) {
                        if (index == 4) {
                          _openProfilePanel(
                            lawyerName: payload.lawyerName,
                            specialization: payload.specialization,
                            rating: payload.rating,
                            profileImageUrl: payload.profilePhotoUrl,
                          );
                          return;
                        }
                        setState(() => _selectedIndex = index);
                      },
                      onCenterButtonTap: () {
                        _showComingSoon('New Case'.translate());
                      },
                    ),
            );
          },
        );
      },
    );
  }
}

// Data Models
class _LawyerDashboardPayload {
  final String lawyerName;
  final String specialization;
  final String rating;
  final int pendingCases;
  final String profilePhotoUrl;
  final List<String> scheduledAppointments;
  final List<String> activeCases;
  final bool onboardingCompleted;

  _LawyerDashboardPayload({
    required this.lawyerName,
    required this.specialization,
    required this.rating,
    required this.pendingCases,
    required this.profilePhotoUrl,
    required this.scheduledAppointments,
    required this.activeCases,
    required this.onboardingCompleted,
  });

  factory _LawyerDashboardPayload.empty({required String fallbackName}) {
    return _LawyerDashboardPayload(
      lawyerName: fallbackName,
      specialization: 'General Law',
      rating: '4.8',
      pendingCases: 0,
      profilePhotoUrl: '',
      scheduledAppointments: const [],
      activeCases: const [],
      onboardingCompleted: false,
    );
  }
}

// Repository
class _LawyerDashboardRepository {
  static Future<_LawyerDashboardPayload> loadForLawyer({
    required User user,
  }) async {
    try {
      final lawyerDoc = await FirebaseFirestore.instance
          .collection('lawyers')
          .doc(user.uid)
          .get();

      if (!lawyerDoc.exists) {
        return _LawyerDashboardPayload.empty(
          fallbackName: user.displayName ?? 'Lawyer',
        );
      }

      final data = lawyerDoc.data() ?? {};
      final derivedSchedule = _extractScheduledAppointments(data['schedule']);
      final embeddedCases = _extractCaseTitles(data['activeCases']);

      final fetchedCasesResult = await _loadActiveCasesFromFirestore(
        lawyerUid: user.uid,
      );
      final mergedCases = LinkedHashSet<String>()
        ..addAll(embeddedCases)
        ..addAll(fetchedCasesResult.caseTitles);

      final pendingFromDoc = _asInt(data['pendingCases']);
      final pendingCount =
          pendingFromDoc ??
          (fetchedCasesResult.pendingCaseCount > 0
              ? fetchedCasesResult.pendingCaseCount
              : mergedCases.length);

      return _LawyerDashboardPayload(
        lawyerName: _extractLawyerName(data, fallback: user.displayName),
        specialization: _extractSpecialization(data),
        rating: _extractRating(data),
        pendingCases: pendingCount,
        profilePhotoUrl: _extractProfilePhotoUrl(data),
        scheduledAppointments: _extractScheduledAppointments(
          data['scheduledAppointments'],
          fallback: derivedSchedule,
        ),
        activeCases: mergedCases.toList(growable: false),
        onboardingCompleted: _isLawyerOnboardingComplete(data),
      );
    } catch (e) {
      debugPrint('Error loading lawyer payload: $e');
      return _LawyerDashboardPayload.empty(
        fallbackName: user.displayName ?? 'Lawyer',
      );
    }
  }

  static String _extractLawyerName(
    Map<String, dynamic> data, {
    String? fallback,
  }) {
    final firstName = _asString(data['first_name']);
    final secondName = _asString(data['second_name']);
    final snakeFullName = _joinNonEmpty([firstName, secondName]);

    return _firstNonEmpty([
          _asString(data['name']),
          snakeFullName,
          _asString(data['firstName']),
          fallback,
          'Lawyer',
        ]) ??
        'Lawyer';
  }

  static String _extractSpecialization(Map<String, dynamic> data) {
    final specializationText = _asString(data['specializationText']);
    final specializationDynamic = data['specialization'];

    if (specializationDynamic is List) {
      final values = specializationDynamic
          .map((item) => _asString(item))
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toList(growable: false);

      if (values.isNotEmpty) {
        return values.join(', ');
      }
    }

    return _firstNonEmpty([
          specializationText,
          _asString(specializationDynamic),
          'General Law',
        ]) ??
        'General Law';
  }

  static String _extractRating(Map<String, dynamic> data) {
    final ratingValue = data['rating'];
    if (ratingValue is num) {
      if (ratingValue % 1 == 0) {
        return ratingValue.toInt().toString();
      }
      return ratingValue.toStringAsFixed(1);
    }

    final raw = _asString(ratingValue);
    if (raw == null || raw.isEmpty) {
      return '0.0';
    }

    final parsed = double.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    return parsed.toStringAsFixed(1);
  }

  static String _extractProfilePhotoUrl(Map<String, dynamic> data) {
    return _firstNonEmpty([
          _asString(data['profilePhotoUrl']),
          _asString(data['profile_photo']),
        ]) ??
        '';
  }

  static bool _isLawyerOnboardingComplete(Map<String, dynamic> data) {
    final onboardingFlag = data['onboardingCompleted'] == true;
    final workStatus = _asString(data['work_status']);
    final bio = _asString(data['professional_bio']);
    final yearsOfExperience = _asInt(data['years_of_experience']);
    final scheduleRaw = data['schedule'];

    final hasSchedule =
        scheduleRaw is Map && scheduleRaw.isNotEmpty ||
        (scheduleRaw is List && scheduleRaw.isNotEmpty);

    final hasCoreData =
        workStatus != null &&
        workStatus.isNotEmpty &&
        bio != null &&
        bio.isNotEmpty &&
        yearsOfExperience != null &&
        yearsOfExperience >= 0 &&
        hasSchedule;

    if (!onboardingFlag || !hasCoreData) {
      return false;
    }

    if (workStatus == 'Works in an Office') {
      return (_asString(data['employer_lawyer_name']) ?? '').isNotEmpty;
    }

    if (workStatus == 'Owns an Office') {
      final officeDetails = data['office_details'];
      if (officeDetails is! Map) {
        return false;
      }
      final governorate = _asString(officeDetails['governorate']);
      final city = _asString(officeDetails['city']);
      final address = _asString(officeDetails['address']);
      final phone = _asString(officeDetails['phone']);
      return governorate != null &&
          city != null &&
          address != null &&
          phone != null &&
          governorate.isNotEmpty &&
          city.isNotEmpty &&
          address.isNotEmpty &&
          phone.isNotEmpty;
    }

    return true;
  }

  static List<String> _extractScheduledAppointments(
    dynamic value, {
    List<String> fallback = const [],
  }) {
    if (value is List) {
      final items = value
          .map((entry) => _asString(entry))
          .whereType<String>()
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
      if (items.isNotEmpty) {
        return items;
      }
    }

    if (value is Map) {
      final entries = <String>[];
      value.forEach((dayKey, dayValue) {
        if (dayValue is! Map) {
          return;
        }

        final selected = dayValue['selected'] == true;
        if (!selected) {
          return;
        }

        final fromTime = _asString(dayValue['from']) ?? '--:--';
        final toTime = _asString(dayValue['to']) ?? '--:--';
        final day = dayKey.toString().trim();
        if (day.isEmpty) {
          return;
        }

        entries.add('$day: $fromTime - $toTime');
      });

      if (entries.isNotEmpty) {
        return entries;
      }
    }

    return fallback;
  }

  static List<String> _extractCaseTitles(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((entry) {
          if (entry is Map) {
            return _firstNonEmpty([
              _asString(entry['title']),
              _asString(entry['caseNumber']),
              _asString(entry['name']),
            ]);
          }
          return _asString(entry);
        })
        .whereType<String>()
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  static Future<_FirestoreCasesResult> _loadActiveCasesFromFirestore({
    required String lawyerUid,
  }) async {
    final caseTitles = LinkedHashSet<String>();
    var pendingCaseCount = 0;

    Future<void> readQuery(Query<Map<String, dynamic>> query) async {
      try {
        final snapshot = await query.limit(50).get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final title = _firstNonEmpty([
            _asString(data['title']),
            _asString(data['caseNumber']),
            _asString(data['name']),
            doc.id,
          ]);

          if (title != null && title.isNotEmpty) {
            caseTitles.add(title);
          }

          final status = (_asString(data['status']) ?? '').toLowerCase();
          if (status == 'pending' || status == 'on_hold') {
            pendingCaseCount += 1;
          }
        }
      } catch (e) {
        debugPrint('Lawyer cases query skipped: $e');
      }
    }

    await readQuery(
      FirebaseFirestore.instance
          .collection('cases')
          .where('lawyerId', isEqualTo: lawyerUid),
    );

    await readQuery(
      FirebaseFirestore.instance
          .collectionGroup('cases')
          .where('lawyerId', isEqualTo: lawyerUid),
    );

    return _FirestoreCasesResult(
      caseTitles: caseTitles.toList(growable: false),
      pendingCaseCount: pendingCaseCount,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static String? _asString(dynamic value) {
    if (value == null) {
      return null;
    }
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String _joinNonEmpty(List<String?> values) {
    final items = values
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return items.join(' ').trim();
  }
}

class _FirestoreCasesResult {
  final List<String> caseTitles;
  final int pendingCaseCount;

  const _FirestoreCasesResult({
    required this.caseTitles,
    required this.pendingCaseCount,
  });
}

// Widgets
class _LawyerHeroCard extends StatelessWidget {
  final String lawyerName;

  const _LawyerHeroCard({required this.lawyerName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF162235) : Colors.white;

    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334766) : const Color(0xFFE5E7EB),
          width: 1.w,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
            blurRadius: 14,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome Back!'.translate(),
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF9FB0CA) : const Color(0xFF98A3B3),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            lawyerName,
            style: GoogleFonts.cairo(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.navyBlue,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'You have pending cases waiting for you'.translate(),
            style: GoogleFonts.cairo(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF9FB0CA) : const Color(0xFF98A3B3),
            ),
          ),
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.navyBlue,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          subtitle,
          style: GoogleFonts.cairo(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF9FB0CA) : const Color(0xFF98A3B3),
          ),
        ),
      ],
    );
  }
}

class _DataEmptyHint extends StatelessWidget {
  final String message;

  const _DataEmptyHint({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF182A42) : const Color(0xFFF0F4FA),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334766) : const Color(0xFFDCE6F5),
        ),
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.cairo(
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF9FB0CA) : const Color(0xFF98A3B3),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final List<String> appointments;

  const _ScheduleCard({required this.appointments});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF162235) : Colors.white;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334766) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.04),
            blurRadius: 8,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < appointments.take(3).length; i++) ...[
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: AppColors.navyBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.schedule_rounded,
                    color: AppColors.navyBlue,
                    size: 18.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    appointments[i],
                    style: GoogleFonts.cairo(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.navyBlue,
                    ),
                  ),
                ),
              ],
            ),
            if (i < appointments.take(3).length - 1)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Divider(
                  color: isDark
                      ? const Color(0xFF334766)
                      : const Color(0xFFE5E7EB),
                  height: 1.h,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AIAssistantCard extends StatelessWidget {
  final VoidCallback onStartChat;

  const _AIAssistantCard({required this.onStartChat});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onStartChat,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.navyBlue.withValues(alpha: 0.95),
              const Color(0xFF1E40AF).withValues(alpha: 0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.navyBlue.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Legal Assistant'.translate(),
                    style: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Chat about your cases and get insights'.translate(),
                    style: GoogleFonts.cairo(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20.sp),
          ],
        ),
      ),
    );
  }
}

class _ServiceMapCard extends StatelessWidget {
  final VoidCallback onOpenMap;

  const _ServiceMapCard({required this.onOpenMap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF162235) : Colors.white;

    return GestureDetector(
      onTap: onOpenMap,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isDark ? const Color(0xFF334766) : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.04),
              blurRadius: 8,
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: const Color(0xFF10B981),
                size: 24.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Government Services Map'.translate(),
                    style: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.navyBlue,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Find nearby government offices'.translate(),
                    style: GoogleFonts.cairo(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFF9FB0CA)
                          : const Color(0xFF98A3B3),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              color: isDark ? Colors.white70 : AppColors.navyBlue,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  final String caseTitle;

  const _CaseCard({required this.caseTitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF162235) : Colors.white;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334766) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.folder_open_rounded,
              color: const Color(0xFF7C3AED),
              size: 18.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              caseTitle,
              style: GoogleFonts.cairo(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.navyBlue,
              ),
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14.sp,
            color: isDark ? Colors.white54 : Colors.grey,
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final _LawyerDashboardPayload payload;

  const _StatsCard({required this.payload});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF162235) : Colors.white;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334766) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.04),
            blurRadius: 8,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  payload.rating,
                  style: GoogleFonts.cairo(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFC107),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Rating'.translate(),
                  style: GoogleFonts.cairo(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF9FB0CA)
                        : const Color(0xFF98A3B3),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1.h,
            height: 40.h,
            color: isDark ? const Color(0xFF334766) : const Color(0xFFE5E7EB),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${payload.activeCases.length}',
                  style: GoogleFonts.cairo(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navyBlue,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Active Cases'.translate(),
                  style: GoogleFonts.cairo(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF9FB0CA)
                        : const Color(0xFF98A3B3),
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

// View Pages
class _ScheduleView extends StatelessWidget {
  final List<String> appointments;

  const _ScheduleView({required this.appointments});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
      children: [
        if (appointments.isEmpty)
          const Center(
            child: _DataEmptyHint(message: 'No scheduled appointments yet.'),
          )
        else
          ...appointments.map((apt) => _ScheduleItemWidget(title: apt)),
      ],
    );
  }
}

class _ScheduleItemWidget extends StatelessWidget {
  final String title;

  const _ScheduleItemWidget({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162235) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334766) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: AppColors.navyBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.schedule_rounded,
              color: AppColors.navyBlue,
              size: 18.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CasesView extends StatelessWidget {
  final List<String> cases;

  const _CasesView({required this.cases});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
      children: [
        if (cases.isEmpty)
          const Center(child: _DataEmptyHint(message: 'No active cases.'))
        else
          ...cases.map((caseData) => _CaseCard(caseTitle: caseData)),
      ],
    );
  }
}

class _ChatView extends StatelessWidget {
  const _ChatView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64.sp,
            color: Colors.grey,
          ),
          SizedBox(height: 16.h),
          Text(
            'AI Chat Feature'.translate(),
            style: GoogleFonts.cairo(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Coming soon'.translate(),
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
