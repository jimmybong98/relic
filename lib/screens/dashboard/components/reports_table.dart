import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../models/report.dart';
import '../../../services/report_service.dart';

/// Widget that displays a table with reports fetched from the backend.
class ReportsTable extends StatelessWidget {
  const ReportsTable({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ReportService();
    return FutureBuilder<List<Report>>(
      future: service.fetchReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(defaultPadding),
            decoration: BoxDecoration(
              color: secondaryColor,
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: const Text('Nenhum relatório encontrado'),
          );
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
              Text('Relatórios', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(
                width: double.infinity,
                child: DataTable(
                  columnSpacing: defaultPadding,
                  columns: const [
                    DataColumn(label: Text('O.S')),
                    DataColumn(label: Text('Partnumber')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: reports
                      .map(
                        (r) => DataRow(cells: [
                          DataCell(Text(r.os)),
                          DataCell(Text(r.partnumber)),
                          DataCell(Text(r.status)),
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
