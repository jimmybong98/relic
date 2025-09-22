import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    required this.reController,
    required this.reLabel,
    required this.items,
    this.reHint,
    this.itemWidth = 160,
  });

  final TextEditingController reController;
  final String reLabel;
  final List<SummaryInfo> items;
  final String? reHint;
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
                  TextField(
                    controller: reController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: reHint ?? 'Informe o R.E.',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
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
