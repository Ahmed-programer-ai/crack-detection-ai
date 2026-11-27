import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'crack_classification_service.dart';
import 'image_preprocessing_service.dart';

class SegmentationResult {
  const SegmentationResult({
    required this.status,
    required this.confidence,
    required this.mask,
    required this.overlayPng,
    required this.measurements,
  });

  final String status;
  final double confidence;
  final Uint8List mask;
  final Uint8List? overlayPng;
  final Map<String, Object?> measurements;
}

class _Detection {
  const _Detection({
    required this.confidence,
    required this.box,
    required this.maskCoefficients,
  });

  final double confidence;
  final List<double> box;
  final Float32List maskCoefficients;
}

class CrackSegmentationService {
  static const int _candidateCount = 8400;
  static const int _prototypeChannels = 32;
  static const int _prototypeSize = 160;
  static const double lowConfidence = 0.10;
  static const double highConfidence = 0.40;
  static const double _nmsIou = 0.70;

  SegmentationResult process(RawModelOutput output, PreparedImage prepared) {
    final candidates = <_Detection>[];
    var maxConfidence = 0.0;
    for (var index = 0; index < _candidateCount; index++) {
      final confidence = output.detections[4 * _candidateCount + index];
      if (confidence < lowConfidence) continue;
      maxConfidence = math.max(maxConfidence, confidence);
      final cx = output.detections[index];
      final cy = output.detections[_candidateCount + index];
      final width = output.detections[2 * _candidateCount + index];
      final height = output.detections[3 * _candidateCount + index];
      final coefficients = Float32List(_prototypeChannels);
      for (var channel = 0; channel < _prototypeChannels; channel++) {
        coefficients[channel] =
            output.detections[(5 + channel) * _candidateCount + index];
      }
      candidates.add(
        _Detection(
          confidence: confidence,
          box: [
            cx - width / 2,
            cy - height / 2,
            cx + width / 2,
            cy + height / 2,
          ],
          maskCoefficients: coefficients,
        ),
      );
    }
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    final detections = _nonMaximumSuppression(candidates);
    final status = maxConfidence < lowConfidence
        ? 'no_detection'
        : maxConfidence >= highConfidence
        ? 'detected'
        : 'possible';

    final resultMask = Uint8List(prepared.image.width * prepared.image.height);
    if (status == 'detected') {
      for (final detection in detections.where(
        (item) => item.confidence >= highConfidence,
      )) {
        _addDetectionMask(output.prototypes, detection, resultMask, prepared);
      }
    }
    final features = _measure(
      resultMask,
      prepared.image.width,
      prepared.image.height,
      prepared.sourceWidth,
      prepared.sourceHeight,
      prepared.pixelScaleFactor,
    );
    final overlay =
        status == 'detected' && resultMask.any((value) => value != 0)
        ? _makeOverlay(prepared.image, resultMask)
        : null;

    return SegmentationResult(
      status: status,
      confidence: maxConfidence,
      mask: resultMask,
      overlayPng: overlay,
      measurements: features,
    );
  }

  List<_Detection> _nonMaximumSuppression(List<_Detection> candidates) {
    final kept = <_Detection>[];
    for (final candidate in candidates) {
      if (kept.every(
        (other) => _intersectionOverUnion(candidate.box, other.box) <= _nmsIou,
      )) {
        kept.add(candidate);
        if (kept.length == 300) break;
      }
    }
    return kept;
  }

  double _intersectionOverUnion(List<double> a, List<double> b) {
    final left = math.max(a[0], b[0]);
    final top = math.max(a[1], b[1]);
    final right = math.min(a[2], b[2]);
    final bottom = math.min(a[3], b[3]);
    final intersection =
        math.max(0.0, right - left) * math.max(0.0, bottom - top);
    final areaA = math.max(0.0, a[2] - a[0]) * math.max(0.0, a[3] - a[1]);
    final areaB = math.max(0.0, b[2] - b[0]) * math.max(0.0, b[3] - b[1]);
    final union = areaA + areaB - intersection;
    return union <= 0 ? 0 : intersection / union;
  }

