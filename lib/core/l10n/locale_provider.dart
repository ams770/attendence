import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for app locale. When null, the app falls back to device locale.
final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    return null;
  }

  void setLocale(Locale? locale) {
    state = locale;
  }
}
