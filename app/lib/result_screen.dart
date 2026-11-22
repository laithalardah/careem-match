import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'room_controller.dart';
import 'theme.dart';
import 'widgets.dart';

/// Step 9: Live "Agent is working" screen streaming tool calls from `agent_trace`.
class MatchingView extends StatelessWidget {
  const MatchingView({super.key, required this.ctrl});
  final RoomController ctrl;

  @override
  Widget build(BuildContext context) {
    final steps = ctrl.result?.trace ?? const <TraceStep>[];
    return CenteredScroll(children: [
      const Tag('Matching', colors: Tok.green),
      const SizedBox(height: Tok.s16),
      Text('Finding the best\nmatch for everyone.', style: T.display(38)),
      const SizedBox(height: Tok.s24),
      Semantics(
        label: 'Agent is working',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: const LinearProgressIndicator(minHeight: 2, backgroundColor: Tok.border, color: Tok.ink),
        ),
      ),
      const SizedBox(height: Tok.s16),
      Text(
        steps.isEmpty ? 'Checking open restaurants and menus' : '${steps.length} tool ${steps.length == 1 ? 'call' : 'calls'} so far',
        style: T.secondary(size: 14),
      ),
      const SizedBox(height: Tok.s16),
      if (steps.isEmpty)
        const Column(children: [
          SkeletonBox(height: 52),
          SizedBox(height: Tok.s8),
          SkeletonBox(height: 52),
        ])
      else
        Panel(
          padding: const EdgeInsets.all(Tok.s16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) const Divider(height: Tok.s16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Tok.wash, borderRadius: BorderRadius.circular(4), border: Border.all(color: Tok.border)),
                  child: Text('${steps[i].iteration}', style: T.mono(size: 11, color: Tok.ink)),
                ),
                const SizedBox(width: Tok.s8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(steps[i].tool, style: T.mono(size: 12.5, color: Tok.ink))),
                      if (steps[i].isFailed) ...[const SizedBox(width: 6), const Tag('Failed', colors: Tok.red)],
                    ]),
                    const SizedBox(height: 2),
                    Text(steps[i].outputSummary, style: T.body(size: 13, color: steps[i].isFailed ? Tok.red.$2 : Tok.secondary)),
                  ]),
                ),
              ]),
            ],
          ]),
        ),
    ]);
  }
}

