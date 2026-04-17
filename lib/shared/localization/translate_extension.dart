import 'package:mezaan/shared/localization/localization_controller.dart';

extension Translate on String? {
  String translate() {
    final source = this;
    if (source == null) {
      return '';
    }

    try {
      final translated = LocalizationController.instance.translate(source);
      if (translated.trim().isEmpty) {
        return source;
      }
      return translated;
    } catch (_) {
      return source;
    }
  }
}
