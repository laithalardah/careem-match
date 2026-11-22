import 'package:web/web.dart' as web;

String? sessionGet(String key) {
  try {
    return web.window.sessionStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void sessionSet(String key, String value) {
  try {
    web.window.sessionStorage.setItem(key, value);
  } catch (_) {}
}

void sessionRemove(String key) {
  try {
    web.window.sessionStorage.removeItem(key);
  } catch (_) {}
}

String? localGet(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void localSet(String key, String value) {
  try {
    web.window.localStorage.setItem(key, value);
  } catch (_) {}
}

String currentOrigin() {
  try {
    final o = web.window.location.origin;
    if (o.isNotEmpty) return o;
  } catch (_) {}
  return 'http://localhost:8080';
}
