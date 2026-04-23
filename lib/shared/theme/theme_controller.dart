import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends GetxController {
  static const _themeKey = 'app_theme_mode';

  static ThemeController get instance {
    if (!Get.isRegistered<ThemeController>()) {
      Get.put(ThemeController(), permanent: true);
    }
    return Get.find<ThemeController>();
  }

  final RxBool isDarkMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode.value = prefs.getBool(_themeKey) ?? false;
  }

  void setDarkMode(bool enabled) {
    isDarkMode.value = enabled;
    _saveTheme(enabled);
  }

  void toggleDarkMode() {
    isDarkMode.value = !isDarkMode.value;
    _saveTheme(isDarkMode.value);
  }

  Future<void> _saveTheme(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, enabled);
  }
}
