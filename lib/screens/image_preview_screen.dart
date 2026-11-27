import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../widgets/crackai_ui.dart';
import 'processing_screen.dart';

class ImagePreviewScreen extends StatefulWidget {
  const ImagePreviewScreen({required this.imageBytes, super.key});

  final Uint8List imageBytes;

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  final _scaleController = TextEditingController();
  String _material = 'unknown';
  String _buildingType = 'unknown';

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _startAnalysis() {
    final scaleText = _scaleController.text.trim();
    final scale = scaleText.isEmpty ? null : double.tryParse(scaleText);
    if (scaleText.isNotEmpty &&
        (scale == null || !scale.isFinite || scale <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a positive scale in millimeters per image pixel.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProcessingScreen(
          imageBytes: widget.imageBytes,
          millimetersPerPixel: scale,
          material: _material,
          buildingType: _buildingType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review image')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              widget.imageBytes,
              height: 300,
              cacheWidth: 1200,
              fit: BoxFit.contain,
              errorBuilder: (_, error, _) => Container(
                height: 250,
                color: CrackAiUi.panel,
                alignment: Alignment.center,
                child: const Text('This image format cannot be previewed.'),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Optional assessment details',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Severity is only estimated when you provide a calibrated scale for this image.',
            style: TextStyle(color: CrackAiUi.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _scaleController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Scale (mm per original image pixel)',
              hintText: 'For example, 0.25',
              prefixIcon: Icon(Icons.straighten_rounded),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _material,
            decoration: const InputDecoration(labelText: 'Surface material'),
            items: const [
              DropdownMenuItem(value: 'unknown', child: Text('Not sure')),
              DropdownMenuItem(value: 'masonry', child: Text('Masonry')),
              DropdownMenuItem(value: 'concrete', child: Text('Concrete')),
            ],
            onChanged: (value) =>
                setState(() => _material = value ?? 'unknown'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _buildingType,
            decoration: const InputDecoration(labelText: 'Building type'),
            items: const [
              DropdownMenuItem(value: 'unknown', child: Text('Not sure')),
              DropdownMenuItem(value: 'modern', child: Text('Modern')),
              DropdownMenuItem(value: 'historic', child: Text('Historic')),
            ],
            onChanged: (value) =>
                setState(() => _buildingType = value ?? 'unknown'),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _startAnalysis,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Analyze on this device'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Images and results stay in the app’s local storage.',
            textAlign: TextAlign.center,
            style: TextStyle(color: CrackAiUi.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
