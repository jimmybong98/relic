import 'package:admin/models/my_files.dart';
import 'package:admin/responsive.dart';
import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../services/report_service.dart';
import 'file_info_card.dart';

class MyFiles extends StatelessWidget {
  const MyFiles({Key? key}) : super(key: key);

  Future<List<CloudStorageInfo>> _loadSummaries() async {
    final reports = await ReportService().fetchReports();
    return buildStatusSummaries(reports);
  }

  @override
  Widget build(BuildContext context) {
    final Size _size = MediaQuery.of(context).size;
    return FutureBuilder<List<CloudStorageInfo>>(
      future: _loadSummaries(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ElevatedButton.icon(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: defaultPadding * 1.5,
                      vertical:
                          defaultPadding / (Responsive.isMobile(context) ? 2 : 1),
                    ),
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar'),
                ),
              ],
            ),
            const SizedBox(height: defaultPadding),
            Responsive(
              mobile: FileInfoCardGridView(
                files: data,
                crossAxisCount: _size.width < 650 ? 2 : 4,
                childAspectRatio:
                    _size.width < 650 && _size.width > 350 ? 1.3 : 1,
              ),
              tablet: FileInfoCardGridView(files: data),
              desktop: FileInfoCardGridView(
                files: data,
                childAspectRatio: _size.width < 1400 ? 1.1 : 1.4,
              ),
            ),
          ],
        );
      },
    );
  }
}

class FileInfoCardGridView extends StatelessWidget {
  const FileInfoCardGridView({
    Key? key,
    required this.files,
    this.crossAxisCount = 4,
    this.childAspectRatio = 1,
  }) : super(key: key);

  final List<CloudStorageInfo> files;
  final int crossAxisCount;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: files.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: defaultPadding,
        mainAxisSpacing: defaultPadding,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) => FileInfoCard(info: files[index]),
    );
  }
}
