import 'package:flutter/material.dart';
import '../models/insight.dart';

class InsightTile extends StatelessWidget {
  final Insight insight;
  const InsightTile({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    final icon = switch (insight.level) {
      InsightLevel.positive => Icons.trending_up_rounded,
      InsightLevel.warning => Icons.warning_amber_rounded,
      InsightLevel.neutral => Icons.insights_rounded,
    };
    final color = switch (insight.level) {
      InsightLevel.positive => Colors.greenAccent,
      InsightLevel.warning => Colors.orangeAccent,
      InsightLevel.neutral => Theme.of(context).colorScheme.primary,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(insight.description, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text(insight.evidence, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
