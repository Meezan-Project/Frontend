import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/navigation/route_generator.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/shared/theme/theme_controller.dart';
import 'package:mezaan/shared/localization/localization_controller.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  VideoPlayerMediaKit.ensureInitialized();
  // Ensure localization controller is available globally.
  LocalizationController.instance;
  ThemeController.instance;
  runApp(const MezaanApp());
}

class MezaanApp extends StatelessWidget {
  final String initialRoute;

  const MezaanApp({super.key, this.initialRoute = AppRoutes.onboarding});

  @override
  Widget build(BuildContext context) {
    final localizationController = LocalizationController.instance;
    final themeController = ThemeController.instance;

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Obx(
          () => MaterialApp(
            title: 'Mezaan',
            debugShowCheckedModeBanner: false,
            themeMode: themeController.isDarkMode.value
                ? ThemeMode.dark
                : ThemeMode.light,
            locale: Locale(localizationController.currentLanguage.value),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              return Directionality(
                textDirection: localizationController.isArabic.value
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: child!,
              );
            },
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.navyBlue,
                brightness: Brightness.light,
              ),
              primaryColor: AppColors.navyBlue,
              textTheme: GoogleFonts.cairoTextTheme(ThemeData.light().textTheme)
                  .apply(
                    bodyColor: AppColors.textDark,
                    displayColor: AppColors.textDark,
                  ),
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.navyBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 32.w,
                    vertical: 12.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 12.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(
                    color: AppColors.legalGold,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(
                    color: AppColors.navyBlue,
                    width: 2,
                  ),
                ),
                labelStyle: const TextStyle(color: AppColors.navyBlue),
                hintStyle: TextStyle(
                  color: AppColors.textDark.withValues(alpha: 0.5),
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.navyBlue,
                brightness: Brightness.dark,
              ),
              textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF081A2F),
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
              ),
            ),
            initialRoute: initialRoute,
            onGenerateRoute: RouteGenerator.onGenerateRoute,
          ),
        );
      },
    );
  }
}
