import 'storage_stub.dart' if (dart.library.js_interop) 'storage_web.dart' as impl;

/// Per-tab sessionStorage + memory cache so a browser refresh keeps the user in the room.
class SessionStore {
  static final _mem = <String, String>{};

  static String? getParticipantId(String roomCode) {
    final k = 'cm_pid_${roomCode.toUpperCase()}';
    return _mem[k] ?? impl.sessionGet(k);
  }

  static void setParticipantId(String roomCode, String participantId) {
    final k = 'cm_pid_${roomCode.toUpperCase()}';
    _mem[k] = participantId;
    impl.sessionSet(k, participantId);
  }

  static void clearParticipantId(String roomCode) {
    final k = 'cm_pid_${roomCode.toUpperCase()}';
    _mem.remove(k);
    impl.sessionRemove(k);
  }

  static String? getLastName() => _mem['cm_name'] ?? impl.sessionGet('cm_name');

  static void setLastName(String name) {
    _mem['cm_name'] = name;
    impl.sessionSet('cm_name', name);
  }

  static String origin() => impl.currentOrigin();

  /// Cross-tab storage (localStorage on web, in-memory map on VM) for MockApi multi-tab demos.
  static String? sharedGet(String key) => impl.localGet(key);
  static void sharedSet(String key, String value) => impl.localSet(key, value);
}
