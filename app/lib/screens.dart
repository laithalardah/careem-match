import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'flow.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

// ── Home ──────────────────────────────────────────────────────────────────────
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.flow});
  final GameFlow flow;

  @override
  Widget build(BuildContext context) {
    return Shell(
      footer: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (flow.error != null) ...[ErrorBanner(message: flow.error!, onClose: flow.dismissError), const SizedBox(height: Tok.s12)],
        FilledButton(onPressed: flow.busy ? null : flow.start, child: Text(flow.busy ? 'Starting' : 'Start')),
        const SizedBox(height: Tok.s12),
        Center(child: Text('Delivering to ${GameFlow.location}', style: T.secondary(size: 13))),
      ]),
      child: CenteredScroll(children: [
        Reveal(
          child: Row(children: [
            const PhosphorIcon(PhosphorIconsFill.forkKnife, size: 18),
            const SizedBox(width: Tok.s8),
            Text('Careem Match', style: T.body(size: 14, weight: FontWeight.w600)),
            if (flow.api.isMock) ...[const SizedBox(width: Tok.s12), const Tag('Mock backend', colors: Tok.yellow)],
          ]),
        ),
        const SizedBox(height: Tok.s48),
        Reveal(delay: 1, child: Text('Two people.\nOne restaurant.', style: T.display(52))),
        const SizedBox(height: Tok.s24),
        Reveal(
          delay: 2,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              'Each of you swipes the same dishes. We find one restaurant that works for both and build the order.',
              style: T.secondary(size: 17),
            ),
          ),
        ),
        const SizedBox(height: Tok.s32),
        Reveal(
          delay: 3,
          child: Panel(
            padding: const EdgeInsets.all(Tok.s16),
            child: Column(children: [
              _Step(n: '1', text: 'Player 1 swipes through the dishes.'),
              const Divider(height: Tok.s24),
              _Step(n: '2', text: 'Pass the phone. Player 2 swipes the same dishes.'),
              const Divider(height: Tok.s24),
              _Step(n: '3', text: 'An agent picks the restaurant and prices the order.'),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final String n, text;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Tok.wash, borderRadius: BorderRadius.circular(4), border: Border.all(color: Tok.border)),
          child: Text(n, style: T.mono(size: 12, color: Tok.ink)),
        ),
        const SizedBox(width: Tok.s12),
        Expanded(child: Text(text, style: T.body(size: 15))),
      ]);
}

// ── Handoff ───────────────────────────────────────────────────────────────────
class HandoffScreen extends StatelessWidget {
  const HandoffScreen({super.key, required this.flow});
  final GameFlow flow;

  @override
  Widget build(BuildContext context) {
    return Shell(
      footer: FilledButton(onPressed: flow.startPlayer2, child: const Text("I'm Player 2")),
      child: CenteredScroll(children: [
        const Reveal(child: Tag('Player 1 done', colors: Tok.blue)),
        const SizedBox(height: Tok.s24),
        Reveal(delay: 1, child: Text('Pass the phone\nto Player 2.', style: T.display(48))),
        const SizedBox(height: Tok.s16),
        Reveal(delay: 2, child: Text('Same dishes, same order. Player 1\'s choices stay hidden.', style: T.secondary(size: 17))),
      ]),
    );
  }
}

// ── Agent running ─────────────────────────────────────────────────────────────
class RunningScreen extends StatelessWidget {
  const RunningScreen({super.key, required this.flow});
  final GameFlow flow;

  @override
  Widget build(BuildContext context) {
    final steps = flow.result?.trace ?? const <TraceStep>[];
    return Shell(
      child: CenteredScroll(children: [
        const Tag('Both done', colors: Tok.green),
        const SizedBox(height: Tok.s24),
        Text('Finding one restaurant for both of you.', style: T.display(40)),
        const SizedBox(height: Tok.s24),
        Semantics(
          label: 'Working',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: const LinearProgressIndicator(minHeight: 2, backgroundColor: Tok.border, color: Tok.ink),
          ),
        ),
        const SizedBox(height: Tok.s24),
        Text(steps.isEmpty ? 'Comparing your swipes' : '${steps.length} lookups so far', style: T.secondary()),
        for (final s in steps) Padding(padding: const EdgeInsets.only(top: Tok.s8), child: Text('${s.iteration}  ${s.tool}', style: T.mono())),
      ]),
    );
  }
}

