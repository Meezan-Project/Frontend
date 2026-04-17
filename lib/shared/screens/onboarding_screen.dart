import 'dart:async'; // مهمة عشان الـ Timer
import 'package:flutter/material.dart';
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

  final List<OnboardingSlide> slides = [
    OnboardingSlide(
      title: 'Video Call with Lawyer',
      description:
          'Connect with legal experts via high-quality video calls safely and privately.',
      videoAsset: 'assets/videos/onboarding_lawer_call.mp4',
    ),
    OnboardingSlide(
      title: 'Book Appointments',
      description:
          'Schedule your meetings with top-rated lawyers easily through our app.',
      icon: Icons.calendar_today,
    ),
    OnboardingSlide(
      title: 'Free AI Consultation',
      description:
          'Get instant legal advice for free through our advanced AI assistant.',
      icon: Icons.smart_toy,
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

    // تشغيل الـ Auto-Slide كل 5 ثواني
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_currentPage < slides.length - 1) {
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
      final activeSlide = slides[_currentPage];
      localizationController.currentLanguage.value;

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
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 10.h),
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
                    itemCount: slides.length,
                    itemBuilder: (context, index) {
                      return OnboardingSlideWidget(slide: slides[index]);
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
                        slides.length,
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
      _videoController = VideoPlayerController.asset(widget.slide.videoAsset!)
        ..setLooping(true)
        ..setVolume(0)
        ..initialize()
            .then((_) {
              if (mounted) setState(() {});
              _videoController?.play();
            })
            .catchError((error) {
              if (mounted) {
                setState(() {
                  _videoLoadFailed = true;
                  _videoErrorMessage = error.toString();
                });
              }
            });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: widget.slide.videoAsset != null
          ? (_videoLoadFailed
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.video_call_outlined,
                        size: 80.sp,
                        color: Color(0xFF9BA8B8),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'Video could not be loaded'.translate(),
                        style: TextStyle(
                          color: Color(0xFF6E7B8B),
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_videoErrorMessage != null) ...[
                        SizedBox(height: 8.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          child: Text(
                            _videoErrorMessage!,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF8A97A8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                : (_videoController == null ||
                      !_videoController!.value.isInitialized)
                ? SizedBox(
                    width: 34.w,
                    height: 34.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.navyBlue,
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(24.r),
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                  ))
          : Container(
              width: 165.w,
              height: 165.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF2F6FB),
                border: Border.all(color: const Color(0xFFE0E6EE), width: 1.2),
              ),
              child: Icon(
                widget.slide.icon,
                size: 78.sp,
                color: AppColors.navyBlue,
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
  OnboardingSlide({
    required this.title,
    required this.description,
    this.icon,
    this.videoAsset,
  });
}
