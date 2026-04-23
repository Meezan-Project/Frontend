import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/navigation/loading_navigator.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';

class LawyerChat {
  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final String avatar;

  const LawyerChat({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.avatar,
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
                final avatar = name.isNotEmpty ? name[0].toUpperCase() : 'L';

                return LawyerChat(
                  id: doc.id,
                  name: name,
                  lastMessage: lastMessage,
                  time: timeLabel,
                  avatar: avatar,
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
                    child: Text(
                      'No conversations found in Firebase yet.'.translate(),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: lawyers.length,
                  itemBuilder: (context, index) {
                    final lawyer = lawyers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.legalGold,
                        child: Text(
                          lawyer.avatar,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(lawyer.name),
                      subtitle: Text(lawyer.lastMessage),
                      trailing: Text(lawyer.time),
                      onTap: () {
                        LoadingNavigator.pushNamed(
                          context,
                          AppRoutes.userAiChat,
                          arguments: lawyer,
                        );
                      },
                    );
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
      appBar: AppBar(
        title: Text('Messages'.translate()),
        backgroundColor: AppColors.navyBlue,
      ),
      body: content,
    );
  }
}
