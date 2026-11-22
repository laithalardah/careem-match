import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

/// One player swipes the whole deck. Drag, tap the buttons, or use the arrow keys.
class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key, required this.player, required this.dishes, required this.onSwipe, required this.onDone});
  final int player;
  final List<Dish> dishes;
  final void Function(Dish dish, bool liked) onSwipe;
  final VoidCallback onDone;

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> with SingleTickerProviderStateMixin {
  static const _threshold = 110.0;
  int _index = 0;
  Offset _drag = Offset.zero;
  bool _busy = false;
  late final AnimationController _ctrl = AnimationController(vsync: this);
  Animation<Offset>? _anim;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() => _drag = _anim!.value));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _animateTo(Offset to, {bool? like, required double width}) async {
    final reduce = MediaQuery.disableAnimationsOf(context);
    _anim = Tween(begin: _drag, end: to).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.duration = reduce ? Duration.zero : Duration(milliseconds: like == null ? 180 : 240);
    await _ctrl.forward(from: 0);
    if (!mounted) return;
    if (like != null) _commit(like);
    _busy = false;
  }

  void _commit(bool liked) {
    HapticFeedback.selectionClick();
    widget.onSwipe(widget.dishes[_index], liked);
    final last = _index + 1 >= widget.dishes.length;
    setState(() {
      _drag = Offset.zero;
      if (!last) _index++;
    });
    if (last) widget.onDone();
  }

  void _decide(bool liked, double width) {
    if (_busy) return;
    _busy = true;
    SemanticsService.sendAnnouncement(View.of(context), liked ? 'Liked' : 'Skipped', TextDirection.ltr);
    _animateTo(Offset((liked ? 1 : -1) * width * 1.4, _drag.dy), like: liked, width: width);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.dishes.length;
    final dish = widget.dishes[_index];
    final next = _index + 1 < total ? widget.dishes[_index + 1] : null;
    final tagColors = widget.player == 1 ? Tok.blue : Tok.green;

    return Shell(
      footer: LayoutBuilder(builder: (context, c) {
        final w = MediaQuery.sizeOf(context).width;
        return Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _decide(false, w),
              icon: const PhosphorIcon(PhosphorIconsBold.x, size: 18),
              label: const Text('Skip'),
            ),
          ),
          const SizedBox(width: Tok.s12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _decide(true, w),
              icon: const PhosphorIcon(PhosphorIconsFill.heart, size: 18),
              label: const Text('Like'),
            ),
          ),
        ]);
      }),
      child: Focus(
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
            Tag('Player ${widget.player}', colors: tagColors),
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
          const SizedBox(height: Tok.s24),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth;
              final progress = (_drag.dx.abs() / _threshold).clamp(0.0, 1.0);
              return Stack(alignment: Alignment.topCenter, children: [
                if (next != null)
                  Transform.scale(
                    scale: 0.95 + 0.05 * progress,
                    alignment: Alignment.bottomCenter,
                    child: Opacity(opacity: 0.6 + 0.4 * progress, child: _DishCard(dish: next, key: ValueKey('b${next.id}'))),
                  ),
                Semantics(
                  label: '${dish.name}, ${dish.cuisine}. Card ${_index + 1} of $total.',
                  customSemanticsActions: {
                    const CustomSemanticsAction(label: 'Like'): () => _decide(true, w),
                    const CustomSemanticsAction(label: 'Skip'): () => _decide(false, w),
                  },
                  child: GestureDetector(
                    onPanUpdate: (d) {
                      if (_busy) return;
                      setState(() => _drag += Offset(d.delta.dx, d.delta.dy * 0.3));
                    },
                    onPanEnd: (d) {
                      if (_busy) return;
                      final fling = d.velocity.pixelsPerSecond.dx;
                      if (_drag.dx > _threshold || fling > 900) {
                        _decide(true, w);
                      } else if (_drag.dx < -_threshold || fling < -900) {
                        _decide(false, w);
                      } else {
                        _busy = true;
                        _animateTo(Offset.zero, width: w);
                      }
                    },
                    child: Transform.translate(
                      offset: _drag,
                      child: Transform.rotate(
                        angle: _drag.dx / w * 0.12,
                        child: Stack(children: [
                          _DishCard(dish: dish, key: ValueKey('t${dish.id}')),
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
        ]),
      ),
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

class _DishCard extends StatelessWidget {
  const _DishCard({super.key, required this.dish});
  final Dish dish;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tok.card,
        borderRadius: BorderRadius.circular(Tok.radius),
        border: Border.all(color: Tok.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 32, offset: const Offset(0, 12))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: FoodImage(url: dish.imageUrl, seed: dish.cuisine, label: dish.name, iconSize: 56)),
        Padding(
          padding: const EdgeInsets.all(Tok.s24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Tag(dish.cuisine, colors: pastelFor(dish.cuisine)),
            const SizedBox(height: Tok.s12),
            Text(dish.name, style: T.display(30)),
          ]),
        ),
      ]),
    );
  }
}
