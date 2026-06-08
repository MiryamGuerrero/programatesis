import "package:flutter/material.dart";

class MedicoSectionPlaceholderPage extends StatelessWidget {
  const MedicoSectionPlaceholderPage({
    super.key,
    required this.title,
    required this.description,
    required this.subsections,
  });

  final String title;
  final String description;
  final List<String> subsections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          title,
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(description),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Subsecciones planificadas",
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final subsection in subsections)
                      Chip(
                        avatar: const Icon(Icons.subdirectory_arrow_right,
                            size: 16),
                        label: Text(subsection),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.pending_actions),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Esta sección está visible para la navegación del médico y se desarrollará paso a paso.",
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
