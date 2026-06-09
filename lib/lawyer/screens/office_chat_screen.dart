import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/services/notification_service.dart';

class OfficeChatScreen extends StatefulWidget {
  final String officeId;
  final String? chatId; // For 1-on-1 chat. Null if global group chat.
  final String chatTitle;
  final bool isGroupChat;
  final String? targetUserId; // For 1-on-1 chat. Null if group chat.

  const OfficeChatScreen({
    super.key,
    required this.officeId,
    this.chatId,
    required this.chatTitle,
    required this.isGroupChat,
    this.targetUserId,
  });

  @override
  State<OfficeChatScreen> createState() => _OfficeChatScreenState();
}

class _OfficeChatScreenState extends State<OfficeChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String _senderName = 'Office Member';

  @override
  void initState() {
    super.initState();
    _loadSenderName();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadSenderName() async {
    if (_currentUserId == null) return;
    try {
      final lawyerDoc = await FirebaseFirestore.instance
          .collection('lawyers')
          .doc(_currentUserId)
          .get();
      if (lawyerDoc.exists) {
        setState(() {
          _senderName = lawyerDoc.data()?['name'] ?? 'Office Member';
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();
      if (userDoc.exists) {
        setState(() {
          _senderName = userDoc.data()?['name'] ?? 'Office Member';
        });
      }
    } catch (_) {}
  }

  CollectionReference<Map<String, dynamic>> _getMessagesCollection() {
    final firestore = FirebaseFirestore.instance;
    if (widget.isGroupChat) {
      return firestore
          .collection('offices')
          .doc(widget.officeId)
          .collection('global_chat')
          .doc('messages_node')
          .collection('messages');
    } else {
      return firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages');
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null) return;

    _messageController.clear();
    final timestamp = FieldValue.serverTimestamp();

    try {
      // Add message to Firestore
      await _getMessagesCollection().add({
        'senderId': _currentUserId,
        'senderName': _senderName,
        'text': text,
        'timestamp': timestamp,
        'isRead': false,
      });

      // Update parent nodes if 1-on-1 chat
      if (!widget.isGroupChat && widget.chatId != null && widget.targetUserId != null) {
        final firestore = FirebaseFirestore.instance;

        await firestore.collection('chats').doc(widget.chatId).set({
          'lastMessage': text,
          'lastMessageTime': timestamp,
          'officeId': widget.officeId,
        }, SetOptions(merge: true));

        // Send push notification to the individual target user
        NotificationService().createAndSendNotification(
          targetUserId: widget.targetUserId!,
          title: _senderName,
          body: text,
          type: 'office_chat',
          referenceId: widget.chatId!,
        ).catchError((_) {});
      } else if (widget.isGroupChat) {
        // Send push notifications to all office members except current user
        final membersSnapshot = await FirebaseFirestore.instance
            .collection('offices')
            .doc(widget.officeId)
            .collection('members')
            .get();

        for (var memberDoc in membersSnapshot.docs) {
          final memberId = memberDoc.id;
          if (memberId != _currentUserId) {
            NotificationService().createAndSendNotification(
              targetUserId: memberId,
              title: '${'Office'.translate()}: ${widget.chatTitle}',
              body: '$_senderName: $text',
              type: 'office_global_chat',
              referenceId: widget.officeId,
            ).catchError((_) {});
          }
        }
      }

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFE);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20.sp,
            color: isDark ? Colors.white : AppColors.navyBlue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.chatTitle,
          style: GoogleFonts.cairo(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.navyBlue,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getMessagesCollection()
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
                      'No messages yet. Send a message to start.'.translate(),
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
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _currentUserId;
                    final text = data['text'] ?? '';
                    final time = data['timestamp'] as Timestamp?;
                    final senderName = data['senderName'] ?? 'Member';

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

                    return _buildMessageBubble(
                      text: text,
                      time: timeStr,
                      senderName: senderName,
                      isMe: isMe,
                      isDark: isDark,
                    );
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

  Widget _buildMessageBubble({
    required String text,
    required String time,
    required String senderName,
    required bool isMe,
    required bool isDark,
  }) {
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
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (widget.isGroupChat && !isMe) ...[
            Padding(
              padding: EdgeInsets.only(left: 4.w, bottom: 4.h),
              child: Text(
                senderName,
                style: GoogleFonts.cairo(
                  color: AppColors.legalGold,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: bubbleBg,
              borderRadius: borderRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: GoogleFonts.cairo(
                    color: textColor,
                    fontSize: 14.sp,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  time,
                  style: GoogleFonts.cairo(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 9.sp,
                  ),
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
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h).copyWith(
        bottom: MediaQuery.of(context).padding.bottom + 12.h,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: GoogleFonts.cairo(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Type a message...'.translate(),
                hintStyle: GoogleFonts.cairo(color: Colors.grey),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          GestureDetector(
            onTap: _sendMessage,
            child: CircleAvatar(
              radius: 24.r,
              backgroundColor: AppColors.legalGold,
              child: Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
