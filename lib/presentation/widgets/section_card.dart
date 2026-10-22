import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  /// Linha discreta abaixo do título (ex.: "Amostra demo").
  final String? subtitle;

  const SectionCard({super.key, required this.title, required this.child, this.trailing, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (trailing != null) Flexible(child: trailing!),
              ],
            ),
            if (subtitle != null) Text(subtitle!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
