import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../models/my_files.dart';
import '../../../services/report_service.dart';
import 'chart.dart';
import 'storage_info_card.dart';

class StorageDetails extends StatelessWidget {
  const StorageDetails({Key? key}) : super(key: key);

  Future<List<CloudStorageInfo>> _loadSummaries() async {
    final reports = await ReportService().fetchReports();
    return buildStatusSummaries(reports);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CloudStorageInfo>>(
      future: _loadSummaries(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
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
              const Text(
                'Detalhes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: defaultPadding),
              Chart(data: data),
              for (final info in data)
                StorageInfoCard(
                  svgSrc: info.svgSrc ?? 'assets/icons/Documents.svg',
                  title: info.title ?? '',
                  amountOfFiles: info.totalStorage ?? '',
                  numOfFiles: info.numOfFiles ?? 0,
                ),
            ],
          ),
        );
      },
    );
  }
}
