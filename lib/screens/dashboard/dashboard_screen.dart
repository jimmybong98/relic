import 'package:admin/responsive.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';
import 'components/operator_report_chart.dart';
import 'components/personnel_report_chart.dart';

class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        primary: false,
        padding: EdgeInsets.all(defaultPadding),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 8,
                  child: Column(
                    children: [
                      OperatorReportChart(),
                      SizedBox(height: defaultPadding),
                      Image.asset('assets/images/traco.png'),
                      SizedBox(height: defaultPadding),
                      PersonnelReportChart(),
                      if (Responsive.isMobile(context))
                        SizedBox(height: defaultPadding),
                    ],
                  ),
                ),
                if (!Responsive.isMobile(context))
                  SizedBox(width: defaultPadding),
                // On Mobile means if the screen is less than 850 we don't want to show it
              ],
            ),
          ],
        ),
      ),
    );
  }
}