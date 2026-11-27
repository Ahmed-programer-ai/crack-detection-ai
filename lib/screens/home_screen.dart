import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/crackai_ui.dart';
import 'about_screen.dart';
import 'history_screen.dart';
import 'image_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _restorePickerData();
  }

  Future<void> _restorePickerData() async {
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) return;
    if (response.exception != null) {
      _showMessage(
        'Could not restore the selected image: ${response.exception}',
      );
      return;
    }
    final files = response.files;
    final file = files != null && files.isNotEmpty
        ? files.first
        : response.file;
    if (file != null) await _openImage(file);
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        requestFullMetadata: false,
      );
      if (file != null) await _openImage(file);
    } catch (error) {
      _showMessage('Unable to open the image: $error');
    }
  }

  Future<void> _openImage(XFile file) async {
    try {
      final bytes = await File(file.path).readAsBytes();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImagePreviewScreen(imageBytes: bytes),
        ),
      );
    } catch (error) {
      _showMessage('Unable to read the selected image: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _selectedIndex,
      children: [
        _HomeDashboard(
          onCamera: () => _pick(ImageSource.camera),
          onGallery: () => _pick(ImageSource.gallery),
        ),
        const HistoryScreen(),
        const AboutScreen(),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_rounded),
          label: 'History',
        ),
        NavigationDestination(
          icon: Icon(Icons.info_outline_rounded),
          label: 'About',
        ),
      ],
    ),
  );
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({required this.onCamera, required this.onGallery});

  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'CrackAI',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 18),
          child: Icon(Icons.shield_outlined, color: CrackAiUi.blue),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'Inspect with confidence.',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Screen a wall photo for visible cracks using AI that runs on this device.',
            style: TextStyle(color: CrackAiUi.muted, height: 1.45),
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.offline_bolt, color: CrackAiUi.blue),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Ready for offline analysis',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF1E8059,
                          ).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'ON DEVICE',
                          style: TextStyle(
                            color: Color(0xFF71D9A5),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'The packaged YOLO26n-seg model and recommendation guide work without a server or internet connection.',
                    style: TextStyle(color: CrackAiUi.muted, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onCamera,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Take photo'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onGallery,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Choose image'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Your inspection flow'),
          const SizedBox(height: 8),
          const InfoCard(
            icon: Icons.center_focus_strong,
            title: 'Capture a clear surface photo',
            description:
                'Use even lighting and photograph the wall straight on.',
          ),
          const InfoCard(
            icon: Icons.auto_awesome_outlined,
            title: 'Run the local AI model',
            description:
                'Crack detection and segmentation run directly on your Android device.',
          ),
          const InfoCard(
            icon: Icons.fact_check_outlined,
            title: 'Review and save results',
            description:
                'See the mask, confidence and cautious guidance in your private local history.',
          ),
          const SizedBox(height: 8),
          const Text(
            'CrackAI provides a preliminary visual assessment only. It is not a structural safety diagnosis.',
            style: TextStyle(color: CrackAiUi.muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    ),
  );
}
