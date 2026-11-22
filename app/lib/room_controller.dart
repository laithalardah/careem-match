import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'models.dart';
import 'storage.dart';

/// Polls a v2.1 room every 1 s, only notifying when `room.version` (or matching trace) changes.
class RoomController extends ChangeNotifier {
  RoomController({
    required this.api,
    required this.roomCode,
    this.pollInterval = const Duration(seconds: 1),
  }) {
    participantId = SessionStore.getParticipantId(roomCode);
  }

  final Api api;
  final String roomCode;
  final Duration pollInterval;

  String? participantId;
  Room? room;
  HealthInfo health = const HealthInfo(status: 'ok', demo: false);
  CardsResponse? cards;
  RoomResult? result;
  OrderResult? orderResult;

  bool initialLoading = true;
  bool busy = false;
  String? error;
  int _consecutivePollErrors = 0;
  int _lastVersion = -1;
  SwipeLevel? _fetchedCardsLevel;
  int _lastTraceLen = -1;
  ResultStatus? _lastResultStatus;
  bool _disposed = false;
  bool _polling = false;
  Timer? _timer;

  /// True once 3 consecutive room polls have failed (drives a non-blocking banner).
  bool get connectionLost => _consecutivePollErrors >= 3;

  bool get isHost => room != null && participantId != null && room!.hostId == participantId;

  Participant? get me => room?.participantById(participantId);

  String get joinUrl {
    final u = room?.joinUrl ?? '';
    if (u.isNotEmpty) return u;
    return '${SessionStore.origin()}/#/join/$roomCode';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> init() async {
    participantId = SessionStore.getParticipantId(roomCode);
    try {
      health = await api.health();
    } catch (_) {
      health = HealthInfo(status: 'ok', demo: api.isMock);
    }
    await _pollOnce(force: true);
    if (_disposed) return;
    initialLoading = false;
    _notify();
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => _pollOnce());
  }

  Future<void> _pollOnce({bool force = false}) async {
    if (_disposed || _polling) return;
    _polling = true;
    try {
      final fetched = await api.getRoom(roomCode, participantId: participantId);
      final recovered = _consecutivePollErrors >= 3;
      _consecutivePollErrors = 0;

      final versionChanged = force || fetched.version != _lastVersion;
      var shouldNotify = versionChanged || recovered;

      if (versionChanged) {
        _lastVersion = fetched.version;
        room = fetched;
      }

      final activeRoom = room ?? fetched;

      // Load cards whenever entering a new swipe level.
      if (activeRoom.stage == RoomStage.swiping &&
          activeRoom.level != null &&
          participantId != null &&
          _fetchedCardsLevel != activeRoom.level) {
        _fetchedCardsLevel = activeRoom.level;
        try {
          cards = await api.getCards(roomCode, participantId: participantId!);
          shouldNotify = true;
        } catch (_) {
          _fetchedCardsLevel = null;
        }
      }

      // Poll result during matching / result / ordered stages.
      if (activeRoom.stage == RoomStage.matching ||
          activeRoom.stage == RoomStage.result ||
          (activeRoom.stage == RoomStage.ordered && result == null)) {
        try {
          final r = await api.getResult(roomCode);
          if (r.trace.length != _lastTraceLen || r.status != _lastResultStatus || result == null) {
            result = r;
            _lastTraceLen = r.trace.length;
            _lastResultStatus = r.status;
            shouldNotify = true;
          }
        } catch (_) {}
      }

      if (shouldNotify) _notify();
    } catch (e) {
      _consecutivePollErrors++;
      if (initialLoading) {
        error = 'Could not load room $roomCode. Check the code and try again.';
        _notify();
      } else if (_consecutivePollErrors == 3) {
        _notify();
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _runAction(Future<void> Function() fn, {String fallbackError = 'Action failed. Please try again.'}) async {
    if (busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      await fn();
      await _pollOnce(force: true);
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = fallbackError;
    } finally {
      busy = false;
      _notify();
    }
  }

  void dismissError() {
    error = null;
    _notify();
  }

  Future<void> nextToSettings() => _runAction(
        () => api.nextStage(roomCode, participantId: participantId!),
        fallbackError: 'Could not advance to settings.',
      );

  Future<void> setMeal(MealType meal) => _runAction(
        () => api.updateSettings(roomCode, participantId: participantId!, meal: meal),
        fallbackError: 'Could not update meal choice.',
      );

  Future<void> startSwiping() => _runAction(
        () => api.startSwiping(roomCode, participantId: participantId!),
        fallbackError: 'Could not start swiping.',
      );

  Future<void> addDemoFriends({required int count, required String scenario}) => _runAction(
        () => api.addDemoFriends(roomCode, participantId: participantId!, count: count, scenario: scenario),
        fallbackError: 'Could not add demo friends.',
      );

  Future<SwipeResponse?> swipeCard(SwipeLevel level, String cardId, bool liked) async {
    final pid = participantId;
    if (pid == null) return null;
    try {
      final resp = await api.swipe(roomCode, participantId: pid, level: level, cardId: cardId, liked: liked);
      if (resp.levelDone) {
        await _pollOnce(force: true);
      }
      return resp;
    } catch (_) {
      error = 'A swipe did not reach the server.';
      _notify();
      return null;
    }
  }

  Future<void> requestEarlyDispute() => _runAction(
        () => api.startDispute(roomCode, participantId: participantId!),
        fallbackError: 'Could not open dispute resolver.',
      );

  Future<void> voteDispute(String method) => _runAction(
        () => api.voteDispute(roomCode, participantId: participantId!, method: method),
        fallbackError: 'Could not record vote.',
      );

  Future<void> spinWheel() => _runAction(
        () => api.spinWheel(roomCode, participantId: participantId!),
        fallbackError: 'Could not spin the wheel.',
      );

  Future<void> moveSplitGroup(int restaurantId) => _runAction(
        () => api.moveSplitGroup(roomCode, participantId: participantId!, restaurantId: restaurantId),
        fallbackError: 'Could not switch groups.',
      );

  Future<void> confirmSplit() => _runAction(
        () => api.confirmSplit(roomCode, participantId: participantId!),
        fallbackError: 'Could not confirm split groups.',
      );

  Future<void> retryResult() async {
    _lastTraceLen = -1;
    _lastResultStatus = null;
    await _pollOnce(force: true);
  }

  Future<OrderResult?> submitOrder() async {
    OrderResult? out;
    await _runAction(() async {
      out = await api.createOrder(roomCode, participantId: participantId!);
      orderResult = out;
    }, fallbackError: 'Could not prepare the order.');
    return out;
  }

  /// Finds the group that contains the current participant (falls back to first group).
  ResultGroup? myGroup() {
    final groups = result?.groups ?? const <ResultGroup>[];
    if (groups.isEmpty) return null;
    final pid = participantId;
    if (pid != null) {
      for (final g in groups) {
        if (g.participantIds.contains(pid)) return g;
      }
    }
    return groups.first;
  }

  OrderGroupStatus? orderStatusFor(String groupId) {
    final gs = orderResult?.groups ?? const <OrderGroupStatus>[];
    for (final g in gs) {
      if (g.groupId == groupId) return g;
    }
    return gs.isNotEmpty ? gs.first : null;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
