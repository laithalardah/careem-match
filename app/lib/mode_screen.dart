import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'api.dart';
import 'models.dart';
import 'storage.dart';
import 'theme.dart';
import 'widgets.dart';

/// Step 1: Choose mode ("Food" delivery with dimmed pizza backdrop, or "Dine Out"
/// with dimmed fancy restaurant table backdrop) in Careem green-and-white structure.
class ModeScreen extends StatefulWidget {
  const ModeScreen({super.key, required this.api});
  final Api api;

  @override
  State<ModeScreen> createState() => _ModeScreenState();
}

class _ModeScreenState extends State<ModeScreen> {
  static const _foodPhoto = 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=900&q=80';
  static const _dineOutPhoto = 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=900&q=80';

  late final TextEditingController _nameCtrl = TextEditingController(
    text: SessionStore.getLastName() ?? 'Awni',
  );
  bool _creating = false;
  RoomMode? _creatingMode;
  String? _nameError;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMode(RoomMode mode) async {
    if (_creating) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Enter your name so friends know who is hosting.');
      return;
    }
    setState(() {
      _creating = true;
      _creatingMode = mode;
      _nameError = null;
      _error = null;
    });
    try {
      SessionStore.setLastName(name);
      final res = await widget.api.createRoom(mode: mode, hostName: name);
      SessionStore.setParticipantId(res.roomCode, res.participantId);
      if (!mounted) return;
      context.go('/room/${res.roomCode}');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not create a room. Check your connection and try again.';
        _creating = false;
        _creatingMode = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shell(
      header: CareemHeaderBar(
        onBack: () => context.go('/'),
        backTooltip: 'Back to Careem',
        title: 'Careem Match',
        subtitle: 'Amman, Jordan',
        trailing: widget.api.isMock ? const Tag('Mock backend', colors: Tok.yellow) : null,
      ),
      footer: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_error != null) ...[
          ErrorBanner(message: _error!, onClose: () => setState(() => _error = null)),
          const SizedBox(height: Tok.s12),
        ],
        if (widget.api.isMock)
          Semantics(
            toggled: widget.api.forceDispute,
            label: 'Force dispute scenario in mock backend',
            child: InkWell(
              onTap: () => setState(() => widget.api.forceDispute = !widget.api.forceDispute),
              borderRadius: BorderRadius.circular(Tok.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Tok.s8, horizontal: Tok.s4),
                child: Row(children: [
                  PhosphorIcon(
                    widget.api.forceDispute ? PhosphorIconsFill.checkSquare : PhosphorIconsBold.square,
                    size: 18,
                    color: Tok.careemGreen,
                  ),
                  const SizedBox(width: Tok.s8),
                  Expanded(child: Text('Force dispute (demo toggle)', style: T.secondary(size: 13))),
                ]),
              ),
            ),
          ),
      ]),
      child: CenteredScroll(children: [
        const Reveal(child: Tag('Start a match', colors: Tok.green)),
        const SizedBox(height: Tok.s12),
        Reveal(delay: 1, child: Text('How are you\neating tonight?', style: T.display(40))),
        const SizedBox(height: Tok.s8),
        Reveal(
          delay: 2,
          child: Text(
            'Choose delivery or dining out to open a room and invite your group.',
            style: T.secondary(size: 15),
          ),
        ),
        const SizedBox(height: Tok.s24),
        Reveal(
          delay: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('YOUR NAME', style: T.tag(Tok.secondary)),
            const SizedBox(height: Tok.s8),
            TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: InputDecoration(
                hintText: 'Your name',
                errorText: _nameError,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: Tok.s16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Tok.radiusSm), borderSide: const BorderSide(color: Tok.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Tok.radiusSm), borderSide: const BorderSide(color: Tok.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Tok.radiusSm), borderSide: const BorderSide(color: Tok.careemGreen, width: 1.5)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: Tok.s24),
        Reveal(
          delay: 3,
          child: _ModePhotoCard(
            title: 'Food',
            badge: 'Delivery',
            subtitle: 'Swipe dishes and restaurants. We build and price one group basket.',
            photoUrl: _foodPhoto,
            icon: PhosphorIconsBold.bag,
            loading: _creating && _creatingMode == RoomMode.food,
            disabled: _creating,
            onTap: () => _pickMode(RoomMode.food),
          ),
        ),
        const SizedBox(height: Tok.s12),
        Reveal(
          delay: 4,
          child: _ModePhotoCard(
            title: 'Dine Out',
            badge: 'In person',
            subtitle: 'Agree on one spot to eat out together. No basket, just go there.',
            photoUrl: _dineOutPhoto,
            icon: PhosphorIconsBold.storefront,
            loading: _creating && _creatingMode == RoomMode.dineout,
            disabled: _creating,
            onTap: () => _pickMode(RoomMode.dineout),
          ),
        ),
      ]),
    );
  }
}

class _ModePhotoCard extends StatelessWidget {
  const _ModePhotoCard({
    required this.title,
    required this.badge,
    required this.subtitle,
    required this.photoUrl,
    required this.icon,
    required this.loading,
    required this.disabled,
    required this.onTap,
  });

  final String title, badge, subtitle, photoUrl;
  final IconData icon;
  final bool loading, disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !disabled,
      label: '$title, $badge. $subtitle',
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 146),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: loading ? Tok.careemMint : Tok.careemGreen.withValues(alpha: 0.25),
              width: loading ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Tok.careemDark.withValues(alpha: 0.14),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(children: [
            // Full-bleed real background photograph (pizza for Food, fancy restaurant table for Dine Out).
            Positioned.fill(
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Tok.careemDark, Tok.careemGreen, Tok.careemMid],
                    ),
                  ),
                ),
                loadingBuilder: (_, child, p) => p == null
                    ? child
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Tok.careemDark, Tok.careemGreen],
                          ),
                        ),
                      ),
              ),
            ),
            // Dimmed Careem deep-green gradient scrim so the photo shows warmly while white text pops cleanly.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF072017).withValues(alpha: 0.88),
                      const Color(0xFF0E3B2B).withValues(alpha: 0.72),
                      const Color(0xFF0A271E).withValues(alpha: 0.56),
                    ],
                  ),
                ),
              ),
            ),
            // Foreground content.
            Padding(
              padding: const EdgeInsets.all(Tok.s24),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Tok.careemMint,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        PhosphorIcon(icon, size: 12, color: Tok.careemDark),
                        const SizedBox(width: 5),
                        Text(
                          badge.toUpperCase(),
                          style: T.tag(Tok.careemDark).copyWith(fontSize: 10.5),
                        ),
                      ]),
                    ),
                    const SizedBox(height: Tok.s12),
                    Text(
                      title,
                      style: T.display(28).copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loading ? 'Creating room...' : subtitle,
                      style: T.body(size: 13.5, color: Colors.white.withValues(alpha: 0.88)).copyWith(height: 1.35),
                    ),
                  ]),
                ),
                const SizedBox(width: Tok.s12),
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const PhosphorIcon(PhosphorIconsBold.arrowRight, size: 18, color: Colors.white),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
