import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'api.dart';
import 'models.dart';
import 'storage.dart';
import 'theme.dart';
import 'widgets.dart';

/// Step 1: Choose mode ("Food" delivery or "Dine Out") and create a room.
class ModeScreen extends StatefulWidget {
  const ModeScreen({super.key, required this.api});
  final Api api;

  @override
  State<ModeScreen> createState() => _ModeScreenState();
}

class _ModeScreenState extends State<ModeScreen> {
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
                    color: Tok.ink,
                  ),
                  const SizedBox(width: Tok.s8),
                  Expanded(child: Text('Force dispute (demo toggle)', style: T.secondary(size: 13))),
                ]),
              ),
            ),
          ),
        Center(child: Text('Amman, Jordan', style: T.secondary(size: 13))),
      ]),
      child: CenteredScroll(children: [
        Reveal(
          child: Row(children: [
            IconButton(
              tooltip: 'Back to Careem',
              onPressed: () => context.go('/'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const PhosphorIcon(PhosphorIconsBold.caretLeft, size: 20),
            ),
            const PhosphorIcon(PhosphorIconsFill.forkKnife, size: 18),
            const SizedBox(width: Tok.s8),
            Flexible(
              child: Text('Careem Match', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(size: 14, weight: FontWeight.w600)),
            ),
            if (widget.api.isMock) ...[
              const SizedBox(width: Tok.s8),
              const Tag('Mock backend', colors: Tok.yellow),
            ],
          ]),
        ),
        const SizedBox(height: Tok.s32),
        Reveal(delay: 1, child: Text('How are you\neating tonight?', style: T.display(44))),
        const SizedBox(height: Tok.s12),
        Reveal(
          delay: 2,
          child: Text(
            'Pick a mode to start a room and invite your group. Everyone swipes together.',
            style: T.secondary(size: 16),
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
                fillColor: Tok.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: Tok.s16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Tok.radiusSm), borderSide: const BorderSide(color: Tok.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Tok.radiusSm), borderSide: const BorderSide(color: Tok.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Tok.radiusSm), borderSide: const BorderSide(color: Tok.ink)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: Tok.s24),
        Reveal(
          delay: 3,
          child: _ModeCard(
            title: 'Food',
            tag: 'Delivery',
            tagColors: Tok.green,
            subtitle: 'Swipe dishes and restaurants. We build and price one group basket.',
            icon: PhosphorIconsBold.bag,
            loading: _creating && _creatingMode == RoomMode.food,
            disabled: _creating,
            onTap: () => _pickMode(RoomMode.food),
          ),
        ),
        const SizedBox(height: Tok.s12),
        Reveal(
          delay: 4,
          child: _ModeCard(
            title: 'Dine Out',
            tag: 'In person',
            tagColors: Tok.blue,
            subtitle: 'Agree on one spot to eat out together. No basket, just go there.',
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

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.tag,
    required this.tagColors,
    required this.subtitle,
    required this.icon,
    required this.loading,
    required this.disabled,
    required this.onTap,
  });

  final String title, tag, subtitle;
  final (Color, Color) tagColors;
  final IconData icon;
  final bool loading, disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !disabled,
      label: '$title, $tag. $subtitle',
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(Tok.radius),
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(Tok.s24),
          decoration: BoxDecoration(
            color: Tok.card,
            borderRadius: BorderRadius.circular(Tok.radius),
            border: Border.all(color: loading ? Tok.ink : Tok.border, width: loading ? 1.5 : 1),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tagColors.$1,
                borderRadius: BorderRadius.circular(Tok.radiusSm),
              ),
              child: PhosphorIcon(icon, size: 22, color: tagColors.$2),
            ),
            const SizedBox(width: Tok.s16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(
                  spacing: Tok.s8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(title, style: T.display(26)),
                    Tag(tag, colors: tagColors),
                  ],
                ),
                const SizedBox(height: 6),
                Text(loading ? 'Creating room...' : subtitle, style: T.secondary(size: 14)),
              ]),
            ),
            const SizedBox(width: Tok.s8),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: PhosphorIcon(PhosphorIconsBold.arrowRight, size: 18, color: Tok.ink),
            ),
          ]),
        ),
      ),
    );
  }
}
