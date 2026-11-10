import 'dart:math' as math;

import '../../../core/config/app_config.dart';
import '../../../core/utils/clock.dart';
import 'session_lockout_storage.dart';

/// Manages consecutive failure counts, lockout state, and expiration.
class SessionLockoutTracker {
  SessionLockoutTracker({
    required this.clock,
    required this.storage,
    this.config = const AppConfig(),
  });

  final Clock clock;
  final SessionLockoutStorage storage;
  final AppConfig config;

  /// Checks whether verification is currently locked out.
  Future<bool> isLocked() async {
    final DateTime? until = await storage.getLockoutUntil();
    if (until == null) return false;
    final DateTime now = clock.now();
    if (until.isAfter(now)) {
      return true;
    }
    // Lockout expired: clear timestamp
    await storage.setLockoutUntil(null);
    return false;
  }

  /// Returns the timestamp until which verification is locked, or null if not locked.
  Future<DateTime?> getLockoutUntil() async {
    final bool locked = await isLocked();
    if (!locked) return null;
    return storage.getLockoutUntil();
  }

  /// Returns remaining lockout time in whole seconds (0 if not locked).
  Future<int> getRemainingLockoutSeconds() async {
    final DateTime? until = await storage.getLockoutUntil();
    if (until == null) return 0;
    final DateTime now = clock.now();
    if (!until.isAfter(now)) {
      await storage.setLockoutUntil(null);
      return 0;
    }
    return math.max(0, until.difference(now).inSeconds);
  }

  /// Returns current consecutive failure count.
  Future<int> getConsecutiveFailures() => storage.getConsecutiveFailures();

  /// Records a session failure.
  ///
  /// Increments consecutive failures. If count reaches [config.failureLimit],
  /// activates lockout for [config.lockoutDuration] and returns true.
  Future<bool> recordFailure() async {
    final int current = await storage.getConsecutiveFailures();
    final int updated = current + 1;
    await storage.setConsecutiveFailures(updated);

    if (updated >= config.failureLimit) {
      final DateTime until = clock.now().add(config.lockoutDuration);
      await storage.setLockoutUntil(until);
      return true;
    }
    return false;
  }

  /// Records a successful verification session, resetting failure count.
  Future<void> recordSuccess() async {
    await storage.clear();
  }

  /// Manually clears any active lockout and resets failures.
  Future<void> reset() async {
    await storage.clear();
  }
}
