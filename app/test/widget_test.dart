import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:careem_match/main.dart';

void main() {
  testWidgets('hub renders Careem sections and opens Careem Match intro', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CareemMatchApp());
    await tester.pump(const Duration(seconds: 1));

    // Hub header + service tiles + quick row + Careem Match banner above Careem Plus banner.
    expect(find.text('Discover places'), findsOneWidget);
    expect(find.text('Rides'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Quik'), findsOneWidget);
    expect(find.text('Match'), findsOneWidget);
    expect(find.text('Start matching'), findsOneWidget);
    expect(find.text('Save on rides'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Start matching')).dy, lessThan(tester.getTopLeft(find.text('Save on rides')).dy));

    await tester.tap(find.text('Match'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Start'), findsOneWidget);
    expect(find.textContaining('One restaurant'), findsOneWidget);

    // Start Player 1 swipe session.
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('PLAYER 1'), findsOneWidget);
    expect(find.text('Like'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });
}
