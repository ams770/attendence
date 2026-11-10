import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/model_self_check.dart';
import 'home_screen.dart';
import 'model_error_screen.dart';

/// Entry screen running model self-checks and displaying loading, error, or home.
class StartupCheckScreen extends ConsumerWidget {
  const StartupCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SelfCheckReport> checkState = ref.watch(selfCheckProvider);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return checkState.when(
      loading: () => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: 16.0),
              Text(
                l10n.selfCheckInProgress,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      error: (Object error, StackTrace? stack) =>
          ModelErrorScreen(errorMessage: error.toString()),
      data: (SelfCheckReport report) {
        if (!report.isAllSuccess) {
          return ModelErrorScreen(report: report);
        }
        return HomeScreen(report: report);
      },
    );
  }
}
