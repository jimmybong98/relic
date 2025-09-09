import 'package:admin/constants.dart';
import 'package:flutter/material.dart';

import 'report.dart';

class CloudStorageInfo {
  final String? svgSrc, title, totalStorage;
  final int? numOfFiles, percentage;
  final Color? color;

  CloudStorageInfo({
    this.svgSrc,
    this.title,
    this.totalStorage,
    this.numOfFiles,
    this.percentage,
    this.color,
  });
}

/// Builds a summary of reports grouped by status that can be consumed by the
/// dashboard widgets such as [FileInfoCard] and [Chart].
List<CloudStorageInfo> buildStatusSummaries(List<Report> reports) {
  if (reports.isEmpty) return [];

  final Map<String, int> counts = {};
  for (final report in reports) {
    counts[report.status] = (counts[report.status] ?? 0) + 1;
  }

  final colors = <Color>[
    primaryColor,
    const Color(0xFF26E5FF),
    const Color(0xFFFFCF26),
    const Color(0xFFEE2727),
    primaryColor.withValues(alpha: 0.1),
  ];

  final total = reports.length;
  var colorIndex = 0;
  return counts.entries.map((entry) {
    final percentage = ((entry.value / total) * 100).round();
    final info = CloudStorageInfo(
      title: entry.key,
      numOfFiles: entry.value,
      svgSrc: 'assets/icons/Documents.svg',
      totalStorage: '$percentage%',
      color: colors[colorIndex % colors.length],
      percentage: percentage,
    );
    colorIndex++;
    return info;
  }).toList();
}
