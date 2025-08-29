import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../models/report.dart';
import '../../../services/report_service.dart';

/// Displays the last machine releases performed by the preparer.
class RecentFiles extends StatelessWidget {
  const RecentFiles({Key? key}) : super(key: key);

  Future<List<Report>> _loadReports() => ReportService().fetchPreparerReleases();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Report>>(
      future: _loadReports(),
      builder: (context, snapshot) {
        final reports = snapshot.data;
        if (reports == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Container(
          padding: const EdgeInsets.all(defaultPadding),
          decoration: BoxDecoration(
            color: secondaryColor,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Últimas liberações (Preparador)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(
                width: double.infinity,
                child: DataTable(
                  columnSpacing: defaultPadding,
                  columns: const [
                    DataColumn(label: Text('O.S')),
                    DataColumn(label: Text('Código da peça')),
                    DataColumn(label: Text('RE Preparador')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: reports
                      .map(
                        (report) => DataRow(cells: [
                          DataCell(Text(report.os)),
                          DataCell(Text(report.partnumber)),
                          DataCell(Text(report.rePreparador)),
                          DataCell(Text(report.status)),
                        ]),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
