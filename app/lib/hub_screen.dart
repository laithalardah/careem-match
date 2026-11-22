import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'theme.dart';

/// Main screen of the host app (Careem-style super app). Every picture is an asset slot
/// (assets/hub/NAME.png) that shows a tinted placeholder until the real image is added.
/// The "Match" tile and banner are the entry points for our feature.
class _C {
  static const headerTop = Color(0xFF154E3B);
  static const headerBottom = Color(0xFF0A271E);
  static const tile = Color(0xFFF6F6F5);
  static const matchTile = Color(0xFFECF8F1);
  static const matchBorder = Color(0xFF1B6B4F);
  static const badge = Color(0xFF164336);
  static const badgeText = Color(0xFF6FE89F);
  static const bannerBg = Color(0xFF143E33);
  static const bannerBgEnd = Color(0xFF1C5344);
  static const discount = Color(0xFFB84755);
  static const cream = Color(0xFFF7F4EE);
}

/// Image slot with an icon fallback.
class SlotImage extends StatelessWidget {
  const SlotImage(this.name, {super.key, required this.icon, this.size = 56, this.fit = BoxFit.contain, this.width, this.height, this.tint = Tok.secondary});
  final String name; // file name without extension, in assets/hub/
  final IconData icon;
  final double size;
  final double? width, height;
  final BoxFit fit;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final fallback = SizedBox(
      width: width ?? size,
      height: height ?? size,
      child: Center(child: PhosphorIcon(icon, size: size * 0.6, color: tint.withValues(alpha: 0.55))),
    );
    return Image.asset(
      'assets/hub/$name.png',
      width: width ?? size,
      height: height ?? size,
      fit: fit,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class HubScreen extends StatelessWidget {
  const HubScreen({super.key, required this.onOpenMatch});
  final VoidCallback onOpenMatch;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.headerTop,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Tok.maxWidth),
          child: Column(children: [
            // Header: search + menu on a green wash
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_C.headerTop, _C.headerBottom]),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Tok.s16, Tok.s16, Tok.s16, Tok.s24),
                  child: Row(children: [
                    Expanded(
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: Tok.s16),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          Expanded(child: Text('Discover places', style: T.body(size: 16, color: const Color(0xFF2B3A35)))),
                          const PhosphorIcon(PhosphorIconsBold.magnifyingGlass, size: 20, color: Tok.ink),
                        ]),
                      ),
                    ),
                    const SizedBox(width: Tok.s12),
                    Semantics(
                      label: 'Menu',
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: PhosphorIcon(PhosphorIconsBold.list, size: 20, color: Tok.ink)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            // White sheet
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView(padding: const EdgeInsets.only(top: Tok.s16, bottom: Tok.s32), children: [
                  _ServiceGrid(onOpenMatch: onOpenMatch),
                  const SizedBox(height: Tok.s16),
                  const _QuickRow(),
                  const SizedBox(height: Tok.s16),
                  _MatchBanner(onOpenMatch: onOpenMatch),
                  const SizedBox(height: Tok.s12),
                  const _PlusBanner(),
                  const SizedBox(height: Tok.s24),
                  const _PromoSection(),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Service grid ──────────────────────────────────────────────────────────────
class _Service {
  const _Service(this.label, this.image, this.icon, {this.badge, this.isNew = false, this.onTap});
  final String label, image;
  final IconData icon;
  final String? badge;
  final bool isNew;
  final VoidCallback? onTap;
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.onOpenMatch});
  final VoidCallback onOpenMatch;

  @override
  Widget build(BuildContext context) {
    final row1 = [
      _Service('Rides', 'rides', PhosphorIconsBold.car),
      _Service('Food', 'food', PhosphorIconsBold.hamburger),
      _Service('Quik', 'quik', PhosphorIconsBold.basket),
      _Service('Pay', 'pay', PhosphorIconsBold.coins),
      _Service('DineOut', 'dineout', PhosphorIconsBold.forkKnife),
    ];
    final row2 = [
      // Our feature lives here.
      _Service('Match', 'match', PhosphorIconsBold.heart, badge: 'New', isNew: true, onTap: onOpenMatch),
      _Service('Hala Taxi', 'hala_taxi', PhosphorIconsBold.taxi),
      _Service('Box', 'box', PhosphorIconsBold.package),
      _Service('Electronics', 'electronics', PhosphorIconsBold.headphones),
      _Service('Home&Spa', 'home_spa', PhosphorIconsBold.broom),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(Tok.s16, 12, Tok.s16, 0), // room for the badges above the tiles
      child: Column(children: [
        Row(children: [for (final s in row1) _Tile(s)]),
        const SizedBox(height: Tok.s12),
        Row(children: [for (final s in row2) _Tile(s)]),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.s);
  final _Service s;

  @override
  Widget build(BuildContext context) {
    final active = s.onTap != null;
    return Padding(
      padding: const EdgeInsets.only(right: Tok.s12),
      child: Semantics(
        button: active,
        label: s.badge == null ? s.label : '${s.label}, ${s.badge}',
        child: ExcludeSemantics(
          child: InkWell(
            onTap: s.onTap ??
                () {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      content: Text('${s.label} is part of the Careem hub — tap Match to start swiping dishes.'),
                    ));
                },
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 88,
              height: 118,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: s.isNew ? _C.matchTile : _C.tile,
                      borderRadius: BorderRadius.circular(14),
                      border: s.isNew ? Border.all(color: _C.matchBorder, width: 1.5) : null,
                    ),
                    padding: const EdgeInsets.fromLTRB(6, 14, 6, 10),
                    child: Column(children: [
                      Expanded(child: SlotImage(s.image, icon: s.icon, size: 68)),
                      const SizedBox(height: 6),
                      Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(size: 13, weight: FontWeight.w700)),
                    ]),
                  ),
                ),
                if (s.badge != null)
                  Positioned(
                    top: -8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: s.isNew ? _C.headerTop : _C.badge,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s.badge!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.body(size: 10.5, weight: FontWeight.w700, color: _C.badgeText).copyWith(height: 1.1),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Quick action cards ────────────────────────────────────────────────────────
class _QuickRow extends StatelessWidget {
  const _QuickRow();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Tok.s16),
      child: Row(children: [
        _QuickCard('Balance', 'Top-up now', 'wallet', PhosphorIconsBold.wallet),
        _QuickCard('Ride to', 'JW Marriott Marquis', 'rides', PhosphorIconsBold.car),
        _QuickCard('Salik', 'Add account', 'salik', PhosphorIconsBold.plusCircle),
      ]),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard(this.top, this.bottom, this.image, this.icon);
  final String top, bottom, image;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: Tok.s12),
        child: Container(
          width: 172,
          padding: const EdgeInsets.symmetric(horizontal: Tok.s12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Tok.border)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(top, style: T.secondary(size: 12)),
                const SizedBox(height: 2),
                Text(bottom, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(size: 13.5, weight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(width: Tok.s8),
            SlotImage(image, icon: icon, size: 34),
          ]),
        ),
      );
}

// ── Banners ───────────────────────────────────────────────────────────────────
class _PlusBanner extends StatelessWidget {
  const _PlusBanner();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Tok.s16, 14, Tok.s16, 0),
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 140),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [_C.bannerBg, _C.bannerBgEnd],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.fromLTRB(Tok.s16, 14, 142, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: _C.badgeText, borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const PhosphorIcon(PhosphorIconsFill.smiley, size: 13, color: _C.bannerBg),
                    Text('+', style: T.body(size: 12, weight: FontWeight.w800, color: _C.bannerBg).copyWith(height: 1.0)),
                  ]),
                ),
                const SizedBox(width: Tok.s8),
                Flexible(child: Text('Save on rides', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(size: 13, weight: FontWeight.w500, color: Colors.white))),
              ]),
              const SizedBox(height: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'Get ', style: T.body(size: 14, weight: FontWeight.w700, color: Colors.white).copyWith(height: 1.25)),
                    TextSpan(text: '10% back on Hala Taxi', style: T.body(size: 14, weight: FontWeight.w700, color: _C.badgeText).copyWith(height: 1.25)),
                  ]),
                ),
                const SizedBox(height: 3),
                Text(
                  'Start a 60-day Careem Plus free trial',
                  style: T.body(size: 11.5, color: Colors.white.withValues(alpha: 0.85)).copyWith(height: 1.3),
                ),
              ]),
            ]),
          ),
          // Two Hala taxis pop cleanly over the top-right corner, matching the Careem Plus card.
          const Positioned(
            right: -4,
            top: -20,
            bottom: -4,
            width: 148,
            child: SlotImage('banner_taxis', icon: PhosphorIconsBold.taxi, width: 148, height: 164, fit: BoxFit.contain, tint: Colors.white),
          ),
        ]),
      );
}

