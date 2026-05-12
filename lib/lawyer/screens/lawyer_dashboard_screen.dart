import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'package:mezaan/lawyer/widgets/lawyer_top_header.dart';
import 'package:mezaan/lawyer/widgets/lawyer_side_drawer.dart';
import 'package:mezaan/lawyer/screens/lawyer_templates_screen.dart';
import 'package:mezaan/lawyer/screens/lawyer_legal_library_screen.dart';
import 'package:mezaan/lawyer/screens/lawyer_conflict_checker_screen.dart';
import 'package:mezaan/lawyer/screens/lawyer_case_management_screen.dart';
import 'package:mezaan/user/models/case_model.dart';
import 'dart:async';

class LawyerDashboardScreen extends StatefulWidget {
  const LawyerDashboardScreen({super.key});

  @override
  State<LawyerDashboardScreen> createState() => _LawyerDashboardScreenState();
}

class _LawyerDashboardScreenState extends State<LawyerDashboardScreen>
    with SingleTickerProviderStateMixin {
  String? _payloadLawyerUid;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // Step A: Create GlobalKey
  Future<_LawyerDashboardPayload>? _payloadFuture;
  late final AnimationController _sosPulseController;
  int _selectedIndex = 3;
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

  Future<void> _refreshDashboard() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _payloadFuture = _LawyerDashboardRepository.loadForLawyer(user: user));
    }
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

  void _showAddCaseModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddCaseSheet(),
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
    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
        children: [
          _LawyerHeroCard(lawyerName: payload.lawyerName),
          SizedBox(height: 16.h),
          _SectionHeader(
            title: 'Upcoming Schedule'.translate(),
            subtitle: 'Manage your appointments'.translate(),
          ),
          SizedBox(height: 10.h),
          _UpcomingScheduleSection(),
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
              return _CaseCard(case_: caseData);
            }),
          SizedBox(height: 16.h),
          _SectionHeader(
            title: 'Statistics'.translate(),
            subtitle: 'Your performance metrics'.translate(),
          ),
          SizedBox(height: 10.h),
          _StatsCard(payload: payload),
        ],
      ),
    );
  }

  Widget _buildCurrentView(_LawyerDashboardPayload payload) {
    switch (_selectedIndex) {
      case 0:
        return const _RescueView();
      case 1:
        return const _ScheduleView();
      case 2:
        return const _CasesView();
      case 3:
        return _buildDashboardView(payload);
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

  Widget _buildBodyContent(
    AsyncSnapshot<_LawyerDashboardPayload> snapshot,
    _LawyerDashboardPayload payload,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
                child: LawyerTopHeader(rating: payload.rating, pendingCases: payload.pendingCases, onNotificationTap: () {}),
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
    );
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
            final payload = snapshot.data ??
                _LawyerDashboardPayload.empty(
                  fallbackName: currentUser.displayName ?? 'Lawyer',
                );

            if (snapshot.connectionState == ConnectionState.done &&
                !payload.onboardingCompleted) {
              return LawyerOnboardingScreen();
            }

            return Scaffold(
              key: _scaffoldKey, // Step A: Key used for Drawer
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              endDrawer: LawyerSideDrawer(
                lawyerName: payload.lawyerName,
                profileImageUrl: payload.profilePhotoUrl,
                specialties: payload.specialization,
                rating: payload.rating,
                templatesCount: 12, documentsCount: 8, hasConflict: false,
                isDarkMode: ThemeController.instance.isDarkMode.value,
                currentLanguage: 'English',
                onDarkModeChanged: (value) => ThemeController.instance.setDarkMode(value),
                onManageSchedule: () {
                  Navigator.pop(context);
                  _showComingSoon('Manage Schedule'.translate());
                },
                onQuickTemplates: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LawyerTemplatesScreen()));
                },
                onLegalLibrary: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LawyerLegalLibraryScreen()));
                },
                onConflictChecker: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LawyerConflictCheckerScreen()));
                },
                onPrivacyPolicy: () => _runPanelAction(() => _showComingSoon('Privacy'.translate())),
                onHelpSupport: () => _runPanelAction(() => _showComingSoon('Support'.translate())),
                onLogout: () => _handleLogout(),
                onLanguageChanged: (lang) => _runPanelAction(() => _showComingSoon('Lang: $lang'.translate())),
              ),
              floatingActionButton: _selectedIndex == 2
                  ? FloatingActionButton.extended(
                      onPressed: _showAddCaseModal,
                      backgroundColor: const Color(0xFF001F3F),
                      icon: const Icon(Icons.add_rounded, color: Color(0xFFFFD700)),
                      label: Text(
                        'Add Case'.translate(),
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    )
                  : null,
              body: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark 
                        ? [const Color(0xFF0B1220), const Color(0xFF131C2C)] 
                        : [const Color(0xFFF8FAFE), const Color(0xFFF1F6FF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: _buildBodyContent(snapshot, payload),
              ),
              bottomNavigationBar: snapshot.connectionState != ConnectionState.done
                  ? null
                  : LawyerBottomNavBar(
                      currentIndex: _selectedIndex,
                      onDestinationSelected: (index) {
                        setState(() => _selectedIndex = index);
                      },
                      onOpenDrawer: () => _scaffoldKey.currentState?.openEndDrawer(),
                    ),
            );
          },
        );
      },
    );
  }
}

