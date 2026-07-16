import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/intervention.dart';

class OpenAnomaliesListScreen extends StatelessWidget {
  const OpenAnomaliesListScreen({
    super.key,
    required this.anomalies,
  });

  final List<Intervention> anomalies;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anomalies ouvertes'),
      ),
      body: anomalies.isEmpty
          ? const Center(
              child: Text('Aucune anomalie ouverte.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: anomalies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final anomaly = anomalies[index];
                final parsedDate = DateTime.tryParse(anomaly.createdAtIso);
                final dateLabel = parsedDate == null
                    ? anomaly.createdAtIso
                    : DateFormat('dd/MM/yyyy HH:mm').format(parsedDate);

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        CircleAvatar(
                          backgroundColor: _priorityColor(anomaly.priority)
                              .withValues(alpha: 0.16),
                          child: Icon(
                            Icons.report_problem_outlined,
                            color: _priorityColor(anomaly.priority),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                anomaly.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text('Date: $dateLabel'),
                              Text('Machine: ${anomaly.machineName}'),
                              if (_hasImage(anomaly)) ...<Widget>[
                                const SizedBox(height: 10),
                                _AnomalyImageThumbnail(
                                  imageUrl: anomaly.imageUrl!,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(_priorityLabel(anomaly.priority)),
                          backgroundColor: _priorityColor(anomaly.priority)
                              .withValues(alpha: 0.18),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  bool _hasImage(Intervention anomaly) {
    final imageUrl = anomaly.imageUrl;
    return imageUrl != null && imageUrl.trim().isNotEmpty;
  }

  Color _priorityColor(InterventionPriority priority) {
    switch (priority) {
      case InterventionPriority.low:
        return Colors.green;
      case InterventionPriority.medium:
        return Colors.orange;
      case InterventionPriority.high:
        return Colors.deepOrange;
      case InterventionPriority.urgent:
        return Colors.red;
    }
  }

  String _priorityLabel(InterventionPriority priority) {
    switch (priority) {
      case InterventionPriority.low:
        return 'Faible';
      case InterventionPriority.medium:
        return 'Moyenne';
      case InterventionPriority.high:
        return 'Haute';
      case InterventionPriority.urgent:
        return 'Urgente';
    }
  }
}

class _AnomalyImageThumbnail extends StatelessWidget {
  const _AnomalyImageThumbnail({
    required this.imageUrl,
  });

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showImageDialog(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 92,
          width: 132,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return const ColoredBox(
                color: Color(0x11000000),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const ColoredBox(
                color: Color(0x11000000),
                child: Center(
                  child: Icon(Icons.broken_image_outlined),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(18),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: <Widget>[
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }
                    return const SizedBox(
                      height: 320,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      height: 240,
                      child: Center(child: Icon(Icons.broken_image_outlined)),
                    );
                  },
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
