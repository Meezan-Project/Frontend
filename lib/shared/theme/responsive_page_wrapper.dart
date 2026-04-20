import 'package:flutter/widgets.dart';
import 'package:mezaan/shared/theme/responsive_profile.dart';

class ResponsivePageWrapper extends StatelessWidget {
  final Widget child;

  const ResponsivePageWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final adjusted = ResponsiveProfile.adaptedMediaQuery(mediaQuery);
    return MediaQuery(data: adjusted, child: child);
  }
}
