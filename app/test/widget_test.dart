import 'package:flutter_test/flutter_test.dart';

import 'package:careem_match/main.dart';

void main() {
  testWidgets('hub opens Careem Match intro with a start button', (tester) async {
    await tester.pumpWidget(const CareemMatchApp());
    await tester.pump(const Duration(seconds: 1));

    // Main screen shows the service tiles; Match is our entry point.
    expect(find.text('Discover places'), findsOneWidget);
    expect(find.text('Match'), findsOneWidget);

    await tester.tap(find.text('Match'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Start'), findsOneWidget);
    expect(find.textContaining('One restaurant'), findsOneWidget);
  });
}
