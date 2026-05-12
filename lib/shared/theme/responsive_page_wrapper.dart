import 'package:flutter/widgets.dart';
import 'package:mezaan/shared/theme/responsive_profile.dart';

class ResponsivePageWrapper extends StatelessWidget {
  final Widget? child;

  const ResponsivePageWrapper({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    // 1. Prevent crashes if the router passes a null child
    if (child == null) return const SizedBox.shrink();

    final mediaQuery = MediaQuery.of(context);
    MediaQueryData adjusted = mediaQuery;

    // 2. Safely attempt to adjust the media query
    try {
      adjusted = ResponsiveProfile.adaptedMediaQuery(mediaQuery);
    } catch (e) {
      debugPrint('ResponsiveProfile Error fallback triggered: $e');
    }

    return MediaQuery(data: adjusted, child: child!);
  }
}
