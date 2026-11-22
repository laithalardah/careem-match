import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';
import 'hub_screen.dart';
import 'join_screen.dart';
import 'mode_screen.dart';
import 'room_screen.dart';
import 'theme.dart';

/// Backend base URL. Empty = offline/cross-tab mock. Example:
///   flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:8000
const _apiBase = String.fromEnvironment('API_BASE');

void main() {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(CareemMatchApp());
}

class CareemMatchApp extends StatefulWidget {
  CareemMatchApp({super.key, Api? api, this.initialLocation})
      : api = api ?? (_apiBase.isEmpty ? MockApi() : HttpApi(_apiBase));

  final Api api;
  final String? initialLocation;

  @override
  State<CareemMatchApp> createState() => _CareemMatchAppState();
}

class _CareemMatchAppState extends State<CareemMatchApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: widget.initialLocation ?? '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _slidePage(
          context,
          state,
          HubScreen(onOpenMatch: () => context.push('/match')),
        ),
      ),
      GoRoute(
        path: '/match',
        pageBuilder: (context, state) => _slidePage(
          context,
          state,
          ModeScreen(api: widget.api),
        ),
      ),
      GoRoute(
        path: '/join/:code',
        pageBuilder: (context, state) => _slidePage(
          context,
          state,
          JoinScreen(api: widget.api, roomCode: state.pathParameters['code'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/room/:code',
        pageBuilder: (context, state) => _slidePage(
          context,
          state,
          RoomScreen(api: widget.api, roomCode: state.pathParameters['code'] ?? ''),
        ),
      ),
    ],
  );

  static CustomTransitionPage<void> _slidePage(BuildContext context, GoRouterState state, Widget child) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: reduce ? const Duration(milliseconds: 120) : const Duration(milliseconds: 260),
      reverseTransitionDuration: reduce ? const Duration(milliseconds: 120) : const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (reduce) return FadeTransition(opacity: animation, child: child);
        final curved = CurvedAnimation(parent: animation, curve: const Cubic(0.16, 1, 0.3, 1));
        final offset = Tween<Offset>(begin: const Offset(0.18, 0), end: Offset.zero).animate(curved);
        return FadeTransition(opacity: curved, child: SlideTransition(position: offset, child: child));
      },
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Careem Match',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: _router,
    );
  }
}
