import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/models/case_model.dart';

// Reusing the date formatting helper for consistency with User side
String formatDate(DateTime date, String format) {
  String result = format;
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  
  result = result.replaceAll('EEEE', days[date.weekday % 7]);
  result = result.replaceAll('MMM', months[date.month - 1]);
  result = result.replaceAll('dd', date.day.toString().padLeft(2, '0'));
  result = result.replaceAll('yyyy', date.year.toString());
  result = result.replaceAll('hh', (date.hour % 12 == 0 ? 12 : date.hour % 12).toString().padLeft(2, '0'));
  result = result.replaceAll('mm', date.minute.toString().padLeft(2, '0'));
  result = result.replaceAll('a', date.hour >= 12 ? 'PM' : 'AM');
  
  return result;
}

class LawyerCaseDetailsScreen extends StatefulWidget {
  final UserCase case_;
  final bool isLawyer; // Global Role Logic toggle

  const LawyerCaseDetailsScreen({
    super.key, 
    required this.case_,
    this.isLawyer = true,
  });

  @override
  State<LawyerCaseDetailsScreen> createState() => _LawyerCaseDetailsScreenState();
}

class _LawyerCaseDetailsScreenState extends State<LawyerCaseDetailsScreen> {
  late PageController _pageController;
  int _currentTabIndex = 0;
  bool _isSaving = false;

  // Local state to simulate database updates without Firestore delay
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String? _selectedCategory;
  String? _selectedStatus;
  late List<RequiredDocument> _documents;
  late List<CaseSession> _sessions;
  late List<CaseUpdate> _updates;

  // Dummy data for Fees Tab
  double _totalFunded = 75000.0;
  double _spentAmount = 32450.0;
  final List<Map<String, dynamic>> _financialActivity = [
    {'title': 'Case Deposit', 'amount': 75000.0, 'date': 'May 01, 2024', 'type': 'funded'},
    {'title': 'Power of Attorney Filing', 'amount': 450.0, 'date': 'May 05, 2024', 'type': 'spent'},
    {'title': 'Consultation Fees', 'amount': 12000.0, 'date': 'May 10, 2024', 'type': 'spent'},
    {'title': 'Court Expenses', 'amount': 20000.0, 'date': 'May 15, 2024', 'type': 'spent'},
  ];

