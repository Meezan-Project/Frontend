import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';

class LawyerOnboardingScreen extends StatefulWidget {
  const LawyerOnboardingScreen({super.key});

  @override
  State<LawyerOnboardingScreen> createState() => _LawyerOnboardingScreenState();
}

class _LawyerOnboardingScreenState extends State<LawyerOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Work Status
  String _workStatus = 'Freelancer';

  // "Works in an Office" Fields
  final _employerLawyerController = TextEditingController();

  // "Owns an Office" Fields
  final _officeGovernorateController = TextEditingController();
  final _officeCityController = TextEditingController();
  final _officeAddressController = TextEditingController();
  final _officePhoneController = TextEditingController();

  // Professional Details
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();
  final _feesController = TextEditingController();

  // Schedule Builder
  final List<String> _daysOfWeek = [
    'Saturday',
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];
  final Map<String, bool> _selectedDays = {};
  final Map<String, TimeOfDay?> _startTime = {};
  final Map<String, TimeOfDay?> _endTime = {};
  final MapController _officeMapController = MapController();

  static const LatLng _defaultOfficeMapCenter = LatLng(30.0444, 31.2357);
  LatLng? _selectedOfficeLocation;
  String? _selectedOfficeLocationName;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (var day in _daysOfWeek) {
      _selectedDays[day] = false;
      _startTime[day] = null;
      _endTime[day] = null;
    }
  }

  @override
  void dispose() {
    _employerLawyerController.dispose();
    _officeGovernorateController.dispose();
    _officeCityController.dispose();
    _officeAddressController.dispose();
    _officePhoneController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _feesController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(String day, bool isStart) async {
    final initialTime =
        (isStart ? _startTime[day] : _endTime[day]) ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime[day] = picked;
        } else {
          _endTime[day] = picked;
        }
      });
    }
  }

  Future<void> _submitOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    if (_workStatus == 'Owns an Office' && _selectedOfficeLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select your office location on the map.'.translate(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate Schedule
    bool scheduleValid = true;
    Map<String, dynamic> firestoreSchedule = {};

    for (var day in _daysOfWeek) {
      if (_selectedDays[day] == true) {
        final start = _startTime[day];
        final end = _endTime[day];
        if (start == null || end == null) {
          scheduleValid = false;
          break;
        }
        firestoreSchedule[day] = {
          'selected': true,
          'from':
              '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
          'to':
              '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
        };
      }
    }

    if (!scheduleValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select From and To times for all selected working days.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not authenticated.");

      final lawyersRef = FirebaseFirestore.instance
          .collection('lawyers')
          .doc(uid);

      final updateData = <String, dynamic>{
        'uid': uid,
        'role': 'lawyer',
        'work_status': _workStatus,
        'professional_bio': _bioController.text.trim(),
        'years_of_experience':
            int.tryParse(_experienceController.text.trim()) ?? 0,
        'consultation_fees':
            double.tryParse(_feesController.text.trim()) ?? 0.0,
        'schedule': firestoreSchedule,
        'onboardingCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Include Conditional Data
      if (_workStatus == 'Works in an Office') {
        updateData['employer_lawyer_name'] = _employerLawyerController.text
            .trim();
      } else if (_workStatus == 'Owns an Office') {
        updateData['office_details'] = {
          'governorate': _officeGovernorateController.text.trim(),
          'city': _officeCityController.text.trim(),
          'address': _officeAddressController.text.trim(),
          'phone': _officePhoneController.text.trim(),
          'location': _selectedOfficeLocation == null
              ? null
              : {
                  'latitude': _selectedOfficeLocation!.latitude,
                  'longitude': _selectedOfficeLocation!.longitude,
                  'displayName': _selectedOfficeLocationName ?? '',
                },
        };
      }

      await lawyersRef
          .set(updateData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Onboarding completed successfully!'),
        ),
      );

      LoadingNavigator.pushReplacementNamed(context, AppRoutes.lawyerHome);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error saving details: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openOfficeLocationPicker() async {
    final result = await Navigator.of(context).push<_OfficeLocationSelection>(
      MaterialPageRoute<_OfficeLocationSelection>(
        builder: (context) => _OfficeLocationPickerScreen(
          initialLocation: _selectedOfficeLocation,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedOfficeLocation = result.location;
      _selectedOfficeLocationName = result.displayName;

      if (result.city != null && result.city!.isNotEmpty) {
        _officeCityController.text = result.city!;
      }

      if (result.governorate != null && result.governorate!.isNotEmpty) {
        _officeGovernorateController.text = result.governorate!;
      }

      if (result.displayName != null && result.displayName!.isNotEmpty) {
        _officeAddressController.text = result.displayName!;
      }
    });

    if (_officeMapController.camera.zoom > 0) {
      _officeMapController.move(result.location, 14.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.30,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF8B7500),
                    AppColors.legalGold,
                    Color(0xFF6B5900),
                  ],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(56),
                ),
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 18.h),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.badge_rounded,
                        color: Colors.white,
                        size: 60.sp,
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        'Complete Lawyer Profile'.translate(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Finish onboarding to access your dashboard'
                            .translate(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, -24.h),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(18.r),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Professional Setup'.translate(),
                            style: textTheme.titleLarge?.copyWith(
                              color: AppColors.navyBlue,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Please provide your work details, fees, and schedule.'
                                .translate(),
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 18.h),

                          _OnboardingSectionCard(
                            title: 'Work Status'.translate(),
                            icon: Icons.apartment_rounded,
                            child: Column(
                              children: [
                                _StatusTile(
                                  title: 'Owns an Office'.translate(),
                                  value: 'Owns an Office',
                                  groupValue: _workStatus,
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _workStatus = value);
                                  },
                                ),
                                _StatusTile(
                                  title: 'Works in an Office'.translate(),
                                  value: 'Works in an Office',
                                  groupValue: _workStatus,
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _workStatus = value;
                                      _selectedOfficeLocation = null;
                                    });
                                  },
                                ),
                                _StatusTile(
                                  title: 'Freelancer'.translate(),
                                  value: 'Freelancer',
                                  groupValue: _workStatus,
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _workStatus = value;
                                      _selectedOfficeLocation = null;
                                    });
                                  },
                                ),
                                if (_workStatus == 'Works in an Office') ...[
                                  SizedBox(height: 10.h),
                                  TextFormField(
                                    controller: _employerLawyerController,
                                    decoration: _inputDecoration(
                                      label: 'Office/Lawyer Name'.translate(),
                                      hint:
                                          'Search or type the name manually...'
                                              .translate(),
                                      icon: Icons.search_rounded,
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Required field'.translate()
                                        : null,
                                  ),
                                ],
                                if (_workStatus == 'Owns an Office') ...[
                                  SizedBox(height: 10.h),
                                  GestureDetector(
                                    onTap: _openOfficeLocationPicker,
                                    child: Container(
                                      height: 220.h,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FBFF),
                                        borderRadius: BorderRadius.circular(
                                          14.r,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFD8E4F6),
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Stack(
                                        children: [
                                          IgnorePointer(
                                            child: FlutterMap(
                                              mapController:
                                                  _officeMapController,
                                              options: MapOptions(
                                                initialCenter:
                                                    _selectedOfficeLocation ??
                                                    _defaultOfficeMapCenter,
                                                initialZoom: 12.5,
                                              ),
                                              children: [
                                                TileLayer(
                                                  urlTemplate:
                                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                  userAgentPackageName:
                                                      'com.mezaan.app',
                                                ),
                                                if (_selectedOfficeLocation !=
                                                    null)
                                                  MarkerLayer(
                                                    markers: [
                                                      Marker(
                                                        point:
                                                            _selectedOfficeLocation!,
                                                        width: 46.w,
                                                        height: 46.h,
                                                        child: Icon(
                                                          Icons
                                                              .location_on_rounded,
                                                          color: AppColors
                                                              .legalGold,
                                                          size: 38.sp,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Positioned(
                                            top: 10.h,
                                            left: 10.w,
                                            right: 10.w,
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10.w,
                                                vertical: 8.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.92,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10.r),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFDCE6F5,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                _selectedOfficeLocation == null
                                                    ? 'Tap to open full map and select office location'
                                                          .translate()
                                                    : _selectedOfficeLocationName
                                                              ?.trim()
                                                              .isNotEmpty ==
                                                          true
                                                    ? _selectedOfficeLocationName!
                                                    : '${'Selected: '.translate()}${_selectedOfficeLocation!.latitude.toStringAsFixed(5)}, ${_selectedOfficeLocation!.longitude.toStringAsFixed(5)}',
                                                style: TextStyle(
                                                  fontSize: 11.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.navyBlue,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 10.h,
                                            right: 10.w,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: AppColors.navyBlue,
                                                borderRadius:
                                                    BorderRadius.circular(10.r),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10.w,
                                                vertical: 8.h,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.fullscreen_rounded,
                                                    color: Colors.white,
                                                    size: 16.sp,
                                                  ),
                                                  SizedBox(width: 6.w),
                                                  Text(
                                                    'Open Full Map'.translate(),
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11.sp,
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                  SizedBox(height: 12.h),
                                  TextFormField(
                                    controller: _officeGovernorateController,
                                    decoration: _inputDecoration(
                                      label: 'Governorate'.translate(),
                                      hint: 'Enter governorate'.translate(),
                                      icon: Icons.location_city_rounded,
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Required field'.translate()
                                        : null,
                                  ),
                                  SizedBox(height: 10.h),
                                  TextFormField(
                                    controller: _officeCityController,
                                    decoration: _inputDecoration(
                                      label: 'City'.translate(),
                                      hint: 'Enter city'.translate(),
                                      icon: Icons.location_on_outlined,
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Required field'.translate()
                                        : null,
                                  ),
                                  SizedBox(height: 10.h),
                                  TextFormField(
                                    controller: _officeAddressController,
                                    decoration: _inputDecoration(
                                      label: 'Detailed Address'.translate(),
                                      hint: 'Street, building, floor...'
                                          .translate(),
                                      icon: Icons.home_work_outlined,
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Required field'.translate()
                                        : null,
                                  ),
                                  SizedBox(height: 10.h),
                                  TextFormField(
                                    controller: _officePhoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: _inputDecoration(
                                      label: 'Office Phone Number'.translate(),
                                      hint: '+201XXXXXXXXX'.translate(),
                                      icon: Icons.phone_outlined,
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Required field'.translate()
                                        : null,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: 14.h),

                          _OnboardingSectionCard(
                            title: 'Professional Details'.translate(),
                            icon: Icons.workspace_premium_outlined,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _bioController,
                                  maxLines: 4,
                                  decoration: _inputDecoration(
                                    label: 'Professional Bio'.translate(),
                                    hint:
                                        'Describe your legal background and approach...'
                                            .translate(),
                                    icon: Icons.description_outlined,
                                    alignLabelWithHint: true,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please provide a brief professional bio.'
                                          .translate();
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 12.h),
                                TextFormField(
                                  controller: _experienceController,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration(
                                    label: 'Years of Experience'.translate(),
                                    hint: 'e.g. 5'.translate(),
                                    icon: Icons.work_outline,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Required'.translate();
                                    }
                                    if (int.tryParse(value) == null) {
                                      return 'Must be a valid number'
                                          .translate();
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 12.h),
                                TextFormField(
                                  controller: _feesController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _inputDecoration(
                                    label: 'Consultation Fees (Starts from)'
                                        .translate(),
                                    hint: 'e.g. 500'.translate(),
                                    icon: Icons.payments_outlined,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Required'.translate();
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Must be a valid number'
                                          .translate();
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 14.h),

                          _OnboardingSectionCard(
                            title: 'Schedule Builder'.translate(),
                            icon: Icons.calendar_month_rounded,
                            child: Column(
                              children: _daysOfWeek.map((day) {
                                final isSelected = _selectedDays[day] == true;
                                return Container(
                                  margin: EdgeInsets.only(bottom: 10.h),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFFFFAED)
                                        : const Color(0xFFF8FBFF),
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.legalGold
                                          : const Color(0xFFDCE6F5),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10.w,
                                      vertical: 6.h,
                                    ),
                                    child: Column(
                                      children: [
                                        CheckboxListTile(
                                          value: isSelected,
                                          activeColor: AppColors.legalGold,
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(
                                            day.translate(),
                                            style: TextStyle(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.navyBlue,
                                            ),
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedDays[day] =
                                                  value ?? false;
                                            });
                                          },
                                        ),
                                        if (isSelected)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              left: 2.w,
                                              right: 2.w,
                                              bottom: 8.h,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: _TimePickerButton(
                                                    title: 'From'.translate(),
                                                    value:
                                                        _startTime[day]?.format(
                                                          context,
                                                        ) ??
                                                        '--:--',
                                                    onPressed: () =>
                                                        _selectTime(day, true),
                                                  ),
                                                ),
                                                SizedBox(width: 10.w),
                                                Expanded(
                                                  child: _TimePickerButton(
                                                    title: 'To'.translate(),
                                                    value:
                                                        _endTime[day]?.format(
                                                          context,
                                                        ) ??
                                                        '--:--',
                                                    onPressed: () =>
                                                        _selectTime(day, false),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          SizedBox(height: 24.h),
                          SizedBox(
                            width: double.infinity,
                            height: 56.h,
                            child: ElevatedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : _submitOnboarding,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.legalGold,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                              ),
                              child: _isSubmitting
                                  ? SizedBox(
                                      width: 22.w,
                                      height: 22.h,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Complete Onboarding'.translate(),
                                      style: TextStyle(
                                        fontSize: 17.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: 10.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      prefixIcon: Icon(icon, color: AppColors.navyBlue),
      filled: true,
      fillColor: const Color(0xFFF8FBFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: Color(0xFFDCE6F5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: Color(0xFFDCE6F5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: AppColors.navyBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }
}

class _OnboardingSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _OnboardingSectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE6EDF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34.w,
                height: 34.h,
                decoration: BoxDecoration(
                  color: AppColors.navyBlue.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, color: AppColors.navyBlue, size: 18.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.navyBlue,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String title;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _StatusTile({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFDCE6F5)),
      ),
      child: RadioListTile<String>(
        dense: true,
        activeColor: AppColors.legalGold,
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.navyBlue,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TimePickerButton extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onPressed;

  const _TimePickerButton({
    required this.title,
    required this.value,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navyBlue,
        side: const BorderSide(color: Color(0xFFDCE6F5)),
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time_rounded, size: 16.sp),
          SizedBox(width: 6.w),
          Flexible(
            child: Text(
              '$title: $value',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficeLocationSelection {
  final LatLng location;
  final String? displayName;
  final String? city;
  final String? governorate;

  const _OfficeLocationSelection({
    required this.location,
    this.displayName,
    this.city,
    this.governorate,
  });
}

class _OfficeLocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const _OfficeLocationPickerScreen({required this.initialLocation});

  @override
  State<_OfficeLocationPickerScreen> createState() =>
      _OfficeLocationPickerScreenState();
}

class _OfficeLocationPickerScreenState
    extends State<_OfficeLocationPickerScreen> {
  static const LatLng _defaultCenter = LatLng(30.0444, 31.2357);

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _pickedLocation;
  String? _resolvedDisplayName;
  String? _resolvedCity;
  String? _resolvedGovernorate;
  bool _isLocating = false;
  bool _isSearching = false;
  bool _isResolving = false;
  List<_PlaceSearchResult> _searchResults = const <_PlaceSearchResult>[];

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveToCurrentLocation();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is denied.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );

      final current = LatLng(position.latitude, position.longitude);
      if (!mounted) return;

      setState(() {
        _pickedLocation = current;
      });
      _mapController.move(current, 15.0);
      await _reverseGeocode(current);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to get current location: ${e.toString()}'.translate(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _searchPlaces() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = const <_PlaceSearchResult>[]);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '8',
      });

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Mezaan-App/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Search failed with ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw Exception('Unexpected search response');
      }

      final results = decoded
          .whereType<Map<String, dynamic>>()
          .map(_PlaceSearchResult.fromNominatim)
          .whereType<_PlaceSearchResult>()
          .toList(growable: false);

      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: ${e.toString()}'.translate())),
      );
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isResolving = true);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'format': 'jsonv2',
        'addressdetails': '1',
      });

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Mezaan-App/1.0',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final address = decoded['address'] as Map<String, dynamic>?;

      if (!mounted) return;
      setState(() {
        _resolvedDisplayName = decoded['display_name']?.toString();
        _resolvedCity =
            address?['city']?.toString() ??
            address?['town']?.toString() ??
            address?['village']?.toString();
        _resolvedGovernorate =
            address?['state']?.toString() ?? address?['region']?.toString();
      });
    } catch (_) {
      // Keep selection even if reverse geocoding fails.
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  void _selectSearchResult(_PlaceSearchResult result) {
    setState(() {
      _pickedLocation = result.location;
      _resolvedDisplayName = result.displayName;
      _resolvedCity = result.city;
      _resolvedGovernorate = result.governorate;
      _searchResults = const <_PlaceSearchResult>[];
    });

    _mapController.move(result.location, 15.5);
  }

  void _confirmSelection() {
    if (_pickedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please pick a location first.'.translate()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _OfficeLocationSelection(
        location: _pickedLocation!,
        displayName: _resolvedDisplayName,
        city: _resolvedCity,
        governorate: _resolvedGovernorate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Office Location'.translate()),
        actions: [
          TextButton(
            onPressed: _confirmSelection,
            child: Text(
              'Done'.translate(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickedLocation ?? _defaultCenter,
              initialZoom: 12.5,
              onTap: (tapPosition, point) {
                setState(() {
                  _pickedLocation = point;
                });
                _reverseGeocode(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mezaan.app',
              ),
              if (_pickedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pickedLocation!,
                      width: 48.w,
                      height: 48.h,
                      child: Icon(
                        Icons.location_on_rounded,
                        color: AppColors.legalGold,
                        size: 40.sp,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          Positioned(
            top: 12.h,
            left: 12.w,
            right: 12.w,
            child: Column(
              children: [
                Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12.r),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchPlaces(),
                    decoration: InputDecoration(
                      hintText: 'Search for place or address'.translate(),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.send_rounded),
                              onPressed: _searchPlaces,
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 8.h),
                    constraints: BoxConstraints(maxHeight: 220.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined),
                          title: Text(
                            result.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          Positioned(
            bottom: 16.h,
            right: 12.w,
            child: FloatingActionButton(
              heroTag: 'office-location-current-btn',
              backgroundColor: AppColors.navyBlue,
              onPressed: _isLocating ? null : _moveToCurrentLocation,
              child: _isLocating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),

          Positioned(
            left: 12.w,
            right: 12.w,
            bottom: 16.h,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFDCE6F5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _pickedLocation == null
                        ? 'Tap on the map to select your office location'
                              .translate()
                        : '${_pickedLocation!.latitude.toStringAsFixed(5)}, ${_pickedLocation!.longitude.toStringAsFixed(5)}',
                    style: TextStyle(
                      color: AppColors.navyBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.sp,
                    ),
                  ),
                  if (_resolvedDisplayName != null &&
                      _resolvedDisplayName!.trim().isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      _resolvedDisplayName!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                  SizedBox(height: 8.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _pickedLocation == null
                          ? null
                          : _confirmSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.legalGold,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      child: _isResolving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('Use This Location'.translate()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceSearchResult {
  final String displayName;
  final LatLng location;
  final String? city;
  final String? governorate;

  const _PlaceSearchResult({
    required this.displayName,
    required this.location,
    required this.city,
    required this.governorate,
  });

  static _PlaceSearchResult? fromNominatim(Map<String, dynamic> map) {
    final lat = double.tryParse(map['lat']?.toString() ?? '');
    final lon = double.tryParse(map['lon']?.toString() ?? '');
    final displayName = map['display_name']?.toString().trim();
    if (lat == null ||
        lon == null ||
        displayName == null ||
        displayName.isEmpty) {
      return null;
    }

    final address = map['address'] as Map<String, dynamic>?;
    final city =
        address?['city']?.toString() ??
        address?['town']?.toString() ??
        address?['village']?.toString();
    final governorate =
        address?['state']?.toString() ?? address?['region']?.toString();

    return _PlaceSearchResult(
      displayName: displayName,
      location: LatLng(lat, lon),
      city: city,
      governorate: governorate,
    );
  }
}
