import 'dart:async'; // مهمة عشان الـ Timer
import 'package:flutter/material.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
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
    final activeSlide = slides[_currentPage];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // 1. بانر علوي أصغر يحتوي النص
            Container(
              height: size.height * 0.25,
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
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
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -35,
                    right: -24,
                    child: Container(
                      width: 120,
                      height: 120,
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
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.legalGold.withOpacity(0.18),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            activeSlide.title,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.06,
                              letterSpacing: 0.4,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.22),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            activeSlide.description,
                            style: TextStyle(
                              fontSize: 15,
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
                ],
              ),
            ),

            // 2. المساحة البيضاء للميديا فقط
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
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
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: _currentPage == index ? 35 : 12,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.legalGold
                              : const Color(0xFFD7DEE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
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
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: SizedBox(
                          height: 56,
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
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Register',
                              style: TextStyle(
                                fontSize: 17,
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
                      const Icon(
                        Icons.video_call_outlined,
                        size: 80,
                        color: Color(0xFF9BA8B8),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Video could not be loaded',
                        style: TextStyle(
                          color: Color(0xFF6E7B8B),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_videoErrorMessage != null) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
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
                ? const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.navyBlue,
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                  ))
          : Container(
              width: 165,
              height: 165,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF2F6FB),
                border: Border.all(color: const Color(0xFFE0E6EE), width: 1.2),
              ),
              child: Icon(
                widget.slide.icon,
                size: 78,
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
