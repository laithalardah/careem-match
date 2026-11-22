import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'storage.dart';

abstract class Api {
  bool get isMock => false;
  bool get forceDispute => false;
  set forceDispute(bool v) {}

  Future<HealthInfo> health();
  Future<CreateRoomResult> createRoom({required RoomMode mode, required String hostName});
  Future<JoinRoomResult> joinRoom(String code, {required String name});
  Future<Room> getRoom(String code, {String? participantId});
  Future<void> nextStage(String code, {required String participantId});
  Future<void> updateSettings(String code, {required String participantId, required MealType meal});
  Future<void> startSwiping(String code, {required String participantId});
  Future<void> addDemoFriends(String code, {required String participantId, required int count, required String scenario});
  Future<CardsResponse> getCards(String code, {required String participantId});
  Future<SwipeResponse> swipe(String code, {required String participantId, required SwipeLevel level, required String cardId, required bool liked});
  Future<void> startDispute(String code, {required String participantId});
  Future<void> voteDispute(String code, {required String participantId, required String method});
  Future<void> spinWheel(String code, {required String participantId});
  Future<void> moveSplitGroup(String code, {required String participantId, required int restaurantId});
  Future<void> confirmSplit(String code, {required String participantId});
  Future<RoomResult> getResult(String code);
  Future<OrderResult> createOrder(String code, {required String participantId});
}

/// Pure-Dart RFC-1123 HTTP Date header parser (works on Web and VM).
int? parseHttpDateMs(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  const months = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };
  final m = RegExp(r'^[A-Za-z]{3},\s+(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+GMT$').firstMatch(raw.trim());
  if (m == null) return null;
  final month = months[m.group(2)!];
  if (month == null) return null;
  return DateTime.utc(
    int.parse(m.group(3)!),
    month,
    int.parse(m.group(1)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
    int.parse(m.group(6)!),
  ).millisecondsSinceEpoch;
}

/// Real FastAPI v2.1 backend. Set with `--dart-define=API_BASE=http://127.0.0.1:8000`.
class HttpApi implements Api {
  HttpApi(String baseUrl) : base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  final String base;

  @override
  bool get isMock => false;

  @override
  bool get forceDispute => false;

  @override
  set forceDispute(bool v) {}

