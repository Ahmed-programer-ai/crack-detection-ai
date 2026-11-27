import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

class RawModelOutput {
  const RawModelOutput({required this.detections, required this.prototypes});

  final Float32List detections;
  final Float32List prototypes;
}

class CrackClassificationService {
  static const int _candidateCount = 8400;
  static const int _detectionChannels = 37;
  static const int _prototypeChannels = 32;
  static const int _prototypeSize = 160;

  OrtSession? _session;
  OrtSessionOptions? _sessionOptions;

  static Float32List flattenTensorOutput(
    Object? value, {
    required int expectedLength,
    required String outputName,
  }) {
    final flattened = Float32List(expectedLength);
    var offset = 0;

    void append(Object? item) {
      if (item is num) {
        if (offset >= expectedLength) {
          throw StateError('$outputName contains more values than expected.');
        }
        flattened[offset++] = item.toDouble();
      } else if (item is Iterable) {
        for (final child in item) {
          append(child);
        }
      } else {
        throw StateError('$outputName contains a non-numeric value.');
      }
    }

    append(value);
    if (offset != expectedLength) {
      throw StateError(
        '$outputName contains $offset values; expected $expectedLength.',
      );
    }
    return flattened;
  }

  Future<void> initialize() async {
    if (_session != null) return;
    OrtEnv.instance.init();
    final options = OrtSessionOptions()
      ..setIntraOpNumThreads(3)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    try {
      final model = await rootBundle.load('assets/models/crack_seg.onnx');
      final bytes = model.buffer.asUint8List(
        model.offsetInBytes,
        model.lengthInBytes,
      );
      final session = OrtSession.fromBuffer(bytes, options);
      if (session.inputNames.length != 1 ||
          session.outputNames.length != 2 ||
          session.inputNames.single != 'images' ||
          session.outputNames[0] != 'output0' ||
          session.outputNames[1] != 'output1') {
        session.release();
        throw StateError(
          'The packaged crack model has an unexpected signature.',
        );
      }
      _sessionOptions = options;
      _session = session;
    } catch (_) {
      options.release();
      rethrow;
    }
  }

  Future<RawModelOutput> predict(Float32List input) async {
    final session = _session;
    if (session == null) {
      throw StateError('The on-device model is not initialized.');
    }
    final inputTensor = OrtValueTensor.createTensorWithDataList(input, [
      1,
      3,
      640,
      640,
    ]);
    final runOptions = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      outputs = await session.runAsync(runOptions, {'images': inputTensor});
      if (outputs == null ||
          outputs.length != 2 ||
          outputs.any((output) => output is! OrtValueTensor)) {
        throw StateError('The on-device model returned unexpected outputs.');
      }
      return RawModelOutput(
        detections: flattenTensorOutput(
          (outputs[0]! as OrtValueTensor).value,
          expectedLength: _detectionChannels * _candidateCount,
          outputName: 'Detection tensor',
        ),
        prototypes: flattenTensorOutput(
          (outputs[1]! as OrtValueTensor).value,
          expectedLength: _prototypeChannels * _prototypeSize * _prototypeSize,
          outputName: 'Mask prototype tensor',
        ),
      );
    } finally {
      inputTensor.release();
      runOptions.release();
      outputs?.forEach((output) => output?.release());
    }
  }

  void dispose() {
    _session?.release();
    _session = null;
    _sessionOptions?.release();
    _sessionOptions = null;
  }
}
