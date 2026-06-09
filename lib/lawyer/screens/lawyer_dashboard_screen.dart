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
import 'package:flutter_typeahead/flutter_typeahead.dart';
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
import 'package:mezaan/user/screens/video_call_screen.dart';
import 'package:mezaan/lawyer/screens/lawyer_chat_screen.dart';
import 'package:mezaan/lawyer/screens/lawyer_calendar_schedule_screen.dart';
import 'package:mezaan/lawyer/screens/freelancer_join_screen.dart';
import 'package:mezaan/lawyer/screens/employee_office_view.dart';
import 'package:mezaan/lawyer/screens/owner_office_management_screen.dart';
import 'package:mezaan/lawyer/screens/lawyer_rescue_screen.dart';
import 'dart:async';

class LawyerDashboardScreen extends StatefulWidget {
  const LawyerDashboardScreen({super.key});

  @override
  State<LawyerDashboardScreen> createState() => _LawyerDashboardScreenState();
}

class _LawyerDashboardScreenState extends State<LawyerDashboardScreen>
    with SingleTickerProviderStateMixin {
  String? _payloadLawyerUid;
  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>(); // Step A: Create GlobalKey
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
      setState(
        () => _payloadFuture = _LawyerDashboardRepository.loadForLawyer(
          user: user,
        ),
      );
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

  void _showAddCaseModal(String lawyerName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddCaseSheet(lawyerName: lawyerName),
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
        return const LawyerRescueScreen();
      case 1:
        return const _CasesView();
      case 2:
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return const Center(child: CircularProgressIndicator());
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('lawyers')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const FreelancerJoinScreen();
            }

            final lawyerData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            
            String officeRole = 'freelancer';
            String? officeId;

            final workStatusRaw = (lawyerData['work_status'] ?? '').toString().trim().toLowerCase();
            final isOwner = workStatusRaw.contains('owns') || workStatusRaw.contains('owner') || workStatusRaw == 'own office';
            final isEmployee = workStatusRaw.contains('work') || workStatusRaw.contains('employee');

            if (isOwner) {
              officeRole = 'owner';
              officeId = lawyerData['officeId'] ?? user.uid;
            } else if (isEmployee) {
              officeRole = 'employee';
              officeId = lawyerData['officeId'] ?? lawyerData['employer_lawyer_id'];
            } else {
              officeId = lawyerData['officeId'];
              officeRole = lawyerData['officeRole'] ?? 'freelancer';
            }

            if (officeId == null || officeRole == 'freelancer') {
              return const FreelancerJoinScreen();
            } else if (officeRole == 'owner') {
              return OwnerOfficeManagementScreen(officeId: officeId);
            } else if (officeRole == 'employee') {
              return EmployeeOfficeView(officeId: officeId);
            } else {
              return const FreelancerJoinScreen();
            }
          },
        );
      case 4:
        return const _MessagesView();
      case 5:
        return const LawyerCalendarScheduleScreen();
      case 3:
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
                child: LawyerTopHeader(
                  rating: payload.rating,
                  pendingCases: payload.pendingCases,
                  onNotificationTap: () {
                    _showNotificationsSheet();
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
    );
  }

  void _showNotificationsSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.symmetric(vertical: 20.h),
        child: Column(
          children: [
            Container(
              width: 40.w,
              height: 5.h,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Notifications'.translate(),
              style: GoogleFonts.cairo(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navyBlue,
              ),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('notifications')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No notifications yet.'.translate(),
                        style: GoogleFonts.cairo(
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final docId = docs[index].id;

                      final title = data['title'] ?? 'Notification';
                      final body = data['body'] ?? '';
                      final isRead = data['isRead'] ?? false;
                      final type = data['type'] ?? '';
                      final referenceId = data['referenceId'] ?? '';
                      final createdAt = data['createdAt'] as Timestamp?;

                      String timeText = '';
                      if (createdAt != null) {
                        final diff = DateTime.now().difference(
                          createdAt.toDate(),
                        );
                        if (diff.inDays > 0) {
                          timeText = '${diff.inDays} ${'days ago'.translate()}';
                        } else if (diff.inHours > 0) {
                          timeText =
                              '${diff.inHours} ${'hours ago'.translate()}';
                        } else if (diff.inMinutes > 0) {
                          timeText =
                              '${diff.inMinutes} ${'minutes ago'.translate()}';
                        } else {
                          timeText = 'Just now'.translate();
                        }
                      }

                      IconData icon = Icons.notifications;
                      if (type == 'transaction') {
                        icon = Icons.account_balance_wallet;
                      }
                      if (type == 'lawyer_request') icon = Icons.event;
                      if (type == 'video_call') icon = Icons.video_call;

                      return _buildNotificationItem(
                        title: title,
                        body: body,
                        time: timeText,
                        isUnread: !isRead,
                        icon: icon,
                        isDark: isDark,
                        onTap: () async {
                          if (!isRead) {
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('notifications')
                                .doc(docId)
                                .update({'isRead': true});
                          }
                          Navigator.pop(context);

                          if (type == 'lawyer_request') {
                            setState(
                              () => _selectedIndex = 5,
                            ); // Go to Schedule View
                          } else if (type == 'video_call' &&
                              referenceId.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    VideoCallScreen(meetingId: referenceId),
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required String title,
    required String body,
    required String time,
    required bool isUnread,
    required IconData icon,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isUnread
              ? AppColors.legalGold.withValues(alpha: isDark ? 0.2 : 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isUnread
                ? AppColors.legalGold.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20.r,
              backgroundColor: AppColors.navyBlue.withValues(
                alpha: isDark ? 0.3 : 0.05,
              ),
              child: Icon(
                icon,
                color: isDark ? AppColors.legalGold : AppColors.navyBlue,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.cairo(
                            fontSize: 14.sp,
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.navyBlue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        time,
                        style: GoogleFonts.cairo(
                          fontSize: 10.sp,
                          color: Colors.grey,
                          fontWeight: isUnread
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    body,
                    style: GoogleFonts.cairo(
                      fontSize: 12.sp,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

        // If not logged in or role is not lawyer, redirect to login
        if (currentUser == null || authState.role != AppRole.lawyer) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            LoadingNavigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.login,
              (route) => false,
            );
          });
          return const Scaffold();
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
                templatesCount: 12,
                documentsCount: 8,
                hasConflict: false,
                isDarkMode: ThemeController.instance.isDarkMode.value,
                currentLanguage: 'English',
                onDarkModeChanged: (value) =>
                    ThemeController.instance.setDarkMode(value),
                onManageSchedule: () {
                  Navigator.pop(context);
                  _showComingSoon('Manage Schedule'.translate());
                },
                onQuickTemplates: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LawyerTemplatesScreen(),
                    ),
                  );
                },
                onLegalLibrary: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LawyerLegalLibraryScreen(),
                    ),
                  );
                },
                onConflictChecker: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LawyerConflictCheckerScreen(),
                    ),
                  );
                },
                onPrivacyPolicy: () => _runPanelAction(
                  () => _showComingSoon('Privacy'.translate()),
                ),
                onHelpSupport: () => _runPanelAction(
                  () => _showComingSoon('Support'.translate()),
                ),
                onLogout: () => _handleLogout(),
                onLanguageChanged: (lang) => _runPanelAction(
                  () => _showComingSoon('Lang: $lang'.translate()),
                ),
              ),
              floatingActionButton: _selectedIndex == 1
                  ? FloatingActionButton.extended(
                      onPressed: () => _showAddCaseModal(payload.lawyerName),
                      backgroundColor: const Color(0xFF001F3F),
                      icon: Icon(Icons.add_rounded, color: AppColors.legalGold),
                      label: Text(
                        'Add Case'.translate(),
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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
              bottomNavigationBar:
                  snapshot.connectionState != ConnectionState.done
                  ? null
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('lawyers')
                          .doc(currentUser.uid)
                          .collection('conversations')
                          .snapshots(),
                      builder: (context, convoSnapshot) {
                        int totalUnread = 0;
                        if (convoSnapshot.hasData) {
                          for (var doc in convoSnapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>?;
                            if (data != null) {
                              totalUnread += (data['unreadCount'] as num?)?.toInt() ?? 0;
                            }
                          }
                        }

                        return LawyerBottomNavBar(
                          currentIndex: _selectedIndex,
                          unreadCount: totalUnread,
                          onDestinationSelected: (index) {
                            setState(() => _selectedIndex = index);
                          },
                          onOpenDrawer: () =>
                              _scaffoldKey.currentState?.openEndDrawer(),
                        );
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

  DateTime? _parseAppointmentDateTime(String day, String time) {
    try {
      final dayParts = day.split(',');
      if (dayParts.length < 2) return null;
      final datePart = dayParts[1].trim(); // "16 May 2026"
      final date = DateTime.parse(_convertToIsoDate(datePart));
      final timeRange = time.split('-');
      final startTime = timeRange[0].trim(); // "06:25 PM"
      final timeOfDay = _parseTimeOfDay(startTime);
      if (timeOfDay == null) return null;
      return DateTime(
        date.year,
        date.month,
        date.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );
    } catch (_) {
      return null;
    }
  }

  String _convertToIsoDate(String datePart) {
    try {
      final parts = datePart.split(' ');
      if (parts.length != 3) return '';
      final day = parts[0].padLeft(2, '0');
      final month = _monthToNumber(parts[1]);
      final year = parts[2];
      return "$year-$month-$day";
    } catch (_) {
      return '';
    }
  }

  String _monthToNumber(String month) {
    switch (month.toLowerCase()) {
      case 'jan':
      case 'january':
        return '01';
      case 'feb':
      case 'february':
        return '02';
      case 'mar':
      case 'march':
        return '03';
      case 'apr':
      case 'april':
        return '04';
      case 'may':
        return '05';
      case 'jun':
      case 'june':
        return '06';
      case 'jul':
      case 'july':
        return '07';
      case 'aug':
      case 'august':
        return '08';
      case 'sep':
      case 'september':
        return '09';
      case 'oct':
      case 'october':
        return '10';
      case 'nov':
      case 'november':
        return '11';
      case 'dec':
      case 'december':
        return '12';
      default:
        return '01';
    }
  }

  TimeOfDay? _parseTimeOfDay(String time) {
    try {
      final match = RegExp(r'^(\d{1,2}):(\d{2})\s*([AP]M)').firstMatch(time);
      if (match == null) return null;
      int hour = int.parse(match.group(1)!);
      final int minute = int.parse(match.group(2)!);
      final String period = match.group(3)!;
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

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
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _DataEmptyHint(message: 'Error loading appointments.');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final appointments = snapshot.data?.docs.toList() ?? [];

        final now = DateTime.now();
        final activeAppointments = appointments.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['bookingStatus'] ?? data['status'] ?? 'pending';
          if (status == 'cancelled') return false;

          final appointmentDay = data['day'] ?? data['dateLabel'] ?? '';
          final appointmentTime = data['time'] ?? data['timeRange'] ?? '';
          if (appointmentDay.isEmpty || appointmentTime.isEmpty) return false;
          final dateTime = _parseAppointmentDateTime(appointmentDay, appointmentTime);
          if (dateTime == null) return false;
          return dateTime.isAfter(now);
        }).toList();

        if (activeAppointments.isEmpty) {
          return const _DataEmptyHint(message: 'No scheduled appointments.');
        }

        // Sort locally by actual appointment time ascending to get the closest upcoming appointment
        activeAppointments.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTimeStr = aData['time'] ?? aData['timeRange'] ?? '';
          final aDayStr = aData['day'] ?? aData['dateLabel'] ?? '';
          final bTimeStr = bData['time'] ?? bData['timeRange'] ?? '';
          final bDayStr = bData['day'] ?? bData['dateLabel'] ?? '';
          final aDate = _parseAppointmentDateTime(aDayStr, aTimeStr) ?? DateTime(2100);
          final bDate = _parseAppointmentDateTime(bDayStr, bTimeStr) ?? DateTime(2100);
          return aDate.compareTo(bDate);
        });

        // Get the nearest / closest upcoming
        final doc = activeAppointments.first;
        final data = doc.data() as Map<String, dynamic>;

        final clientName =
            data['userName'] as String? ??
            data['clientName'] as String? ??
            'Unknown Client';
        final appointmentTime =
            data['time'] as String? ??
            data['appointmentTime'] as String? ??
            'Time not set';
        final day = data['day'] as String? ?? 'Date not set';
        final type = data['consultationType'] as String? ?? 'office';
        final isOnline = type.toLowerCase() == 'online';

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor = isDark ? const Color(0xFF162235) : Colors.white;
        final badgeColor = isOnline
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFE3F2FD);
        final badgeTextColor = isOnline
            ? const Color(0xFF2E7D32)
            : const Color(0xFF1565C0);

        return Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isDark ? const Color(0xFF334766) : const Color(0xFFE5E7EB),
              width: 1.w,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
                blurRadius: 10,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: isOnline
                      ? Colors.green.withOpacity(0.1)
                      : AppColors.navyBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOnline ? Icons.video_call_rounded : Icons.business_rounded,
                  color: isOnline ? Colors.green : AppColors.navyBlue,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: GoogleFonts.cairo(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.navyBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12.sp,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            '$day | $appointmentTime',
                            style: GoogleFonts.cairo(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isDark ? badgeColor.withOpacity(0.15) : badgeColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  isOnline ? 'Online' : 'In Office',
                  style: GoogleFonts.cairo(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
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
          description:
              'Conflict regarding commercial property ownership in New Cairo.',
          category: 'Civil',
          status: 'active',
          createdDate: DateTime(2024, 2, 12),
          lawyerName: 'Client: Ahmed Aly',
          legalFees: 75000.0,
          requiredDocuments: List.generate(
            4,
            (i) => RequiredDocument(
              id: '$i',
              name: 'Deed',
              description: '',
              isSubmitted: false,
            ),
          ),
          sessions: List.generate(
            2,
            (i) => CaseSession(
              id: '$i',
              scheduledDate: DateTime.now(),
              status: 'scheduled',
            ),
          ),
          updates: [],
        ),
        UserCase(
          id: 'CASE-2024-005', // Unique ID for the case
          lawyerId: 'lawyer_admin_01', // Dummy lawyer ID
          caseNumber: 'CASE-2024-005',
          title: 'IP Rights Review',
          description:
              'Copyright infringement investigation for a tech startup mobile app.',
          category: 'Corporate',
          status: 'pending',
          createdDate: DateTime(2024, 3, 05),
          lawyerName: 'Client: Tech Nile Inc.',
          legalFees: 45000.0,
          requiredDocuments: List.generate(
            2,
            (i) => RequiredDocument(
              id: '$i',
              name: 'License',
              description: '',
              isSubmitted: false,
            ),
          ),
          sessions: List.generate(
            1,
            (i) => CaseSession(
              id: '$i',
              scheduledDate: DateTime.now(),
              status: 'scheduled',
            ),
          ),
          updates: [],
        ),
        UserCase(
          id: 'CASE-2024-012', // Unique ID for the case
          lawyerId: 'lawyer_admin_01', // Dummy lawyer ID
          caseNumber: 'CASE-2024-012',
          title: 'Labor Contract Breach',
          description:
              'Investigation into employee non-compete clause violations.',
          category: 'Labor',
          status: 'active',
          createdDate: DateTime(2024, 4, 18),
          lawyerName: 'Client: Modern Cairo Co.',
          legalFees: 20000.0,
          requiredDocuments: List.generate(
            6,
            (i) => RequiredDocument(
              id: '$i',
              name: 'Contract',
              description: '',
              isSubmitted: true,
            ),
          ),
          sessions: List.generate(
            3,
            (i) => CaseSession(
              id: '$i',
              scheduledDate: DateTime.now(),
              status: 'scheduled',
            ),
          ),
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

    debugPrint('--- Lawyer Onboarding Check ---');
    debugPrint('onboardingCompleted: \u001b[33m\u001b[1m$onboardingFlag\u001b[0m');
    debugPrint('work_status: $workStatus');
    debugPrint('professional_bio: $bio');
    debugPrint('years_of_experience: $yearsOfExperience');
    debugPrint('schedule: $scheduleRaw');
    debugPrint('hasSchedule: $hasSchedule');
    debugPrint('hasCoreData: $hasCoreData');

    if (!onboardingFlag || !hasCoreData) {
      debugPrint('Result: \u001b[31m\u001b[1mNOT COMPLETE (core data missing)\u001b[0m');
      return false;
    }

    final workStatusLower = (workStatus ?? '').trim().toLowerCase();
    final isEmployee = workStatusLower.contains('work') || workStatusLower.contains('employee');
    final isOwner = workStatusLower.contains('owns') || workStatusLower.contains('owner') || workStatusLower == 'own office';

    if (isEmployee) {
      final employerName = _asString(data['employer_lawyer_name']);
      debugPrint('employer_lawyer_name: $employerName');
      final result = (employerName ?? '').isNotEmpty;
      debugPrint(
        'Result: ${result ? '\u001b[32mCOMPLETE\u001b[0m' : '\u001b[31mNOT COMPLETE (employer name missing)\u001b[0m'}',
      );
      return result;
    }

    if (isOwner) {
      final officeDetails = data['office_details'];
      if (officeDetails is! Map) {
        debugPrint(
          'Result: \u001b[31mNOT COMPLETE (office_details missing)\u001b[0m',
        );
        return false;
      }
      final governorate = _asString(officeDetails['governorate']);
      final city = _asString(officeDetails['city']);
      final address = _asString(officeDetails['address']);

      List<String> allPhones = [];

      final legacyPhone = _asString(officeDetails['phone']);
      if (legacyPhone != null && legacyPhone.isNotEmpty) {
        allPhones.add(legacyPhone);
      }

      final phonesRaw = officeDetails['phones'];
      if (phonesRaw is List) {
        for (var p in phonesRaw) {
          final pStr = _asString(p);
          if (pStr != null && pStr.isNotEmpty && !allPhones.contains(pStr)) {
            allPhones.add(pStr);
          }
        }
      }

      final hasPhone = allPhones.isNotEmpty;
      final phoneDisplay = allPhones.join(', ');

      debugPrint(
        'office_details: governorate=$governorate, city=$city, address=$address, phones=$phoneDisplay',
      );
      final result =
          governorate != null &&
          city != null &&
          address != null &&
          hasPhone &&
          governorate.isNotEmpty &&
          city.isNotEmpty &&
          address.isNotEmpty;
      debugPrint(
        'Result: ${result ? '\u001b[32mCOMPLETE\u001b[0m' : '\u001b[31mNOT COMPLETE (office details missing)\u001b[0m'}',
      );
      return result;
    }

    debugPrint('Result: \u001b[32mCOMPLETE (default)\u001b[0m');
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
              _asString(entry['caseId']),
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
        final snapshot = await query
            .limit(50)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 10));
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final title = _firstNonEmpty([
            _asString(data['title']),
            _asString(data['caseNumber']),
            _asString(data['caseId']),
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
            color: const Color(0xFF0D2345).withOpacity(0.22),
            blurRadius: 22,
            offset: Offset(0, 12.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${'Welcome back,'.translate()} $lawyerName',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'You have pending cases waiting for you'.translate(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              height: 1.35,
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
              const Color(
                0xFF1E40AF,
              ).withOpacity(0.95), // Corrected withValues to withOpacity
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.navyBlue.withOpacity(
                0.2,
              ), // Corrected withValues to withOpacity
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
                color: Colors.white.withOpacity(
                  0.25,
                ), // Corrected withValues to withOpacity
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
                color: const Color(
                  0xFF10B981,
                ).withOpacity(0.15), // Corrected withValues to withOpacity
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
  final String? clientId;
  final bool isOwner;
  final String? officeId;

  const _CaseCard({
    required this.case_,
    this.clientId,
    this.isOwner = false,
    this.officeId,
  });

  Future<List<Map<String, dynamic>>> _getOfficeLawyers(String officeId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('offices')
        .doc(officeId)
        .collection('members')
        .get();

    return snapshot.docs
        .map((doc) => doc.data())
        .where((m) => m['role'] == 'employee' || m['role'] == 'owner')
        .toList();
  }

  void _assignCase(BuildContext context, String officeId, String caseDocId, String currentLawyerId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lawyers = await _getOfficeLawyers(officeId);

    String? selectedLawyerId = currentLawyerId;
    if (lawyers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No lawyers found in this office.'.translate())),
      );
      return;
    }

    final bool hasCurrent = lawyers.any((l) => l['memberId'] == currentLawyerId);
    if (!hasCurrent && lawyers.isNotEmpty) {
      selectedLawyerId = lawyers.first['memberId'];
    }

    double initialCommission = 15.0;
    if (lawyers.isNotEmpty) {
      final defaultLawyer = lawyers.firstWhere(
        (l) => l['memberId'] == selectedLawyerId,
        orElse: () => lawyers.first,
      );
      initialCommission = (defaultLawyer['commissionRate'] as num?)?.toDouble() ?? 15.0;
    }

    final commController = TextEditingController(text: initialCommission.toString());

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              title: Text(
                'Assign Case'.translate(),
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedLawyerId,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    decoration: InputDecoration(
                      labelText: 'Select Lawyer'.translate(),
                      border: const OutlineInputBorder(),
                    ),
                    items: lawyers.map((lawyer) {
                      final String name = lawyer['name'] ?? 'Unknown';
                      final String role = lawyer['role'] == 'owner' ? 'Owner'.translate() : 'Employee'.translate();
                      return DropdownMenuItem<String>(
                        value: lawyer['memberId'],
                        child: Text('$name ($role)'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      selectedLawyerId = val;
                      final selectedLawyer = lawyers.firstWhere((l) => l['memberId'] == val);
                      final double newComm = (selectedLawyer['commissionRate'] as num?)?.toDouble() ?? 15.0;
                      setDialogState(() {
                        commController.text = newComm.toString();
                      });
                    },
                  ),
                  SizedBox(height: 16.h),
                  TextFormField(
                    controller: commController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Commission %'.translate(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'.translate()),
                ),
                FilledButton(
                  onPressed: () {
                    final chosen = lawyers.firstWhere((l) => l['memberId'] == selectedLawyerId);
                    final double rate = double.tryParse(commController.text) ?? 15.0;
                    Navigator.pop(context, {
                      'member': chosen,
                      'commissionRate': rate,
                    });
                  },
                  child: Text('Assign'.translate()),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      final Map<String, dynamic> chosenMember = result['member'];
      final double chosenRate = result['commissionRate'];
      try {
        await FirebaseFirestore.instance.collection('cases').doc(caseDocId).update({
          'lawyerId': chosenMember['memberId'],
          'lawyerName': chosenMember['name'],
          'officeId': officeId,
          'isOfficeAssigned': true,
          'commissionRate': chosenRate,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Case assigned successfully.'.translate()),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign case.'.translate()),
            backgroundColor: AppColors.sosRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A2940) : Colors.white;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                LawyerCaseDetailsScreen(case_: case_, isLawyer: true),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: case_.isOfficeAssigned
                            ? Colors.blue.withOpacity(0.12)
                            : Colors.purple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        case_.isOfficeAssigned
                            ? 'Assigned by Office'.translate()
                            : 'Own Case'.translate(),
                        style: GoogleFonts.cairo(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: case_.isOfficeAssigned ? Colors.blue : Colors.purple,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    _buildStatusBadge(case_.status),
                  ],
                ),
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
            _buildClientInfo(isDark),
            SizedBox(height: 12.h),
            Divider(
              color: isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5),
              height: 1.h,
            ),
            SizedBox(height: 12.h),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('cases')
                  .doc(case_.id)
                  .collection('documentations')
                  .snapshots(),
              builder: (context, docSnap) {
                final docCount =
                    docSnap.data?.docs.length ?? case_.requiredDocuments.length;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('cases')
                      .doc(case_.id)
                      .collection('sessions')
                      .snapshots(),
                  builder: (context, sessionSnap) {
                    final sessionCount =
                        sessionSnap.data?.docs.length ?? case_.sessions.length;

                    return Row(
                      children: [
                        _buildStatIcon(
                          Icons.description_outlined,
                          '$docCount Requested Documents',
                        ),
                        SizedBox(width: 16.w),
                        _buildStatIcon(
                          Icons.gavel_outlined,
                          '$sessionCount Sessions',
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            if (case_.isOfficeAssigned) ...[
              SizedBox(height: 12.h),
              Row(
                children: [
                  Icon(Icons.assignment_ind_rounded, size: 14.sp, color: AppColors.legalGold),
                  SizedBox(width: 4.w),
                  Text(
                    'Assigned to'.translate() + ': ${case_.lawyerName} (${case_.commissionRate}%)',
                    style: GoogleFonts.cairo(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : AppColors.textDark.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ],
            if (isOwner && officeId != null) ...[
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _assignCase(context, officeId!, case_.id, case_.lawyerId),
                    icon: Icon(Icons.assignment_ind_rounded, size: 16.sp),
                    label: Text(
                      'Assign Lawyer'.translate(),
                      style: GoogleFonts.cairo(fontSize: 12.sp, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.legalGold,
                      side: const BorderSide(color: AppColors.legalGold),
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                  ),
                ],
              ),
            ],
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

  Widget _buildClientInfo(bool isDark) {
    String clientName = case_.clientName.isNotEmpty ? case_.clientName : case_.lawyerName;
    if (clientName.startsWith('Client: ')) {
      clientName = clientName.substring(8);
    } else if (clientName.isEmpty || clientName == 'Unknown Client') {
      clientName = 'Client'.translate();
    }

    Widget avatar = CircleAvatar(
      radius: 14.r,
      backgroundColor: AppColors.navyBlue.withOpacity(isDark ? 0.3 : 0.1),
      child: Icon(
        Icons.person_outline,
        size: 16.sp,
        color: AppColors.legalGold,
      ),
    );

    if (clientId != null && clientId!.isNotEmpty) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(clientId)
            .get(),
        builder: (context, snapshot) {
          String? photoUrl;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data != null) {
              photoUrl =
                  data['profileImage'] ??
                  data['profilePhotoUrl'] ??
                  data['photoUrl'];
              final fName = data['first_name'] ?? '';
              final sName = data['second_name'] ?? '';
              final fullName = data['fullName'] ?? '$fName $sName'.trim();
              if (fullName.isNotEmpty) clientName = fullName;
            }
          }

          if (photoUrl != null && photoUrl.isNotEmpty) {
            avatar = CircleAvatar(
              radius: 14.r,
              backgroundImage: NetworkImage(photoUrl),
              backgroundColor: AppColors.navyBlue.withOpacity(
                isDark ? 0.3 : 0.1,
              ),
            );
          }

          return _buildClientRow(avatar, clientName, isDark);
        },
      );
    }

    return _buildClientRow(avatar, clientName, isDark);
  }

  Widget _buildClientRow(Widget avatar, String name, bool isDark) {
    return Row(
      children: [
        avatar,
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.cairo(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
class _CasesView extends StatefulWidget {
  const _CasesView();

  @override
  State<_CasesView> createState() => _CasesViewState();
}

class _CasesViewState extends State<_CasesView> {
  String _filterStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lawyers')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, lawyerSnap) {
        if (lawyerSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final lawyerData = lawyerSnap.data?.data() as Map<String, dynamic>? ?? {};
        final workStatusRaw = (lawyerData['work_status'] ?? '').toString().trim().toLowerCase();
        final isOwner = workStatusRaw.contains('owns') || workStatusRaw.contains('owner') || workStatusRaw == 'own office';
        final String? officeId = lawyerData['officeId'];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('cases')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              print('Error details: ${snapshot.error}');
              return Center(
                child: _DataEmptyHint(message: 'Error: ${snapshot.error}'),
              );
            }

            final allDocs = snapshot.data?.docs.toList() ?? [];

            // Filter in-memory:
            // If Owner: Only show their own cases OR cases that are office-assigned
            // If not Owner: lawyerId == currentUser.uid
            final docs = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              if (isOwner && officeId != null) {
                final String? caseOfficeId = data['officeId'];
                final String? caseLawyerId = data['lawyerId'];
                final bool isOfficeAssigned = data['isOfficeAssigned'] == true;
                return caseLawyerId == currentUser.uid || (isOfficeAssigned && caseOfficeId == officeId);
              } else {
                return data['lawyerId'] == currentUser.uid;
              }
            }).toList();

            // Sort in Dart to avoid missing Composite Index error in Firestore
            docs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['createdAt'] as Timestamp?;
              final bTime = bData['createdAt'] as Timestamp?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });

            final allCasesData = docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final caseData = UserCase.fromFirestore(doc);
              return {'case': caseData, 'clientId': data['clientId']};
            }).toList();

            final filteredCases = _filterStatus == 'all'
                ? allCasesData
                : allCasesData
                      .where((c) => (c['case'] as UserCase).status == _filterStatus)
                      .toList();

            return ListView(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
              children: [
                Text(
                  'My Cases'.translate(),
                  style: GoogleFonts.cairo(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 12.h),
                if (docs.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40.h),
                      child: _DataEmptyHint(
                        message: 'No active cases.'.translate(),
                      ),
                    ),
                  )
                else ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          'all',
                          'All'.translate(),
                          allCasesData.length,
                          isDark,
                        ),
                        SizedBox(width: 8.w),
                        _buildFilterChip(
                          'active',
                          'Active'.translate(),
                          allCasesData
                              .where(
                                (c) => (c['case'] as UserCase).status == 'active',
                              )
                              .length,
                          isDark,
                        ),
                        SizedBox(width: 8.w),
                        _buildFilterChip(
                          'closed',
                          'Closed'.translate(),
                          allCasesData
                              .where(
                                (c) => (c['case'] as UserCase).status == 'closed',
                              )
                              .length,
                          isDark,
                        ),
                        SizedBox(width: 8.w),
                        _buildFilterChip(
                          'pending',
                          'Pending'.translate(),
                          allCasesData
                              .where(
                                (c) => (c['case'] as UserCase).status == 'pending',
                              )
                              .length,
                          isDark,
                        ),
                        SizedBox(width: 8.w),
                        _buildFilterChip(
                          'on_hold',
                          'On Hold'.translate(),
                          allCasesData
                              .where(
                                (c) => (c['case'] as UserCase).status == 'on_hold',
                              )
                              .length,
                          isDark,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  if (filteredCases.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40.h),
                        child: _DataEmptyHint(
                          message: 'No cases in this category'.translate(),
                        ),
                      ),
                    )
                  else
                    ...filteredCases.map((caseMap) {
                      return _CaseCard(
                        case_: caseMap['case'] as UserCase,
                        clientId: caseMap['clientId'] as String?,
                        isOwner: isOwner,
                        officeId: officeId,
                      );
                    }),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String value, String label, int count, bool isDark) {
    final isActive = _filterStatus == value;
    return FilterChip(
      label: Text(
        '$label ($count)',
        style: GoogleFonts.cairo(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: isActive
              ? Colors.white
              : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
        ),
      ),
      backgroundColor: isActive
          ? AppColors.legalGold
          : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
    );
  }
}

class _MessagesView extends StatelessWidget {
  const _MessagesView();

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lawyers')
          .doc(currentUser.uid)
          .collection('conversations')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading messages: ${snapshot.error}'),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs.toList() ?? [];
        
        // Sort in Dart to prevent Firestore Composite Index errors
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = (aData['updatedAt'] ?? aData['lastMessageTime']) as Timestamp?;
          final bTime = (bData['updatedAt'] ?? bData['lastMessageTime']) as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return ListView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
          children: [
            Text(
              'Messages'.translate(),
              style: GoogleFonts.cairo(
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 16.h),
            if (docs.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40.h),
                  child: _DataEmptyHint(message: 'No messages yet.'.translate()),
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final chatId = data['chatId'] ?? doc.id;
                final clientId = data['clientId'] ?? data['userId'] ?? '';
                final clientName = data['clientName'] ?? data['userName'] ?? 'Unknown Client';
                final lastMessage = data['lastMessage'] ?? '';
                final lastTime = (data['updatedAt'] ?? data['lastMessageTime']) as Timestamp?;
                final clientImage = data['clientProfileImage'] ?? data['userAvatar'] as String?;
                final unreadCount = (data['unreadCount'] as num?)?.toInt() ?? 0;

                String timeText = '';
                if (lastTime != null) {
                  final now = DateTime.now();
                  final dt = lastTime.toDate();
                  if (now.difference(dt).inDays == 0 && now.day == dt.day) {
                    timeText = '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                  } else {
                    timeText = '${dt.day}/${dt.month}/${dt.year}';
                  }
                }

                return _MessageTile(
                  chatId: chatId,
                  clientName: clientName,
                  lastMessage: lastMessage,
                  timeText: timeText,
                  clientImage: clientImage,
                  clientId: clientId,
                  unreadCount: unreadCount,
                  isDark: isDark,
                );
              }),
          ],
        );
      },
    );
  }
}

class _MessageTile extends StatelessWidget {
  final String chatId;
  final String clientName;
  final String lastMessage;
  final String timeText;
  final String? clientImage;
  final String clientId;
  final int unreadCount;
  final bool isDark;

  const _MessageTile({
    required this.chatId,
    required this.clientName,
    required this.lastMessage,
    required this.timeText,
    this.clientImage,
    required this.clientId,
    required this.unreadCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = unreadCount > 0 
        ? (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE8F4FE)) 
        : (isDark ? const Color(0xFF1A2940) : Colors.white);
        
    final borderColor = unreadCount > 0
        ? AppColors.legalGold.withOpacity(0.6)
        : (isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(clientId)
          .snapshots(),
      builder: (context, snapshot) {
        String resolvedName = clientName;
        String? resolvedImage = clientImage;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            final fName = data['fullName'] ?? data['name'] ?? '';
            if (fName.toString().trim().isNotEmpty) {
              resolvedName = fName.toString().trim();
            }
            final img = (data['profilePhotoUrl'] ?? data['profile_photo'] ?? data['photoUrl'] ?? '').toString().trim();
            if (img.isNotEmpty) {
              resolvedImage = img;
            }
          }
        }

        final hasValidImage = resolvedImage != null && resolvedImage.startsWith('http');

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LawyerChatScreen(
                  chatId: chatId,
                  clientName: resolvedName,
                  clientId: clientId,
                  clientImage: resolvedImage,
                ),
              ),
            );
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: borderColor),
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
                CircleAvatar(
                  radius: 24.r,
                  backgroundColor: AppColors.navyBlue.withOpacity(0.1),
                  backgroundImage: hasValidImage ? NetworkImage(resolvedImage!) : null,
                  child: !hasValidImage
                      ? Text(
                          resolvedName.isNotEmpty ? resolvedName[0].toUpperCase() : 'U',
                          style: GoogleFonts.cairo(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navyBlue,
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              resolvedName,
                              style: GoogleFonts.cairo(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.navyBlue,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            timeText,
                            style: GoogleFonts.cairo(
                              fontSize: 11.sp,
                              color: unreadCount > 0 ? AppColors.legalGold : Colors.grey,
                              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage.isNotEmpty
                                  ? lastMessage
                                  : 'Image or Attachment'.translate(),
                              style: GoogleFonts.cairo(
                                fontSize: 13.sp,
                                color: unreadCount > 0 
                                    ? (isDark ? Colors.white : Colors.black87) 
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.all(6.r),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$unreadCount',
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AddCaseSheet extends StatefulWidget {
  final String lawyerName;
  const _AddCaseSheet({required this.lawyerName});

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
  final _nameController = TextEditingController();
  final _phoneResultController = TextEditingController();
  final _nationalIdController = TextEditingController();

  String _selectedCategory = 'Civil';
  String _selectedServiceType = 'non_litigation';
  Map<String, dynamic>? _selectedClient;
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
    _nameController.dispose();
    _phoneResultController.dispose();
    _nationalIdController.dispose();
    super.dispose();
  }

  void _selectUser(Map<String, dynamic> user) {
    String rawPhone = user['phone'] ?? '';
    // If it starts with +20, we display the 0... version to the lawyer in the search bar
    String displayPhone = rawPhone;
    if (rawPhone.startsWith('+20')) {
      displayPhone = rawPhone.substring(2);
    }

    setState(() {
      _selectedClient = user;
      _phoneController.text = displayPhone;
      // Fill controllers with data from Firestore (FullName or parts)
      _nameController.text =
          user['fullName'] ??
          '${user['first_name'] ?? ''} ${user['second_name'] ?? ''}'.trim();
      _phoneResultController.text = user['phone'] ?? '';
      _nationalIdController.text =
          user['nationalId'] ?? user['national_id'] ?? 'N/A';
    });
  }

  Future<void> _submitCase() async {
    // Bypass validation for testing as requested
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      String? officeId;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('lawyers').doc(user.uid).get();
        if (doc.exists) {
          officeId = doc.data()?['officeId'];
        }
      }

      // Prepare data map for Firestore
      final Map<String, dynamic> mapData = {
        'caseId': _caseNumber,
        'caseNumber': '',
        'caseYear': '',
        'clientId': _selectedClient!['uid'], // Button is disabled if null
        'lawyerId': user?.uid ?? 'unknown_lawyer',
        'lawyerName': widget.lawyerName,
        if (officeId != null) 'officeId': officeId,
        'title': _titleController.text.trim(),
        'status': 'pending_payment',
        'category': _selectedCategory,
        'serviceType': _selectedServiceType,
        'description': _descController.text.trim(),
        'legalFees': double.tryParse(_feesController.text) ?? 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'clientName': _nameController.text,
        'clientPhone': _phoneResultController.text,
        'clientNationalId': _nationalIdController.text,
      };

      // Task: Add Print Statements
      print('Attempting to save to collection: cases');
      print('Data: $mapData');

      // Firebase Call
      await FirebaseFirestore.instance.collection('cases').add(mapData);

      if (!mounted) return;

      // Task: Success SnackBar
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Case Syncing...'.translate())));

      // Task: Force Close & Navigate
      Navigator.pop(context);
    } catch (e) {
      // Task: Global Error Catching
      print("Firebase Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e'.translate())));
    } finally {
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
            child: Text(
              'Add New Case'.translate(),
              style: GoogleFonts.cairo(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20.w,
                10.h,
                20.w,
                MediaQuery.of(context).viewInsets.bottom + 20.h,
              ),
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
                      decoration: _inputDeco(
                        inputBg,
                        Icons.confirmation_number_outlined,
                      ),
                      style: GoogleFonts.cairo(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Section 2: Client Search
                    Text(
                      'Search Client by Phone'.translate(),
                      style: labelStyle,
                    ),
                    SizedBox(height: 6.h),
                    TypeAheadField<Map<String, dynamic>>(
                      controller: _phoneController,
                      builder: (context, controller, focusNode) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          keyboardType: TextInputType.phone,
                          onChanged: (val) {
                            String searchPhone = val.trim().replaceAll(
                              RegExp(r'[\s\-]'),
                              '',
                            );
                            if (searchPhone.startsWith('0')) {
                              searchPhone = '+2$searchPhone';
                            }
                            if (_selectedClient != null &&
                                searchPhone != _selectedClient!['phone']) {
                              setState(() {
                                _selectedClient = null;
                              });
                              _nameController.clear();
                              _phoneResultController.clear();
                              _nationalIdController.clear();
                            }
                          },
                          decoration:
                              _inputDeco(
                                inputBg,
                                Icons.person_search_outlined,
                              ).copyWith(
                                hintText: 'Search by phone number...'
                                    .translate(),
                              ),
                        );
                      },
                      // Safely styles the dropdown box with a border and elevation
                      decorationBuilder: (context, child) {
                        return Material(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: AppColors.legalGold.withOpacity(0.5),
                              ),
                            ),
                            child: child,
                          ),
                        );
                      },
                      suggestionsCallback: (pattern) async {
                        String searchPhone = pattern.trim().replaceAll(
                          RegExp(r'[\s\-]'),
                          '',
                        );
                        if (searchPhone.startsWith('0')) {
                          searchPhone = '+2$searchPhone';
                        }
                        if (searchPhone.isEmpty) {
                          return [];
                        }
                        final querySnapshot = await FirebaseFirestore.instance
                            .collection('users')
                            .where('role', isEqualTo: 'user')
                            .where('phone', isGreaterThanOrEqualTo: searchPhone)
                            .where('phone', isLessThan: '$searchPhone\uf8ff')
                            .limit(5)
                            .get();
                        return querySnapshot.docs
                            .map((doc) => {...doc.data(), 'uid': doc.id})
                            .toList();
                      },
                      itemBuilder: (context, suggestion) {
                        final firstName = suggestion['first_name'] ?? '';
                        final secondName = suggestion['second_name'] ?? '';
                        final fullName =
                            suggestion['fullName'] ??
                            '$firstName $secondName'.trim();
                        final phone = suggestion['phone'] ?? '';
                        final profileImageUrl =
                            suggestion['profileImage'] ??
                            suggestion['profilePhotoUrl'] ??
                            suggestion['photoUrl'];

                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 18.r,
                            backgroundColor: AppColors.navyBlue.withOpacity(
                              0.1,
                            ),
                            backgroundImage:
                                (profileImageUrl != null &&
                                    profileImageUrl.toString().isNotEmpty)
                                ? NetworkImage(profileImageUrl.toString())
                                : null,
                            child:
                                (profileImageUrl == null ||
                                    profileImageUrl.toString().isEmpty)
                                ? Icon(
                                    Icons.person_outline,
                                    size: 20.sp,
                                    color: AppColors.legalGold,
                                  )
                                : null,
                          ),
                          title: Text(
                            fullName.isNotEmpty ? fullName : 'Unknown User',
                            style: GoogleFonts.cairo(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            phone,
                            style: GoogleFonts.cairo(fontSize: 12.sp),
                          ),
                        );
                      },
                      onSelected: (suggestion) {
                        _selectUser(suggestion);
                      },
                      emptyBuilder: (context) => Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Text(
                          'Client not registered'.translate(),
                          style: GoogleFonts.cairo(
                            color: Colors.red,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    SizedBox(height: 16.h),
                    Text('Client Name'.translate(), style: labelStyle),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _nameController,
                      readOnly: true,
                      decoration: _inputDeco(
                        isDark ? const Color(0xFF262F3C) : Colors.grey[200]!,
                        Icons.person,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text('Client Phone No'.translate(), style: labelStyle),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _phoneResultController,
                      readOnly: true,
                      decoration: _inputDeco(
                        isDark ? const Color(0xFF262F3C) : Colors.grey[200]!,
                        Icons.phone,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text('Client National ID'.translate(), style: labelStyle),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _nationalIdController,
                      readOnly: true,
                      decoration: _inputDeco(
                        isDark ? const Color(0xFF262F3C) : Colors.grey[200]!,
                        Icons.badge,
                      ),
                    ),

                    if (_selectedClient != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(() {
                            _selectedClient = null;
                            _phoneController.clear();
                            _nameController.clear();
                            _phoneResultController.clear();
                            _nationalIdController.clear();
                          }),
                          child: Text(
                            'Change Client'.translate(),
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    SizedBox(height: 20.h),

                    // Section 3: Specifications
                    Text('Case Title'.translate(), style: labelStyle),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _titleController,
                      decoration: _inputDeco(inputBg, Icons.title_rounded),
                      validator: (v) =>
                          v!.isEmpty ? 'Required'.translate() : null,
                    ),
                    SizedBox(height: 16.h),
                    Text('Status'.translate(), style: labelStyle),
                    SizedBox(height: 6.h),
                    TextFormField(
                      initialValue: 'pending_payment'.translate(),
                      readOnly: true,
                      decoration: _inputDeco(
                        inputBg,
                        Icons.hourglass_empty_rounded,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text('Category'.translate(), style: labelStyle),
                    SizedBox(height: 6.h),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('lawyer_specialization')
                          .snapshots(),
                      builder: (context, snapshot) {
                        List<String> categories = [
                          'Civil',
                          'Criminal',
                          'Family',
                          'Commercial',
                          'Labor',
                          'Real Estate',
                        ];
                        if (snapshot.hasData &&
                            snapshot.data!.docs.isNotEmpty) {
                          categories = snapshot.data!.docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return (data['name'] ?? doc.id).toString();
                          }).toList();
                        }

                        String dropdownValue =
                            categories.contains(_selectedCategory)
                            ? _selectedCategory
                            : (categories.isNotEmpty
                                  ? categories.first
                                  : 'Civil');

                        if (_selectedCategory != dropdownValue) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() => _selectedCategory = dropdownValue);
                            }
                          });
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: dropdownValue,
                          items: categories
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e.translate()),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedCategory = v!),
                          decoration: _inputDeco(
                            inputBg,
                            Icons.list_alt_rounded,
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 20.h),

                    Text('Service Type'.translate(), style: labelStyle),
                    SizedBox(height: 6.h),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedServiceType,
                      items: [
                        DropdownMenuItem(
                          value: 'litigation',
                          child: Text('Litigation'.translate()),
                        ),
                        DropdownMenuItem(
                          value: 'non_litigation',
                          child: Text('Non-Litigation'.translate()),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedServiceType = v!),
                      decoration: _inputDeco(
                        inputBg,
                        Icons.work_outline_rounded,
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Section 4: Details & Fees
                    Text('Description'.translate(), style: labelStyle),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _descController,
                      maxLines: 4,
                      decoration: _inputDeco(
                        inputBg,
                        Icons.description_outlined,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text('Legal Fees (EGP)'.translate(), style: labelStyle),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _feesController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDeco(
                        inputBg,
                        Icons.account_balance_wallet_outlined,
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Required'.translate() : null,
                    ),
                    SizedBox(height: 32.h),

                    SizedBox(
                      width: double.infinity,
                      height: 54.h,
                      child: ElevatedButton(
                        onPressed: (_isSubmitting || _selectedClient == null)
                            ? null
                            : _submitCase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF001F3F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'Create Case'.translate(),
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
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
      prefixIcon: Icon(icon, color: AppColors.legalGold, size: 20.sp),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: AppColors.legalGold),
      ),
    );
  }

  Widget _buildReadOnlyRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: const Color(0xFF001F3F)),
          SizedBox(width: 8.w),
          Text(
            '$label: ',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 13.sp,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.cairo(fontSize: 13.sp),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
