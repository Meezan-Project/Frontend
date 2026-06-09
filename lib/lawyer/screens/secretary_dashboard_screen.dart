import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/auth/auth_state.dart';
import 'package:mezaan/shared/auth/firebase_session_service.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
import 'package:mezaan/lawyer/screens/lawyer_calendar_schedule_screen.dart';
import 'package:mezaan/user/models/case_model.dart';
import 'package:mezaan/lawyer/screens/lawyer_case_management_screen.dart';
import 'package:mezaan/lawyer/screens/lawyer_cases_tracker_screen.dart';


class SecretaryDashboardScreen extends StatefulWidget {
  const SecretaryDashboardScreen({super.key});

  @override
  State<SecretaryDashboardScreen> createState() => _SecretaryDashboardScreenState();
}

class _SecretaryDashboardScreenState extends State<SecretaryDashboardScreen> {
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  int _selectedIndex = 0;

  String? _ownerId;
  String? _officeId;
  String? _officeName;
  String? _ownerName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSecretaryMetadata();
  }

  void _loadSecretaryMetadata() async {
    if (_currentUserId == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          _ownerId = data['ownerId'];
          _officeId = data['officeId'];
          _isLoading = false;
        });

        if (_officeId != null) {
          final officeDoc = await FirebaseFirestore.instance.collection('offices').doc(_officeId).get();
          if (officeDoc.exists) {
            final officeData = officeDoc.data() ?? {};
            setState(() {
              _officeName = officeData['name'];
              _ownerName = officeData['ownerName'];
            });
          }
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : AppColors.backgroundGrey;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_officeId == null || _ownerId == null) {
      return Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleLogout,
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.r),
            child: Text(
              'No active office link found for this secretary account. Please contact your office Owner.'.translate(),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _officeName ?? 'Office Secretary'.translate(),
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
                color: isDark ? Colors.white : AppColors.navyBlue,
              ),
            ),
            Text(
              '${'Owner'.translate()}: ${_ownerName ?? ''}',
              style: GoogleFonts.cairo(
                fontSize: 11.sp,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8.w),
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.legalGold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              'Secretary'.translate(),
              style: GoogleFonts.cairo(
                color: AppColors.legalGold,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.sosRed),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _buildSelectedTab(isDark),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: AppColors.legalGold,
        unselectedItemColor: Colors.grey,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_month_rounded),
            label: 'Schedule'.translate(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.assignment_rounded),
            label: 'Cases'.translate(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.business_rounded),
            label: 'Office'.translate(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTab(bool isDark) {
    switch (_selectedIndex) {
      case 0:
        return LawyerCalendarScheduleScreen(lawyerId: _ownerId);
      case 1:
        return _buildCasesView(isDark);
      case 2:
        return _buildOfficeView(isDark);
      default:
        return const SizedBox();
    }
  }

  // Fetch all lawyers registered in the office (owner + employee lawyers)
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

  // Assign or re-assign office case to a specific lawyer
  void _assignCaseToLawyer(String officeId, String caseDocId, String currentLawyerId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lawyers = await _getOfficeLawyers(officeId);
    if (!mounted) return;

    String? selectedLawyerId = currentLawyerId;
    if (lawyers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No lawyers found in this office.'.translate())),
      );
      return;
    }

    // Ensure current lawyer id is valid in option list, otherwise default to first option
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Case assigned successfully.'.translate()),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to assign case.'.translate()),
              backgroundColor: AppColors.sosRed,
            ),
          );
        }
      }
    }
  }

  // Cases List Subview (Supports details viewing and dropdown assignment)
  Widget _buildCasesView(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cases')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allCasesDocs = snapshot.data?.docs ?? [];
        
        // Filter in-memory for officeId == _officeId OR lawyerId == _ownerId
        final officeCases = allCasesDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final String? caseOfficeId = data['officeId'];
          final String? caseLawyerId = data['lawyerId'];
          return caseOfficeId == _officeId || caseLawyerId == _ownerId;
        }).toList();

        if (officeCases.isEmpty) {
          return Center(
            child: Text(
              'No active cases found for this office.'.translate(),
              style: GoogleFonts.cairo(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: officeCases.length,
          padding: EdgeInsets.all(16.r),
          itemBuilder: (context, index) {
            final caseDoc = officeCases[index];
            final userCase = UserCase.fromFirestore(caseDoc);

            return Card(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              margin: EdgeInsets.only(bottom: 12.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              child: Padding(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          userCase.caseNumber.isNotEmpty ? userCase.caseNumber : 'Case #${userCase.id.substring(0, 5)}',
                          style: GoogleFonts.cairo(
                            color: AppColors.legalGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            userCase.status.toUpperCase().translate(),
                            style: GoogleFonts.cairo(
                              color: Colors.green,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      userCase.title,
                      style: GoogleFonts.cairo(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.navyBlue,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      userCase.description,
                      style: GoogleFonts.cairo(
                        fontSize: 13.sp,
                        color: isDark ? Colors.white70 : AppColors.textDark.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 12.h),
                    Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                    SizedBox(height: 8.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assigned Lawyer:'.translate(),
                              style: GoogleFonts.cairo(fontSize: 11.sp, color: Colors.grey),
                            ),
                            Text(
                              userCase.lawyerName.isNotEmpty ? userCase.lawyerName : 'Unassigned'.translate(),
                              style: GoogleFonts.cairo(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.navyBlue,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.assignment_ind_rounded, color: AppColors.legalGold),
                              tooltip: 'Assign Lawyer'.translate(),
                              onPressed: () {
                                if (_officeId != null) {
                                  _assignCaseToLawyer(_officeId!, caseDoc.id, userCase.lawyerId);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.visibility_rounded, color: AppColors.navyBlue),
                              tooltip: 'View Details'.translate(),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LawyerCaseDetailsScreen(case_: userCase, isLawyer: true),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Office Members View (Read-only, no staff delete buttons)
  Widget _buildOfficeView(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offices')
          .doc(_officeId)
          .collection('members')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final membersDocs = snapshot.data?.docs ?? [];
        final members = membersDocs.map((doc) => doc.data() as Map<String, dynamic>).toList();

        // Filter out owner for view clean-up
        final staff = members.where((m) => m['role'] != 'owner').toList();

        if (staff.isEmpty) {
          return Center(
            child: Text(
              'No other staff members registered.'.translate(),
              style: GoogleFonts.cairo(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: staff.length,
          padding: EdgeInsets.all(16.r),
          itemBuilder: (context, index) {
            final member = staff[index];
            final String roleName = member['role'] == 'secretary' ? 'Secretary'.translate() : 'Lawyer'.translate();

            return Card(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              margin: EdgeInsets.only(bottom: 12.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              child: ListTile(
                onTap: member['role'] == 'employee'
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LawyerCasesTrackerScreen(
                              lawyerId: member['memberId'],
                              lawyerName: member['name'] ?? 'Lawyer',
                            ),
                          ),
                        );
                      }
                    : null,
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                title: Text(
                  member['name'] ?? '',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.navyBlue,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Role: $roleName'.translate(),
                      style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey),
                    ),
                    if (member['role'] == 'employee') ...[
                      Text(
                        'Specialty: ${(member['specialization'] as List? ?? []).join(', ')}'.translate(),
                        style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

