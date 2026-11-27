import 'analysis_service.dart';
import 'crack_classification_service.dart';
import 'crack_segmentation_service.dart';
import 'image_preprocessing_service.dart';
import 'local_storage_service.dart';
import 'recommendation_service.dart';
import 'severity_assessment_service.dart';

class AppServices {
  AppServices._();

  static final AppServices instance = AppServices._();

  final preprocessing = ImagePreprocessingService();
  final classification = CrackClassificationService();
  final segmentation = CrackSegmentationService();
  final severity = SeverityAssessmentService();
  final recommendations = RecommendationService();
  final storage = LocalStorageService();
  late final AnalysisService analysis = AnalysisService(
    preprocessing: preprocessing,
    classification: classification,
    segmentation: segmentation,
    severity: severity,
    recommendations: recommendations,
    storage: storage,
  );

  Future<void> initialize() async {
    await Future.wait([
      classification.initialize(),
      recommendations.initialize(),
      storage.initialize(),
    ]);
  }
}