/// Entry banner for our feature — Careem-themed flagship promo card.
class _MatchBanner extends StatelessWidget {
  const _MatchBanner({required this.onOpenMatch});
  final VoidCallback onOpenMatch;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tok.s16),
        child: Semantics(
          button: true,
          label: 'Careem Match. Can\'t agree on dinner? Swipe dishes with a friend and get one restaurant you both want.',
          child: InkWell(
            onTap: onOpenMatch,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A3327), Color(0xFF13503D), Color(0xFF1C6B50)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B3529).withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(children: [
                // Subtle Careem mint ambient glow behind the 3D artwork.
                Positioned(
                  right: -24,
                  top: -20,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _C.badgeText.withValues(alpha: 0.34),
                          _C.badgeText.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Subtle Careem bolt watermark along the right side.
                const Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 180,
                  child: IgnorePointer(child: CustomPaint(painter: _PromoPatternPainter())),
                ),
                IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(Tok.s16, 16, Tok.s8, 16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: _C.badgeText,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const PhosphorIcon(PhosphorIconsFill.sparkle, size: 11, color: _C.headerBottom),
                                const SizedBox(width: 4),
                                Text('NEW · MATCH', style: T.body(size: 10.5, weight: FontWeight.w800, color: _C.headerBottom).copyWith(height: 1.0, letterSpacing: 0.4)),
                              ]),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                text: "Can't agree on ",
                                style: T.body(size: 19, weight: FontWeight.w800, color: Colors.white).copyWith(height: 1.18, letterSpacing: -0.3),
                              ),
                              TextSpan(
                                text: 'dinner?',
                                style: T.body(size: 19, weight: FontWeight.w800, color: _C.badgeText).copyWith(height: 1.18, letterSpacing: -0.3),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Swipe dishes with a friend. We find one restaurant for both.',
                            style: T.body(size: 12.5, color: Colors.white.withValues(alpha: 0.86)).copyWith(height: 1.35),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: _C.badgeText,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('Start matching', style: T.body(size: 12.5, weight: FontWeight.w800, color: _C.headerBottom).copyWith(height: 1.1)),
                              const SizedBox(width: 5),
                              const PhosphorIcon(PhosphorIconsBold.arrowRight, size: 13, color: _C.headerBottom),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(0, 8, 8, 8),
                      child: SizedBox(
                        width: 124,
                        child: SlotImage('match_banner', icon: PhosphorIconsBold.heart, width: 124, height: 158, fit: BoxFit.contain, tint: Colors.white),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}

// ── Promo products ────────────────────────────────────────────────────────────
class _PromoSection extends StatelessWidget {
  const _PromoSection();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Stack(children: [
        const Positioned(
          right: 0,
          top: -8,
          bottom: -8,
          width: 240,
          child: IgnorePointer(child: CustomPaint(painter: _PromoPatternPainter())),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tok.s16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AED 500 off across\n10 orders', style: T.body(size: 22, weight: FontWeight.w800).copyWith(height: 1.2)),
                const SizedBox(height: 6),
                Text('Use code: SAVE500', style: T.body(size: 13.5, color: const Color(0xFF333333))),
              ]),
            ),
            const SlotImage('promo_bags', icon: PhosphorIconsBold.shoppingBag, size: 112),
          ]),
        ),
      ]),
      const SizedBox(height: Tok.s16),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Tok.s16),
        child: Row(children: const [
          _Product('69% off', 'Morocco...', 'product_blueberries', PhosphorIconsBold.orange, limitLabel: '1 Per Order'),
          _Product('75% off', 'Ecuador', 'product_bananas', PhosphorIconsBold.orange, limitLabel: '1 Per Order'),
          _Product('60% off', 'Daily', 'product_tissues', PhosphorIconsBold.package),
        ]),
      ),
    ]);
  }
}

