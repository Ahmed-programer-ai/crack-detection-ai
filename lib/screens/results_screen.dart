import 'package:flutter/material.dart';

import '../models/analysis_result.dart';
import '../widgets/crackai_ui.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({required this.result, super.key});

  final AnalysisResult result;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _showSegmentation = true;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final segmentation = result.segmentationImage;
    final displaySegmentation = _showSegmentation && segmentation != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis result')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              displaySegmentation ? segmentation : result.originalImage,
              height: 290,
              cacheWidth: 1200,
              fit: BoxFit.contain,
            ),
          ),
          if (segmentation != null) ...[
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Segmentation')),
                ButtonSegment(value: false, label: Text('Original')),
              ],
              selected: {_showSegmentation},
              onSelectionChanged: (values) =>
                  setState(() => _showSegmentation = values.first),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  _statusLabel(result.status),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusChip(status: result.status),
            ],
          ),
          const SizedBox(height: 12),
          _MetricRow(
            label: 'Model confidence',
            value: '${(result.confidence * 100).toStringAsFixed(1)}%',
          ),
          _MetricRow(
            label: 'Detected crack regions',
            value: '${result.measurements['n_cracks'] ?? 0}',
          ),
          if (result.widthMm != null)
            _MetricRow(
              label: 'Estimated width (95th percentile)',
              value: '${result.widthMm!.toStringAsFixed(1)} mm',
            ),
          if (result.severity != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: CrackAiUi.blue,
                ),
                title: Text('${result.severity} severity band'),
                subtitle: const Text(
                  'Based on the supplied scale and project width bands.',
                ),
              ),
            ),
          ] else if (result.status == 'detected') ...[
            const SizedBox(height: 12),
            const InfoCard(
              icon: Icons.straighten_rounded,
              title: 'Severity not estimated',
              description:
                  'A calibrated image scale is required before crack width or severity can be estimated.',
            ),
          ],
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...result.warnings.map(
              (warning) => InfoCard(
                icon: Icons.info_outline,
                title: 'Measurement limitation',
                description: warning,
                color: const Color(0xFFFFC46B),
              ),
            ),
          ],
          const SizedBox(height: 18),
          const SectionTitle('Recommendations'),
          const SizedBox(height: 8),
          ...result.recommendations.map(
            (recommendation) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  recommendation,
                  style: const TextStyle(height: 1.45),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Preliminary visual assessment only. This result is not a structural safety diagnosis and does not replace a qualified engineer.',
            style: TextStyle(
              color: CrackAiUi.muted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'detected' => 'Crack detected',
    'possible' => 'Possible crack',
    _ => 'No crack detected',
  };
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: CrackAiUi.muted)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'detected' => const Color(0xFFFF9C9C),
      'possible' => const Color(0xFFFFC46B),
      _ => const Color(0xFF71D9A5),
    };
    final label = switch (status) {
      'detected' => 'DETECTED',
      'possible' => 'POSSIBLE',
      _ => 'NO DETECTION',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
