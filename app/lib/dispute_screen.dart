import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'models.dart';
import 'room_controller.dart';
import 'theme.dart';
import 'widgets.dart';

/// Step 8: Dispute resolver — Intro vote -> Wheel OR Split into groups.
class DisputeView extends StatelessWidget {
  const DisputeView({super.key, required this.ctrl});
  final RoomController ctrl;

  @override
  Widget build(BuildContext context) {
    final dispute = ctrl.room?.dispute;
    if (dispute == null) {
      return const CenteredScroll(children: [SkeletonBox(height: 160)]);
    }
    return switch (dispute.method) {
      'wheel' => _WheelView(ctrl: ctrl, dispute: dispute),
      'split' => _SplitView(ctrl: ctrl, dispute: dispute),
      _ => _DisputeIntroView(ctrl: ctrl, dispute: dispute),
    };
  }
}

// ── Intro + Vote ──────────────────────────────────────────────────────────────
class _DisputeIntroView extends StatelessWidget {
  const _DisputeIntroView({required this.ctrl, required this.dispute});
  final RoomController ctrl;
  final DisputeState dispute;

  @override
  Widget build(BuildContext context) {
    final room = ctrl.room!;
    final myVote = ctrl.participantId == null ? null : dispute.methodVotes[ctrl.participantId!];
    final wheelVoters = [
      for (final p in room.participants)
        if (dispute.methodVotes[p.id] == 'wheel') p,
    ];
    final splitVoters = [
      for (final p in room.participants)
        if (dispute.methodVotes[p.id] == 'split') p,
    ];

    return ListView(children: [
      const Align(alignment: Alignment.centerLeft, child: Tag('Split decision', colors: Tok.yellow)),
      const SizedBox(height: Tok.s16),
      Text('No clear winner.', style: T.display(38)),
      const SizedBox(height: Tok.s8),
      Text(
        'Your group is split between these spots. Vote on how to settle it.',
        style: T.secondary(size: 15),
      ),
      const SizedBox(height: Tok.s24),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < dispute.contenders.length; i++) ...[
            if (i > 0) const SizedBox(width: Tok.s12),
            Expanded(child: _ContenderCard(contender: dispute.contenders[i], room: room, myId: ctrl.participantId)),
          ],
        ],
      ),
      const SizedBox(height: Tok.s24),
      Text('HOW SHOULD WE RESOLVE IT?', style: T.tag(Tok.secondary)),
      const SizedBox(height: Tok.s12),
      _VoteCard(
        title: 'Spin the wheel',
        subtitle: 'One restaurant, picked at random with everyone watching live.',
        icon: PhosphorIconsBold.arrowsClockwise,
        selected: myVote == 'wheel',
        voters: wheelVoters,
        myId: ctrl.participantId,
        disabled: ctrl.busy,
        onTap: () => ctrl.voteDispute('wheel'),
      ),
      const SizedBox(height: Tok.s12),
      _VoteCard(
        title: 'Split into groups',
        subtitle: 'Everyone gets what they want with separate orders.',
        icon: PhosphorIconsBold.gitFork,
        selected: myVote == 'split',
        voters: splitVoters,
        myId: ctrl.participantId,
        disabled: ctrl.busy,
        onTap: () => ctrl.voteDispute('split'),
      ),
      const SizedBox(height: Tok.s16),
      Text(
        'Majority wins. A tie is broken by the host\'s vote.',
        style: T.secondary(size: 12.5),
      ),
      const SizedBox(height: Tok.s16),
    ]);
  }
}