class _RescueView extends StatelessWidget {
  const _RescueView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.radar_rounded,
            size: 64.sp,
            color: Colors.redAccent,
          ),
          SizedBox(height: 16.h),
          Text(
            'Rescue Mode'.translate(),
            style: GoogleFonts.cairo(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Waiting for emergency requests...'.translate(),
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

// Data Models
class _LawyerDashboardPayload {
  final String lawyerName;
  final String specialization;
  final String rating;
  final int pendingCases;
  final String profilePhotoUrl;
  final List<String> scheduledAppointments;
  final List<UserCase> activeCases;
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
      activeCases: const <UserCase>[],
      onboardingCompleted: false,
    );
  }
}

// Upcoming Schedule Section with StreamBuilder
class _UpcomingScheduleSection extends StatelessWidget {
  const _UpcomingScheduleSection();

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const _DataEmptyHint(message: 'User not logged in.');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('lawyerId', isEqualTo: currentUser.uid)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _DataEmptyHint(message: 'Error loading appointments.');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final appointments = snapshot.data?.docs ?? [];

        if (appointments.isEmpty) {
          return const _DataEmptyHint(message: 'No scheduled appointments.');
        }

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
                color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
                blurRadius: 8,
                offset: Offset(0, 2.h),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < appointments.length; i++) ...[
                Builder(
                  builder: (context) {
                    final doc = appointments[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final clientName = data['clientName'] as String? ?? 'Unknown Client';
                    final appointmentTime = data['appointmentTime'] as String? ?? 'Time not set';
                    final day = data['day'] as String? ?? 'Date not set';

                    return Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: AppColors.navyBlue.withOpacity(0.1),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clientName,
                                style: GoogleFonts.cairo(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AppColors.navyBlue,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                '$day | $appointmentTime',
                                style: GoogleFonts.cairo(
                                  fontSize: 11.sp,
                                  color: isDark ? Colors.white70 : Colors.grey[600]!,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (i < appointments.length - 1)
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
      },
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
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 15));

      if (!lawyerDoc.exists) {
        return _LawyerDashboardPayload.empty(
          fallbackName: user.displayName ?? 'Lawyer',
        );
      }

      final data = lawyerDoc.data() ?? {};
      final derivedSchedule = _extractScheduledAppointments(data['schedule']);

      // Hardcoded professional dummy data to showcase the UI as requested
      final List<UserCase> dummyCases = [
        UserCase(
          id: 'CASE-2024-001', // Unique ID for the case
          lawyerId: 'lawyer_admin_01', // Dummy lawyer ID
          caseNumber: 'CASE-2024-001',
          title: 'Real Estate Dispute',
          description: 'Conflict regarding commercial property ownership in New Cairo.',
          category: 'Civil',
          status: 'active',
          createdDate: DateTime(2024, 2, 12),
          lawyerName: 'Client: Ahmed Aly',
          requiredDocuments: List.generate(4, (i) => RequiredDocument(id: '$i', name: 'Deed', description: '', isSubmitted: false)),
          sessions: List.generate(2, (i) => CaseSession(id: '$i', scheduledDate: DateTime.now(), status: 'scheduled')),
          updates: [],
        ),
        UserCase(
          id: 'CASE-2024-005', // Unique ID for the case
          lawyerId: 'lawyer_admin_01', // Dummy lawyer ID
          caseNumber: 'CASE-2024-005',
          title: 'IP Rights Review',
          description: 'Copyright infringement investigation for a tech startup mobile app.',
          category: 'Corporate',
          status: 'pending',
          createdDate: DateTime(2024, 3, 05),
          lawyerName: 'Client: Tech Nile Inc.',
          requiredDocuments: List.generate(2, (i) => RequiredDocument(id: '$i', name: 'License', description: '', isSubmitted: false)),
          sessions: List.generate(1, (i) => CaseSession(id: '$i', scheduledDate: DateTime.now(), status: 'scheduled')),
          updates: [],
        ),
        UserCase(
          id: 'CASE-2024-012', // Unique ID for the case
          lawyerId: 'lawyer_admin_01', // Dummy lawyer ID
          caseNumber: 'CASE-2024-012',
          title: 'Labor Contract Breach',
          description: 'Investigation into employee non-compete clause violations.',
          category: 'Labor',
          status: 'active',
          createdDate: DateTime(2024, 4, 18),
          lawyerName: 'Client: Modern Cairo Co.',
          requiredDocuments: List.generate(6, (i) => RequiredDocument(id: '$i', name: 'Contract', description: '', isSubmitted: true)),
          sessions: List.generate(3, (i) => CaseSession(id: '$i', scheduledDate: DateTime.now(), status: 'scheduled')),
          updates: [],
        ),
      ];

      final pendingFromDoc = _asInt(data['pendingCases']);
      final pendingCount =
          pendingFromDoc ??
          dummyCases.where((c) => c.status != 'active').length;

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
        activeCases: dummyCases,
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
    final caseTitles = <String>{};
    var pendingCaseCount = 0;

    Future<void> readQuery(Query<Map<String, dynamic>> query) async {
      try {
        final snapshot = await query.limit(50)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 10));
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
            color: Colors.black.withOpacity(isDark ? 0.22 : 0.04),
            blurRadius: 14, // Corrected withValues to withOpacity
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
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
            blurRadius: 8,
            offset: Offset(0, 2.h), // Corrected withValues to withOpacity
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
                    color: AppColors.navyBlue.withOpacity(0.1),
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
    return GestureDetector(
      onTap: onStartChat,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.navyBlue.withOpacity(0.95),
              const Color(0xFF1E40AF).withOpacity(0.95), // Corrected withValues to withOpacity
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.navyBlue.withOpacity(0.2), // Corrected withValues to withOpacity
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
              color: Colors.white.withOpacity(0.25), // Corrected withValues to withOpacity
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
              color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
              blurRadius: 8, // Corrected withValues to withOpacity
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15), // Corrected withValues to withOpacity
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
  final UserCase case_;

  const _CaseCard({required this.case_});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A2940) : Colors.white;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LawyerCaseDetailsScreen(
              case_: case_,
              isLawyer: true,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  case_.caseNumber,
                  style: GoogleFonts.cairo(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.legalGold,
                  ),
                ),
                _buildStatusBadge(case_.status),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              case_.title,
              style: GoogleFonts.cairo(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.navyBlue,
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                _buildStatIcon(Icons.description_outlined, '${case_.requiredDocuments.length} Documents'),
                SizedBox(width: 16.w),
                _buildStatIcon(Icons.gavel_outlined, '${case_.sessions.length} Sessions'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final bool isActive = status.toLowerCase() == 'active';
    final Color badgeColor = isActive ? Colors.green : Colors.orange;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.cairo(
          fontSize: 10.sp,
          fontWeight: FontWeight.w900,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildStatIcon(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14.sp, color: Colors.grey[500]),
        SizedBox(width: 4.w),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
      ],
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
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
            blurRadius: 8, // Corrected withValues to withOpacity
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
  const _ScheduleView();

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Center(child: Text('User not logged in'.translate()));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('lawyerId', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: _DataEmptyHint(message: 'Error loading schedule.'.translate()));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final appointments = snapshot.data?.docs ?? [];

        if (appointments.isEmpty) {
          return Center(
            child: _DataEmptyHint(message: 'No scheduled appointments yet.'.translate()),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final data = appointments[index].data() as Map<String, dynamic>;
            final clientName = data['clientName'] as String? ?? 'Unknown Client';
            final time = data['appointmentTime'] as String? ?? '--:--';
            final day = data['day'] as String? ?? 'Date not set';

            return _ScheduleItemWidget(
              title: clientName,
              subtitle: '$day | $time',
            );
          },
        );
      },
    );
  }
}

