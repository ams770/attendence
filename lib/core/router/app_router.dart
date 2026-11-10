import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/camera/presentation/camera_dev_screen.dart';
import '../../features/detection/presentation/detection_dev_screen.dart';
import '../../features/employees/presentation/employees_screen.dart';
import '../../features/employees/presentation/enrollment_screen.dart';
import '../../features/liveness/domain/liveness_session.dart';
import '../../features/liveness/domain/session_policy.dart';
import '../../features/liveness/presentation/challenges_dev_screen.dart';
import '../../features/liveness/presentation/passive_dev_screen.dart';
import '../../features/liveness/presentation/result_screen.dart';
import '../../features/liveness/presentation/verification_screen.dart';
import '../../features/ml/presentation/home_screen.dart';
import '../../features/ml/presentation/model_error_screen.dart';
import '../../features/ml/presentation/startup_check_screen.dart';

/// Provider for app navigation router.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const StartupCheckScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (BuildContext context, GoRouterState state) =>
            const HomeScreen(),
      ),
      GoRoute(
        path: '/error',
        builder: (BuildContext context, GoRouterState state) =>
            const ModelErrorScreen(),
      ),
      GoRoute(
        path: '/verification',
        builder: (BuildContext context, GoRouterState state) {
          final SessionPolicy policy = state.extra is SessionPolicy
              ? state.extra! as SessionPolicy
              : SessionPolicy.attendance;
          return VerificationScreen(policy: policy);
        },
      ),
      GoRoute(
        path: '/result',
        builder: (BuildContext context, GoRouterState state) {
          final LiveSessionResult result = state.extra! as LiveSessionResult;
          return ResultScreen(result: result);
        },
      ),
      GoRoute(
        path: '/employees',
        builder: (BuildContext context, GoRouterState state) =>
            const EmployeesScreen(),
      ),
      GoRoute(
        path: '/enrollment',
        builder: (BuildContext context, GoRouterState state) {
          final Map<String, dynamic>? extra =
              state.extra as Map<String, dynamic>?;
          return EnrollmentScreen(
            employeeId: extra?['employeeId'] as int?,
            initialName: extra?['name'] as String?,
            initialCode: extra?['code'] as String?,
          );
        },
      ),
      ...<RouteBase>[
        GoRoute(
          path: '/dev/camera',
          builder: (BuildContext context, GoRouterState state) =>
              const CameraDevScreen(),
        ),
        GoRoute(
          path: '/dev/detection',
          builder: (BuildContext context, GoRouterState state) =>
              const DetectionDevScreen(),
        ),
        GoRoute(
          path: '/dev/passive',
          builder: (BuildContext context, GoRouterState state) =>
              const PassiveDevScreen(),
        ),
        GoRoute(
          path: '/dev/challenges',
          builder: (BuildContext context, GoRouterState state) =>
              const ChallengesDevScreen(),
        ),
      ],
    ],
  );
});
