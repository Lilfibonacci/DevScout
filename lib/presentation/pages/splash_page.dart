import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _taglineFade;
  late final Animation<double> _glowFade;
  Timer? _navigationTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _glowFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.7, curve: Curves.easeIn),
    );

    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _taglineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();

    // انتقال خودکار به صفحه اصلی پس از اتمام نمایش اسپلش
    _navigationTimer = Timer(const Duration(milliseconds: 2400), _proceedToHome);
  }

  void _proceedToHome() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    context.go('/');
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF070A10),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF070A10),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _proceedToHome,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. پس‌زمینه گرادیان عمیق و های‌تک
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.15),
                    radius: 1.15,
                    colors: [
                      Color(0xFF0F172A), // Dark slate navy
                      Color(0xFF0A0E17),
                      Color(0xFF05070B),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),

              // 2. هاله نورانی (Ambient Glow) متناسب با رنگ‌های فلاتر و اندروید
              Positioned.fill(
                child: FadeTransition(
                  opacity: _glowFade,
                  child: Center(
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF38BDF8).withValues(alpha: 0.18), // Cyan Flutter glow
                            const Color(0xFF3DDC84).withValues(alpha: 0.12), // Mint Android glow
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 0.9],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. محتوای اصلی لوگو و انیمیشن مقیاس و ظهور
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 3),

                        // لوگوی اصلی DevScout با انیمیشن ورود
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _logoScale.value,
                              child: Opacity(
                                opacity: _logoFade.value,
                                child: child,
                              ),
                            );
                          },
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Image.asset(
                              'assets/branding/splash_logo_clean.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // زیرعنوان و تگ‌لاین فارسی/انگلیسی با انیمیشن Fade
                        FadeTransition(
                          opacity: _taglineFade,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              s.appTagline,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFF94A3B8),
                                fontSize: s.isFa ? 12.5 : 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: s.isFa ? 0 : 0.2,
                              ),
                            ),
                          ),
                        ),

                        const Spacer(flex: 3),

                        // 4. نوار بارگذاری مینیمال با گرادیان رنگی DevScout
                        SizedBox(
                          width: 140,
                          height: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: const LinearProgressIndicator(
                              backgroundColor: Color(0xFF1E293B),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF3DDC84),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // نسخه و کپی‌رایت نرم‌افزار
                        Text(
                          'v1.0.0 • DevScout Radar',
                          style: TextStyle(
                            color: const Color(0xFF64748B).withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
