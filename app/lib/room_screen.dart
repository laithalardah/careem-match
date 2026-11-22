import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';
import 'dispute_screen.dart';
import 'lobby_view.dart';
import 'models.dart';
import 'result_screen.dart';
import 'room_controller.dart';
import 'storage.dart';
import 'swipe_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Host/Guest room screen (`/room/:code`): polls room every 1 s, switches body by `stage`
/// via one AnimatedSwitcher (250 ms, fade + 12 px rise, Cubic(0.16,1,0.3,1)), and guards
/// destructive navigation back with "Leave this room?".
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.api, required this.roomCode});
  final Api api;
  final String roomCode;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final RoomController _ctrl = RoomController(api: widget.api, roomCode: widget.roomCode.toUpperCase());
  bool _allowLeave = false;

  @override
  void initState() {
    super.initState();
    if (SessionStore.getParticipantId(widget.roomCode.toUpperCase()) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/join/${widget.roomCode.toUpperCase()}');
      });
      return;
    }
    _ctrl.init();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Tok.canvas,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tok.radius)),
        title: Text('Leave this room?', style: T.display(26)),
        content: Text(
          'Your swipes stay saved, and you can reopen the link to jump back in.',
          style: T.secondary(size: 14.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Stay', style: T.body(size: 14, weight: FontWeight.w600, color: Tok.ink)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _allowLeave = true);
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: _allowLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Shell(
        header: CareemHeaderBar(
          onBack: _confirmLeave,
          backTooltip: 'Leave room',
          title: 'Careem Match',
          subtitle: 'Room ${_ctrl.roomCode}',
          trailing: widget.api.isMock ? const Tag('Mock backend', colors: Tok.yellow) : null,
        ),
        child: ListenableBuilder(
          listenable: _ctrl,
          builder: (context, _) {
            final room = _ctrl.room;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_ctrl.connectionLost) ...[
                const ConnectionBanner(),
                const SizedBox(height: Tok.s8),
              ],
              if (_ctrl.error != null) ...[
                ErrorBanner(message: _ctrl.error!, onClose: _ctrl.dismissError),
                const SizedBox(height: Tok.s8),
              ],
              Expanded(
                child: AnimatedSwitcher(
                  duration: reduce ? Duration.zero : const Duration(milliseconds: 250),
                  switchInCurve: const Cubic(0.16, 1, 0.3, 1),
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) {
                    if (reduce) return FadeTransition(opacity: anim, child: child);
                    final slide = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(anim);
                    return FadeTransition(opacity: anim, child: SlideTransition(position: slide, child: child));
                  },
                  child: KeyedSubtree(
                    key: ValueKey(room == null ? 'loading' : '${room.stage.wire}_${room.dispute?.method ?? ''}'),
                    child: _stageBody(room),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _stageBody(Room? room) {
    if (_ctrl.initialLoading) {
      return const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SkeletonBox(width: 120, height: 24),
        SizedBox(height: Tok.s16),
        SkeletonBox(height: 44),
        SizedBox(height: Tok.s16),
        SkeletonBox(height: 180, radius: Tok.radius),
        SizedBox(height: Tok.s12),
        SkeletonBox(height: 120, radius: Tok.radius),
      ]);
    }
    if (room == null) {
      return CenteredScroll(children: [
        const Tag('Unavailable', colors: Tok.red),
        const SizedBox(height: Tok.s16),
        Text('Room not found.', style: T.display(36)),
        const SizedBox(height: Tok.s12),
        Text('Ask the host for a fresh invite link, or start a new room.', style: T.secondary(size: 15)),
        const SizedBox(height: Tok.s24),
        FilledButton(onPressed: () => context.go('/match'), child: const Text('Start a new room')),
      ]);
    }
    return switch (room.stage) {
      RoomStage.lobby => LobbyView(ctrl: _ctrl),
      RoomStage.settings => SettingsView(ctrl: _ctrl),
      RoomStage.swiping => RoomSwipeView(ctrl: _ctrl),
      RoomStage.dispute => DisputeView(ctrl: _ctrl),
      RoomStage.matching => MatchingView(ctrl: _ctrl),
      RoomStage.result => ResultView(
          ctrl: _ctrl,
          onStartOver: () {
            setState(() => _allowLeave = true);
            context.go('/match');
          },
        ),
      RoomStage.ordered => OrderedView(
          ctrl: _ctrl,
          onDone: () {
            setState(() => _allowLeave = true);
            context.go('/');
          },
        ),
    };
  }
}
