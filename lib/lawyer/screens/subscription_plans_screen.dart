import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/user/widgets/subscription_badge_widget.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  bool _isLoading = false;

  void _upgradePlan(String tier) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User session not found. Please log in.'.translate())),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final expiryDate = DateTime.now().add(const Duration(days: 30));
      await FirebaseFirestore.instance.collection('lawyers').doc(uid).update({
        'subscriptionTier': tier,
        'subscriptionExpiryDate': Timestamp.fromDate(expiryDate),
      });

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      _showSuccessDialog(tier);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Error updating subscription:'.translate()} $e')),
      );
    }
  }

  void _showCheckoutDialog(String tier, double price) {
    String selectedMethod = 'card'; // 'card' or 'wallet'
    final cardNoController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();
    final phoneController = TextEditingController(text: '+20 ');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;

            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              title: Column(
                children: [
                  Text(
                    'Checkout'.translate(),
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.sp,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${'Plan:'.translate()} ${tier.toUpperCase()}',
                    style: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      color: AppColors.legalGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'EGP $price / ${'month'.translate()}',
                    style: GoogleFonts.cairo(
                      fontSize: 12.sp,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Text('Credit Card'.translate()),
                            selected: selectedMethod == 'card',
                            onSelected: (val) {
                              if (val) setDialogState(() => selectedMethod = 'card');
                            },
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: ChoiceChip(
                            label: Text('Smart Wallet'.translate()),
                            selected: selectedMethod == 'wallet',
                            onSelected: (val) {
                              if (val) setDialogState(() => selectedMethod = 'wallet');
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    if (selectedMethod == 'card') ...[
                      TextField(
                        controller: cardNoController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Card Number'.translate(),
                          hintText: '1234 5678 9012 3456',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: expiryController,
                              keyboardType: TextInputType.datetime,
                              decoration: InputDecoration(
                                labelText: 'MM/YY'.translate(),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: TextField(
                              controller: cvvController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'CVV'.translate(),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number'.translate(),
                          hintText: '+20 11XXXXXXXX',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'.translate(), style: const TextStyle(color: Colors.grey)),
                ),
                FilledButton(
                  onPressed: () {
                    // Validations
                    if (selectedMethod == 'card') {
                      if (cardNoController.text.trim().isEmpty ||
                          expiryController.text.trim().isEmpty ||
                          cvvController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please fill all card details.'.translate())),
                        );
                        return;
                      }
                    } else {
                      final phone = phoneController.text.trim();
                      if (phone.isEmpty || phone.length < 11) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please enter a valid phone number.'.translate())),
                        );
                        return;
                      }
                    }
                    Navigator.pop(context);
                    _upgradePlan(tier);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navyBlue,
                  ),
                  child: Text('Pay & Subscribe'.translate()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog(String tier) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;

        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80.w,
                height: 80.h,
                decoration: BoxDecoration(
                  color: AppColors.legalGold.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.legalGold,
                  size: 54.sp,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Subscribed Successfully!'.translate(),
                style: GoogleFonts.cairo(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyBlue,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10.h),
              Text(
                '${'You are now on'.translate()} ${tier.toUpperCase()} ${'plan. Enjoy the premium benefits!'.translate()}',
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navyBlue,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Awesome!'.translate(),
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFFCFDFF),
      appBar: AppBar(
        title: Text(
          'SaaS Subscriptions'.translate(),
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w800,
            fontSize: 18.sp,
            color: AppColors.navyBlue,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.navyBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: uid == null
          ? Center(child: Text('Please log in first.'.translate()))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('lawyers').doc(uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
                  return Center(child: Text('Lawyer profile not found.'.translate()));
                }

                final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                final currentTier = data['subscriptionTier']?.toString().toLowerCase() ?? 'basic';
                final expiryTimestamp = data['subscriptionExpiryDate'] as Timestamp?;
                final expiryDate = expiryTimestamp?.toDate();
                final isExpired = expiryDate != null && expiryDate.isBefore(DateTime.now());
                final activeTier = isExpired ? 'basic' : currentTier;

                return Stack(
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose the Perfect Plan for your Office'.translate(),
                            style: GoogleFonts.cairo(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navyBlue,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'Grow your law firm visibility, decrease commissions, and unlock team management.'.translate(),
                            style: GoogleFonts.cairo(
                              fontSize: 13.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(height: 24.h),
                          _buildPlanCard(
                            tierKey: 'basic',
                            name: 'Basic'.translate(),
                            price: 0,
                            features: [
                              'Standard search visibility'.translate(),
                              '15% platform commission rate'.translate(),
                              'No profile badge display'.translate(),
                              'No office management/staff access'.translate(),
                            ],
                            isActive: activeTier == 'basic',
                            isDark: isDark,
                            cardGradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF1E293B), const Color(0xFF1E293B)]
                                  : [Colors.grey.shade50, Colors.grey.shade50],
                            ),
                            borderCol: Colors.grey.shade300,
                            badgeWidget: const SizedBox.shrink(),
                          ),
                          SizedBox(height: 16.h),
                          _buildPlanCard(
                            tierKey: 'elite',
                            name: 'Elite'.translate(),
                            price: 299,
                            features: [
                              'Boosted search recommendations'.translate(),
                              '10% platform commission rate'.translate(),
                              'Silver Elite profile badge'.translate(),
                              'Office management (Max 3 staff)'.translate(),
                            ],
                            isActive: activeTier == 'elite',
                            isDark: isDark,
                            cardGradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF1E3A5F), const Color(0xFF162E4A)]
                                  : [const Color(0xFFE9F2FD), const Color(0xFFD0E2FA)],
                            ),
                            borderCol: const Color(0xFFB0CBE9),
                            badgeWidget: const SubscriptionBadgeWidget(tier: 'elite', isProfile: true),
                          ),
                          SizedBox(height: 16.h),
                          _buildPlanCard(
                            tierKey: 'partner',
                            name: 'Partner'.translate(),
                            price: 799,
                            features: [
                              'Top Priority/Recommended visibility'.translate(),
                              '5% platform commission rate'.translate(),
                              'Glowing Gold Partner profile badge'.translate(),
                              'Unlimited office management & staff'.translate(),
                            ],
                            isActive: activeTier == 'partner',
                            isDark: isDark,
                            cardGradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF3F3011), const Color(0xFF261D0B)]
                                  : [const Color(0xFFFFF9E6), const Color(0xFFFFF2CC)],
                            ),
                            borderCol: const Color(0xFFFFD54F),
                            badgeWidget: const SubscriptionBadgeWidget(tier: 'partner', isProfile: true),
                          ),
                        ],
                      ),
                    ),
                    if (_isLoading)
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildPlanCard({
    required String tierKey,
    required String name,
    required double price,
    required List<String> features,
    required bool isActive,
    required bool isDark,
    required Gradient cardGradient,
    required Color borderCol,
    required Widget badgeWidget,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isActive ? AppColors.legalGold : borderCol,
          width: isActive ? 2.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.legalGold.withOpacity(0.25),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      padding: EdgeInsets.all(20.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: GoogleFonts.cairo(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  badgeWidget,
                ],
              ),
              if (isActive)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.legalGold,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    'Active'.translate(),
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            textBaseline: TextBaseline.alphabetic,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            children: [
              Text(
                'EGP $price',
                style: GoogleFonts.cairo(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyBlue,
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                '/ ${'month'.translate()}',
                style: GoogleFonts.cairo(
                  fontSize: 13.sp,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          Divider(height: 24.h, color: borderCol),
          ...features.map((feature) {
            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.legalGold,
                    size: 18.sp,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      feature,
                      style: GoogleFonts.cairo(
                        fontSize: 13.sp,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton(
              onPressed: isActive
                  ? null
                  : () {
                      if (price == 0) {
                        _upgradePlan(tierKey);
                      } else {
                        _showCheckoutDialog(tierKey, price);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.grey.shade400 : AppColors.navyBlue,
                foregroundColor: Colors.white,
                elevation: isActive ? 0 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                isActive ? 'Current Plan'.translate() : 'Choose Plan'.translate(),
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
