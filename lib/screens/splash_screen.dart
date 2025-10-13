import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_decor.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  bool _hasWordmark = false;
  bool _hasSparkle = false;
  // We will always use the provided app icon as the splash hero.

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scale = Tween<double>(begin: 0.985, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    // Navigate to Auth with a smooth fade after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 950));
      if (!mounted) return;
      final seen = await OnboardingScreen.hasSeen();
      if (!mounted) return;
      if (seen) {
        Navigator.of(context).pushReplacementNamed('/auth');
      } else {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    });

    _probeAssets();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final decor = Theme.of(context).extension<AppDecor>();
    final size = MediaQuery.of(context).size;
    // Responsive hero size based on device; clamp for tablets/phones
    final hero = size.shortestSide;
    final heroSize = hero.clamp(120.0, 220.0);
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Container(
        decoration: decor == null
            ? null
            : BoxDecoration(
                gradient: decor.headerGradient,
              ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_hasSparkle)
                    Positioned(
                      top: -12,
                      child: Opacity(
                        opacity: 0.35,
                        child: Lottie.asset(
                          'assets/brand/sparkle.json',
                          width: heroSize,
                          height: heroSize,
                          fit: BoxFit.contain,
                          repeat: true,
                        ),
                      ),
                    ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/brand/icon_1024.png',
                          width: heroSize * 0.8,
                          height: heroSize * 0.8,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            'web/favicon.png',
                            width: heroSize * 0.7,
                            height: heroSize * 0.7,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _hasWordmark
                          ? SvgPicture.asset(
                              'assets/brand/wordmark.svg',
                              width: heroSize * 0.8,
                              colorFilter: ColorFilter.mode(scheme.onSurface, BlendMode.srcIn),
                            )
                          : Text(
                              'dgHabit',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                            ),
                      const SizedBox(height: 8),
                      Text(
                        'Build habits, day by day',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      // Subtle progress to indicate loading
                      SizedBox(
                        width: heroSize * 0.35,
                        child: LinearProgressIndicator(
                          backgroundColor: scheme.onSurface.withValues(alpha: 0.06),
                          color: scheme.primary,
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _probeAssets() async {
    final hasWordmark = await _exists('assets/brand/wordmark.svg');
    final hasSparkle = await _exists('assets/brand/sparkle.json');
    if (!mounted) return;
    setState(() {
      _hasWordmark = hasWordmark;
      _hasSparkle = hasSparkle;
    });
  }

  Future<bool> _exists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }
}