/// Step 10 & 11: Result screen (1 group or multi-group split) + Group Order bottom sheet.
class ResultView extends StatefulWidget {
  const ResultView({super.key, required this.ctrl, required this.onStartOver});
  final RoomController ctrl;
  final VoidCallback onStartOver;

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> {
  int _selectedGroupIdx = 0;
  bool _whyOpen = false;

  /// Host: send everyone to the chosen restaurant, then open this host's own restaurant in Careem.
  Future<void> _sendEveryone() async {
    final out = await widget.ctrl.submitOrder();
    if (out == null || !mounted) return;
    final mine = widget.ctrl.myGroup();
    final g = mine == null ? null : widget.ctrl.orderStatusFor(mine.groupId);
    await openCareemLink(context, g?.restaurantLink ?? mine?.restaurant.link);
  }
  @override
  Widget build(BuildContext context) {
    final res = widget.ctrl.result;
    final room = widget.ctrl.room!;
    if (res == null || res.status == ResultStatus.running) {
      return MatchingView(ctrl: widget.ctrl);
    }

    if (res.status == ResultStatus.noMatch) {
      return _ResultErrorView(
        tag: const Tag('No match', colors: Tok.yellow),
        title: 'No restaurant fits everyone.',
        body: res.reasoning.isEmpty ? 'Your picks did not overlap at any open restaurant.' : res.reasoning,
        isHost: widget.ctrl.isHost,
        busy: widget.ctrl.busy,
        primaryLabel: 'Swipe again',
        onPrimary: widget.ctrl.restart, // same people, new round
        secondaryLabel: 'Leave room',
        onSecondary: widget.onStartOver,
        trace: res.trace,
      );
    }

    if (res.status == ResultStatus.failed || res.groups.isEmpty) {
      return _ResultErrorView(
        tag: const Tag('Something went wrong', colors: Tok.red),
        title: 'The match could not finish.',
        body: res.reasoning.isEmpty ? 'Try again. Your swipes are saved.' : res.reasoning,
        isHost: widget.ctrl.isHost,
        busy: widget.ctrl.busy,
        primaryLabel: 'Try again',
        onPrimary: widget.ctrl.retryMatch,
        secondaryLabel: 'Leave room',
        onSecondary: widget.onStartOver,
        trace: res.trace,
      );
    }

    final groups = res.groups;
    final multi = groups.length > 1;
    final idx = _selectedGroupIdx.clamp(0, groups.length - 1);
    final activeGroup = groups[idx];
    final isDineOut = room.mode == RoomMode.dineout;
    final isHost = widget.ctrl.isHost;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Tok.s8,
            runSpacing: 6,
            children: [
              Tag(res.resolution.label, colors: res.resolution.type == 'split' ? Tok.blue : Tok.green),
            ],
          ),
          if (multi) ...[
            const SizedBox(height: Tok.s16),
            Text('Split into ${groups.length} groups.', style: T.display(34)),
            const SizedBox(height: Tok.s12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (var i = 0; i < groups.length; i++) ...[
                  if (i > 0) const SizedBox(width: Tok.s8),
                  _GroupSegmentTab(
                    label: groups[i].restaurant.name,
                    isMine: widget.ctrl.participantId != null && groups[i].participantIds.contains(widget.ctrl.participantId!),
                    selected: i == idx,
                    onTap: () => setState(() => _selectedGroupIdx = i),
                  ),
                ],
              ]),
            ),
          ],
          const SizedBox(height: Tok.s16),
          _GroupDetailSection(
            group: activeGroup,
            room: room,
            myId: widget.ctrl.participantId,
            isDineOut: isDineOut,
            isMine: widget.ctrl.participantId != null && activeGroup.participantIds.contains(widget.ctrl.participantId!),
            whyOpen: _whyOpen,
            onToggleWhy: () => setState(() => _whyOpen = !_whyOpen),
          ),
          const SizedBox(height: Tok.s16),
        ]),
      ),
      const SizedBox(height: Tok.s12),
      if (isHost)
        FilledButton.icon(
          onPressed: widget.ctrl.busy ? null : _sendEveryone,
          icon: const PhosphorIcon(PhosphorIconsBold.arrowSquareOut, size: 18),
          label: Text(
            isDineOut
                ? (multi ? 'Send everyone to their spot' : 'Send everyone there')
                : (multi ? 'Send everyone to their restaurant' : 'Start group order in Careem'),
          ),
        )
      else
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: Tok.s16, vertical: 14),
          color: Tok.wash,
          child: Row(children: [
            const PhosphorIcon(PhosphorIconsBold.hourglassMedium, size: 18, color: Tok.secondary),
            const SizedBox(width: Tok.s12),
            Expanded(
              child: Text(
                isDineOut ? 'Waiting for the host to send everyone there' : 'Waiting for the host to start the group order',
                style: T.body(size: 14.5, weight: FontWeight.w500),
              ),
            ),
          ]),
        ),
    ]);
  }
}

