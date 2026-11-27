import 'package:crackai/services/recommendation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads and uses the packaged offline recommendation knowledge base',
    () async {
      final service = RecommendationService();
      await service.initialize();

      final recommendations = service.recommend(
        status: 'detected',
        severity: null,
        crackCount: 1,
        lengthRatio: 0.1,
        orientation: null,
        material: 'unknown',
        buildingType: 'unknown',
      );

      expect(recommendations, contains(contains('without a scale')));
      expect(recommendations, contains(contains('not a structural safety')));
    },
  );
}
