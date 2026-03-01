import 'package:flutter/material.dart';

/// Premium page transitions — identical to Cruise passenger app.
/// Tuned for 60fps buttery-smooth feel.

// ─── Slide up + Fade (Dashboard → Detail) ────────────────────────────────
Route<T> slideUpFadeRoute<T>(Widget page, {int durationMs = 450}) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, animation, __) => page,
    transitionDuration: Duration(milliseconds: durationMs),
    reverseTransitionDuration: Duration(milliseconds: (durationMs * 0.75).round()),
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0, 0.7, curve: Curves.easeOut),
            ),
          ),
          child: child,
        ),
      );
    },
  );
}

// ─── Scale + Fade (FAB → Create Trip) ────────────────────────────────────
Route<T> scaleExpandRoute<T>(Widget page, {int durationMs = 500}) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, animation, __) => page,
    transitionDuration: Duration(milliseconds: durationMs),
    reverseTransitionDuration: Duration(milliseconds: (durationMs * 0.65).round()),
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutExpo,
        reverseCurve: Curves.easeInExpo,
      );
      return FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0, 0.5, curve: Curves.easeOut),
          ),
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

// ─── Shared-axis vertical (Trip receipt / detail) ─────────────────────────
Route<T> sharedAxisVerticalRoute<T>(Widget page, {int durationMs = 450}) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, animation, __) => page,
    transitionDuration: Duration(milliseconds: durationMs),
    reverseTransitionDuration: Duration(milliseconds: (durationMs * 0.7).round()),
    transitionsBuilder: (_, animation, __, child) {
      final fadeIn = CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      );
      final slideIn = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: fadeIn,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(slideIn),
          child: child,
        ),
      );
    },
  );
}

// ─── Smooth Fade (Splash → Home) ─────────────────────────────────────────
Route<T> smoothFadeRoute<T>(Widget page, {int durationMs = 700}) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, animation, __) => page,
    transitionDuration: Duration(milliseconds: durationMs),
    reverseTransitionDuration: Duration(milliseconds: (durationMs * 0.6).round()),
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.03, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

// ─── Slide from right (General navigation) ───────────────────────────────
Route<T> slideFromRightRoute<T>(Widget page, {int durationMs = 400}) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, animation, __) => page,
    transitionDuration: Duration(milliseconds: durationMs),
    reverseTransitionDuration: Duration(milliseconds: (durationMs * 0.7).round()),
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.20, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.3, end: 1).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0, 0.6, curve: Curves.easeOut),
            ),
          ),
          child: child,
        ),
      );
    },
  );
}
