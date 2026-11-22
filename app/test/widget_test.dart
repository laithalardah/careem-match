import 'package:flutter_test/flutter_test.dart';

import 'package:careem_match/main.dart';

void main() {
  testWidgets('home screen shows the headline and start button', (tester) async {
    await tester.pumpWidget(const CareemMatchApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Start'), findsOneWidget);
    expect(find.textContaining('One restaurant'), findsOneWidget);
  });
}
