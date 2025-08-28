import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:admin/main.dart';

void main() {
  testWidgets('renders main menu', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    expect(find.text('Menu Principal'), findsOneWidget);
  });
}
