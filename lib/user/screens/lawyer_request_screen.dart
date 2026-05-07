import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math'; // For atan2
import 'package:mezaan/shared/localization/localization_controller.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/screens/sos_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class LawyerRequestScreen extends StatefulWidget {
  const LawyerRequestScreen({super.key});

  @override
  State<LawyerRequestScreen> createState() => _LawyerRequestScreenState();
}

class _LawyerRequestScreenState extends State<LawyerRequestScreen>
    with SingleTickerProviderStateMixin {
  // Helper to format numbers with commas (e.g., 10,000)
  String formatFee(num fee) {
    return fee.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  // 1. Core State Variables
  String? selectedService;
  int price = 0;
  bool isSearching = false;
  bool isLawyerAccepted = false; // New state variable
  LawyerOffer? _acceptedOffer; // New state variable to store the accepted offer
  final TextEditingController descriptionController = TextEditingController();
  int _userRating = 0;
  final TextEditingController feedbackController = TextEditingController();

  // Animation Variables for Tracking Notification
  late AnimationController _notificationController;
  late Animation<Offset> _notificationOffsetAnimation;

  // 2. Map & Location Variables
  final MapController _mapController = MapController();
  bool _isLocationLoading = true;
  String _locationName = 'Finding your location...';
  bool _mapReady = false;
  // For moving car animation
  LatLng? _currentCarLocation;
  double _carRotation = 0.0; // in radians
  final List<LatLng> _routePoints = [];
  Timer? _carMovementTimer; // Declare the timer
  double? _latitude;
  double? _longitude;
  LatLng _userLocation = LatLng(30.0444, 31.2357);

  // 3. Offers Variables
  final List<LawyerOffer> _virtualLawyers = const [
    LawyerOffer(
      name: 'Ahmed Ali',
      title: 'Senior Criminal Lawyer',
      rating: 4.93,
      price: 300,
      travelTime: 5,
      serviceType: 'Comfort',
      cases: 120,
      phoneNumber: '+201001234567',
      location: LatLng(30.0460, 31.2370),
      imageUrl:
          'https://cdn-icons-png.flaticon.com/512/3135/3135715.png', // Ahmed Ali
    ),
    LawyerOffer(
      name: 'Fatima Hassan',
      title: 'Family Law Expert',
      rating: 4.88,
      price: 320,
      travelTime: 7, // Mock travel time
      serviceType: 'Premium',
      cases: 95,
      phoneNumber: '+201001234568',
      location: LatLng(30.0420, 31.2340),
      imageUrl: 'https://i.pravatar.cc/150?u=FatimaHassan', // Placeholder
    ),
    LawyerOffer(
      name: 'Mohamed Karim',
      title: 'Corporate Legal Consultant',
      rating: 5.00,
      price: 360,
      travelTime: 4, // Mock travel time
      serviceType: 'Express',
      cases: 150,
      phoneNumber: '+201001234569',
      location: LatLng(30.0480, 31.2390),
      imageUrl: 'https://i.pravatar.cc/150?u=MohamedKarim', // Placeholder
    ),
    LawyerOffer(
      name: 'Sara Omar',
      title: 'Human Rights Specialist',
      rating: 4.75,
      price: 310,
      travelTime: 6, // Mock travel time
      serviceType: 'Standard',
      cases: 80,
      phoneNumber: '+201001234570',
      location: LatLng(30.0410, 31.2320),
      imageUrl:
          'https://cdn-icons-png.flaticon.com/512/6997/6997662.png', // Sara Omar
    ),
    LawyerOffer(
      name: 'Omar Saleh',
      title: 'Civil Litigation Expert',
      rating: 4.65,
      price: 340,
      travelTime: 8,
      serviceType: 'Premium',
      cases: 110,
      phoneNumber: '+201001234571',
      imageUrl: 'https://i.pravatar.cc/150?u=OmarSaleh', // Placeholder
      location: LatLng(30.0475, 31.2385),
    ),
  ];
  List<LawyerOffer> offers = [];
  Timer? _offerTimer;
  int _offerIndex = 0;

  // Helper getter for language
  bool get _isArabic =>
      LocalizationController.instance.currentLanguage.value == 'ar';

  // Helper getter for form validation
  bool get _isFormValid =>
      selectedService != null && descriptionController.text.trim().isNotEmpty;

  // 3. Logic Functions
  void selectService(String type, int minPrice) {
    setState(() {
      selectedService = type;
      price = minPrice;
    });
  }

  int getMinPrice() {
    if (selectedService == 'urgent') return 300;
    if (selectedService == 'legal') return 450;
    return 500; // Document Review
  }

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

  void _showLocationOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.all(24.r),
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
              leading: const Icon(
                Icons.my_location,
                color: AppColors.legalGold,
              ),
              title: Text(
                _isArabic ? 'موقعي الحالي' : 'Current Location',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.pop(context);
                _loadCurrentLocation();
              },
            ),
            Divider(color: Colors.grey.withOpacity(0.2)),
            ListTile(
              leading: const Icon(
                Icons.map_outlined,
                color: AppColors.legalGold,
              ),
              title: Text(
                _isArabic ? 'موقع آخر' : 'Another Location',
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
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: searchCtrl,
                style: GoogleFonts.cairo(),
                decoration: InputDecoration(
                  hintText: _isArabic ? 'ادخل العنوان...' : 'Enter address...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.legalGold,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
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
                        _isArabic
                            ? 'اضغط على الخريطة لتحديد الموقع'
                            : 'Tap on the map to select location',
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
          SnackBar(
            content: Text(
              _isArabic ? 'لم يتم العثور على الموقع' : 'Location not found',
            ),
          ),
        );
      }
    }
  }

  void _findLawyer() {
    setState(() {
      isSearching = true;
      offers = [];
      _offerIndex = 0;
    });
    _generateMockOffers();
  }

  void _generateMockOffers() {
    _offerTimer?.cancel();
    _offerTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_offerIndex < _virtualLawyers.length) {
        setState(() {
          offers.add(_virtualLawyers[_offerIndex]);
          _offerIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _cancelSearch() {
    _offerTimer?.cancel();
    setState(() {
      isSearching = false;
      offers = [];
      _offerIndex = 0;
    });
  }

  void _acceptOffer(LawyerOffer offer) {
    setState(() {
      _acceptedOffer = offer;
      isLawyerAccepted = true;
      isSearching = false; // Exit searching mode
      _offerTimer?.cancel(); // Stop generating offers
    });

    // Start notification animation with 2s delay after offer acceptance
    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted &&
          isLawyerAccepted &&
          _notificationController.status != AnimationStatus.forward) {
        await _notificationController.forward();
      }
    });

    // Start car movement animation
    if (offer.location != null && _mapReady) {
      _currentCarLocation = offer.location!;
      _generateRoutePoints(offer.location!, _userLocation);
      _startCarAnimation();
    }
  }

  // Generates interpolated points for the car's route
  void _generateRoutePoints(LatLng start, LatLng end) {
    _routePoints.clear();
    const int numberOfSteps =
        20; // Adjusted for smoother animation with 500ms interval
    for (int i = 0; i <= numberOfSteps; i++) {
      final double t = i / numberOfSteps;
      final double lat = start.latitude + t * (end.latitude - start.latitude);
      final double lng =
          start.longitude + t * (end.longitude - start.longitude);
      _routePoints.add(LatLng(lat, lng));
    }
  }

  // Starts the car movement animation along the route points
  void _startCarAnimation() {
    _carMovementTimer?.cancel(); // Cancel any existing timer
    int currentPointIndex = 0;
    _carMovementTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (currentPointIndex < _routePoints.length - 1) {
        final LatLng prevPoint = _routePoints[currentPointIndex];
        final LatLng nextPoint = _routePoints[currentPointIndex + 1];

        // Calculate rotation angle based on direction of movement
        final double dx = nextPoint.longitude - prevPoint.longitude;
        final double dy = nextPoint.latitude - prevPoint.latitude;
        _carRotation = atan2(dy, dx); // Angle in radians

        setState(() {
          _currentCarLocation = nextPoint;
          _mapController.move(_currentCarLocation!, 15.0); // Keep car centered
        });
        currentPointIndex++;
      } else {
        timer.cancel(); // Animation complete
        // Optionally, snap to final user location and reset rotation
        setState(() {
          _currentCarLocation = _userLocation;
          _carRotation = 0.0; // Reset rotation or keep final direction
        });
      }
    });
  }

  void _declineOffer(int index) {
    setState(() {
      offers.removeAt(index);
    });
  }

  // Function to show the cancel confirmation dialog
  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          title: Text(
            _isArabic ? 'إلغاء طلب المحامي؟' : 'Cancel your lawyer?',
            style: GoogleFonts.cairo(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.navyBlue,
            ),
          ),
          content: Text(
            _isArabic
                ? 'هل أنت متأكد أنك تريد الإلغاء؟ قد يؤثر هذا على تقييم خدمتك.'
                : 'Are you sure you want to cancel? This might affect your service rating.',
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              color: AppColors.textDark.withOpacity(0.7),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Dismiss dialog
              child: Text(
                _isArabic ? 'لا، احتفظ به' : 'No, keep it',
                style: GoogleFonts.cairo(
                  color: AppColors.navyBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss dialog
                setState(() {
                  isLawyerAccepted = false;
                  _acceptedOffer = null;
                  _notificationController.reset();
                  isSearching = false;
                  _currentCarLocation = null;
                  _carMovementTimer?.cancel();
                });
              },
              child: Text(
                _isArabic ? 'نعم، إلغاء' : 'Yes, Cancel',
                style: GoogleFonts.cairo(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showChatBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            children: [
              // 1. Header
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 10.h, 10.w, 10.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isArabic
                          ? 'المحادثة مع ${_acceptedOffer?.name ?? "المحامي"}'
                          : 'Chat with ${_acceptedOffer?.name ?? "Lawyer"}',
                      style: GoogleFonts.cairo(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // 2. Chat Body
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 15.h,
                  ),
                  children: [
                    _buildChatBubble(
                      message: _isArabic
                          ? 'مرحباً! لقد قبلت طلبك وأنا في الطريق إليك.'
                          : 'Hello! I have accepted your request and I\'m moving toward your location now.',
                      isUser: false,
                    ),
                    _buildChatBubble(
                      message: _isArabic
                          ? 'شكراً لك، أنا في انتظارك عند المدخل الرئيسي.'
                          : 'Thank you. I\'m waiting at the main entrance.',
                      isUser: true,
                    ),
                    _buildChatBubble(
                      message: _isArabic
                          ? 'تمام، سأصل خلال 5 دقائق تقريباً.'
                          : 'Perfect. I should be there in about 5 minutes.',
                      isUser: false,
                    ),
                    _buildChatBubble(
                      message: _isArabic
                          ? 'عظيم، أراك قريباً.'
                          : 'Sounds good, see you soon.',
                      isUser: true,
                    ),
                  ],
                ),
              ),

              // 3. Message Input (Footer)
              Padding(
                padding: EdgeInsets.all(20.w),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: GoogleFonts.cairo(fontSize: 14.sp),
                        decoration: InputDecoration(
                          hintText: _isArabic
                              ? 'اكتب رسالة...'
                              : 'Type a message...',
                          hintStyle: GoogleFonts.cairo(color: Colors.grey),
                          fillColor: Colors.grey[200],
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.r),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 10.h,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    GestureDetector(
                      onTap: () {
                        // Send functionality placeholder
                      },
                      child: Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: const BoxDecoration(
                          color: AppColors.navyBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble({required String message, required bool isUser}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.navyBlue : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
            bottomLeft: isUser ? Radius.circular(16.r) : Radius.zero,
            bottomRight: isUser ? Radius.zero : Radius.circular(16.r),
          ),
        ),
        child: Text(
          message,
          style: GoogleFonts.cairo(
            fontSize: 14.sp,
            color: isUser ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  void _finishService() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
              ),
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  // 1. Skip Button (Subtle and accessible at the top)
                  Align(
                    alignment: _isArabic
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          isLawyerAccepted = false;
                          _acceptedOffer = null;
                          _notificationController.reset();
                          isSearching = false;
                          _currentCarLocation = null;
                          _carMovementTimer?.cancel();
                          _userRating = 0;
                          feedbackController.clear();
                        });
                      },
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: Text(
                        _isArabic ? 'تخطي' : 'Skip',
                        style: GoogleFonts.cairo(
                          color: Colors.grey[600],
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20.h),
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF29CC68),
                    size: 70,
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    _isArabic ? 'شكراً لك!' : 'Thank you!',
                    style: GoogleFonts.cairo(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    _isArabic
                        ? 'اكتملت المهمة مع ${_acceptedOffer?.name ?? "أحمد علي"}.'
                        : 'Task with ${_acceptedOffer?.name ?? "Ahmed Ali"} completed.',
                    style: GoogleFonts.cairo(
                      fontSize: 16.sp,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 30.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setModalState(() => _userRating = index + 1);
                        },
                        child: Icon(
                          index < _userRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 40.sp,
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 30.h),
                  TextField(
                    controller: feedbackController,
                    maxLines: 4,
                    style: GoogleFonts.cairo(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: _isArabic
                          ? 'اكتب ملاحظاتك...'
                          : 'Write your feedback...',
                      hintStyle: GoogleFonts.cairo(color: Colors.grey),
                      fillColor: Colors.grey[100],
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        isLawyerAccepted = false;
                        _acceptedOffer = null;
                        _notificationController.reset();
                        isSearching = false;
                        _currentCarLocation = null;
                        _carMovementTimer?.cancel();
                        _userRating = 0;
                        feedbackController.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyBlue,
                      minimumSize: Size(double.infinity, 56.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    child: Text(
                      _isArabic ? 'إرسال والعودة للرئيسية' : 'Submit & Go Home',
                      style: GoogleFonts.cairo(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // 2. "Not Now" button (Subtle secondary choice at the bottom)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        isLawyerAccepted = false;
                        _acceptedOffer = null;
                        _notificationController.reset();
                        isSearching = false;
                        _currentCarLocation = null;
                        _carMovementTimer?.cancel();
                        _userRating = 0;
                        feedbackController.clear();
                      });
                    },
                    child: Text(
                      _isArabic ? 'تخطي / ليس الآن' : 'Not Now / Skip',
                      style: GoogleFonts.cairo(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _offerTimer?.cancel();
    _notificationController.dispose();
    _carMovementTimer?.cancel(); // Cancel car movement timer
    descriptionController.dispose();
    feedbackController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();

    // Initialize the slide-down animation logic for the notification banner
    _notificationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _notificationOffsetAnimation =
        Tween<Offset>(
          begin: const Offset(0, -1.0), // Start high above the screen
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _notificationController,
            curve: Curves.easeOut,
          ),
        );

    // No need to trigger animation here, it's triggered in _acceptOffer
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

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locationName = 'Location permission denied';
          _isLocationLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
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
        final locationName =
            '${place.name}, ${place.locality}, ${place.administrativeArea}';
        setState(() {
          _locationName = locationName.isNotEmpty
              ? locationName
              : 'Selected location';
          _isLocationLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _locationName =
            '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
        _isLocationLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor =
        theme.textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : AppColors.navyBlue);
    final cardColor = theme.cardColor;

    // 1. SIMPLE IF/ELSE SWITCH FOR CORE UI MODES
    if (isLawyerAccepted) {
      return Scaffold(
        body: Stack(
          children: [
            _buildMapBackground(isDark),
            // Soft overlay to ensure white UI elements pop against the map
            Container(color: Colors.black.withOpacity(0.2)),
            _buildTrackingModeUI(),
          ],
        ),
      );
    }

    // 2. DEFAULT REQUEST / OFFERS MODE
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. Full-screen map background
          _buildMapBackground(isDark),
          // Dark Overlay (Searching Mode)
          if (isSearching) Container(color: Colors.black54),

          // Header: Normal Mode Location Card vs Searching Mode Cancel Button
          Positioned(
            top: 16.h,
            left: 18.w,
            right: 18.w,
            child: SafeArea(
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42.w,
                      height: 42.w,
                      decoration: BoxDecoration(
                        color: cardColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow( // This was causing an error
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: theme.iconTheme.color ?? AppColors.navyBlue,
                        size: 22.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: isSearching
                        ? Center(
                            child: GestureDetector(
                              onTap: _cancelSearch,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 26.w,
                                  vertical: 12.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.navyBlue,
                                  borderRadius: BorderRadius.circular(30.r),
                                  border: Border.all(
                                    color: AppColors.legalGold,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow( // This was causing an error
                                      color: AppColors.navyBlue.withOpacity(
                                        0.25,
                                      ),
                                      blurRadius: 18,
                                      offset: Offset(0, 6.h),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 20.sp,
                                    ),
                                    SizedBox(width: 10.w),
                                    Text(
                                      'Cancel request',
                                      style: GoogleFonts.cairo(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : _buildLocationCard(),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Section: Floating Offers vs White Bottom Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: isSearching ? 25.h : 0,
            child: isSearching // This was causing an error
                ? _buildOffersView(isDark)
                : _buildBottomSheet(context), // Pass isDark parameter
          ),
        ],
      ),
    );
  }

  Widget _buildMapBackground(bool isDark) {
    // Add isDark parameter
    return FlutterMap( // This was causing an error
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _userLocation,
        initialZoom: 14.0,
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
          urlTemplate: isDark
              ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.mezaan.app',
        ),
        if (_latitude != null && _longitude != null)
          MarkerLayer(
            markers: [
              _buildUserMarker(),
              if (isLawyerAccepted &&
                  _acceptedOffer != null &&
                  _currentCarLocation != null)
                _buildMovingCarMarker(_acceptedOffer!),
            ],
          ),
        // 3. The Route Line (Polyline)
        if (isLawyerAccepted &&
            _acceptedOffer != null &&
            _routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                color: const Color(0xFF0D2137), // Navy Blue
                strokeWidth: 4.0,
              ),
            ],
          ),
      ],
    );
  }

  Marker _buildUserMarker() {
    return Marker(
      width: 80.w,
      height: 95.h,
      point: _userLocation,
      child: Column(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [ // This was causing an error
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
          SizedBox(height: 4.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Text(
              'You',
              style: GoogleFonts.cairo(
                fontSize: 10.sp,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Marker _buildMovingCarMarker(LawyerOffer offer) {
    return Marker(
      width: 80.w,
      height: 95.h,
      point: _currentCarLocation!,
      child: Column(
        children: [
          Transform.rotate(
            angle: _carRotation,
            child: Icon(
              Icons.directions_car,
              color: AppColors.navyBlue,
              size: 30.sp,
            ),
          ),
          SizedBox(height: 4.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: AppColors.navyBlue,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Text(
              offer.name,
              style: GoogleFonts.cairo(
                fontSize: 10.sp,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;

    return GestureDetector(
      onTap: _showLocationOptions,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow( // This was causing an error
              color: Colors.black.withOpacity(0.12),
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
                ), // This was causing an error
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
                        fontSize: 12.sp, // This was causing an error
                      fontWeight: FontWeight.w700,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    _isLocationLoading
                        ? (_isArabic
                              ? 'جاري تحديد الموقع...'
                              : 'Finding location...')
                        : _locationName,
                    style: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: textColor,
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

  Widget _buildOffersView(bool isDark) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        padding: EdgeInsets.only(
          top: 18.h,
          left: 18.w,
          right: 18.w,
          bottom: 12.h,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 60.w,
                height: 5.h,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              _isArabic ? 'عروض المحامين' : 'Lawyer Offers',
              style: GoogleFonts.cairo(
                fontSize: 18.sp,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: offers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.hourglass_bottom,
                            size: 48.sp,
                            color: AppColors.legalGold,
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            _isArabic
                                ? 'في انتظار العروض...'
                                : 'Waiting for offers...',
                            style: GoogleFonts.cairo(
                              fontSize: 14.sp,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.only(top: 12.h, bottom: 8.h),
                      itemCount: offers.length,
                      separatorBuilder: (_, _) => SizedBox(height: 12.h),
                      itemBuilder: (context, index) {
                        final offer = offers[index];
                        return _buildOfferCard(offer, index, isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferCard(LawyerOffer offer, int index, bool isDark) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: AppColors.legalGold.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      padding: EdgeInsets.all(18.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'E£ ${formatFee(offer.price)}',
                      style: GoogleFonts.cairo(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navyBlue,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.legalGold.withOpacity(
                          isDark ? 0.2 : 0.1,
                        ), // This was causing an error
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Text(
                        '${offer.travelTime} min • ${offer.serviceType}', // This was causing an error
                        style: GoogleFonts.cairo(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: textColor?.withOpacity(0.7),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      _isArabic ? 'عرض مميز للخدمة' : 'Premium service offer',
                      style: GoogleFonts.cairo(
                        fontSize: 13.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.legalGold,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow( // This was causing an error
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 12,
                            offset: Offset(0, 6.h),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 37.w,
                        backgroundColor: Colors.grey[200],
                        foregroundImage: NetworkImage(offer.imageUrl),
                        child: Icon(
                          Icons.person,
                          size: 40.sp,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      offer.name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    Text(
                      offer.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 11.sp,
                        color: AppColors.textDark.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.star_rate_rounded,
                          color: Colors.amber,
                          size: 16.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          '${offer.rating}',
                          style: GoogleFonts.cairo(
                            fontSize: 12.sp,
                            color: textColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      '${offer.cases} cases',
                      style: GoogleFonts.cairo(
                        fontSize: 11.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _declineOffer(index),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade400, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  child: Text(
                    _isArabic ? 'رفض' : 'Decline',
                    style: GoogleFonts.cairo(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptOffer(offer),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    elevation: 0,
                  ),
                  child: Text(
                    _isArabic ? 'احجز الآن' : 'Book Now',
                    style: GoogleFonts.cairo(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final isDark = theme.brightness == Brightness.dark;

    final bottomHeight = MediaQuery.of(context).size.height * 0.55;
    return Container(
      height: bottomHeight,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        boxShadow: [
          BoxShadow( // This was causing an error
            color: Colors.black.withOpacity(0.15),
            blurRadius: 32,
            offset: Offset(0, -12.h),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 60.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
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
                  color: textColor,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Choose the service that best matches your legal issue.',
                style: GoogleFonts.cairo(
                  fontSize: 13.sp,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              SizedBox(height: 18.h),
              Container(
                // Description input field
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border.all( // This was causing an error
                    color: AppColors.legalGold.withOpacity(0.3),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.cairo(fontSize: 14.sp, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Describe your legal issue',
                    hintStyle: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      color: theme.hintColor,
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
                  color: textColor,
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                // Service selection cards
                height: 140.h,
                child: ListView.separated(
                  itemCount: _serviceCards.length,
                  scrollDirection: Axis.horizontal,
                  separatorBuilder: (_, _) => SizedBox(width: 12.w),
                  itemBuilder: (context, index) {
                    final card = _serviceCards[index];
                    final isSelected =
                        (card.title == 'Urgent SOS' &&
                            selectedService == 'urgent') ||
                        (card.title == 'Legal Consultation' &&
                            selectedService == 'legal') ||
                        (card.title == 'Document Review' &&
                            selectedService == 'document');
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (card.title == 'Urgent SOS') {
                          selectService('urgent', 300);
                        } else if (card.title == 'Legal Consultation') {
                          selectService('legal', 450);
                        } else if (card.title == 'Document Review') {
                          selectService('document', 500);
                        }
                      },
                      child: Container(
                        width: 200.w,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.navyBlue
                              : theme.cardColor,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.legalGold // This was causing an error
                                : AppColors.legalGold.withOpacity(0.3),
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
                                color: isSelected // This was causing an error
                                    ? AppColors.legalGold // This was causing an error
                                    : AppColors.legalGold.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                card.icon,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.legalGold,
                                size: 22.sp,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              card.title,
                              style: GoogleFonts.cairo(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : textColor,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              card.subtitle,
                              style: GoogleFonts.cairo(
                                fontSize: 11.sp,
                                color: isSelected
                                    ? Colors.white70
                                    : theme.textTheme.bodySmall?.color?.withOpacity(0.6),
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
                    selectedService == null
                        ? 'Select service'
                        : selectedService == 'urgent'
                        ? 'Minimum Salary: SOS 300'
                        : selectedService == 'legal'
                        ? 'Minimum Salary: Legal 450'
                        : 'Minimum Salary: Document 500',
                    style: GoogleFonts.cairo(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: selectedService != null
                          ? textColor
                          : theme.hintColor,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : AppColors.backgroundGrey,
                      border: Border.all( // This was causing an error
                        color: AppColors.legalGold.withOpacity(0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    child: Row(
                      children: [
                        _buildCounterButton(
                          Icons.remove,
                          () => setState(() {
                            if (selectedService != null &&
                                price > getMinPrice()) {
                              price -= 10;
                            }
                          }),
                          enabled:
                              selectedService != null && price > getMinPrice(),
                        ),
                        SizedBox(width: 14.w),
                        Text(
                          'E£ $price',
                          style: GoogleFonts.cairo(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: selectedService != null
                                ? textColor
                                : theme.hintColor,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        _buildCounterButton(Icons.add, () {
                          if (selectedService != null) {
                            setState(() => price += 10);
                          }
                        }, enabled: selectedService != null),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 22.h),
              ElevatedButton(
                onPressed: selectedService == 'urgent'
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SOSScreen(),
                          ),
                        );
                      }
                    : (_isFormValid ? _findLawyer : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedService == 'urgent'
                      ? Colors.red
                      : const Color(0xFF0D2137),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[400],
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  selectedService == 'urgent'
                      ? 'Open SOS Screen'
                      : 'Find a Lawyer',
                  style: GoogleFonts.cairo(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: AppColors.legalGold,
                    width: 1.5,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.cairo(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.legalGold,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCounterButton(
    IconData icon,
    VoidCallback onTap, {
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32.w,
        height: 32.h,
        decoration: BoxDecoration(
          color: enabled
              ? (isDark ? Colors.white10 : Colors.white) // This was causing an error
              : (isDark ? Colors.black12 : Colors.grey.withOpacity(0.1)),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled
                ? AppColors.legalGold // This was causing an error
                : theme.disabledColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: enabled
              ? (isDark ? Colors.white : AppColors.navyBlue)
              : theme.disabledColor,
          size: 16.sp,
        ),
      ),
    );
  }

  // Upgraded Tracking Mode UI with White Theme and Image 13 Details
  Widget _buildTrackingModeUI() {
    if (_acceptedOffer == null) return const SizedBox.shrink();

    return Stack(
      children: [
        // 1. Animated White Notification (Capsule Shape)
        Positioned(
          top: 60.h,
          left: 20.w,
          right: 20.w,
          child: SlideTransition(
            position: _notificationOffsetAnimation,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30.r),
                  boxShadow: [
                    BoxShadow( // This was causing an error
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: const BoxDecoration(
                        color: Color(0xFF29CC68), // Green 'iD' icon
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        'iD',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Flexible(
                      child: Text(
                        "Driver: I'm on my way. Is your pickup address correct?",
                        style: GoogleFonts.cairo(
                          color: Colors.black,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ), // End of Animated White Notification
        // 2. White Bottom Panel
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
              boxShadow: [
                BoxShadow( // This was causing an error
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 25,
                  offset: Offset(0, -10.h),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24.w,
                24.h,
                24.w,
                MediaQuery.of(context).viewInsets.bottom + 24.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Lawyer Info Section (Modern Driver Profile Layout)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: Profile Image
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.legalGold,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 32.w,
                            backgroundColor: Colors.grey[200],
                            foregroundImage: NetworkImage(
                              _acceptedOffer?.imageUrl ?? '',
                            ),
                            child: Icon(
                              Icons.person,
                              size: 32.sp,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),

                        // Center: Main Information
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _acceptedOffer?.name ?? 'Lawyer',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                _acceptedOffer?.title ?? 'Counsel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  fontSize: 13.sp,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Criminal & Family Law Expert',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  fontSize: 11.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8.h),
                              // Stats Row: Rating + Cases
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rate_rounded,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    '${_acceptedOffer?.rating ?? 0.0}',
                                    style: GoogleFonts.cairo(
                                      fontSize: 14.sp,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Container(
                                    width: 1,
                                    height: 12.h,
                                    color: Colors.grey[300],
                                  ),
                                  SizedBox(width: 12.w),
                                  Text(
                                    '${_acceptedOffer?.cases ?? 0} cases',
                                    style: GoogleFonts.cairo(
                                      fontSize: 13.sp,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12.w),

                        // Right: Action Buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _showChatBottomSheet,
                              child: Container(
                                padding: EdgeInsets.all(10.w),
                                decoration: const BoxDecoration(
                                  color: AppColors.navyBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            GestureDetector(
                              onTap: () {
                                final phone = _acceptedOffer?.phoneNumber ?? '';
                                if (phone.isNotEmpty) {
                                  launchUrl(Uri.parse('tel:$phone'));
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.all(10.w),
                                decoration: const BoxDecoration(
                                  color: AppColors.legalGold,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.call,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // 2. White Pickup Note (Interactive TextField)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: TextField(
                      style: GoogleFonts.cairo(
                        fontSize: 14.sp,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Add a note...',
                        hintStyle: GoogleFonts.cairo(
                          color: Colors.grey[400],
                          fontSize: 13.sp,
                        ),
                        prefixIcon: const Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.black,
                          size: 20,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 14.h,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: const BorderSide(
                            color: AppColors.legalGold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // 3. Payment Row
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Row(
                      children: [
                        Text(
                          'E£ $price',
                          style: GoogleFonts.cairo(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.money,
                                color: Colors.green,
                                size: 16,
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                'Cash',
                                style: GoogleFonts.cairo(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Divider(color: Colors.grey.withOpacity(0.2)),
                  ),
                  SizedBox(height: 16.h),

                  // 4. Current Trip Details (Pickup -> Destination)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: _buildTripTimeline(),
                  ),

                  SizedBox(height: 24.h),

                  // 4.5 Service Completed Button
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: ElevatedButton(
                      onPressed: _finishService,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF29CC68),
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 50.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _isArabic ? 'اكتملت الخدمة' : 'Service Completed',
                        style: GoogleFonts.cairo(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Divider(color: Colors.grey.withOpacity(0.2)),
                  ),

                  // 5. Bottom Actions
                  ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 24.w),
                    onTap: () {
                      final lawyerName = _acceptedOffer?.name ?? 'Lawyer';
                      Share.share(
                        'I am on my way with lawyer $lawyerName. Track me here: https://mezaan.app/track/123',
                        subject: 'Track my legal trip',
                      );
                    },
                    leading: const Icon(
                      Icons.share_outlined,
                      color: Colors.black,
                    ),
                    title: Text(
                      'Share my ride',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 24.w),
                    onTap: () => launchUrl(
                      Uri.parse('tel:122'),
                    ), // Launch dialer with 122
                    leading: const Icon(
                      Icons.security_outlined,
                      color: Colors.black,
                    ),
                    title: Text(
                      'Call 122',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 24.w),
                    onTap:
                        _showCancelConfirmationDialog, // Show confirmation dialog
                    leading: const Icon(Icons.close, color: Colors.red),
                    title: Text(
                      'Cancel Request',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTripTimeline() {
    return Column(
      children: [
        _buildLocationRow(
          icon: Icons.circle,
          iconColor: Colors.blue,
          address: _locationName,
          isFirst: true,
        ),
        Padding(
          padding: EdgeInsets.only(left: 8.5.w),
          child: Align(
            alignment: Alignment.centerLeft, // This was causing an error
            child: Container(
              width: 1.5,
              height: 25.h,
              color: Colors.grey.withOpacity(0.3),
            ),
          ),
        ),
        _buildLocationRow(
          icon: Icons.location_on,
          iconColor: Colors.red,
          address: 'Lawyers Syndicate HQ',
          isFirst: false,
        ),
      ],
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String address,
    required bool isFirst,
  }) {
    final addressColor = isFirst ? Colors.grey[700]! : Colors.black;
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18.sp),
        SizedBox(width: 14.w),
        Expanded(
          child: Text(
            address,
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              fontWeight: isFirst ? FontWeight.w500 : FontWeight.w700,
              color: addressColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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

class LawyerOffer {
  final String name;
  final String title;
  final double rating;
  final int price;
  final int travelTime;
  final String serviceType;
  final int cases;
  final String phoneNumber;
  final LatLng? location;
  final String imageUrl;

  const LawyerOffer({
    required this.name,
    required this.title,
    required this.rating,
    required this.price,
    required this.travelTime,
    required this.serviceType,
    required this.cases,
    required this.phoneNumber,
    this.location,
    required this.imageUrl,
  });
}