class _GroupSegmentTab extends StatelessWidget {
  const _GroupSegmentTab({
    required this.label,
    required this.isMine,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool isMine, selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label${isMine ? ', your group' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tok.radiusSm),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: Tok.s12, vertical: Tok.s8),
          decoration: BoxDecoration(
            color: selected ? Tok.ink : Tok.card,
            borderRadius: BorderRadius.circular(Tok.radiusSm),
            border: Border.all(color: selected ? Tok.ink : Tok.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: T.body(size: 13.5, weight: FontWeight.w600, color: selected ? Colors.white : Tok.ink)),
            if (isMine) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.18) : Tok.green.$1,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text('YOU', style: T.tag(selected ? Colors.white : Tok.green.$2).copyWith(fontSize: 9.5)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _GroupDetailSection extends StatelessWidget {
  const _GroupDetailSection({
    required this.group,
    required this.room,
    required this.myId,
    required this.isDineOut,
    required this.isMine,
    required this.whyOpen,
    required this.onToggleWhy,
  });

  final ResultGroup group;
  final Room room;
  final String? myId;
  final bool isDineOut, isMine, whyOpen;
  final VoidCallback onToggleWhy;

  @override
  Widget build(BuildContext context) {
    final rest = group.restaurant;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(Tok.radius),
        child: SizedBox(
          height: 164,
          child: FoodImage(url: rest.imageUrl, seed: rest.cuisine, label: rest.name, height: 164),
        ),
      ),
      const SizedBox(height: Tok.s16),
      Row(children: [
        if (isMine) ...[const Tag('Your group', colors: Tok.green), const SizedBox(width: Tok.s8)],
        if (rest.cuisine.isNotEmpty) Text(rest.cuisine, style: T.secondary(size: 14)),
        if (rest.rating != null) ...[
          const Spacer(),
          const PhosphorIcon(PhosphorIconsFill.star, size: 14),
          const SizedBox(width: 4),
          Text(rest.rating!.toStringAsFixed(1), style: T.mono(size: 13, color: Tok.ink)),
        ],
      ]),
      const SizedBox(height: Tok.s8),
      Text(rest.name, style: T.display(36)),
      if (group.reasoning.isNotEmpty) ...[
        const SizedBox(height: Tok.s8),
        Text(
          group.reasoning,
          style: T.body(size: 16, weight: FontWeight.w500, color: Tok.secondary).copyWith(height: 1.4),
        ),
      ],
      const SizedBox(height: Tok.s16),
      // Members in this group
      Wrap(
        spacing: Tok.s12,
        runSpacing: Tok.s8,
        children: [
          for (final pid in group.participantIds)
            if (room.participantById(pid) != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                ParticipantAvatar(
                  id: pid,
                  name: room.participantById(pid)!.name,
                  isHost: room.participantById(pid)!.isHost,
                  size: 30,
                ),
                const SizedBox(width: 6),
                Text(
                  pid == myId ? '${room.participantById(pid)!.name} (you)' : room.participantById(pid)!.name,
                  style: T.body(size: 13),
                ),
              ]),
        ],
      ),
      if (group.perPerson.isNotEmpty) ...[
        const SizedBox(height: Tok.s16),
        const Divider(height: 1),
        Semantics(
          button: true,
          expanded: whyOpen,
          label: 'Why this one',
          child: InkWell(
            onTap: onToggleWhy,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(children: [
                Text('Why this one', style: T.body(weight: FontWeight.w600)),
                const Spacer(),
                AnimatedRotation(
                  turns: whyOpen ? 0.5 : 0,
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
                  child: const PhosphorIcon(PhosphorIconsBold.caretDown, size: 16),
                ),
              ]),
            ),
          ),
        ),
        if (whyOpen)
          for (final pw in group.perPerson)
            Padding(
              padding: const EdgeInsets.only(bottom: Tok.s12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ParticipantAvatar(
                  id: pw.participantId,
                  name: pw.name,
                  isHost: room.participantById(pw.participantId)?.isHost == true,
                  size: 26,
                ),
                const SizedBox(width: Tok.s12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(pw.participantId == myId ? '${pw.name} (you)' : pw.name, style: T.body(size: 13.5, weight: FontWeight.w600)),
                    Text(pw.why, style: T.secondary(size: 13.5)),
                  ]),
                ),
              ]),
            ),
      ],
    ]);
  }
}

