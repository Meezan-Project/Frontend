import 'package:flutter/material.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  List<_PrivacySectionData> _privacySections() {
    return [
      _PrivacySectionData(
        title: 'Data Encryption / تشفير البيانات',
        description:
            'Your information is encrypted at rest and in transit to protect your privacy.\n\nمعلوماتك مشفرة أثناء الراحة والنقل لحماية خصوصيتك.',
        icon: Icons.lock_outline_rounded,
      ),
      _PrivacySectionData(
        title: 'SOS & Camera Privacy / خصوصية SOS والكاميرا',
        description:
            'SOS recordings and camera access are handled securely and only when needed.\n\nتسجيلات SOS ووصول الكاميرا تتم التعامل معها بشكل آمن وفقط عند الحاجة.',
        icon: Icons.camera_alt_outlined,
      ),
      _PrivacySectionData(
        title: 'Location Services / خدمات الموقع',
        description:
            'Location sharing is controlled by you and used only for emergency support.\n\nمشاركة الموقع تتحكم فيها أنت وتستخدم فقط لدعم الطوارئ.',
        icon: Icons.location_on_outlined,
      ),
      _PrivacySectionData(
        title: 'Lawyer Verification / التحقق من المحامين',
        description:
            'All lawyers are verified before they appear in the platform for added trust.\n\nجميع المحامين يتم التحقق منهم قبل ظهورهم في المنصة لزيادة الثقة.',
        icon: Icons.verified_user_rounded,
      ),
      _PrivacySectionData(
        title: 'Payment & Refund Policy / سياسة الدفع والاسترداد',
        description:
            'Your card data is fully encrypted and never stored on our servers.\n'
            'A 5% administrative fee is applied to each transaction.\n'
            'Refunds are subject to a 2% fee (minimum 200 EGP).\n\n'
            'بيانات بطاقتك مشفرة بالكامل ولا يتم تخزينها لدينا.\n'
            'يتم تحصيل 5% كرسوم إدارية عن كل عملية دفع.\n'
            'عند الاسترجاع، يتم خصم 2% من المبلغ (بحد أدنى 200 جنيه).',
        icon: Icons.credit_card_rounded,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sections = _privacySections();

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navyBlue,
        elevation: 0,
        centerTitle: true,
        title: const Text('Privacy & Security / الخصوصية والأمان'),
      ),
      body: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              children: [
                const Text(
                  'Protect your personal data and keep your account secure.\n\nحماية بياناتك الشخصية وإبقاء حسابك آمناً.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textDark,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                ...sections.map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _PrivacyCard(section: section),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text(
                    'Back / العودة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.section});

  final _PrivacySectionData section;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyBlue.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: AppColors.navyBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(section.icon, color: AppColors.legalGold, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textDark.withOpacity(0.74),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacySectionData {
  const _PrivacySectionData({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}
