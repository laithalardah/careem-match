import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'models.dart';
import 'room_controller.dart';
import 'theme.dart';
import 'widgets.dart';

/// Step 2 & 3: Invite / Lobby screen (host invites & advances; guests wait).
class LobbyView extends StatefulWidget {
  const LobbyView({super.key, required this.ctrl});
  final RoomController ctrl;

  @override
  State<LobbyView> createState() => _LobbyViewState();
}

class _LobbyViewState extends State<LobbyView> {
  bool _copied = false;

  Future<void> _copyLink({String? toast}) async {
    await Clipboard.setData(ClipboardData(text: widget.ctrl.joinUrl));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text(toast ?? 'Join link copied to clipboard.'),
      ));
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _openDemoFriendsSheet() {
    var count = 2;
    var scenario = 'consensus';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Tok.canvas,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Tok.radius))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Tok.s24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Add demo friends', style: T.display(28)),
              const SizedBox(height: Tok.s8),
              Text('Demo friends join this room and swipe automatically.', style: T.secondary(size: 14)),
              const SizedBox(height: Tok.s24),
              Text('HOW MANY', style: T.tag(Tok.secondary)),
              const SizedBox(height: Tok.s8),
              Row(children: [
                for (final n in [1, 2, 3, 4]) ...[
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: count == n,
                      label: '$n demo ${n == 1 ? 'friend' : 'friends'}',
                      child: InkWell(
                        onTap: () => setSheetState(() => count = n),
                        borderRadius: BorderRadius.circular(Tok.radiusSm),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: count == n ? Tok.ink : Tok.card,
                            borderRadius: BorderRadius.circular(Tok.radiusSm),
                            border: Border.all(color: count == n ? Tok.ink : Tok.border),
                          ),
                          child: Text('$n', style: T.mono(size: 14, color: count == n ? Colors.white : Tok.ink)),
                        ),
                      ),
                    ),
                  ),
                  if (n < 4) const SizedBox(width: Tok.s8),
                ],
              ]),
              const SizedBox(height: Tok.s24),
              Text('SCENARIO', style: T.tag(Tok.secondary)),
              const SizedBox(height: Tok.s8),
              Row(children: [
                for (final entry in const [
                  ('consensus', 'Agree'),
                  ('dispute', 'Disagree'),
                  ('random', 'Random'),
                ]) ...[
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: scenario == entry.$1,
                      label: 'Scenario ${entry.$2}',
                      child: InkWell(
                        onTap: () => setSheetState(() => scenario = entry.$1),
                        borderRadius: BorderRadius.circular(Tok.radiusSm),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scenario == entry.$1 ? Tok.ink : Tok.card,
                            borderRadius: BorderRadius.circular(Tok.radiusSm),
                            border: Border.all(color: scenario == entry.$1 ? Tok.ink : Tok.border),
                          ),
                          child: Text(
                            entry.$2,
                            style: T.body(size: 14, weight: FontWeight.w600, color: scenario == entry.$1 ? Colors.white : Tok.ink),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (entry.$1 != 'random') const SizedBox(width: Tok.s8),
                ],
              ]),
              const SizedBox(height: Tok.s24),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  widget.ctrl.addDemoFriends(count: count, scenario: scenario);
                },
                child: Text('Add $count demo ${count == 1 ? 'friend' : 'friends'}'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.ctrl.room!;
    final isHost = widget.ctrl.isHost;
    final canAdvance = room.participants.length >= 2 && !widget.ctrl.busy;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(children: [
          Row(children: [
            Tag(room.mode == RoomMode.dineout ? 'Dine Out' : 'Food delivery', colors: room.mode == RoomMode.dineout ? Tok.blue : Tok.green),
            const SizedBox(width: Tok.s8),
            Text('Room ${room.roomCode}', style: T.mono(size: 12, color: Tok.ink)),
          ]),
          const SizedBox(height: Tok.s16),
          Text(isHost ? 'Invite your group.' : 'You\'re in the room.', style: T.display(38)),
          const SizedBox(height: Tok.s8),
          Text(
            isHost
                ? 'Share the link or scan the code. Next unlocks once at least 2 people join.'
                : 'Waiting for the host to move to meal settings.',
            style: T.secondary(size: 15),
          ),
          const SizedBox(height: Tok.s24),
          if (isHost) ...[
            Panel(
              padding: const EdgeInsets.all(Tok.s16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(
                  child: Semantics(
                    label: 'QR code to join room ${room.roomCode}',
                    child: Container(
                      padding: const EdgeInsets.all(Tok.s12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(Tok.radiusSm),
                        border: Border.all(color: Tok.border),
                      ),
                      child: QrImageView(
                        data: widget.ctrl.joinUrl,
                        version: QrVersions.auto,
                        size: 156,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Tok.ink),
                        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Tok.ink),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Tok.s16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Tok.s12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Tok.wash,
                    borderRadius: BorderRadius.circular(Tok.radiusSm),
                    border: Border.all(color: Tok.border),
                  ),
                  child: SelectableText(
                    widget.ctrl.joinUrl,
                    style: T.mono(size: 12, color: Tok.ink),
                  ),
                ),
                const SizedBox(height: Tok.s12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyLink,
                      icon: PhosphorIcon(_copied ? PhosphorIconsBold.check : PhosphorIconsBold.copy, size: 17),
                      label: Text(_copied ? 'Copied' : 'Copy'),
                    ),
                  ),
                  const SizedBox(width: Tok.s8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyLink(toast: 'Link ready to share — paste it into WhatsApp or chat.'),
                      icon: const PhosphorIcon(PhosphorIconsBold.shareNetwork, size: 17),
                      label: const Text('Share'),
                    ),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: Tok.s16),
          ],
          Panel(
            padding: const EdgeInsets.all(Tok.s16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Tok.s8,
                runSpacing: 4,
                children: [
                  Text('PARTICIPANTS (${room.participants.length})', style: T.tag(Tok.secondary)),
                  if (isHost && widget.ctrl.health.demo)
                    Semantics(
                      button: true,
                      label: 'Add demo friends',
                      child: InkWell(
                        onTap: widget.ctrl.busy ? null : _openDemoFriendsSheet,
                        borderRadius: BorderRadius.circular(Tok.radiusSm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Tok.s8, vertical: 6),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const PhosphorIcon(PhosphorIconsBold.userPlus, size: 14, color: Tok.ink),
                            const SizedBox(width: 4),
                            Text('Add demo friends', style: T.body(size: 13, weight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Tok.s12),
              for (var i = 0; i < room.participants.length; i++) ...[
                if (i > 0) const Divider(height: Tok.s16),
                _ParticipantRow(
                  participant: room.participants[i],
                  isMe: room.participants[i].id == widget.ctrl.participantId,
                ),
              ],
            ]),
          ),
          const SizedBox(height: Tok.s16),
        ]),
      ),
      const SizedBox(height: Tok.s12),
      if (isHost)
        FilledButton(
          onPressed: canAdvance ? widget.ctrl.nextToSettings : null,
          child: Text(room.participants.length < 2 ? 'Waiting for 1 more person' : 'Next'),
        )
      else
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: Tok.s16, vertical: 14),
          color: Tok.wash,
          child: Row(children: [
            const PhosphorIcon(PhosphorIconsBold.hourglassMedium, size: 18, color: Tok.secondary),
            const SizedBox(width: Tok.s12),
            Expanded(child: Text('Waiting for the host', style: T.body(size: 15, weight: FontWeight.w500))),
          ]),
        ),
    ]);
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.participant, required this.isMe});
  final Participant participant;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      ParticipantAvatar(id: participant.id, name: participant.name, isHost: participant.isHost),
      const SizedBox(width: Tok.s12),
      Expanded(
        child: Row(children: [
          Flexible(
            child: Text(
              isMe ? '${participant.name} (you)' : participant.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.body(size: 15, weight: FontWeight.w600),
            ),
          ),
          if (participant.isBot) ...[
            const SizedBox(width: Tok.s8),
            const Tag('Demo', colors: Tok.yellow),
          ],
        ]),
      ),
      if (participant.isHost) const Tag('Host', colors: Tok.blue),
    ]);
  }
}

