import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class LawyerChatScreen extends StatefulWidget {
  final String chatId;
  final String clientName;
  final String clientId;
  final String? clientImage;

  const LawyerChatScreen({
    super.key,
    required this.chatId,
    required this.clientName,
    required this.clientId,
    this.clientImage,
  });

  @override
  State<LawyerChatScreen> createState() => _LawyerChatScreenState();
}

class _LawyerChatScreenState extends State<LawyerChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null) return;

    _messageController.clear();

    final timestamp = FieldValue.serverTimestamp();

    // Add message to subcollection
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

    // Update the parent chat document with the latest message
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .set({
      'lastMessage': text,
      'lastMessageTime': timestamp,
    }, SetOptions(merge: true));

    // Update the user's conversation node for the Messages list screen
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.clientId)
        .collection('conversations')
        .doc(widget.chatId)
        .set({
      'lastMessage': text,
      'updatedAt': timestamp,
    }, SetOptions(merge: true));

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
              backgroundColor: AppColors.navyBlue.withOpacity(0.1),
              backgroundImage: (widget.clientImage != null &&
                      widget.clientImage!.isNotEmpty)
                  ? NetworkImage(widget.clientImage!)
                  : null,
              child: (widget.clientImage == null || widget.clientImage!.isEmpty)
                  ? Icon(Icons.person, color: AppColors.navyBlue, size: 20.sp)
                  : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                widget.clientName,
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
                      'No messages yet. Send a message to start the conversation.'
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
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _currentUserId;
                    final text = data['text'] ?? '';
                    final time = data['timestamp'] as Timestamp?;

                    String timeStr = '';
                    if (time != null) {
                      final dt = time.toDate();
                      timeStr =
                          '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                    }

                    return _buildMessageBubble(text, timeStr, isMe, isDark);
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

  Widget _buildMessageBubble(
      String text, String time, bool isMe, bool isDark) {
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isMe
        ? AppColors.navyBlue
        : (isDark ? const Color(0xFF1E293B) : Colors.white);
    final textColor =
        isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);
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
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: borderRadius,
              boxShadow: [
                if (!isMe && !isDark)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: Offset(0, 2.h),
                  ),
              ],
            ),
            child: Text(
              text,
              style: GoogleFonts.cairo(
                color: textColor,
                fontSize: 14.sp,
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            time,
            style: GoogleFonts.cairo(
              color: Colors.grey,
              fontSize: 10.sp,
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
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
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