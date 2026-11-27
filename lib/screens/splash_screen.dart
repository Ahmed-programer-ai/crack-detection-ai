import 'package:flutter/material.dart';

import '../services/app_services.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await AppServices.instance.initialize();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFF4D9CFF).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.architecture_rounded,
                color: Color(0xFF4D9CFF),
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'CrackAI',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'On-device building inspection',
              style: TextStyle(color: Color(0xFF9FB2C8)),
            ),
            const SizedBox(height: 28),
            if (_error == null)
              const CircularProgressIndicator()
            else ...[
              Text(
                'CrackAI could not initialize its local model or storage.\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFF9C9C)),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() => _error = null);
                  _initialize();
                },
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
