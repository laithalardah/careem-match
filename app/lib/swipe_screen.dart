import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'models.dart';
import 'room_controller.dart';
import 'theme.dart';
import 'widgets.dart';

/// Steps 5, 6, 7: Level 1 (categories) -> interstitial -> Level 2 (restaurants) + Waiting screen.
class RoomSwipeView extends StatefulWidget {
  const RoomSwipeView({super.key, required this.ctrl});
  final RoomController ctrl;

  @override
  State<RoomSwipeView> createState() => _RoomSwipeViewState();
}

class _RoomSwipeViewState extends State<RoomSwipeView> {
  SwipeLevel? _seenLevel;
  bool _showInterstitial = false;
  Timer? _interstitialTimer;

  @override
  void initState() {
    super.initState();
    _seenLevel = widget.ctrl.room?.level;
  }

  @override
  void didUpdateWidget(covariant RoomSwipeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cur = widget.ctrl.room?.level;
    if (_seenLevel == SwipeLevel.category && cur == SwipeLevel.restaurant) {
      _seenLevel = cur;
      setState(() => _showInterstitial = true);
      _interstitialTimer?.cancel();
      _interstitialTimer = Timer(const Duration(milliseconds: 1100), () {
        if (mounted) setState(() => _showInterstitial = false);
      });
    } else if (cur != null) {
      _seenLevel = cur;
    }
  }

  @override
  void dispose() {
    _interstitialTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.ctrl.room!;
    final level = room.level ?? SwipeLevel.category;
    final me = widget.ctrl.me;
    final done = me?.progress.done == true && me?.progress.level == level;

    if (_showInterstitial) {
      return _LevelInterstitial(
        onContinue: () {
          _interstitialTimer?.cancel();
          setState(() => _showInterstitial = false);
        },
      );
    }

    if (done) {
      return WaitingOthersView(ctrl: widget.ctrl, level: level);
    }

    final cardsResp = widget.ctrl.cards;
    if (cardsResp == null || cardsResp.level != level) {
      return const _SwipeSkeleton();
    }

    if (cardsResp.cards.isEmpty) {
      return CenteredScroll(children: [
        const Tag('No cards', colors: Tok.yellow),
        const SizedBox(height: Tok.s16),
        Text('No options available right now.', style: T.display(32)),
        const SizedBox(height: Tok.s12),
        Text('Waiting for the room to update.', style: T.secondary(size: 15)),
      ]);
    }

    final initialIndex = (me?.progress.level == level ? (me?.progress.swiped ?? 0) : 0).clamp(0, cardsResp.cards.length - 1);

    return _SwipeDeck(
      key: ValueKey('deck_${level.wire}_${cardsResp.cards.length}'),
      level: level,
      cards: cardsResp.cards,
      initialIndex: initialIndex,
      isHost: widget.ctrl.isHost,
      busy: widget.ctrl.busy,
      onSwipe: (card, liked) => widget.ctrl.swipeCard(level, card.id, liked),
      onRequestDispute: widget.ctrl.requestEarlyDispute,
    );
  }
}

class _LevelInterstitial extends StatelessWidget {
  const _LevelInterstitial({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return CenteredScroll(children: [
      const Reveal(child: Tag('Level 2 of 2', colors: Tok.green)),
      const SizedBox(height: Tok.s24),
      Reveal(delay: 1, child: Text('Now pick\nrestaurants.', style: T.display(46))),
      const SizedBox(height: Tok.s12),
      Reveal(
        delay: 2,
        child: Text(
          'Narrowed down from your group\'s favorite categories.',
          style: T.secondary(size: 16),
        ),
      ),
      const SizedBox(height: Tok.s32),
      FilledButton(onPressed: onContinue, child: const Text('Start swiping')),
    ]);
  }
}

class _SwipeSkeleton extends StatelessWidget {
  const _SwipeSkeleton();

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
        Row(children: [SkeletonBox(width: 96, height: 24), Spacer(), SkeletonBox(width: 48, height: 16)]),
        SizedBox(height: Tok.s16),
        Expanded(child: SkeletonBox(height: 360, radius: Tok.radius)),
        SizedBox(height: Tok.s16),
        Row(children: [Expanded(child: SkeletonBox(height: 52)), SizedBox(width: Tok.s12), Expanded(child: SkeletonBox(height: 52))]),
      ]);
}

