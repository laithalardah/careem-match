import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'theme.dart';

/// Careem-themed shell matching the Hub structure:
/// dark forest-green gradient header + rounded plain white sheet (max 480).
class Shell extends StatelessWidget {
  const Shell({super.key, required this.child, this.header, this.footer, this.immersive = false});
  final Widget child;
  final Widget? header;
  final Widget? footer;

  /// Full-screen mode: no header or sheet, the child fills everything (give `child` a GlobalKey to keep its state).
  final bool immersive;

  @override
  Widget build(BuildContext context) {
    if (immersive) {
      return Scaffold(
        backgroundColor: Tok.careemDark,
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: Tok.maxWidth), child: child)),
      );
    }
    return Scaffold(
      backgroundColor: Tok.careemDark,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Tok.maxWidth),
          child: Column(children: [
            // Careem green gradient top header (same visual structure as HubScreen).
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Tok.careemGreen, Tok.careemDark],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  // Extra 24 at the bottom: the sheet overlaps it, so both top corners of the curve show header green.
                  padding: EdgeInsets.fromLTRB(Tok.s16, Tok.s12, Tok.s16, (header == null ? Tok.s12 : Tok.s16) + 24),
                  child: header ?? const SizedBox(height: 8),
                ),
              ),
            ),
            // Rounded plain white sheet rising over the green header: identical to the home page.
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => OverflowBox(
                  alignment: Alignment.bottomCenter,
                  minHeight: box.maxHeight + 24,
                  maxHeight: box.maxHeight + 24,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(Tok.s24, Tok.s16, Tok.s24, Tok.s24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: child),
                            if (footer != null) ...[const SizedBox(height: Tok.s16), footer!],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Standard Careem green header bar for sub-screens matching HubScreen's chrome.
class CareemHeaderBar extends StatelessWidget {
  const CareemHeaderBar({
    super.key,
    required this.onBack,
    required this.backTooltip,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final VoidCallback onBack;
  final String backTooltip;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Semantics(
        button: true,
        label: backTooltip,
        child: InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const PhosphorIcon(PhosphorIconsBold.caretLeft, size: 20, color: Colors.white),
          ),
        ),
      ),
      const SizedBox(width: Tok.s12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const PhosphorIcon(PhosphorIconsFill.forkKnife, size: 15, color: Tok.careemMint),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.body(size: 16, weight: FontWeight.w700, color: Colors.white).copyWith(height: 1.15),
              ),
            ),
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.mono(size: 11.5, color: Tok.careemMint.withValues(alpha: 0.92)),
            ),
          ],
        ]),
      ),
      if (trailing != null) ...[const SizedBox(width: Tok.s8), trailing!],
    ]);
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

/// Network image with verified restaurant/dish photo fallbacks (when MCP URLs are
/// missing, null, or dead sandbox CDN links) and a cuisine-aware icon placeholder offline.
class FoodImage extends StatelessWidget {
  const FoodImage({super.key, required this.url, required this.seed, this.label, this.height, this.iconSize = 40});
  final String? url;
  final String seed;
  final String? label;
  final double? height;
  final double iconSize;

  static const _deadSandboxHost = 'careem-catalog-media.media.careem.com';

  static const _generalPool = [
    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=900&q=80',
    'https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?w=900&q=80',
    'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=900&q=80',
    'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=900&q=80',
  ];

  static IconData _iconFor(String key) {
    final k = key.toLowerCase();
    if (k.contains('burger')) return PhosphorIconsBold.hamburger;
    if (k.contains('coffee') || k.contains('cappuccino') || k.contains('breakfast')) return PhosphorIconsBold.coffee;
    if (k.contains('pizza') || k.contains('italian') || k.contains('napoli')) return PhosphorIconsBold.pizza;
    if (k.contains('sushi') || k.contains('salmon') || k.contains('japanese')) return PhosphorIconsBold.fish;
    if (k.contains('dessert') || k.contains('bakery') || k.contains('gelato') || k.contains('sweet')) return PhosphorIconsBold.cookie;
    if (k.contains('bowl') || k.contains('healthy') || k.contains('salad') || k.contains('greens')) return PhosphorIconsBold.bowlFood;
    if (k.contains('grill') || k.contains('shawarma') || k.contains('mandi') || k.contains('arabic')) return PhosphorIconsBold.fire;
    return PhosphorIconsBold.forkKnife;
  }

