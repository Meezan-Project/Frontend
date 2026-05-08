import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class SosVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const SosVideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<SosVideoPlayerScreen> createState() => _SosVideoPlayerScreenState();
}

class _SosVideoPlayerScreenState extends State<SosVideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize()
          .then((_) {
            setState(() {});
            _controller.play();
          })
          .catchError((error) {
            setState(() {
              _isError = true;
              _errorMessage = error.toString();
            });
            debugPrint("Video Player Error: $error");
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'SOS Evidence Video',
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
      ),
      body: Center(
        child: _isError
            ? Text(
                'Error loading video\n$_errorMessage',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontSize: 14.sp),
              )
            : _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(color: AppColors.legalGold),
      ),
      floatingActionButton: _controller.value.isInitialized
          ? FloatingActionButton(
              backgroundColor: AppColors.navyBlue,
              onPressed: () => setState(
                () => _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play(),
              ),
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}
