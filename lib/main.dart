import 'package:flutter/material.dart';
import 'package:mezaan/shared/navigation/route_generator.dart';
import 'package:mezaan/shared/navigation/app_routes.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  VideoPlayerMediaKit.ensureInitialized();
  runApp(const MezaanApp());
}

class MezaanApp extends StatelessWidget {
  final String initialRoute;

  const MezaanApp({super.key, this.initialRoute = AppRoutes.onboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mezaan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.navyBlue,
          brightness: Brightness.light,
        ),
        primaryColor: AppColors.navyBlue,
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
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: AppColors.textDark),
          displayMedium: TextStyle(color: AppColors.textDark),
          displaySmall: TextStyle(color: AppColors.textDark),
          headlineMedium: TextStyle(color: AppColors.textDark),
          headlineSmall: TextStyle(color: AppColors.textDark),
          titleLarge: TextStyle(color: AppColors.textDark),
          titleMedium: TextStyle(color: AppColors.textDark),
          titleSmall: TextStyle(color: AppColors.textDark),
          bodyLarge: TextStyle(color: AppColors.textDark),
          bodyMedium: TextStyle(color: AppColors.textDark),
          bodySmall: TextStyle(color: AppColors.textDark),
        ),
        inputDecorationTheme: InputDecorationTheme(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: AppColors.legalGold,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.navyBlue, width: 2),
          ),
          labelStyle: const TextStyle(color: AppColors.navyBlue),
          hintStyle: TextStyle(
            color: AppColors.textDark.withValues(alpha: 0.5),
          ),
        ),
      ),
      initialRoute: initialRoute,
      onGenerateRoute: RouteGenerator.onGenerateRoute,
    );
  }
}
