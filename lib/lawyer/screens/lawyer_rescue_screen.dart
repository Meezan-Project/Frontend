import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class RescueRequest {
  final String clientId;
  final String clientName;
  final String clientPhone;
  final String clientAvatar;
  final String requestType; // 'sos' | 'consultation' | 'document'
  final String description;
  final double proposedFee;
  double finalFee;
  final LatLng location;

  RescueRequest({
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.clientAvatar,
    required this.requestType,
    required this.description,
    required this.proposedFee,
    required this.location,
  }) : finalFee = proposedFee;
}

class ChatMessage {
  final String text;
  final bool isUser; // true if sent by lawyer, false if client
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class LawyerRescueScreen extends StatefulWidget {
  const LawyerRescueScreen({super.key});

  @override
  State<LawyerRescueScreen> createState() => _LawyerRescueScreenState();
}

class _LawyerRescueScreenState extends State<LawyerRescueScreen> {
  // Map & Location State
  final MapController _mapController = MapController();
  bool _mapReady = false;
  LatLng _lawyerLocation = const LatLng(30.0444, 31.2357); // default Cairo
  bool _isLocationLoading = true;

  // Active Status State
  bool _isActive = false;
  Timer? _simulationTimer;

  // Active Requests State
  RescueRequest? _currentRequest;
  RescueRequest? _acceptedRequest;
  bool _isWaitingResponse = false;
  bool _showCounterInput = false;
  final TextEditingController _counterFeeController = TextEditingController();

  // Route/Line details
  final List<LatLng> _routePoints = [];

  // Database Users for realistic simulations
  List<Map<String, dynamic>> _firebaseUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchFirebaseUsers();
    _checkLocationPermissionAndGetLocation();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _counterFeeController.dispose();
    super.dispose();
  }

