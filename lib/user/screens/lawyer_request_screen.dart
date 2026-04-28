import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mezaan/shared/localization/localization_controller.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class LawyerRequestScreen extends StatefulWidget {
  const LawyerRequestScreen({super.key});

  @override
  State<LawyerRequestScreen> createState() => _LawyerRequestScreenState();
}

class _LawyerRequestScreenState extends State<LawyerRequestScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final MapController _mapController = MapController();
  bool _isLocationLoading = true;
  String _locationName = 'Finding your location...';
  String _locationCoordinates = '';
  bool _mapReady = false;
  double? _latitude;
  double? _longitude;
  LatLng _userLocation = const LatLng(30.0444, 31.2357); // Default Cairo location
  int _selectedServiceIndex = 0;
  int _offerAmount = 150;

  final List<_LegalServiceCard> _serviceCards = const [
    _LegalServiceCard(
      title: 'Urgent SOS',
      subtitle: 'Immediate support',
      icon: Icons.warning_amber_rounded,
    ),
    _LegalServiceCard(
      title: 'Legal Consultation',
      subtitle: 'Speak to a lawyer',
      icon: Icons.gavel,
    ),
    _LegalServiceCard(
      title: 'Document Review',
      subtitle: 'Contracts & papers',
      icon: Icons.balance,
    ),
  ];

  void _updateOffer(int delta) {
    setState(() {
      _offerAmount = (_offerAmount + delta).clamp(50, 1000);
    });
  }

  void _showLocationOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isArabic ? 'اختر الموقع' : 'Select Location',
              style: GoogleFonts.cairo(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0D2345),
              ),
            ),
            SizedBox(height: 20.h),
            ListTile(
              leading: const Icon(Icons.my_location, color: AppColors.legalGold),
              title: Text(
                _isArabic ? 'موقعي الحالي' : 'Current location',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.pop(context);
                _loadCurrentLocation();
              },
            ),
            Divider(color: Colors.grey.withValues(alpha: 0.2)),
            ListTile(
              leading: const Icon(Icons.map_outlined, color: AppColors.legalGold),
              title: Text(
                _isArabic ? 'موقع آخر' : 'Another location',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.pop(context);
                _showLocationSearchSheet();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationSearchSheet() {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: searchCtrl,
                style: GoogleFonts.cairo(),
                decoration: InputDecoration(
                  hintText: _isArabic ? 'ادخل العنوان...' : 'Enter address...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.legalGold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                onSubmitted: (value) async {
                  if (value.isEmpty) return;
                  Navigator.pop(context);
                  _searchAndMoveToLocation(value);
                },
              ),
              SizedBox(height: 12.h),
              ListTile(
                leading: const Icon(Icons.pin_drop, color: AppColors.legalGold),
                title: Text(
                  _isArabic ? 'تحديد على الخريطة' : 'Pin on map',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _isArabic ? 'اضغط على الخريطة لتحديد الموقع' : 'Tap on the map to select location',
                        style: GoogleFonts.cairo(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _searchAndMoveToLocation(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final newPoint = LatLng(loc.latitude, loc.longitude);
        _updateLocationDetails(newPoint);
        _mapController.move(newPoint, 15.0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isArabic ? 'لم يتم العثور على الموقع' : 'Location not found')),
        );
      }
    }
  }

  void _findLawyer() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Searching for a lawyer...')),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationName = 'Enable location services';
          _isLocationLoading = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _locationName = 'Location permission denied';
          _isLocationLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;
      _userLocation = LatLng(position.latitude, position.longitude);

      // Get location name using reverse geocoding
      _updateLocationDetails(_userLocation);

      if (_mapReady) {
        _mapController.move(_userLocation, 15.0);
      }
    } catch (e) {
      setState(() {
        _locationName = 'Unable to get location';
        _isLocationLoading = false;
      });
    }
  }

  Future<void> _updateLocationDetails(LatLng point) async {
    setState(() {
      _latitude = point.latitude;
      _longitude = point.longitude;
      _userLocation = point;
      _isLocationLoading = true;
    });

    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final locationName = '${place.name}, ${place.locality}, ${place.administrativeArea}';
        setState(() {
          _locationName = locationName.isNotEmpty ? locationName : 'Selected location';
          _locationCoordinates = '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
          _isLocationLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _locationName = '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
        _isLocationLoading = false;
      });
    }
  }

  bool get _isArabic =>
      LocalizationController.instance.currentLanguage.value == 'ar';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Stack(
        children: [
          _buildMapBackground(),
          Positioned(
            left: 12.w,
            bottom: 18.h,
            child: IgnorePointer(
              child: Container(
                padding: EdgeInsets.symmetric( // This container is for the MapTiler attribution text
                  horizontal: 10.w,
                  vertical: 6.h,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: const Color(0xFFD2DCE8),
                    width: 1,
                  ),
                ),
                child: Text(
                  'MapTiler Streets v2',
                  style: GoogleFonts.cairo(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF23436A),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 72.h, // تم ترحيلها للأسفل قليلاً لتجنب التداخل مع زر الرجوع
            left: 18.w,
            right: 18.w,
            child: _buildLocationCard(),
          ),
          // زر الرجوع العائم داخل دائرة
          Positioned(
            top: 16.h,
            left: _isArabic ? null : 18.w,
            right: _isArabic ? 18.w : null,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    color: AppColors.navyBlue,
                    size: 22.sp,
                  ),
                ),
              ),
            ),
          ),
          _buildBottomSheet(context),
        ],
      ),
    );
  }

  Widget _buildMapBackground() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _userLocation,
        initialZoom: 14.5,
        onMapReady: () {
          _mapReady = true;
          if (!_isLocationLoading) _mapController.move(_userLocation, 15.0);
        },
        onTap: (tapPosition, point) {
          _updateLocationDetails(point);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=HNGIJUr6VGmHEr8rxntj',
          userAgentPackageName: 'com.example.mezaan',
          tileSize: 256,
        ),
        if (_latitude != null && _longitude != null)
          MarkerLayer(
            markers: [
              Marker(
                width: 80.w,
                height: 80.h,
                point: _userLocation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 50.w,
                      height: 50.h,
                      decoration: BoxDecoration(
                        color: AppColors.legalGold,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.legalGold.withOpacity(0.4),
                            blurRadius: 12,
                            offset: Offset(0, 4.h),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.location_on,
                          color: AppColors.navyBlue,
                          size: 28.sp,
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppColors.legalGold,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        'You',
                        style: GoogleFonts.cairo(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navyBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              '© MapTiler',
              onTap: () => launchUrl(
                Uri.parse('https://www.maptiler.com/copyright/'),
              ),
            ),
            TextSourceAttribution(
              '© OpenStreetMap contributors',
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    return GestureDetector(
      onTap: _showLocationOptions,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D2345).withOpacity(0.12),
              blurRadius: 16,
              offset: Offset(0, 6.h),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Container(
              width: 52.w,
              height: 52.h,
              decoration: BoxDecoration(
                color: const Color(0xFF0D2345).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: const Color(0xFF0D2345).withOpacity(0.1),
                ),
              ),
              child: Icon(
                Icons.location_on_outlined,
                color: AppColors.legalGold,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isArabic ? 'موقعك الحالي' : 'Your location',
                    style: GoogleFonts.cairo(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D2345).withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    _isLocationLoading 
                        ? (_isArabic ? 'جاري تحديد الموقع...' : 'Finding location...') 
                        : _locationName,
                    style: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D2345),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_isLocationLoading)
              SizedBox(
                width: 20.w,
                height: 20.h,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.legalGold),
                ),
              )
            else
              Icon(
                Icons.verified_rounded,
                color: const Color(0xFF0B5E55),
                size: 20.sp,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.35,
      maxChildSize: 0.75,
      builder: (_, controller) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
            boxShadow: [
              BoxShadow(
                color: AppColors.navyBlue.withOpacity(0.15),
                blurRadius: 32,
                offset: Offset(0, -12.h),
              ),
            ],
          ),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 60.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: AppColors.navyBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Select legal service',
                style: GoogleFonts.cairo(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navyBlue,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Choose the service that best matches your legal issue.',
                style: GoogleFonts.cairo(
                  fontSize: 13.sp,
                  color: AppColors.textDark.withOpacity(0.7),
                ),
              ),
              SizedBox(height: 18.h),
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.legalGold.withOpacity(0.3), width: 1.5),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: GoogleFonts.cairo(
                    fontSize: 14.sp,
                    color: AppColors.navyBlue,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Describe your legal issue',
                    hintStyle: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      color: AppColors.textDark.withOpacity(0.4),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Service types',
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyBlue,
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                height: 140.h,
                child: ListView.separated(
                  itemCount: _serviceCards.length,
                  scrollDirection: Axis.horizontal,
                  separatorBuilder: (_, _) => SizedBox(width: 12.w),
                  itemBuilder: (context, index) {
                    final card = _serviceCards[index];
                    final selected = index == _selectedServiceIndex;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedServiceIndex = index;
                      }),
                      child: Container(
                        width: 200.w,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.navyBlue : Colors.white,
                          border: Border.all(
                            color: selected ? AppColors.legalGold : AppColors.legalGold.withOpacity(0.3),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        padding: EdgeInsets.all(14.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 42.w,
                              height: 42.h,
                              decoration: BoxDecoration(
                                color: selected ? AppColors.legalGold : AppColors.legalGold.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                card.icon,
                                color: selected ? AppColors.navyBlue : AppColors.legalGold,
                                size: 22.sp,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              card.title,
                              style: GoogleFonts.cairo(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : AppColors.navyBlue,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              card.subtitle,
                              style: GoogleFonts.cairo(
                                fontSize: 11.sp,
                                color: selected ? Colors.white70 : AppColors.textDark.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 22.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your offer',
                    style: GoogleFonts.cairo(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundGrey,
                      border: Border.all(color: AppColors.legalGold.withOpacity(0.3), width: 1),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    child: Row(
                      children: [
                        _buildCounterButton(Icons.remove, () => _updateOffer(-10)),
                        SizedBox(width: 14.w),
                        Text(
                          '\$$_offerAmount',
                          style: GoogleFonts.cairo(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navyBlue,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        _buildCounterButton(Icons.add, () => _updateOffer(10)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 22.h),
              ElevatedButton(
                onPressed: _findLawyer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Find a Lawyer',
                  style: GoogleFonts.cairo(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.navyBlue,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    side: BorderSide(color: AppColors.legalGold, width: 1.5),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.cairo(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCounterButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32.w,
        height: 32.h,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.legalGold, width: 1.5),
        ),
        child: Icon(icon, color: AppColors.navyBlue, size: 16.sp),
      ),
    );
  }
}

class _LegalServiceCard {
  final String title;
  final String subtitle;
  final IconData icon;

  const _LegalServiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