/// Waiting screen shown after finishing a swipe level while other participants finish.
class WaitingOthersView extends StatelessWidget {
  const WaitingOthersView({super.key, required this.ctrl, required this.level});
  final RoomController ctrl;
  final SwipeLevel level;

  @override
  Widget build(BuildContext context) {
    final room = ctrl.room!;
    return CenteredScroll(children: [
      Tag(level == SwipeLevel.category ? 'Categories done' : 'Restaurants done', colors: Tok.green),
      const SizedBox(height: Tok.s16),
      Text('Waiting for\nthe others.', style: T.display(40)),
      const SizedBox(height: Tok.s8),
      Text(
        level == SwipeLevel.category
            ? 'Next up: restaurant cards once everyone finishes.'
            : 'Moving to matching as soon as the group finishes.',
        style: T.secondary(size: 15),
      ),
      const SizedBox(height: Tok.s24),
      Panel(
        padding: const EdgeInsets.all(Tok.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < room.participants.length; i++) ...[
            if (i > 0) const Divider(height: Tok.s16),
            _ProgressRow(
              participant: room.participants[i],
              isMe: room.participants[i].id == ctrl.participantId,
            ),
          ],
        ]),
      ),
    ]);
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.participant, required this.isMe});
  final Participant participant;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final p = participant.progress;
    final total = p.total <= 0 ? 1 : p.total;
    final ratio = (p.swiped / total).clamp(0.0, 1.0);
    return Row(children: [
      ParticipantAvatar(id: participant.id, name: participant.name, isHost: participant.isHost, size: 36),
      const SizedBox(width: Tok.s12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: Text(
                isMe ? '${participant.name} (you)' : participant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.body(size: 14, weight: FontWeight.w600),
              ),
            ),
            if (participant.isBot) ...[const SizedBox(width: 6), const Tag('Demo', colors: Tok.yellow)],
            const Spacer(),
            Text(p.done ? 'Done' : '${p.swiped}/${p.total}', style: T.mono(size: 12, color: p.done ? Tok.green.$2 : Tok.secondary)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: p.done ? 1.0 : ratio,
              minHeight: 4,
              backgroundColor: Tok.border,
              color: p.done ? Tok.green.$2 : Tok.ink,
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _SwipeDeck extends StatefulWidget {
  const _SwipeDeck({
    super.key,
    required this.level,
    required this.cards,
    required this.initialIndex,
    required this.isHost,
    required this.busy,
    required this.onSwipe,
    required this.onRequestDispute,
  });

  final SwipeLevel level;
  final List<SwipeCard> cards;
  final int initialIndex;
  final bool isHost;
  final bool busy;
  final Future<SwipeResponse?> Function(SwipeCard card, bool liked) onSwipe;
  final VoidCallback onRequestDispute;

  @override
  State<_SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<_SwipeDeck> with SingleTickerProviderStateMixin {
  static const _threshold = 110.0;
  late int _index = widget.initialIndex;
  late int _swipedCount = widget.initialIndex;
  Offset _drag = Offset.zero;
  bool _animating = false;
  bool _finishedLocally = false;
  late final AnimationController _ctrl = AnimationController(vsync: this);
  Animation<Offset>? _anim;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (_anim != null) setState(() => _drag = _anim!.value);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _animateTo(Offset to, {bool? like}) async {
    final reduce = MediaQuery.disableAnimationsOf(context);
    _anim = Tween(begin: _drag, end: to).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.duration = reduce ? Duration.zero : Duration(milliseconds: like == null ? 180 : 240);
    await _ctrl.forward(from: 0);
    if (!mounted) return;
    if (like != null) _commit(like);
    _animating = false;
  }

  void _commit(bool liked) {
    HapticFeedback.selectionClick();
    final card = widget.cards[_index];
    widget.onSwipe(card, liked);
    final last = _index + 1 >= widget.cards.length;
    setState(() {
      _drag = Offset.zero;
      _swipedCount++;
      if (!last) {
        _index++;
      } else {
        _finishedLocally = true;
      }
    });
  }

  void _decide(bool liked, double width) {
    if (_animating || _finishedLocally) return;
    _animating = true;
    SemanticsService.sendAnnouncement(View.of(context), liked ? 'Liked' : 'Skipped', TextDirection.ltr);
    _animateTo(Offset((liked ? 1 : -1) * width * 1.4, _drag.dy), like: liked);
  }

  @override
  Widget build(BuildContext context) {
    if (_finishedLocally) {
      return CenteredScroll(children: [
        const Tag('Saved', colors: Tok.green),
        const SizedBox(height: Tok.s16),
        Text('Wrapping up your picks...', style: T.display(32)),
        const SizedBox(height: Tok.s16),
        const SkeletonBox(height: 80),
      ]);
    }

    final total = widget.cards.length;
    final card = widget.cards[_index];
    final next = _index + 1 < total ? widget.cards[_index + 1] : null;
    final isLevel2 = widget.level == SwipeLevel.restaurant;
    final showEarlyDispute = widget.isHost && isLevel2 && _swipedCount >= 5;

    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) {
        if (e is! KeyDownEvent) return KeyEventResult.ignored;
        final w = MediaQuery.sizeOf(context).width;
        if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
          _decide(true, w);
          return KeyEventResult.handled;
        }
        if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _decide(false, w);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Tag(isLevel2 ? 'Restaurants' : 'Categories', colors: isLevel2 ? Tok.green : Tok.blue),
          const Spacer(),
          Text('${_index + 1} of $total', style: T.mono(size: 12)),
        ]),
        const SizedBox(height: Tok.s12),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: _index / total,
            minHeight: 2,
            backgroundColor: Tok.border,
            color: Tok.ink,
          ),
        ),
        const SizedBox(height: Tok.s16),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            final progress = (_drag.dx.abs() / _threshold).clamp(0.0, 1.0);
            return Stack(alignment: Alignment.topCenter, children: [
              if (next != null)
                Transform.scale(
                  scale: 0.95 + 0.05 * progress,
                  alignment: Alignment.bottomCenter,
                  child: Opacity(opacity: 0.6 + 0.4 * progress, child: _CardFace(card: next, key: ValueKey('b${next.id}'))),
                ),
              Semantics(
                label: '${card.title}${card.cuisine.isNotEmpty ? ', ${card.cuisine}' : ''}. Card ${_index + 1} of $total.',
                customSemanticsActions: {
                  const CustomSemanticsAction(label: 'Like'): () => _decide(true, w),
                  const CustomSemanticsAction(label: 'Skip'): () => _decide(false, w),
                },
                child: GestureDetector(
                  onPanUpdate: (d) {
                    if (_animating) return;
                    setState(() => _drag += Offset(d.delta.dx, d.delta.dy * 0.3));
                  },
                  onPanEnd: (d) {
                    if (_animating) return;
                    final fling = d.velocity.pixelsPerSecond.dx;
                    if (_drag.dx > _threshold || fling > 900) {
                      _decide(true, w);
                    } else if (_drag.dx < -_threshold || fling < -900) {
                      _decide(false, w);
                    } else {
                      _animating = true;
                      _animateTo(Offset.zero);
                    }
                  },
                  child: Transform.translate(
                    offset: _drag,
                    child: Transform.rotate(
                      angle: _drag.dx / (w <= 0 ? 320 : w) * 0.12,
                      child: Stack(children: [
                        _CardFace(card: card, key: ValueKey('t${card.id}')),
                        Positioned(top: 20, left: 20, child: _Stamp('Like', Tok.green, _drag.dx > 0 ? progress : 0)),
                        Positioned(top: 20, right: 20, child: _Stamp('Skip', Tok.red, _drag.dx < 0 ? progress : 0)),
                      ]),
                    ),
                  ),
                ),
              ),
            ]);
          }),
        ),
        const SizedBox(height: Tok.s16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _decide(false, MediaQuery.sizeOf(context).width),
              icon: const PhosphorIcon(PhosphorIconsBold.x, size: 18),
              label: const Text('Skip'),
            ),
          ),
          const SizedBox(width: Tok.s12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _decide(true, MediaQuery.sizeOf(context).width),
              icon: const PhosphorIcon(PhosphorIconsFill.heart, size: 18),
              label: const Text('Like'),
            ),
          ),
        ]),
        if (showEarlyDispute) ...[
          const SizedBox(height: Tok.s8),
          Center(
            child: TextButton(
              onPressed: widget.busy ? null : widget.onRequestDispute,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                foregroundColor: Tok.secondary,
              ),
              child: Text("Can't decide? Help us decide", style: T.body(size: 13.5, weight: FontWeight.w500, color: Tok.secondary)),
            ),
          ),
        ],
      ]),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp(this.text, this.colors, this.opacity);
  final String text;
  final (Color, Color) colors;
  final double opacity;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: colors.$1, borderRadius: BorderRadius.circular(Tok.radiusSm)),
          child: Text(text.toUpperCase(), style: T.tag(colors.$2).copyWith(fontSize: 13)),
        ),
      );
}

