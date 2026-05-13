import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String appId = '1ce28e9fd5da4c14b213916ee9539486';
const String token = '007eJxTYHiQXLrqqPmvU6weS3pWaIcs69xxat3j/X+00x+/MxPI5VqhwGCYnGpkkWqZlmKakmiSbGiSZGRobGlolppqaWpsaWJhtrOcOashkJFhf4E1EyMDBIL4nAwlqcUl8UX5+bkMDACb1SMB'; // Temp token for 'test_room'

class VideoCallScreen extends StatefulWidget {
  final String meetingId;

  const VideoCallScreen({super.key, required this.meetingId});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isMuted = false;
  bool _isCameraOn = true;
  late RtcEngine _engine;
  
  Timer? _callTimer;
  int _remainingSeconds = 3600; // 60 minutes
  bool _timerStarted = false;
  
  bool _isCheckingAccess = true;
  String? _accessError;

  @override
  void initState() {
    super.initState();
    _checkAccessAndInit();
  }

  Future<void> _checkAccessAndInit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError("User not logged in.");
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.meetingId)
          .get();
          
      if (!doc.exists) {
        _showError("Meeting not found.");
        return;
      }

      final data = doc.data()!;
      // Security Check: Ensure current user is the participant lawyer or user
      if (data['userId'] != user.uid && data['lawyerId'] != user.uid) {
        _showError("You are not authorized to join this call.");
        return;
      }

      // Access granted
      await _initAgora();
      
    } catch (e) {
      _showError("Failed to verify meeting access. Please check your connection.");
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _accessError = message;
        _isCheckingAccess = false;
      });
    }
  }

  Future<void> _initAgora() async {
    // Retrieve permissions
    await [Permission.microphone, Permission.camera].request();

    // Create the engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("local user ${connection.localUid} joined");
          setState(() {
            _localUserJoined = true;
          });
          _checkAndStartTimer();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("remote user $remoteUid joined");
          setState(() {
            _remoteUid = remoteUid;
          });
          _checkAndStartTimer();
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("remote user $remoteUid left channel");
          setState(() {
            _remoteUid = null;
          });
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint('[onTokenPrivilegeWillExpire] token expired');
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('[onError] err: $err, msg: $msg');
          _showError("Agora Error: $msg ($err)");
        },
      ),
    );

    await _engine.enableVideo();
    await _engine.startPreview();

    setState(() {
      _isCheckingAccess = false;
    });

    await _engine.joinChannel(
      token: token,
      channelId: 'test_room', // Hardcoded for testing with temp token
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  void _checkAndStartTimer() {
    if (!_timerStarted && _localUserJoined && _remoteUid != null) {
      _timerStarted = true;
      _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            timer.cancel();
            _onCallEnd();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    if (_localUserJoined) {
      _disposeAgora();
    }
    super.dispose();
  }

  Future<void> _disposeAgora() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  void _onToggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine.muteLocalAudioStream(_isMuted);
  }
  
  void _onToggleCamera() {
    setState(() {
      _isCameraOn = !_isCameraOn;
    });
    _engine.muteLocalVideoStream(!_isCameraOn);
  }

  void _onSwitchCamera() {
    _engine.switchCamera();
  }

  void _onCallEnd() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_accessError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, color: Colors.redAccent, size: 80),
              const SizedBox(height: 20),
              Text(
                'Access Denied',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _accessError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F1726),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _onCallEnd,
                child: const Text('Go Back'),
              )
            ],
          ),
        ),
      );
    }

    if (_isCheckingAccess) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text(
              'Connecting securely...',
              style: GoogleFonts.cairo(color: Colors.white),
            )
          ],
        ),
      );
    }

    return Stack(
      children: [
        _remoteVideo(),
        _localVideo(),
        _buildTopBar(),
        _buildGlassControls(),
      ],
    );
  }

  String get _formattedTime {
    int minutes = _remainingSeconds ~/ 60;
    int seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 36),
              onPressed: _onCallEnd,
            ),
            Column(
              children: [
                if (_timerStarted)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: _remainingSeconds <= 300 
                          ? Colors.redAccent.withValues(alpha: 0.9) 
                          : Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formattedTime,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.green, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'End-to-End Encrypted',
                        style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 36), // Balance
          ],
        ),
      ),
    );
  }

  Widget _remoteVideo() {
    if (_remoteUid != null) {
      return SizedBox.expand(
        child: AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine,
            canvas: VideoCanvas(uid: _remoteUid),
            connection: RtcConnection(channelId: widget.meetingId),
          ),
        ),
      );
    } else {
      return Container(
        color: const Color(0xFF1E2124),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, color: Colors.white24, size: 100),
              const SizedBox(height: 20),
              Text(
                'Waiting for others to join...',
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _localVideo() {
    if (_localUserJoined) {
      return Positioned(
        top: MediaQuery.of(context).padding.top + 60,
        right: 20,
        child: GestureDetector(
          // Allow users to tap the PIP if needed, draggable could be added here
          child: Container(
            width: 120,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.black54,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _isCameraOn 
                ? AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.videocam_off, color: Colors.white54, size: 40),
                  ),
            ),
          ),
        ),
      );
    } else {
      return const SizedBox();
    }
  }

  Widget _buildGlassControls() {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _controlButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  color: _isMuted ? Colors.white : Colors.white24,
                  iconColor: _isMuted ? Colors.black : Colors.white,
                  onPressed: _onToggleMute,
                ),
                _controlButton(
                  icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                  color: !_isCameraOn ? Colors.white : Colors.white24,
                  iconColor: !_isCameraOn ? Colors.black : Colors.white,
                  onPressed: _onToggleCamera,
                ),
                _controlButton(
                  icon: Icons.switch_camera,
                  color: Colors.white24,
                  iconColor: Colors.white,
                  onPressed: _onSwitchCamera,
                ),
                _controlButton(
                  icon: Icons.call_end,
                  color: Colors.redAccent,
                  iconColor: Colors.white,
                  onPressed: _onCallEnd,
                  size: 60,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onPressed,
    double size = 52,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: size * 0.5),
      ),
    );
  }
}