class _ScheduleItemWidget extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ScheduleItemWidget({
    required this.title,
    required this.subtitle,
  });

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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
            blurRadius: 8,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: AppColors.navyBlue.withOpacity(0.1),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.navyBlue,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    fontSize: 11.sp,
                    color: isDark ? Colors.white70 : Colors.grey[600],
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

class _CasesView extends StatelessWidget {
  const _CasesView();

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cases')
          .where('lawyerId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: _DataEmptyHint(message: 'Error loading cases.'.translate()));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: _DataEmptyHint(message: 'No active cases.'.translate()));
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final caseData = UserCase(
              id: docs[index].id,
              lawyerId: data['lawyerId'] ?? '',
              caseNumber: data['caseNumber'] ?? 'N/A',
              title: data['title'] ?? 'Untitled',
              description: data['description'] ?? '',
              category: data['category'] ?? 'Civil',
              status: data['status'] ?? 'pending',
              createdDate: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              lawyerName: '', // Placeholder as fetching client name would require a separate query
              requiredDocuments: [],
              sessions: [],
              updates: [],
            );
            return _CaseCard(case_: caseData);
          },
        );
      },
    );
  }
}

// _ChatView class removed - was unused

class _AddCaseSheet extends StatefulWidget {
  const _AddCaseSheet();

