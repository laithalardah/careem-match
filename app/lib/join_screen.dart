import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';
import 'storage.dart';
import 'theme.dart';
import 'widgets.dart';

/// Step 3: Guest joins a room via `/#/join/{room_code}`.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.api, required this.roomCode});
  final Api api;
  final String roomCode;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  late final TextEditingController _nameCtrl = TextEditingController(
    text: SessionStore.getLastName() ?? '',
  );
  bool _joining = false;
  String? _nameError;
  String? _error;

  String get _code => widget.roomCode.toUpperCase();

  @override
  void initState() {
    super.initState();
    // If this tab already joined this room, jump straight into it.
    if (SessionStore.getParticipantId(_code) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/room/$_code');
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Enter your name to join.');
      return;
    }
    setState(() {
      _joining = true;
      _nameError = null;
      _error = null;
    });
    try {
      SessionStore.setLastName(name);
      final res = await widget.api.joinRoom(_code, name: name);
      SessionStore.setParticipantId(_code, res.participantId);
      if (!mounted) return;
      context.go('/room/$_code');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 404
            ? 'Room $_code was not found. Ask the host for a fresh link.'
            : e.message;
        _joining = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not join room $_code. Check your connection and try again.';
        _joining = false;
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
        subtitle: 'Room $_code',
        trailing: widget.api.isMock ? const Tag('Mock backend', colors: Tok.yellow) : null,
      ),
      footer: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_error != null) ...[
          ErrorBanner(message: _error!, onClose: () => setState(() => _error = null)),
          const SizedBox(height: Tok.s12),
        ],
        FilledButton(
          onPressed: _joining ? null : _submit,
          child: Text(_joining ? 'Joining...' : 'Join'),
        ),
      ]),
      child: CenteredScroll(children: [
        Reveal(child: Tag('Room $_code', colors: Tok.green)),
        const SizedBox(height: Tok.s16),
        Reveal(delay: 1, child: Text('Join your group.', style: T.display(42))),
        const SizedBox(height: Tok.s12),
        Reveal(
          delay: 2,
          child: Text(
            'Enter your name to join room $_code and swipe dishes together.',
            style: T.secondary(size: 16),
          ),
        ),
        const SizedBox(height: Tok.s24),
        Reveal(
          delay: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('YOUR NAME', style: T.tag(Tok.secondary)),
            const SizedBox(height: Tok.s8),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: InputDecoration(
                hintText: 'e.g. Layla',
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
      ]),
    );
  }
}
