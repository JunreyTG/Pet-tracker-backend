import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/models/auth_state.dart';
import '../../features/auth/presentation/auth_pages.dart';
import '../../features/auth/presentation/logout_button.dart';
import '../../features/auth/providers/auth_controller.dart';
import '../../features/shell/presentation/placeholder_page.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/loading/loading_state.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return createAppRouter(authState);
});

GoRouter createAppRouter(
  AuthState authState, {
  String initialLocation = '/dashboard',
}) {
  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) => _authRedirect(authState, state.uri.path),
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/dashboard'),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const Scaffold(
          body: LoadingState(message: 'Restoring your session...'),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginRoutePage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterRoutePage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const PlaceholderRoutePage(
              title: 'Dashboard',
              description: 'Owner overview will be migrated here.',
              icon: Icons.dashboard_outlined,
            ),
          ),
          GoRoute(
            path: '/pets',
            builder: (context, state) => const PlaceholderRoutePage(
              title: 'My Pets',
              description: 'Pet management will move to this feature route.',
              icon: Icons.pets_outlined,
            ),
          ),
          GoRoute(
            path: '/devices',
            builder: (context, state) => const PlaceholderRoutePage(
              title: 'Trackers',
              description: 'Device management will move to this feature route.',
              icon: Icons.gps_fixed_outlined,
            ),
          ),
          GoRoute(
            path: '/tracking',
            builder: (context, state) => const PlaceholderRoutePage(
              title: 'Live Map',
              description: 'Live tracking will use backend device state only.',
              icon: Icons.map_outlined,
            ),
          ),
          GoRoute(
            path: '/geofences',
            builder: (context, state) => const PlaceholderRoutePage(
              title: 'Safe Zones',
              description: 'Geofence screens will move to this feature route.',
              icon: Icons.shield_outlined,
            ),
          ),
          GoRoute(
            path: '/alerts',
            builder: (context, state) => const PlaceholderRoutePage(
              title: 'Alerts',
              description: 'Backend-generated alerts will move here.',
              icon: Icons.notifications_none_outlined,
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const PlaceholderRoutePage(
              title: 'Profile',
              description: 'Backend user profile state will move here.',
              icon: Icons.person_outline,
              actions: [LogoutButton()],
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const PlaceholderRoutePage(
              title: 'Settings',
              description: 'Application settings will move here.',
              icon: Icons.settings_outlined,
            ),
          ),
        ],
      ),
    ],
  );
}

String? _authRedirect(AuthState authState, String location) {
  final onAuthRoute = location == '/login' || location == '/register';
  final onSplash = location == '/splash';

  if (authState.isLoading) {
    return onSplash ? null : '/splash';
  }

  if (authState.isAuthenticated) {
    if (onAuthRoute || onSplash || location == '/') return '/dashboard';
    return null;
  }

  if (onAuthRoute) return null;
  return '/login';
}