class _CardFace extends StatelessWidget {
  const _CardFace({super.key, required this.card});
  final SwipeCard card;

  @override
  Widget build(BuildContext context) {
    final isRest = card.level == SwipeLevel.restaurant;
    final tagLabel = card.cuisine.isNotEmpty ? card.cuisine : (isRest ? 'Restaurant' : 'Category');
    return Container(
      decoration: BoxDecoration(
        color: Tok.card,
        borderRadius: BorderRadius.circular(Tok.radius),
        border: Border.all(color: Tok.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 32, offset: const Offset(0, 12))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: FoodImage(
            url: card.imageUrl,
            seed: tagLabel,
            label: card.title,
            iconSize: 56,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Tok.s16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Tag(tagLabel, colors: pastelFor(tagLabel)),
              if (card.rating != null) ...[
                const Spacer(),
                const PhosphorIcon(PhosphorIconsFill.star, size: 14, color: Tok.ink),
                const SizedBox(width: 4),
                Text(card.rating!.toStringAsFixed(1), style: T.mono(size: 12.5, color: Tok.ink)),
              ],
              if (card.etaMinutes != null) ...[
                const SizedBox(width: Tok.s12),
                const PhosphorIcon(PhosphorIconsBold.clock, size: 13, color: Tok.secondary),
                const SizedBox(width: 4),
                Text('${card.etaMinutes} min', style: T.mono(size: 12)),
              ],
            ]),
            const SizedBox(height: Tok.s8),
            Text(card.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.display(isRest ? 26 : 30)),
            if (isRest && card.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(card.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.secondary(size: 13.5)),
            ] else if (!isRest && card.subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(card.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.secondary(size: 14)),
            ],
            if (isRest && card.topDishes.isNotEmpty) ...[
              const SizedBox(height: Tok.s12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final dish in card.topDishes.take(3))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Tok.wash,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Tok.border),
                      ),
                      child: Text(dish, style: T.body(size: 12, color: Tok.ink).copyWith(height: 1.1)),
                    ),
                ],
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
