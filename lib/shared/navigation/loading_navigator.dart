import 'package:flutter/material.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

class LoadingNavigator {
  static const Duration _minLoadingDuration = Duration(milliseconds: 700);
  static const Duration _loadingOverlayDuration = Duration(milliseconds: 260);
  static const Duration _pageTransitionDuration = Duration(milliseconds: 420);

  static Future<void> pushNamed(
    BuildContext context,
    String routeName, {
    Object? arguments,
    Future<void>? preload,
  }) async {
    await _showAndNavigate(
      context,
      preload: preload,
      navigate: () async {
        if (!context.mounted) return;
        await Navigator.pushNamed(context, routeName, arguments: arguments);
      },
    );
  }

  static Future<void> pushReplacementNamed(
    BuildContext context,
    String routeName, {
    Object? arguments,
    Future<void>? preload,
  }) async {
    await _showAndNavigate(
      context,
      preload: preload,
      navigate: () async {
        if (!context.mounted) return;
        await Navigator.pushReplacementNamed(
          context,
          routeName,
          arguments: arguments,
        );
      },
    );
  }

  static Future<void> pushNamedAndRemoveUntil(
    BuildContext context,
    String routeName,
    RoutePredicate predicate, {
    Object? arguments,
    Future<void>? preload,
  }) async {
    await _showAndNavigate(
      context,
      preload: preload,
      navigate: () async {
        if (!context.mounted) return;
        await Navigator.pushNamedAndRemoveUntil(
          context,
          routeName,
          predicate,
          arguments: arguments,
        );
      },
    );
  }

  static Future<void> pushPage(
    BuildContext context,
    Widget page, {
    Future<void>? preload,
  }) async {
    await _showAndNavigate(
      context,
      preload: preload,
      navigate: () async {
        if (!context.mounted) return;
        await Navigator.push(context, _buildModernRoute(page));
      },
    );
  }

  static PageRouteBuilder<void> _buildModernRoute(Widget page) {
    return PageRouteBuilder<void>(
      transitionDuration: _pageTransitionDuration,
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final slide =
            Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        final scale = Tween<double>(begin: 0.985, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(scale: scale, child: child),
          ),
        );
      },
    );
  }

  static Future<void> _showAndNavigate(
    BuildContext context, {
    required Future<void> Function() navigate,
    Future<void>? preload,
  }) async {
    if (!context.mounted) return;

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Loading',
      barrierColor: Colors.white.withOpacity(0.94),
      transitionDuration: _loadingOverlayDuration,
      pageBuilder: (_, _, _) => const _FullScreenLoadingBody(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(opacity: fade, child: child);
      },
    );

    await Future.wait([
      Future<void>.delayed(_minLoadingDuration),
      preload ?? Future<void>.value(),
    ]);

    if (rootNavigator.mounted && rootNavigator.canPop()) {
      rootNavigator.pop();
      await Future<void>.delayed(_loadingOverlayDuration);
    }

    await navigate();
  }
}

class _FullScreenLoadingBody extends StatefulWidget {
  const _FullScreenLoadingBody();

  @override
  State<_FullScreenLoadingBody> createState() => _FullScreenLoadingBodyState();
}

class _FullScreenLoadingBodyState extends State<_FullScreenLoadingBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _tiltAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.88,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _tiltAnimation = Tween<double>(
      begin: -0.08,
      end: 0.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _tiltAnimation.value,
                child: child,
              ),
            );
          },
          child: const Icon(
            Icons.balance_rounded,
            size: 92,
            color: AppColors.legalGold,
          ),
        ),
      ),
    );
  }
}
