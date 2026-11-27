import 'dart:convert';

import 'package:flutter/services.dart';

class RecommendationService {
  Map<String, Object?>? _knowledgeBase;

  Future<void> initialize() async {
    if (_knowledgeBase != null) return;
    final source = await rootBundle.loadString(
      'assets/data/knowledge_base.json',
    );
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('The local recommendation data is invalid.');
    }
    _knowledgeBase = decoded;
  }

  List<String> recommend({
    required String status,
    required String? severity,
    required int crackCount,
    required double lengthRatio,
    required String? orientation,
    required String material,
    required String buildingType,
  }) {
    final knowledgeBase = _knowledgeBase;
    if (knowledgeBase == null) {
      throw StateError('The local recommendation data is not initialized.');
    }
    final policy = knowledgeBase['policy']! as Map<String, Object?>;
    final items = knowledgeBase['items']! as Map<String, Object?>;
    final ids = <String>[];
    final escalation =
        crackCount >= (policy['widespread_min_cracks']! as num).toInt() ||
        lengthRatio >=
            (policy['widespread_min_length_ratio']! as num).toDouble();

    if (status == 'no_detection') {
      ids.add('R_NO_DETECTION');
    } else if (status == 'possible') {
      ids.add('R_RETAKE');
    } else {
      if (severity == null) {
        ids.addAll(['R_ADD_SCALE', 'R_DOCUMENT']);
      } else if (severity == 'Low') {
        ids.addAll(['R_DOCUMENT', 'R_MONITOR', 'R_AESTHETIC_NOTE']);
      } else if (severity == 'Moderate') {
        ids.addAll(['R_DOCUMENT', 'R_PROF_INSPECT', 'R_WARNING_SIGNS']);
      } else {
        ids.addAll(['R_PROF_URGENT', 'R_WARNING_SIGNS', 'R_DOCUMENT']);
      }

      final needsEscalation = escalation || orientation == 'diagonal';
      if (needsEscalation) {
        if (!ids.contains('R_PROF_INSPECT') && !ids.contains('R_PROF_URGENT')) {
          ids.add('R_PROF_INSPECT');
        }
        ids.add('R_PATTERN');
      }
      ids.add('R_NO_DIY');
      if (material == 'concrete') ids.add('R_CONCRETE_SCOPE');
      if (buildingType == 'historic') ids.add('R_HERITAGE');
    }
    ids.add('R_DISCLAIMER');

    final uniqueIds = ids.toSet();
    return uniqueIds
        .map((id) {
          final item = items[id]! as Map<String, Object?>;
          final text = item['en']! as String;
          final basis = (item['basis']! as List<Object?>).cast<String>();
          return '$text\nBasis: ${basis.join(', ')}';
        })
        .toList(growable: false);
  }
}
