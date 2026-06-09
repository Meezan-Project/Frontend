import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/lawyer/screens/office_chat_screen.dart';
import 'package:mezaan/user/models/case_model.dart';
import 'package:mezaan/lawyer/screens/lawyer_case_management_screen.dart';
import 'package:mezaan/lawyer/screens/lawyer_cases_tracker_screen.dart';

class OwnerOfficeManagementScreen extends StatefulWidget {
  final String? officeId;
  const OwnerOfficeManagementScreen({super.key, this.officeId});

  @override
  State<OwnerOfficeManagementScreen> createState() => _OwnerOfficeManagementScreenState();
}

class _OwnerOfficeManagementScreenState extends State<OwnerOfficeManagementScreen>
    with SingleTickerProviderStateMixin {
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  late TabController _tabController;

  // Office Creation Form fields
  final _createFormKey = GlobalKey<FormState>();
  final _officeNameController = TextEditingController();
  final _officeAddressController = TextEditingController();
  bool _isCreatingOffice = false;

  // Search Lawyers fields
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  List<DocumentSnapshot> _allInviteCandidates = [];
  bool _isLoadingCandidates = false;

  // Secretary Form fields
  final _secFormKey = GlobalKey<FormState>();
  final _secNameController = TextEditingController();
  final _secEmailController = TextEditingController();
  final _secPasswordController = TextEditingController();
  bool _isCreatingSecretary = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _searchController.addListener(_onSearchTextChanged);
    _loadInviteCandidates();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _tabController.dispose();
    _officeNameController.dispose();
    _officeAddressController.dispose();
    _searchController.dispose();
    _secNameController.dispose();
    _secEmailController.dispose();
    _secPasswordController.dispose();
    super.dispose();
  }

  // Helper to fetch owner license ID for strict confirmation actions
  Future<String> _getOwnerLicenseId() async {
    if (_currentUserId == null) return '';
    final doc = await FirebaseFirestore.instance.collection('lawyers').doc(_currentUserId).get();
    return doc.data()?['license_ID']?.toString().trim() ?? '';
  }

  // Create new office in Firestore
  void _createOffice() async {
    if (!_createFormKey.currentState!.validate() || _currentUserId == null) return;
    setState(() => _isCreatingOffice = true);

    try {
      final firestore = FirebaseFirestore.instance;
      // Get owner lawyer details
      final ownerDoc = await firestore.collection('lawyers').doc(_currentUserId).get();
      final ownerData = ownerDoc.data() ?? {};
      final ownerName = ownerData['name'] ?? 'Owner Lawyer';
      final ownerLicenseId = ownerData['license_ID'] ?? '';

      final officeId = _currentUserId!; // Owner UID is the officeId
      final officeName = _officeNameController.text.trim();
      final officeAddress = _officeAddressController.text.trim();

      final batch = firestore.batch();

      // Create office doc
      batch.set(firestore.collection('offices').doc(officeId), {
        'officeId': officeId,
        'ownerId': _currentUserId,
        'ownerName': ownerName,
        'ownerLicenseId': ownerLicenseId,
        'name': officeName,
        'address': officeAddress,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update owner lawyer status
      batch.update(firestore.collection('lawyers').doc(_currentUserId), {
        'officeId': officeId,
        'officeRole': 'owner',
      });

      // Add owner as a member
      batch.set(firestore.collection('offices').doc(officeId).collection('members').doc(_currentUserId), {
        'memberId': _currentUserId,
        'name': ownerName,
        'role': 'owner',
        'joinedAt': FieldValue.serverTimestamp(),
        'specialization': ownerData['specialization'] ?? [],
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Office created successfully.'.translate()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create office. Please try again.'.translate()),
            backgroundColor: AppColors.sosRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingOffice = false);
      }
    }
  }

  void _loadInviteCandidates() async {
    if (_currentUserId == null) return;
    setState(() => _isLoadingCandidates = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('lawyers')
          .get();
      if (mounted) {
        setState(() {
          _allInviteCandidates = snapshot.docs;
          _isLoadingCandidates = false;
        });
        _filterInviteCandidates();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCandidates = false);
      }
      debugPrint('Error loading candidates: $e');
    }
  }

  void _onSearchTextChanged() {
    _filterInviteCandidates();
  }

  void _filterInviteCandidates() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchQuery = '';
      });
      return;
    }

    final filtered = _allInviteCandidates.where((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final uid = data['uid'] ?? '';
      
      // Skip if current user (owner)
      if (uid == _currentUserId) return false;

      // Skip if already in another office
      if (data['officeId'] != null) return false;

      final name = (data['name'] ?? '').toString().toLowerCase();
      final licenseId = (data['license_ID'] ?? '').toString().toLowerCase();

      return name.contains(query) || licenseId.contains(query);
    }).toList();

    setState(() {
      _searchResults = filtered;
      _searchQuery = query;
    });
  }

  // Search lawyers for invitation (manual trigger just re-filters)
  void _searchLawyers() {
    _filterInviteCandidates();
  }

  // Invite lawyer to office
  void _inviteLawyer(DocumentSnapshot lawyerDoc) async {
    final lawyer = lawyerDoc.data() as Map<String, dynamic>;
    final lawyerId = lawyer['uid'];
    final officeId = widget.officeId ?? _currentUserId;

    if (officeId == null || lawyerId == null) return;

    // Check if lawyer is already in an office
    if (lawyer['officeId'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This lawyer is already associated with another office.'.translate()),
          backgroundColor: AppColors.sosRed,
        ),
      );
      return;
    }

    try {
      // Get office name
      final officeDoc = await FirebaseFirestore.instance.collection('offices').doc(officeId).get();
      final officeName = officeDoc.data()?['name'] ?? 'Law Office';

      final requestId = '${lawyerId}_$officeId';
      await FirebaseFirestore.instance.collection('office_requests').doc(requestId).set({
        'requestId': requestId,
        'freelancerId': lawyerId,
        'freelancerName': lawyer['name'] ?? '',
        'freelancerLicenseId': lawyer['license_ID'] ?? '',
        'freelancerSpecialization': lawyer['specialization'] ?? [],
        'officeId': officeId,
        'officeName': officeName,
        'ownerId': _currentUserId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation sent successfully.'.translate()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invitation.'.translate()),
            backgroundColor: AppColors.sosRed,
          ),
        );
      }
    }
  }

  // Accept a freelancer's request to join
  void _acceptRequest(DocumentSnapshot requestDoc) async {
    final request = requestDoc.data() as Map<String, dynamic>;
    final freelancerId = request['freelancerId'];
    final officeId = request['officeId'];

    if (freelancerId == null || officeId == null) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // Add to members sub-collection
      batch.set(firestore.collection('offices').doc(officeId).collection('members').doc(freelancerId), {
        'memberId': freelancerId,
        'name': request['freelancerName'] ?? 'Employee Lawyer',
        'role': 'employee',
        'specialization': request['freelancerSpecialization'] ?? [],
        'joinedAt': FieldValue.serverTimestamp(),
        'commissionRate': 15.0, // default rate
      });

      // Update lawyer doc
      batch.update(firestore.collection('lawyers').doc(freelancerId), {
        'officeId': officeId,
        'officeRole': 'employee',
        'work_status': 'Works in an Office',
      });

      // Update request status
      batch.update(firestore.collection('office_requests').doc(requestDoc.id), {
        'status': 'accepted',
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request accepted. Lawyer joined the office.'.translate()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept request.'.translate()),
            backgroundColor: AppColors.sosRed,
          ),
        );
      }
    }
  }

  // Reject request
  void _rejectRequest(DocumentSnapshot requestDoc) async {
    try {
      await FirebaseFirestore.instance
          .collection('office_requests')
          .doc(requestDoc.id)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request rejected/deleted.'.translate()),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process rejection.'.translate()),
            backgroundColor: AppColors.sosRed,
          ),
        );
      }
    }
  }

  // Remove staff member from office
  void _removeMember(Map<String, dynamic> member) async {
    final officeId = widget.officeId ?? _currentUserId;
    if (officeId == null) return;

    final ownerLicenseId = await _getOwnerLicenseId();
    final licenseController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text(
            'Remove Staff'.translate(),
            style: GoogleFonts.cairo(color: AppColors.sosRed, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Are you sure you want to remove ${member['name']}? Enter your License ID to confirm.'
                      .translate(),
                  style: GoogleFonts.cairo(color: AppColors.textDark.withOpacity(0.7), fontSize: 14.sp),
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: licenseController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Owner License ID'.translate(),
                    labelStyle: GoogleFonts.cairo(color: Colors.grey),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.sosRed, width: 1.5.w),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'License ID is required'.translate();
                    }
                    if (value.trim() != ownerLicenseId) {
                      return 'License ID is incorrect'.translate();
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'.translate(), style: GoogleFonts.cairo(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sosRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Text('Confirm Remove'.translate(), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();

        final memberId = member['memberId'];

        if (member['role'] == 'employee') {
          // Revert employee lawyer to freelancer
          batch.update(firestore.collection('lawyers').doc(memberId), {
            'officeId': null,
            'officeRole': 'freelancer',
            'work_status': 'Freelancer',
          });
        } else if (member['role'] == 'secretary') {
          // Update secretary doc
          batch.update(firestore.collection('users').doc(memberId), {
            'officeId': null,
            'ownerId': null,
            'role': 'user', // demote to regular user
            'accountType': 'user',
          });
        }

        // Delete from office members
        batch.delete(firestore.collection('offices').doc(officeId).collection('members').doc(memberId));

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Staff member removed successfully.'.translate()),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove staff member.'.translate()),
              backgroundColor: AppColors.sosRed,
            ),
          );
        }
      }
    }
  }

  // Delete office
  void _deleteOffice() async {
    final officeId = widget.officeId ?? _currentUserId;
    if (officeId == null) return;

    final ownerLicenseId = await _getOwnerLicenseId();
    final licenseController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text(
            'Delete/Close Office'.translate(),
            style: GoogleFonts.cairo(color: AppColors.sosRed, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Are you absolutely sure you want to CLOSE and DELETE this office? All members will be disconnected and this action is permanent. Enter your License ID to confirm.'
                      .translate(),
                  style: GoogleFonts.cairo(color: AppColors.textDark.withOpacity(0.7), fontSize: 14.sp),
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: licenseController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Owner License ID'.translate(),
                    labelStyle: GoogleFonts.cairo(color: Colors.grey),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.sosRed, width: 1.5.w),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'License ID is required'.translate();
                    }
                    if (value.trim() != ownerLicenseId) {
                      return 'License ID is incorrect'.translate();
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'.translate(), style: GoogleFonts.cairo(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sosRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Text('Confirm Delete'.translate(), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final firestore = FirebaseFirestore.instance;
        final membersSnapshot = await firestore.collection('offices').doc(officeId).collection('members').get();

        final batch = firestore.batch();

        for (var memberDoc in membersSnapshot.docs) {
          final member = memberDoc.data();
          final memberId = member['memberId'];

          if (member['role'] == 'employee') {
            batch.update(firestore.collection('lawyers').doc(memberId), {
              'officeId': null,
              'officeRole': 'freelancer',
              'work_status': 'Freelancer',
            });
          } else if (member['role'] == 'secretary') {
            batch.update(firestore.collection('users').doc(memberId), {
              'officeId': null,
              'ownerId': null,
              'role': 'user',
              'accountType': 'user',
            });
          }

          batch.delete(memberDoc.reference);
        }

        // Update owner status
        batch.update(firestore.collection('lawyers').doc(_currentUserId), {
          'officeId': null,
          'officeRole': 'freelancer',
          'work_status': 'Freelancer',
        });

        // Delete office document
        batch.delete(firestore.collection('offices').doc(officeId));

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Office closed and deleted successfully.'.translate()),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete office.'.translate()),
              backgroundColor: AppColors.sosRed,
            ),
          );
        }
      }
    }
  }

  // Create a Secretary account programmatically using a secondary Firebase App instance
  void _createSecretaryAccount() async {
    if (!_secFormKey.currentState!.validate() || _currentUserId == null) return;
    setState(() => _isCreatingSecretary = true);

    final officeId = widget.officeId ?? _currentUserId!;
    final name = _secNameController.text.trim();
    final email = _secEmailController.text.trim();
    final password = _secPasswordController.text;

    try {
      // Initialize temporary secondary app
      FirebaseApp tempApp = await Firebase.initializeApp(
        name: 'SecretaryApp',
        options: Firebase.app().options,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final cred = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final secretaryUid = cred.user!.uid;

      // Clean up secondary app right away
      await tempApp.delete();

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // Write to users collection
      batch.set(firestore.collection('users').doc(secretaryUid), {
        'uid': secretaryUid,
        'name': name,
        'email': email,
        'emailLower': email.toLowerCase(),
        'role': 'secretary',
        'accountType': 'secretary',
        'officeId': officeId,
        'ownerId': _currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add to office members
      batch.set(firestore.collection('offices').doc(officeId).collection('members').doc(secretaryUid), {
        'memberId': secretaryUid,
        'name': name,
        'role': 'secretary',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      _secNameController.clear();
      _secEmailController.clear();
      _secPasswordController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Secretary account created successfully.'.translate()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      String errorMessage = 'Failed to create secretary account.'.translate();
      if (e is FirebaseAuthException) {
        errorMessage = e.message ?? errorMessage;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.sosRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingSecretary = false);
      }
    }
  }

  // Update commission rate dialog
  void _editCommissionRate(Map<String, dynamic> member) async {
    final controller = TextEditingController(text: (member['commissionRate'] ?? 15.0).toString());
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Set Commission Rate'.translate(),
            style: GoogleFonts.cairo(color: AppColors.navyBlue, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Commission %'.translate(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.legalGold, width: 1.5.w),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Required'.translate();
                    final rate = double.tryParse(value);
                    if (rate == null || rate < 0 || rate > 100) return 'Enter value between 0 and 100'.translate();
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'.translate(), style: GoogleFonts.cairo(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, double.parse(controller.text));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue),
              child: Text('Save'.translate(), style: GoogleFonts.cairo(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final officeId = widget.officeId ?? _currentUserId;
      if (officeId == null) return;

      try {
        await FirebaseFirestore.instance
            .collection('offices')
            .doc(officeId)
            .collection('members')
            .doc(member['memberId'])
            .update({'commissionRate': result});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Commission rate updated successfully.'.translate()),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update commission rate.'.translate()),
            backgroundColor: AppColors.sosRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final officeId = widget.officeId ?? _currentUserId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (officeId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // If no office exists yet, show office registration/creation layout
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('offices').doc(officeId).snapshots(),
      builder: (context, officeSnapshot) {
        if (officeSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!officeSnapshot.hasData || !officeSnapshot.data!.exists) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.backgroundGrey,
            body: SingleChildScrollView(
              padding: EdgeInsets.all(24.r),
              child: Form(
                key: _createFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 40.h),
                    Icon(Icons.business_rounded, size: 72.sp, color: AppColors.legalGold),
                    SizedBox(height: 16.h),
                    Text(
                      'Register Law Office'.translate(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.navyBlue,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Create your legal office instance to register secretaries, hire lawyers, track active cases, and handle payouts.'
                          .translate(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 14.sp,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 32.h),
                    TextFormField(
                      controller: _officeNameController,
                      style: GoogleFonts.cairo(color: isDark ? Colors.white : AppColors.textDark),
                      decoration: InputDecoration(
                        labelText: 'Office Name'.translate(),
                        prefixIcon: const Icon(Icons.drive_file_rename_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Office Name is required'.translate();
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: _officeAddressController,
                      style: GoogleFonts.cairo(color: isDark ? Colors.white : AppColors.textDark),
                      decoration: InputDecoration(
                        labelText: 'Office Address'.translate(),
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Office Address is required'.translate();
                        return null;
                      },
                    ),
                    SizedBox(height: 32.h),
                    ElevatedButton(
                      onPressed: _isCreatingOffice ? null : _createOffice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navyBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      child: _isCreatingOffice
                          ? SizedBox(
                              width: 22.w,
                              height: 22.h,
                              child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                            )
                          : Text(
                              'Establish Office'.translate(),
                              style: GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final office = officeSnapshot.data!.data() as Map<String, dynamic>;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.backgroundGrey,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            elevation: 1,
            title: Text(
              office['name'] ?? '',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navyBlue,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.legalGold,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.legalGold,
              tabs: [
                Tab(text: 'Members'.translate()),
                Tab(text: 'Office Cases'.translate()),
                Tab(text: 'Recruitment'.translate()),
                Tab(text: 'Add Secretary'.translate()),
                Tab(text: 'Office Chats'.translate()),
                Tab(text: 'Settings'.translate()),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildMembersTab(officeId, isDark),
              _buildOfficeCasesTab(officeId, isDark),
              _buildRecruitmentTab(officeId, isDark),
              _buildAddSecretaryTab(isDark),
              _buildChatsTab(officeId, isDark),
              _buildSettingsTab(officeId, isDark),
            ],
          ),
        );
      },
    );
  }

  // Widget for Tab 1: Members (Secretaries & Employees)
  Widget _buildMembersTab(String officeId, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offices')
          .doc(officeId)
          .collection('members')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final membersDocs = snapshot.data?.docs ?? [];
        final members = membersDocs.map((doc) => doc.data() as Map<String, dynamic>).toList();

        // Filter out owner from list view
        final staff = members.where((m) => m['role'] != 'owner').toList();

        if (staff.isEmpty) {
          return Center(
            child: Text(
              'No staff members registered yet.'.translate(),
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
                      Text(
                        'Commission: ${member['commissionRate'] ?? 15.0}%'.translate(),
                        style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (member['role'] == 'employee')
                      IconButton(
                        icon: const Icon(Icons.percent, color: AppColors.legalGold),
                        onPressed: () => _editCommissionRate(member),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.sosRed),
                      onPressed: () => _removeMember(member),
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

  // Widget for Tab 2: Recruitment (Invite & Incoming Requests)
  Widget _buildRecruitmentTab(String officeId, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Invite Section Title
          Text(
            'Invite Lawyers'.translate(),
            style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.navyBlue),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.cairo(color: isDark ? Colors.white : AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Search lawyer by name or license ID...'.translate(),
                    hintStyle: GoogleFonts.cairo(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              ElevatedButton(
                onPressed: _searchLawyers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: Text('Search'.translate(), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Search Results
          if (_isSearching || _isLoadingCandidates)
            const Center(child: CircularProgressIndicator())
          else if (_searchResults.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final lawyerDoc = _searchResults[index];
                final lawyer = lawyerDoc.data() as Map<String, dynamic>;

                // Skip if current owner or already has office
                if (lawyer['uid'] == _currentUserId) return const SizedBox();

                return Card(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  margin: EdgeInsets.only(bottom: 8.h),
                  child: ListTile(
                    title: Text(lawyer['name'] ?? '', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    subtitle: Text('License: ${lawyer['license_ID'] ?? ''}', style: GoogleFonts.cairo(fontSize: 12.sp)),
                    trailing: ElevatedButton(
                      onPressed: () => _inviteLawyer(lawyerDoc),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.legalGold),
                      child: Text('Invite'.translate(), style: GoogleFonts.cairo(color: Colors.white)),
                    ),
                  ),
                );
              },
            ),

          SizedBox(height: 24.h),
          const Divider(),
          SizedBox(height: 12.h),

          // Incoming Join Requests Section Title
          Text(
            'Incoming Join Requests'.translate(),
            style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.navyBlue),
          ),
          SizedBox(height: 12.h),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('office_requests')
                .where('officeId', isEqualTo: officeId)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final requests = snapshot.data?.docs ?? [];
              if (requests.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  child: Center(
                    child: Text(
                      'No pending join requests.'.translate(),
                      style: GoogleFonts.cairo(color: Colors.grey),
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final requestDoc = requests[index];
                  final request = requestDoc.data() as Map<String, dynamic>;

                  return Card(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    margin: EdgeInsets.only(bottom: 12.h),
                    child: Padding(
                      padding: EdgeInsets.all(12.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            request['freelancerName'] ?? '',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15.sp),
                          ),
                          Text(
                            '${'License ID'.translate()}: ${request['freelancerLicenseId'] ?? ''}',
                            style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey),
                          ),
                          Text(
                            '${'Specialization'.translate()}: ${(request['freelancerSpecialization'] as List? ?? []).join(', ')}',
                            style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey),
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _rejectRequest(requestDoc),
                                child: Text('Reject'.translate(), style: GoogleFonts.cairo(color: AppColors.sosRed)),
                              ),
                              SizedBox(width: 12.w),
                              ElevatedButton(
                                onPressed: () => _acceptRequest(requestDoc),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue),
                                child: Text('Accept'.translate(), style: GoogleFonts.cairo(color: Colors.white)),
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
          ),
        ],
      ),
    );
  }

  // Widget for Tab 3: Create Secretary Form
  Widget _buildAddSecretaryTab(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.r),
      child: Form(
        key: _secFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Secretary Account'.translate(),
              style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.navyBlue),
            ),
            SizedBox(height: 8.h),
            Text(
              'Provision a credentials-based account that lets the secretary view and manage schedule, appointments, cases, and operations without accessing your wallet.'
                  .translate(),
              style: GoogleFonts.cairo(fontSize: 13.sp, color: Colors.grey),
            ),
            SizedBox(height: 24.h),
            TextFormField(
              controller: _secNameController,
              style: GoogleFonts.cairo(color: isDark ? Colors.white : AppColors.textDark),
              decoration: InputDecoration(
                labelText: 'Full Name'.translate(),
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Full Name is required'.translate();
                return null;
              },
            ),
            SizedBox(height: 16.h),
            TextFormField(
              controller: _secEmailController,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.cairo(color: isDark ? Colors.white : AppColors.textDark),
              decoration: InputDecoration(
                labelText: 'Email Address'.translate(),
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Email is required'.translate();
                if (!value.contains('@')) return 'Enter a valid email address'.translate();
                return null;
              },
            ),
            SizedBox(height: 16.h),
            TextFormField(
              controller: _secPasswordController,
              obscureText: true,
              style: GoogleFonts.cairo(color: isDark ? Colors.white : AppColors.textDark),
              decoration: InputDecoration(
                labelText: 'Password'.translate(),
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Password is required'.translate();
                if (value.length < 6) return 'Password must be at least 6 characters'.translate();
                return null;
              },
            ),
            SizedBox(height: 32.h),
            ElevatedButton(
              onPressed: _isCreatingSecretary ? null : _createSecretaryAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: _isCreatingSecretary
                  ? SizedBox(
                      width: 22.w,
                      height: 22.h,
                      child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                    )
                  : Text(
                      'Create Account'.translate(),
                      style: GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget for Tab 4: Chats (Group Chat & 1-on-1 List)
  Widget _buildChatsTab(String officeId, bool isDark) {
    return ListView(
      padding: EdgeInsets.all(16.r),
      children: [
        // Global Chat Option
        Card(
          color: AppColors.navyBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          child: ListTile(
            contentPadding: EdgeInsets.all(16.r),
            leading: CircleAvatar(
              backgroundColor: AppColors.legalGold,
              child: const Icon(Icons.group, color: Colors.white),
            ),
            title: Text(
              'Global Office Chat'.translate(),
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16.sp),
            ),
            subtitle: Text(
              'Group conversation with all office members'.translate(),
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12.sp),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OfficeChatScreen(
                    officeId: officeId,
                    chatTitle: 'Global Office Chat'.translate(),
                    isGroupChat: true,
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          '1-on-1 Staff Chats'.translate(),
          style: GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.navyBlue),
        ),
        SizedBox(height: 12.h),

        // Retrieve members to list for 1-on-1 chats
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('offices')
              .doc(officeId)
              .collection('members')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final membersDocs = snapshot.data?.docs ?? [];
            final staff = membersDocs
                .map((doc) => doc.data() as Map<String, dynamic>)
                .where((m) => m['memberId'] != _currentUserId)
                .toList();

            if (staff.isEmpty) {
              return Center(
                child: Text(
                  'No other staff members available to chat.'.translate(),
                  style: GoogleFonts.cairo(color: Colors.grey),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: staff.length,
              itemBuilder: (context, index) {
                final member = staff[index];

                return Card(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  margin: EdgeInsets.only(bottom: 8.h),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.navyBlue.withOpacity(0.1),
                      child: Icon(
                        member['role'] == 'secretary' ? Icons.support_agent : Icons.person,
                        color: AppColors.navyBlue,
                      ),
                    ),
                    title: Text(member['name'] ?? '', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      member['role'] == 'secretary' ? 'Secretary'.translate() : 'Employee Lawyer'.translate(),
                      style: GoogleFonts.cairo(fontSize: 11.sp),
                    ),
                    trailing: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.legalGold),
                    onTap: () {
                      // Construct sorted unique chatId for 1-on-1 chats
                      final sortedIds = [_currentUserId!, member['memberId'] as String]..sort();
                      final chatId = 'office_1on1_${sortedIds[0]}_${sortedIds[1]}';

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OfficeChatScreen(
                            officeId: officeId,
                            chatId: chatId,
                            chatTitle: member['name'] ?? 'Chat',
                            isGroupChat: false,
                            targetUserId: member['memberId'],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // Widget for Tab 5: Settings
  Widget _buildSettingsTab(String officeId, bool isDark) {
    return ListView(
      padding: EdgeInsets.all(24.r),
      children: [
        Text(
          'Office Operations'.translate(),
          style: GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.navyBlue),
        ),
        SizedBox(height: 12.h),
        Card(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          child: ListTile(
            leading: const Icon(Icons.delete_forever, color: AppColors.sosRed),
            title: Text(
              'Close and Delete Office'.translate(),
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.sosRed),
            ),
            subtitle: Text(
              'Disconnect all staff members and permanently delete office files'.translate(),
              style: GoogleFonts.cairo(fontSize: 12.sp),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.sosRed),
            onTap: _deleteOffice,
          ),
        ),
      ],
    );
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

  // Widget for Tab 2: Office Cases (Unified Cases Management for Owner)
  Widget _buildOfficeCasesTab(String officeId, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cases')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allCasesDocs = snapshot.data?.docs ?? [];
        
        // Filter in-memory for officeId == officeId OR lawyerId == ownerId (_currentUserId)
        final officeCases = allCasesDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final String? caseOfficeId = data['officeId'];
          final String? caseLawyerId = data['lawyerId'];
          return caseOfficeId == officeId || caseLawyerId == _currentUserId;
        }).toList();

        if (officeCases.isEmpty) {
          return Center(
            child: Text(
              'No cases found for this office.'.translate(),
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
              child: InkWell(
                borderRadius: BorderRadius.circular(12.r),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LawyerCaseDetailsScreen(case_: userCase, isLawyer: true),
                    ),
                  );
                },
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
                              Row(
                                children: [
                                  Text(
                                    userCase.lawyerName.isNotEmpty ? userCase.lawyerName : 'Unassigned'.translate(),
                                    style: GoogleFonts.cairo(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : AppColors.navyBlue,
                                    ),
                                  ),
                                  if (userCase.lawyerName.isNotEmpty && userCase.isOfficeAssigned) ...[
                                    SizedBox(width: 8.w),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                      decoration: BoxDecoration(
                                        color: AppColors.legalGold.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Text(
                                        '${userCase.commissionRate}%',
                                        style: GoogleFonts.cairo(
                                          color: AppColors.legalGold,
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
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.assignment_ind_rounded, color: AppColors.legalGold),
                                tooltip: 'Assign Lawyer'.translate(),
                                onPressed: () => _assignCaseToLawyer(officeId, caseDoc.id, userCase.lawyerId),
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
              ),
            );
          },
        );
      },
    );
  }
}
