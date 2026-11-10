import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../recognition/domain/face_matcher.dart';
import '../../recognition/domain/face_recognizer.dart';
import '../../recognition/domain/match_result.dart';
import '../domain/liveness_session.dart';

/// Screen presenting the final outcome of a liveness verification session,
/// including biometric 1:N employee identification when liveness is verified.
class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({
    super.key,
    required this.result,
    this.faceRecognizerOverride,
    this.faceMatcherOverride,
  });

  final LiveSessionResult result;
  final FaceRecognizer? faceRecognizerOverride;
  final FaceMatcher? faceMatcherOverride;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _isIdentifying = false;
  MatchResult? _matchResult;

  @override
  void initState() {
    super.initState();
    if (widget.result.passed && widget.result.verifiedFaces != null) {
      _runIdentification();
    }
  }

  Future<void> _runIdentification() async {
    setState(() => _isIdentifying = true);
    try {
      final FaceRecognizer recognizer =
          widget.faceRecognizerOverride ?? ref.read(faceRecognizerProvider);
      final FaceMatcher matcher =
          widget.faceMatcherOverride ?? ref.read(faceMatcherProvider);

      final List<double> embedding = await recognizer.embedVerifiedFaces(
        widget.result.verifiedFaces!,
      );
      final MatchResult match = await matcher.match(embedding);

      if (mounted) {
        setState(() {
          _matchResult = match;
          _isIdentifying = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isIdentifying = false);
      }
    }
  }

  String _getFailureReasonText(
    SessionFailureReason? reason,
    AppLocalizations l10n,
  ) {
    if (reason == null) return l10n.stateFailed;
    switch (reason) {
      case SessionFailureReason.timeout:
        return l10n.reasonTimeout;
      case SessionFailureReason.faceLost:
        return l10n.reasonFaceLost;
      case SessionFailureReason.trackingChanged:
        return l10n.reasonTrackingChanged;
      case SessionFailureReason.challengeFailed:
        return l10n.reasonChallengeFailed;
      case SessionFailureReason.passiveFailed:
        return l10n.reasonPassiveFailed;
      case SessionFailureReason.passiveHardFloorViolation:
        return l10n.reasonPassiveHardFloorViolation;
      case SessionFailureReason.temporalFailed:
        return l10n.reasonTemporalFailed;
      case SessionFailureReason.flashFailed:
        return l10n.reasonFlashFailed;
      case SessionFailureReason.cancelled:
        return l10n.reasonCancelled;
      case SessionFailureReason.tooManyAttempts:
        return l10n.reasonTooManyAttempts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final LiveSessionResult result = widget.result;
    final bool isPassed = result.passed;

    final Color statusColor = isPassed ? Colors.green : Colors.redAccent;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resultTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 16),

              // Status Icon
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor, width: 3),
                  ),
                  child: Icon(
                    isPassed
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    color: statusColor,
                    size: 56,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Headline
              Text(
                isPassed ? l10n.resultPassedTitle : l10n.resultFailedTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),

              const SizedBox(height: 12),

              // Failure reason description (if failed)
              if (!isPassed) ...<Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _getFailureReasonText(result.failureReason, l10n),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Biometric Employee Identification Result (if passed)
              if (isPassed) ...<Widget>[
                _buildIdentificationCard(l10n, theme),
                const SizedBox(height: 20),
              ],

              // Metrics Card
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: <Widget>[
                      _buildMetricRow(
                        context,
                        label: l10n.resultDuration(
                          result.duration.inMilliseconds,
                        ),
                        icon: Icons.timer_outlined,
                      ),
                      const Divider(height: 20),
                      _buildMetricRow(
                        context,
                        label: l10n.resultPassiveScore(
                          result.meanPassiveScore.toStringAsFixed(3),
                        ),
                        icon: Icons.shield_outlined,
                      ),
                      const Divider(height: 20),
                      _buildMetricRow(
                        context,
                        label: l10n.resultTemporalScore(
                          result.temporalConfidence.toStringAsFixed(3),
                        ),
                        icon: Icons.motion_photos_on_outlined,
                      ),
                      const Divider(height: 20),
                      _buildMetricRow(
                        context,
                        label: l10n.resultChallengesCompleted(
                          result.challengeResults.length,
                        ),
                        icon: Icons.checklist_outlined,
                      ),
                      if (isPassed && result.verifiedFaces != null) ...<Widget>[
                        const Divider(height: 20),
                        _buildMetricRow(
                          context,
                          label: l10n.resultCropsCount(
                            result.verifiedFaces!.crops.length,
                          ),
                          icon: Icons.face_outlined,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Action buttons
              if (!isPassed) ...<Widget>[
                FilledButton(
                  onPressed: () => context.pushReplacement('/verification'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(l10n.actionRetry),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(l10n.actionCancel),
                ),
              ] else ...<Widget>[
                FilledButton(
                  onPressed: () => context.go('/'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(l10n.actionDone),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentificationCard(AppLocalizations l10n, ThemeData theme) {
    if (_isIdentifying) {
      return Card(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l10n.identificationTitle, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    final MatchResult? match = _matchResult;
    if (match == null) return const SizedBox.shrink();

    if (match is MatchResultMatched) {
      return Card(
        color: theme.colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.verified,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    l10n.identifiedEmployee,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              Text(
                match.employee.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4.0),
              Text(
                '${match.employee.code} • ${l10n.matchScore(match.displayPercent.toStringAsFixed(0), match.rawScore.toStringAsFixed(3))}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer.withValues(
                    alpha: 0.8,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else if (match is MatchResultNoMatch) {
      return Card(
        color: theme.colorScheme.errorContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: theme.colorScheme.error, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.person_off_outlined,
                    color: theme.colorScheme.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    l10n.noMatchFound,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Text(
                l10n.noMatchDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else if (match is MatchResultAmbiguous) {
      return Card(
        color: theme.colorScheme.tertiaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: theme.colorScheme.tertiary, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.help_outline,
                    color: theme.colorScheme.onTertiaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    l10n.ambiguousMatch,
                    style: TextStyle(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Text(
                l10n.ambiguousDescription(
                  match.bestEmployee.name,
                  match.secondEmployee.name,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else if (match is MatchResultNoEnrolledEmployees) {
      return Card(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    l10n.noEnrolledEmployees,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Text(
                l10n.noEnrolledDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMetricRow(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
