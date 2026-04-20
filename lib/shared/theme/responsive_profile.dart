import 'package:flutter/widgets.dart';

enum DeviceProfile { compactPhone, phone, tablet, desktop }

class ResponsiveProfile {
  const ResponsiveProfile._();

  static DeviceProfile fromSize(Size size) {
    final shortest = size.shortestSide;
    if (shortest < 360) return DeviceProfile.compactPhone;
    if (shortest < 600) return DeviceProfile.phone;
    if (shortest < 1024) return DeviceProfile.tablet;
    return DeviceProfile.desktop;
  }

  static double maxTextScaleFor(DeviceProfile profile) {
    switch (profile) {
      case DeviceProfile.compactPhone:
        return 1.00;
      case DeviceProfile.phone:
        return 1.05;
      case DeviceProfile.tablet:
        return 1.12;
      case DeviceProfile.desktop:
        return 1.20;
    }
  }

  static MediaQueryData adaptedMediaQuery(MediaQueryData source) {
    final profile = fromSize(source.size);
    final maxTextScale = maxTextScaleFor(profile);
    return source.copyWith(
      textScaler: source.textScaler.clamp(
        minScaleFactor: 0.9,
        maxScaleFactor: maxTextScale,
      ),
    );
  }
}

extension ResponsiveContextX on BuildContext {
  DeviceProfile get deviceProfile =>
      ResponsiveProfile.fromSize(MediaQuery.of(this).size);

  bool get isCompactPhone => deviceProfile == DeviceProfile.compactPhone;
  bool get isPhone => deviceProfile == DeviceProfile.phone;
  bool get isTablet => deviceProfile == DeviceProfile.tablet;
  bool get isDesktop => deviceProfile == DeviceProfile.desktop;
}