  void _addDetectionMask(
    Float32List prototypes,
    _Detection detection,
    Uint8List target,
    PreparedImage prepared,
  ) {
    final lowResolution = Float32List(_prototypeSize * _prototypeSize);
    for (var y = 0; y < _prototypeSize; y++) {
      for (var x = 0; x < _prototypeSize; x++) {
        var logit = 0.0;
        final pixel = y * _prototypeSize + x;
        for (var channel = 0; channel < _prototypeChannels; channel++) {
          logit +=
              detection.maskCoefficients[channel] *
              prototypes[channel * _prototypeSize * _prototypeSize + pixel];
        }
        lowResolution[pixel] = logit;
      }
    }

    final x1 = detection.box[0];
    final y1 = detection.box[1];
    final x2 = detection.box[2];
    final y2 = detection.box[3];
    final imageWidth = prepared.image.width;
    final imageHeight = prepared.image.height;
    for (var y = 0; y < imageHeight; y++) {
      final modelY = prepared.padTop + (y + 0.5) * prepared.scale;
      if (modelY < y1 || modelY >= y2) continue;
      final protoY = ((modelY + 0.5) / 4 - 0.5).clamp(
        0.0,
        _prototypeSize - 1.0,
      );
      final y0 = protoY.floor();
      final y1p = math.min(y0 + 1, _prototypeSize - 1);
      final fy = protoY - y0;
      for (var x = 0; x < imageWidth; x++) {
        final modelX = prepared.padLeft + (x + 0.5) * prepared.scale;
        if (modelX < x1 || modelX >= x2) continue;
        final protoX = ((modelX + 0.5) / 4 - 0.5).clamp(
          0.0,
          _prototypeSize - 1.0,
        );
        final x0 = protoX.floor();
        final x1p = math.min(x0 + 1, _prototypeSize - 1);
        final fx = protoX - x0;
        final top =
            lowResolution[y0 * _prototypeSize + x0] * (1 - fx) +
            lowResolution[y0 * _prototypeSize + x1p] * fx;
        final bottom =
            lowResolution[y1p * _prototypeSize + x0] * (1 - fx) +
            lowResolution[y1p * _prototypeSize + x1p] * fx;
        if (top * (1 - fy) + bottom * fy > 0) {
          target[y * imageWidth + x] = 1;
        }
      }
    }
  }

  Map<String, Object?> _measure(
    Uint8List mask,
    int width,
    int height,
    int sourceWidth,
    int sourceHeight,
    double pixelScaleFactor,
  ) {
    final cleaned = _removeSmallComponents(mask, width, height, 20);
    final skeleton = _skeletonize(cleaned, width, height);
    final distances = _distanceTransform(cleaned, width, height);
    final widths = <double>[];
    for (var i = 0; i < skeleton.length; i++) {
      if (skeleton[i] != 0) {
        widths.add(math.max(1, distances[i] * 2 - 1));
      }
    }
    widths.sort();
    final length = _skeletonLength(skeleton, width, height);
    final area = cleaned.where((value) => value != 0).length;
    final merged = _closeGaps(cleaned, width, height);
    final components = _componentCount(merged, width, height);
    return {
      'image_h': sourceHeight,
      'image_w': sourceWidth,
      'area_ratio': area / (width * height),
      'n_cracks': components,
      'length_px': length * pixelScaleFactor,
      'length_ratio': length / math.sqrt(width * width + height * height),
      'width_max_px': widths.isEmpty ? 0.0 : widths.last * pixelScaleFactor,
      'width_p95_px': widths.isEmpty
          ? 0.0
          : widths[((widths.length * 0.95).ceil() - 1).clamp(
                  0,
                  widths.length - 1,
                )] *
                pixelScaleFactor,
      'orientation': _orientation(skeleton, width),
    };
  }

