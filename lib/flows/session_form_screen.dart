import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/recitro_store.dart';
import '../models/recitation_session.dart';
import '../screens/session_detail_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Opens the form to create a session, or edit [session] when given.
/// A newly created session is opened right away.
Future<void> openSessionForm(
  BuildContext context, {
  RecitationSession? session,
}) async {
  final createdId = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SessionFormScreen(session: session),
    ),
  );
  if (createdId != null && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionDetailScreen(sessionId: createdId),
      ),
    );
  }
}

class SessionFormScreen extends StatefulWidget {
  const SessionFormScreen({super.key, this.session});

  final RecitationSession? session;

  @override
  State<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends State<SessionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _reward;
  late final TextEditingController _points;
  late final TextEditingController _threshold;
  late bool _recallUnanswered;
  late bool _recallAnswered;

  bool get _editing => widget.session != null;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _name = TextEditingController(text: s?.name ?? '');
    _reward = TextEditingController(text: s?.rewardLabel ?? '');
    _points = TextEditingController(text: '${s?.pointsPerAnswer ?? 5}');
    _threshold =
        TextEditingController(text: '${s?.pointsRequiredForReward ?? 10}');
    _recallUnanswered = s?.allowRecallUnanswered ?? false;
    _recallAnswered = s?.allowRecallAnswered ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _reward.dispose();
    _points.dispose();
    _threshold.dispose();
    super.dispose();
  }

  String? _positive(String? v) {
    final n = int.tryParse(v ?? '');
    if (n == null || n < 1) return 'Enter a number of 1 or more';
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final store = context.read<RecitroStore>();
    final reward = _reward.text.trim();
    final args = (
      name: _name.text.trim(),
      points: int.parse(_points.text),
      threshold: int.parse(_threshold.text),
      reward: reward,
    );

    if (_editing) {
      await store.updateSession(
        widget.session!.id,
        name: args.name,
        pointsPerAnswer: args.points,
        pointsRequiredForReward: args.threshold,
        rewardLabel: args.reward,
        allowRecallUnanswered: _recallUnanswered,
        allowRecallAnswered: _recallAnswered,
      );
      if (mounted) Navigator.of(context).pop();
    } else {
      final created = await store.addSession(
        name: args.name,
        pointsPerAnswer: args.points,
        pointsRequiredForReward: args.threshold,
        rewardLabel: args.reward,
        allowRecallUnanswered: _recallUnanswered,
        allowRecallAnswered: _recallAnswered,
      );
      if (mounted) Navigator.of(context).pop(created.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    final text = Theme.of(context).textTheme;
    final missed = _editing ? 0 : store.studentsMissedInLatestSession().length;


    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_editing ? 'Edit session' : 'New session'),
      ),
      bottomNavigationBar: BottomAction(
        child: FilledButton(
          style: primaryActionStyle(),
          onPressed: _save,
          child: Text(_editing ? 'Save changes' : 'Create session'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.only(bottom: Space.xl),
            children: [
              const SectionHeader('Details'),
              _Group(
                children: [
                  TextFormField(
                    controller: _name,
                    autofocus: !_editing,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Session name',
                      hintText: 'Science — Week 3',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Give the session a name'
                        : null,
                  ),
                  const SizedBox(height: Space.md),
                  TextFormField(
                    controller: _reward,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Reward',
                      hintText: 'Sticker, homework pass, extra recess…',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Decide what students earn'
                        : null,
                  ),
                ],
              ),
              const SectionHeader('Points'),
              _Group(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _points,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Per answer',
                          ),
                          validator: _positive,
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: TextFormField(
                          controller: _threshold,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'To earn reward',
                          ),
                          validator: _positive,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    'You can give more or fewer points each time you score.',
                    style: text.bodySmall,
                  ),
                ],
              ),
              const SectionHeader('Calling'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.page),
                child: Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _recallUnanswered,
                        onChanged: (v) =>
                            setState(() => _recallUnanswered = v),
                        title: const Text('Call again if not answered'),
                      ),
                      const Divider(indent: Space.lg),
                      SwitchListTile(
                        value: _recallAnswered,
                        onChanged: (v) => setState(() => _recallAnswered = v),
                        title: const Text('Call again after answering'),
                        subtitle: const Text('Picked less often'),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.page,
                  Space.md,
                  Space.page,
                  0,
                ),
                child: Text(
                  missed > 0
                      ? '$missed ${missed == 1 ? 'student' : 'students'} '
                          'missed last session and will be called first.'
                      : 'Anyone not called this session goes first next time.',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
