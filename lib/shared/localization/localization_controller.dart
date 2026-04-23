import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationController extends GetxController {
  static const _languageKey = 'app_language_code';

  static LocalizationController get instance {
    if (!Get.isRegistered<LocalizationController>()) {
      Get.put(LocalizationController(), permanent: true);
    }
    return Get.find<LocalizationController>();
  }

  // Observable language code
  final RxString currentLanguage = 'en'.obs;
  final RxBool isArabic = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_languageKey) ?? 'en';
    setLanguage(saved, persist: false);
  }

  /// Switch between English and Arabic
  void toggleLanguage() {
    if (currentLanguage.value == 'en') {
      setLanguage('ar');
    } else {
      setLanguage('en');
    }
  }

  /// Set language to specific code
  void setLanguage(String languageCode, {bool persist = true}) {
    currentLanguage.value = languageCode;
    isArabic.value = languageCode == 'ar';
    Get.updateLocale(Locale(languageCode));
    if (persist) {
      _saveLanguage(languageCode);
    }
  }

  Future<void> _saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  /// Get translated string
  String translate(String? key) {
    final safeKey = key?.trim() ?? '';
    if (safeKey.isEmpty) {
      return '';
    }

    try {
      final translated = _getTranslation(safeKey, currentLanguage.value);
      if (translated.trim().isEmpty) {
        return safeKey;
      }
      return translated;
    } catch (_) {
      return safeKey;
    }
  }

  String _getTranslation(String key, String languageCode) {
    final translations = {
      'en': _englishTranslations,
      'ar': _arabicTranslations,
    };

    final selectedLanguageMap = translations[languageCode] ?? const {};
    final direct = selectedLanguageMap[key];
    if (direct != null) {
      return direct;
    }

    final normalizedKey = key.trim();
    final lowerKey = normalizedKey.toLowerCase();

    final directNormalized = selectedLanguageMap[normalizedKey];
    if (directNormalized != null) {
      return directNormalized;
    }

    final directLower = selectedLanguageMap[lowerKey];
    if (directLower != null) {
      return directLower;
    }

    // Fallback for screens that still use literal text instead of stable keys.
    if (languageCode == 'ar') {
      return _englishLiteralToArabic[key] ??
          _englishLiteralToArabic[normalizedKey] ??
          _englishLiteralToArabicLower[lowerKey] ??
          key;
    }

    if (languageCode == 'en') {
      return _arabicLiteralToEnglish[key] ??
          _arabicLiteralToEnglish[normalizedKey] ??
          _arabicLiteralToEnglishLower[lowerKey] ??
          key;
    }

    return key;
  }

  static final Map<String, String> _arabicLiteralToEnglish = {
    for (final entry in _englishLiteralToArabic.entries) entry.value: entry.key,
  };

  static final Map<String, String> _englishLiteralToArabicLower = {
    for (final entry in _englishLiteralToArabic.entries)
      entry.key.toLowerCase().trim(): entry.value,
  };

  static final Map<String, String> _arabicLiteralToEnglishLower = {
    for (final entry in _arabicLiteralToEnglish.entries)
      entry.key.toLowerCase().trim(): entry.value,
  };

  static const _englishLiteralToArabic = {
    'Welcome Back': 'مرحبا بعودتك',
    'Sign in to access your legal dashboard':
        'سجل الدخول للوصول إلى لوحة التحكم القانونية الخاصة بك',
    'Sign In': 'تسجيل الدخول',
    'Sign in as Guest': 'الدخول كضيف',
    "Don't have an account? ": 'ليس لديك حساب؟ ',
    'Create': 'إنشاء',
    'Phone': 'الهاتف',
    'Email': 'البريد الإلكتروني',
    '11-digit mobile number': 'رقم هاتف مكون من 11 رقم',
    'example@gmail.com': 'example@gmail.com',
    'Password': 'كلمة المرور',
    'Secure': 'آمن',
    'Trusted': 'موثوق',
    'Justice at Your Fingertips': 'العدالة بين يديك',
    'Justice in your finger tips': 'العدالة بين يديك',
    'justic in your finger tips': 'العدالة بين يديك',
    'Join As User': 'انضم كمستخدم',
    'Tap to start user registration': 'اضغط لبدء تسجيل المستخدم',
    'Join As Lawyer': 'انضم كمحام',
    'Tap to start lawyer registration': 'اضغط لبدء تسجيل المحامي',
    'Back to Login': 'العودة لتسجيل الدخول',
    'Select': 'اختيار',
    'Video Call with Lawyer': 'مكالمة فيديو مع محام',
    'Connect with legal experts via high-quality video calls safely and privately.':
        'تواصل مع خبراء قانونيين عبر مكالمات فيديو عالية الجودة بأمان وخصوصية.',
    'Book Appointments': 'احجز المواعيد',
    'Schedule your meetings with top-rated lawyers easily through our app.':
        'حدد مواعيدك مع أفضل المحامين بسهولة عبر التطبيق.',
    'Free AI Consultation': 'استشارة ذكاء اصطناعي مجانية',
    'Get instant legal advice for free through our advanced AI assistant.':
        'احصل على نصائح قانونية فورية مجانًا عبر مساعدنا الذكي المتقدم.',
    'Your Legal Hub': 'مركزك القانوني',
    'Access all legal services in one powerful application anytime.':
        'الوصول إلى جميع الخدمات القانونية في تطبيق واحد قوي في أي وقت.',
    'Login': 'تسجيل الدخول',
    'Register': 'تسجيل',
    'Video could not be loaded': 'تعذر تحميل الفيديو',
    'Join Meezan': 'انضم إلى ميزان',
    'Your Legal Partner': 'شريكك القانوني',
    'Phone Number': 'رقم الهاتف',
    'Continue with Phone': 'المتابعة عبر الهاتف',
    'Or continue with': 'أو المتابعة عبر',
    'Facebook': 'فيسبوك',
    'Google': 'جوجل',
    'Apple': 'آبل',
    'Please enter a phone number': 'يرجى إدخال رقم هاتف',
    'User Registration': 'تسجيل المستخدم',
    'Lawyer Registration': 'تسجيل المحامي',
    'Country': 'الدولة',
    'Egypt': 'مصر',
    'First Name': 'الاسم الأول',
    'Second Name': 'الاسم الثاني',
    'e.g. Ahmed': 'مثال: أحمد',
    'e.g. Ali': 'مثال: علي',
    'e.g. ahmed.ali@gmail.com': 'مثال: ahmed.ali@gmail.com',
    'e.g. Aa@12345': 'مثال: Aa@12345',
    'Re-enter Password': 'إدخال كلمة المرور مرة أخرى',
    'Enter the same password': 'أدخل نفس كلمة المرور',
    'At least 8 characters': '8 أحرف على الأقل',
    'One uppercase letter': 'حرف واحد بأحرف كبيرة',
    'One lowercase letter': 'حرف واحد بأحرف صغيرة',
    'One special character': 'رمز خاص واحد',
    'One number': 'رقم واحد',
    'Must be +18': 'يجب أن يكون +18',
    'City': 'المدينة',
    'Address': 'العنوان',
    'Street, building, floor, apartment, landmark...':
        'الشارع، المبنى، الطابق، الشقة، المعلم...',
    'Birth Date': 'تاريخ الميلاد',
    'DD/MM/YYYY': 'DD/MM/YYYY',
    'National ID Number': 'رقم الهوية الوطنية',
    'e.g. 29801011234567': 'مثال: 29801011234567',
    'National ID (Front)': 'الهوية الوطنية (الأمام)',
    'National ID (Back)': 'الهوية الوطنية (الخلف)',
    'Profile Photo (Optional)': 'صورة الملف الشخصي (اختياري)',
    'Tap to add or change photo': 'اضغط لإضافة أو تغيير الصورة',
    'Reading ID data...': 'جاري قراءة بيانات الهوية...',
    'Tap to capture': 'اضغط للالتقاط',
    'Capture failed. Please try again.':
        'فشل الالتقاط. يرجى المحاولة مرة أخرى.',
    'Could not select profile photo.': 'تعذر اختيار صورة الملف الشخصي.',
    'No camera available on this device': 'لا توجد كاميرا متاحة على هذا الجهاز',
    'Unable to open camera right now': 'تعذر فتح الكاميرا الآن',
    'Birth date could not be confirmed from OCR.':
        'تعذر تأكيد تاريخ الميلاد من التعرف الضوئي.',
    'Failed to read National ID. Please retake the photo':
        'فشل قراءة الهوية الوطنية. يرجى إعادة التقاط الصورة.',
    'Could not detect a valid 14-digit National ID. Retake the front photo clearly.':
        'تعذر اكتشاف رقم هوية وطني صحيح من 14 رقمًا. أعد تصوير الوجه الأمامي بوضوح.',
    'Register failed. Please fix highlighted fields.':
        'فشل التسجيل. يرجى تصحيح الحقول المحددة.',
    'Register successfully': 'تم التسجيل بنجاح',
    'Register failed. Please try again.':
        'فشل التسجيل. يرجى المحاولة مرة أخرى.',
    'Could not connect to server. Check API URL and network.':
        'تعذر الاتصال بالخادم. تحقق من رابط الواجهة والشبكة.',
    'Gender': 'الجنس',
    'Male': 'ذكر',
    'Female': 'أنثى',
    'Governorate': 'المحافظة',
    'Select Governorate': 'اختر المحافظة',
    'Select City': 'اختر المدينة',
    'National ID must contain digits only':
        'يجب أن يحتوي الرقم القومي على أرقام فقط',
    'National ID must be exactly 14 digits':
        'يجب أن يتكون الرقم القومي من 14 رقمًا بالضبط',
    'Address is required': 'العنوان مطلوب',
    'Enter a more detailed address': 'أدخل عنوانًا أكثر تفصيلًا',
    'Gender selection is required': 'اختيار الجنس مطلوب',
    'Governorate is required': 'المحافظة مطلوبة',
    'City is required': 'المدينة مطلوبة',
    'Capture front ID photo from camera': 'التقط صورة الوجه الأمامي للهوية',
    'Capture back ID photo from camera': 'التقط صورة الوجه الخلفي للهوية',
    'Date of birth is required': 'تاريخ الميلاد مطلوب',
    '+21 only': '+21 فقط',
    'License Number': 'رقم الرخصة',
    'e.g. LAW123456789': 'مثال: LAW123456789',
    'Specialization': 'التخصص',
    'e.g. Criminal Law': 'مثال: القانون الجنائي',
    'Date of Birth': 'تاريخ الميلاد',
    'License Photo': 'صورة الرخصة',
    'Profile Photo': 'الصورة الشخصية',
    'e.g. 01234567890': 'مثال: 01234567890',
    'Capture Photo': 'التقط صورة',
    'Must be +21': 'يجب أن يكون +21',
    'Please fix highlighted fields': 'يرجى تصحيح الحقول المحددة',
    'Ready to save lawyer payload: ': 'جاهز لحفظ بيانات تسجيل المحامي: ',
    'Enter a valid email address': 'أدخل بريدًا إلكترونيًا صحيحًا',
    'Password does not meet the required rules':
        'كلمة المرور لا تستوفي الشروط المطلوبة',
    'Please re-enter password': 'يرجى إعادة إدخال كلمة المرور',
    'Passwords must match': 'يجب أن تتطابق كلمتا المرور',
    'License number is required': 'رقم الرخصة مطلوب',
    'Specialization is required': 'التخصص مطلوب',
    'Phone number is required': 'رقم الهاتف مطلوب',
    'Phone number must be at least 10 digits':
        'يجب أن يحتوي رقم الهاتف على 10 أرقام على الأقل',
    'First name is required': 'الاسم الأول مطلوب',
    'Second name is required': 'الاسم الثاني مطلوب',
    'Email is required': 'البريد الإلكتروني مطلوب',
    'Password is required': 'كلمة المرور مطلوبة',
    'Birth date is required (captured from National ID)':
        'تاريخ الميلاد مطلوب (مأخوذ من الهوية الوطنية)',
    'National ID is required (captured from National ID image)':
        'رقم الهوية الوطنية مطلوب (مأخوذ من صورة الهوية الوطنية)',
    'Take photo': 'التقط صورة',
    'Choose from gallery': 'اختر من المعرض',
    'Remove selected photo': 'إزالة الصورة المحددة',
    'Front Side': 'الجانب الأمامي',
    'Back Side': 'الجانب الخلفي',
    'Align National ID Front Side inside the grid':
        'حاذِ الجانب الأمامي من الهوية الوطنية داخل الشبكة',
    'Align National ID Back Side inside the grid':
        'حاذِ الجانب الخلفي من الهوية الوطنية داخل الشبكة',
    'Center the whole card, then align ID number with the yellow band':
        'قم بتوسيط البطاقة بالكامل ثم حاذِ رقم الهوية مع الشريط الأصفر',
    'Keep 14-digit number line here': 'ضع سطر الرقم المكون من 14 رقمًا هنا',
    'Capture license photo from camera': 'التقط صورة الرخصة من الكاميرا',
    'Capture profile photo from camera': 'التقط صورة الملف الشخصي من الكاميرا',
    'Join as User': 'انضم كمستخدم',
    'Join as Lawyer': 'انضم كمحام',
    'Already have an account? ': 'هل لديك حساب بالفعل؟ ',
    'Create Account': 'إنشاء حساب',
    'After capturing the front side, National ID and Birth Date are auto-filled.':
        'بعد التقاط الجانب الأمامي، يتم ملء رقم الهوية وتاريخ الميلاد تلقائياً.',
    'Access Legal Services with Ease': 'الوصول للخدمات القانونية بسهولة',
    'Serve Justice & Help Communities': 'حقق العدالة وساعد المجتمع',
    'Admin Dashboard': 'لوحة تحكم المدير',
    'Lawyer Interface': 'واجهة المحامي',
    'User Dashboard': 'لوحة تحكم المستخدم',
    'Welcome Admin': 'مرحبًا أيها المدير',
    'Welcome Lawyer': 'مرحبًا أيها المحامي',
    'Welcome User': 'مرحبًا أيها المستخدم',
    'Try Admin Dashboard': 'جرّب لوحة تحكم المدير',
    'Try Lawyer Interface': 'جرّب واجهة المحامي',
    'Try User Dashboard': 'جرّب لوحة تحكم المستخدم',
    'Logout': 'تسجيل الخروج',
    'coming soon': 'قريبًا',
    'Welcome back, User': 'مرحبًا بعودتك، المستخدم',
    'Your dashboard is powered by live database content':
        'لوحة التحكم الخاصة بك تعمل بمحتوى مباشر من قاعدة البيانات',
    'Search lawyers, categories, cases...':
        'ابحث عن المحامين والتصنيفات والقضايا...',
    'Categories': 'التصنيفات',
    'Browse legal services from the database':
        'تصفح الخدمات القانونية من قاعدة البيانات',
    'Top Lawyers': 'أفضل المحامين',
    'Sorted by rating, availability, and specialization':
        'مرتبة حسب التقييم والتوفر والتخصص',
    'Featured Services': 'الخدمات المميزة',
    'Database-driven legal offers and consultations':
        'عروض واستشارات قانونية مدعومة بقاعدة البيانات',
    'Legal AI Assistant': 'مساعد الذكاء الاصطناعي القانوني',
    'Get instant answers to your legal questions':
        'احصل على إجابات فورية لأسئلتك القانونية',
    'Start Chat': 'ابدأ المحادثة',
    'Nearby Government Services': 'الخدمات الحكومية القريبة',
    'Find government offices, courts, and service centers nearby':
        'اعثر على المكاتب الحكومية والمحاكم ومراكز الخدمة القريبة',
    'Open map to see the closest places': 'افتح الخريطة لرؤية أقرب الأماكن',
    'Open Map': 'افتح الخريطة',
    'Urgent Rescue': 'إنقاذ عاجل',
    'Cases': 'القضايا',
    'Messages': 'الرسائل',
    'Profile': 'الملف الشخصي',
    'Manage your account': 'إدارة حسابك',
    'Edit Profile': 'تعديل الملف الشخصي',
    'Language': 'اللغة',
    'Arabic / English': 'العربية / الإنجليزية',
    'Dark Mode': 'الوضع الداكن',
    'Saved Cards': 'البطاقات المحفوظة',
    'Emergency Contacts': 'جهات اتصال الطوارئ',
    'Settings': 'الإعدادات',
    'Privacy & Security': 'الخصوصية والأمان',
    'Need Help?': 'تحتاج مساعدة؟',
    'AI Chat': 'محادثة الذكاء الاصطناعي',
    'SOS': 'استغاثة',
    'Edit profile': 'تعديل الملف الشخصي',
    'Saved cards': 'البطاقات المحفوظة',
    'Emergency contacts': 'جهات اتصال الطوارئ',
    'Privacy & security': 'الخصوصية والأمان',
    'Help center': 'مركز المساعدة',
    'Map': 'الخريطة',
    'Lawyers': 'المحامون',
    'Help': 'المساعدة',
    'Family Law': 'قانون الأسرة',
    'Civil Law': 'القانون المدني',
    'Criminal Law': 'القانون الجنائي',
    'Labor Law': 'قانون العمل',
    'Contracts': 'العقود',
    'Companies': 'الشركات',
    'Video Consultation': 'استشارة عبر الفيديو',
    'Book a secure live session': 'احجز جلسة مباشرة آمنة',
    'Document Review': 'مراجعة المستندات',
    'Send contracts and legal files': 'أرسل العقود والملفات القانونية',
    '12 years experience': '12 سنة خبرة',
    '9 years experience': '9 سنوات خبرة',
    'Online now': 'متصل الآن',
    'Available later': 'متاح لاحقًا',
    'View': 'عرض',
    'Notifications': 'الإشعارات',
  };

  // English translations
  static const _englishTranslations = {
    // Onboarding
    'onboarding_title': 'Welcome to Mezaan',
    'onboarding_subtitle': 'Your legal companion',

    // User Registration
    'register_title': 'Create Account',
    'register_fullname': 'Full Name',
    'register_email': 'Email Address',
    'register_password': 'Password',
    'register_confirm_password': 'Confirm Password',
    'register_gender': 'Gender',
    'register_country': 'Country',
    'register_government': 'Government',
    'register_city': 'City',
    'register_address': 'Address',
    'register_birthdate': 'Birth Date',
    'register_national_id': 'National ID',
    'register_front_id_photo': 'Front ID Photo',
    'register_back_id_photo': 'Back ID Photo',
    'register_profile_photo': 'Profile Photo (Optional)',
    'register_button': 'Create Account',
    'register_success': 'Account created successfully',
    'register_error': 'Registration failed',

    'first_name': 'First Name',
    'first_name_hint': 'e.g. Ahmed',
    'second_name': 'Second Name',
    'second_name_hint': 'e.g. Ali',
    'email_hint': 'e.g. ahmed.ali@gmail.com',
    'password_hint': 'e.g. Aa@12345',
    'confirm_password_label': 'Re-enter Password',
    'confirm_password_hint': 'Enter the same password',
    'governorate': 'Governorate',
    'select_governorate': 'Select Governorate',
    'select_city': 'Select City',
    'address_hint': 'Street, building, floor, apartment, landmark...',
    'national_id_hint': 'e.g. 29801011234567',
    'birth_date_hint': 'DD/MM/YYYY',

    'password_rules_title': 'Password Requirements:',
    'password_rule_8chars': 'At least 8 characters',
    'password_rule_upper': 'One uppercase letter',
    'password_rule_lower': 'One lowercase letter',
    'password_rule_special': 'One special character',
    'password_rule_number': 'One number',
    'must_be_18': 'Must be +18',

    'id_front_note':
        'After capturing the front side, National ID and Birth Date are auto-filled.',
    'already_have_account': 'Already have an account? ',
    'login_link': 'Login',

    'select_photo': 'Select Photo',
    'take_photo': 'Take Photo',
    'choose_from_gallery': 'Choose from Gallery',
    'remove_photo': 'Remove Photo',
    'cancel': 'Cancel',

    'extract_id_info': 'Extract ID Information',
    'id_extraction_failed':
        'Could not detect a valid 14-digit National ID. Retake the front photo clearly.',

    'male': 'Male',
    'female': 'Female',
    'other': 'Other',

    'required_field': 'This field is required',
    'invalid_email': 'Please enter a valid email',
    'password_mismatch': 'Passwords do not match',
    'duplicate_email': 'Email already exists',
    'duplicate_national_id': 'National ID already registered',
    'duplicate_phone': 'Phone number already registered',
    'first_name_required': 'First name is required',
    'second_name_required': 'Second name is required',
    'birthdate_required': 'Birth date is required (captured from National ID)',
    'age_restricted': '+18 only',
    'national_id_required':
        'National ID is required (captured from National ID image)',
    'national_id_digits_only': 'National ID must contain digits only',
    'national_id_14_digits': 'National ID must be exactly 14 digits',
    'address_required': 'Address is required',
    'address_detailed': 'Enter a more detailed address',
    'gender_required': 'Gender selection is required',
    'governorate_required': 'Governorate is required',
    'city_required': 'City is required',
    'front_id_required': 'Capture front ID photo from camera',
    'back_id_required': 'Capture back ID photo from camera',

    'submit': 'Submit',
    'next': 'Next',
    'back': 'Back',
    'loading': 'Loading...',
    'error': 'Error',
    'success': 'Success',
    'register_failed_validation':
        'Register failed. Please fix highlighted fields.',
    'register_successfully': 'Register successfully',
    'register_failed': 'Register failed. Please try again.',
    'connection_error':
        'Could not connect to server. Check API URL and network.',
  };

  // Arabic translations
  static const _arabicTranslations = {
    // Onboarding
    'onboarding_title': 'مرحبا بك في ميزان',
    'onboarding_subtitle': 'رفيقك القانوني',

    // User Registration
    'register_title': 'إنشاء حساب',
    'register_fullname': 'الاسم الكامل',
    'register_email': 'عنوان البريد الإلكتروني',
    'register_password': 'كلمة المرور',
    'register_confirm_password': 'تأكيد كلمة المرور',
    'register_gender': 'النوع',
    'register_country': 'الدولة',
    'register_government': 'المحافظة',
    'register_city': 'المدينة',
    'register_address': 'العنوان',
    'register_birthdate': 'تاريخ الميلاد',
    'register_national_id': 'رقم الهوية الوطنية',
    'register_front_id_photo': 'صورة الهوية الأمامية',
    'register_back_id_photo': 'صورة الهوية الخلفية',
    'register_profile_photo': 'صورة الملف الشخصي (اختياري)',
    'register_button': 'إنشاء حساب',
    'register_success': 'تم إنشاء الحساب بنجاح',
    'register_error': 'فشل التسجيل',

    'first_name': 'الاسم الأول',
    'first_name_hint': 'مثال: أحمد',
    'second_name': 'الاسم الثاني',
    'second_name_hint': 'مثال: علي',
    'email_hint': 'مثال: ahmed.ali@gmail.com',
    'password_hint': 'مثال: Aa@12345',
    'confirm_password_label': 'إدخال كلمة المرور مرة أخرى',
    'confirm_password_hint': 'أدخل نفس كلمة المرور',
    'governorate': 'المحافظة',
    'select_governorate': 'اختر المحافظة',
    'select_city': 'اختر المدينة',
    'address_hint': 'الشارع، المبنى، الطابق، الشقة، المعلم...',
    'national_id_hint': 'مثال: 29801011234567',
    'birth_date_hint': 'DD/MM/YYYY',

    'password_rules_title': 'متطلبات كلمة المرور:',
    'password_rule_8chars': '8 أحرف على الأقل',
    'password_rule_upper': 'حرف واحد بأحرف كبيرة',
    'password_rule_lower': 'حرف واحد بأحرف صغيرة',
    'password_rule_special': 'رمز خاص واحد',
    'password_rule_number': 'رقم واحد',
    'must_be_18': 'يجب أن يكون +18',

    'id_front_note':
        'بعد التقاط الجانب الأمامي، يتم ملء رقم الهوية وتاريخ الميلاد تلقائياً.',
    'already_have_account': 'هل لديك حساب بالفعل؟ ',
    'login_link': 'تسجيل الدخول',

    'select_photo': 'اختر صورة',
    'take_photo': 'التقط صورة',
    'choose_from_gallery': 'اختر من المعرض',
    'remove_photo': 'إزالة الصورة',
    'cancel': 'إلغاء',

    'extract_id_info': 'استخراج معلومات الهوية',
    'id_extraction_failed':
        'لم يتمكن من اكتشاف رقم هوية وطنية صحيح من 14 رقما. أعد التقاط الصورة بوضوح.',

    'male': 'ذكر',
    'female': 'أنثى',
    'other': 'آخر',

    'required_field': 'هذا الحقل مطلوب',
    'invalid_email': 'يرجى إدخال بريد إلكتروني صحيح',
    'password_mismatch': 'كلمات المرور غير متطابقة',
    'duplicate_email': 'البريد الإلكتروني موجود بالفعل',
    'duplicate_national_id': 'رقم الهوية الوطنية مسجل بالفعل',
    'duplicate_phone': 'رقم الهاتف مسجل بالفعل',
    'first_name_required': 'الاسم الأول مطلوب',
    'second_name_required': 'الاسم الثاني مطلوب',
    'birthdate_required': 'تاريخ الميلاد مطلوب (مأخوذ من الهوية الوطنية)',
    'age_restricted': '+18 فقط',
    'national_id_required':
        'رقم الهوية الوطنية مطلوب (مأخوذ من صورة الهوية الوطنية)',
    'national_id_digits_only': 'يجب أن تحتوي الهوية الوطنية على أرقام فقط',
    'national_id_14_digits': 'يجب أن تحتوي الهوية الوطنية على 14 رقم بالضبط',
    'address_required': 'العنوان مطلوب',
    'address_detailed': 'أدخل عنواناً أكثر تفصيلاً',
    'gender_required': 'اختيار الجنس مطلوب',
    'governorate_required': 'المحافظة مطلوبة',
    'city_required': 'المدينة مطلوبة',
    'front_id_required': 'التقط صورة الهوية الأمامية من الكاميرا',
    'back_id_required': 'التقط صورة الهوية الخلفية من الكاميرا',

    'submit': 'إرسال',
    'next': 'التالي',
    'back': 'رجوع',
    'loading': 'جاري التحميل...',
    'error': 'خطأ',
    'success': 'نجاح',
    'register_failed_validation': 'فشل التسجيل. يرجى إصلاح الحقول المحددة.',
    'register_successfully': 'تم التسجيل بنجاح',
    'register_failed': 'فشل التسجيل. يرجى المحاولة مرة أخرى.',
    'connection_error':
        'لم يتمكن من الاتصال بالخادم. تحقق من عنوان URL للواجهة والشبكة.',
  };
}
