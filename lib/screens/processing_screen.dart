import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../widgets/crackai_ui.dart';
import 'results_screen.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({
    required this.imageBytes,
    required this.millimetersPerPixel,
    required this.material,
    required this.buildingType,
    super.key,
  });

  final Uint8List imageBytes;
  final double? millimetersPerPixel;
  final String material;
  final String buildingType;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    try {
      final result = await AppServices.instance.analysis.analyze(
        imageBytes: widget.imageBytes,
        millimetersPerPixel: widget.millimetersPerPixel,
        material: widget.material,
        buildingType: widget.buildingType,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ResultsScreen(result: result)),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Offline analysis')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: _error == null
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 22),
                  Text(
                    'Analyzing on your device',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Preparing image, running the crack segmentation model, and saving your result locally.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: CrackAiUi.muted, height: 1.45),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFFF9C9C),
                    size: 52,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Analysis could not be completed',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: CrackAiUi.muted, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      setState(() => _error = null);
                      _runAnalysis();
                    },
                    child: const Text('Try again'),
                  ),
                ],
              ),
      ),
    ),
  );
}
