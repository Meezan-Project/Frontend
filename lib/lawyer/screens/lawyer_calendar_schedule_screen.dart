import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/user/models/case_model.dart';
import 'package:mezaan/user/screens/video_call_screen.dart';
import 'package:intl/intl.dart';

enum CalendarViewMode { month, day, agenda }
enum CalendarEventType { appointment, courtSession }

class CalendarEvent {
  final String id;
  final String title;
  final String subtitle;
  final DateTime dateTime;
  final String timeRange;
  final String location;
  final String notes;
  final CalendarEventType type;
  final Map<String, dynamic> rawData;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.dateTime,
    required this.timeRange,
    required this.location,
    required this.notes,
    required this.type,
    required this.rawData,
  });
}

class LawyerCalendarScheduleScreen extends StatefulWidget {
  final String? lawyerId;
  const LawyerCalendarScheduleScreen({super.key, this.lawyerId});

  @override
  State<LawyerCalendarScheduleScreen> createState() => _LawyerCalendarScheduleScreenState();
}

class _LawyerCalendarScheduleScreenState extends State<LawyerCalendarScheduleScreen> {
  CalendarViewMode _viewMode = CalendarViewMode.month;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  final ScrollController _timelineScrollController = ScrollController();

  // Color Palette Constants
  static const Color primaryNavy = AppColors.navyBlue;
  static const Color accentGold = AppColors.legalGold;
  static const Color appointmentColor = Color(0xFF4CAF50); // Green
  static const Color sessionColor = Color(0xFFE65100);     // Orange/Amber

  @override
  void dispose() {
    _timelineScrollController.dispose();
    super.dispose();
  }

