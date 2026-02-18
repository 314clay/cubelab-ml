import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cubelab/core/theme/app_colors.dart';

/// CustomPainter that draws a 3x3 grid overlay highlighting stickers
/// based on the detected phase (OLL, PLL, solved).
class StickerOverlayPainter extends CustomPainter {
  /// 27 sticker colors in order: U-face (9), F-face (9), R-face (9)
  final List<String> visible27;

  /// Detected phase: 'oll', 'pll', 'solved', etc.
  final String phase;

  StickerOverlayPainter({
    required this.visible27,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (visible27.length != 27) return;

    final uFace = visible27.sublist(0, 9);
    final fFace = visible27.sublist(9, 18);
    final rFace = visible27.sublist(18, 27);

    // Layout: U-face top-center, F-face bottom-left, R-face bottom-right
    // as seen from a 3/4 angle view of the cube
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final cellSize = math.min(size.width, size.height) / 12;

    _drawFaceGrid(canvas, uFace, centerX - cellSize * 1.5, centerY - cellSize * 3.5, cellSize, phase, 'U');
    _drawFaceGrid(canvas, fFace, centerX - cellSize * 3.5, centerY - cellSize * 0.5, cellSize, phase, 'F');
    _drawFaceGrid(canvas, rFace, centerX + cellSize * 0.5, centerY - cellSize * 0.5, cellSize, phase, 'R');
  }

  void _drawFaceGrid(
    Canvas canvas,
    List<String> face,
    double startX,
    double startY,
    double cellSize,
    String phase,
    String faceLabel,
  ) {
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        final index = row * 3 + col;
        final sticker = face[index];
        final rect = Rect.fromLTWH(
          startX + col * cellSize,
          startY + row * cellSize,
          cellSize,
          cellSize,
        );

        final highlight = _getHighlightColor(sticker, phase, faceLabel, index);

        // Draw sticker fill
        final fillPaint = Paint()
          ..color = highlight.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          fillPaint,
        );

        // Draw sticker border
        final borderPaint = Paint()
          ..color = highlight.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          borderPaint,
        );
      }
    }
  }

  Color _getHighlightColor(String sticker, String phase, String face, int index) {
    switch (phase) {
      case 'oll':
        // OLL: U-face white stickers are correct (green), non-white are wrong (orange)
        if (face == 'U') {
          return sticker == 'W' ? AppColors.success : const Color(0xFFFFA726);
        }
        // F/R face: top row shows misorientation
        if (index < 3) {
          return sticker == _expectedCenter(face)
              ? AppColors.success
              : const Color(0xFFFFA726);
        }
        return AppColors.success;

      case 'pll':
        // PLL: U-face all white (correct), side stickers may be swapped
        if (face == 'U') return AppColors.success;
        // Side faces: top row may have mispositioned stickers
        if (index < 3) {
          return sticker == _expectedCenter(face)
              ? AppColors.success
              : const Color(0xFFFFC107);
        }
        return AppColors.success;

      case 'solved':
        return AppColors.success;

      default:
        return AppColors.textTertiary;
    }
  }

  /// Get the expected center color for a face.
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

  @override
  bool shouldRepaint(StickerOverlayPainter oldDelegate) {
    return oldDelegate.visible27 != visible27 || oldDelegate.phase != phase;
  }
}
