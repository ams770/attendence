import 'package:shared_preferences/shared_preferences.dart';

/// Contract for persisting verification session lockout timestamps and failure counts.
abstract interface class SessionLockoutStorage {
  /// Retrieves the persisted lockout expiration timestamp, or null if not locked.
  Future<DateTime?> getLockoutUntil();

  /// Persists the lockout expiration timestamp, or null to clear lockout.
  Future<void> setLockoutUntil(DateTime? until);

  /// Retrieves the current count of consecutive failed attempts.
  Future<int> getConsecutiveFailures();

  /// Persists the count of consecutive failed attempts.
  Future<void> setConsecutiveFailures(int count);

  /// Clears all lockout timestamps and resets failure counters.
  Future<void> clear();
}

/// In-memory implementation of [SessionLockoutStorage] for deterministic testing.
class InMemorySessionLockoutStorage implements SessionLockoutStorage {
  InMemorySessionLockoutStorage({
    DateTime? initialLockoutUntil,
    int initialConsecutiveFailures = 0,
  }) : _lockoutUntil = initialLockoutUntil,
       _consecutiveFailures = initialConsecutiveFailures;

  DateTime? _lockoutUntil;
  int _consecutiveFailures;

  @override
  Future<DateTime?> getLockoutUntil() async => _lockoutUntil;

  @override
  Future<void> setLockoutUntil(DateTime? until) async {
    _lockoutUntil = until;
  }

  @override
  Future<int> getConsecutiveFailures() async => _consecutiveFailures;

  @override
  Future<void> setConsecutiveFailures(int count) async {
    _consecutiveFailures = count;
  }

  @override
  Future<void> clear() async {
    _lockoutUntil = null;
    _consecutiveFailures = 0;
  }
}

/// Production implementation of [SessionLockoutStorage] backed by [SharedPreferences].
class SharedPrefsSessionLockoutStorage implements SessionLockoutStorage {
  SharedPrefsSessionLockoutStorage([this._preferences]);

  SharedPreferences? _preferences;

  static const String _lockoutKey = 'liveness_lockout_until_ms';
  static const String _failuresKey = 'liveness_consecutive_failures';

  Future<SharedPreferences> _getPrefs() async {
    if (_preferences != null) return _preferences!;
    _preferences = await SharedPreferences.getInstance();
    return _preferences!;
  }

  @override
  Future<DateTime?> getLockoutUntil() async {
    final SharedPreferences prefs = await _getPrefs();
    final int? ms = prefs.getInt(_lockoutKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> setLockoutUntil(DateTime? until) async {
    final SharedPreferences prefs = await _getPrefs();
    if (until == null) {
      await prefs.remove(_lockoutKey);
    } else {
      await prefs.setInt(_lockoutKey, until.millisecondsSinceEpoch);
    }
  }

  @override
  Future<int> getConsecutiveFailures() async {
    final SharedPreferences prefs = await _getPrefs();
    return prefs.getInt(_failuresKey) ?? 0;
  }

  @override
  Future<void> setConsecutiveFailures(int count) async {
    final SharedPreferences prefs = await _getPrefs();
    await prefs.setInt(_failuresKey, count);
  }

  @override
  Future<void> clear() async {
    final SharedPreferences prefs = await _getPrefs();
    await prefs.remove(_lockoutKey);
    await prefs.setInt(_failuresKey, 0);
  }
}
