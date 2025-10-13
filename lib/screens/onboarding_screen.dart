import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'permissions_screen.dart';
import '../theme/app_decor.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const _seenKey = 'onboarding_seen_v1';

  static Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _page = PageController();
  int _index = 0;
  late final AnimationController _bgCtrl;

  void _next() {
    HapticFeedback.lightImpact();
    if (_index < 2) {
      _page.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await OnboardingScreen.markSeen();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  void initState() {
    super.initState();
  _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _IntroPage(
        title: 'Track your day',
        body: 'Log activities with smart continuity that fills gaps.',
        icon: Icons.timeline,
        illustrationAsset: 'assets/brand/onb_track.svg',
      ),
      _IntroPage(
        title: 'See insights',
        body: 'Breakdowns by category, weekly trends, and top apps.',
        icon: Icons.insights,
        illustrationAsset: 'assets/brand/onb_insights.svg',
      ),
      _FinalPage(
        title: 'Connect & personalize',
        body: 'Steps, screen time, and custom categories to make it yours.',
        onPermissions: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PermissionsScreen()));
        },
        illustrationAsset: 'assets/brand/onb_personalize.svg',
      ),
    ];

    final scheme = Theme.of(context).colorScheme;
    final decor = Theme.of(context).extension<AppDecor>();
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: decor == null ? null : Container(decoration: BoxDecoration(gradient: decor.headerGradient)),
        title: const Text('Welcome'),
        actions: [
          TextButton(
            onPressed: _finish,
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: const Text('Skip'),
          )
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative blobs for a modern Gen Z feel (animated gently)
            // Minimal background (no animated blobs for a cleaner look)
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset('assets/brand/icon_1024.png', width: 56, height: 56, fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 10),
                      Text('dgHabit', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: .2)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.25)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 14, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            // Subtle frosted glass effect
                            Positioned.fill(
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                child: const SizedBox.shrink(),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _page,
                              builder: (context, _) {
                                return PageView.builder(
                                  controller: _page,
                                  physics: const BouncingScrollPhysics(),
                                  onPageChanged: (i) => setState(() => _index = i),
                                  itemCount: pages.length,
                                  itemBuilder: (context, i) {
                                    final current = _page.hasClients && _page.page != null ? _page.page! : _index.toDouble();
                                    final delta = (i - current).abs();
                                    // Simple, minimal fade only
                                    final opacity = 1 - (delta * 0.15).clamp(0.0, 0.15);
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      curve: Curves.easeOut,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      child: Opacity(
                                        opacity: opacity,
                                        child: pages[i],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _Dots(count: pages.length, index: _index),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                          textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Skip'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        icon: Icon(_index == pages.length - 1 ? Icons.check : Icons.arrow_forward),
                        label: Text(_index == pages.length - 1 ? 'Continue' : 'Next'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// (Removed old _FeatureCard; replaced by page-based content.)

class _IntroPage extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final String? illustrationAsset; // e.g., 'assets/brand/onb_track.png'
  const _IntroPage({required this.title, required this.body, required this.icon, this.illustrationAsset});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _HeroVisual(icon: icon, illustrationAsset: illustrationAsset),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _FinalPage extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onPermissions;
  final String? illustrationAsset; // e.g., 'assets/brand/onb_personalize.png'
  const _FinalPage({required this.title, required this.body, required this.onPermissions, this.illustrationAsset});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _HeroVisual(icon: Icons.tune, illustrationAsset: illustrationAsset),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onPermissions,
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.primary,
              side: BorderSide(color: scheme.primary),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(Icons.privacy_tip_outlined),
            label: const Text('Permissions'),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: active ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.6), width: 1.6),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(2.2),
            decoration: BoxDecoration(
              color: active ? scheme.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

// _Blob removed for minimal background

class _HeroVisual extends StatelessWidget {
  final IconData icon;
  final String? illustrationAsset;
  const _HeroVisual({required this.icon, this.illustrationAsset});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final heroSize = MediaQuery.of(context).size.shortestSide.clamp(120.0, 220.0) * 0.55;
    Widget content;
    if (illustrationAsset != null) {
      if (illustrationAsset!.toLowerCase().endsWith('.svg')) {
        content = SvgPicture.asset(
          illustrationAsset!,
          width: heroSize,
          height: heroSize,
          fit: BoxFit.contain,
        );
      } else {
        content = Image.asset(
          illustrationAsset!,
          width: heroSize,
          height: heroSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(icon, size: heroSize * 0.9, color: scheme.primary),
        );
      }
    } else {
      content = Icon(icon, size: heroSize * 0.9, color: scheme.primary);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: value, child: child),
      ),
      child: content,
    );
  }
}