  // Fetch real users from Firestore to make requests look authentic
  void _fetchFirebaseUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(10)
          .get();
      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _firebaseUsers = snapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data(),
                  })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching Firebase users for simulation: $e');
    }
  }

  Future<void> _checkLocationPermissionAndGetLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLocationLoading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLocationLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLocationLoading = false);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _lawyerLocation = LatLng(position.latitude, position.longitude);
        _isLocationLoading = false;
      });
      if (_mapReady) {
        _mapController.move(_lawyerLocation, 15.0);
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
      setState(() => _isLocationLoading = false);
    }
  }

  void _toggleActiveStatus() async {
    if (!_isActive) {
      // Toggle to Active
      setState(() {
        _isActive = true;
      });
      _startRequestSimulation();
    } else {
      // Toggle to Offline
      _simulationTimer?.cancel();
      setState(() {
        _isActive = false;
        _currentRequest = null;
        _acceptedRequest = null;
        _isWaitingResponse = false;
        _showCounterInput = false;
        _routePoints.clear();
      });
    }
    HapticFeedback.mediumImpact();
  }

  void _startRequestSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      if (!_isActive) {
        timer.cancel();
        return;
      }
      if (_currentRequest != null || _acceptedRequest != null || _isWaitingResponse) {
        return; // Don't trigger if already handling a request
      }

      _generateSimulatedRequest();
    });

    // Also trigger first request immediately after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (_isActive && _currentRequest == null && _acceptedRequest == null && !_isWaitingResponse) {
        _generateSimulatedRequest();
      }
    });
  }

  void _generateSimulatedRequest() {
    final rand = Random();
    final categories = ['sos', 'consultation', 'document'];
    final selectedCat = categories[rand.nextInt(categories.length)];

    double proposedFee = 300.0;
    String description = '';

    if (selectedCat == 'sos') {
      proposedFee = 400.0 + rand.nextInt(200); // 400 - 600
      description = 'Emergency! Stopped by traffic police, need immediate support at the scene.'.translate();
    } else if (selectedCat == 'consultation') {
      proposedFee = 300.0 + rand.nextInt(150); // 300 - 450
      description = 'Quick legal advice needed regarding apartment lease contract dispute.'.translate();
    } else {
      proposedFee = 500.0 + rand.nextInt(300); // 500 - 800
      description = 'Commercial service agreement review for a newly launched online store.'.translate();
    }

    // Coordinates offset close to lawyer
    final latOffset = (rand.nextDouble() - 0.5) * 0.012;
    final lngOffset = (rand.nextDouble() - 0.5) * 0.012;
    final userLocation = LatLng(
      _lawyerLocation.latitude + latOffset,
      _lawyerLocation.longitude + lngOffset,
    );

    // Pick a real Firestore user if available, otherwise fallback to mock
    String clientName = 'Amr Fathy';
    String clientPhone = '+201112345678';
    String clientAvatar = 'https://i.pravatar.cc/150?u=amrfathy';
    String clientId = 'mock_user_id';

    if (_firebaseUsers.isNotEmpty) {
      final user = _firebaseUsers[rand.nextInt(_firebaseUsers.length)];
      clientId = user['id'] ?? 'user_id';
      clientName = user['name'] ?? user['fullName'] ?? 'Client User';
      clientPhone = user['phone'] ?? user['phoneNumber'] ?? '+201000000000';
      clientAvatar = user['profile_photo'] ?? user['profilePic'] ?? 'https://i.pravatar.cc/150?u=${clientId}';
    } else {
      final fallbackNames = ['Mohamed Ali', 'Sherif Kamel', 'Yasmine Refaat', 'Nour Eldin'];
      clientName = fallbackNames[rand.nextInt(fallbackNames.length)];
      clientPhone = '+2010${rand.nextInt(89999999) + 10000000}';
      clientAvatar = 'https://i.pravatar.cc/150?u=${clientName.replaceAll(' ', '')}';
    }

    setState(() {
      _currentRequest = RescueRequest(
        clientId: clientId,
        clientName: clientName,
        clientPhone: clientPhone,
        clientAvatar: clientAvatar,
        requestType: selectedCat,
        description: description,
        proposedFee: proposedFee,
        location: userLocation,
      );
      _counterFeeController.text = proposedFee.toStringAsFixed(0);
    });

    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.click);
  }

  void _acceptPrice() {
    if (_currentRequest == null) return;
    setState(() {
      _currentRequest!.finalFee = _currentRequest!.proposedFee;
      _isWaitingResponse = true;
      _showCounterInput = false;
    });

    _simulateUserDecision(acceptChance: 85);
  }

  void _sendCounterOffer() {
    if (_currentRequest == null) return;
    final double counterVal = double.tryParse(_counterFeeController.text) ?? _currentRequest!.proposedFee;
    if (counterVal < _currentRequest!.proposedFee) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Counter offer cannot be less than proposed fee'.translate()),
          backgroundColor: AppColors.sosRed,
        ),
      );
      return;
    }

    setState(() {
      _currentRequest!.finalFee = counterVal;
      _isWaitingResponse = true;
      _showCounterInput = false;
    });

    // Decreased chance if counter is much higher
    final multiplier = counterVal / _currentRequest!.proposedFee;
    int chance = 70;
    if (multiplier > 1.5) {
      chance = 25;
    } else if (multiplier > 1.2) {
      chance = 45;
    }

    _simulateUserDecision(acceptChance: chance);
  }

  void _simulateUserDecision({required int acceptChance}) {
    Timer(const Duration(seconds: 3), () {
      if (!mounted || _currentRequest == null) return;

      final rand = Random().nextInt(100);
      if (rand < acceptChance) {
        // User Accepted!
        setState(() {
          _acceptedRequest = _currentRequest;
          _currentRequest = null;
          _isWaitingResponse = false;
          _generateRoute(_lawyerLocation, _acceptedRequest!.location);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Client accepted your request! Routing now...'.translate()),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // User Rejected!
        final rejectedReq = _currentRequest!;
        setState(() {
          _isWaitingResponse = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Client rejected your offer. Request returns...'.translate()),
            backgroundColor: AppColors.sosRed,
          ),
        );

        // Put request back after 2 seconds loop as requested by the user
        Timer(const Duration(seconds: 2), () {
          if (mounted && _isActive && _acceptedRequest == null && _currentRequest == null) {
            setState(() {
              _currentRequest = rejectedReq;
              _counterFeeController.text = rejectedReq.proposedFee.toStringAsFixed(0);
            });
          }
        });
      }
    });
  }

  void _generateRoute(LatLng start, LatLng end) {
    _routePoints.clear();
    // Simple simulated path
    _routePoints.add(start);
    final midLat1 = start.latitude + (end.latitude - start.latitude) * 0.3 + 0.001;
    final midLng1 = start.longitude + (end.longitude - start.longitude) * 0.4 - 0.001;
    _routePoints.add(LatLng(midLat1, midLng1));

    final midLat2 = start.latitude + (end.latitude - start.latitude) * 0.7 - 0.001;
    final midLng2 = start.longitude + (end.longitude - start.longitude) * 0.6 + 0.001;
    _routePoints.add(LatLng(midLat2, midLng2));

    _routePoints.add(end);

    if (_mapReady) {
      // Zoom map to show both markers
      final bounds = LatLngBounds.fromPoints([start, end]);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
    }
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text(
            'Cancel Request?'.translate(),
            style: GoogleFonts.cairo(color: AppColors.sosRed, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to cancel this request? This could affect your emergency response rating.'.translate(),
            style: GoogleFonts.cairo(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('No, Keep'.translate(), style: GoogleFonts.cairo(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _acceptedRequest = null;
                  _routePoints.clear();
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.sosRed),
              child: Text('Yes, Cancel'.translate(), style: GoogleFonts.cairo(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _completeRequest() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 72),
              SizedBox(height: 16.h),
              Text(
                'Job Completed!'.translate(),
                style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.bold, color: AppColors.navyBlue),
              ),
              SizedBox(height: 8.h),
              Text(
                'EGP ${_acceptedRequest?.finalFee.toStringAsFixed(0)} ${'has been added to your office wallet.'.translate()}',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 14.sp),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _acceptedRequest = null;
                      _routePoints.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.legalGold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: Text('Done'.translate(), style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openChatBottomSheet() {
    if (_acceptedRequest == null) return;

    final List<ChatMessage> messages = [
      ChatMessage(
        text: _acceptedRequest!.requestType == 'sos'
            ? 'Emergency! Please hurry, I am waiting for you.'.translate()
            : 'Hello, thank you for accepting. Ready when you are.'.translate(),
        isUser: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    ];

    final TextEditingController textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            void sendMsg() {
              final val = textController.text.trim();
              if (val.isEmpty) return;
              textController.clear();
              setBottomSheetState(() {
                messages.add(ChatMessage(text: val, isUser: true, timestamp: DateTime.now()));
              });

              // Simulate response
              Timer(const Duration(milliseconds: 1500), () {
                if (!mounted) return;
                setBottomSheetState(() {
                  messages.add(ChatMessage(
                    text: 'Okay, sounds good. I will wait.'.translate(),
                    isUser: false,
                    timestamp: DateTime.now(),
                  ));
                });
              });
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                ),
                child: Column(
                  children: [
                    // Handle line
                    SizedBox(height: 8.h),
                    Center(
                      child: Container(
                        width: 48.w,
                        height: 5.h,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8.r)),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: NetworkImage(_acceptedRequest!.clientAvatar),
                            radius: 20.r,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _acceptedRequest!.clientName,
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14.sp, color: AppColors.navyBlue),
                                ),
                                Text(
                                  _acceptedRequest!.clientPhone,
                                  style: GoogleFonts.cairo(fontSize: 11.sp, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Message List
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.all(16.r),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final align = msg.isUser ? Alignment.centerRight : Alignment.centerLeft;
                          final bubbleBg = msg.isUser ? AppColors.navyBlue : Colors.grey[200];
                          final textColor = msg.isUser ? Colors.white : Colors.black87;

                          return Align(
                            alignment: align,
                            child: Container(
                              margin: EdgeInsets.only(bottom: 12.h),
                              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: bubbleBg,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(16.r),
                                  topRight: Radius.circular(16.r),
                                  bottomLeft: msg.isUser ? Radius.circular(16.r) : Radius.zero,
                                  bottomRight: msg.isUser ? Radius.zero : Radius.circular(16.r),
                                ),
                              ),
                              child: Text(
                                msg.text,
                                style: GoogleFonts.cairo(fontSize: 13.sp, color: textColor),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    // Input bar
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: textController,
                              style: GoogleFonts.cairo(fontSize: 14.sp),
                              decoration: InputDecoration(
                                hintText: 'Type a message...'.translate(),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24.r),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                              ),
                              onSubmitted: (_) => sendMsg(),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          GestureDetector(
                            onTap: sendMsg,
                            child: CircleAvatar(
                              radius: 20.r,
                              backgroundColor: AppColors.legalGold,
                              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            ),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Map layer
          _isLocationLoading
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _lawyerLocation,
                    initialZoom: 14.0,
                    onMapReady: () {
                      _mapReady = true;
                      _mapController.move(_lawyerLocation, 14.0);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: isDark
                          ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.mezaan.app',
                    ),
                    // Markers Layer
                    MarkerLayer(
                      markers: [
                        // Lawyer marker
                        Marker(
                          point: _lawyerLocation,
                          width: 50.w,
                          height: 50.h,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.navyBlue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3.w),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6.r,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.gavel_rounded, color: AppColors.legalGold, size: 22),
                          ),
                        ),
                        // Client marker
                        if (_acceptedRequest != null)
                          Marker(
                            point: _acceptedRequest!.location,
                            width: 60.w,
                            height: 60.h,
                            child: Column(
                              children: [
                                CircleAvatar(
                                  backgroundImage: NetworkImage(_acceptedRequest!.clientAvatar),
                                  radius: 18.r,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.sosRed, width: 2.w),
                                    ),
                                  ),
                                ),
                                const Icon(Icons.pin_drop_rounded, color: AppColors.sosRed, size: 20),
                              ],
                            ),
                          ),
                        if (_currentRequest != null && _acceptedRequest == null)
                          Marker(
                            point: _currentRequest!.location,
                            width: 60.w,
                            height: 60.h,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.legalGold,
                              size: 38,
                            ),
                          ),
                      ],
                    ),
                    // Polyline layer
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            color: AppColors.navyBlue,
                            strokeWidth: 4.w,
                          ),
                        ],
                      ),
                  ],
                ),

          // 2. Active / Offline Toggler Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 12.h,
            left: 20.w,
            right: 20.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(30.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10.r,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12.w,
                        height: 12.w,
                        decoration: BoxDecoration(
                          color: _isActive ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        _isActive ? 'ACTIVE & ONLINE'.translate() : 'OFFLINE'.translate(),
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                          color: _isActive
                              ? Colors.green
                              : (isDark ? Colors.grey : AppColors.textDark.withOpacity(0.6)),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _toggleActiveStatus,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: _isActive ? AppColors.sosRed : AppColors.navyBlue,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        _isActive ? 'Go Offline'.translate() : 'Go Active'.translate(),
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. UI overlays at the bottom (Incoming request card, accepted request card, loader)
          if (_isActive) ...[
            // Scenario A: Waiting client response loader
            if (_isWaitingResponse && _currentRequest != null)
              Positioned(
                bottom: 24.h,
                left: 16.w,
                right: 16.w,
                child: Container(
                  padding: EdgeInsets.all(20.r),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 12.r),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.legalGold),
                      SizedBox(height: 16.h),
                      Text(
                        'Sending offer to client...'.translate(),
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15.sp),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Waiting for client decision'.translate(),
                        style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

            // Scenario B: Incoming request card
            if (_currentRequest != null && !_isWaitingResponse)
              Positioned(
                bottom: 24.h,
                left: 16.w,
                right: 16.w,
                child: Container(
                  padding: EdgeInsets.all(20.r),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 16.r, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: _currentRequest!.requestType == 'sos'
                                  ? AppColors.sosRed.withOpacity(0.15)
                                  : AppColors.legalGold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _currentRequest!.requestType == 'sos'
                                      ? Icons.warning_rounded
                                      : Icons.gavel_rounded,
                                  color: _currentRequest!.requestType == 'sos'
                                      ? AppColors.sosRed
                                      : AppColors.legalGold,
                                  size: 16.sp,
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  _currentRequest!.requestType == 'sos'
                                      ? 'Urgent SOS'.translate()
                                      : _currentRequest!.requestType == 'consultation'
                                          ? 'Consultation'.translate()
                                          : 'Document Review'.translate(),
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.sp,
                                    color: _currentRequest!.requestType == 'sos'
                                        ? AppColors.sosRed
                                        : AppColors.legalGold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'EGP ${_currentRequest!.proposedFee.toStringAsFixed(0)}',
                            style: GoogleFonts.cairo(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navyBlue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      // Client info
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: NetworkImage(_currentRequest!.clientAvatar),
                            radius: 22.r,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentRequest!.clientName,
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15.sp),
                                ),
                                Text(
                                  'Proposed Emergency Fee'.translate(),
                                  style: GoogleFonts.cairo(fontSize: 11.sp, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        _currentRequest!.description,
                        style: GoogleFonts.cairo(fontSize: 13.sp, color: Colors.grey[700]),
                      ),
                      SizedBox(height: 16.h),
                      // Action buttons or Counter input
                      _showCounterInput
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _counterFeeController,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.cairo(),
                                        decoration: InputDecoration(
                                          labelText: 'Counter Offer (EGP)'.translate(),
                                          border: const OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    ElevatedButton(
                                      onPressed: _sendCounterOffer,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.navyBlue,
                                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                                      ),
                                      child: Text('Send'.translate(), style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8.h),
                                TextButton(
                                  onPressed: () => setState(() => _showCounterInput = false),
                                  child: Text('Cancel'.translate(), style: GoogleFonts.cairo(color: Colors.grey)),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(() => _showCounterInput = true),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: AppColors.legalGold),
                                      foregroundColor: AppColors.legalGold,
                                      padding: EdgeInsets.symmetric(vertical: 12.h),
                                    ),
                                    child: Text('Counter Offer'.translate(), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _acceptPrice,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.navyBlue,
                                      padding: EdgeInsets.symmetric(vertical: 12.h),
                                    ),
                                    child: Text('Accept Price'.translate(), style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),

            // Scenario C: Accepted active request card
            if (_acceptedRequest != null)
              Positioned(
                bottom: 24.h,
                left: 16.w,
                right: 16.w,
                child: Container(
                  padding: EdgeInsets.all(20.r),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 16.r, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.directions_car_rounded, color: AppColors.legalGold),
                              SizedBox(width: 6.w),
                              Text(
                                'EN ROUTE TO CLIENT'.translate(),
                                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.legalGold, fontSize: 13.sp),
                              ),
                            ],
                          ),
                          Text(
                            'EGP ${_acceptedRequest!.finalFee.toStringAsFixed(0)}',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 16.sp, color: AppColors.navyBlue),
                          ),
                        ],
                      ),
                      SizedBox(height: 14.h),
                      // Client data
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: NetworkImage(_acceptedRequest!.clientAvatar),
                            radius: 24.r,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _acceptedRequest!.clientName,
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16.sp),
                                ),
                                Text(
                                  _acceptedRequest!.clientPhone,
                                  style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 18.h),
                      // Actions row
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined, color: AppColors.sosRed),
                            iconSize: 28.sp,
                            onPressed: _showCancelConfirmation,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openChatBottomSheet,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.navyBlue),
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                              ),
                              icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.navyBlue),
                              label: Text('Chat'.translate(), style: GoogleFonts.cairo(color: AppColors.navyBlue, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _completeRequest,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.navyBlue,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                              ),
                              child: Text('Complete'.translate(), style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
