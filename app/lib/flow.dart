import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'models.dart';

enum Phase { hub, home, swipe1, handoff, swipe2, running, result }

/// hub (Careem-style main screen) -> home (Match intro) -> player 1 swipes -> handoff ->
/// player 2 swipes -> agent runs -> result.
class GameFlow extends ChangeNotifier {
  GameFlow(this.api);
  final Api api;

  static const location = 'Amman, Jordan';

  Phase phase = Phase.hub;
  String? sessionId;
  List<Dish> dishes = const [];
  MatchResult? result;
  String? error;
  bool busy = false;
  Timer? _poll;

  void _set(void Function() f) {
    f();
    notifyListeners();
  }

  Future<void> start() async {
    _set(() {
      busy = true;
      error = null;
    });
    try {
      final s = await api.start(location);
      _set(() {
        sessionId = s.sessionId;
        dishes = s.dishes;
        result = null;
        phase = Phase.swipe1;
      });
    } catch (_) {
      _set(() => error = 'Could not start a session. Check that the backend is running, then try again.');
    } finally {
      _set(() => busy = false);
    }
  }

  void swipe(int player, Dish dish, bool liked) {
    final id = sessionId;
    if (id == null) return;
    api.swipe(id, player, dish.id, liked).catchError((_) {
      _set(() => error = 'A swipe did not reach the server. Your match may be incomplete.');
    });
  }

  void finishPlayer1() => _set(() => phase = Phase.handoff);
  void startPlayer2() => _set(() => phase = Phase.swipe2);

  Future<void> finishPlayer2() async {
    _set(() {
      phase = Phase.running;
      result = null;
      error = null;
    });
    await _run();
  }

  Future<void> retry() async {
    _set(() {
      phase = Phase.running;
      result = null;
      error = null;
    });
    await _run();
  }

  Future<void> _run() async {
    final id = sessionId!;
    try {
      await api.run(id);
    } catch (_) {
      _set(() {
        result = const MatchResult(status: ResultStatus.failed, reasoning: 'The agent could not be started.');
        phase = Phase.result;
      });
      return;
    }
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 1), (t) async {
      try {
        final r = await api.result(id);
        if (r.status == ResultStatus.running) {
          _set(() => result = r);
        } else {
          t.cancel();
          _set(() {
            result = r;
            phase = Phase.result;
          });
        }
      } catch (_) {
        t.cancel();
        _set(() {
          result = const MatchResult(status: ResultStatus.failed, reasoning: 'Lost contact with the server.');
          phase = Phase.result;
        });
      }
    });
  }

  void reset() {
    _poll?.cancel();
    _set(() {
      phase = Phase.home; // back to the Match intro, one tap from a new game
      result = null;
      error = null;
      sessionId = null;
    });
  }

  void dismissError() => _set(() => error = null);

  /// Open Careem Match from the hub tile.
  void openMatch() => _set(() => phase = Phase.home);

  /// Leave Careem Match and go back to the main screen.
  void goHub() {
    _poll?.cancel();
    _set(() {
      phase = Phase.hub;
      error = null;
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
