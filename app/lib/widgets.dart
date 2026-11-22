import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'theme.dart';

/// Shell shell: centered column (max 480), safe areas, 24 margins.
class Shell extends StatelessWidget {
  const Shell({super.key, required this.child, this.footer});
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Tok.maxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Tok.s24, Tok.s16, Tok.s24, Tok.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Expanded(child: child), if (footer != null) ...[const SizedBox(height: Tok.s16), footer!]],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertically centered, left-aligned content that scrolls instead of overflowing on short screens.
class CenteredScroll extends StatelessWidget {
  const CenteredScroll({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: children),
          ),
        ),
      );
}

/// Small uppercase pastel tag.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.colors = Tok.blue});
  final String text;
  final (Color, Color) colors;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: colors.$1, borderRadius: BorderRadius.circular(100)),
        child: Text(text.toUpperCase(), style: T.tag(colors.$2)),
      );
}

(Color, Color) pastelFor(String key) {
  const all = [Tok.yellow, Tok.green, Tok.blue, Tok.red];
  return all[key.codeUnits.fold(0, (a, b) => a + b) % all.length];
}

/// Bordered 1px card, no shadow.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(Tok.s24), this.color = Tok.card});
  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Tok.radius),
          border: Border.all(color: Tok.border),
        ),
        child: child,
      );
}

/// Network image with a tinted, icon-based fallback (catalog images may not load offline).
class FoodImage extends StatelessWidget {
  const FoodImage({super.key, required this.url, required this.seed, this.height, this.iconSize = 40});
  final String? url;
  final String seed;
  final double? height;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = pastelFor(seed);
    final fallback = Container(
      height: height,
      color: c.$1,
      alignment: Alignment.center,
      child: PhosphorIcon(PhosphorIconsBold.forkKnife, size: iconSize, color: c.$2),
    );
    if (url == null) return fallback;
    return Image.network(
      url!,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (_, child, p) => p == null ? child : fallback,
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(Tok.s16, Tok.s12, Tok.s8, Tok.s12),
          decoration: BoxDecoration(color: Tok.red.$1, borderRadius: BorderRadius.circular(Tok.radiusSm)),
          child: Row(children: [
            Expanded(child: Text(message, style: T.body(size: 14, color: Tok.red.$2))),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onClose,
              icon: PhosphorIcon(PhosphorIconsBold.x, size: 16, color: Tok.red.$2),
            ),
          ]),
        ),
      );
}

/// Fade + 12px rise entry, 600ms. Respects Reduce Motion.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.delay = 0});
  final Widget child;
  final int delay; // step index; 80ms each

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + delay * 80),
      curve: const Cubic(0.16, 1, 0.3, 1),
      builder: (_, v, c) => Opacity(opacity: v.clamp(0, 1), child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: c)),
      child: child,
    );
  }
}
