import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'models.dart';

abstract class Api {
  bool get isMock => false;
  Future<StartResult> start(String location);
  Future<void> swipe(String sessionId, int player, String dishId, bool liked);
  Future<void> run(String sessionId);
  Future<MatchResult> result(String sessionId);
}

/// Real backend (FastAPI). Set with --dart-define=API_BASE=http://127.0.0.1:8000
class HttpApi implements Api {
  HttpApi(this.base);
  final String base;

  @override
  bool get isMock => false;

  Uri _u(String path) => Uri.parse('$base$path');
  Map<String, String> get _json => {'Content-Type': 'application/json'};

  Future<Map<String, dynamic>> _check(http.Response r) async {
    if (r.statusCode >= 400) throw Exception('HTTP ${r.statusCode}: ${r.body}');
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  @override
  Future<StartResult> start(String location) async {
    final j = await _check(await http.post(_u('/session/start'), headers: _json, body: jsonEncode({'location': location})));
    return StartResult(j['session_id'] as String, [for (final d in j['dishes'] as List) Dish.fromJson(d as Map<String, dynamic>)]);
  }

  @override
  Future<void> swipe(String id, int player, String dishId, bool liked) async {
    await _check(await http.post(_u('/session/$id/swipe'),
        headers: _json, body: jsonEncode({'player': player, 'dish_id': dishId, 'liked': liked})));
  }

  @override
  Future<void> run(String id) async {
    await _check(await http.post(_u('/session/$id/run'), headers: _json, body: '{}'));
  }

  @override
  Future<MatchResult> result(String id) async => MatchResult.fromJson(await _check(await http.get(_u('/session/$id/result'))));
}

/// Offline stand-in so the UI runs before the backend exists. Uses the real cached deck
/// (assets/mock_deck.json, produced by backend/deck.py) and a simple overlap rule.
class MockApi implements Api {
  @override
  bool get isMock => true;

  Map<String, dynamic>? _deck;
  final _likes = <int, Set<String>>{1: {}, 2: {}};
  int _polls = 0;

  Future<Map<String, dynamic>> _load() async =>
      _deck ??= jsonDecode(await rootBundle.loadString('assets/mock_deck.json')) as Map<String, dynamic>;

  @override
  Future<StartResult> start(String location) async {
    final deck = await _load();
    _likes
      ..[1] = {}
      ..[2] = {};
    _polls = 0;
    return StartResult('mock-session', [for (final d in deck['dishes'] as List) Dish.fromJson(d as Map<String, dynamic>)]);
  }

  @override
  Future<void> swipe(String sessionId, int player, String dishId, bool liked) async {
    if (liked) _likes[player]!.add(dishId);
  }

  @override
  Future<void> run(String sessionId) async => _polls = 0;

  @override
  Future<MatchResult> result(String sessionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (++_polls < 4) return const MatchResult(status: ResultStatus.running);

    final deck = await _load();
    final dishes = [for (final d in deck['dishes'] as List) d as Map<String, dynamic>];
    final byRestaurant = <int, List<Map<String, dynamic>>>{};
    for (final d in dishes) {
      byRestaurant.putIfAbsent(d['restaurant_id'] as int, () => []).add(d);
    }

    int? best;
    var bestScore = 0;
    byRestaurant.forEach((rid, ds) {
      final a = ds.where((d) => _likes[1]!.contains(d['id'])).length;
      final b = ds.where((d) => _likes[2]!.contains(d['id'])).length;
      if (a > 0 && b > 0 && a + b > bestScore) {
        best = rid;
        bestScore = a + b;
      }
    });

    if (best == null) {
      return const MatchResult(
        status: ResultStatus.noMatch,
        reasoning: 'No single restaurant serves a dish each of you liked.',
        trace: [
          TraceStep(iteration: 1, tool: 'food_merchant_search', input: {'query': 'liked dishes'}, outputSummary: 'No restaurant overlaps both players.'),
        ],
      );
    }

    final r = (deck['restaurants'] as Map<String, dynamic>)['$best'] as Map<String, dynamic>;
    final lines = <BasketLine>[];
    for (final player in [1, 2]) {
      for (final d in byRestaurant[best]!.where((d) => _likes[player]!.contains(d['id']))) {
        lines.add(BasketLine(player: player, dishName: d['name'] as String, price: (d['price'] as num).toDouble(), imageUrl: d['image_url'] as String?));
      }
    }
    final needsOptions = byRestaurant[best]!.any((d) => d['requires_options'] == true);

    return MatchResult(
      status: ResultStatus.ready,
      restaurant: Restaurant.fromJson(r),
      basket: lines,
      totalPrice: lines.fold(0.0, (s, l) => s + l.price),
      currency: r['currency'] as String,
      reasoning: '${r['name']} is the only open restaurant that has a dish each of you liked, so one order covers both.',
      trace: [
        const TraceStep(iteration: 1, tool: 'food_merchant_search', input: {'query': 'liked dishes'}, outputSummary: 'Found restaurants serving the liked dishes.'),
        TraceStep(iteration: 2, tool: 'food_get_restaurant_menu', input: {'restaurant_id': best}, outputSummary: 'Menu loaded, restaurant open.'),
        if (needsOptions) ...[
          TraceStep(iteration: 3, tool: 'cart_add_items', input: {'merchant_id': best}, outputSummary: 'Failed: a required option was missing. Re-planning.'),
          TraceStep(iteration: 4, tool: 'food_get_items_options', input: {'restaurant_id': best}, outputSummary: 'Got required option groups; picked the defaults.'),
        ],
        TraceStep(iteration: needsOptions ? 5 : 3, tool: 'cart_get_basket_price', input: {'merchant_id': best}, outputSummary: 'Priced the basket.'),
      ],
    );
  }
}
