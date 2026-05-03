import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/theme/app_spacing.dart';
import 'package:mezaan/shared/theme/app_typography.dart';
import 'package:mezaan/shared/widgets/responsive_base_layout.dart';

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBaseLayout(
      title: 'Transaction History',
      backgroundColor: const Color(0xFFF4F7FB),
      customPadding: AppSpacing.screenPadding(context),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Padding(
                padding: EdgeInsets.only(top: 100.h),
                child: const CircularProgressIndicator(
                  color: AppColors.navyBlue,
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.only(top: 100.h),
                child: Text(
                  'Something went wrong loading transactions.',
                  style: AppTypography.bodyMedium(
                    context,
                  ).copyWith(color: Colors.red),
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs.toList() ?? [];

          // Sort locally to show the newest transactions first
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.only(top: 100.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 64.w,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: AppSpacing.md.h),
                    Text(
                      'No transactions yet',
                      style: AppTypography.bodyLarge(context).copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (context, index) =>
                SizedBox(height: AppSpacing.md.h),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
              final type = data['type'] as String? ?? 'payment';
              final description =
                  data['description'] as String? ?? 'Transaction';
              final isWallet = data['isWalletTransaction'] as bool? ?? false;
              final createdAt = data['createdAt'] as Timestamp?;
              // Generate a short transaction ID from the document ID
              final transactionId = docs[index].id.toUpperCase().substring(
                0,
                8,
              );

              final isDeposit = amount > 0 || type == 'deposit';

              String dateString = 'Pending...';
              if (createdAt != null) {
                dateString = DateFormat(
                  'dd MMM yyyy, hh:mm a',
                  'en',
                ).format(createdAt.toDate());
              }

              return Container(
                padding: AppSpacing.cardPadding(context),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8.r,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10.r),
                                decoration: BoxDecoration(
                                  color: isDeposit
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isDeposit
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  color: isDeposit ? Colors.green : Colors.red,
                                  size: 20.sp,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isDeposit ? 'Deposit' : 'Payment',
                                      style: AppTypography.bodyMedium(context)
                                          .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.navyBlue,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      dateString,
                                      style: AppTypography.caption(context),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '${isDeposit ? '+' : ''}${amount.toStringAsFixed(2)} EGP',
                          style: AppTypography.bodyLarge(context).copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDeposit ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      child: Divider(color: Colors.grey.shade200, height: 1),
                    ),
                    _buildDetailRow(
                      context,
                      'Transaction ID',
                      '#$transactionId',
                    ),
                    SizedBox(height: 8.h),
                    _buildDetailRow(context, 'Description', description),
                    SizedBox(height: 8.h),
                    _buildDetailRow(
                      context,
                      'Payment Method',
                      isWallet ? 'Mezaan Wallet' : 'Credit/Debit Card',
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

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: AppTypography.caption(context)),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: AppTypography.bodyMedium(
              context,
            ).copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