  /// Always returns a verified real food/restaurant photo URL for any restaurant, dish, or category.
  static String fallbackPhoto({String? label, required String seed}) {
    final q = '${label ?? ''} $seed'.toLowerCase();

    // Specific sandbox restaurants & dishes first so every card gets its own distinct photo.
    if (q.contains('napoli') || q.contains('pepperoni') || q.contains('slice')) {
      return 'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=900&q=80';
    }
    if (q.contains('pizza') || q.contains('margherita') || q.contains('italian')) {
      return 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=900&q=80';
    }
    if (q.contains('burger') || q.contains('smash') || q.contains('american')) {
      return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=900&q=80';
    }
    if (q.contains('gelato') || q.contains('sorbet') || q.contains('ice cream')) {
      return 'https://images.unsplash.com/photo-1567206563064-6f60f40a2b57?w=900&q=80';
    }
    if (q.contains('sweet tooth') || q.contains('bakery') || q.contains('kunafa') || q.contains('baklava') || q.contains('cake') || q.contains('dessert') || q.contains('sweets')) {
      return 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=900&q=80';
    }
    if (q.contains('mandi') || q.contains('mansaf') || q.contains('biryani') || q.contains('kabsa')) {
      return 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=900&q=80';
    }
    if (q.contains('wok') || q.contains('chow mein') || q.contains('noodle') || q.contains('chinese') || q.contains('asian') || q.contains('thai')) {
      return 'https://images.unsplash.com/photo-1585032226651-759b368d7246?w=900&q=80';
    }
    if (q.contains('ramen')) {
      return 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=900&q=80';
    }
    if (q.contains('sunrise') || q.contains('foul') || q.contains('falafel') || q.contains('hummus') || q.contains('shakshuka')) {
      return 'https://images.unsplash.com/photo-1547058881-aa0edd92aab3?w=900&q=80';
    }
    if (q.contains('syrniki') || q.contains('morning') || q.contains('breakfast') || q.contains('pancake') || q.contains('brunch')) {
      return 'https://images.unsplash.com/photo-1528207776546-365bb710ee93?w=900&q=80';
    }
    if (q.contains('cappuccino') || q.contains('coffee') || q.contains('latte') || q.contains('cafe')) {
      return 'https://images.unsplash.com/photo-1572442388796-11668a67e53d?w=900&q=80';
    }
    if (q.contains('sushi') || q.contains('salmon') || q.contains('sakura') || q.contains('maki')) {
      return 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=900&q=80';
    }
    if (q.contains('katsu') || q.contains('bento') || q.contains('japanese') || q.contains('chicken')) {
      return 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=900&q=80';
    }
    if (q.contains('fresh greens') || q.contains('quinoa') || q.contains('greek') || q.contains('salad')) {
      return 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=900&q=80';
    }
    if (q.contains('green bowl') || q.contains('bowl') || q.contains('caesar') || q.contains('healthy')) {
      return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=900&q=80';
    }
    if (q.contains('shawarma')) {
      return 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=900&q=80';
    }
    if (q.contains('grill') || q.contains('kebab') || q.contains('arabic') || q.contains('lebanese')) {
      return 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=900&q=80';
    }
    if (q.contains('pasta') || q.contains('spaghetti') || q.contains('risotto')) {
      return 'https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?w=900&q=80';
    }
    if (q.contains('taco') || q.contains('burrito') || q.contains('mexican')) {
      return 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=900&q=80';
    }
    if (q.contains('steak') || q.contains('bbq') || q.contains('ribs')) {
      return 'https://images.unsplash.com/photo-1544025162-d76694265947?w=900&q=80';
    }
    if (q.contains('curry') || q.contains('indian') || q.contains('tikka') || q.contains('masala')) {
      return 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=900&q=80';
    }

    // Guaranteed deterministic photo fallback so NO restaurant is ever left without an image.
    final hash = q.codeUnits.fold(0, (a, b) => a + b);
    return _generalPool[hash % _generalPool.length];
  }