  // Controller for manual updates
  final TextEditingController _manualUpdateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _titleController = TextEditingController(text: widget.case_.title);
    _descriptionController = TextEditingController(text: widget.case_.description);
    _selectedCategory = widget.case_.category;
    _selectedStatus = widget.case_.status;
    _documents = List.from(widget.case_.requiredDocuments);
    _sessions = List.from(widget.case_.sessions);
    _updates = List.from(widget.case_.updates);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _manualUpdateController.dispose();
    super.dispose();
  }

  Future<void> _addCaseUpdate({
    required String type,
    required String title,
    required String description,
  }) async {
    // Local dummy update
    setState(() {
      _updates.insert(0, CaseUpdate(
        id: 'upd_${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        title: title,
        description: description,
        date: DateTime.now(),
      ));
    });
  }

  // Theme Constants based on requirements
  static const Color primaryBlue = Color(0xFF001F3F); // Dark Blue
  static const Color legalGold = Color(0xFFFFD700);   // Gold/Yellow
  static const Color bgColorLight = Color(0xFFFCFDFF);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F1419) : const Color(0xFFFCFDFF);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20.sp, color: isDark ? Colors.white : primaryBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.isLawyer ? 'Manage Case'.translate() : 'Case Details'.translate(),
          style: GoogleFonts.cairo(
            fontSize: 18.sp, 
            fontWeight: FontWeight.w700, 
            color: isDark ? Colors.white : primaryBlue,
          ),
        ),
        actions: [
          if (widget.isLawyer)
            _isSaving
                ? const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : TextButton(
                    onPressed: _saveOverviewChanges,
                    child: Text('Save'.translate(), style: GoogleFonts.cairo(color: legalGold, fontWeight: FontWeight.bold)),
                  )
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(isDark),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentTabIndex = index),
              children: [
                _buildOverviewTab(isDark),
                _buildDocumentsTab(isDark),
                _buildSessionsTab(isDark),
                _buildUpdatesTab(isDark),
                _buildFeesTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    final tabs = [
      'Overview'.translate(),
      'Documents'.translate(),
      'Sessions'.translate(),
      'Updates'.translate(),
      'Fees'.translate(),
    ];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isActive = _currentTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Text(
                      tabs[index],
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                        color: isActive ? legalGold : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (isActive) Container(height: 3.h, decoration: BoxDecoration(color: legalGold, borderRadius: BorderRadius.circular(2.r))),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- OVERVIEW TAB ---
  Widget _buildOverviewTab(bool isDark) {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        if (widget.isLawyer) ...[
          _buildLabel('Case Title'.translate()),
          TextField(
            controller: _titleController,
            decoration: _inputDecoration(isDark),
            style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16.h),
        ] else ...[
          Text(_titleController.text, style: GoogleFonts.cairo(fontSize: 20.sp, fontWeight: FontWeight.w800, color: isDark ? Colors.white : primaryBlue)),
          SizedBox(height: 12.h),
        ],
        _buildLabel('Case Status'.translate()),
        widget.isLawyer ? DropdownButtonFormField<String>(
          value: _selectedStatus,
          items: ['active', 'closed', 'on_hold', 'pending'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
          onChanged: (val) => setState(() => _selectedStatus = val),
          decoration: _inputDecoration(isDark),
        ) : _readOnlyField(isDark, _selectedStatus?.toUpperCase() ?? 'N/A'),
        SizedBox(height: 16.h),
        _buildLabel('Category'.translate()),
        widget.isLawyer ? DropdownButtonFormField<String>(
          value: _selectedCategory,
          items: ['Criminal', 'Civil', 'Family', 'Corporate'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (val) => setState(() => _selectedCategory = val),
          decoration: _inputDecoration(isDark),
        ) : _readOnlyField(isDark, _selectedCategory ?? 'N/A'),
        SizedBox(height: 16.h),
        _buildLabel('Case Description'.translate()),
        widget.isLawyer ? TextField(
          controller: _descriptionController,
          maxLines: 5,
          decoration: _inputDecoration(isDark),
          style: GoogleFonts.cairo(fontSize: 14.sp),
        ) : _readOnlyField(isDark, _descriptionController.text, maxLines: 5),
        SizedBox(height: 24.h),
        if (widget.isLawyer)
          ElevatedButton.icon(
            onPressed: _showAddTimelineDialog,
            icon: const Icon(Icons.add_chart_rounded, color: Colors.white),
            label: Text('Add Timeline Event'.translate(), style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              padding: EdgeInsets.symmetric(vertical: 12.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
      ],
    );
  }

  Future<void> _saveOverviewChanges() async {
    setState(() => _isSaving = true);
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 600));
    await _addCaseUpdate(type: 'process', title: 'Details Updated', description: 'Case metadata was modified by the lawyer.');
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Changes saved successfully'.translate())));
  }

  void _showAddTimelineDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New Timeline Event'.translate(), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(hintText: 'e.g., Initial Investigation'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'.translate())),
          TextButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                await _addCaseUpdate(type: 'process', title: 'Timeline Updated', description: titleController.text);
                Navigator.pop(context);
              }
            },
            child: Text('Add'.translate()),
          )
        ],
      ),
    );
  }

  // --- DOCUMENTS TAB ---
  Widget _buildDocumentsTab(bool isDark) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: _documents.length,
            itemBuilder: (context, index) {
              final doc = _documents[index];
              return Container(
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2940) : Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: doc.isSubmitted ? Colors.green : Colors.grey.shade300),
                ),
                child: ListTile(
                  title: Text(doc.name, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  subtitle: Text(doc.description, style: GoogleFonts.cairo(fontSize: 12.sp)),
                  trailing: !widget.isLawyer && !doc.isSubmitted
                      ? TextButton(
                          onPressed: () => _showUploadSimulation(doc.name),
                          child: Text('Upload'.translate(), style: const TextStyle(color: legalGold, fontWeight: FontWeight.bold)),
                        )
                      : Icon(
                          doc.isSubmitted ? Icons.check_circle : Icons.pending_actions,
                          color: doc.isSubmitted ? Colors.green : legalGold,
                        ),
                ),
              );
            },
          ),
        ),
        if (widget.isLawyer) Padding(
          padding: EdgeInsets.all(16.w),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showRequestDocumentModal,
              icon: const Icon(Icons.note_add_rounded, color: Colors.white),
              label: Text('Request Document'.translate(), style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, padding: EdgeInsets.symmetric(vertical: 14.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r))),
            ),
          ),
        ),
      ],
    );
  }

  void _showRequestDocumentModal() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20.w, right: 20.w, top: 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Request New Document'.translate(), style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 16.h),
            TextField(controller: nameController, decoration: _inputDecoration(false).copyWith(hintText: 'Document Title (e.g. ID Copy)')),
            SizedBox(height: 12.h),
            TextField(controller: descController, decoration: _inputDecoration(false).copyWith(hintText: 'Why is this needed?')),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty) return;
                  setState(() {
                    _documents.add(RequiredDocument(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text,
                      description: descController.text,
                      isSubmitted: false,
                      submittedDate: null,
                    ));
                  });
                  await _addCaseUpdate(type: 'action', title: 'Document Requested', description: 'Lawyer requested: ${nameController.text}');
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
                child: Text('Send Request'.translate(), style: const TextStyle(color: Colors.white)),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  // --- SESSIONS TAB ---
  Widget _buildSessionsTab(bool isDark) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: _sessions.length,
            itemBuilder: (context, index) {
              final session = _sessions[index];
              DateTime date = session.scheduledDate;
              
              return Container(
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2940) : Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatDate(date, 'EEEE, MMM dd'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                        _statusBadge(session.status),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(session.location ?? 'TBD', style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey)),
                        if (!widget.isLawyer && session.status == 'scheduled')
                          ElevatedButton(
                            onPressed: () => _showComingSoon('Meeting Link'),
                            style: ElevatedButton.styleFrom(backgroundColor: legalGold, padding: EdgeInsets.symmetric(horizontal: 12.w)),
                            child: Text('Join Meeting'.translate(), style: const TextStyle(fontSize: 10, color: Colors.white)),
                          )
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (widget.isLawyer) Padding(
          padding: EdgeInsets.all(16.w),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showScheduleSessionModal,
              icon: const Icon(Icons.calendar_month, color: Colors.white),
              label: Text('Schedule Session'.translate(), style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, padding: EdgeInsets.symmetric(vertical: 14.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r))),
            ),
          ),
        ),
      ],
    );
  }

  void _showScheduleSessionModal() {
    final titleController = TextEditingController();
    final locController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20.w, right: 20.w, top: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Schedule Session'.translate(), style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 16.h),
              TextField(controller: titleController, decoration: _inputDecoration(false).copyWith(hintText: 'Session Title')),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                        if (d != null) setModalState(() => selectedDate = d);
                      },
                      icon: const Icon(Icons.date_range),
                      label: Text(formatDate(selectedDate, 'MMM dd, yyyy')),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: selectedTime);
                        if (t != null) setModalState(() => selectedTime = t);
                      },
                      icon: const Icon(Icons.access_time),
                      label: Text(selectedTime.format(context)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              TextField(controller: locController, decoration: _inputDecoration(false).copyWith(hintText: 'Location (or Zoom Link)')),
              SizedBox(height: 12.h),
              TextField(controller: notesController, decoration: _inputDecoration(false).copyWith(hintText: 'Additional Notes')),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final fullDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                    setState(() {
                      _sessions.add(CaseSession(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        scheduledDate: fullDateTime,
                        status: 'scheduled',
                        location: locController.text,
                        notes: notesController.text,
                      ));
                    });
                    await _addCaseUpdate(
                      type: 'process',
                      title: 'New Session Scheduled',
                      description: '${titleController.text} on ${formatDate(fullDateTime, 'MMM dd at hh:mm a')}',
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
                  child: Text('Save Session'.translate(), style: const TextStyle(color: Colors.white)),
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  // --- UPDATES TAB ---
  Widget _buildUpdatesTab(bool isDark) {
    final updatesToDisplay = _updates.reversed.toList();
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: updatesToDisplay.length,
            itemBuilder: (context, index) {
              final update = updatesToDisplay[index];
              final date = update.date;
              return _buildUpdateItem(update, date, isDark);
            },
          ),
        ),
        if (widget.isLawyer) Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2940) : Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualUpdateController,
                  decoration: _inputDecoration(isDark).copyWith(hintText: 'Post case progress update...'.translate()),
                  style: GoogleFonts.cairo(fontSize: 13.sp),
                ),
              ),
              SizedBox(width: 8.w),
              IconButton(
                onPressed: _postManualUpdate,
                icon: const Icon(Icons.send_rounded, color: legalGold),
              )
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _postManualUpdate() async {
    if (_manualUpdateController.text.isEmpty) return;
    _addCaseUpdate(
      type: 'info',
      title: 'Lawyer Update',
      description: _manualUpdateController.text,
    );
    setState(() {
      _manualUpdateController.clear();
      FocusScope.of(context).unfocus();
    });
  }

  Widget _buildUpdateItem(CaseUpdate update, DateTime date, bool isDark) {
    final type = update.type;
    IconData icon = Icons.info_outline;
    Color color = isDark ? Colors.white : primaryBlue;

    if (type == 'action') {
      icon = Icons.assignment_turned_in_outlined;
      color = Colors.blue;
    } else if (type == 'process') {
      icon = Icons.trending_up_outlined;
      color = legalGold;
    } else if (type == 'result') {
      icon = Icons.check_circle_outline;
      color = Colors.green;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
            child: Icon(icon, size: 16.sp, color: color),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(update.title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13.sp, color: isDark ? Colors.white : primaryBlue)),
                Text(formatDate(date, 'MMM dd - hh:mm a'), style: TextStyle(fontSize: 10.sp, color: Colors.grey)),
                SizedBox(height: 4.h),
                Text(update.description, style: GoogleFonts.cairo(fontSize: 12.sp, height: 1.4, color: isDark ? Colors.white70 : Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- FEES TAB ---
  Widget _buildFeesTab(bool isDark) {
    final cardColor = isDark ? const Color(0xFF1A2940) : Colors.white;
    final double balance = _totalFunded - _spentAmount;

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        // Client Dashboard View
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          color: cardColor,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 10.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFeeStatColumn('Total Funded'.translate(), _totalFunded, isDark),
                _buildFeeStatColumn('Spent Amount'.translate(), _spentAmount, isDark, color: Colors.red),
                _buildFeeStatColumn('Balance'.translate(), balance, isDark, color: balance < 5000 ? Colors.orange : Colors.green),
              ],
            ),
          ),
        ),
        SizedBox(height: 24.h),
        if (widget.isLawyer) ...[
          _buildLabel('Manage Fees'.translate()),
          _buildFeeManagementForm(isDark),
          SizedBox(height: 24.h),
        ],
        Text('Financial Activity'.translate(), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16.sp, color: isDark ? Colors.white : primaryBlue)),
        SizedBox(height: 12.h),
        ..._financialActivity.map((activity) => 
          _buildActivityItem(activity['date'], activity['title'], '${activity['type'] == 'spent' ? '-' : '+'} ${activity['amount']} EGP', activity['type'] == 'spent' ? Colors.red : Colors.green, isDark)
        ).toList(),
      ],
    );
  }

  Widget _buildFeeStatColumn(String label, dynamic value, bool isDark, {Color? color}) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.cairo(fontSize: 10.sp, color: Colors.grey, fontWeight: FontWeight.bold)),
        SizedBox(height: 4.h),
        Text('${value.toString()} EGP', style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.w900, color: color ?? (isDark ? Colors.white : primaryBlue))),
      ],
    );
  }

  Widget _buildFeeManagementForm(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: TextField(decoration: _inputDecoration(isDark).copyWith(hintText: 'Total Fees'), keyboardType: TextInputType.number)),
            SizedBox(width: 10.w),
            Expanded(child: TextField(decoration: _inputDecoration(isDark).copyWith(hintText: 'Expenses'), keyboardType: TextInputType.number)),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(child: TextField(decoration: _inputDecoration(isDark).copyWith(hintText: 'Log Spent Amount'), keyboardType: TextInputType.number)),
            SizedBox(width: 10.w),
            ElevatedButton(
              onPressed: () => _showComingSoon('Logging'),
              style: ElevatedButton.styleFrom(backgroundColor: legalGold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
              child: const Icon(Icons.add, color: Colors.white),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildActivityItem(String date, String title, String amount, Color amountColor, bool isDark) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1A2940) : Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13.sp, color: isDark ? Colors.white : primaryBlue)),
            Text(date, style: TextStyle(fontSize: 10.sp, color: Colors.grey)),
          ]),
          Text(amount, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: amountColor)),
        ],
      ),
    );
  }

  // --- COMMON UI COMPONENTS ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h, top: 4.h),
      child: Text(text, style: GoogleFonts.cairo(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : primaryBlue)),
    );
  }

  InputDecoration _inputDecoration(bool isDark) {
    return InputDecoration(
      filled: true,
      fillColor: isDark ? const Color(0xFF1A2940) : const Color(0xFFF8FAFE),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: legalGold, width: 1.5),
      ),
    );
  }

  Widget _readOnlyField(bool isDark, String value, {int maxLines = 1}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1A2940) : const Color(0xFFF3F5F9), borderRadius: BorderRadius.circular(12.r)),
      child: Text(value, style: GoogleFonts.cairo(fontSize: 14.sp, color: isDark ? Colors.grey.shade300 : Colors.black87), maxLines: maxLines, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(color: legalGold.withOpacity(0.1), borderRadius: BorderRadius.circular(6.r)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: legalGold)),
    );
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label coming soon...')));
  }

  void _showUploadSimulation(String docName) {
    _showComingSoon('Upload for $docName');
  }
}