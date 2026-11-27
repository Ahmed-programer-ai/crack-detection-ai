import 'dart:typed_data';

import 'package:crackai/services/crack_classification_service.dart';
import 'package:crackai/services/crack_segmentation_service.dart';
import 'package:crackai/services/image_preprocessing_service.dart';
import 'package:crackai/services/severity_assessment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CrackClassificationService tensor outputs', () {
    test('flattens nested ONNX output values in order', () {
      final flattened = CrackClassificationService.flattenTensorOutput(
        [
          [
            [1.0, 2.0],
            [3, 4],
          ],
        ],
        expectedLength: 4,
        outputName: 'test tensor',
      );

      expect(flattened, [1, 2, 3, 4]);
    });

    test('rejects outputs with an unexpected number of values', () {
      expect(
        () => CrackClassificationService.flattenTensorOutput(
          [
            [1.0, 2.0],
          ],
          expectedLength: 3,
          outputName: 'test tensor',
        ),
        throwsStateError,
      );
    });
  });

  test('preprocessing creates the model RGB NCHW tensor', () async {
    final source = img.Image(width: 32, height: 32);
    img.fill(source, color: img.ColorRgb8(255, 0, 0));
    final prepared = await ImagePreprocessingService().preprocess(
      Uint8List.fromList(img.encodePng(source)),
    );
    const planeSize = 640 * 640;

    expect(prepared.tensor.length, 3 * planeSize);
    expect(prepared.tensor[320 * 640 + 320], closeTo(1, 1e-6));
    expect(prepared.tensor[planeSize + 320 * 640 + 320], 0);
    expect(prepared.tensor[2 * planeSize + 320 * 640 + 320], 0);
  });

  group('CrackSegmentationService', () {
    final service = CrackSegmentationService();

    test('reports no detection for empty model outputs', () {
      final prepared = _preparedImage();
      final output = RawModelOutput(
        detections: Float32List(37 * 8400),
        prototypes: Float32List(32 * 160 * 160),
      );

      final result = service.process(output, prepared);

      expect(result.status, 'no_detection');
      expect(result.confidence, 0);
      expect(result.overlayPng, isNull);
      expect(result.measurements['n_cracks'], 0);
    });

    test('decodes an actual model-format box and mask output', () {
      const candidates = 8400;
      final detections = Float32List(37 * candidates);
      final prototypes = Float32List(32 * 160 * 160);
      detections[0] = 320;
      detections[candidates] = 320;
      detections[2 * candidates] = 32;
      detections[3 * candidates] = 32;
      detections[4 * candidates] = 0.85;
      detections[5 * candidates] = 1;
      prototypes.fillRange(0, 160 * 160, 1);

      final result = service.process(
        RawModelOutput(detections: detections, prototypes: prototypes),
        _preparedImage(),
      );

      expect(result.status, 'detected');
      expect(result.confidence, closeTo(0.85, 1e-6));
      expect(result.mask.every((value) => value == 1), isTrue);
      expect(result.overlayPng, isNotNull);
      expect(result.measurements['n_cracks'], 1);
    });
  });

  group('SeverityAssessmentService', () {
    final service = SeverityAssessmentService();

    test('does not assign severity without a calibrated scale', () {
      final result = service.assess(
        status: 'detected',
        measurements: {'width_p95_px': 3.0},
        millimetersPerPixel: null,
      );

      expect(result.severity, isNull);
      expect(result.widthMm, isNull);
      expect(result.warnings, hasLength(2));
      expect(result.warnings.first, contains('unreliable'));
    });

    test('uses the project width bands with a supplied scale', () {
      final low = service.assess(
        status: 'detected',
        measurements: {'width_p95_px': 10.0},
        millimetersPerPixel: 0.5,
      );
      final moderate = service.assess(
        status: 'detected',
        measurements: {'width_p95_px': 30.0},
        millimetersPerPixel: 0.5,
      );
      final high = service.assess(
        status: 'detected',
        measurements: {'width_p95_px': 30.1},
        millimetersPerPixel: 0.5,
      );

      expect(low.severity, 'Low');
      expect(low.widthMm, 5);
      expect(moderate.severity, 'Moderate');
      expect(high.severity, 'High');
    });
  });
}

PreparedImage _preparedImage() => PreparedImage(
  sourceBytes: Uint8List(0),
  image: img.Image(width: 32, height: 32),
  tensor: Float32List(3 * 640 * 640),
  scale: 1,
  padLeft: 304,
  padTop: 304,
  resizedWidth: 32,
  resizedHeight: 32,
  sourceWidth: 32,
  sourceHeight: 32,
  pixelScaleFactor: 1,
);