// ── Result ────────────────────────────────────────────────────────────────────
String money(double v, String cur) => '${v.toStringAsFixed(2)} $cur';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.flow});
  final GameFlow flow;

  @override
  Widget build(BuildContext context) {
    final r = flow.result!;
    return switch (r.status) {
      ResultStatus.ready => _Ready(flow: flow, r: r),
      ResultStatus.noMatch => _Message(
          flow: flow,
          tag: const Tag('No match', colors: Tok.yellow),
          title: 'No restaurant works for both of you.',
          body: r.reasoning.isEmpty ? 'Your picks do not overlap at any open restaurant.' : r.reasoning,
          primary: 'Swipe again',
          onPrimary: flow.reset,
          trace: r.trace,
        ),
      _ => _Message(
          flow: flow,
          tag: const Tag('Something went wrong', colors: Tok.red),
          title: 'The agent could not finish.',
          body: r.reasoning.isEmpty ? 'Try again. Your swipes are kept.' : '${r.reasoning} Your swipes are kept.',
          primary: 'Try again',
          onPrimary: flow.retry,
          secondary: 'Start over',
          onSecondary: flow.reset,
          trace: r.trace,
        ),
    };
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.flow, required this.tag, required this.title, required this.body, required this.primary, required this.onPrimary, this.secondary, this.onSecondary, this.trace = const []});
  final GameFlow flow;
  final Widget tag;
  final String title, body, primary;
  final VoidCallback onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;
  final List<TraceStep> trace;

  @override
  Widget build(BuildContext context) => Shell(
        footer: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilledButton(onPressed: onPrimary, child: Text(primary)),
          if (secondary != null) ...[const SizedBox(height: Tok.s8), OutlinedButton(onPressed: onSecondary, child: Text(secondary!))],
        ]),
        child: ListView(children: [
          const SizedBox(height: Tok.s48),
          Align(alignment: Alignment.centerLeft, child: tag),
          const SizedBox(height: Tok.s24),
          Text(title, style: T.display(40)),
          const SizedBox(height: Tok.s16),
          Text(body, style: T.secondary(size: 17)),
          if (trace.isNotEmpty) ...[const SizedBox(height: Tok.s32), AgentTrace(steps: trace)],
        ]),
      );
}

class _Ready extends StatelessWidget {
  const _Ready({required this.flow, required this.r});
  final GameFlow flow;
  final MatchResult r;

  @override
  Widget build(BuildContext context) {
    final rest = r.restaurant!;
    return Shell(
      footer: OutlinedButton(onPressed: flow.reset, child: const Text('Start over')),
      child: ListView(children: [
        const SizedBox(height: Tok.s8),
        Reveal(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Tok.radius),
            child: SizedBox(height: 160, child: FoodImage(url: rest.imageUrl, seed: rest.cuisine, height: 160)),
          ),
        ),
        const SizedBox(height: Tok.s24),
        Reveal(
          delay: 1,
          child: Row(children: [
            const Tag('Your match', colors: Tok.green),
            if (rest.cuisine.isNotEmpty) ...[const SizedBox(width: Tok.s8), Text(rest.cuisine, style: T.secondary(size: 14))],
            if (rest.rating != null) ...[
              const Spacer(),
              const PhosphorIcon(PhosphorIconsFill.star, size: 14),
              const SizedBox(width: 4),
              Text(rest.rating!.toStringAsFixed(1), style: T.mono(size: 13, color: Tok.ink)),
            ],
          ]),
        ),
        const SizedBox(height: Tok.s12),
        Reveal(delay: 2, child: Text(rest.name, style: T.display(40))),
        const SizedBox(height: Tok.s16),
        if (r.reasoning.isNotEmpty) Reveal(delay: 3, child: Text(r.reasoning, style: T.display(20, style: FontStyle.italic).copyWith(letterSpacing: -0.2, height: 1.35, color: Tok.secondary))),
        const SizedBox(height: Tok.s32),
        Reveal(
          delay: 4,
          child: Panel(
            padding: const EdgeInsets.symmetric(horizontal: Tok.s24, vertical: Tok.s16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.only(bottom: Tok.s8),
                child: Text('WHO GETS WHAT', style: T.tag(Tok.secondary)),
              ),
              for (final l in r.basket) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Tok.s12),
                  child: Row(children: [
                    Tag('P${l.player}', colors: l.player == 1 ? Tok.blue : Tok.green),
                    const SizedBox(width: Tok.s12),
                    Expanded(child: Text(l.dishName, style: T.body(size: 15))),
                    Text(money(l.price, r.currency), style: T.mono(size: 13, color: Tok.ink)),
                  ]),
                ),
              ],
              const Divider(height: 1, color: Tok.ink),
              Padding(
                padding: const EdgeInsets.only(top: Tok.s12),
                child: Row(children: [
                  Text('Total', style: T.body(weight: FontWeight.w600)),
                  const Spacer(),
                  Text(money(r.totalPrice, r.currency), style: T.mono(size: 15, color: Tok.ink).copyWith(fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: Tok.s24),
        Reveal(delay: 5, child: AgentTrace(steps: r.trace)),
        const SizedBox(height: Tok.s16),
      ]),
    );
  }
}

// ── Agent trace (collapsible) ─────────────────────────────────────────────────
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
    final failed = step.outputSummary.toLowerCase().startsWith('failed') || step.outputSummary.toLowerCase().startsWith('error');
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