class _ResultErrorView extends StatelessWidget {
  const _ResultErrorView({
    required this.tag,
    required this.title,
    required this.body,
    required this.isHost,
    required this.busy,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.trace,
  });

  final Widget tag;
  final String title, body, primaryLabel, secondaryLabel;
  final bool isHost, busy;
  final VoidCallback onPrimary, onSecondary;
  final List<TraceStep> trace;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(children: [
          const SizedBox(height: Tok.s24),
          Align(alignment: Alignment.centerLeft, child: tag),
          const SizedBox(height: Tok.s16),
          Text(title, style: T.display(38)),
          const SizedBox(height: Tok.s12),
          Text(body, style: T.secondary(size: 16)),
          if (trace.isNotEmpty) ...[const SizedBox(height: Tok.s24), AgentTrace(steps: trace)],
        ]),
      ),
      const SizedBox(height: Tok.s12),
      if (isHost)
        FilledButton(onPressed: busy ? null : onPrimary, child: Text(primaryLabel))
      else
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: Tok.s16, vertical: 14),
          color: Tok.wash,
          child: Row(children: [
            const PhosphorIcon(PhosphorIconsBold.hourglassMedium, size: 18, color: Tok.secondary),
            const SizedBox(width: Tok.s12),
            Expanded(child: Text('Waiting for the host', style: T.body(size: 14.5, weight: FontWeight.w500))),
          ]),
        ),
      const SizedBox(height: Tok.s8),
      OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel)),
    ]);
  }
}
/// Opens a Careem link (careemfood://...). If the device cannot open it, copies it and says so.
Future<void> openCareemLink(BuildContext context, String? link) async {
  final messenger = ScaffoldMessenger.of(context);
  if (link == null || link.isEmpty) {
    messenger.showSnackBar(const SnackBar(behavior: SnackBarBehavior.floating, content: Text('No restaurant link available.')));
    return;
  }
  var opened = false;
  if (kIsWeb) {
    // A browser reports success for any custom link, even when no app handles it. So copy the link first
    // and say so: if the Careem app does not open, the person can still paste it.
    var copied = true;
    try {
      await Clipboard.setData(ClipboardData(text: link));
    } catch (_) {
      copied = false;
    }
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(copied ? 'Opening Careem. If nothing opens, the link is copied: paste it in the Careem app.' : 'Opening Careem. If nothing opens: $link'),
    ));
    try {
      final uri = Uri.tryParse(link);
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    return;
  }
  try {
    final uri = Uri.tryParse(link);
    if (uri != null) opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    var copied = true;
    try {
      await Clipboard.setData(ClipboardData(text: link));
    } catch (_) {
      copied = false;
    }
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(copied ? 'Link copied. Open it in the Careem app.' : 'Open this in the Careem app: $link'),
    ));
  }
}

