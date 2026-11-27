import 'package:flutter/material.dart';

import '../models/analysis_result.dart';
import '../services/app_services.dart';
import '../widgets/crackai_ui.dart';
import 'results_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<AnalysisSummary>> _history;

  @override
  void initState() {
    super.initState();
    _history = AppServices.instance.storage.getHistory();
  }

  void _reload() =>
      setState(() => _history = AppServices.instance.storage.getHistory());

  Future<void> _delete(String id) async {
    await AppServices.instance.storage.delete(id);
    _reload();
  }

  Future<void> _open(AnalysisSummary summary) async {
    try {
      final result = await AppServices.instance.storage.getAnalysis(summary.id);
      if (result == null) {
        throw StateError('This saved analysis no longer exists.');
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ResultsScreen(result: result)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open saved analysis: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Analysis history'),
      actions: [
        IconButton(
          onPressed: _reload,
          tooltip: 'Refresh history',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<List<AnalysisSummary>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.error_outline,
            title: 'History could not be loaded',
            message: '${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.history_rounded,
            title: 'No saved analyses yet',
            message:
                'Completed inspections are stored on this device and will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final result = items[index];
              return Dismissible(
                key: ValueKey(result.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C2C38),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.delete_outline),
                ),
                onDismissed: (_) => _delete(result.id),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor: CrackAiUi.blue.withValues(alpha: 0.15),
                      child: Icon(
                        result.status == 'detected'
                            ? Icons.warning_amber_rounded
                            : Icons.fact_check_outlined,
                        color: CrackAiUi.blue,
                      ),
                    ),
                    title: Text(
                      _statusLabel(result.status),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${result.createdAt.toLocal()}\n'
                      'Confidence ${(result.confidence * 100).toStringAsFixed(1)}%'
                      '${result.severity == null ? '' : ' · ${result.severity}'}',
                      style: const TextStyle(
                        color: CrackAiUi.muted,
                        height: 1.4,
                      ),
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _open(result),
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );

  String _statusLabel(String status) => switch (status) {
    'detected' => 'Crack detected',
    'possible' => 'Possible crack',
    _ => 'No crack detected',
  };
}
