import 'dart:typed_data';

import '../models/analysis_result.dart';
import 'crack_classification_service.dart';
import 'crack_segmentation_service.dart';
import 'image_preprocessing_service.dart';
import 'local_storage_service.dart';
import 'recommendation_service.dart';
import 'severity_assessment_service.dart';

class AnalysisService {
  AnalysisService({
    required this.preprocessing,
    required this.classification,
    required this.segmentation,
    required this.severity,
    required this.recommendations,
    required this.storage,
  });

  final ImagePreprocessingService preprocessing;
  final CrackClassificationService classification;
  final CrackSegmentationService segmentation;
  final SeverityAssessmentService severity;
  final RecommendationService recommendations;
  final LocalStorageService storage;

  Future<AnalysisResult> analyze({
    required Uint8List imageBytes,
    required double? millimetersPerPixel,
    required String material,
    required String buildingType,
  }) async {
    final prepared = await preprocessing.preprocess(imageBytes);
    final tensors = await classification.predict(prepared.tensor);
    final maskResult = segmentation.process(tensors, prepared);
    final assessment = severity.assess(
      status: maskResult.status,
      measurements: maskResult.measurements,
      millimetersPerPixel: millimetersPerPixel,
    );
    final crackCount = (maskResult.measurements['n_cracks'] as num).toInt();
    final lengthRatio = (maskResult.measurements['length_ratio'] as num)
        .toDouble();
    final orientation = maskResult.measurements['orientation'] as String?;
    final advice = recommendations.recommend(
      status: maskResult.status,
      severity: assessment.severity,
      crackCount: crackCount,
      lengthRatio: lengthRatio,
      orientation: orientation,
      material: material,
      buildingType: buildingType,
    );
    final createdAt = DateTime.now();
    final measurements = <String, Object?>{
      ...maskResult.measurements,
      if (assessment.widthMm != null) 'width_mm': assessment.widthMm,
    };
    final result = AnalysisResult(
      id: createdAt.microsecondsSinceEpoch.toString(),
      createdAt: createdAt,
      status: maskResult.status,
      confidence: maskResult.confidence,
      severity: assessment.severity,
      widthMm: assessment.widthMm,
      originalImage: imageBytes,
      segmentationImage: maskResult.overlayPng,
      recommendations: advice,
      warnings: assessment.warnings,
      measurements: measurements,
    );
    await storage.save(result);
    return result;
  }
}
