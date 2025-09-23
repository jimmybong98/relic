import 'package:flutter/material.dart';

/// Representation of a summary item shown in the [SearchSummaryCard].
class SummaryInfo {
  const SummaryInfo({required this.label, required this.value});

  final String label;
  final String value;
}

/// Card used to present a compact summary of the search parameters once the
/// form is hidden.
class SearchSummaryCard extends StatelessWidget {
  const SearchSummaryCard({
    super.key,
    required this.reLabel,
    required this.reValue,
    required this.items,
    this.itemWidth = 160,
  });

  final String reLabel;
  final String reValue;
  final List<SummaryInfo> items;
  final double itemWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleItems = items.where((e) => e.value.trim().isNotEmpty).toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reLabel, style: theme.textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(
                    reValue.trim().isEmpty ? '-' : reValue,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            ...visibleItems.map(
              (item) => SizedBox(
                width: itemWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label, style: theme.textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text(
                      item.value.isEmpty ? '-' : item.value,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience wrapper that combines the [SearchSummaryCard] with an action
/// button to reopen the search form.
class SearchSummarySection extends StatelessWidget {
  const SearchSummarySection({
    super.key,
    required this.reLabel,
    required this.reValue,
    required this.items,
    required this.onEdit,
    this.itemWidth = 160,
    this.editLabel = 'Alterar dados da busca',
  });

  final String reLabel;
  final String reValue;
  final List<SummaryInfo> items;
  final VoidCallback onEdit;
  final double itemWidth;
  final String editLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchSummaryCard(
          reLabel: reLabel,
          reValue: reValue,
          items: items,
          itemWidth: itemWidth,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: Text(editLabel),
          ),
        ),
      ],
    );
  }
}
