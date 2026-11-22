import 'dart:convert';

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

  void _openOrderSheet(RoomResult res, RoomMode mode) {
    final isDineOut = mode == RoomMode.dineout;
    final groups = res.groups;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Tok.canvas,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Tok.radius))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tok.s24),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                isDineOut
                    ? 'Confirm destination'
                    : (groups.length > 1 ? 'Create ${groups.length} group orders' : 'Create group order'),
                style: T.display(28),
              ),
              const SizedBox(height: Tok.s8),
              Text(
                isDineOut
                    ? 'Everyone will get a link to their restaurant.'
                    : 'Review each restaurant and basket below. This prepares the group basket — it will never charge or check out.',
                style: T.secondary(size: 14),
              ),
              const SizedBox(height: Tok.s16),
              for (final g in groups) ...[
                Panel(
                  padding: const EdgeInsets.all(Tok.s16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: Text(g.restaurant.name, style: T.body(size: 16, weight: FontWeight.w700))),
                      if (!isDineOut) Text(money(g.totalPrice, g.currency), style: T.mono(size: 13, color: Tok.ink)),
                    ]),
                    if (!isDineOut && g.basket.isNotEmpty) ...[
                      const SizedBox(height: Tok.s8),
                      for (final item in g.basket) ...[
                        const Divider(height: Tok.s12),
                        Row(children: [
                          Expanded(child: Text('${item.name}: ${item.dishName}', style: T.body(size: 13.5))),
                          Text(money(item.price, g.currency), style: T.mono(size: 12)),
                        ]),
                      ],
                    ],
                  ]),
                ),
                const SizedBox(height: Tok.s12),
              ],
              if (!isDineOut && groups.length > 1) ...[
                Row(children: [
                  Text('Grand total', style: T.body(size: 15, weight: FontWeight.w700)),
                  const Spacer(),
                  Text(money(res.grandTotal, res.displayCurrency), style: T.mono(size: 15, color: Tok.ink)),
                ]),
                const SizedBox(height: Tok.s16),
              ],
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  widget.ctrl.submitOrder();
                },
                child: Text(
                  isDineOut
                      ? 'Go there'
                      : (groups.length > 1 ? 'Approve & create ${groups.length} orders' : 'Approve & create group order'),
                ),
              ),
              const SizedBox(height: Tok.s8),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
            ]),
          ),
        ),
      ),
    );
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
        primaryLabel: 'Try again',
        onPrimary: widget.ctrl.retryResult,
        secondaryLabel: 'Start over',
        onSecondary: widget.onStartOver,
        trace: res.trace,
      );
    }

    if (res.status == ResultStatus.failed || res.groups.isEmpty) {
      return _ResultErrorView(
        tag: const Tag('Something went wrong', colors: Tok.red),
        title: 'The agent could not finish.',
        body: res.reasoning.isEmpty ? 'Retry to run matching again. Your swipes are saved.' : res.reasoning,
        primaryLabel: 'Retry',
        onPrimary: widget.ctrl.retryResult,
        secondaryLabel: 'Start over',
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
              if (multi && !isDineOut)
                Text('Total ${money(res.grandTotal, res.displayCurrency)}', style: T.mono(size: 12, color: Tok.ink)),
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
          AgentTrace(steps: res.trace),
          const SizedBox(height: Tok.s16),
        ]),
      ),
      const SizedBox(height: Tok.s12),
      if (isHost)
        FilledButton(
          onPressed: widget.ctrl.busy ? null : () => _openOrderSheet(res, room.mode),
          child: Text(
            isDineOut
                ? 'Go there'
                : (multi ? 'Create ${groups.length} orders' : 'Create group order'),
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
                isDineOut ? 'Waiting for the host to confirm' : 'Waiting for the host to create the group order',
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
    // Group basket items by participant
    final byPerson = <String, List<BasketItem>>{};
    for (final item in group.basket) {
      byPerson.putIfAbsent(item.participantId, () => []).add(item);
    }

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
          style: T.display(18, style: FontStyle.italic).copyWith(letterSpacing: -0.2, height: 1.35, color: Tok.secondary),
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
      if (!isDineOut && group.basket.isNotEmpty) ...[
        const SizedBox(height: Tok.s24),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: Tok.s16, vertical: Tok.s16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: Tok.s8),
              child: Text('WHO GETS WHAT', style: T.tag(Tok.secondary)),
            ),
            for (final entry in byPerson.entries) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Tok.s12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    ParticipantAvatar(
                      id: entry.key,
                      name: entry.value.first.name,
                      isHost: room.participantById(entry.key)?.isHost == true,
                      size: 28,
                    ),
                    const SizedBox(width: Tok.s8),
                    Expanded(
                      child: Text(
                        entry.key == myId ? '${entry.value.first.name} (you)' : entry.value.first.name,
                        style: T.body(size: 14, weight: FontWeight.w700),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  for (final item in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(left: 36, top: 2),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(item.dishName, style: T.body(size: 14.5)),
                            if (item.options.isNotEmpty)
                              Text(item.options.join(' · '), style: T.secondary(size: 12)),
                          ]),
                        ),
                        const SizedBox(width: Tok.s8),
                        Text(money(item.price, group.currency), style: T.mono(size: 13, color: Tok.ink)),
                      ]),
                    ),
                ]),
              ),
            ],
            const Divider(height: 1, color: Tok.ink),
            Padding(
              padding: const EdgeInsets.only(top: Tok.s12),
              child: Row(children: [
                Text('Total', style: T.body(weight: FontWeight.w600)),
                const Spacer(),
                Text(money(group.totalPrice, group.currency), style: T.mono(size: 15, color: Tok.ink).copyWith(fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      ],
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
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.trace,
  });

  final Widget tag;
  final String title, body, primaryLabel, secondaryLabel;
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
      FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
      const SizedBox(height: Tok.s8),
      OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel)),
    ]);
  }
}

