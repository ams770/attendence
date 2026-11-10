import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/model_self_check.dart';

/// Full-screen error screen displayed when one or more AI models fail self-check.
class ModelErrorScreen extends ConsumerWidget {
  const ModelErrorScreen({super.key, this.report, this.errorMessage});

  final SelfCheckReport? report;
  final String? errorMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final List<ModelCheckResult> failures =
        report?.failures ?? const <ModelCheckResult>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.selfCheckFailedTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    errorMessage ?? l10n.selfCheckFailedDescription,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              if (failures.isNotEmpty) ...<Widget>[
                Text(
                  l10n.failedModelsHeader,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8.0),
                Expanded(
                  child: ListView.separated(
                    itemCount: failures.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8.0),
                    itemBuilder: (BuildContext context, int index) {
                      final ModelCheckResult failure = failures[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${l10n.modelNameLabel}: ${failure.spec.name}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                '${l10n.expectedPathLabel}: ${failure.spec.assetPath}',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                '${l10n.reasonLabel}: ${failure.errorMessage ?? l10n.statusFailed}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...<Widget>[const Spacer()],
              const SizedBox(height: 16.0),
              FilledButton(
                onPressed: () {
                  ref.read(selfCheckProvider.notifier).retry();
                },
                child: Text(l10n.retryButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
