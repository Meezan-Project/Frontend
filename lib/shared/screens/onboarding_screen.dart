import 'dart:async'; // مهمة عشان الـ Timer
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
import 'package:mezaan/shared/localization/localization_controller.dart';
import 'package:mezaan/shared/widgets/language_toggle_button.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:video_player/video_player.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer; // التايمر اللي هيحرك الصفحات
  List<OnboardingSlide> _slides = <OnboardingSlide>[];
  bool _isLoadingSlides = true;
  String? _slidesError;

  static const List<OnboardingSlide> _localFallbackSlides = <OnboardingSlide>[
    OnboardingSlide(
      title: 'Video Call with Lawyer',
      description:
          'Connect with legal experts via high-quality video calls safely and privately.',
      videoAsset: 'assets/videos/onboarding_lawer_call.mp4',
      videoScale: 1.20,
    ),
    OnboardingSlide(
      title: 'Book Appointments',
      description:
          'Schedule your meetings with top-rated lawyers easily through our app.',
      videoAsset: 'assets/videos/onboarding_booking_appointment.mp4',
      fallbackVideoAssets: <String>[
        'assets/videos/Animation_of_Booking_an_Appointment.mp4',
        'assets/videos/onboarding_lawer_call.mp4',
      ],
      videoScale: 1.38,
    ),
    OnboardingSlide(
      title: 'Free AI Consultation',
      description:
          'Get instant legal advice for free through our advanced AI assistant.',
      videoAsset: 'assets/videos/Video_Generated_Without_Lawyer.mp4',
      videoScale: 1.25,
    ),
    OnboardingSlide(
      title: 'Your Legal Hub',
      description:
          'Access all legal services in one powerful application anytime.',
      icon: Icons.hub,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadSlidesFromFirebase();

    // تشغيل الـ Auto-Slide كل 7 ثواني
    _timer = Timer.periodic(const Duration(seconds: 7), (Timer timer) {
      if (_slides.length < 2) {
        return;
      }

      if (_currentPage < _slides.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0; // يرجع لأول صفحة لما يخلص
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadSlidesFromFirebase() async {
    setState(() {
      _isLoadingSlides = true;
      _slidesError = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('onboarding_slides')
          .orderBy('order')
          .get();

      final loaded = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final title = data['title']?.toString().trim() ?? '';
            final description = data['description']?.toString().trim() ?? '';
            if (title.isEmpty || description.isEmpty) {
              return null;
            }

            final videoAsset = data['videoAsset']?.toString().trim();
            final videoScaleRaw = data['videoScale'];
            final videoScale = videoScaleRaw is num
                ? videoScaleRaw.toDouble()
                : double.tryParse(videoScaleRaw?.toString() ?? '') ?? 1.0;

            final fallbackRaw = data['fallbackVideoAssets'];
            final fallbackAssets = fallbackRaw is List
                ? fallbackRaw
                      .map((e) => e?.toString().trim() ?? '')
                      .where((e) => e.isNotEmpty)
                      .toList(growable: false)
                : const <String>[];

            return OnboardingSlide(
              title: title,
              description: description,
              videoAsset: (videoAsset?.isNotEmpty ?? false) ? videoAsset : null,
              fallbackVideoAssets: fallbackAssets,
              videoScale: videoScale,
            );
          })
          .whereType<OnboardingSlide>()
          .toList(growable: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _slides = loaded.isNotEmpty ? loaded : _localFallbackSlides;
        _isLoadingSlides = false;
        _slidesError = loaded.isEmpty
            ? 'No onboarding slides found in Firebase. Showing local fallback.'
            : null;
        if (_slides.isEmpty) {
          _currentPage = 0;
        } else if (_currentPage >= _slides.length) {
          _currentPage = 0;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _slides = _localFallbackSlides;
        _isLoadingSlides = false;
        _slidesError =
            'Failed to load onboarding slides from Firebase. Showing local fallback.';
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // لازم تكنسل التايمر عشان ميعملش Memory Leak
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final localizationController = LocalizationController.instance;

    return Obx(() {
      localizationController.currentLanguage.value;

      if (_isLoadingSlides) {
        return const Scaffold(
          backgroundColor: Color(0xFFF5F7FA),
          body: SafeArea(child: Center(child: CircularProgressIndicator())),
        );
      }

      if (_slides.isEmpty) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 54.sp,
                      color: AppColors.navyBlue,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      (_slidesError ??
                              'No onboarding slides found in Firebase.')
                          .translate(),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: _loadSlidesFromFirebase,
                      child: Text('Retry'.translate()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final activeSlide = _slides[_currentPage];

      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SafeArea(
          child: Column(
            children: [
              // 1. بانر علوي أصغر يحتوي النص
              Container(
                height: size.height * 0.25,
                width: double.infinity,
                margin: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 10.h),
                padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 18.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28.r),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF052B52),
                      AppColors.navyBlue,
                      Color(0xFF0B5E55),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.16),
                      blurRadius: 18,
                      offset: Offset(0, 8.h),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -35,
                      right: -24,
                      child: Container(
                        width: 120.w,
                        height: 120.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.09),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -42,
                      left: -32,
                      child: Container(
                        width: 140.w,
                        height: 140.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.legalGold.withOpacity(0.18),
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              activeSlide.title.translate(),
                              style: TextStyle(
                                fontSize: 30.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.06,
                                letterSpacing: 0.4,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.22),
                                    blurRadius: 10,
                                    offset: Offset(0, 3.h),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              activeSlide.description.translate(),
                              style: TextStyle(
                                fontSize: 15.sp,
                                color: Colors.white.withOpacity(0.92),
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                                letterSpacing: 0.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Positioned(
                      top: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: LanguageToggleButton(
                            backgroundColor: Colors.white24,
                            iconColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. المساحة البيضاء للميديا فقط
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 14.w),
                  padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 8.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 18,
                        offset: Offset(0, 8.h),
                      ),
                    ],
                  ),
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      return OnboardingSlideWidget(slide: _slides[index]);
                    },
                  ),
                ),
              ),

              // 3. المؤشرات + الأزرار
              Container(
                padding: EdgeInsets.fromLTRB(28.w, 18.h, 28.w, 20.h),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: EdgeInsets.symmetric(horizontal: 5.w),
                          width: _currentPage == index ? 35.w : 12.w,
                          height: 8.h,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppColors.legalGold
                                : const Color(0xFFD7DEE7),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 56.h,
                            child: ElevatedButton(
                              onPressed: () =>
                                  LoadingNavigator.pushReplacementNamed(
                                    context,
                                    AppRoutes.login,
                                  ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF042A52),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Login'.translate(),
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: SizedBox(
                            height: 56.h,
                            child: OutlinedButton(
                              onPressed: () =>
                                  LoadingNavigator.pushReplacementNamed(
                                    context,
                                    AppRoutes.register,
                                  ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.legalGold,
                                  width: 1.8,
                                ),
                                foregroundColor: const Color(0xFF8B6A00),
                                backgroundColor: const Color(0xFFFFF9E8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                              ),
                              child: Text(
                                'Register'.translate(),
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class OnboardingSlideWidget extends StatefulWidget {
  final OnboardingSlide slide;
  const OnboardingSlideWidget({super.key, required this.slide});

  @override
  State<OnboardingSlideWidget> createState() => _OnboardingSlideWidgetState();
}

class _OnboardingSlideWidgetState extends State<OnboardingSlideWidget> {
  VideoPlayerController? _videoController;
  bool _videoLoadFailed = false;
  String? _videoErrorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.slide.videoAsset != null) {
      _initializeVideo();
    }
  }

  @override
  void didUpdateWidget(covariant OnboardingSlideWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slide.videoAsset != widget.slide.videoAsset &&
        widget.slide.videoAsset != null) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    final primaryVideoAsset = widget.slide.videoAsset;
    if (primaryVideoAsset == null) return;

    final previousController = _videoController;
    _videoController = null;

    if (mounted) {
      setState(() {
        _videoLoadFailed = false;
        _videoErrorMessage = null;
      });
    }

    await previousController?.dispose();

    final candidateAssets = <String>[
      primaryVideoAsset,
      ...widget.slide.fallbackVideoAssets,
    ];

    Object? lastError;

    for (final asset in candidateAssets) {
      final controller = VideoPlayerController.asset(asset);

      try {
        await controller.initialize().timeout(const Duration(seconds: 8));
        await controller.setLooping(true);
        await controller.setVolume(0);

        if (!mounted) {
          await controller.dispose();
          return;
        }

        _videoController = controller;
        setState(() {});
        await controller.play();
        return;
      } catch (error) {
        lastError = error;
        await controller.dispose();
      }
    }

    if (!mounted) return;
    setState(() {
      _videoLoadFailed = true;
      _videoErrorMessage = (lastError ?? 'Video failed to load').toString();
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasInitializedVideo =
        _videoController != null && _videoController!.value.isInitialized;

    return LayoutBuilder(
      builder: (context, constraints) {
        final frameWidth = (constraints.maxWidth * 0.97).clamp(230.0, 335.0);
        final frameHeight = constraints.maxHeight;

        return Center(
          child: widget.slide.videoAsset != null
              ? Container(
                  width: frameWidth,
                  height: frameHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24.r),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF7FAFD), Color(0xFFEAF1F8)],
                    ),
                    border: Border.all(
                      color: const Color(0xFFDCE6F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: Offset(0, 8.h),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24.r),
                    child: _videoLoadFailed
                        ? _VideoFallback(
                            errorMessage: _videoErrorMessage,
                            translateLabel: 'Video could not be loaded'
                                .translate(),
                            onRetry: _initializeVideo,
                          )
                        : !hasInitializedVideo
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 44.w,
                                  height: 44.h,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: AppColors.navyBlue,
                                  ),
                                ),
                                SizedBox(height: 14.h),
                                Text(
                                  'Loading video...'.translate(),
                                  style: TextStyle(
                                    color: const Color(0xFF6E7B8B),
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final videoSize = _videoController!.value.size;

                              return ColoredBox(
                                color: const Color(0xFFEAF1F8),
                                child: ClipRect(
                                  child: SizedBox.expand(
                                    child: Transform.scale(
                                      scale: widget.slide.videoScale,
                                      alignment: Alignment.center,
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: videoSize.width,
                                          height: videoSize.height,
                                          child: VideoPlayer(_videoController!),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                )
              : Container(
                  width: 165.w,
                  height: 165.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF2F6FB),
                    border: Border.all(
                      color: const Color(0xFFE0E6EE),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    widget.slide.icon,
                    size: 78.sp,
                    color: AppColors.navyBlue,
                  ),
                ),
        );
      },
    );
  }
}

class _VideoFallback extends StatelessWidget {
  final String translateLabel;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const _VideoFallback({
    required this.translateLabel,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 76.sp,
              color: const Color(0xFF98A6B7),
            ),
            SizedBox(height: 12.h),
            Text(
              translateLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF5F6E7E),
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (errorMessage != null) ...[
              SizedBox(height: 8.h),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF8A97A8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (onRetry != null) ...[
              SizedBox(height: 12.h),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text('Retry'.translate()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class OnboardingSlide {
  final String title;
  final String description;
  final IconData? icon;
  final String? videoAsset;
  final List<String> fallbackVideoAssets;
  final double videoScale;
  const OnboardingSlide({
    required this.title,
    required this.description,
    this.icon,
    this.videoAsset,
    this.fallbackVideoAssets = const [],
    this.videoScale = 1.0,
  });
}