  // Parses day string and time slot to create a DateTime
  DateTime? _parseEventDateTime(String dateLabel, String timeRange) {
    try {
      String cleanDate = dateLabel;
      if (dateLabel.contains(',')) {
        cleanDate = dateLabel.split(',').last.trim(); // e.g. "9 Jun 2026"
      }
      
      DateTime? parsedDate;
      final formats = ['d MMM yyyy', 'dd MMM yyyy', 'yyyy-MM-dd', 'dd/MM/yyyy'];
      for (final format in formats) {
        try {
          parsedDate = DateFormat(format).parse(cleanDate);
          break;
        } catch (_) {}
      }
      if (parsedDate == null) return null;

      final cleanTime = timeRange.split('-')[0].trim(); // "10:00 AM"
      final parts = cleanTime.split(' ');
      final hms = parts[0].split(':');
      int hour = int.parse(hms[0]);
      final minute = hms.length > 1 ? int.parse(hms[1]) : 0;
      final amPm = parts.length > 1 ? parts[1].toUpperCase() : 'AM';
      
      if (amPm == 'PM' && hour < 12) {
        hour += 12;
      } else if (amPm == 'AM' && hour == 12) {
        hour = 0;
      }
      return DateTime(parsedDate.year, parsedDate.month, parsedDate.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  // Parse court sessions and appointments into calendar events
  List<CalendarEvent> _parseEvents(List<QueryDocumentSnapshot> apptDocs, List<QueryDocumentSnapshot> caseDocs) {
    final List<CalendarEvent> events = [];

    // 1. Appointments
    for (final doc in apptDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? data['bookingStatus'] ?? '';
      if (status == 'cancelled') continue;

      final clientName = data['userName'] ?? data['clientName'] ?? 'Client'.translate();
      final dayStr = data['day'] ?? data['dateLabel'] ?? '';
      final timeRange = data['time'] ?? data['timeRange'] ?? 'Time not set';
      final consultationType = data['consultationType'] ?? 'online';
      
      DateTime? eventDate = _parseEventDateTime(dayStr, timeRange);
      if (eventDate == null && data['createdAt'] is Timestamp) {
        eventDate = (data['createdAt'] as Timestamp).toDate();
      }
      eventDate ??= DateTime.now();

      events.add(
        CalendarEvent(
          id: doc.id,
          title: '${'Consultation with'.translate()} $clientName',
          subtitle: consultationType.toLowerCase() == 'online'
              ? 'Online Meeting'.translate()
              : 'In-Office Consultation'.translate(),
          dateTime: eventDate,
          timeRange: timeRange,
          location: data['officeAddress'] ?? data['address'] ?? (consultationType == 'online' ? 'Online'.translate() : ''),
          notes: '${'Fees:'.translate()} ${data['fees'] ?? 0} EGP\n${'Payment:'.translate()} ${(data['paymentMethod'] ?? 'cash').toString().toUpperCase()}',
          type: CalendarEventType.appointment,
          rawData: data,
        ),
      );
    }

    // 2. Court Sessions (Galsat)
    for (final doc in caseDocs) {
      final caseData = doc.data() as Map<String, dynamic>;
      final caseName = caseData['title'] ?? 'Case'.translate();
      final caseNumber = caseData['caseNumber'] ?? '';
      final clientId = caseData['clientId'] ?? '';
      final clientName = caseData['clientName'] ?? '';
      
      final sessionsListRaw = caseData['sessions'] as List<dynamic>? ?? [];
      for (int i = 0; i < sessionsListRaw.length; i++) {
        final sessionMap = sessionsListRaw[i] as Map<String, dynamic>;
        final status = sessionMap['status'] ?? 'scheduled';
        if (status == 'cancelled') continue;

        final scheduledDate = (sessionMap['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final location = sessionMap['location'] ?? 'Court Room'.translate();
        final notes = sessionMap['notes'] ?? '';

        events.add(
          CalendarEvent(
            id: '${doc.id}_session_$i',
            title: '${'Court Session:'.translate()} $caseName',
            subtitle: '${'Case Number:'.translate()} $caseNumber • ${'Client:'.translate()} $clientName',
            dateTime: scheduledDate,
            timeRange: DateFormat('hh:mm a').format(scheduledDate),
            location: location,
            notes: notes,
            type: CalendarEventType.courtSession,
            rawData: sessionMap,
          ),
        );
      }
    }

    return events;
  }

  // Grid Builder for Month days
  List<DateTime> _generateMonthDays(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final totalDays = DateTime(month.year, month.month + 1, 0).day;
    
    // We want Sunday as 0, Monday as 1... Saturday as 6
    // weekday is 1 for Mon, 7 for Sun
    int leadingOffset = firstDay.weekday % 7; 
    
    final List<DateTime> days = [];
    
    // Previous Month Days
    final prevMonthEnd = DateTime(month.year, month.month, 0);
    for (int i = leadingOffset - 1; i >= 0; i--) {
      days.add(DateTime(month.year, month.month - 1, prevMonthEnd.day - i));
    }
    
    // Current Month Days
    for (int i = 1; i <= totalDays; i++) {
      days.add(DateTime(month.year, month.month, i));
    }
    
    // Next Month Days to fill grid rows (42 cells = 6 weeks)
    int remaining = 42 - days.length;
    for (int i = 1; i <= remaining; i++) {
      days.add(DateTime(month.year, month.month + 1, i));
    }
    
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F1419) : const Color(0xFFFCFDFF);
    final cardColor = isDark ? const Color(0xFF162235) : Colors.white;

    final queryUid = widget.lawyerId ?? currentUser?.uid ?? '';

    if (queryUid.isEmpty) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: Text('User not logged in'.translate())),
      );
    }

    final appointmentsStream = FirebaseFirestore.instance
        .collection('appointments')
        .where('lawyerId', isEqualTo: queryUid)
        .snapshots();

    final casesStream = FirebaseFirestore.instance
        .collection('cases')
        .where('lawyerId', isEqualTo: queryUid)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: appointmentsStream,
      builder: (context, apptSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: casesStream,
          builder: (context, casesSnap) {
            if (apptSnap.hasError || casesSnap.hasError) {
              return Scaffold(
                backgroundColor: bgColor,
                body: Center(child: Text('Error loading schedule'.translate())),
              );
            }
            if (apptSnap.connectionState == ConnectionState.waiting ||
                casesSnap.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: bgColor,
                body: const Center(child: CircularProgressIndicator(color: primaryNavy)),
              );
            }

            final events = _parseEvents(
              apptSnap.data?.docs ?? [],
              casesSnap.data?.docs ?? [],
            );

            return Scaffold(
              backgroundColor: bgColor,
              appBar: AppBar(
                backgroundColor: isDark ? const Color(0xFF162235) : Colors.white,
                elevation: 0,
                centerTitle: false,
                title: Text(
                  DateFormat('MMMM yyyy', Localizations.localeOf(context).languageCode).format(_focusedMonth),
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800,
                    fontSize: 18.sp,
                    color: isDark ? Colors.white : primaryNavy,
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedDate = DateTime.now();
                        _focusedMonth = DateTime.now();
                      });
                    },
                    icon: Icon(Icons.today, color: isDark ? Colors.white : primaryNavy),
                    tooltip: 'Today'.translate(),
                  ),
                  _buildViewModeSelector(isDark),
                ],
              ),
              body: Column(
                children: [
                  _buildNavigationRow(isDark),
                  Expanded(
                    child: _buildMainCalendarContent(events, isDark, cardColor),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Top Bar View Toggle Selector
  Widget _buildViewModeSelector(bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24324A) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSelectorTab(CalendarViewMode.month, 'Month', isDark),
          _buildSelectorTab(CalendarViewMode.day, 'Day', isDark),
          _buildSelectorTab(CalendarViewMode.agenda, 'Agenda', isDark),
        ],
      ),
    );
  }

  Widget _buildSelectorTab(CalendarViewMode mode, String label, bool isDark) {
    final isSelected = _viewMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _viewMode = mode;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? accentGold : primaryNavy) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Text(
          label.translate(),
          style: GoogleFonts.cairo(
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
            color: isSelected 
                ? Colors.white 
                : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }

  // Month navigation row
  Widget _buildNavigationRow(bool isDark) {
    final textColor = isDark ? Colors.white : primaryNavy;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month, size: 20.sp, color: isDark ? accentGold : primaryNavy),
              SizedBox(width: 8.w),
              Text(
                DateFormat('EEEE, d MMMM', Localizations.localeOf(context).languageCode).format(_selectedDate),
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: _navigatePrevious,
                icon: Icon(Icons.chevron_left, color: textColor),
                splashRadius: 20.r,
              ),
              IconButton(
                onPressed: _navigateNext,
                icon: Icon(Icons.chevron_right, color: textColor),
                splashRadius: 20.r,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigatePrevious() {
    setState(() {
      if (_viewMode == CalendarViewMode.month) {
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
        _selectedDate = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      } else {
        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
        _focusedMonth = _selectedDate;
      }
    });
  }

  void _navigateNext() {
    setState(() {
      if (_viewMode == CalendarViewMode.month) {
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
        _selectedDate = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      } else {
        _selectedDate = _selectedDate.add(const Duration(days: 1));
        _focusedMonth = _selectedDate;
      }
    });
  }

  Widget _buildMainCalendarContent(List<CalendarEvent> events, bool isDark, Color cardColor) {
    switch (_viewMode) {
      case CalendarViewMode.month:
        return _buildMonthView(events, isDark, cardColor);
      case CalendarViewMode.day:
        return _buildDayView(events, isDark, cardColor);
      case CalendarViewMode.agenda:
        return _buildAgendaView(events, isDark, cardColor);
    }
  }

  // ==========================================
  // MONTH VIEW IMPLEMENTATION
  // ==========================================
  Widget _buildMonthView(List<CalendarEvent> events, bool isDark, Color cardColor) {
    final days = _generateMonthDays(_focusedMonth);
    final weekDaysLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Column(
      children: [
        // Weekdays Headers
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDaysLabels.map((lbl) => Expanded(
              child: Text(
                lbl.translate(),
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.sp,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            )).toList(),
          ),
        ),
        SizedBox(height: 6.h),
        // Days Grid
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isDark ? const Color(0xFF24324A) : Colors.grey.shade200,
              ),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 2,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final date = days[index];
                final isCurrentMonth = date.month == _focusedMonth.month;
                final isSelected = date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;
                final isToday = date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;

                // Find events for this day
                final dayEvents = events.where((e) =>
                    e.dateTime.year == date.year &&
                    e.dateTime.month == date.month &&
                    e.dateTime.day == date.day).toList();

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                      _focusedMonth = date;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? (isDark ? accentGold.withOpacity(0.25) : primaryNavy.withOpacity(0.08)) 
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isToday 
                          ? Border.all(color: accentGold, width: 1.5.w) 
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          date.day.toString(),
                          style: GoogleFonts.cairo(
                            fontSize: 14.sp,
                            fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.w600,
                            color: !isCurrentMonth 
                                ? Colors.grey.shade400
                                : (isSelected 
                                    ? (isDark ? accentGold : primaryNavy) 
                                    : (isDark ? Colors.white : Colors.black87)),
                          ),
                        ),
                        if (dayEvents.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: dayEvents.take(3).map((e) => Container(
                              margin: EdgeInsets.symmetric(horizontal: 1.w),
                              width: 5.r,
                              height: 5.r,
                              decoration: BoxDecoration(
                                color: e.type == CalendarEventType.appointment 
                                    ? appointmentColor 
                                    : sessionColor,
                                shape: BoxShape.circle,
                              ),
                            )).toList(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(height: 12.h),
        // Split view Agenda list of events for the selected day
        Expanded(
          child: _buildSplitViewAgendaList(events, isDark, cardColor),
        ),
      ],
    );
  }

  Widget _buildSplitViewAgendaList(List<CalendarEvent> events, bool isDark, Color cardColor) {
    final dayEvents = events.where((e) =>
        e.dateTime.year == _selectedDate.year &&
        e.dateTime.month == _selectedDate.month &&
        e.dateTime.day == _selectedDate.day).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (dayEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 42.sp, color: Colors.grey.shade400),
            SizedBox(height: 8.h),
            Text(
              'No events scheduled for this day.'.translate(),
              style: GoogleFonts.cairo(
                color: Colors.grey.shade500,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      itemCount: dayEvents.length,
      itemBuilder: (context, index) {
        final event = dayEvents[index];
        return _buildEventCard(event, isDark, cardColor);
      },
    );
  }

  // ==========================================
  // DAY TIMELINE VIEW IMPLEMENTATION
  // ==========================================
  Widget _buildDayView(List<CalendarEvent> events, bool isDark, Color cardColor) {
    final dayEvents = events.where((e) =>
        e.dateTime.year == _selectedDate.year &&
        e.dateTime.month == _selectedDate.month &&
        e.dateTime.day == _selectedDate.day).toList();

    // Timeline hours: 8:00 AM to 10:00 PM
    final List<int> hours = List.generate(15, (index) => index + 8); 

    return ListView.builder(
      controller: _timelineScrollController,
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      itemCount: hours.length,
      itemBuilder: (context, index) {
        final hour = hours[index];
        final timeDisplay = hour == 12 
            ? '12:00 PM' 
            : (hour > 12 ? '${hour - 12}:00 PM' : '$hour:00 AM');
            
        // Filter events starting in this specific hour slot
        final slotEvents = dayEvents.where((e) => e.dateTime.hour == hour).toList();

        return Container(
          height: 90.h,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF24324A) : Colors.grey.shade100,
                width: 1.w,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time label Column
              SizedBox(
                width: 75.w,
                child: Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Text(
                    timeDisplay.translate(),
                    style: GoogleFonts.cairo(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              // Vertical divider line
              Container(
                width: 1.5.w,
                color: isDark ? const Color(0xFF24324A) : Colors.grey.shade200,
                margin: EdgeInsets.symmetric(horizontal: 8.w),
              ),
              // Events block Column
              Expanded(
                child: slotEvents.isEmpty
                    ? const SizedBox()
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: slotEvents.length,
                        itemBuilder: (context, index) {
                          final event = slotEvents[index];
                          final color = event.type == CalendarEventType.appointment 
                              ? appointmentColor 
                              : sessionColor;

                          return GestureDetector(
                            onTap: () => _showEventDetailsDialog(event, isDark),
                            child: Container(
                              width: 220.w,
                              margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border(
                                  left: BorderSide(color: color, width: 4.w),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    event.title,
                                    style: GoogleFonts.cairo(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : primaryNavy,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${event.timeRange} | ${event.subtitle}',
                                    style: GoogleFonts.cairo(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // AGENDA VIEW IMPLEMENTATION
  // ==========================================
  Widget _buildAgendaView(List<CalendarEvent> events, bool isDark, Color cardColor) {
    // Sort all events chronologically (future events or all events)
    final upcomingEvents = events
        .where((e) => e.dateTime.isAfter(DateTime.now().subtract(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (upcomingEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48.sp, color: Colors.grey.shade400),
            SizedBox(height: 12.h),
            Text(
              'No upcoming events scheduled.'.translate(),
              style: GoogleFonts.cairo(
                color: Colors.grey.shade500,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: upcomingEvents.length,
      itemBuilder: (context, index) {
        final event = upcomingEvents[index];
        final monthStr = DateFormat('MMM yyyy', Localizations.localeOf(context).languageCode).format(event.dateTime);
        
        // Group events by displaying a header when month changes
        bool showHeader = index == 0 ||
            DateFormat('MMM yyyy').format(upcomingEvents[index - 1].dateTime) !=
                DateFormat('MMM yyyy').format(event.dateTime);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Padding(
                padding: EdgeInsets.only(top: 14.h, bottom: 8.h, left: 4.w),
                child: Text(
                  monthStr.toUpperCase(),
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.sp,
                    color: isDark ? accentGold : primaryNavy,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date display column
                SizedBox(
                  width: 50.w,
                  child: Column(
                    children: [
                      Text(
                        event.dateTime.day.toString(),
                        style: GoogleFonts.cairo(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : primaryNavy,
                        ),
                      ),
                      Text(
                        DateFormat('E', Localizations.localeOf(context).languageCode).format(event.dateTime).toUpperCase(),
                        style: GoogleFonts.cairo(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                // Card column
                Expanded(
                  child: _buildEventCard(event, isDark, cardColor),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // Card view for Monthsplit and Agenda views
  Widget _buildEventCard(CalendarEvent event, bool isDark, Color cardColor) {
    final typeColor = event.type == CalendarEventType.appointment 
        ? appointmentColor 
        : sessionColor;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF24324A) : Colors.grey.shade200,
          width: 1.w,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.12 : 0.03),
            blurRadius: 10,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Colored line indicator
              Container(
                width: 5.w,
                color: typeColor,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(14.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: GoogleFonts.cairo(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : primaryNavy,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              (event.type == CalendarEventType.appointment ? 'Appointment' : 'Court Session').translate(),
                              style: GoogleFonts.cairo(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: typeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        event.subtitle,
                        style: GoogleFonts.cairo(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14.sp, color: Colors.grey.shade500),
                          SizedBox(width: 4.w),
                          Text(
                            event.timeRange,
                            style: GoogleFonts.cairo(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          if (event.location.isNotEmpty) ...[
                            SizedBox(width: 14.w),
                            Icon(Icons.location_on_rounded, size: 14.sp, color: Colors.grey.shade500),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                event.location,
                                style: GoogleFonts.cairo(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(
                          onPressed: () => _showEventDetailsDialog(event, isDark),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: typeColor, width: 1.w),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                          ),
                          child: Text(
                            'Details'.translate(),
                            style: GoogleFonts.cairo(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: typeColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show dialog modal with detailed event description
  void _showEventDetailsDialog(CalendarEvent event, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        final isOnline = event.rawData['consultationType']?.toString().toLowerCase() == 'online';
        final isAppt = event.type == CalendarEventType.appointment;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          backgroundColor: isDark ? const Color(0xFF162235) : Colors.white,
          title: Row(
            children: [
              Icon(
                isAppt ? Icons.event : Icons.gavel,
                color: isAppt ? appointmentColor : sessionColor,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  event.title,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800,
                    fontSize: 16.sp,
                    color: isDark ? Colors.white : primaryNavy,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPopupDetailRow('Date'.translate(), DateFormat('EEEE, d MMM yyyy', Localizations.localeOf(context).languageCode).format(event.dateTime), isDark),
                _buildPopupDetailRow('Time'.translate(), event.timeRange, isDark),
                if (event.location.isNotEmpty)
                  _buildPopupDetailRow('Location'.translate(), event.location, isDark),
                _buildPopupDetailRow('Type'.translate(), event.subtitle, isDark),
                if (event.notes.isNotEmpty)
                  _buildPopupDetailRow('Details/Notes'.translate(), event.notes, isDark),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close'.translate(),
                style: GoogleFonts.cairo(
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isAppt && isOnline)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoCallScreen(meetingId: event.id),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: appointmentColor,
                ),
                icon: const Icon(Icons.video_call, color: Colors.white),
                label: Text(
                  'Join Meeting'.translate(),
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPopupDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white54 : Colors.grey.shade500,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
