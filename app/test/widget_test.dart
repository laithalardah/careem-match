import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:careem_match/api.dart';
import 'package:careem_match/main.dart';
import 'package:careem_match/models.dart';
import 'package:careem_match/room_controller.dart';
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

/// A backend that is already in the "ordered" stage, as a guest (not the host) would read it.
class _OrderedApi extends MockApi {
  _OrderedApi() : super(fastDemo: true);

  static final _room = <String, dynamic>{
    'room_code': 'ABC123',
    'mode': 'food',
    'stage': 'ordered',
    'version': 9,
    'host_id': 'host1',
    'join_url': '',
    'level': null,
    'settings': {'meal': 'dinner'},
    'participants': [
      {'id': 'host1', 'name': 'Awni', 'is_host': true, 'is_bot': false, 'progress': {'level': null, 'swiped': 0, 'total': 0, 'done': true}},
      {'id': 'guest1', 'name': 'Layla', 'is_host': false, 'is_bot': false, 'progress': {'level': null, 'swiped': 0, 'total': 0, 'done': true}},
    ],
    'dispute': null,
    'order': {
      'status': 'go',
      'message': 'Head to Shawarma Station in Careem and start a group order.',
      'groups': [
        {
          'group_id': 'g1',
          'status': 'go',
          'restaurant_name': 'Shawarma Station',
          'restaurant_link': 'careemfood://restaurants/30101',
          'message': 'Open Shawarma Station in Careem and start a group order for Awni and Layla. Everyone picks their own dishes there.',
        },
      ],
    },
  };

  static final _result = <String, dynamic>{
    'status': 'ready',
    'resolution': {'type': 'consensus'},
    'groups': [
      {
        'group_id': 'g1',
        'restaurant': {'id': 30101, 'name': 'Shawarma Station', 'image_url': null, 'cuisine': 'Shawarma', 'rating': 4.6, 'link': 'careemfood://restaurants/30101'},
        'participant_ids': ['host1', 'guest1'],
        'basket': [],
        'total_price': 0,
        'currency': 'AED',
        'reasoning': 'Shawarma Station was liked by 2 of 2.',
        'per_person': [],
      },
    ],
    'basket': [],
    'total_price': 0,
    'currency': 'AED',
    'reasoning': 'Shawarma Station was liked by 2 of 2.',
    'per_person': [],
    'agent_trace': [],
  };

  @override
  Future<HealthInfo> health() async => const HealthInfo(status: 'ok', demo: false);

  @override
  Future<Room> getRoom(String code, {String? participantId}) async => Room.fromJson(_room);

  @override
  Future<RoomResult> getResult(String code) async => RoomResult.fromJson(_result);
}

/// The first swipe fails (network blip), later ones work.
class _FlakyApi extends MockApi {
  _FlakyApi() : super(fastDemo: true);
  int failuresLeft = 1;

  @override
  Future<SwipeResponse> swipe(
    String code, {
    required String participantId,
    required SwipeLevel level,
    required String cardId,
    required bool liked,
  }) async {
    if (failuresLeft > 0) {
      failuresLeft--;
      throw Exception('offline');
    }
    return super.swipe(code, participantId: participantId, level: level, cardId: cardId, liked: liked);
  }
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

    // 1-tap demo bot button is immediately visible in footer and unlocks Next.
    expect(find.text('Add demo bot to continue'), findsOneWidget);
    await tester.tap(find.text('Add demo bot to continue'));
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
    // v2.2: swiping chooses the restaurant only. No dishes, no prices, no totals.
    expect(find.text('WHO GETS WHAT'), findsNothing);
    expect(find.textContaining('AED'), findsNothing);
    expect(find.textContaining('JOD'), findsNothing);

    // Scroll to Why this one & Agent trace, expand trace and verify failed call + re-plan visibility.
    final listScroll = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Agent trace'), 250, scrollable: listScroll);
    expect(find.text('Why this one'), findsOneWidget);
    expect(find.text('Agent trace'), findsOneWidget);
    await tester.tap(find.text('Agent trace'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(find.text('FAILED'), 200, scrollable: listScroll);
    expect(find.text('FAILED'), findsOneWidget);

    // Host taps one button (no approval sheet) -> everyone is sent to the restaurant in Careem.
    expect(find.text('Create group order'), findsNothing);
    await tester.tap(find.text('Start group order in Careem'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('GROUP ORDER'), findsOneWidget);
    expect(find.textContaining('Go to '), findsWidgets);
    expect(find.textContaining('start a group order and share it'), findsOneWidget);
    expect(find.textContaining('in Careem'), findsWidgets);
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

  testWidgets('dispute resolved by split allows moving groups, confirming, and shows a 2-group result and sends each group to its restaurant', (tester) async {
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
    expect(find.text('Send everyone to their restaurant'), findsOneWidget);
    expect(find.text('Grand total'), findsNothing);
    expect(find.textContaining('Total'), findsNothing);

    // One tap sends each group to its own restaurant; the host sees their own group's Go-to screen.
    await tester.tap(find.text('Send everyone to their restaurant'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('GROUP ORDER'), findsOneWidget);
    expect(find.textContaining('Go to '), findsWidgets);
  });

  testWidgets('dineout mode has no basket and uses the send-everyone-there flow; host sees early dispute after 5 swipes', (tester) async {
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
    expect(find.text('Send everyone there'), findsOneWidget);
  });

  testWidgets('a guest sees where to go after the host sends everyone to the restaurant', (tester) async {
    _setMobileViewport(tester);
    SessionStore.setParticipantId('ABC123', 'guest1'); // this tab is the guest, not the host
    await tester.pumpWidget(CareemMatchApp(api: _OrderedApi(), initialLocation: '/room/ABC123'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('GROUP ORDER'), findsOneWidget);
    expect(find.text('Go to Shawarma Station.'), findsOneWidget);
    expect(find.textContaining('Awni starts the group order in Careem'), findsOneWidget);
    expect(find.text('Open Shawarma Station in Careem'), findsOneWidget);
    expect(find.text('Layla (you)'), findsOneWidget);
    // guests never get the host's button, and nothing about dishes or prices
    expect(find.text('Start group order in Careem'), findsNothing);
    expect(find.textContaining('AED'), findsNothing);
  });

  test('a swipe that failed to reach the server is sent again on the next poll', () async {
    final api = _FlakyApi();
    final created = await api.createRoom(mode: RoomMode.food, hostName: 'Awni');
    SessionStore.setParticipantId(created.roomCode, created.participantId);
    await api.addDemoFriends(created.roomCode, participantId: created.participantId, count: 1, scenario: 'consensus');
    await api.nextStage(created.roomCode, participantId: created.participantId);
    await api.startSwiping(created.roomCode, participantId: created.participantId);

    final ctrl = RoomController(api: api, roomCode: created.roomCode, pollInterval: const Duration(hours: 1));
    final cards = await api.getCards(created.roomCode, participantId: created.participantId);
    final first = cards.cards.first;

    Future<int> hostSwipes() async {
      final room = await api.getRoom(created.roomCode, participantId: created.participantId);
      return room.participantById(created.participantId)!.progress.swiped;
    }

    expect(await hostSwipes(), 0);
    await ctrl.swipeCard(SwipeLevel.category, first.id, true); // fails (offline)
    expect(await hostSwipes(), 0);
    await ctrl.retryResult(); // next poll flushes the pending swipe
    expect(await hostSwipes(), 1);
    ctrl.dispose();
  });
}