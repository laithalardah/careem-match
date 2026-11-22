import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:careem_match/api.dart';
import 'package:careem_match/main.dart';
import 'package:careem_match/models.dart';
import 'package:careem_match/storage.dart';

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tapLike(WidgetTester tester) async {
  await tester.tap(find.text('Like'));
  await tester.pump(); // start 240ms swipe animation at t=0
  await tester.pump(const Duration(milliseconds: 300)); // finish animation & commit
  await tester.pump(const Duration(milliseconds: 50)); // flush async swipe callback
}

void main() {
  testWidgets('hub opens Mode screen, creates room, shows crown on host, adds demo friends, switches stages', (tester) async {
    _setMobileViewport(tester);
    final api = MockApi(fastDemo: true);

    await tester.pumpWidget(CareemMatchApp(api: api));
    await tester.pump(const Duration(milliseconds: 500));

    // Hub renders untouched with Match tile and Careem Match hero banner.
    expect(find.text('Discover places'), findsOneWidget);
    expect(find.text('Match'), findsOneWidget);
    expect(find.text('Start matching'), findsOneWidget);

    // Tap Match -> Mode screen (Food & Dine Out).
    await tester.tap(find.text('Match'));
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Dine Out'), findsOneWidget);

    // Tap Food -> creates room and opens Lobby.
    await tester.tap(find.text('Food'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Invite your group.'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    // Crown icon above host avatar.
    expect(find.byIcon(PhosphorIconsFill.crown), findsOneWidget);
    expect(find.text('Awni (you)'), findsOneWidget);

    // Add demo friends -> enables Next.
    await tester.tap(find.text('Add demo friends'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 2 demo friends'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('DEMO'), findsWidgets);
    expect(find.text('Next'), findsOneWidget);

    // Host advances lobby -> settings.
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('What meal is this?'), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);

    // Pick Lunch & Start -> swiping Level 1 (categories).
    await tester.tap(find.text('Lunch'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('CATEGORIES'), findsOneWidget);
    expect(find.text('Like'), findsOneWidget);

    // Finish Level 1 (5 category cards) -> Level 2 interstitial ("Now pick restaurants.").
    for (var i = 0; i < 5; i++) {
      await _tapLike(tester);
    }
    await tester.pump(const Duration(milliseconds: 400));

    // Verify Level 1 -> Level 2 transition interstitial or restaurant cards.
    if (find.text('Start swiping').evaluate().isNotEmpty) {
      expect(find.textContaining('Now pick'), findsOneWidget);
      await tester.tap(find.text('Start swiping'));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('RESTAURANTS'), findsOneWidget);
    expect(find.text('Shawarma Station'), findsOneWidget);

    // Finish Level 2 (6 restaurant cards) -> Matching -> 1-group Result.
    for (var i = 0; i < 6; i++) {
      await _tapLike(tester);
    }
    // Wait for mock agent trace & result to settle.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(find.text('EVERYONE AGREED'), findsOneWidget);
    expect(find.text('WHO GETS WHAT'), findsOneWidget);

    // Scroll to Why this one & Agent trace, expand trace and verify failed call + re-plan visibility.
    final listScroll = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Agent trace'), 250, scrollable: listScroll);
    expect(find.text('Why this one'), findsOneWidget);
    expect(find.text('Agent trace'), findsOneWidget);
    await tester.tap(find.text('Agent trace'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(find.text('FAILED'), 200, scrollable: listScroll);
    expect(find.text('FAILED'), findsOneWidget);

    // Host opens Create group order bottom sheet and confirms -> Order ready -> Go to {restaurant}.
    await tester.tap(find.text('Create group order'));
    await tester.pumpAndSettle();
    expect(find.text('Approve & create group order'), findsOneWidget);
    await tester.tap(find.text('Approve & create group order'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('ORDER READY'), findsOneWidget);
    expect(find.textContaining('Go to '), findsWidgets);
  });

  testWidgets('guest joins via /join/:code with inline validation and sees Waiting for the host + waiting state', (tester) async {
    _setMobileViewport(tester);
    final api = MockApi(fastDemo: true);
    final created = await api.createRoom(mode: RoomMode.food, hostName: 'Awni');
    // Clear host session id so this widget acts as a separate guest tab.
    SessionStore.clearParticipantId(created.roomCode);

    await tester.pumpWidget(CareemMatchApp(api: api, initialLocation: '/join/${created.roomCode}'));
    await tester.pumpAndSettle();

    expect(find.text('Join your group.'), findsOneWidget);
    // Inline validation on empty name.
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Join'));
    await tester.pump();
    expect(find.text('Enter your name to join.'), findsOneWidget);

    // Enter guest name & join.
    await tester.enterText(find.byType(TextField), 'Laith');
    await tester.tap(find.text('Join'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Waiting for the host'), findsOneWidget);
    expect(find.text('Laith (you)'), findsOneWidget);
    expect(find.text('Awni'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.crown), findsOneWidget);

    // Host starts swiping; guest finishes Level 1 while host hasn't -> Waiting for the others.
    await api.nextStage(created.roomCode, participantId: created.participantId);
    await api.startSwiping(created.roomCode, participantId: created.participantId);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('CATEGORIES'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await _tapLike(tester);
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Waiting for'), findsWidgets);
    expect(find.byIcon(PhosphorIconsFill.crown), findsOneWidget);
  });

  testWidgets('dispute resolved by wheel shows vote, wheel spin, and winner', (tester) async {
    _setMobileViewport(tester);
    final api = MockApi(fastDemo: true)..forceDispute = true;
    final created = await api.createRoom(mode: RoomMode.food, hostName: 'Awni');
    SessionStore.setParticipantId(created.roomCode, created.participantId);
    await api.addDemoFriends(created.roomCode, participantId: created.participantId, count: 2, scenario: 'dispute');
    await api.nextStage(created.roomCode, participantId: created.participantId);
    await api.startSwiping(created.roomCode, participantId: created.participantId);
    await api.startDispute(created.roomCode, participantId: created.participantId);

    await tester.pumpWidget(CareemMatchApp(api: api, initialLocation: '/room/${created.roomCode}'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('No clear winner.'), findsOneWidget);
    expect(find.text('Shawarma Station'), findsOneWidget);
    expect(find.text('Pizza Piazza'), findsOneWidget);
    expect(find.text('Spin the wheel'), findsOneWidget);
    expect(find.text('Split into groups'), findsOneWidget);

    // Vote Spin the wheel -> bots follow -> Wheel screen appears.
    await tester.tap(find.text('Spin the wheel'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Let the wheel decide.'), findsOneWidget);
    expect(find.text('Spin'), findsOneWidget);

    // Host spins -> wheel reveals winner.
    await tester.tap(find.text('Spin'));
    await tester.pump(const Duration(milliseconds: 200));
    if (find.text('Skip animation').evaluate().isNotEmpty) {
      await tester.tap(find.text('Skip animation'));
      await tester.pump(const Duration(milliseconds: 300));
    } else {
      await tester.pump(const Duration(milliseconds: 800));
    }
    expect(find.textContaining('wins'), findsOneWidget);
  });

  testWidgets('dispute resolved by split allows moving groups, confirming, and shows 2-group result + Create 2 orders', (tester) async {
    _setMobileViewport(tester);
    final api = MockApi(fastDemo: true)..forceDispute = true;
    final created = await api.createRoom(mode: RoomMode.food, hostName: 'Awni');
    SessionStore.setParticipantId(created.roomCode, created.participantId);
    await api.addDemoFriends(created.roomCode, participantId: created.participantId, count: 2, scenario: 'dispute');
    await api.nextStage(created.roomCode, participantId: created.participantId);
    await api.startSwiping(created.roomCode, participantId: created.participantId);
    await api.startDispute(created.roomCode, participantId: created.participantId);

    await tester.pumpWidget(CareemMatchApp(api: api, initialLocation: '/room/${created.roomCode}'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // Vote Split into groups -> Split screen appears.
    await tester.tap(find.text('Split into groups'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Pick your group.'), findsOneWidget);
    expect(find.text('Join this group'), findsOneWidget);
    expect(find.text('Confirm groups'), findsOneWidget);

    // Move host to the other group.
    await tester.tap(find.text('Join this group'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // Confirm split groups -> Matching -> 2-group Result.
    await tester.tap(find.text('Confirm groups'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(find.text('SPLIT INTO GROUPS'), findsOneWidget);
    expect(find.text('Split into 2 groups.'), findsOneWidget);
    expect(find.text('Create 2 orders'), findsOneWidget);

    // Open Create 2 orders bottom sheet.
    await tester.tap(find.text('Create 2 orders'));
    await tester.pumpAndSettle();
    expect(find.text('Create 2 group orders'), findsOneWidget);
    expect(find.text('Grand total'), findsOneWidget);
  });

  testWidgets('dineout mode has no basket and uses Go there flow; host sees early dispute after 5 swipes', (tester) async {
    _setMobileViewport(tester);
    final api = MockApi(fastDemo: true);
    final created = await api.createRoom(mode: RoomMode.dineout, hostName: 'Awni');
    SessionStore.setParticipantId(created.roomCode, created.participantId);
    await api.addDemoFriends(created.roomCode, participantId: created.participantId, count: 1, scenario: 'consensus');
    await api.nextStage(created.roomCode, participantId: created.participantId);
    await api.startSwiping(created.roomCode, participantId: created.participantId);

    await tester.pumpWidget(CareemMatchApp(api: api, initialLocation: '/room/${created.roomCode}'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // Finish Level 1 categories.
    for (var i = 0; i < 5; i++) {
      await _tapLike(tester);
    }
    await tester.pump(const Duration(milliseconds: 400));
    if (find.text('Start swiping').evaluate().isNotEmpty) {
      await tester.tap(find.text('Start swiping'));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pump(const Duration(milliseconds: 400));

    // Swipe 5 restaurant cards -> quiet "Can't decide? Help us decide" appears for host on card 6.
    for (var i = 0; i < 5; i++) {
      await _tapLike(tester);
    }
    expect(find.text("Can't decide? Help us decide"), findsOneWidget);

    // Finish 6th card -> Dine Out Result has no basket and shows "Go there".
    await _tapLike(tester);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('WHO GETS WHAT'), findsNothing);
    expect(find.text('Go there'), findsOneWidget);
  });
}
