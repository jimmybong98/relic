import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../models/my_files.dart';

class Chart extends StatelessWidget {
  const Chart({Key? key, required this.data}) : super(key: key);

  final List<CloudStorageInfo> data;

  @override
  Widget build(BuildContext context) {
    final total = data.fold<int>(0, (sum, e) => sum + (e.numOfFiles ?? 0));
    final sections = data
        .map((e) => PieChartSectionData(
              color: e.color,
              value: (e.percentage ?? 0).toDouble(),
              showTitle: false,
              radius: 25,
            ))
        .toList();
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: 70,
              startDegreeOffset: -90,
              sections: sections,
            ),
          ),
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: defaultPadding),
                Text(
                  '$total',
                  style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 0.5,
                      ),
                ),
                const Text('Relatórios')
              ],
            ),
          ),
        ],
      ),
    );
  }
}