  @override
  State<_AddCaseSheet> createState() => _AddCaseSheetState();
}

class _AddCaseSheetState extends State<_AddCaseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final String _caseNumber;

  final _phoneController = TextEditingController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _feesController = TextEditingController();

  String _selectedCategory = 'Civil';
  Map<String, dynamic>? _selectedClient;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _caseNumber = 'CASE-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _feesController.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String value) async {
    if (value.length < 3) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final querySnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'client')
          .where('phone', isGreaterThanOrEqualTo: value)
          .where('phone', isLessThanOrEqualTo: '$value\uf8ff')
          .limit(5)
          .get();

      setState(() {
        _searchResults = querySnap.docs.map((doc) => {...doc.data(), 'uid': doc.id}).toList();
      });
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _submitCase() async {
    if (!_formKey.currentState!.validate()) return;
    debugPrint(">>> Create Case Button Tapped! <<<");

    // Check form validation
    final isValid = _formKey.currentState?.validate() ?? false;
    debugPrint("Form Validation Status: $isValid");
    if (!isValid) {
      debugPrint("Stopping: Form validation failed.");
      return;
    }

    if (_selectedClient == null) {
      debugPrint("Stopping: No client selected.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a client'.translate())),
      );
      return;
    }

    if (_isSubmitting) {
      debugPrint("Warning: Submission already in progress (Async Lock).");
      return;
    }

    setState(() => _isSubmitting = true);

    debugPrint("Submitting to Firebase...");
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("Error: No authenticated user found.");
        return;
      }

      final casePayload = {
        'caseNumber': _caseNumber,
        'clientId': _selectedClient!['uid'],
        'lawyerId': user.uid,
        'title': _titleController.text.trim(),
        'status': 'pending_payment',
        'category': _selectedCategory,
        'description': _descController.text.trim(),
        'legalFees': double.tryParse(_feesController.text) ?? 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      };

      debugPrint("Payload: $casePayload");

      await FirebaseFirestore.instance.collection('cases').add(casePayload);

      debugPrint("Success: Document added to Firestore.");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Case linked successfully'.translate())),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Firebase Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'.translate())),
      );
    } finally {
      debugPrint("Resetting isSubmitting state.");
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputBg = isDark ? const Color(0xFF1A2940) : Colors.grey[50]!;
    final labelStyle = GoogleFonts.cairo(
      fontSize: 13.sp,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white70 : const Color(0xFF001F3F),
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1419) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Text('Add New Case'.translate(), style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.w800)),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, MediaQuery.of(context).viewInsets.bottom + 20.h),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Generated ID
                    Text('Case Number'.translate(), style: labelStyle),
                    SizedBox(height: 6.h),
                    TextFormField(
                      initialValue: _caseNumber,
                      readOnly: true,
                      decoration: _inputDeco(inputBg, Icons.confirmation_number_outlined),
                      style: GoogleFonts.cairo(color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20.h),

                    // Section 2: Client Search
                    Text('Search Client by Phone'.translate(), style: labelStyle),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _phoneController,
                      onChanged: _onSearchChanged,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDeco(inputBg, Icons.person_search_outlined).copyWith(
                        suffixIcon: _isSearching ? Padding(padding: EdgeInsets.all(12.r), child: const CircularProgressIndicator(strokeWidth: 2)) : null,
                      ),
                    ),
                    if (_searchResults.isNotEmpty && _selectedClient == null)
                      Container(
                        margin: EdgeInsets.only(top: 8.h),
                        decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: const Color(0xFFFFD700))),
                        child: Column(
                          children: _searchResults.map((user) => ListTile(
                            title: Text('${user['first_name'] ?? ''} ${user['second_name'] ?? ''}', style: GoogleFonts.cairo(fontSize: 14.sp)),
                            subtitle: Text(user['phone'] ?? '', style: GoogleFonts.cairo(fontSize: 12.sp)),
                            onTap: () => setState(() {
                              _selectedClient = user;
                              _searchResults = [];
                            }),
                          )).toList(),
                        ),
                      ),
                    if (_selectedClient != null) ...[
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.1), borderRadius: BorderRadius.circular(12.r)),
                        child: Column(
                          children: [
                            _buildReadOnlyRow(Icons.person, 'Client Name'.translate(), '${_selectedClient!['first_name'] ?? ''} ${_selectedClient!['second_name'] ?? ''}'),
                            _buildReadOnlyRow(Icons.phone, 'Phone'.translate(), _selectedClient!['phone'] ?? ''),
                            _buildReadOnlyRow(Icons.badge, 'National ID'.translate(), _selectedClient!['national_id'] ?? 'N/A'),
                            TextButton(onPressed: () => setState(() => _selectedClient = null), child: Text('Clear Selection'.translate(), style: const TextStyle(color: Colors.red))),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 20.h),

                    // Section 3: Specifications
                    Text('Case Title'.translate(), style: labelStyle),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _titleController,
                      decoration: _inputDeco(inputBg, Icons.title_rounded),
                      validator: (v) => v!.isEmpty ? 'Required'.translate() : null,
                    ),
                    SizedBox(height: 16.h),
                    Text('Status'.translate(), style: labelStyle),
                    SizedBox(height: 6.h),
                    TextFormField(
                      initialValue: 'pending_payment'.translate(),
                      readOnly: true,
                      decoration: _inputDeco(inputBg, Icons.hourglass_empty_rounded),
                    ),
                    SizedBox(height: 16.h),
                    Text('Category'.translate(), style: labelStyle),
                    SizedBox(height: 6.h),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      items: ['Civil', 'Criminal', 'Family', 'Commercial', 'Labor', 'Real Estate']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e.translate())))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                      decoration: _inputDeco(inputBg, Icons.list_alt_rounded),
                    ),
                    SizedBox(height: 20.h),

                    // Section 4: Details & Fees
                    Text('Description'.translate(), style: labelStyle),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _descController,
                      maxLines: 4,
                      decoration: _inputDeco(inputBg, Icons.description_outlined),
                    ),
                    SizedBox(height: 16.h),
                    Text('Legal Fees (EGP)'.translate(), style: labelStyle),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _feesController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDeco(inputBg, Icons.account_balance_wallet_outlined),
                      validator: (v) => v!.isEmpty ? 'Required'.translate() : null,
                    ),
                    SizedBox(height: 32.h),

                    SizedBox(
                      width: double.infinity,
                      height: 54.h,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitCase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF001F3F),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                        ),
                        child: _isSubmitting 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text('Create Case'.translate(), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(Color bg, IconData icon) {
    return InputDecoration(
      filled: true,
      fillColor: bg,
      prefixIcon: Icon(icon, color: const Color(0xFFFFD700), size: 20.sp),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: Colors.grey.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFFFFD700))),
    );
  }

  Widget _buildReadOnlyRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: const Color(0xFF001F3F)),
          SizedBox(width: 8.w),
          Text('$label: ', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13.sp)),
          Expanded(child: Text(value, style: GoogleFonts.cairo(fontSize: 13.sp), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
