// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

/// Generate a white rounded-rect icon with bold black "Cruise" text
/// for both launcher_icon.png (1024x1024) and foreground (1024x1024).
void main() {
  const size = 1024;
  final bgColor = img.ColorRgba8(255, 255, 255, 255); // white
  final textColor = img.ColorRgba8(0, 0, 0, 255); // black

  // --- Main icon (full with rounded corners) ---
  final icon = img.Image(width: size, height: size);
  img.fill(icon, color: img.ColorRgba8(0, 0, 0, 0)); // transparent bg

  // Draw white rounded rect
  const r = 180; // corner radius
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      if (_inRoundedRect(x, y, 0, 0, size, size, r)) {
        icon.setPixel(x, y, bgColor);
      }
    }
  }

  // Draw "Cruise" text centered using built-in bitmap font
  final font = img.arial48;
  const text = 'Cruise';

  // Measure text width approximately
  int textWidth = 0;
  for (int i = 0; i < text.length; i++) {
    final ch = text.codeUnitAt(i);
    if (font.characters.containsKey(ch)) {
      textWidth += font.characters[ch]!.xAdvance;
    }
  }
  final textHeight = font.lineHeight;

  // Scale: we want text to be ~45% of icon width
  final targetWidth = (size * 0.45).round();
  final scale = targetWidth / textWidth;

  // Draw text at a temporary small image, then scale it up
  final tmpW = textWidth + 10;
  final tmpH = textHeight + 10;
  final tmp = img.Image(width: tmpW, height: tmpH);
  img.fill(tmp, color: img.ColorRgba8(255, 255, 255, 0));
  img.drawString(tmp, text, font: font, x: 5, y: 5, color: textColor);

  // Scale the text image
  final scaledW = (tmpW * scale).round();
  final scaledH = (tmpH * scale).round();
  final scaledText = img.copyResize(
    tmp,
    width: scaledW,
    height: scaledH,
    interpolation: img.Interpolation.cubic,
  );

  // Composite onto icon centered
  final ox = (size - scaledW) ~/ 2;
  final oy = (size - scaledH) ~/ 2;
  img.compositeImage(icon, scaledText, dstX: ox, dstY: oy);

  // Save main icon
  File('assets/launcher_icon.png').writeAsBytesSync(img.encodePng(icon));
  print('✓ assets/launcher_icon.png');

  // --- Foreground (for adaptive icon, same but on transparent bg) ---
  // Adaptive icons need ~66% safe zone in center of 108dp canvas
  final fg = img.Image(width: size, height: size);
  img.fill(fg, color: img.ColorRgba8(255, 255, 255, 0));

  // Slightly smaller text for adaptive safe zone (inner ~66%)
  final safeScale = scale * 0.72;
  final safeSW = (tmpW * safeScale).round();
  final safeSH = (tmpH * safeScale).round();
  final safeText = img.copyResize(
    tmp,
    width: safeSW,
    height: safeSH,
    interpolation: img.Interpolation.cubic,
  );
  final sox = (size - safeSW) ~/ 2;
  final soy = (size - safeSH) ~/ 2;
  img.compositeImage(fg, safeText, dstX: sox, dstY: soy);

  File(
    'assets/launcher_icon_foreground.png',
  ).writeAsBytesSync(img.encodePng(fg));
  print('✓ assets/launcher_icon_foreground.png');
}

bool _inRoundedRect(int x, int y, int left, int top, int w, int h, int radius) {
  final right = left + w;
  final bottom = top + h;
  if (x < left || x >= right || y < top || y >= bottom) return false;

  // Check corners
  final corners = [
    [left + radius, top + radius],
    [right - radius - 1, top + radius],
    [left + radius, bottom - radius - 1],
    [right - radius - 1, bottom - radius - 1],
  ];

  for (final c in corners) {
    final cx = c[0], cy = c[1];
    final inCornerX =
        (x < left + radius && cx == left + radius) ||
        (x >= right - radius && cx == right - radius - 1);
    final inCornerY =
        (y < top + radius && cy == top + radius) ||
        (y >= bottom - radius && cy == bottom - radius - 1);
    if (inCornerX && inCornerY) {
      final dx = x - cx;
      final dy = y - cy;
      if (sqrt(dx * dx + dy * dy) > radius) return false;
    }
  }
  return true;
}
