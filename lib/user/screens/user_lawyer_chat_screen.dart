import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/services/notification_service.dart';

class UserLawyerChatScreen extends StatefulWidget {
  final String chatId;
  final String lawyerName;
  final String lawyerId;
  final String? lawyerAvatar;

  const UserLawyerChatScreen({
    super.key,
    required this.chatId,
    required this.lawyerName,
    required this.lawyerId,
    this.lawyerAvatar,
  });

  @override
  State<UserLawyerChatScreen> createState() => _UserLawyerChatScreenState();
}

class _UserLawyerChatScreenState extends State<UserLawyerChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  StreamSubscription? _unreadSub;
  StreamSubscription? _messagesSub;

  @override
  void initState() {
    super.initState();
    if (_currentUserId != null) {
      _unreadSub = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('conversations')
          .doc(widget.chatId)
          .snapshots()
          .listen((doc) {
            if (doc.exists && (doc.data()?['unreadCount'] ?? 0) > 0) {
              doc.reference.update({'unreadCount': 0}).catchError((_) {});
            }
          });

      _messagesSub = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: _currentUserId)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
            for (var doc in snapshot.docs) {
              doc.reference.update({'isRead': true}).catchError((_) {});
            }
          });
    }
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    _messagesSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null) return;

    _messageController.clear();

    final timestamp = FieldValue.serverTimestamp();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
          'senderId': _currentUserId,
          'text': text,
          'timestamp': timestamp,
          'isRead': false,
        });

    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set(
      {'lastMessage': text, 'lastMessageTime': timestamp},
      SetOptions(merge: true),
    );

    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('conversations')
        .doc(widget.chatId)
        .set({
          'lastMessage': text,
          'updatedAt': timestamp,
          'unreadCount': 0,
        }, SetOptions(merge: true));

    if (widget.lawyerId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('lawyers')
          .doc(widget.lawyerId)
          .collection('conversations')
          .doc(widget.chatId)
          .set({
            'lastMessage': text,
            'updatedAt': timestamp,
            'unreadCount': FieldValue.increment(1),
          }, SetOptions(merge: true));

      // Fetch client's name for notification
      String clientName = 'Client'.translate();
      try {
        final clientDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .get();
        if (clientDoc.exists) {
          clientName = clientDoc.data()?['name'] ?? clientDoc.data()?['fullName'] ?? 'Client'.translate();
        }
      } catch (_) {}

      // Send push and in-app notification to the lawyer
      NotificationService().createAndSendNotification(
        targetUserId: widget.lawyerId,
        title: clientName,
        body: text,
        type: 'chat',
        referenceId: widget.chatId,
      ).catchError((e) {
        debugPrint('Failed to trigger chat notification: $e');
      });
    }

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFE);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF162235) : Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20.sp,
            color: isDark ? Colors.white : AppColors.navyBlue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18.r,
              backgroundColor: AppColors.legalGold.withOpacity(0.2),
              backgroundImage:
                  (widget.lawyerAvatar != null &&
                      widget.lawyerAvatar!.startsWith('http'))
                  ? NetworkImage(widget.lawyerAvatar!)
                  : null,
              child:
                  (widget.lawyerAvatar == null ||
                      !widget.lawyerAvatar!.startsWith('http'))
                  ? Text(
                      widget.lawyerAvatar ?? 'L',
                      style: GoogleFonts.cairo(
                        color: AppColors.legalGold,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                widget.lawyerName,
                style: GoogleFonts.cairo(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.navyBlue,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Send a message to your lawyer.'
                          .translate(),
                      style: GoogleFonts.cairo(
                        color: Colors.grey,
                        fontSize: 14.sp,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 16.h,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _currentUserId;
                    final text = data['text'] ?? '';
                    final time = data['timestamp'] as Timestamp?;
                    final isRead = data['isRead'] ?? false;
                    final isSending = time == null;

                    String timeStr = '';
                    if (time != null) {
                      final dt = time.toDate();
                      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
                      final minute = dt.minute.toString().padLeft(2, '0');
                      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
                      timeStr = '$hour:$minute $amPm';
                    } else {
                      timeStr = 'Sending...'.translate();
                    }

                    return _buildMessageBubble(text, timeStr, isMe, isDark, isRead, isSending);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(isDark),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(bool isRead, bool isSending, bool isDark) {
    if (isSending) {
      return Icon(
        Icons.access_time_rounded,
        size: 11.sp,
        color: isDark ? Colors.white54 : Colors.black45,
      );
    }
    
    final color = isRead 
        ? Colors.blueAccent 
        : (isDark ? Colors.white54 : Colors.black45);
        
    return Icon(
      Icons.done_all_rounded,
      size: 14.sp,
      color: color,
    );
  }

  Widget _buildMessageBubble(
      String text, String time, bool isMe, bool isDark, bool isRead, bool isSending) {
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleBg = isMe
        ? (isDark ? const Color(0xFF0F3A5F) : const Color(0xFFE3F2FD)) 
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));
        
    final textColor = isMe 
        ? (isDark ? Colors.white : const Color(0xFF0D2345))
        : (isDark ? Colors.white : Colors.black87);
        
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(16.r),
      topRight: Radius.circular(16.r),
      bottomLeft: isMe ? Radius.circular(16.r) : Radius.circular(4.r),
      bottomRight: isMe ? Radius.circular(4.r) : Radius.circular(16.r),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: bubbleBg,
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.05 : 0.02),
                  blurRadius: 3,
                  offset: Offset(0, 1.h),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: GoogleFonts.cairo(
                    color: textColor,
                    fontSize: 14.5.sp,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: GoogleFonts.cairo(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 10.sp,
                      ),
                    ),
                    if (isMe) ...[
                      SizedBox(width: 4.w),
                      _buildStatusIcon(isRead, isSending, isDark),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: 12.h,
      ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 12.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162235) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -4.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: GoogleFonts.cairo(
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Type a message...'.translate(),
                hintStyle: GoogleFonts.cairo(color: Colors.grey),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F1419) : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.r),
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
            onTap: _sendMessage,
            child: CircleAvatar(
              radius: 24.r,
              backgroundColor: AppColors.legalGold,
              child: Icon(Icons.send_rounded, color: Colors.white, size: 20.sp),
            ),
          ),
        ],
      ),
    );
  }
}
