import 'dart:ui';

class YoloResult {
  final Rect rect;
  final double confidence;
  final int classIndex;

  YoloResult({
    required this.rect,
    required this.confidence,
    required this.classIndex,
  });
}
