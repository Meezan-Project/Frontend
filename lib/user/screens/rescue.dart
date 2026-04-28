import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class RescueScreen extends StatefulWidget {
  const RescueScreen({super.key});

  @override
  State<RescueScreen> createState() => _RescueScreenState();
}

class _RescueScreenState extends State<RescueScreen> {
  // Sample lawyer offers data
  final List<LawyerOfferArabic> offers = [
    LawyerOfferArabic(
      id: 1,
      lawyerName: 'المحامي أحمد محمد',
      specialization: 'قانون شركات',
      rating: 4.8,
      reviewCount: 142,
      priceEGP: 887,
      estimatedTimeMinutes: 10,
      imageUrl: 'https://via.placeholder.com/100',
    ),
    LawyerOfferArabic(
      id: 2,
      lawyerName: 'المحامية فاطمة علي',
      specialization: 'قانون العائلة',
      rating: 4.6,
      reviewCount: 98,
      priceEGP: 650,
      estimatedTimeMinutes: 15,
      imageUrl: 'https://via.placeholder.com/100',
    ),
    LawyerOfferArabic(
      id: 3,
      lawyerName: 'المحامي محمود إبراهيم',
      specialization: 'قانون جنائي',
      rating: 4.9,
      reviewCount: 210,
      priceEGP: 1200,
      estimatedTimeMinutes: 5,
      imageUrl: 'https://via.placeholder.com/100',
    ),
    LawyerOfferArabic(
      id: 4,
      lawyerName: 'المحامي خالد سالم',
      specialization: 'قانون العقارات',
      rating: 4.5,
      reviewCount: 76,
      priceEGP: 750,
      estimatedTimeMinutes: 20,
      imageUrl: 'https://via.placeholder.com/100',
    ),
    LawyerOfferArabic(
      id: 5,
      lawyerName: 'المحامية سارة حسن',
      specialization: 'قانون العمل',
      rating: 4.7,
      reviewCount: 165,
      priceEGP: 920,
      estimatedTimeMinutes: 8,
      imageUrl: 'https://via.placeholder.com/100',
    ),
  ];

  Set<int> declinedOffers = {};

  void _acceptOffer(LawyerOfferArabic offer) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم قبول العرض من ${offer.lawyerName}',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50).withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _declineOffer(int offerId) {
    setState(() {
      declinedOffers.add(offerId);
    });
  }

  void _cancelRequest() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'إلغاء الطلب',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟ سيتعين عليك تقديم طلب جديد لاحقاً.',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'لا',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم إلغاء الطلب',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: Colors.grey[700],
                ),
              );
            },
            child: Text(
              'نعم، إلغاء',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE53935),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableOffers = offers
        .where((offer) => !declinedOffers.contains(offer.id))
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Column(
              children: [
                // Top Bar with Title and Back Button
                SafeArea(
                  child: Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(
                            Icons.arrow_back_ios_rounded,
                            size: 24.sp,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Text(
                            'العروض من المحامين',
                            style: GoogleFonts.cairo(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                            textAlign: TextAlign.start,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE0E0E0)),
                // Offers List
                Expanded(
                  child: availableOffers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_rounded,
                                size: 64.sp,
                                color: Colors.grey[300],
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                'لا توجد عروض متاحة',
                                style: GoogleFonts.cairo(
                                  fontSize: 16.sp,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 120.h),
                          itemCount: availableOffers.length,
                          itemBuilder: (context, index) {
                            final offer = availableOffers[index];
                            return _OfferCard(
                              offer: offer,
                              onAccept: () => _acceptOffer(offer),
                              onDecline: () => _declineOffer(offer.id),
                            );
                          },
                        ),
                ),
              ],
            ),
            // Bottom Sticky Panel
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomStickyPanel(onCancelRequest: _cancelRequest),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final LawyerOfferArabic offer;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _OfferCard({
    required this.offer,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Price
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${offer.priceEGP} EGP',
                style: GoogleFonts.cairo(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
            SizedBox(height: 12.h),
            // Middle Row: Lawyer Info and Time
            Row(
              children: [
                // Lawyer Avatar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: Container(
                    width: 60.w,
                    height: 60.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6F9),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Image.network(
                      offer.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          Icons.person_rounded,
                          size: 32.sp,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                // Lawyer Details (expanded to avoid overflow)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.lawyerName,
                        style: GoogleFonts.cairo(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        offer.specialization,
                        style: GoogleFonts.cairo(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 14.sp,
                            color: const Color(0xFFFFC107),
                          ),
                          SizedBox(width: 4.w),
                          Flexible(
                            child: Text(
                              '${offer.rating} (${offer.reviewCount})',
                              style: GoogleFonts.cairo(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            // Estimated Time
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14.sp,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    '${offer.estimatedTimeMinutes} دقائق',
                    style: GoogleFonts.cairo(
                      fontSize: 12.sp,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),
            // Bottom Row: Action Buttons (using Expanded to prevent overflow)
            Row(
              children: [
                // Decline Button
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFF9AAAC8),
                        width: 1.5,
                      ),
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Text(
                      'رفض',
                      style: GoogleFonts.cairo(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                // Accept Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'قبول',
                      style: GoogleFonts.cairo(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomStickyPanel extends StatelessWidget {
  final VoidCallback onCancelRequest;

  const _BottomStickyPanel({required this.onCancelRequest});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: const Color(0xFFE0E0E0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Information Card
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: const Color(0xFFFFE082), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_rounded,
                      size: 20.sp,
                      color: const Color(0xFFF57F17),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'اقبل العرض المناسب. لتلقي عرض جديد، يرجى رفض أي عرض حالي.',
                        style: GoogleFonts.cairo(
                          fontSize: 12.sp,
                          color: const Color(0xFF5D4037),
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onCancelRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'إلغاء الطلب',
                    style: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LawyerOfferArabic {
  final int id;
  final String lawyerName;
  final String specialization;
  final double rating;
  final int reviewCount;
  final double priceEGP;
  final int estimatedTimeMinutes;
  final String imageUrl;

  LawyerOfferArabic({
    required this.id,
    required this.lawyerName,
    required this.specialization,
    required this.rating,
    required this.reviewCount,
    required this.priceEGP,
    required this.estimatedTimeMinutes,
    required this.imageUrl,
  });
}
