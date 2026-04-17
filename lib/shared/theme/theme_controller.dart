import 'package:get/get.dart';

class ThemeController extends GetxController {
  static ThemeController get instance {
    if (!Get.isRegistered<ThemeController>()) {
      Get.put(ThemeController(), permanent: true);
    }
    return Get.find<ThemeController>();
  }

  final RxBool isDarkMode = false.obs;

  void setDarkMode(bool enabled) {
    isDarkMode.value = enabled;
  }

  void toggleDarkMode() {
    isDarkMode.value = !isDarkMode.value;
  }
}