class _ContenderCard extends StatelessWidget {
  const _ContenderCard({required this.contender, required this.room, required this.myId});
  final DisputeContender contender;
  final Room room;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    final supporters = [
      for (final id in contender.supporterIds)
        if (room.participantById(id) != null) room.participantById(id)!,
    ];
    return Panel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tok.radius - 1),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 92,
            child: FoodImage(url: contender.imageUrl, seed: contender.cuisine, label: contender.name, height: 92, iconSize: 28),
          ),
          Padding(
            padding: const EdgeInsets.all(Tok.s12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(contender.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.body(size: 14, weight: FontWeight.w700).copyWith(height: 1.2)),
              const SizedBox(height: Tok.s8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in supporters)
                    ParticipantAvatar(id: p.id, name: p.name, isHost: p.isHost, size: 28),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${supporters.length} ${supporters.length == 1 ? 'person' : 'people'}',
                style: T.mono(size: 11),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _VoteCard extends StatelessWidget {
  const _VoteCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.voters,
    required this.myId,
    required this.disabled,
    required this.onTap,
  });

  final String title, subtitle;
  final IconData icon;
  final bool selected, disabled;
  final List<Participant> voters;
  final String? myId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $subtitle. ${voters.length} votes.',
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(Tok.radius),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(Tok.s16),
          decoration: BoxDecoration(
            color: selected ? Tok.wash : Tok.card,
            borderRadius: BorderRadius.circular(Tok.radius),
            border: Border.all(color: selected ? Tok.ink : Tok.border, width: selected ? 1.5 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              PhosphorIcon(icon, size: 20, color: Tok.ink),
              const SizedBox(width: Tok.s8),
              Expanded(child: Text(title, style: T.body(size: 16, weight: FontWeight.w700))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: selected ? Tok.ink : Tok.wash,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${voters.length} ${voters.length == 1 ? 'vote' : 'votes'}',
                  style: T.mono(size: 11.5, color: selected ? Colors.white : Tok.ink),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text(subtitle, style: T.secondary(size: 13.5)),
            if (voters.isNotEmpty) ...[
              const SizedBox(height: Tok.s12),
              Wrap(
                spacing: Tok.s8,
                runSpacing: 6,
                children: [
                  for (final v in voters)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      ParticipantAvatar(id: v.id, name: v.name, isHost: v.isHost, size: 24),
                      const SizedBox(width: 4),
                      Text(v.id == myId ? '${v.name} (you)' : v.name, style: T.body(size: 12, color: Tok.secondary)),
                    ]),
                ],
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Synchronized Wheel ────────────────────────────────────────────────────────
class _WheelView extends StatefulWidget {
  const _WheelView({required this.ctrl, required this.dispute});
  final RoomController ctrl;
  final DisputeState dispute;

  @override
  State<_WheelView> createState() => _WheelViewState();
}

class _WheelViewState extends State<_WheelView> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this);
  String? _activeSpinId;
  bool _revealed = false;
  int _lastSliceIdx = -1;
  double _targetDeg = 0;

  @override
  void initState() {
    super.initState();
    _anim.addListener(_onTick);
    _anim.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_revealed) {
        _revealWinner();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSpin());
  }

  @override
  void didUpdateWidget(covariant _WheelView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  double get _currentDeg {
    final t = _easeOutQuart(_anim.value);
    return _targetDeg * t;
  }

  static double _easeOutQuart(double t) {
    final inv = 1.0 - t.clamp(0.0, 1.0);
    return 1.0 - inv * inv * inv * inv;
  }

  void _syncSpin() {
    final wheel = widget.dispute.wheel;
    if (wheel == null || !wheel.hasSpun) return;
    if (_activeSpinId == wheel.spinId) return;
    _activeSpinId = wheel.spinId;
    _targetDeg = (wheel.finalAngleDeg ?? 0) + 5 * 360.0;

    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _anim.value = 1.0;
      _revealWinner();
      return;
    }

    final durationMs = math.max(300, wheel.durationMs);
    final nowServerApprox = DateTime.now().millisecondsSinceEpoch - (widget.ctrl.room?.serverOffsetMs ?? 0);
    final startedAt = wheel.spinStartedAtMs;
    var elapsedMs = 0;
    if (startedAt != null) {
      final rawElapsed = nowServerApprox - startedAt;
      // Only honor clock offset if reasonable; otherwise start fresh on receipt.
      if (rawElapsed >= 0 && rawElapsed < durationMs + 60000) {
        elapsedMs = rawElapsed;
      }
    }

    if (elapsedMs >= durationMs) {
      _anim.value = 1.0;
      _revealWinner();
    } else {
      _revealed = false;
      _anim.duration = Duration(milliseconds: durationMs);
      _anim.forward(from: (elapsedMs / durationMs).clamp(0.0, 1.0));
    }
  }

  void _onTick() {
    final wheel = widget.dispute.wheel;
    if (wheel == null || wheel.segments.isEmpty) return;
    final idx = _sliceIndexAt(_currentDeg, wheel.segments);
    if (_lastSliceIdx != -1 && idx != _lastSliceIdx) {
      HapticFeedback.selectionClick();
    }
    _lastSliceIdx = idx;
    setState(() {});
  }

  int _sliceIndexAt(double deg, List<WheelSegment> segments) {
    final totalW = segments.fold<double>(0, (s, seg) => s + math.max(0.1, seg.weight));
    final norm = (360.0 - (deg % 360.0)) % 360.0;
    var acc = 0.0;
    for (var i = 0; i < segments.length; i++) {
      final sweep = (math.max(0.1, segments[i].weight) / totalW) * 360.0;
      if (norm >= acc && norm < acc + sweep) return i;
      acc += sweep;
    }
    return 0;
  }

  void _skipAnimation() {
    _anim.stop();
    _anim.value = 1.0;
    _revealWinner();
  }

  void _revealWinner() {
    if (!mounted) return;
    setState(() => _revealed = true);
    final winnerName = _winnerName;
    if (winnerName != null) {
      SemanticsService.sendAnnouncement(View.of(context), '$winnerName wins', TextDirection.ltr);
    }
  }

  String? get _winnerName {
    final wheel = widget.dispute.wheel;
    if (wheel == null || wheel.winnerRestaurantId == null) return null;
    for (final s in wheel.segments) {
      if (s.restaurantId == wheel.winnerRestaurantId) return s.name;
    }
    return wheel.segments.isNotEmpty ? wheel.segments.first.name : null;
  }

  @override
  Widget build(BuildContext context) {
    final wheel = widget.dispute.wheel;
    if (wheel == null) return const SkeletonBox(height: 280);
    final isHost = widget.ctrl.isHost;
    final spinning = wheel.hasSpun && !_revealed;
    final winner = _winnerName;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: CenteredScroll(children: [
          const Tag('Wheel spin', colors: Tok.blue),
          const SizedBox(height: Tok.s12),
          Text('Let the wheel decide.', style: T.display(36)),
          const SizedBox(height: Tok.s24),
          Center(
            child: Semantics(
              label: 'Decision wheel with ${wheel.segments.map((s) => s.name).join(' and ')}',
              child: SizedBox(
                width: 276,
                height: 292,
                child: Stack(alignment: Alignment.bottomCenter, children: [
                  Positioned(
                    top: 0,
                    child: CustomPaint(size: const Size(24, 18), painter: _PointerPainter()),
                  ),
                  SizedBox(
                    width: 268,
                    height: 268,
                    child: Transform.rotate(
                      angle: _currentDeg * math.pi / 180.0,
                      child: CustomPaint(painter: _WheelPainter(wheel.segments)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: Tok.s24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _revealed && winner != null
                ? Semantics(
                    liveRegion: true,
                    child: Panel(
                      key: const ValueKey('winner'),
                      padding: const EdgeInsets.all(Tok.s16),
                      color: Tok.green.$1,
                      child: Row(children: [
                        PhosphorIcon(PhosphorIconsFill.trophy, size: 22, color: Tok.green.$2),
                        const SizedBox(width: Tok.s12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('WINNER', style: T.tag(Tok.green.$2)),
                            const SizedBox(height: 2),
                            Text('$winner wins', style: T.display(26)),
                          ]),
                        ),
                      ]),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ]),
      ),
      const SizedBox(height: Tok.s12),
      if (!wheel.hasSpun) ...[
        if (isHost)
          FilledButton.icon(
            onPressed: widget.ctrl.busy ? null : widget.ctrl.spinWheel,
            icon: const PhosphorIcon(PhosphorIconsBold.arrowsClockwise, size: 18),
            label: Text(widget.ctrl.busy ? 'Spinning...' : 'Spin'),
          )
        else
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: Tok.s16, vertical: 14),
            color: Tok.wash,
            child: Row(children: [
              const PhosphorIcon(PhosphorIconsBold.hourglassMedium, size: 18, color: Tok.secondary),
              const SizedBox(width: Tok.s12),
              Expanded(child: Text('Waiting for the host to spin', style: T.body(size: 15, weight: FontWeight.w500))),
            ]),
          ),
      ] else if (spinning)
        OutlinedButton(
          onPressed: _skipAnimation,
          child: const Text('Skip animation'),
        )
      else
        Center(child: Text('Preparing your match...', style: T.secondary(size: 14))),
    ]);
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(p, Paint()..color = Tok.ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.segments);
  final List<WheelSegment> segments;

  static const _palette = [Tok.green, Tok.blue, Tok.yellow, Tok.red];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final totalW = segments.fold<double>(0, (s, seg) => s + math.max(0.1, seg.weight));
    final borderPaint = Paint()
      ..color = Tok.ink.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    var start = -math.pi / 2;
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final sweep = (math.max(0.1, seg.weight) / totalW) * math.pi * 2;
      final colors = _palette[i % _palette.length];
      canvas.drawArc(rect, start, sweep, true, Paint()..color = colors.$1);
      canvas.drawArc(rect, start, sweep, true, borderPaint);

      // Draw restaurant label cleanly along slice bisector.
      final mid = start + sweep / 2;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(mid);
      final tp = TextPainter(
        text: TextSpan(
          text: seg.name,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.$2),
        ),
        maxLines: 2,
        textAlign: TextAlign.center,
        ellipsis: '...',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: radius * 0.62);
      tp.paint(canvas, Offset(radius * 0.26, -tp.height / 2));
      canvas.restore();
      start += sweep;
    }

    // Outer ring + center hub
    canvas.drawCircle(center, radius, Paint()..color = Tok.ink..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(center, 14, Paint()..color = Tok.ink);
    canvas.drawCircle(center, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => oldDelegate.segments != segments;
}

// ── Split Into Groups ─────────────────────────────────────────────────────────
class _SplitView extends StatelessWidget {
  const _SplitView({required this.ctrl, required this.dispute});
  final RoomController ctrl;
  final DisputeState dispute;

  @override
  Widget build(BuildContext context) {
    final split = dispute.split;
    final room = ctrl.room!;
    if (split == null) return const SkeletonBox(height: 220);
    final groups = [for (final g in split.groups) if (g.participantIds.isNotEmpty) g];
    final myId = ctrl.participantId;
    final isHost = ctrl.isHost;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(children: [
          const Align(alignment: Alignment.centerLeft, child: Tag('Split into groups', colors: Tok.green)),
          const SizedBox(height: Tok.s16),
          Text('Pick your group.', style: T.display(38)),
          const SizedBox(height: Tok.s8),
          Text(
            'Switch freely before the host confirms. Empty groups disappear automatically.',
            style: T.secondary(size: 15),
          ),
          const SizedBox(height: Tok.s24),
          for (final g in groups) ...[
            _SplitGroupCard(
              group: g,
              room: room,
              myId: myId,
              busy: ctrl.busy || split.confirmed,
              onJoin: () => ctrl.moveSplitGroup(g.restaurantId),
            ),
            const SizedBox(height: Tok.s12),
          ],
        ]),
      ),
      const SizedBox(height: Tok.s12),
      if (isHost)
        FilledButton(
          onPressed: ctrl.busy || split.confirmed ? null : ctrl.confirmSplit,
          child: Text(ctrl.busy ? 'Confirming...' : 'Confirm groups'),
        )
      else
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: Tok.s16, vertical: 14),
          color: Tok.wash,
          child: Row(children: [
            const PhosphorIcon(PhosphorIconsBold.hourglassMedium, size: 18, color: Tok.secondary),
            const SizedBox(width: Tok.s12),
            Expanded(child: Text('Waiting for the host to confirm', style: T.body(size: 15, weight: FontWeight.w500))),
          ]),
        ),
    ]);
  }
}

