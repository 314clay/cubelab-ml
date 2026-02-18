import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cubelab/core/theme/app_colors.dart';

/// CustomPainter that draws a 3-face cube diagram with actual sticker colors
/// and phase-based highlight borders (OLL, PLL, solved).
class StickerOverlayPainter extends CustomPainter {
  /// 27 sticker colors in order: U-face (9), F-face (9), R-face (9)
  final List<String> visible27;

  /// Detected phase: 'oll', 'pll', 'solved', etc.
  final String phase;

  StickerOverlayPainter({
    required this.visible27,
    required this.phase,
  });

  static const _stickerColors = {
    'W': Color(0xFFFFFFFF), // White
    'Y': Color(0xFFFFEB3B), // Yellow
    'R': Color(0xFFE53935), // Red
    'O': Color(0xFFFF9800), // Orange
    'B': Color(0xFF1E88E5), // Blue
    'G': Color(0xFF43A047), // Green
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (visible27.length != 27) return;

    final uFace = visible27.sublist(0, 9);
    final fFace = visible27.sublist(9, 18);
    final rFace = visible27.sublist(18, 27);

    final cellSize = math.min(size.width, size.height) / 10;
    final gap = cellSize * 0.08;

    // Position the three face grids to resemble a cube net:
    // U-face centered above, F-face below-left, R-face below-right
    final centerX = size.width / 2;
    final topY = size.height * 0.08;

    // U face: centered at top
    _drawFaceGrid(
      canvas, uFace,
      centerX - cellSize * 1.5, topY,
      cellSize, gap, 'U',
    );

    // F face: below U, shifted left
    _drawFaceGrid(
      canvas, fFace,
      centerX - cellSize * 3.3, topY + cellSize * 3 + cellSize * 0.3,
      cellSize, gap, 'F',
    );

    // R face: below U, shifted right
    _drawFaceGrid(
      canvas, rFace,
      centerX + cellSize * 0.3, topY + cellSize * 3 + cellSize * 0.3,
      cellSize, gap, 'R',
    );

    // Draw face labels
    final labelStyle = TextStyle(
      color: AppColors.textTertiary,
      fontSize: cellSize * 0.4,
      fontWeight: FontWeight.w600,
    );

    _drawLabel(canvas, 'U', centerX, topY - cellSize * 0.25, labelStyle);
    _drawLabel(canvas, 'F', centerX - cellSize * 1.8, topY + cellSize * 3.15, labelStyle);
    _drawLabel(canvas, 'R', centerX + cellSize * 1.8, topY + cellSize * 3.15, labelStyle);
  }

  void _drawFaceGrid(
    Canvas canvas,
    List<String> face,
    double startX,
    double startY,
    double cellSize,
    double gap,
    String faceLabel,
  ) {
    // Draw face background
    final bgRect = Rect.fromLTWH(
      startX - gap,
      startY - gap,
      cellSize * 3 + gap * 2,
      cellSize * 3 + gap * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
      Paint()..color = const Color(0xFF2C2C2C),
    );

    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        final index = row * 3 + col;
        final sticker = face[index];

        final rect = Rect.fromLTWH(
          startX + col * cellSize + gap,
          startY + row * cellSize + gap,
          cellSize - gap * 2,
          cellSize - gap * 2,
        );

        // Draw sticker color
        final stickerColor = _stickerColors[sticker] ?? AppColors.textTertiary;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = stickerColor,
        );

        // Draw phase-based highlight border
        final highlight = _getHighlightColor(sticker, faceLabel, index);
        if (highlight != null) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              rect.inflate(1),
              const Radius.circular(4),
            ),
            Paint()
              ..color = highlight
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5,
          );
        }
      }
    }
  }

  /// Returns highlight border color, or null for no highlight.
  Color? _getHighlightColor(String sticker, String face, int index) {
    switch (phase) {
      case 'oll':
        if (face == 'U') {
          // OLL: green border on correct white stickers, orange on misoriented
          return sticker == 'W'
              ? AppColors.success.withValues(alpha: 0.8)
              : const Color(0xFFFFA726);
        }
        // Side faces: highlight top row misoriented stickers
        if (index < 3) {
          final expected = _expectedCenter(face);
          return sticker != expected ? const Color(0xFFFFA726) : null;
        }
        return null;

      case 'pll':
        if (face == 'U') return null; // U-face is all white, no highlight needed
        // Side faces: amber on mispositioned top-row stickers
        if (index < 3) {
          final expected = _expectedCenter(face);
          return sticker != expected ? const Color(0xFFFFC107) : null;
        }
        return null;

      case 'solved':
        // All green borders
        return AppColors.success.withValues(alpha: 0.6);

      default:
        return null;
    }
  }

  String _expectedCenter(String face) {
    switch (face) {
      case 'U': return 'W';
      case 'D': return 'Y';
      case 'F': return 'R';
      case 'R': return 'B';
      case 'B': return 'O';
      case 'L': return 'G';
      default: return 'W';
    }
  }

  void _drawLabel(Canvas canvas, String text, double x, double y, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(StickerOverlayPainter oldDelegate) {
    return oldDelegate.visible27 != visible27 || oldDelegate.phase != phase;
  }
}
