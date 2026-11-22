final _session = <String, String>{};
final _local = <String, String>{};

String? sessionGet(String key) => _session[key];
void sessionSet(String key, String value) => _session[key] = value;
void sessionRemove(String key) => _session.remove(key);

String? localGet(String key) => _local[key];
void localSet(String key, String value) => _local[key] = value;

String currentOrigin() => 'http://localhost:8080';
