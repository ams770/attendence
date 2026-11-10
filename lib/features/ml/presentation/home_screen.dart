import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/model_self_check.dart';

/// Minimal home screen showing application title, self-check status, ready state,
/// and developer tools in debug mode.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.report});

  final SelfCheckReport? report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final List<ModelCheckResult> results =
        report?.results ?? const <ModelCheckResult>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.selfCheckPassed,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        l10n.homeStatusReady,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              FilledButton.icon(
                onPressed: () => context.push('/verification'),
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(l10n.startVerification),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                ),
              ),
              const SizedBox(height: 8.0),
              FilledButton.tonalIcon(
                onPressed: () => context.push('/employees'),
                icon: const Icon(Icons.people_outline),
                label: Text(l10n.homeEmployeesAction),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                ),
              ),
              const SizedBox(height: 16.0),
              ...<Widget>[
                OutlinedButton.icon(
                  onPressed: () => context.push('/dev/camera'),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(l10n.homeDevCameraAction),
                ),
                const SizedBox(height: 8.0),
                OutlinedButton.icon(
                  onPressed: () => context.push('/dev/detection'),
                  icon: const Icon(Icons.face_outlined),
                  label: Text(l10n.homeDevDetectionAction),
                ),
                const SizedBox(height: 8.0),
                OutlinedButton.icon(
                  onPressed: () => context.push('/dev/passive'),
                  icon: const Icon(Icons.security_outlined),
                  label: Text(l10n.homeDevPassiveAction),
                ),
                const SizedBox(height: 8.0),
                OutlinedButton.icon(
                  onPressed: () => context.push('/dev/challenges'),
                  icon: const Icon(Icons.psychology_outlined),
                  label: Text(l10n.homeDevChallengesAction),
                ),
                const SizedBox(height: 16.0),
              ],
              if (results.isNotEmpty) ...<Widget>[
                Text(
                  l10n.verifiedModelsHeader,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8.0),
                ...results.map(
                  (ModelCheckResult modelResult) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Card(
                      child: ListTile(
                        title: Text(modelResult.spec.name),
                        subtitle: Text(modelResult.spec.assetPath),
                        trailing: Text(
                          modelResult.isSuccess
                              ? l10n.statusPassed
                              : l10n.statusFailed,
                          style: TextStyle(
                            color: modelResult.isSuccess
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
