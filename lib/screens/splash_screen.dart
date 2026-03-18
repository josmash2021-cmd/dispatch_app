import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/page_transitions.dart';
import '../main.dart';

/// Cruise-identical splash — staggered elastic letter entrance, shimmer glow,
/// scale+fade exit. Matches the passenger app animation frame-for-frame.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _bg = Color(0xFF000000);
  static const _gold = Color(0xFFE8C547);
  static const _goldBright = Color(0xFFFFF1C1);

  static const _letters = ['C', 'r', 'u', 'i', 's', 'e'];

  // ── Phase 1: staggered letter entrance ──
  late AnimationController _entranceCtrl;
  late List<Animation<double>> _letterSlide;
  late List<Animation<double>> _letterFade;
  late List<Animation<double>> _letterScale;

  // ── Phase 2: shimmer glow ──
  late AnimationController _glowCtrl;

  // ── Phase 3: scale-up + fade-out ──
  late AnimationController _exitCtrl;
  late Animation<double> _exitFade;
  late Animation<double> _exitScale;

  // ── Icon bounce ──
  late AnimationController _iconCtrl;
  late Animation<double> _iconSlide;
  late Animation<double> _iconFade;

  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _bg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _setupAnimations();
    _runSequence();
  }

  void _setupAnimations() {
    // Letter entrance — same timing as Cruise (1200ms, staggered ~100ms each)
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _letterSlide = [];
    _letterFade = [];
    _letterScale = [];

    for (int i = 0; i < _letters.length; i++) {
      final start = (i * 0.10).clamp(0.0, 1.0);
      final end = (start + 0.45).clamp(0.0, 1.0);
      final curveI = Interval(start, end, curve: Curves.elasticOut);
      final fadeI = Interval(
        start,
        (start + 0.22).clamp(0.0, 1.0),
        curve: Curves.easeOut,
      );

      _letterSlide.add(
        Tween<double>(
          begin: 60.0,
          end: 0.0,
        ).animate(CurvedAnimation(parent: _entranceCtrl, curve: curveI)),
      );
      _letterFade.add(
        Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: _entranceCtrl, curve: fadeI)),
      );
      _letterScale.add(
        Tween<double>(
          begin: 0.3,
          end: 1.0,
        ).animate(CurvedAnimation(parent: _entranceCtrl, curve: curveI)),
      );
    }

    // Icon enters slightly before letters
    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _iconSlide = Tween<double>(
      begin: -30.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut));
    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconCtrl,
        curve: const Interval(0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Shimmer glow
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Exit
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _exitFade = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInQuart));
    _exitScale = Tween<double>(
      begin: 1.0,
      end: 1.35,
    ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));
  }

  Future<void> _runSequence() async {
    if (_disposed) return;
    await Future.delayed(const Duration(milliseconds: 200));
    if (_disposed) return;

    // Icon bounces in first
    _iconCtrl.forward().catchError((_) {});
    await Future.delayed(const Duration(milliseconds: 250));
    if (_disposed) return;

    // Letters stagger in
    await _entranceCtrl.forward().orCancel.catchError((_) {});
    if (_disposed) return;

    // Shimmer sweep
    await _glowCtrl.forward().orCancel.catchError((_) {});
    if (_disposed) return;

    await Future.delayed(const Duration(milliseconds: 400));
    if (_disposed) return;

    // Scale + fade out
    await _exitCtrl.forward().orCancel.catchError((_) {});
    if (_disposed) return;

    _navigate();
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(smoothFadeRoute(const AuthWrapper(), durationMs: 400));
  }

  @override
  void dispose() {
    _disposed = true;
    _entranceCtrl.dispose();
    _iconCtrl.dispose();
    _glowCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _entranceCtrl,
          _glowCtrl,
          _exitCtrl,
          _iconCtrl,
        ]),
        builder: (_, _) {
          final exitOpacity = (_exitCtrl.isAnimating || _exitCtrl.isCompleted)
              ? _exitFade.value
              : 1.0;
          final exitSc = (_exitCtrl.isAnimating || _exitCtrl.isCompleted)
              ? _exitScale.value
              : 1.0;

          return Opacity(
            opacity: exitOpacity.clamp(0.0, 1.0),
            child: Center(
              child: Transform.scale(
                scale: exitSc,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Icon ──
                    Transform.translate(
                      offset: Offset(0, _iconSlide.value),
                      child: Opacity(
                        opacity: _iconFade.value.clamp(0.0, 1.0),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: _gold,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: _gold.withValues(alpha: 0.45),
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_taxi_rounded,
                            color: Color(0xFF08090C),
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // ── Staggered letters ──
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_letters.length, (i) {
                        final dy = _letterSlide[i].value;
                        final opacity = _letterFade[i].value.clamp(0.0, 1.0);
                        final scale = _letterScale[i].value.clamp(0.0, 2.0);

                        // Shimmer sweep L→R
                        final glowProgress = _glowCtrl.value;
                        final letterCenter = i / (_letters.length - 1);
                        final dist = (glowProgress - letterCenter).abs();
                        final glowAmount =
                            (1.0 - (dist / 0.35).clamp(0.0, 1.0));
                        final letterColor = Color.lerp(
                          _gold,
                          _goldBright,
                          glowAmount * (_glowCtrl.isAnimating ? 1.0 : 0.0),
                        )!;
                        final shadowOpacity =
                            (glowAmount *
                                    0.7 *
                                    (_glowCtrl.isAnimating ? 1.0 : 0.0))
                                .clamp(0.0, 1.0);

                        return Transform.translate(
                          offset: Offset(0, dy),
                          child: Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: scale,
                              child: Text(
                                _letters[i],
                                style: TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                  color: letterColor,
                                  shadows: [
                                    Shadow(
                                      color: _gold.withValues(
                                        alpha: shadowOpacity,
                                      ),
                                      blurRadius: 24,
                                    ),
                                    Shadow(
                                      color: _goldBright.withValues(
                                        alpha: shadowOpacity * 0.5,
                                      ),
                                      blurRadius: 48,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    // ── Subtitle ──
                    Opacity(
                      opacity: _entranceCtrl.value.clamp(0.0, 1.0),
                      child: Text(
                        'Dispatch  ·  Admin',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3.0,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