class _SplitGroupCard extends StatelessWidget {
  const _SplitGroupCard({
    required this.group,
    required this.room,
    required this.myId,
    required this.busy,
    required this.onJoin,
  });

  final SplitGroup group;
  final Room room;
  final String? myId;
  final bool busy;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final inThisGroup = myId != null && group.participantIds.contains(myId);
    final members = [
      for (final id in group.participantIds)
        if (room.participantById(id) != null) room.participantById(id)!,
    ];

    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(Tok.s16),
      decoration: BoxDecoration(
        color: Tok.card,
        borderRadius: BorderRadius.circular(Tok.radius),
        border: Border.all(color: inThisGroup ? Tok.ink : Tok.border, width: inThisGroup ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Tok.radiusSm),
            child: SizedBox(
              width: 52,
              height: 52,
              child: FoodImage(url: group.imageUrl, seed: group.name, label: group.name, height: 52, iconSize: 22),
            ),
          ),
          const SizedBox(width: Tok.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(group.name, style: T.body(size: 16, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${members.length} ${members.length == 1 ? 'member' : 'members'}', style: T.secondary(size: 13)),
            ]),
          ),
          if (inThisGroup) const Tag('Your group', colors: Tok.green),
        ]),
        const SizedBox(height: Tok.s12),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
          child: Align(
            key: ValueKey(group.participantIds.join(',')),
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: Tok.s12,
              runSpacing: Tok.s8,
              children: [
                for (final m in members)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    ParticipantAvatar(id: m.id, name: m.name, isHost: m.isHost, size: 30),
                    const SizedBox(width: 6),
                    Text(m.id == myId ? '${m.name} (you)' : m.name, style: T.body(size: 13)),
                  ]),
              ],
            ),
          ),
        ),
        if (!inThisGroup) ...[
          const SizedBox(height: Tok.s12),
          OutlinedButton(
            onPressed: busy ? null : onJoin,
            child: const Text('Join this group'),
          ),
        ],
      ]),
    );
  }
}
