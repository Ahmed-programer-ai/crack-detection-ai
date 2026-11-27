import 'package:flutter/material.dart';

import '../widgets/crackai_ui.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('About CrackAI')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        SizedBox(height: 8),
        InfoCard(
          icon: Icons.phone_android_rounded,
          title: 'Private and offline',
          description:
              'The ONNX model, image processing, recommendations, and analysis history are packaged or stored locally. CrackAI does not call a server.',
        ),
        InfoCard(
          icon: Icons.memory_rounded,
          title: 'On-device model',
          description:
              'YOLO26n-seg, trained for one class: visible cracks. Detection confidence thresholds are provisional.',
        ),
        InfoCard(
          icon: Icons.straighten_rounded,
          title: 'Severity limitations',
          description:
              'A width-based severity band is shown only when a calibrated mm-per-pixel scale is supplied. The separate MobileNet classification checkpoint was not included with the project.',
        ),
        SizedBox(height: 12),
        Text(
          'CrackAI provides a preliminary visual assessment only. It cannot determine structural safety, diagnose the cause of cracking, or prescribe structural repairs. Consult a qualified building or structural professional.',
          style: TextStyle(color: CrackAiUi.muted, height: 1.5),
        ),
      ],
    ),
  );
}