  Uint8List _removeSmallComponents(
    Uint8List mask,
    int width,
    int height,
    int minimumArea,
  ) {
    final output = Uint8List(mask.length);
    final visited = Uint8List(mask.length);
    final queue = Int32List(mask.length);
    for (var start = 0; start < mask.length; start++) {
      if (mask[start] == 0 || visited[start] != 0) continue;
      var head = 0;
      var tail = 0;
      queue[tail++] = start;
      visited[start] = 1;
      while (head < tail) {
        final index = queue[head++];
        final x = index % width;
        final y = index ~/ width;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = x + dx;
            final ny = y + dy;
            if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
            final next = ny * width + nx;
            if (mask[next] != 0 && visited[next] == 0) {
              visited[next] = 1;
              queue[tail++] = next;
            }
          }
        }
      }
      if (tail >= minimumArea) {
        for (var i = 0; i < tail; i++) {
          output[queue[i]] = 1;
        }
      }
    }
    return output;
  }

  int _componentCount(Uint8List mask, int width, int height) {
    final visited = Uint8List(mask.length);
    final queue = Int32List(mask.length);
    var count = 0;
    for (var start = 0; start < mask.length; start++) {
      if (mask[start] == 0 || visited[start] != 0) continue;
      count++;
      var head = 0;
      var tail = 0;
      queue[tail++] = start;
      visited[start] = 1;
      while (head < tail) {
        final index = queue[head++];
        final x = index % width;
        final y = index ~/ width;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = x + dx;
            final ny = y + dy;
            if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
            final next = ny * width + nx;
            if (mask[next] != 0 && visited[next] == 0) {
              visited[next] = 1;
              queue[tail++] = next;
            }
          }
        }
      }
    }
    return count;
  }

  Uint8List _closeGaps(Uint8List mask, int width, int height) {
    const kernel = [
      [0, -2],
      [-2, -1],
      [-1, -1],
      [0, -1],
      [1, -1],
      [2, -1],
      [-2, 0],
      [-1, 0],
      [0, 0],
      [1, 0],
      [2, 0],
      [-2, 1],
      [-1, 1],
      [0, 1],
      [1, 1],
      [2, 1],
      [0, 2],
    ];
    final dilated = Uint8List(mask.length);
    final closed = Uint8List(mask.length);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = y * width + x;
        if (mask[index] == 0) continue;
        for (final offset in kernel) {
          final nx = x + offset[0];
          final ny = y + offset[1];
          if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
            dilated[ny * width + nx] = 1;
          }
        }
      }
    }
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var allSet = true;
        for (final offset in kernel) {
          final nx = x + offset[0];
          final ny = y + offset[1];
          if (nx >= 0 &&
              nx < width &&
              ny >= 0 &&
              ny < height &&
              dilated[ny * width + nx] == 0) {
            allSet = false;
            break;
          }
        }
        if (allSet) closed[y * width + x] = 1;
      }
    }
    return closed;
  }

  Uint8List _skeletonize(Uint8List mask, int width, int height) {
    final skeleton = Uint8List.fromList(mask);
    final remove = <int>[];
    var changed = true;
    while (changed) {
      changed = false;
      for (var phase = 0; phase < 2; phase++) {
        remove.clear();
        for (var y = 1; y < height - 1; y++) {
          for (var x = 1; x < width - 1; x++) {
            final index = y * width + x;
            if (skeleton[index] == 0) continue;
            final p2 = skeleton[index - width] != 0;
            final p3 = skeleton[index - width + 1] != 0;
            final p4 = skeleton[index + 1] != 0;
            final p5 = skeleton[index + width + 1] != 0;
            final p6 = skeleton[index + width] != 0;
            final p7 = skeleton[index + width - 1] != 0;
            final p8 = skeleton[index - 1] != 0;
            final p9 = skeleton[index - width - 1] != 0;
            final neighbors = [p2, p3, p4, p5, p6, p7, p8, p9];
            final count = neighbors.where((item) => item).length;
            if (count < 2 || count > 6) continue;
            var transitions = 0;
            for (var i = 0; i < neighbors.length; i++) {
              if (!neighbors[i] && neighbors[(i + 1) % neighbors.length]) {
                transitions++;
              }
            }
            if (transitions != 1) continue;
            final conditionA = phase == 0 ? p2 && p4 && p6 : p2 && p4 && p8;
            final conditionB = phase == 0 ? p4 && p6 && p8 : p2 && p6 && p8;
            if (!conditionA && !conditionB) remove.add(index);
          }
        }
        if (remove.isNotEmpty) {
          changed = true;
          for (final index in remove) {
            skeleton[index] = 0;
          }
        }
      }
    }
    return skeleton;
  }

  Float32List _distanceTransform(Uint8List mask, int width, int height) {
    const diagonal = 1.41421356237;
    const infinity = 1000000.0;
    final distances = Float32List(mask.length);
    for (var i = 0; i < mask.length; i++) {
      final x = i % width;
      final y = i ~/ width;
      distances[i] =
          mask[i] == 0 || x == 0 || x == width - 1 || y == 0 || y == height - 1
          ? 0
          : infinity;
    }
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = y * width + x;
        if (distances[index] == 0) continue;
        var value = distances[index];
        if (x > 0) value = math.min(value, distances[index - 1] + 1);
        if (y > 0) value = math.min(value, distances[index - width] + 1);
        if (x > 0 && y > 0) {
          value = math.min(value, distances[index - width - 1] + diagonal);
        }
        if (x + 1 < width && y > 0) {
          value = math.min(value, distances[index - width + 1] + diagonal);
        }
        distances[index] = value;
      }
    }
    for (var y = height - 1; y >= 0; y--) {
      for (var x = width - 1; x >= 0; x--) {
        final index = y * width + x;
        if (distances[index] == 0) continue;
        var value = distances[index];
        if (x + 1 < width) value = math.min(value, distances[index + 1] + 1);
        if (y + 1 < height) {
          value = math.min(value, distances[index + width] + 1);
        }
        if (x + 1 < width && y + 1 < height) {
          value = math.min(value, distances[index + width + 1] + diagonal);
        }
        if (x > 0 && y + 1 < height) {
          value = math.min(value, distances[index + width - 1] + diagonal);
        }
        distances[index] = value;
      }
    }
    return distances;
  }

  double _skeletonLength(Uint8List mask, int width, int height) {
    var length = 0.0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = y * width + x;
        if (x + 1 < width && mask[index] != 0 && mask[index + 1] != 0) {
          length++;
        }
        if (y + 1 < height && mask[index] != 0 && mask[index + width] != 0) {
          length++;
        }
        if (x + 1 < width &&
            y + 1 < height &&
            mask[index] != 0 &&
            mask[index + width + 1] != 0 &&
            mask[index + 1] == 0 &&
            mask[index + width] == 0) {
          length += math.sqrt2;
        }
        if (x + 1 < width &&
            y + 1 < height &&
            mask[index + 1] != 0 &&
            mask[index + width] != 0 &&
            mask[index] == 0 &&
            mask[index + width + 1] == 0) {
          length += math.sqrt2;
        }
      }
    }
    return length;
  }

  String? _orientation(Uint8List skeleton, int width) {
    var count = 0;
    var meanX = 0.0;
    var meanY = 0.0;
    for (var i = 0; i < skeleton.length; i++) {
      if (skeleton[i] == 0) continue;
      count++;
      meanX += i % width;
      meanY += i ~/ width;
    }
    if (count < 10) return null;
    meanX /= count;
    meanY /= count;
    var xx = 0.0;
    var yy = 0.0;
    var xy = 0.0;
    for (var i = 0; i < skeleton.length; i++) {
      if (skeleton[i] == 0) continue;
      final dx = i % width - meanX;
      final dy = i ~/ width - meanY;
      xx += dx * dx;
      yy += dy * dy;
      xy += dx * dy;
    }
    final trace = xx + yy;
    final discriminant = math.sqrt((xx - yy) * (xx - yy) + 4 * xy * xy);
    final major = (trace + discriminant) / 2;
    final minor = (trace - discriminant) / 2;
    if (minor > 1e-9 && major / minor < 2) return 'mixed';
    final angle = (math.atan2(major - xx, xy) * 180 / math.pi) % 180;
    if ((angle - 90).abs() <= 22.5) return 'vertical';
    if (angle <= 22.5 || angle >= 157.5) return 'horizontal';
    return 'diagonal';
  }

  Uint8List _makeOverlay(img.Image source, Uint8List mask) {
    final overlay = img.Image.from(source);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        if (mask[y * source.width + x] == 0) continue;
        final pixel = source.getPixel(x, y);
        overlay.setPixelRgb(
          x,
          y,
          math.min(255, (pixel.r * 0.55 + 114).round()),
          (pixel.g * 0.55).round(),
          (pixel.b * 0.55).round(),
        );
      }
    }
    return Uint8List.fromList(img.encodePng(overlay));
  }
}
