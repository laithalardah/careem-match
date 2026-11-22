import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'flow.dart';
import 'theme.dart';
import 'widgets.dart';

/// Main screen of the host app (Careem-style super app). Every picture is an asset slot
/// (assets/hub/NAME.png) that shows a tinted placeholder until the real image is added.
/// The "Match" tile and banner are the entry points for our feature.
class _C {
  static const headerTop = Color(0xFF0B3B2C);
  static const headerBottom = Color(0xFF1F6B4F);
  static const tile = Color(0xFFF5F5F3);
  static const badge = Color(0xFF14463A);
  static const badgeText = Color(0xFF7DF0B0);
  static const bannerBg = Color(0xFF123F34);
  static const discount = Color(0xFFC8505C);
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
  const HubScreen({super.key, required this.flow});
  final GameFlow flow;

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
                  padding: const EdgeInsets.fromLTRB(Tok.s16, Tok.s32, Tok.s16, Tok.s24),
                  child: Row(children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: Tok.s16),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(Tok.radius)),
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
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(Tok.radius)),
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView(padding: const EdgeInsets.only(top: Tok.s16, bottom: Tok.s32), children: [
                  _ServiceGrid(flow: flow),
                  const SizedBox(height: Tok.s16),
                  const _QuickRow(),
                  const SizedBox(height: Tok.s16),
                  const _PlusBanner(),
                  const SizedBox(height: Tok.s16),
                  _MatchBanner(flow: flow),
                  const SizedBox(height: Tok.s32),
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
  const _ServiceGrid({required this.flow});
  final GameFlow flow;

  @override
  Widget build(BuildContext context) {
    final row1 = [
      _Service('Rides', 'rides', PhosphorIconsBold.car),
      _Service('Food', 'food', PhosphorIconsBold.hamburger, badge: 'Plus Week'),
      _Service('Quik', 'quik', PhosphorIconsBold.basket, badge: 'AED 500 Off'),
      _Service('Pay', 'pay', PhosphorIconsBold.coins),
      _Service('DineOut', 'dineout', PhosphorIconsBold.forkKnife),
    ];
    final row2 = [
      // Our feature lives here.
      _Service('Match', 'match', PhosphorIconsBold.heart, badge: 'New', isNew: true, onTap: flow.openMatch),
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
            onTap: s.onTap,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 88,
              height: 118,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _C.tile,
                      borderRadius: BorderRadius.circular(14),
                      border: s.isNew ? Border.all(color: Tok.ink, width: 1.5) : null,
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: s.isNew ? Tok.ink : _C.badge, borderRadius: BorderRadius.circular(4)),
                        child: Text(s.badge!, style: T.body(size: 11, weight: FontWeight.w700, color: s.isNew ? Colors.white : _C.badgeText).copyWith(height: 1.1)),
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
        _QuickCard('Balance', 'Top-up now', 'pay', PhosphorIconsBold.wallet),
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
          width: 168,
          padding: const EdgeInsets.all(Tok.s12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Tok.radius), border: Border.all(color: Tok.border)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(top, style: T.secondary(size: 12)),
                const SizedBox(height: 2),
                Text(bottom, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(size: 14, weight: FontWeight.w700)),
              ]),
            ),
            SlotImage(image, icon: icon, size: 32),
          ]),
        ),
      );
}

// ── Banners ───────────────────────────────────────────────────────────────────
class _PlusBanner extends StatelessWidget {
  const _PlusBanner();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tok.s16),
        child: Container(
          height: 140,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: _C.bannerBg, borderRadius: BorderRadius.circular(Tok.radius)),
          child: Stack(children: [
            Positioned(right: 0, bottom: 0, top: 0, width: 170, child: SlotImage('banner_taxis', icon: PhosphorIconsBold.taxi, width: 170, height: 140, fit: BoxFit.cover, tint: Colors.white)),
            Padding(
              padding: const EdgeInsets.all(Tok.s16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _C.badgeText, borderRadius: BorderRadius.circular(6)),
                    child: Text('C+', style: T.body(size: 12, weight: FontWeight.w800, color: _C.bannerBg)),
                  ),
                  const SizedBox(width: Tok.s8),
                  Text('Save on rides', style: T.body(size: 13, color: Colors.white)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Get 10% back on Hala Taxi', style: T.body(size: 15, weight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 2),
                  SizedBox(width: 190, child: Text('Start a 60-day Careem Plus free trial', style: T.body(size: 12, color: Colors.white.withValues(alpha: 0.85)))),
                ]),
              ]),
            ),
          ]),
        ),
      );
}

/// Entry banner for our feature.
class _MatchBanner extends StatelessWidget {
  const _MatchBanner({required this.flow});
  final GameFlow flow;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tok.s16),
        child: Semantics(
          button: true,
          label: 'Careem Match. Swipe dishes with a friend and get one restaurant you both want.',
          child: InkWell(
            onTap: flow.openMatch,
            borderRadius: BorderRadius.circular(Tok.radius),
            child: Container(
              height: 156,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: _C.cream, borderRadius: BorderRadius.circular(Tok.radius), border: Border.all(color: Tok.border)),
              child: Row(children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(Tok.s16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Tag('New', colors: Tok.green),
                      const SizedBox(height: Tok.s8),
                      Text('Can\'t agree on dinner?', style: T.display(21)),
                      const SizedBox(height: 4),
                      Text('Swipe dishes with a friend. Get one restaurant.', maxLines: 3, style: T.secondary(size: 13)),
                    ]),
                  ),
                ),
                SlotImage('match_banner', icon: PhosphorIconsBold.heart, width: 120, height: 156, fit: BoxFit.cover),
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
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tok.s16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AED 500 off across\n10 orders', style: T.body(size: 24, weight: FontWeight.w800).copyWith(height: 1.2)),
              const SizedBox(height: Tok.s8),
              Text('Use code: SAVE500', style: T.body(size: 14)),
            ]),
          ),
          SlotImage('promo_bags', icon: PhosphorIconsBold.shoppingBag, size: 110),
        ]),
      ),
      const SizedBox(height: Tok.s16),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Tok.s16),
        child: Row(children: const [
          _Product('69% off', 'Morocco', 'product_blueberries', PhosphorIconsBold.orange),
          _Product('75% off', 'Ecuador', 'product_bananas', PhosphorIconsBold.orange),
          _Product('60% off', 'Daily', 'product_tissues', PhosphorIconsBold.package),
        ]),
      ),
    ]);
  }
}

class _Product extends StatelessWidget {
  const _Product(this.discount, this.origin, this.image, this.icon);
  final String discount, origin, image;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: Tok.s12),
        child: Container(
          width: 150,
          height: 170,
          decoration: BoxDecoration(color: _C.cream, borderRadius: BorderRadius.circular(Tok.radius)),
          child: Stack(children: [
            Positioned.fill(child: Padding(padding: const EdgeInsets.fromLTRB(Tok.s12, 36, Tok.s12, Tok.s12), child: SlotImage(image, icon: icon, size: 100, width: 126, height: 120))),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _C.discount, borderRadius: BorderRadius.circular(4)),
                child: Text(discount, style: T.body(size: 12, weight: FontWeight.w700, color: Colors.white).copyWith(height: 1.1)),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Text(origin, style: T.body(size: 11, weight: FontWeight.w600, color: Tok.secondary)),
            ),
          ]),
        ),
      );
}