/// Step 4: Meal settings (host picks with large chips, guests watch live).
class SettingsView extends StatelessWidget {
  const SettingsView({super.key, required this.ctrl});
  final RoomController ctrl;

  static IconData _mealIcon(MealType meal) => switch (meal) {
        MealType.breakfast => PhosphorIconsBold.coffee,
        MealType.lunch => PhosphorIconsBold.sun,
        MealType.dinner => PhosphorIconsBold.moonStars,
        MealType.dessert => PhosphorIconsBold.cookie,
      };

  @override
  Widget build(BuildContext context) {
    final room = ctrl.room!;
    final isHost = ctrl.isHost;
    final selected = room.settings.meal ?? MealType.dinner;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: CenteredScroll(children: [
          const Tag('Settings', colors: Tok.blue),
          const SizedBox(height: Tok.s16),
          Text('What meal is this?', style: T.display(40)),
          const SizedBox(height: Tok.s8),
          Text(
            isHost
                ? 'Choose the meal so the deck matches the time of day.'
                : 'The host is picking the meal. Your screen updates live.',
            style: T.secondary(size: 16),
          ),
          const SizedBox(height: Tok.s24),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: Tok.s12,
            crossAxisSpacing: Tok.s12,
            childAspectRatio: 1.45,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final meal in MealType.values)
                Semantics(
                  button: isHost,
                  selected: selected == meal,
                  label: '${meal.label}${selected == meal ? ', selected' : ''}',
                  child: InkWell(
                    onTap: isHost && !ctrl.busy ? () => ctrl.setMeal(meal) : null,
                    borderRadius: BorderRadius.circular(Tok.radius),
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(Tok.s16),
                      decoration: BoxDecoration(
                        color: selected == meal ? Tok.ink : Tok.card,
                        borderRadius: BorderRadius.circular(Tok.radius),
                        border: Border.all(color: selected == meal ? Tok.ink : Tok.border, width: selected == meal ? 1.5 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          PhosphorIcon(_mealIcon(meal), size: 22, color: selected == meal ? Colors.white : Tok.ink),
                          Text(
                            meal.label,
                            style: T.body(
                              size: 16,
                              weight: FontWeight.w600,
                              color: selected == meal ? Colors.white : Tok.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Tok.s24),
          Wrap(
            spacing: Tok.s12,
            runSpacing: Tok.s8,
            children: [
              for (final p in room.participants)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  ParticipantAvatar(id: p.id, name: p.name, isHost: p.isHost, size: 30),
                  const SizedBox(width: 6),
                  Text(p.id == ctrl.participantId ? '${p.name} (you)' : p.name, style: T.secondary(size: 13)),
                ]),
            ],
          ),
        ]),
      ),
      const SizedBox(height: Tok.s12),
      if (isHost)
        FilledButton(
          onPressed: ctrl.busy ? null : ctrl.startSwiping,
          child: Text(ctrl.busy ? 'Starting...' : 'Start'),
        )
      else
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: Tok.s16, vertical: 14),
          color: Tok.wash,
          child: Row(children: [
            const PhosphorIcon(PhosphorIconsBold.hourglassMedium, size: 18, color: Tok.secondary),
            const SizedBox(width: Tok.s12),
            Expanded(child: Text('Waiting for the host to start', style: T.body(size: 15, weight: FontWeight.w500))),
          ]),
        ),
    ]);
  }
}
