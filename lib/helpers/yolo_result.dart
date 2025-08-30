import 'dart:math';
import 'dart:ui';

import 'package:tiktok_privacy/models/yolo_result_model.dart';

class YoloHelper {
  List<YoloResult> processYoloOutput(
    List<List<List<double>>> output,
    int imgWidth,
    int imgHeight, {
    double confidenceThreshold = 0.4,
    double iouThreshold = 0.5,
  }) {
    final results = <YoloResult>[];

    for (var prediction in output[0]) {
      final x = prediction[0];
      final y = prediction[1];
      final w = prediction[2];
      final h = prediction[3];
      final objectness = prediction[4];

      // class probabilities
      final classScores = prediction.sublist(5);
      final classIndex = classScores.indexWhere(
        (s) => s == classScores.reduce(max),
      );
      final confidence = objectness * classScores[classIndex];

      if (confidence > confidenceThreshold) {
        final rect = Rect.fromLTWH(
          (x - w / 2) * imgWidth,
          (y - h / 2) * imgHeight,
          w * imgWidth,
          h * imgHeight,
        );
        results.add(
          YoloResult(
            rect: rect,
            confidence: confidence,
            classIndex: classIndex,
          ),
        );
      }
    }

    // Apply NMS
    return nonMaxSuppression(results, iouThreshold);
  }

  List<YoloResult> nonMaxSuppression(
    List<YoloResult> boxes,
    double iouThreshold,
  ) {
    boxes.sort((a, b) => b.confidence.compareTo(a.confidence));
    final picked = <YoloResult>[];

    while (boxes.isNotEmpty) {
      final current = boxes.removeAt(0);
      picked.add(current);

      boxes.removeWhere(
        (other) => iou(current.rect, other.rect) > iouThreshold,
      );
    }
    return picked;
  }

  double iou(Rect a, Rect b) {
    final inter = a.intersect(b);
    final interArea = inter.width * inter.height;
    if (interArea <= 0) return 0.0;
    final unionArea = a.width * a.height + b.width * b.height - interArea;
    return interArea / unionArea;
  }
}
