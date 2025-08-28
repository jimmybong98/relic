import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../models/report.dart';
import '../../../services/report_service.dart';

class RecentFiles extends StatelessWidget {
  const RecentFiles({Key? key}) : super(key: key);

  Future<List<Report>> _loadReports() => ReportService().fetchReports();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Report>>(
      future: _loadReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erro ao carregar relatórios',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }
        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return Center(
            child: Text(
              'Nenhum relatório encontrado',
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
              Text(
                'Últimas O.S',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(
                width: double.infinity,
                child: DataTable(
                  columnSpacing: defaultPadding,
                  columns: const [
                    DataColumn(label: Text('O.S')),
                    DataColumn(label: Text('Operação')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: reports
                      .map(
                        (report) => DataRow(cells: [
                          DataCell(Text(report.os)),
                          DataCell(Text(report.operacao)),
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