  /// Picks the primary URL to load: live MCP image if usable, otherwise the verified fallback photo immediately.
  static String primaryUrl(String? url, {String? label, required String seed}) {
    final trimmed = url?.trim() ?? '';
    final usable = trimmed.isNotEmpty &&
        (trimmed.startsWith('http://') || trimmed.startsWith('https://')) &&
        !trimmed.contains(_deadSandboxHost);
    return usable ? trimmed : fallbackPhoto(label: label, seed: seed);
  }

  Widget _net(String src, Widget onErr, Widget placeholder) => Image.network(
        src,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => onErr,
        loadingBuilder: (_, child, p) => p == null ? child : placeholder,
      );

  @override
  Widget build(BuildContext context) {
    final c = pastelFor(seed);
    final iconPlaceholder = Container(
      height: height,
      color: c.$1,
      alignment: Alignment.center,
      child: PhosphorIcon(_iconFor('${label ?? ''} $seed'), size: iconSize, color: c.$2),
    );
    final backup = fallbackPhoto(label: label, seed: seed);
    final primary = primaryUrl(url, label: label, seed: seed);
    final backupWidget = _net(backup, iconPlaceholder, iconPlaceholder);
    if (primary == backup) return backupWidget;
    return _net(primary, backupWidget, iconPlaceholder);
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

String money(double v, String cur) => '${v.toStringAsFixed(2)} ${cur.isEmpty ? 'JOD' : cur}';

/// Distinct pastel avatar with Phosphor crown above the host everywhere participants appear.
class ParticipantAvatar extends StatelessWidget {
  const ParticipantAvatar({
    super.key,
    required this.id,
    required this.name,
    this.isHost = false,
    this.size = 38,
  });

  final String id;
  final String name;
  final bool isHost;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = pastelFor('$id:$name');
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.$1,
        shape: BoxShape.circle,
        border: Border.all(color: c.$2.withValues(alpha: 0.25)),
      ),
      child: Text(
        _initials,
        style: T.body(size: size * 0.38, weight: FontWeight.w700, color: c.$2).copyWith(height: 1.0),
      ),
    );

    return Semantics(
      label: isHost ? '$name, host' : name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 14,
            child: isHost
                ? const PhosphorIcon(PhosphorIconsFill.crown, size: 13, color: Color(0xFF956400))
                : null,
          ),
          avatar,
        ],
      ),
    );
  }
}

/// Warm monochrome skeleton block (used instead of blocking spinners).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = Tok.radiusSm});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Tok.wash,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Tok.border),
        ),
      );
}

/// Non-blocking banner shown after 3 consecutive failed room polls.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Tok.s12, vertical: Tok.s8),
          decoration: BoxDecoration(
            color: Tok.yellow.$1,
            borderRadius: BorderRadius.circular(Tok.radiusSm),
            border: Border.all(color: Tok.yellow.$2.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            PhosphorIcon(PhosphorIconsBold.wifiSlash, size: 16, color: Tok.yellow.$2),
            const SizedBox(width: Tok.s8),
            Expanded(
              child: Text(
                'Reconnecting to room. Changes will sync once back online.',
                style: T.body(size: 13, color: Tok.yellow.$2).copyWith(height: 1.3),
              ),
            ),
          ]),
        ),
      );
}
