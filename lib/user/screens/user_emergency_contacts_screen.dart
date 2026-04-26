import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class UserEmergencyContactsScreen extends StatefulWidget {
  const UserEmergencyContactsScreen({super.key});

  @override
  State<UserEmergencyContactsScreen> createState() =>
      _UserEmergencyContactsScreenState();
}

class _UserEmergencyContactsScreenState
    extends State<UserEmergencyContactsScreen> {
  static const List<String> _emergencyRelations = <String>[
    'Father',
    'Mother',
    'Brother',
    'Sister',
    'Spouse',
    'Friend',
    'Other',
  ];

  final List<_EmergencyContactModel> _contacts = <_EmergencyContactModel>[];
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();

  User? _currentUser;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadContacts();
  }

  @override
  void dispose() {
    for (final contact in _contacts) {
      contact.dispose();
    }
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final currentUser = _currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final data = doc.data() ?? <String, dynamic>{};
      final rawContacts = data['emergencyContacts'];
      final parsedContacts = <_EmergencyContactModel>[];

      if (rawContacts is List) {
        for (final rawContact in rawContacts) {
          if (rawContact is Map) {
            parsedContacts.add(
              _EmergencyContactModel(
                name: rawContact['name']?.toString().trim() ?? '',
                phone: rawContact['phone']?.toString().trim() ?? '',
                relation: _normalizeRelationValue(
                  rawContact['relation']?.toString(),
                ),
              ),
            );
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _contacts
          ..clear()
          ..addAll(parsedContacts);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showSnackBar(
        'Failed to load emergency contacts: $error'.translate(),
        isError: true,
      );
    }
  }

  String _normalizeToEmergencyLocal11(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11 && digits.startsWith('0')) {
      return digits;
    }
    if (digits.length == 12 && digits.startsWith('20')) {
      return '0${digits.substring(2)}';
    }
    if (digits.length == 14 && digits.startsWith('0020')) {
      return '0${digits.substring(4)}';
    }
    return digits;
  }

  String? _validatePhone(String value) {
    final phone = _normalizeToEmergencyLocal11(value);
    if (phone.isEmpty) {
      return 'Emergency contact number is required';
    }
    if (!RegExp(r'^0[0-9]{10}$').hasMatch(phone)) {
      return 'Emergency number must be exactly 11 digits';
    }
    return null;
  }

  String? _validateName(String value) {
    if (value.trim().isEmpty) {
      return 'Emergency contact name is required';
    }
    return null;
  }

  String? _validateRelation(String? relation) {
    if (relation == null || relation.trim().isEmpty) {
      return 'Select relation';
    }
    return null;
  }

  String? _normalizeRelationValue(String? rawRelation) {
    final raw = rawRelation?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    for (final relation in _emergencyRelations) {
      if (relation.toLowerCase() == raw.toLowerCase()) {
        return relation;
      }
    }

    const arabicToEnglish = <String, String>{
      'اب': 'Father',
      'أب': 'Father',
      'الأب': 'Father',
      'ام': 'Mother',
      'أم': 'Mother',
      'الأم': 'Mother',
      'اخ': 'Brother',
      'أخ': 'Brother',
      'الأخ': 'Brother',
      'اخت': 'Sister',
      'أخت': 'Sister',
      'الأخت': 'Sister',
      'زوج': 'Spouse',
      'زوجة': 'Spouse',
      'صديق': 'Friend',
      'صديقة': 'Friend',
      'اخرى': 'Other',
      'أخرى': 'Other',
    };

    return arabicToEnglish[raw];
  }

  List<Map<String, String>> _serializeContacts() {
    return _contacts
        .map(
          (contact) => <String, String>{
            'name': contact.nameController.text.trim(),
            'phone': _normalizeToEmergencyLocal11(contact.phoneController.text),
            'relation': _normalizeRelationValue(contact.relation) ?? '',
          },
        )
        .toList();
  }

  Future<void> _persistContacts({required bool showSuccessMessage}) async {
    final currentUser = _currentUser;
    if (currentUser == null) {
      _showSnackBar('Please sign in again.'.translate(), isError: true);
      return;
    }

    final expectedCount = _serializeContacts().length;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .set(<String, dynamic>{
          'emergencyContacts': _serializeContacts(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final rawContacts = snapshot.data()?['emergencyContacts'];
    final savedCount = rawContacts is List ? rawContacts.length : 0;
    if (savedCount != expectedCount) {
      throw Exception('Could not verify emergency contacts save.');
    }

    if (showSuccessMessage) {
      _showSnackBar(
        'Emergency contacts updated successfully'.translate(),
        isError: false,
      );
    }
  }

  Future<void> _saveContacts() async {
    if (_contacts.isEmpty) {
      _showSnackBar(
        'Add at least one emergency contact.'.translate(),
        isError: true,
      );
      return;
    }

    bool hasError = false;
    final seenNumbers = <String>{};

    for (final contact in _contacts) {
      contact.nameError = _validateName(contact.nameController.text);
      final normalizedPhone = _normalizeToEmergencyLocal11(
        contact.phoneController.text,
      );
      contact.phoneError = _validatePhone(normalizedPhone);
      contact.relation = _normalizeRelationValue(contact.relation);
      contact.relationError = _validateRelation(contact.relation);
      if (contact.phoneError == null && seenNumbers.contains(normalizedPhone)) {
        contact.phoneError = 'Duplicate emergency number';
      }
      if (contact.phoneError == null) {
        seenNumbers.add(normalizedPhone);
      }
      if (contact.nameError != null ||
          contact.phoneError != null ||
          contact.relationError != null) {
        hasError = true;
      }
    }

    if (hasError) {
      if (mounted) {
        setState(() {});
      }
      _showSnackBar(
        'Please complete emergency contacts correctly'.translate(),
        isError: true,
      );
      return;
    }

    if (mounted) {
      setState(() => _isSaving = true);
    }

    try {
      await _persistContacts(showSuccessMessage: true);

      if (!mounted) {
        return;
      }

      setState(() => _isSaving = false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      _showSnackBar(
        'Failed to save emergency contacts: $error'.translate(),
        isError: true,
      );
    }
  }

  Future<void> _addContact() async {
    if (_contacts.length >= 4) {
      _showSnackBar(
        'Maximum 4 emergency contacts allowed.'.translate(),
        isError: true,
      );
      return;
    }

    final contact = await _showContactEditor();
    if (contact == null || !mounted) {
      return;
    }

    setState(() {
      _contacts.add(contact);
    });

    if (!_isSaving) {
      setState(() => _isSaving = true);
    }

    try {
      await _persistContacts(showSuccessMessage: true);
    } catch (error) {
      _showSnackBar(
        'Failed to save emergency contacts: $error'.translate(),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _editContact(int index) async {
    final contact = await _showContactEditor(contact: _contacts[index]);
    if (contact == null || !mounted) {
      return;
    }

    setState(() {
      _contacts[index].nameController.text = contact.nameController.text;
      _contacts[index].phoneController.text = contact.phoneController.text;
      _contacts[index].relation = contact.relation;
      _contacts[index].nameError = null;
      _contacts[index].phoneError = null;
      _contacts[index].relationError = null;
    });

    if (!_isSaving) {
      setState(() => _isSaving = true);
    }

    try {
      await _persistContacts(showSuccessMessage: true);
    } catch (error) {
      _showSnackBar(
        'Failed to save emergency contacts: $error'.translate(),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteContact(int index) async {
    final shouldDelete = await showDialog<bool?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          title: Text(
            'Delete Contact'.translate(),
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w800,
              color: AppColors.navyBlue,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this emergency contact?'
                .translate(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'.translate()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC63F3F),
                foregroundColor: Colors.white,
              ),
              child: Text('Delete'.translate()),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _contacts[index].dispose();
      _contacts.removeAt(index);
    });

    if (!_isSaving) {
      setState(() => _isSaving = true);
    }

    try {
      await _persistContacts(showSuccessMessage: true);
    } catch (error) {
      _showSnackBar(
        'Failed to save emergency contacts: $error'.translate(),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<_EmergencyContactModel?> _showContactEditor({
    _EmergencyContactModel? contact,
  }) async {
    final nameController = TextEditingController(
      text: contact?.nameController.text ?? '',
    );
    final phoneController = TextEditingController(
      text: contact?.phoneController.text ?? '',
    );
    String? nameError;
    String? relation = _normalizeRelationValue(contact?.relation);
    String? phoneError;
    String? relationError;

    final result = await showDialog<_EmergencyContactModel?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22.r),
              ),
              title: Text(
                contact == null
                    ? 'Add Emergency Contact'.translate()
                    : 'Edit Emergency Contact'.translate(),
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navyBlue,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      onChanged: (value) {
                        setDialogState(() {
                          nameError = _validateName(value);
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Emergency Contact Name'.translate(),
                        hintText: 'Full name'.translate(),
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        errorText: nameError?.translate(),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(11),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          phoneError = _validatePhone(value);
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Emergency Phone Number'.translate(),
                        hintText: '01XXXXXXXXX'.translate(),
                        prefixIcon: const Icon(Icons.phone_in_talk_outlined),
                        errorText: phoneError?.translate(),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<String>(
                      initialValue: relation,
                      items: _emergencyRelations
                          .map(
                            (relationItem) => DropdownMenuItem<String>(
                              value: relationItem,
                              child: Text(relationItem.translate()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          relation = value;
                          relationError = _validateRelation(value);
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Relation'.translate(),
                        prefixIcon: const Icon(Icons.people_alt_outlined),
                        errorText: relationError?.translate(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'.translate()),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newNameError = _validateName(nameController.text);
                    final normalizedPhone = _normalizeToEmergencyLocal11(
                      phoneController.text,
                    );
                    final newPhoneError = _validatePhone(normalizedPhone);
                    final newRelationError = _validateRelation(relation);

                    if (newNameError != null ||
                        newPhoneError != null ||
                        newRelationError != null) {
                      setDialogState(() {
                        nameError = newNameError;
                        phoneError = newPhoneError;
                        relationError = newRelationError;
                      });
                      return;
                    }

                    Navigator.of(context).pop(
                      _EmergencyContactModel(
                        name: nameController.text.trim(),
                        phone: normalizedPhone,
                        relation: _normalizeRelationValue(relation),
                      ),
                    );
                  },
                  child: Text('Save'.translate()),
                ),
              ],
            );
          },
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      phoneController.dispose();
    });
    return result;
  }

  void _showSnackBar(String message, {required bool isError}) {
    final messenger =
        _scaffoldKey.currentState ?? ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          content: Text(message),
          backgroundColor: isError ? const Color(0xFFC63F3F) : Colors.green,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F1726)
            : const Color(0xFFF4F7FB),
        // AppBar has been removed completely to give a clean modern look
        body: SafeArea(
          bottom: false,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentUser == null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.r),
                    child: Container(
                      padding: EdgeInsets.all(18.r),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF24344C) : Colors.white,
                        borderRadius: BorderRadius.circular(22.r),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2A3550)
                              : const Color(0xFFE6ECF5),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.navyBlue,
                            size: 40.sp,
                          ),
                          SizedBox(height: 14.h),
                          Text(
                            'No signed in user found'.translate(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navyBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadContacts,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 150.h),
                    children: [
                      _buildHeaderCard(isDark),
                      SizedBox(height: 16.h),
                      if (_contacts.isEmpty)
                        _buildEmptyState(isDark)
                      else
                        ...List<Widget>.generate(
                          _contacts.length,
                          (index) => Padding(
                            padding: EdgeInsets.only(bottom: 14.h),
                            child: _buildContactCard(index, isDark),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        bottomNavigationBar: _buildStickyActionBar(isDark),
      ),
    );
  }

  Widget _buildStickyActionBar(bool isDark) {
    return SafeArea(
      top: false,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 14.h),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xCC111A2A)
                  : Colors.white.withValues(alpha: 0.86),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? const Color(0xFF2A3850)
                      : const Color(0xFFDCE5F2),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving || _contacts.length >= 4
                        ? null
                        : _addContact,
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text('Add Emergency Contact'.translate()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navyBlue,
                      side: const BorderSide(
                        color: AppColors.navyBlue,
                        width: 1.5,
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                _buildSaveButton(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark) {
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
            color: const Color(0xFF0D2345).withValues(alpha: 0.18),
            blurRadius: 20,
            offset: Offset(0, 12.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.h,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  padding: EdgeInsets.zero,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Emergency Contacts'.translate(),
                  style: GoogleFonts.cairo(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '${_contacts.length}/4',
                  style: GoogleFonts.cairo(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            'See, edit, add, or delete the people you want to reach in an emergency.'
                .translate(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.35,
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24344C) : Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3550) : const Color(0xFFE6ECF5),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 66.w,
            height: 66.h,
            decoration: BoxDecoration(
              color: AppColors.navyBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.contact_emergency_outlined,
              color: AppColors.navyBlue,
              size: 34.sp,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'No emergency contacts yet'.translate(),
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.navyBlue,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Add one or more trusted contacts so they are ready when you need them.'
                .translate(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.75)
                  : AppColors.textDark.withValues(alpha: 0.72),
              height: 1.35,
            ),
          ),
          SizedBox(height: 16.h),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _addContact,
            icon: const Icon(Icons.add_circle_outline),
            label: Text('Add Emergency Contact'.translate()),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navyBlue,
              side: const BorderSide(color: AppColors.navyBlue, width: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(int index, bool isDark) {
    final contact = _contacts[index];
    final name = contact.nameController.text.trim().isEmpty
        ? '${'Contact'.translate()} ${index + 1}'
        : contact.nameController.text.trim();
    final relation =
        contact.relation?.translate() ?? 'Relation not set'.translate();
    final phone = contact.phoneController.text.trim().isEmpty
        ? 'No number'.translate()
        : contact.phoneController.text;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24344C) : Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3550) : const Color(0xFFE6ECF5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D2345).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: Offset(0, 10.h),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56.w,
            height: 56.h,
            decoration: BoxDecoration(
              color: AppColors.navyBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_rounded,
              color: AppColors.navyBlue,
              size: 26.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.cairo(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.navyBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  relation,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: (isDark ? Colors.white : AppColors.textDark)
                        .withValues(alpha: 0.6),
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Icon(
                      Icons.phone_in_talk_rounded,
                      size: 14.sp,
                      color: AppColors.legalGold,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      phone,
                      style: GoogleFonts.cairo(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _isSaving ? null : () => _editContact(index),
                icon: const Icon(Icons.edit_outlined),
                color: isDark ? Colors.white70 : AppColors.navyBlue,
                iconSize: 22.sp,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.all(8.r),
              ),
              IconButton(
                onPressed: _isSaving ? null : () => _deleteContact(index),
                icon: const Icon(Icons.delete_outline_rounded),
                color: const Color(0xFFC63F3F),
                iconSize: 22.sp,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.all(8.r),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveContacts,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navyBlue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 14.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        icon: _isSaving
            ? SizedBox(
                width: 20.w,
                height: 20.h,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Icon(Icons.save_outlined),
        label: Text(
          _isSaving ? 'Saving...'.translate() : 'Save Changes'.translate(),
          style: GoogleFonts.cairo(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _EmergencyContactModel {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  String? relation;
  String? nameError;
  String? phoneError;
  String? relationError;

  _EmergencyContactModel({String name = '', String phone = '', this.relation})
    : nameController = TextEditingController(text: name),
      phoneController = TextEditingController(text: phone);

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
  }
}
