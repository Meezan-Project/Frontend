import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class SosVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const SosVideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<SosVideoPlayerScreen> createState() => _SosVideoPlayerScreenState();
}

class _SosVideoPlayerScreenState extends State<SosVideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isControlsVisible = true;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      // mixWithOthers forces audio to play even if device is on Silent/Vibrate mode
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )
      ..initialize().then((_) {
        setState(() {}); // Update UI when video is ready
        _controller.setVolume(1.0); // Explicitly ensure volume is up
        _controller.play(); // Auto-play
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Toggle Play/Pause
  void _togglePlay() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  // Toggle Mute/Unmute
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  // Format Duration (e.g., 01:23)
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Cinematic black background
      body: GestureDetector(
        onTap: () {
          // Show/Hide controls when tapping the screen
          setState(() {
            _isControlsVisible = !_isControlsVisible;
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Video Player
            Center(
              child: _controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const CircularProgressIndicator(
                      color: AppColors.legalGold,
                    ),
            ),

            // 2. Top Gradient & Back Button (Custom AppBar)
            AnimatedOpacity(
              opacity: _isControlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: 100.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3. Bottom Controls (Play, Slider, Time, Volume)
            if (_controller.value.isInitialized)
              AnimatedOpacity(
                opacity: _isControlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: EdgeInsets.only(bottom: 30.h, left: 20.w, right: 20.w, top: 40.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress Bar
                        VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: AppColors.legalGold,
                            bufferedColor: Colors.white54,
                            backgroundColor: Colors.white24,
                          ),
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                        ),
                        SizedBox(height: 10.h),

                        // Controls Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Play/Pause Button
                            GestureDetector(
                              onTap: _togglePlay,
                              child: Icon(
                                _controller.value.isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_filled_rounded,
                                color: Colors.white,
                                size: 40.sp,
                              ),
                            ),
                            SizedBox(width: 16.w),

                            // Time Indicator
                            ValueListenableBuilder(
                              valueListenable: _controller,
                              builder: (context, VideoPlayerValue value, child) {
                                return Text(
                                  "${_formatDuration(value.position)} / ${_formatDuration(value.duration)}",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),

                            const Spacer(),

                            // Volume/Mute Button
                            GestureDetector(
                              onTap: _toggleMute,
                              child: Icon(
                                _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                color: Colors.white,
                                size: 28.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}