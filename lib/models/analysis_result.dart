import 'dart:convert';
import 'dart:typed_data';

class AnalysisSummary {
  const AnalysisSummary({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.confidence,
    this.severity,
  });

  final String id;
  final DateTime createdAt;
  final String status;
  final double confidence;
  final String? severity;

  factory AnalysisSummary.fromDatabaseMap(Map<String, Object?> map) =>
      AnalysisSummary(
        id: map['id']! as String,
        createdAt: DateTime.parse(map['created_at']! as String),
        status: map['status']! as String,
        confidence: (map['confidence']! as num).toDouble(),
        severity: map['severity'] as String?,
      );
}

class AnalysisResult {
  const AnalysisResult({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.confidence,
    required this.originalImage,
    required this.segmentationImage,
    required this.recommendations,
    required this.warnings,
    required this.measurements,
    this.severity,
    this.widthMm,
  });

  final String id;
  final DateTime createdAt;
  final String status;
  final double confidence;
  final String? severity;
  final double? widthMm;
  final Uint8List originalImage;
  final Uint8List? segmentationImage;
  final List<String> recommendations;
  final List<String> warnings;
  final Map<String, Object?> measurements;

  Map<String, Object?> toDatabaseMap() => {
    'id': id,
    'created_at': createdAt.toIso8601String(),
    'status': status,
    'confidence': confidence,
    'severity': severity,
    'width_mm': widthMm,
    'original_image': originalImage,
    'segmentation_image': segmentationImage,
    'recommendations': jsonEncode(recommendations),
    'warnings': jsonEncode(warnings),
    'measurements': jsonEncode(measurements),
  };

  factory AnalysisResult.fromDatabaseMap(Map<String, Object?> map) {
    List<String> decodeStrings(Object? value) =>
        (jsonDecode(value! as String) as List<Object?>)
            .map((item) => item! as String)
            .toList(growable: false);

    return AnalysisResult(
      id: map['id']! as String,
      createdAt: DateTime.parse(map['created_at']! as String),
      status: map['status']! as String,
      confidence: (map['confidence']! as num).toDouble(),
      severity: map['severity'] as String?,
      widthMm: (map['width_mm'] as num?)?.toDouble(),
      originalImage: map['original_image']! as Uint8List,
      segmentationImage: map['segmentation_image'] as Uint8List?,
      recommendations: decodeStrings(map['recommendations']),
      warnings: decodeStrings(map['warnings']),
      measurements:
          (jsonDecode(map['measurements']! as String) as Map<String, Object?>),
    );
  }
}