/// Step 11 (post-order): "Order ready" -> "Go to {restaurant}" for the viewer's own group.
class OrderedView extends StatelessWidget {
  const OrderedView({super.key, required this.ctrl, required this.onDone});
  final RoomController ctrl;
  final VoidCallback onDone;

  Future<void> _openLink(BuildContext context, String? link) async {
    if (link == null || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, content: Text('No restaurant link available.')),
      );
      return;
    }
    var opened = false;
    try {
      final uri = Uri.tryParse(link);
      if (uri != null) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: link));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Could not open link — copied to clipboard instead.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = ctrl.room!;
    final isDineOut = room.mode == RoomMode.dineout;
    final group = ctrl.myGroup();
    final restName = group?.restaurant.name ?? 'your restaurant';
    final orderGroup = group == null ? null : ctrl.orderStatusFor(group.groupId);
    final link = orderGroup?.restaurantLink ?? group?.restaurant.link;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: CenteredScroll(children: [
          Tag(isDineOut ? 'Spot ready' : 'Order ready', colors: Tok.green),
          const SizedBox(height: Tok.s16),
          Text('Go to $restName.', style: T.display(40)),
          const SizedBox(height: Tok.s12),
          Text(
            orderGroup?.message.isNotEmpty == true
                ? orderGroup!.message
                : (isDineOut
                    ? 'Your group agreed on $restName. Open the restaurant details to head over.'
                    : 'Your group basket at $restName is prepared. Open Careem to review and finish.'),
            style: T.secondary(size: 16),
          ),
          if (group != null) ...[
            const SizedBox(height: Tok.s24),
            Panel(
              padding: const EdgeInsets.all(Tok.s16),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Tok.radiusSm),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: FoodImage(
                      url: group.restaurant.imageUrl,
                      seed: group.restaurant.cuisine,
                      label: group.restaurant.name,
                      height: 60,
                      iconSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: Tok.s12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(group.restaurant.name, style: T.body(size: 16, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      isDineOut
                          ? '${group.participantIds.length} going together'
                          : '${group.basket.length} items · ${money(group.totalPrice, group.currency)}',
                      style: T.secondary(size: 13.5),
                    ),
                  ]),
                ),
              ]),
            ),
          ],
        ]),
      ),
      const SizedBox(height: Tok.s12),
      FilledButton.icon(
        onPressed: () => _openLink(context, link),
        icon: const PhosphorIcon(PhosphorIconsBold.arrowSquareOut, size: 18),
        label: Text('Go to $restName'),
      ),
      const SizedBox(height: Tok.s8),
      OutlinedButton(
        onPressed: onDone,
        child: const Text('Back to Careem'),
      ),
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