class _Product extends StatelessWidget {
  const _Product(this.discount, this.origin, this.image, this.icon, {this.limitLabel});
  final String discount, origin, image;
  final IconData icon;
  final String? limitLabel;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: Tok.s12),
        child: Container(
          width: 150,
          height: 172,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: _C.cream, borderRadius: BorderRadius.circular(12)),
          child: Stack(children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(limitLabel == null ? Tok.s12 : 26, 36, Tok.s8, Tok.s8),
                child: SlotImage(image, icon: icon, size: 108, width: 120, height: 124, fit: BoxFit.contain),
              ),
            ),
            if (limitLabel != null)
              Positioned(
                left: 6,
                top: 40,
                bottom: 8,
                child: Container(
                  width: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _C.discount, borderRadius: BorderRadius.circular(4)),
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      limitLabel!,
                      style: T.body(size: 10.5, weight: FontWeight.w700, color: Colors.white).copyWith(height: 1.0),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(color: _C.discount, borderRadius: BorderRadius.circular(5)),
                child: Text(discount, style: T.body(size: 11.5, weight: FontWeight.w700, color: Colors.white).copyWith(height: 1.1)),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(5)),
                child: Text(origin, style: T.body(size: 10.5, weight: FontWeight.w600, color: Tok.ink).copyWith(height: 1.1)),
              ),
            ),
          ]),
        ),
      );
}

/// Subtle diagonal Careem-Quik mint bolt pattern behind the promo bags header.
class _PromoPatternPainter extends CustomPainter {
  const _PromoPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF6FE89F).withValues(alpha: 0.14);
    const stepX = 24.0;
    const stepY = 22.0;
    for (double y = 0; y < size.height; y += stepY) {
      final offset = ((y ~/ stepY) % 2) * 12.0;
      for (double x = offset; x < size.width; x += stepX) {
        final p = Path()
          ..moveTo(x + 7, y)
          ..lineTo(x + 12, y)
          ..lineTo(x + 6, y + 8)
          ..lineTo(x + 10, y + 8)
          ..lineTo(x + 3, y + 16)
          ..lineTo(x + 6, y + 10)
          ..lineTo(x + 2, y + 10)
          ..close();
        canvas.drawPath(p, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