  Uri _u(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$base$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Map<String, String> get _json => const {'Content-Type': 'application/json'};

  Map<String, dynamic> _decode(http.Response r) {
    if (r.statusCode >= 400) {
      String detail = r.body;
      try {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        if (j is Map && j['detail'] != null) detail = '${j['detail']}';
      } catch (_) {}
      throw ApiException('HTTP ${r.statusCode}: $detail', r.statusCode);
    }
    if (r.bodyBytes.isEmpty) return const {};
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  int _offsetFromHeaders(Map<String, String> headers) {
    final dateStr = headers['date'] ?? headers['Date'];
    final serverMs = parseHttpDateMs(dateStr);
    if (serverMs == null) return 0;
    return DateTime.now().millisecondsSinceEpoch - serverMs;
  }

  @override
  Future<HealthInfo> health() async => HealthInfo.fromJson(_decode(await http.get(_u('/health'))));

  @override
  Future<CreateRoomResult> createRoom({required RoomMode mode, required String hostName}) async {
    final j = _decode(await http.post(
      _u('/rooms'),
      headers: _json,
      body: jsonEncode({'mode': mode.wire, 'host_name': hostName}),
    ));
    return CreateRoomResult.fromJson(j);
  }

  @override
  Future<JoinRoomResult> joinRoom(String code, {required String name}) async {
    final j = _decode(await http.post(
      _u('/rooms/$code/join'),
      headers: _json,
      body: jsonEncode({'name': name}),
    ));
    return JoinRoomResult.fromJson(j);
  }

  @override
  Future<Room> getRoom(String code, {String? participantId}) async {
    final q = participantId == null ? null : {'participant_id': participantId};
    final r = await http.get(_u('/rooms/$code', q));
    final j = _decode(r);
    return Room.fromJson(j, serverOffsetMs: _offsetFromHeaders(r.headers));
  }

  @override
  Future<void> nextStage(String code, {required String participantId}) async {
    _decode(await http.post(_u('/rooms/$code/next'), headers: _json, body: jsonEncode({'participant_id': participantId})));
  }

  @override
  Future<void> updateSettings(String code, {required String participantId, required MealType meal}) async {
    _decode(await http.put(
      _u('/rooms/$code/settings'),
      headers: _json,
      body: jsonEncode({'participant_id': participantId, 'meal': meal.wire}),
    ));
  }

  @override
  Future<void> startSwiping(String code, {required String participantId}) async {
    _decode(await http.post(_u('/rooms/$code/start'), headers: _json, body: jsonEncode({'participant_id': participantId})));
  }

  @override
  Future<void> addDemoFriends(String code, {required String participantId, required int count, required String scenario}) async {
    _decode(await http.post(
      _u('/rooms/$code/demo-friends'),
      headers: _json,
      body: jsonEncode({'participant_id': participantId, 'count': count, 'scenario': scenario}),
    ));
  }

  @override
  Future<CardsResponse> getCards(String code, {required String participantId}) async {
    final j = _decode(await http.get(_u('/rooms/$code/cards', {'participant_id': participantId})));
    return CardsResponse.fromJson(j);
  }

  @override
  Future<SwipeResponse> swipe(
    String code, {
    required String participantId,
    required SwipeLevel level,
    required String cardId,
    required bool liked,
  }) async {
    final j = _decode(await http.post(
      _u('/rooms/$code/swipe'),
      headers: _json,
      body: jsonEncode({'participant_id': participantId, 'level': level.wire, 'card_id': cardId, 'liked': liked}),
    ));
    return SwipeResponse.fromJson(j);
  }

  @override
  Future<void> startDispute(String code, {required String participantId}) async {
    _decode(await http.post(_u('/rooms/$code/dispute/start'), headers: _json, body: jsonEncode({'participant_id': participantId})));
  }

  @override
  Future<void> voteDispute(String code, {required String participantId, required String method}) async {
    _decode(await http.post(
      _u('/rooms/$code/dispute/vote'),
      headers: _json,
      body: jsonEncode({'participant_id': participantId, 'method': method}),
    ));
  }

  @override
  Future<void> spinWheel(String code, {required String participantId}) async {
    _decode(await http.post(_u('/rooms/$code/dispute/spin'), headers: _json, body: jsonEncode({'participant_id': participantId})));
  }

  @override
  Future<void> moveSplitGroup(String code, {required String participantId, required int restaurantId}) async {
    _decode(await http.post(
      _u('/rooms/$code/dispute/move'),
      headers: _json,
      body: jsonEncode({'participant_id': participantId, 'restaurant_id': restaurantId}),
    ));
  }

  @override
  Future<void> confirmSplit(String code, {required String participantId}) async {
    _decode(await http.post(_u('/rooms/$code/dispute/confirm'), headers: _json, body: jsonEncode({'participant_id': participantId})));
  }

  @override
  Future<RoomResult> getResult(String code) async => RoomResult.fromJson(_decode(await http.get(_u('/rooms/$code/result'))));

  @override
  Future<OrderResult> createOrder(String code, {required String participantId}) async => OrderResult.fromJson(_decode(
        await http.post(_u('/rooms/$code/order'), headers: _json, body: jsonEncode({'participant_id': participantId})),
      ));
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// Offline / cross-tab mock backend using localStorage on Web (in-memory on VM),
/// so two browser tabs (host + guest) can run the full v2.1 flow together with zero backend.
class MockApi implements Api {
  MockApi({this.fastDemo = false});

  /// Speeds up mock timings in automated widget tests.
  final bool fastDemo;

  @override
  bool get isMock => true;

  bool _forceDispute = false;
  @override
  bool get forceDispute => _forceDispute;
  @override
  set forceDispute(bool v) => _forceDispute = v;

  static const _storagePrefix = 'cm_mock_room_v21_';
  final _rng = Random();

  static const _categoryCards = <Map<String, dynamic>>[
    {
      'id': 'cat_shawarma',
      'level': 'category',
      'title': 'Shawarma & Grill',
      'subtitle': 'Wraps, mezze, charcoal plates',
      'cuisine': 'Arabic',
      'image_url': 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=800&q=80',
    },
    {
      'id': 'cat_pizza',
      'level': 'category',
      'title': 'Pizza',
      'subtitle': 'Wood-fired pies & sourdough crusts',
      'cuisine': 'Italian',
      'image_url': 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=800&q=80',
    },
    {
      'id': 'cat_sushi',
      'level': 'category',
      'title': 'Sushi & Bento',
      'subtitle': 'Fresh maki rolls & crispy katsu',
      'cuisine': 'Japanese',
      'image_url': 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=800&q=80',
    },
    {
      'id': 'cat_breakfast',
      'level': 'category',
      'title': 'Breakfast & Cafe',
      'subtitle': 'Syrniki, specialty coffee & brunch',
      'cuisine': 'Breakfast',
      'image_url': 'https://images.unsplash.com/photo-1528207776546-365bb710ee93?w=800&q=80',
    },
    {
      'id': 'cat_healthy',
      'level': 'category',
      'title': 'Healthy Bowls',
      'subtitle': 'Warm grain bowls & crisp salads',
      'cuisine': 'Healthy',
      'image_url': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80',
    },
  ];

  static const _restaurantCards = <Map<String, dynamic>>[
    {
      'id': '30101',
      'level': 'restaurant',
      'title': 'Shawarma Station',
      'description': 'Charcoal-grilled chicken shawarma wraps, crispy falafel, and smoky mixed grills.',
      'cuisine': 'Arabic',
      'rating': 4.6,
      'eta_minutes': 24,
      'image_url': 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=800&q=80',
      'top_dishes': ['Chicken Shawarma Wrap', 'Falafel Plate', 'Mixed Grill Platter'],
    },
    {
      'id': '30103',
      'level': 'restaurant',
      'title': 'Pizza Piazza',
      'description': 'Blistered Neapolitan crusts topped with San Marzano tomatoes and creamy mozzarella.',
      'cuisine': 'Italian',
      'rating': 4.5,
      'eta_minutes': 28,
      'image_url': 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=800&q=80',
      'top_dishes': ['Margherita Pizza', 'Pepperoni Pizza', 'Truffle Garlic Knots'],
    },
    {
      'id': '30102',
      'level': 'restaurant',
      'title': 'Sakura Sushi Lab',
      'description': 'Hand-rolled salmon avocado maki and crunchy chicken katsu bento boxes.',
      'cuisine': 'Japanese',
      'rating': 4.4,
      'eta_minutes': 32,
      'image_url': 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=800&q=80',
      'top_dishes': ['Salmon Avocado Roll (8 pcs)', 'Chicken Katsu Bento', 'Miso Soup'],
    },
    {
      'id': '30104',
      'level': 'restaurant',
      'title': 'Morning Syrniki Café',
      'description': 'Golden cottage-cheese syrniki with sour cream paired with velvety cappuccinos.',
      'cuisine': 'Breakfast',
      'rating': 4.8,
      'eta_minutes': 20,
      'image_url': 'https://images.unsplash.com/photo-1528207776546-365bb710ee93?w=800&q=80',
      'top_dishes': ['Classic Syrniki with Sour Cream', 'Cappuccino', 'Berry Granola Bowl'],
    },
    {
      'id': '30105',
      'level': 'restaurant',
      'title': 'Green Bowl Co.',
      'description': 'Bright protein-packed bowls with roasted chicken, avocado, and house dressings.',
      'cuisine': 'Healthy',
      'rating': 4.3,
      'eta_minutes': 22,
      'image_url': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80',
      'top_dishes': ['Chicken Caesar Bowl', 'Avocado Quinoa Salad', 'Green Glow Juice'],
    },
    {
      'id': '30106',
      'level': 'restaurant',
      'title': 'Shawarma Station Express',
      'description': 'Late-night saj wraps, pomegranate fries, and extra garlic toum on the side.',
      'cuisine': 'Arabic',
      'rating': 4.5,
      'eta_minutes': 19,
      'image_url': 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=800&q=80',
      'top_dishes': ['Saj Shawarma Box', 'Loaded Toum Fries', 'Hummus & Pita'],
    },
  ];

  static const _menuByRestaurant = <int, Map<String, dynamic>>{
    30101: {
      'id': 30101,
      'name': 'Shawarma Station',
      'cuisine': 'Arabic',
      'rating': 4.6,
      'image_url': 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=800&q=80',
      'link': 'https://www.careem.com/food/shawarma-station',
      'dishes': [
        {'name': 'Chicken Shawarma Wrap', 'price': 3.50, 'options': ['Extra garlic toum', 'Saj bread']},
        {'name': 'Falafel Plate', 'price': 4.25, 'options': ['Tahini dip']},
        {'name': 'Mixed Grill Platter', 'price': 9.75, 'options': ['Grilled tomato & onion']},
      ],
    },
    30103: {
      'id': 30103,
      'name': 'Pizza Piazza',
      'cuisine': 'Italian',
      'rating': 4.5,
      'image_url': 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=800&q=80',
      'link': 'https://www.careem.com/food/pizza-piazza',
      'dishes': [
        {'name': 'Margherita Pizza', 'price': 7.50, 'options': ['Classic 12" crust']},
        {'name': 'Pepperoni Pizza', 'price': 8.75, 'options': ['Classic 12" crust', 'Chili honey']},
        {'name': 'Truffle Garlic Knots', 'price': 4.50, 'options': ['Parmesan dip']},
      ],
    },
    30102: {
      'id': 30102,
      'name': 'Sakura Sushi Lab',
      'cuisine': 'Japanese',
      'rating': 4.4,
      'image_url': 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=800&q=80',
      'link': 'https://www.careem.com/food/sakura-sushi-lab',
      'dishes': [
        {'name': 'Salmon Avocado Roll (8 pcs)', 'price': 8.25, 'options': ['Low-sodium soy']},
        {'name': 'Chicken Katsu Bento', 'price': 9.50, 'options': ['Steamed rice']},
      ],
    },
    30104: {
      'id': 30104,
      'name': 'Morning Syrniki Café',
      'cuisine': 'Breakfast',
      'rating': 4.8,
      'image_url': 'https://images.unsplash.com/photo-1528207776546-365bb710ee93?w=800&q=80',
      'link': 'https://www.careem.com/food/morning-syrniki-cafe',
      'dishes': [
        {'name': 'Classic Syrniki with Sour Cream', 'price': 6.50, 'options': ['Warm berry compote']},
        {'name': 'Cappuccino', 'price': 3.75, 'options': ['Oat milk']},
      ],
    },
    30105: {
      'id': 30105,
      'name': 'Green Bowl Co.',
      'cuisine': 'Healthy',
      'rating': 4.3,
      'image_url': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80',
      'link': 'https://www.careem.com/food/green-bowl-co',
      'dishes': [
        {'name': 'Chicken Caesar Bowl', 'price': 7.25, 'options': ['Dressing on the side']},
        {'name': 'Avocado Quinoa Salad', 'price': 6.75, 'options': ['Lemon olive oil']},
      ],
    },
  };

  Map<String, dynamic> _readRoom(String code) {
    final key = '$_storagePrefix${code.toUpperCase()}';
    final raw = SessionStore.sharedGet(key);
    if (raw == null) throw ApiException('Room $code not found.', 404);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  void _writeRoom(Map<String, dynamic> room) {
    final code = '${room['room_code']}'.toUpperCase();
    room['version'] = ((room['version'] as num?)?.toInt() ?? 0) + 1;
    SessionStore.sharedSet('$_storagePrefix$code', jsonEncode(room));
  }

  String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  String _genId(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch % 1000000}_${_rng.nextInt(999)}';

  int get _now => DateTime.now().millisecondsSinceEpoch;

  /// Advances bots & async matching stages deterministically based on elapsed wall-clock time.
  bool _tickRoom(Map<String, dynamic> room) {
    var changed = false;
    final now = _now;
    final stage = room['stage'] as String;
    final participants = [for (final p in room['participants'] as List) p as Map<String, dynamic>];

    if (stage == 'swiping') {
      final level = (room['level'] ?? 'category') as String;
      final total = level == 'category' ? _categoryCards.length : _restaurantCards.length;
      final startedAt = (room['_level_started_at'] as num?)?.toInt() ?? now;
      final stepMs = fastDemo ? 150 : 650;
      final elapsedSteps = fastDemo ? total + participants.length : ((now - startedAt) / stepMs).floor();

      for (var i = 0; i < participants.length; i++) {
        final p = participants[i];
        if (p['is_bot'] != true) continue;
        final prog = p['progress'] as Map<String, dynamic>;
        final target = (elapsedSteps - i).clamp(0, total);
        final cur = (prog['swiped'] as num?)?.toInt() ?? 0;
        if (prog['level'] != level || target > cur || (target >= total && prog['done'] != true)) {
          prog['level'] = level;
          prog['swiped'] = target;
          prog['total'] = total;
          prog['done'] = target >= total;
          if (target >= total && level == 'restaurant') {
            final swipes = (room['_swipes'] as Map<String, dynamic>);
            final pSwipes = Map<String, dynamic>.from((swipes[p['id']] ?? const {}) as Map);
            final scenario = (room['_scenario'] ?? 'consensus') as String;
            if (scenario == 'dispute') {
              pSwipes['30103'] = true;
              pSwipes['30101'] = false;
            } else {
              pSwipes['30101'] = true;
              pSwipes['30103'] = true;
            }
            swipes[p['id']] = pSwipes;
          }
          changed = true;
        }
      }

      final allDone = participants.isNotEmpty &&
          participants.every((p) => (p['progress'] as Map<String, dynamic>)['done'] == true);
      if (allDone) {
        if (level == 'category') {
          room['level'] = 'restaurant';
          room['_level_started_at'] = now;
          for (final p in participants) {
            p['progress'] = {'level': 'restaurant', 'swiped': 0, 'total': _restaurantCards.length, 'done': false};
          }
          changed = true;
        } else {
          _resolveAfterSwiping(room);
          changed = true;
        }
      }
    } else if (stage == 'dispute') {
      final dispute = room['dispute'] as Map<String, dynamic>?;
      if (dispute != null && dispute['method'] == null) {
        final startedAt = (room['_dispute_started_at'] as num?)?.toInt() ?? now;
        final votes = Map<String, dynamic>.from((dispute['method_votes'] ?? const {}) as Map);
        final botDelay = fastDemo ? 0 : 1200;
        final hostVote = votes[room['host_id']] as String?;
        if ((fastDemo && hostVote != null) || (!fastDemo && now - startedAt >= botDelay)) {
          for (var i = 0; i < participants.length; i++) {
            final p = participants[i];
            if (p['is_bot'] == true && !votes.containsKey(p['id'])) {
              // Bots lean toward the host's choice if cast, otherwise split evenly
              votes[p['id']] = hostVote ?? (i.isEven ? 'wheel' : 'split');
              changed = true;
            }
          }
          dispute['method_votes'] = votes;
          if (_tryFinalizeMethodVote(room)) changed = true;
        }
      } else if (dispute != null && dispute['method'] == 'wheel') {
        final wheel = dispute['wheel'] as Map<String, dynamic>?;
        final startedAt = (wheel?['spin_started_at_ms'] as num?)?.toInt();
        final dur = (wheel?['duration_ms'] as num?)?.toInt() ?? 4200;
        final autoAdvanceDelay = dur + 2400;
        if (!fastDemo && startedAt != null && now - startedAt >= autoAdvanceDelay) {
          final winnerId = (wheel!['winner_restaurant_id'] as num).toInt();
          _beginMatching(room, resolutionType: 'wheel', selectedRestaurantIds: [winnerId]);
          changed = true;
        }
      }
    } else if (stage == 'matching') {
      final startedAt = (room['_matching_started_at'] as num?)?.toInt() ?? now;
      final stepMs = 650;
      final fullTrace = (room['_full_trace'] as List?) ?? const [];
      final prevVisible = (room['_trace_visible'] as num?)?.toInt() ?? 0;
      final visibleCount = fastDemo
          ? (prevVisible + 2).clamp(1, fullTrace.length)
          : ((now - startedAt) / stepMs).floor().clamp(1, fullTrace.length);
      if (visibleCount != prevVisible) {
        room['_trace_visible'] = visibleCount;
        changed = true;
      }
      if (visibleCount >= fullTrace.length && (fastDemo || now - startedAt >= stepMs * fullTrace.length + 500)) {
        room['stage'] = 'result';
        changed = true;
      }
    }

    return changed;
  }

  void _resolveAfterSwiping(Map<String, dynamic> room) {
    final scenario = (room['_scenario'] ?? 'consensus') as String;
    final swipes = (room['_swipes'] as Map<String, dynamic>?) ?? const {};
    final participants = [for (final p in room['participants'] as List) p as Map<String, dynamic>];

    // Tally restaurant likes
    final likesByRest = <int, List<String>>{};
    for (final p in participants) {
      final pid = '${p['id']}';
      final ps = (swipes[pid] as Map<String, dynamic>?) ?? const {};
      for (final e in ps.entries) {
        final rid = int.tryParse(e.key);
        if (rid != null && e.value == true) {
          likesByRest.putIfAbsent(rid, () => []).add(pid);
        }
      }
    }

    final shouldDispute = _forceDispute ||
        scenario == 'dispute' ||
        (scenario == 'random' && _rng.nextBool()) ||
        (participants.length >= 2 &&
            likesByRest.values.every((supporters) => supporters.length < participants.length));

    if (shouldDispute) {
      _enterDispute(room, reason: 'no_consensus');
    } else {
      // Pick the highest-liked restaurant (default Shawarma Station)
      var winnerId = 30101;
      var bestCount = -1;
      likesByRest.forEach((rid, sup) {
        if (sup.length > bestCount && _menuByRestaurant.containsKey(rid)) {
          bestCount = sup.length;
          winnerId = rid;
        }
      });
      _beginMatching(room, resolutionType: 'consensus', selectedRestaurantIds: [winnerId]);
    }
  }

  void _enterDispute(Map<String, dynamic> room, {required String reason}) {
    final participants = [for (final p in room['participants'] as List) p as Map<String, dynamic>];
    final blocA = <String>[];
    final blocB = <String>[];
    for (var i = 0; i < participants.length; i++) {
      if (i.isEven) {
        blocA.add('${participants[i]['id']}');
      } else {
        blocB.add('${participants[i]['id']}');
      }
    }
    if (blocB.isEmpty && blocA.length > 1) {
      blocB.add(blocA.removeLast());
    }
    final rA = _menuByRestaurant[30101]!;
    final rB = _menuByRestaurant[30103]!;
    room['stage'] = 'dispute';
    room['_dispute_started_at'] = _now;
    room['dispute'] = {
      'reason': reason,
      'contenders': [
        {
          'restaurant_id': rA['id'],
          'name': rA['name'],
          'image_url': rA['image_url'],
          'cuisine': rA['cuisine'],
          'supporter_ids': blocA,
        },
        {
          'restaurant_id': rB['id'],
          'name': rB['name'],
          'image_url': rB['image_url'],
          'cuisine': rB['cuisine'],
          'supporter_ids': blocB,
        },
      ],
      'method_votes': <String, dynamic>{},
      'method': null,
      'wheel': null,
      'split': null,
    };
  }

  bool _tryFinalizeMethodVote(Map<String, dynamic> room) {
    final dispute = room['dispute'] as Map<String, dynamic>;
    if (dispute['method'] != null) return false;
    final participants = [for (final p in room['participants'] as List) p as Map<String, dynamic>];
    final votes = Map<String, dynamic>.from((dispute['method_votes'] ?? const {}) as Map);
    if (votes.length < participants.length) return false;

    var wheelVotes = 0;
    var splitVotes = 0;
    for (final v in votes.values) {
      if (v == 'wheel') wheelVotes++;
      if (v == 'split') splitVotes++;
    }
    final String method;
    if (wheelVotes > splitVotes) {
      method = 'wheel';
    } else if (splitVotes > wheelVotes) {
      method = 'split';
    } else {
      // Tie broken by host's vote
      method = (votes[room['host_id']] as String?) ?? 'wheel';
    }
    dispute['method'] = method;
    final contenders = [for (final c in dispute['contenders'] as List) c as Map<String, dynamic>];
    if (method == 'wheel') {
      dispute['wheel'] = {
        'segments': [
          for (final c in contenders)
            {
              'restaurant_id': c['restaurant_id'],
              'name': c['name'],
              'weight': max(1, (c['supporter_ids'] as List).length),
            },
        ],
        'spin_id': null,
        'spin_started_at_ms': null,
        'duration_ms': fastDemo ? 600 : 4200,
        'final_angle_deg': null,
        'winner_restaurant_id': null,
      };
    } else {
      dispute['split'] = {
        'groups': [
          for (final c in contenders)
            {
              'restaurant_id': c['restaurant_id'],
              'name': c['name'],
              'image_url': c['image_url'],
              'participant_ids': List<String>.from(c['supporter_ids'] as List),
            },
        ],
        'confirmed': false,
      };
    }
    return true;
  }

  void _beginMatching(
    Map<String, dynamic> room, {
    required String resolutionType,
    required List<int> selectedRestaurantIds,
    List<Map<String, dynamic>>? explicitGroups,
  }) {
    final participants = [for (final p in room['participants'] as List) p as Map<String, dynamic>];
    final groupsJson = <Map<String, dynamic>>[];

    if (explicitGroups != null && explicitGroups.isNotEmpty) {
      var gi = 1;
      for (final sg in explicitGroups) {
        final pids = List<String>.from(sg['participant_ids'] as List);
        if (pids.isEmpty) continue;
        final rid = (sg['restaurant_id'] as num).toInt();
        groupsJson.add(_buildResultGroup('g$gi', rid, pids, participants, room['mode'] as String));
        gi++;
      }
    } else {
      final rid = selectedRestaurantIds.first;
      final pids = [for (final p in participants) '${p['id']}'];
      groupsJson.add(_buildResultGroup('g1', rid, pids, participants, room['mode'] as String));
    }

    final first = groupsJson.first;
    final firstRestId = (first['restaurant'] as Map<String, dynamic>)['id'];
    final trace = [
      {
        'iteration': 1,
        'tool': 'food_merchant_search',
        'input': {'location': 'Amman', 'meal': (room['settings'] as Map)['meal'] ?? 'dinner'},
        'output_summary': 'Found ${groupsJson.length == 1 ? 'top candidate' : '${groupsJson.length} group restaurants'} open in Amman.',
        'failed': false,
      },
      {
        'iteration': 2,
        'tool': 'food_get_restaurant_menu',
        'input': {'restaurant_id': firstRestId},
        'output_summary': 'Verified menu items and live pricing.',
        'failed': false,
      },
      {
        'iteration': 3,
        'tool': 'cart_add_items',
        'input': {'merchant_id': firstRestId, 'items': ['primary_selection']},
        'output_summary': 'Failed: required modifier group missing on main item. Re-planning.',
        'failed': true,
      },
      {
        'iteration': 4,
        'tool': 'food_get_items_options',
        'input': {'restaurant_id': firstRestId},
        'output_summary': 'Loaded required options and picked valid house defaults.',
        'failed': false,
      },
      {
        'iteration': 5,
        'tool': 'cart_get_basket_price',
        'input': {'merchant_id': firstRestId, 'groups': groupsJson.length},
        'output_summary': 'Basket priced cleanly (${groupsJson.length == 1 ? '${first['total_price']} JOD' : '${groupsJson.length} separate orders'}).',
        'failed': false,
      },
    ];

    room['stage'] = 'matching';
    room['_matching_started_at'] = _now;
    room['_trace_visible'] = 1;
    room['_full_trace'] = trace;
    room['_result'] = {
      'status': 'ready',
      'resolution': {'type': resolutionType},
      'groups': groupsJson,
      'restaurant': groupsJson.length == 1 ? first['restaurant'] : null,
      'basket': groupsJson.length == 1 ? first['basket'] : const [],
      'total_price': groupsJson.fold<double>(0, (s, g) => s + ((g['total_price'] as num).toDouble())),
      'currency': 'JOD',
      'reasoning': groupsJson.length == 1
          ? first['reasoning']
          : 'You split into ${groupsJson.length} groups so everyone gets their top craving with zero compromise.',
      'per_person': [for (final g in groupsJson) ...(g['per_person'] as List)],
      'scores': const [],
      'agent_trace': trace,
    };
  }

  Map<String, dynamic> _buildResultGroup(
    String groupId,
    int rid,
    List<String> pids,
    List<Map<String, dynamic>> allParticipants,
    String mode,
  ) {
    final rest = _menuByRestaurant[rid] ?? _menuByRestaurant[30101]!;
    final dishes = [for (final d in rest['dishes'] as List) d as Map<String, dynamic>];
    final basket = <Map<String, dynamic>>[];
    final perPerson = <Map<String, dynamic>>[];
    var total = 0.0;

    for (var i = 0; i < pids.length; i++) {
      final pid = pids[i];
      final person = allParticipants.firstWhere((p) => '${p['id']}' == pid, orElse: () => {'id': pid, 'name': 'Guest'});
      final name = '${person['name']}';
      final dish = dishes[i % dishes.length];
      final price = (dish['price'] as num).toDouble();
      if (mode == 'food') {
        total += price;
        basket.add({
          'participant_id': pid,
          'name': name,
          'dish_name': dish['name'],
          'price': price,
          'image_url': rest['image_url'],
          'options': dish['options'],
        });
      }
      perPerson.add({
        'participant_id': pid,
        'name': name,
        'why': 'Matches $name\'s swipe for ${rest['cuisine'].toString().toLowerCase()} with ${dish['name']}.',
      });
    }

    return {
      'group_id': groupId,
      'restaurant': {
        'id': rest['id'],
        'name': rest['name'],
        'image_url': rest['image_url'],
        'cuisine': rest['cuisine'],
        'rating': rest['rating'],
        'link': rest['link'],
      },
      'participant_ids': pids,
      'basket': basket,
      'total_price': double.parse(total.toStringAsFixed(2)),
      'currency': 'JOD',
      'reasoning': '${rest['name']} satisfies everyone in this group with fast prep and available favorites.',
      'per_person': perPerson,
    };
  }

  @override
  Future<HealthInfo> health() async => const HealthInfo(status: 'ok', demo: true);

  @override
  Future<CreateRoomResult> createRoom({required RoomMode mode, required String hostName}) async {
    final code = _genCode();
    final hostId = _genId('host');
    final joinUrl = '${SessionStore.origin()}/#/join/$code';
    final room = <String, dynamic>{
      'room_code': code,
      'mode': mode.wire,
      'stage': 'lobby',
      'version': 1,
      'host_id': hostId,
      'join_url': joinUrl,
      'level': null,
      'settings': {'meal': 'dinner'},
      'participants': [
        {
          'id': hostId,
          'name': hostName.trim(),
          'is_host': true,
          'is_bot': false,
          'progress': {'level': null, 'swiped': 0, 'total': 0, 'done': false},
        },
      ],
      'dispute': null,
      '_swipes': <String, dynamic>{},
      '_scenario': _forceDispute ? 'dispute' : 'consensus',
    };
    _writeRoom(room);
    return CreateRoomResult(roomCode: code, participantId: hostId, joinUrl: joinUrl);
  }

  @override
  Future<JoinRoomResult> joinRoom(String code, {required String name}) async {
    final room = _readRoom(code);
    final pid = _genId('guest');
    final level = room['level'] as String?;
    final total = level == 'category'
        ? _categoryCards.length
        : level == 'restaurant'
            ? _restaurantCards.length
            : 0;
    (room['participants'] as List).add({
      'id': pid,
      'name': name.trim(),
      'is_host': false,
      'is_bot': false,
      'progress': {'level': level, 'swiped': 0, 'total': total, 'done': false},
    });
    _writeRoom(room);
    return JoinRoomResult(participantId: pid);
  }

  @override
  Future<Room> getRoom(String code, {String? participantId}) async {
    final room = _readRoom(code);
    if (_tickRoom(room)) _writeRoom(room);
    return Room.fromJson(room);
  }

  @override
  Future<void> nextStage(String code, {required String participantId}) async {
    final room = _readRoom(code);
    if (room['host_id'] != participantId) throw const ApiException('Only the host can continue.', 403);
    room['stage'] = 'settings';
    _writeRoom(room);
  }

  @override
  Future<void> updateSettings(String code, {required String participantId, required MealType meal}) async {
    final room = _readRoom(code);
    if (room['host_id'] != participantId) throw const ApiException('Only the host can change meal settings.', 403);
    room['settings'] = {'meal': meal.wire};
    _writeRoom(room);
  }

  @override
  Future<void> startSwiping(String code, {required String participantId}) async {
    final room = _readRoom(code);
    if (room['host_id'] != participantId) throw const ApiException('Only the host can start.', 403);
    room['stage'] = 'swiping';
    room['level'] = 'category';
    room['_level_started_at'] = _now;
    for (final p in room['participants'] as List) {
      (p as Map<String, dynamic>)['progress'] = {
        'level': 'category',
        'swiped': 0,
        'total': _categoryCards.length,
        'done': false,
      };
    }
    _writeRoom(room);
  }

  @override
  Future<void> addDemoFriends(String code, {required String participantId, required int count, required String scenario}) async {
    final room = _readRoom(code);
    const botNames = ['Layla', 'Omar', 'Nour', 'Zaid'];
    final participants = room['participants'] as List;
    final existingBots = participants.where((p) => (p as Map)['is_bot'] == true).length;
    for (var i = 0; i < count.clamp(1, 4); i++) {
      final name = botNames[(existingBots + i) % botNames.length];
      participants.add({
        'id': _genId('bot'),
        'name': name,
        'is_host': false,
        'is_bot': true,
        'progress': {'level': null, 'swiped': 0, 'total': 0, 'done': false},
      });
    }
    room['_scenario'] = _forceDispute ? 'dispute' : scenario;
    _writeRoom(room);
  }

  @override
  Future<CardsResponse> getCards(String code, {required String participantId}) async {
    final room = _readRoom(code);
    final level = SwipeLevel.parse(room['level'] as String?) ?? SwipeLevel.category;
    final raw = level == SwipeLevel.category ? _categoryCards : _restaurantCards;
    return CardsResponse(
      level: level,
      cards: [for (final c in raw) SwipeCard.fromJson(c)],
    );
  }

  @override
  Future<SwipeResponse> swipe(
    String code, {
    required String participantId,
    required SwipeLevel level,
    required String cardId,
    required bool liked,
  }) async {
    final room = _readRoom(code);
    final swipes = (room['_swipes'] as Map<String, dynamic>);
    final ps = Map<String, dynamic>.from((swipes[participantId] ?? const {}) as Map);
    ps[cardId] = liked;
    swipes[participantId] = ps;

    final total = level == SwipeLevel.category ? _categoryCards.length : _restaurantCards.length;
    final participants = [for (final p in room['participants'] as List) p as Map<String, dynamic>];
    var done = false;
    for (final p in participants) {
      if (p['id'] == participantId) {
        final prog = p['progress'] as Map<String, dynamic>;
        final next = (((prog['swiped'] as num?)?.toInt() ?? 0) + 1).clamp(0, total);
        done = next >= total;
        prog['level'] = level.wire;
        prog['swiped'] = next;
        prog['total'] = total;
        prog['done'] = done;
      }
    }
    _tickRoom(room);
    _writeRoom(room);
    return SwipeResponse(ok: true, levelDone: done);
  }

  @override
  Future<void> startDispute(String code, {required String participantId}) async {
    final room = _readRoom(code);
    if (room['host_id'] != participantId) throw const ApiException('Only the host can start a dispute.', 403);
    _enterDispute(room, reason: 'host_requested');
    _writeRoom(room);
  }

  @override
  Future<void> voteDispute(String code, {required String participantId, required String method}) async {
    final room = _readRoom(code);
    final dispute = room['dispute'] as Map<String, dynamic>?;
    if (dispute == null) return;
    final votes = Map<String, dynamic>.from((dispute['method_votes'] ?? const {}) as Map);
    votes[participantId] = method;
    dispute['method_votes'] = votes;
    if (fastDemo) _tickRoom(room);
    _tryFinalizeMethodVote(room);
    _writeRoom(room);
  }

  @override
  Future<void> spinWheel(String code, {required String participantId}) async {
    final room = _readRoom(code);
    if (room['host_id'] != participantId) throw const ApiException('Only the host can spin the wheel.', 403);
    final dispute = room['dispute'] as Map<String, dynamic>?;
    final wheel = dispute?['wheel'] as Map<String, dynamic>?;
    if (wheel == null || wheel['spin_id'] != null) return;

    final segments = [for (final s in wheel['segments'] as List) s as Map<String, dynamic>];
    final totalW = segments.fold<double>(0, (sum, s) => sum + ((s['weight'] as num).toDouble()));
    final targetAngle = 25.0 + _rng.nextDouble() * 310.0; // degrees where pointer lands in wheel-space
    // Determine which segment sits at the pointer after rotating clockwise by targetAngle
    final normalized = (360.0 - (targetAngle % 360.0)) % 360.0;
    var acc = 0.0;
    var winnerId = (segments.first['restaurant_id'] as num).toInt();
    for (final s in segments) {
      final sweep = ((s['weight'] as num).toDouble() / totalW) * 360.0;
      if (normalized >= acc && normalized < acc + sweep) {
        winnerId = (s['restaurant_id'] as num).toInt();
        break;
      }
      acc += sweep;
    }

    wheel['spin_id'] = _genId('spin');
    wheel['spin_started_at_ms'] = _now;
    wheel['duration_ms'] = fastDemo ? 600 : 4200;
    wheel['final_angle_deg'] = double.parse(targetAngle.toStringAsFixed(2));
    wheel['winner_restaurant_id'] = winnerId;
    _writeRoom(room);
  }

  @override
  Future<void> moveSplitGroup(String code, {required String participantId, required int restaurantId}) async {
    final room = _readRoom(code);
    final split = (room['dispute'] as Map<String, dynamic>?)?['split'] as Map<String, dynamic>?;
    if (split == null || split['confirmed'] == true) return;
    final groups = [for (final g in split['groups'] as List) g as Map<String, dynamic>];
    for (final g in groups) {
      final ids = List<String>.from(g['participant_ids'] as List);
      ids.remove(participantId);
      if ((g['restaurant_id'] as num).toInt() == restaurantId) {
        ids.add(participantId);
      }
      g['participant_ids'] = ids;
    }
    split['groups'] = [for (final g in groups) if ((g['participant_ids'] as List).isNotEmpty) g];
    _writeRoom(room);
  }

  @override
  Future<void> confirmSplit(String code, {required String participantId}) async {
    final room = _readRoom(code);
    if (room['host_id'] != participantId) throw const ApiException('Only the host can confirm groups.', 403);
    final split = (room['dispute'] as Map<String, dynamic>?)?['split'] as Map<String, dynamic>?;
    if (split == null) return;
    split['confirmed'] = true;
    final groups = [for (final g in split['groups'] as List) g as Map<String, dynamic>];
    _beginMatching(
      room,
      resolutionType: groups.length > 1 ? 'split' : 'consensus',
      selectedRestaurantIds: [for (final g in groups) (g['restaurant_id'] as num).toInt()],
      explicitGroups: groups,
    );
    _writeRoom(room);
  }

  @override
  Future<RoomResult> getResult(String code) async {
    final room = _readRoom(code);
    if (_tickRoom(room)) _writeRoom(room);
    final stage = room['stage'] as String;
    final res = room['_result'] as Map<String, dynamic>?;
    if (res == null) return const RoomResult(status: ResultStatus.running);
    if (stage == 'matching') {
      final vis = (room['_trace_visible'] as num?)?.toInt() ?? 1;
      final full = [for (final t in (res['agent_trace'] as List)) t as Map<String, dynamic>];
      return RoomResult.fromJson({
        ...res,
        'status': 'running',
        'agent_trace': full.take(vis).toList(),
      });
    }
    return RoomResult.fromJson(res);
  }

  @override
  Future<OrderResult> createOrder(String code, {required String participantId}) async {
    final room = _readRoom(code);
    final res = room['_result'] as Map<String, dynamic>?;
    final groups = [for (final g in ((res?['groups'] ?? const []) as List)) g as Map<String, dynamic>];
    final isDineOut = room['mode'] == 'dineout';
    final orderStatus = isDineOut ? 'go' : 'basket_ready';
    final outGroups = [
      for (final g in groups)
        {
          'group_id': g['group_id'],
          'status': orderStatus,
          'price_breakdown': {'total': g['total_price'], 'currency': g['currency']},
          'restaurant_link': (g['restaurant'] as Map)['link'],
          'message': isDineOut ? 'Directions ready for ${(g['restaurant'] as Map)['name']}.' : 'Group basket ready in Careem Food.',
        },
    ];
    room['stage'] = 'ordered';
    room['_order_result'] = {'status': orderStatus, 'groups': outGroups};
    _writeRoom(room);
    return OrderResult.fromJson(room['_order_result'] as Map<String, dynamic>);
  }
}