/// After the host sent everyone to the restaurant: "Go to {restaurant}" with that person's own group.
/// Everyone reads this from the room, so guests see it as well as the host.
class OrderedView extends StatelessWidget {
  const OrderedView({super.key, required this.ctrl, required this.onDone});
  final RoomController ctrl;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final room = ctrl.room!;
    final group = ctrl.myGroup();
    final order = group == null ? null : ctrl.orderStatusFor(group.groupId);
    final restName = group?.restaurant.name ?? order?.restaurantName ?? 'your restaurant';
    final link = order?.restaurantLink ?? group?.restaurant.link;
    final isDineOut = room.mode == RoomMode.dineout;
    final host = room.participantById(room.hostId);
    final hostName = host?.name ?? 'The host';
    final hint = isDineOut
        ? 'Head over together.'
        : (ctrl.isHost
            ? 'Open the restaurant in Careem, start a group order and share it with your group.'
            : '$hostName starts the group order in Careem and shares it with you. Open the restaurant now and join it.');

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: CenteredScroll(children: [
          Tag(isDineOut ? 'Spot ready' : 'Group order', colors: Tok.green),
          const SizedBox(height: Tok.s16),
          Text('Go to $restName.', style: T.display(40)),
          const SizedBox(height: Tok.s12),
          Text(hint, style: T.secondary(size: 16)),
          if (group != null) ...[
            const SizedBox(height: Tok.s24),
            Panel(
              padding: const EdgeInsets.all(Tok.s16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Tok.radiusSm),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: FoodImage(url: group.restaurant.imageUrl, seed: group.restaurant.cuisine, label: group.restaurant.name, height: 60, iconSize: 24),
                    ),
                  ),
                  const SizedBox(width: Tok.s12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(group.restaurant.name, style: T.body(size: 16, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${group.participantIds.length} going together', style: T.secondary(size: 13.5)),
                    ]),
                  ),
                ]),
                const SizedBox(height: Tok.s12),
                Wrap(spacing: Tok.s12, runSpacing: Tok.s8, children: [
                  for (final pid in group.participantIds)
                    if (room.participantById(pid) != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        ParticipantAvatar(id: pid, name: room.participantById(pid)!.name, isHost: room.participantById(pid)!.isHost, size: 28),
                        const SizedBox(width: 6),
                        Text(pid == ctrl.participantId ? '${room.participantById(pid)!.name} (you)' : room.participantById(pid)!.name, style: T.body(size: 13)),
                      ]),
                ]),
              ]),
            ),
          ],
        ]),
      ),
      const SizedBox(height: Tok.s12),
      FilledButton.icon(
        onPressed: () => openCareemLink(context, link),
        icon: const PhosphorIcon(PhosphorIconsBold.arrowSquareOut, size: 18),
        label: Text('Open $restName in Careem'),
      ),
      const SizedBox(height: Tok.s8),
      OutlinedButton(onPressed: onDone, child: const Text('Back to Careem')),
    ]);
  }
}
// ── Collapsible Agent Trace ───────────────────────────────────────────────────
class AgentTrace extends StatefulWidget {
  const AgentTrace({super.key, required this.steps});
  final List<TraceStep> steps;

  @override
  State<AgentTrace> createState() => _AgentTraceState();
}

class _AgentTraceState extends State<AgentTrace> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.steps.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Divider(height: 1),
      Semantics(
        button: true,
        expanded: _open,
        label: 'Agent trace, $n tool calls',
        child: InkWell(
          onTap: () => setState(() => _open = !_open),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(children: [
              Text('Agent trace', style: T.body(weight: FontWeight.w600)),
              const SizedBox(width: Tok.s8),
              Text('$n calls', style: T.mono()),
              const Spacer(),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
                child: const PhosphorIcon(PhosphorIconsBold.caretDown, size: 16),
              ),
            ]),
          ),
        ),
      ),
      if (_open)
        for (final s in widget.steps) _TraceRow(step: s),
      const Divider(height: 1),
    ]);
  }
}

class _TraceRow extends StatelessWidget {
  const _TraceRow({required this.step});
  final TraceStep step;

  @override
  Widget build(BuildContext context) {
    final failed = step.isFailed;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tok.s16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Tok.wash, borderRadius: BorderRadius.circular(4), border: Border.all(color: Tok.border)),
            child: Text('${step.iteration}', style: T.mono(size: 11, color: Tok.ink)),
          ),
          const SizedBox(width: Tok.s8),
          Flexible(child: Text(step.tool, style: T.mono(size: 13, color: Tok.ink))),
          if (failed) ...[const SizedBox(width: Tok.s8), const Tag('Failed', colors: Tok.red)],
        ]),
        const SizedBox(height: 6),
        SelectableText(const JsonEncoder().convert(step.input), style: T.mono(size: 11)),
        const SizedBox(height: 4),
        Text(step.outputSummary, style: T.body(size: 14, color: failed ? Tok.red.$2 : Tok.secondary)),
      ]),
    );
  }
}
