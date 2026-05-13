import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class ReviewSubmissionSheet extends StatefulWidget {
  final String lawyerId;
  final VoidCallback? onReviewSubmitted;

  const ReviewSubmissionSheet({
    super.key,
    required this.lawyerId,
    this.onReviewSubmitted,
  });

  /// Helper method to trigger the bottom sheet easily from any screen
  static Future<void> show(BuildContext context, String lawyerId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ReviewSubmissionSheet(lawyerId: lawyerId),
      ),
    );
  }

  @override
  State<ReviewSubmissionSheet> createState() => _ReviewSubmissionSheetState();
}

class _ReviewSubmissionSheetState extends State<ReviewSubmissionSheet> {
  double _rating = 5.0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to submit a review.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final db = FirebaseFirestore.instance;
    final lawyerRef = db.collection('lawyers').doc(widget.lawyerId);
    final reviewRef = lawyerRef.collection('reviews').doc();

    try {
      await db.runTransaction((transaction) async {
        // 1. Read the current lawyer document to get existing rating stats
        final lawyerDoc = await transaction.get(lawyerRef);

        double currentAvgRating = 0.0;
        int reviewCount = 0;

        if (lawyerDoc.exists && lawyerDoc.data() != null) {
          final data = lawyerDoc.data()!;
          currentAvgRating = (data['rating'] ?? 0.0).toDouble();
          reviewCount = (data['reviewCount'] ?? 0).toInt();
        }

        // 2. Calculate the new average rating
        double newRating =
            ((currentAvgRating * reviewCount) + _rating) / (reviewCount + 1);

        // 3. Write the new review document into the sub-collection
        transaction.set(reviewRef, {
          'userId': user.uid,
          'lawyerId': widget.lawyerId,
          'rating': _rating,
          'comment': _commentController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 4. Update the lawyer's root document with the newly calculated stats
        transaction.set(lawyerRef, {
          'rating': newRating,
          'reviewCount': reviewCount + 1,
        }, SetOptions(merge: true));
      });

      if (mounted) {
        Navigator.of(context).pop(); // Close the sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onReviewSubmitted?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rate your experience',
            style: GoogleFonts.cairo(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : AppColors.navyBlue,
            ),
          ),
          SizedBox(height: 20.h),
          Center(
            child: RatingBar.builder(
              initialRating: _rating,
              minRating: 0.5,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemPadding: EdgeInsets.symmetric(horizontal: 4.w),
              itemBuilder: (context, _) =>
                  const Icon(Icons.star_rounded, color: Colors.amber),
              onRatingUpdate: (rating) {
                setState(() => _rating = rating);
              },
            ),
          ),
          SizedBox(height: 24.h),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Write an optional review...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(
                  color: AppColors.legalGold,
                  width: 2,
                ),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            height: 54.h,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.legalGold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 24.w,
                      height: 24.h,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Submit Review',
                      style: GoogleFonts.cairo(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
