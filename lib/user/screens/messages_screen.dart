import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/user/screens/user_lawyer_chat_screen.dart';

class LawyerChat {
  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final String avatar;
  final String lawyerId;
  final int unreadCount;

  const LawyerChat({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.avatar,
    required this.lawyerId,
    required this.unreadCount,
  });
}

class MessagesScreen extends StatelessWidget {
  final bool embedded;

  const MessagesScreen({super.key, this.embedded = false});

  Stream<List<LawyerChat>> _lawyerThreadsStream(User user) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('conversations')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                final name =
                    data['lawyerName']?.toString().trim().isNotEmpty == true
                    ? data['lawyerName'].toString().trim()
                    : (data['name']?.toString().trim().isNotEmpty == true
                          ? data['name'].toString().trim()
                          : 'Lawyer');
                final lastMessage =
                    data['lastMessage']?.toString().trim().isNotEmpty == true
                    ? data['lastMessage'].toString().trim()
                    : 'No messages yet';

                final timestamp = data['updatedAt'];
                final timeLabel = _formatTimestamp(timestamp);
                final avatarRaw = data['lawyerAvatar']?.toString().trim() ?? '';
                final avatar = avatarRaw.isNotEmpty
                    ? avatarRaw
                    : (name.isNotEmpty ? name[0].toUpperCase() : 'L');
                
                final lawyerId = data['lawyerId']?.toString() ?? '';
                final unreadCount = (data['unreadCount'] as num?)?.toInt() ?? 0;

                return LawyerChat(
                  id: doc.id,
                  name: name,
                  lastMessage: lastMessage,
                  time: timeLabel,
                  avatar: avatar,
                  lawyerId: lawyerId,
                  unreadCount: unreadCount,
                );
              })
              .toList(growable: false);
        });
  }

  String _formatTimestamp(dynamic value) {
    if (value is! Timestamp) {
      return '';
    }

    final date = value.toDate();
    final now = DateTime.now();
    final isSameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (isSameDay) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final suffix = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $suffix';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
    if (isYesterday) {
      return 'Yesterday';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFE);

    final content = StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (user == null) {
          return Center(
            child: Text('Please login to view messages'.translate()),
          );
        }

        return StreamBuilder<List<LawyerChat>>(
          stream: _lawyerThreadsStream(user),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Could not load messages from Firebase.'.translate(),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final lawyers = snapshot.data ?? const <LawyerChat>[];
            if (lawyers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 48.sp,
                      color: isDark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'No messages yet.'.translate(),
                      style: GoogleFonts.cairo(
                        fontSize: 14.sp,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
              itemCount: lawyers.length,
              itemBuilder: (context, index) {
                final lawyer = lawyers[index];
                return _MessageTile(chat: lawyer, isDark: isDark);
              },
            );
          },
        );
      },
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF162235) : Colors.white,
        elevation: 1,
        centerTitle: true,
        title: Text(
          'Messages'.translate(),
          style: GoogleFonts.cairo(
            color: isDark ? Colors.white : AppColors.navyBlue,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : AppColors.navyBlue,
        ),
      ),
      body: content,
    );
  }
}

class _MessageTile extends StatelessWidget {
  final LawyerChat chat;
  final bool isDark;

  const _MessageTile({required this.chat, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardColor = chat.unreadCount > 0 
        ? (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE8F4FE)) 
        : (isDark ? const Color(0xFF1A2940) : Colors.white);
        
    final borderColor = chat.unreadCount > 0
        ? AppColors.legalGold.withOpacity(0.6)
        : (isDark ? const Color(0xFF304563) : const Color(0xFFDCE6F5));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lawyers')
          .doc(chat.lawyerId)
          .snapshots(),
      builder: (context, snapshot) {
        String lawyerName = chat.name;
        String lawyerAvatar = chat.avatar;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            final fName = data['fullName'] ?? data['name'] ?? '';
            if (fName.toString().trim().isNotEmpty) {
              lawyerName = fName.toString().trim();
            }
            final avatarRaw = (data['profilePhotoUrl'] ?? data['profile_photo'] ?? data['photoUrl'] ?? '').toString().trim();
            if (avatarRaw.isNotEmpty) {
              lawyerAvatar = avatarRaw;
            } else {
              lawyerAvatar = lawyerName.isNotEmpty ? lawyerName[0].toUpperCase() : 'L';
            }
          }
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserLawyerChatScreen(
                  chatId: chat.id,
                  lawyerName: lawyerName,
                  lawyerId: chat.lawyerId,
                  lawyerAvatar: lawyerAvatar,
                ),
              ),
            );
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
                  blurRadius: 8,
                  offset: Offset(0, 2.h),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24.r,
                  backgroundColor: AppColors.legalGold.withOpacity(0.2),
                  backgroundImage: (lawyerAvatar.startsWith('http'))
                      ? NetworkImage(lawyerAvatar)
                      : null,
                  child: (!lawyerAvatar.startsWith('http'))
                      ? Text(
                          lawyerAvatar,
                          style: GoogleFonts.cairo(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.legalGold,
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              lawyerName,
                              style: GoogleFonts.cairo(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.navyBlue,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            chat.time,
                            style: GoogleFonts.cairo(
                              fontSize: 11.sp,
                              color: chat.unreadCount > 0 ? AppColors.legalGold : Colors.grey,
                              fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              chat.lastMessage.isNotEmpty
                                  ? chat.lastMessage
                                  : 'Image or Attachment'.translate(),
                              style: GoogleFonts.cairo(
                                fontSize: 13.sp,
                                color: chat.unreadCount > 0 
                                    ? (isDark ? Colors.white : Colors.black87) 
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (chat.unreadCount > 0) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.all(6.r),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${chat.unreadCount}',
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
