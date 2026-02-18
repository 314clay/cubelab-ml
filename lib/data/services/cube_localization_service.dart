import 'dart:typed_data';
import 'dart:ui';

/// Abstract interface for cube localization in camera images.
/// Detects the cube position and individual sticker bounding boxes
/// from a photo, enabling the overlay painter to align with the real cube.
abstract class CubeLocalizationService {
  /// Detect the cube in the image and return sticker regions.
  /// Returns null if no cube is found.
  Future<CubeLocalization?> localize(Uint8List imageBytes);
}

/// Result of cube localization containing the detected cube position
/// and individual sticker bounding boxes for all 27 visible stickers.
class CubeLocalization {
  /// Bounding rect of the entire cube in the image (normalized 0-1 coords).
  final Rect cubeBounds;

  /// 27 sticker regions in order: U-face (9), F-face (9), R-face (9).
  /// Each rect is in normalized image coordinates (0-1).
  final List<Rect> stickerRegions;

  /// Corner points of each face (4 corners per face, 3 faces).
  /// Used for perspective-correct overlay rendering.
  final List<List<Offset>> faceCorners;

  /// Detection confidence (0-1).
  final double confidence;

  const CubeLocalization({
    required this.cubeBounds,
    required this.stickerRegions,
    required this.faceCorners,
    required this.confidence,
  });

  factory CubeLocalization.fromJson(Map<String, dynamic> json) {
    return CubeLocalization(
      cubeBounds: _rectFromJson(json['cubeBounds'] as Map<String, dynamic>),
      stickerRegions: (json['stickerRegions'] as List)
          .map((r) => _rectFromJson(r as Map<String, dynamic>))
          .toList(),
      faceCorners: (json['faceCorners'] as List)
          .map((face) => (face as List)
              .map((p) => Offset(
                    (p['x'] as num).toDouble(),
                    (p['y'] as num).toDouble(),
                  ))
              .toList())
          .toList(),
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cubeBounds': _rectToJson(cubeBounds),
      'stickerRegions': stickerRegions.map(_rectToJson).toList(),
      'faceCorners': faceCorners
          .map((face) => face.map((p) => {'x': p.dx, 'y': p.dy}).toList())
          .toList(),
      'confidence': confidence,
    };
  }

  static Rect _rectFromJson(Map<String, dynamic> json) {
    return Rect.fromLTWH(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
      (json['w'] as num).toDouble(),
      (json['h'] as num).toDouble(),
    );
  }

  static Map<String, dynamic> _rectToJson(Rect rect) {
    return {
      'x': rect.left,
      'y': rect.top,
      'w': rect.width,
      'h': rect.height,
    };
  }
}

/// Stub implementation that returns a fixed localization
/// centered in the image, useful for testing overlays.
class StubCubeLocalizationService implements CubeLocalizationService {
  @override
  Future<CubeLocalization?> localize(Uint8List imageBytes) async {
    // Return a fixed cube position centered in the frame
    final regions = <Rect>[];
    final cellSize = 0.08;
    final gap = 0.01;

    // U-face: top-center
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        regions.add(Rect.fromLTWH(
          0.35 + col * (cellSize + gap),
          0.15 + row * (cellSize + gap),
          cellSize,
          cellSize,
        ));
      }
    }

    // F-face: bottom-left
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        regions.add(Rect.fromLTWH(
          0.2 + col * (cellSize + gap),
          0.45 + row * (cellSize + gap),
          cellSize,
          cellSize,
        ));
      }
    }

    // R-face: bottom-right
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        regions.add(Rect.fromLTWH(
          0.55 + col * (cellSize + gap),
          0.45 + row * (cellSize + gap),
          cellSize,
          cellSize,
        ));
      }
    }

    return CubeLocalization(
      cubeBounds: const Rect.fromLTWH(0.15, 0.1, 0.7, 0.7),
      stickerRegions: regions,
      faceCorners: [
        // U-face corners
        [const Offset(0.35, 0.15), const Offset(0.62, 0.15),
         const Offset(0.62, 0.42), const Offset(0.35, 0.42)],
        // F-face corners
        [const Offset(0.2, 0.45), const Offset(0.47, 0.45),
         const Offset(0.47, 0.72), const Offset(0.2, 0.72)],
        // R-face corners
        [const Offset(0.55, 0.45), const Offset(0.82, 0.45),
         const Offset(0.82, 0.72), const Offset(0.55, 0.72)],
      ],
      confidence: 0.95,
    );
  }
}
