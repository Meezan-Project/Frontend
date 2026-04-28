import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/screens/lawyer_profile_screen.dart';

class LawyersListScreen extends StatefulWidget {
  final String categoryName;

  const LawyersListScreen({super.key, this.categoryName = 'Criminal Lawyers'});

  @override
  State<LawyersListScreen> createState() => _LawyersListScreenState();
}

class _LawyersListScreenState extends State<LawyersListScreen> {
  int _selectedSortIndex = 0;
  String? _selectedGov;
  String? _selectedCity;
  String _searchQuery = '';
  bool _isLoading = true;
  List<LawyerMockModel> _allLawyers = <LawyerMockModel>[];
  List<LawyerMockModel> _displayedLawyers = <LawyerMockModel>[];
  List<String> _availableGovs = [];
  List<String> _availableCities = [];

  final List<String> _sortOptions = [
    'No sorting',
    'Highest Rated',
    'Lowest Price',
    'Highest Price',
    'Shortest Wait',
  ];

  @override
  void initState() {
    super.initState();
    _loadLawyers();
  }

  Future<void> _loadLawyers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('lawyers')
          .get();

      final normalizedCategory = _normalizeText(widget.categoryName);
      final loaded = snapshot.docs
          .map((doc) {
            final data = doc.data();
            if (!_matchesCategory(data, normalizedCategory)) {
              return null;
            }

            final firstName = _readString(data, [
              'first_name',
              'firstName',
              'firstname',
            ]);
            final secondName = _readString(data, [
              'second_name',
              'secondName',
              'lastname',
              'last_name',
            ]);
            final displayName = data['displayName']?.toString().trim() ?? '';
            final fullName = '$firstName $secondName'.trim();
            final name = fullName.isNotEmpty
                ? fullName
                : (displayName.isNotEmpty ? displayName : doc.id);
            final workStatus = _extractWorkStatus(data);
            final govsAndCities = _extractGovsAndCities(data, workStatus);

            return LawyerMockModel(
              name: name,
              specialization: _extractSpecializationLabel(data),
              rating: _readDouble(data, ['rating', 'averageRating']) ?? 4.5,
              reviewsCount:
                  _readInt(data, ['reviewsCount', 'reviewCount']) ?? 0,
              workStatus: workStatus,
              officeName: _extractOfficeName(data, workStatus),
              location: _buildLocationLabel(data, workStatus),
              governorates: govsAndCities['govs'] ?? [],
              cities: govsAndCities['cities'] ?? [],
              fee: _readDouble(data, ['consultation_fees', 'fee', 'consultationFee', 'price']) ?? 0.0,
              availability: _extractAvailability(data),
              imageUrl: _extractImageUrl(data),
            );
          })
          .whereType<LawyerMockModel>()
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _allLawyers = loaded;
        _populateFilterOptions();
        _isLoading = false;
      });
      _applyFiltersAndSort();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allLawyers = <LawyerMockModel>[];
        _displayedLawyers = <LawyerMockModel>[];
        _isLoading = false;
      });
    }
  }

  void _populateFilterOptions() {
    final Set<String> govs = {};
    final Set<String> cities = {};

    for (final lawyer in _allLawyers) {
      govs.addAll(lawyer.governorates);
      cities.addAll(lawyer.cities);
    }

    _availableGovs = govs.toList()..sort();
    _availableCities = cities.toList()..sort();
  }

  void _applyFiltersAndSort() {
    List<LawyerMockModel> result = List.from(_allLawyers);

    if (_searchQuery.isNotEmpty) {
      final query = _normalizeText(_searchQuery);
      result = result.where((lawyer) {
        return _normalizeText(lawyer.name).contains(query) ||
               _normalizeText(lawyer.specialization).contains(query);
      }).toList();
    }

    if (_selectedGov != null && _selectedGov!.isNotEmpty) {
      result = result.where((lawyer) => lawyer.governorates.contains(_selectedGov)).toList();
    }

    if (_selectedCity != null && _selectedCity!.isNotEmpty) {
      result = result.where((lawyer) => lawyer.cities.contains(_selectedCity)).toList();
    }

    result.sort((a, b) {
      switch (_selectedSortIndex) {
        case 0: // No sorting
          return 0;
        case 1: // Highest Rated
          final ratingCmp = b.rating.compareTo(a.rating);
          if (ratingCmp != 0) return ratingCmp;
          return b.reviewsCount.compareTo(a.reviewsCount);
        case 2: // Lowest Price
          return a.fee.compareTo(b.fee);
        case 3: // Highest Price
          return b.fee.compareTo(a.fee);
        case 4: // Shortest Wait
          final aNow = a.availability.toLowerCase().contains('now') ? 0 : 1;
          final bNow = b.availability.toLowerCase().contains('now') ? 0 : 1;
          return aNow.compareTo(bNow);
        default:
          return 0;
      }
    });

    setState(() {
      _displayedLawyers = result;
    });
  }

  static bool _matchesCategory(
    Map<String, dynamic> data,
    String normalizedCategory,
  ) {
    if (normalizedCategory.isEmpty) {
      return true;
    }

    final values = <String>[
      data['specialization']?.toString() ?? '',
      data['specializationText']?.toString() ?? '',
      data['category']?.toString() ?? '',
      data['specialty']?.toString() ?? '',
    ];

    final specialization = data['specialization'];
    if (specialization is List) {
      values.addAll(specialization.map((e) => e.toString()));
    }

    return values.any((value) {
      final normalizedValue = _normalizeText(value);
      return normalizedValue.isNotEmpty &&
          (normalizedValue == normalizedCategory ||
              normalizedValue.contains(normalizedCategory) ||
              normalizedCategory.contains(normalizedValue));
    });
  }

  static String _extractSpecializationLabel(Map<String, dynamic> data) {
    final specializationText =
        data['specializationText']?.toString().trim() ?? '';
    if (specializationText.isNotEmpty) {
      return specializationText;
    }

    final specialization = data['specialization'];
    if (specialization is List && specialization.isNotEmpty) {
      return specialization.map((e) => e.toString()).join(', ');
    }
    if (specialization is String && specialization.trim().isNotEmpty) {
      return specialization.trim();
    }

    return 'General Law';
  }

  static String _extractAvailability(Map<String, dynamic> data) {
    final availability = data['availability']?.toString().trim() ?? '';
    if (availability.isNotEmpty) {
      return availability;
    }

    final online = data['isOnline'] == true;
    return online ? 'Available now' : 'Available later';
  }

  static String _extractImageUrl(Map<String, dynamic> data) {
    final profilePhotoUrl = data['profilePhotoUrl']?.toString().trim() ?? '';
    if (profilePhotoUrl.isNotEmpty) {
      return profilePhotoUrl;
    }

    final profilePhoto = data['profile_photo']?.toString().trim() ?? '';
    if (profilePhoto.isNotEmpty) {
      return profilePhoto;
    }

    final photoUrl = data['photoUrl']?.toString().trim() ?? '';
    if (photoUrl.isNotEmpty) {
      return photoUrl;
    }

    final imageUrl = data['imageUrl']?.toString().trim() ?? '';
    if (imageUrl.isNotEmpty) {
      return imageUrl;
    }

    return 'https://i.pravatar.cc/150?u=${DateTime.now().microsecondsSinceEpoch}';
  }

  static String _extractWorkStatus(Map<String, dynamic> data) {
    final raw = _readString(data, ['work_status', 'workStatus']);
    switch (_normalizeText(raw)) {
      case 'owns an office':
      case 'owns office':
        return 'Owns an Office';
      case 'works in an office':
      case 'working in office':
        return 'Working in an Office';
      case 'freelancer':
        return 'Freelancer';
      default:
        return raw;
    }
  }

  static String _extractOfficeName(
    Map<String, dynamic> data,
    String workStatus,
  ) {
    if (workStatus == 'Working in an Office') {
      return _readString(data, ['employer_lawyer_name', 'employerLawyerName']);
    }

    if (workStatus == 'Owns an Office') {
      final officeDetails = data['office_details'];
      if (officeDetails is Map) {
        return _readString(officeDetails.cast<String, dynamic>(), [
          'office_name',
          'officeName',
          'name',
        ]);
      }
    }

    return '';
  }

  static String _buildLocationLabel(
    Map<String, dynamic> data,
    String workStatus,
  ) {
    if (workStatus == 'Freelancer') {
      final freelancerLocations = data['freelancer_locations'];
      if (freelancerLocations is List) {
        // Group by governorate
        final Map<String, List<String>> govToCities = {};
        for (final entry in freelancerLocations.whereType<Map>()) {
          final locationMap = entry.cast<String, dynamic>();
          final governorate = _readString(locationMap, [
            'governorate',
            'govern',
          ]);
          final city = _readString(locationMap, ['city']);
          if (governorate.isEmpty && city.isEmpty) continue;
          if (!govToCities.containsKey(governorate)) {
            govToCities[governorate] = [];
          }
          if (city.isNotEmpty && !govToCities[governorate]!.contains(city)) {
            govToCities[governorate]!.add(city);
          }
        }
        final lines = <String>[];
        for (final entry in govToCities.entries) {
          final gov = entry.key;
          final cities = entry.value;
          if (gov.isEmpty && cities.isEmpty) continue;
          if (gov.isNotEmpty && cities.isNotEmpty) {
            lines.add('$gov: ${cities.join(', ')}');
          } else if (gov.isNotEmpty) {
            lines.add(gov);
          } else if (cities.isNotEmpty) {
            lines.add(cities.join(', '));
          }
        }
        if (lines.isNotEmpty) {
          return lines.join('\n');
        }
      }
    }

    if (workStatus == 'Working in an Office' || workStatus == 'Owns an Office') {
      final officeDetails = data['office_details'];
      if (officeDetails is Map) {
        final officeMap = officeDetails.cast<String, dynamic>();
        final gov = _readString(officeMap, ['governorate', 'govern', 'state']);
        final city = _readString(officeMap, ['city']);
        final parts = <String>[gov, city]..removeWhere((part) => part.isEmpty);
        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    }

    final address = data['address'];
    final addressMap = address is Map ? address.cast<String, dynamic>() : null;
    final fallbackParts = <String>[];
    if (addressMap != null) {
      final governorate = _readString(addressMap, [
        'govern',
        'governorate',
        'state',
      ]);
      final city = _readString(addressMap, ['city']);
      if (governorate.isNotEmpty) fallbackParts.add(governorate);
      if (city.isNotEmpty) fallbackParts.add(city);
    }

    return fallbackParts.isNotEmpty
        ? fallbackParts.join(', ')
        : 'Location not available';
  }

  static Map<String, List<String>> _extractGovsAndCities(Map<String, dynamic> data, String workStatus) {
    final Set<String> govs = {};
    final Set<String> cities = {};

    if (workStatus == 'Freelancer') {
      final freelancerLocations = data['freelancer_locations'];
      if (freelancerLocations is List) {
        for (final entry in freelancerLocations.whereType<Map>()) {
          final locationMap = entry.cast<String, dynamic>();
          final gov = _readString(locationMap, ['governorate', 'govern']);
          final city = _readString(locationMap, ['city']);
          if (gov.isNotEmpty) govs.add(gov);
          if (city.isNotEmpty) cities.add(city);
        }
      }
    }

    if (workStatus == 'Working in an Office' || workStatus == 'Owns an Office') {
      final officeDetails = data['office_details'];
      if (officeDetails is Map) {
        final officeMap = officeDetails.cast<String, dynamic>();
        final gov = _readString(officeMap, ['governorate', 'govern', 'state']);
        final city = _readString(officeMap, ['city']);
        if (gov.isNotEmpty) govs.add(gov);
        if (city.isNotEmpty) cities.add(city);
      }
    }

    final address = data['address'];
    final addressMap = address is Map ? address.cast<String, dynamic>() : null;
    if (addressMap != null) {
      final gov = _readString(addressMap, ['govern', 'governorate', 'state']);
      final city = _readString(addressMap, ['city']);
      if (gov.isNotEmpty) govs.add(gov);
      if (city.isNotEmpty) cities.add(city);
    }

    return {
      'govs': govs.toList(),
      'cities': cities.toList(),
    };
  }

  static String _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static int? _readInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString().trim() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static double? _readDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is double) return value;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString().trim() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String _normalizeText(String text) {
    return text.trim().toLowerCase();
  }

  static String _displayCategoryTitle(String categoryName) {
    switch (_normalizeText(categoryName)) {
      case 'محامين جنائيين':
      case 'criminal lawyers':
        return 'Criminal Lawyers';
      case 'محامين أسرة':
      case 'family lawyers':
        return 'Family Lawyers';
      case 'محامين عقارات':
      case 'real estate lawyers':
        return 'Real Estate Lawyers';
      case 'محامين شركات':
      case 'commercial lawyers':
        return 'Commercial Lawyers';
      case 'محامين عمل':
      case 'labor lawyers':
        return 'Labor Lawyers';
      default:
        return categoryName;
    }
  }

  void _showSortBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.all(20.r),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sort By',
                    style: GoogleFonts.cairo(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  ...List.generate(_sortOptions.length, (index) {
                    final isSelected = _selectedSortIndex == index;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: AppColors.navyBlue,
                      ),
                      title: Text(
                        _sortOptions[index],
                        style: GoogleFonts.cairo(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        setModalState(() => _selectedSortIndex = index);
                        setState(() {
                          _selectedSortIndex = index;
                          _applyFiltersAndSort();
                        });
                        Navigator.of(sheetContext).pop();
                      },
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.all(20.r),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter',
                    style: GoogleFonts.cairo(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  DropdownButtonFormField<String?>(
                    key: ValueKey(_selectedGov),
                    initialValue: _selectedGov,
                    decoration: InputDecoration(
                      labelText: 'Governorate',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All'),
                      ),
                      ..._availableGovs.map(
                        (e) => DropdownMenuItem<String?>(
                          value: e,
                          child: Text(e),
                        ),
                      )
                    ],
                    onChanged: (val) {
                      setModalState(() => _selectedGov = val);
                    },
                  ),
                  SizedBox(height: 16.h),
                  DropdownButtonFormField<String?>(
                    key: ValueKey(_selectedCity),
                    initialValue: _selectedCity,
                    decoration: InputDecoration(
                      labelText: 'District',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All'),
                      ),
                      ..._availableCities.map(
                        (e) => DropdownMenuItem<String?>(
                          value: e,
                          child: Text(e),
                        ),
                      )
                    ],
                    onChanged: (val) {
                      setModalState(() => _selectedCity = val);
                    },
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50.h,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.navyBlue),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            onPressed: () {
                              setModalState(() {
                                _selectedGov = null;
                                _selectedCity = null;
                              });
                              _applyFiltersAndSort();
                              Navigator.of(sheetContext).pop();
                            },
                            child: Text(
                              'Clear',
                              style: GoogleFonts.cairo(
                                color: AppColors.navyBlue,
                                fontWeight: FontWeight.w800,
                                fontSize: 16.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 50.h,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navyBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            onPressed: () {
                              _applyFiltersAndSort();
                              Navigator.of(sheetContext).pop();
                            },
                            child: Text(
                              'Apply Filter',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton(String title, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18.sp, color: AppColors.navyBlue),
      label: Text(
        title,
        style: GoogleFonts.cairo(
          color: AppColors.navyBlue,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.navyBlue.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        padding: EdgeInsets.symmetric(vertical: 8.h),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: AppColors.navyBlue),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayCategoryTitle = _displayCategoryTitle(widget.categoryName);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.navyBlue,
        title: Text(
          displayCategoryTitle,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w800,
            fontSize: 20.sp,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: TextField(
              onChanged: (value) {
                _searchQuery = value;
                _applyFiltersAndSort();
              },
              decoration: InputDecoration(
                hintText: 'Search by name, specialization...',
                hintStyle: GoogleFonts.cairo(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: AppColors.navyBlue),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 12.h,
                  horizontal: 16.w,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: AppColors.navyBlue),
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Sort',
                    Icons.sort,
                    _showSortBottomSheet,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _buildActionButton(
                    'Filter',
                    Icons.filter_alt_outlined,
                    _showFilterBottomSheet,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _displayedLawyers.isEmpty
                ? Center(
                    child: Text(
                      'No lawyers found for this category',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    itemCount: _displayedLawyers.length,
                    itemBuilder: (context, index) {
                      final lawyer = _displayedLawyers[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: 16.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              height: 4.h,
                              decoration: BoxDecoration(
                                color: AppColors.navyBlue,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16.r),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(16.r),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              lawyer.name,
                                              style: GoogleFonts.cairo(
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.navyBlue,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              lawyer.workStatus,
                                              style: GoogleFonts.cairo(
                                                fontSize: 13.sp,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (lawyer
                                                .officeName
                                                .isNotEmpty) ...[
                                              SizedBox(height: 2.h),
                                              Text(
                                                lawyer.officeName,
                                                style: GoogleFonts.cairo(
                                                  fontSize: 12.sp,
                                                  color: Colors.grey.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            SizedBox(height: 6.h),
                                            Text(
                                              lawyer.specialization,
                                              style: GoogleFonts.cairo(
                                                fontSize: 13.sp,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(height: 6.h),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.star_rounded,
                                                  color: Colors.amber,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 4.w),
                                                Text(
                                                  '${lawyer.rating.toStringAsFixed(1)} (${lawyer.reviewsCount} reviews)',
                                                  style: GoogleFonts.cairo(
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey.shade800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      CircleAvatar(
                                        radius: 30.r,
                                        backgroundColor: Colors.grey.shade200,
                                        backgroundImage: NetworkImage(
                                          lawyer.imageUrl,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16.h),
                                  _buildInfoRow(
                                    Icons.location_on_outlined,
                                    lawyer.location,
                                  ),
                                  _buildInfoRow(
                                    Icons.account_balance_wallet_outlined,
                                    lawyer.fee > 0
                                        ? 'Fees start from: ${lawyer.fee % 1 == 0 ? lawyer.fee.toInt() : lawyer.fee} EGP'
                                        : 'Fees: Not available',
                                  ),
                                  SizedBox(height: 16.h),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44.h,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => LawyerProfileScreen(lawyer: lawyer),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.legalGold,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10.r),
                                        ),
                                      ),
                                      child: Text(
                                        'Book Now',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15.sp,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class LawyerMockModel {
  final String name;
  final String specialization;
  final String workStatus;
  final String officeName;
  final double rating;
  final int reviewsCount;
  final String location;
  final List<String> governorates;
  final List<String> cities;
  final double fee;
  final String availability;
  final String imageUrl;

  LawyerMockModel({
    required this.name,
    required this.specialization,
    required this.workStatus,
    required this.officeName,
    required this.rating,
    required this.reviewsCount,
    required this.location,
    required this.governorates,
    required this.cities,
    required this.fee,
    required this.availability,
    required this.imageUrl,
  });
}
