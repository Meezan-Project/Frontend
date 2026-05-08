import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mezaan/shared/widgets/responsive_base_layout.dart';
import 'package:mezaan/user/screens/sos_video_player_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class SosRequestsScreen extends StatelessWidget {
  const SosRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return ResponsiveBaseLayout(
      title: 'SOS Evidence History',
      scrollable: false,
      child: currentUser == null
          ? const Center(child: Text('User not logged in.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sos_requests')
                  .where('userId', isEqualTo: currentUser.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No SOS alerts found.',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (_, _) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final timestamp = data['timestamp'] as Timestamp?;
                    final dateLabel = timestamp != null
                        ? DateFormat(
                            'MMM d, yyyy - h:mm a',
                          ).format(timestamp.toDate())
                        : 'Unknown Date';

                    final duration = data['duration'] ?? 0;
                    final String durationLabel = duration > 60
                        ? '${(duration / 60).toStringAsFixed(1)} min'
                        : '$duration sec';

                    return ResponsiveCard(
                      padding: EdgeInsets.all(16.r),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_rounded,
                            color: Colors.red[700],
                            size: 36.sp,
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15.sp,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Duration: $durationLabel • Status: ${data['status']}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.download_rounded,
                              color: Colors.green,
                            ),
                            onPressed: () async {
                              final videoUrl = data['videoUrl'] as String;
                              // Adding ?download= helps trigger a file download instead of browser playback
                              final url = Uri.parse(videoUrl.contains('?') ? '$videoUrl&download=' : '$videoUrl?download=');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Could not download video')),
                                  );
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.blue,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SosVideoPlayerScreen(videoUrl: data['videoUrl']),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
