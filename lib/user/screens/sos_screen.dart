import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const int _kMaxRecordingSeconds = 15 * 60; // 15 minutes

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  int _remainingRecordingSeconds = _kMaxRecordingSeconds;
  Timer? _recordingTimer;
  String? _activeAlertDocId;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // Pulsing animation for the SOS button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        // Prioritize the back camera for SOS situations, fallback to any camera
        final backCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
        _cameraController = CameraController(
          backCamera,
          ResolutionPreset.medium,
          enableAudio: true, // Enable audio for real recording
        );
        await _cameraController!.initialize();
        if (!mounted) return;
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
      // Fail gracefully, the screen should still work without the preview
    }
  }

  void _onSOSPressed() {
    // CRITICAL: Ensure user is logged in before starting SOS
    if (FirebaseAuth.instance.currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: You must be logged in to send an SOS alert.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return; // Stop execution
    }
    if (!_isRecording) {
      _startSOS();
    }
  }

  void _startSOS() {
    setState(() {
      _isRecording = true;
      _remainingRecordingSeconds = _kMaxRecordingSeconds;
    });

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingRecordingSeconds > 0) {
        setState(() => _remainingRecordingSeconds--);
      } else {
        _stopSOS();
      }
    });

    _startCameraRecording();
    _sendSilentAlert();
  }

  Future<void> _startCameraRecording() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        await _cameraController!.startVideoRecording();
      } catch (e) {
        debugPrint('Error starting recording: $e');
      }
    }
  }

  Future<void> _sendSilentAlert() async {
    String locationText = 'Location unavailable';
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        // Handle this case, maybe show a dialog
        debugPrint("Location permission denied forever.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is permanently denied. Please enable it in app settings.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        locationText =
            'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }

    // Silent Background Send to Firestore
    // This acts as the trigger. A backend Cloud Function should listen to this
    // and send the WhatsApp/SMS silently via Twilio or similar API.
    try {
      // The user's existence is already checked in _onSOSPressed, so we can use !.
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final docRef = await FirebaseFirestore.instance
          .collection('sos_alerts')
          .add({
            'userId': userId,
            'location': locationText,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'active',
          });
      _activeAlertDocId = docRef.id;
    } catch (e) {
      debugPrint('Failed to send silent alert: $e');
    }
  }

  Future<void> _stopSOS() async {
    _recordingTimer?.cancel();
    if (_cameraController != null &&
        _cameraController!.value.isRecordingVideo) {
      try {
        final XFile videoFile = await _cameraController!.stopVideoRecording();
        final duration = _kMaxRecordingSeconds - _remainingRecordingSeconds;

        _uploadVideoToSupabase(videoFile.path, duration);
      } catch (e) {
        debugPrint('Error stopping recording: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _uploadVideoToSupabase(String filePath, int duration) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading secure evidence... Please wait.'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        debugPrint('Upload failed: User is not authenticated.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload failed: User session expired.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final ext = filePath.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = '$userId/$fileName'; // Creates a folder for the user
      final file = File(filePath);

      // Upload to Supabase Bucket 'sos_videos'
      await Supabase.instance.client.storage
          .from('sos_videos')
          .upload(storagePath, file);

      // CRITICAL FIX: Use createSignedUrl instead of getPublicUrl.
      // If the Supabase bucket is private, getPublicUrl gives a broken link.
      // createSignedUrl gives a guaranteed playable link.
      final videoUrl = await Supabase.instance.client.storage
          .from('sos_videos')
          .createSignedUrl(storagePath, 60 * 60 * 24 * 365 * 10); // Valid for 10 years

      if (_activeAlertDocId != null) {
        // Update the existing alert record to include the videoUrl
        await FirebaseFirestore.instance
            .collection('sos_alerts')
            .doc(_activeAlertDocId)
            .update({
              'videoUrl': videoUrl,
              'duration': duration,
              'status': 'saved',
            });
      } else {
        // Fallback: Create a new record if silent alert somehow didn't store the ID
        await FirebaseFirestore.instance.collection('sos_alerts').add({
          'userId': userId, // Now using the verified non-null userId
          'videoUrl': videoUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'duration': duration,
          'status': 'saved',
          'location': 'Location unavailable',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evidence uploaded and saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading video to Supabase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showPinDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Stop SOS Alert',
          style: TextStyle(
            color: AppColors.navyBlue,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Enter Wallet PIN',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              try {
                final doc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get();

                final savedPin = doc.data()?['walletPasscode'];

                if (dialogContext.mounted) {
                  if (savedPin != null && pinController.text == savedPin) {
                    Navigator.pop(dialogContext); // Close dialog
                    _stopSOS();
                  } else {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid PIN!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint('Error validating PIN: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String get _formattedTime {
    int m = _remainingRecordingSeconds ~/ 60;
    int s = _remainingRecordingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _recordingTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return PopScope(
      canPop: !_isRecording,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isRecording) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please stop the SOS alert to go back.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0A0E27), Color(0xFF1A1A3E)],
            ),
          ),
          child: Stack(
            children: [
              // Camera Preview Background
              if (_isCameraInitialized && _cameraController != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.4, // Lower opacity to keep text readable
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              // Glow background effect
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.5,
                          colors: [
                            Colors.red.withOpacity(0.1 * _glowController.value),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Main content
              SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                            minWidth: constraints.maxWidth,
                          ),
                          child: _isRecording
                              ? _buildRecordingUI()
                              : Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _buildHeader(isMobile),
                                    _buildSOSButton(isMobile),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Back Arrow to Dashboard
              if (!_isRecording)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16.h,
                  left: 16.w,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 28.sp,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.w : 40.w,
        vertical: isMobile ? 16.h : 24.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Are you in danger?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 24.sp : 28.sp,
            ),
          ),
          SizedBox(height: isMobile ? 12.h : 16.h),
          Text(
            'Press the button to alert your\nemergency contacts.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[400],
              fontSize: isMobile ? 14.sp : 16.sp,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSButton(bool isMobile) {
    final buttonSize = isMobile ? 160.0.r : 200.0.r;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (0.1 * _pulseController.value),
          child: GestureDetector(
            onTap: _isRecording ? null : _onSOSPressed,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.6),
                    blurRadius: 20 + (10 * _pulseController.value),
                    spreadRadius: 5 + (5 * _pulseController.value),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.deepOrange[700],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'SOS',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 48.sp : 56.sp,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecordingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 100.h),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Opacity(
              opacity: _pulseController.value,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 16.r,
                    height: 16.r,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'REC',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        SizedBox(height: 40.h),
        Text(
          _formattedTime,
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: 64.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: 20.h),
        Text(
          'Secure evidence is being recorded\nand live location is shared.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 16.sp),
        ),
        SizedBox(height: 80.h),
        ElevatedButton(
          onPressed: _showPinDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[800],
            padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 16.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.r),
            ),
          ),
          child: Text(
            'Stop SOS Alert',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
