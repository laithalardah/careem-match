import 'package:flutter/material.dart';

import 'api.dart';
import 'flow.dart';
import 'hub_screen.dart';
import 'screens.dart';
import 'swipe_screen.dart';
import 'theme.dart';

/// Backend base URL. Empty = offline mock. Example:
///   flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:8000
const _apiBase = String.fromEnvironment('API_BASE');

void main() => runApp(const CareemMatchApp());

class CareemMatchApp extends StatefulWidget {
  const CareemMatchApp({super.key});

  @override
  State<CareemMatchApp> createState() => _CareemMatchAppState();
}

class _CareemMatchAppState extends State<CareemMatchApp> {
  late final GameFlow flow = GameFlow(_apiBase.isEmpty ? MockApi() : HttpApi(_apiBase));

  @override
  void dispose() {
    flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Careem Match',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: flow,
        builder: (context, _) => AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 250),
          child: KeyedSubtree(key: ValueKey(flow.phase), child: _screen()),
        ),
      ),
    );
  }

  Widget _screen() => switch (flow.phase) {
        Phase.hub => HubScreen(flow: flow),
        Phase.home => HomeScreen(flow: flow),
        Phase.swipe1 => SwipeScreen(player: 1, dishes: flow.dishes, onSwipe: (d, l) => flow.swipe(1, d, l), onDone: flow.finishPlayer1),
        Phase.handoff => HandoffScreen(flow: flow),
        Phase.swipe2 => SwipeScreen(player: 2, dishes: flow.dishes, onSwipe: (d, l) => flow.swipe(2, d, l), onDone: flow.finishPlayer2),
        Phase.running => RunningScreen(flow: flow),
        Phase.result => ResultScreen(flow: flow),
      };
}
