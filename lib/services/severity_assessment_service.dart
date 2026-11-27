class SeverityAssessment {
  const SeverityAssessment({
    required this.severity,
    required this.widthMm,
    required this.warnings,
  });

  final String? severity;
  final double? widthMm;
  final List<String> warnings;
}

class SeverityAssessmentService {
  SeverityAssessment assess({
    required String status,
    required Map<String, Object?> measurements,
    required double? millimetersPerPixel,
  }) {
    final warnings = <String>[];
    if (status != 'detected') {
      return SeverityAssessment(
        severity: null,
        widthMm: null,
        warnings: warnings,
      );
    }

    final widthPixels = (measurements['width_p95_px'] as num?)?.toDouble() ?? 0;
    if (widthPixels < 5) {
      warnings.add(
        'The crack is only a few pixels wide; its width estimate is unreliable. Retake the photo closer.',
      );
    }
    if (millimetersPerPixel == null) {
      warnings.add(
        'No image scale was supplied. Crack width and severity are unavailable.',
      );
      return SeverityAssessment(
        severity: null,
        widthMm: null,
        warnings: warnings,
      );
    }
    if (!millimetersPerPixel.isFinite || millimetersPerPixel <= 0) {
      throw ArgumentError.value(
        millimetersPerPixel,
        'millimetersPerPixel',
        'Scale must be a positive finite number.',
      );
    }

    final widthMm = widthPixels * millimetersPerPixel;
    final severity = widthMm <= 5
        ? 'Low'
        : widthMm <= 15
        ? 'Moderate'
        : 'High';
    return SeverityAssessment(
      severity: severity,
      widthMm: widthMm,
      warnings: warnings,
    );
  }
}
