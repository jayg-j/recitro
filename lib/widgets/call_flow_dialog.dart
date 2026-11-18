import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recitro_store.dart';
import '../models/call_outcome.dart';
import '../theme/app_theme.dart';
import 'pick_reveal.dart';
import 'reward_center_dialog.dart';

/// Runs one call for a student who is already marked as being called:
/// 1. Full-screen reveal for the class (with a name shuffle when
///    [shuffleFrom] has several names). The teacher lets them answer or
///    skips them for later.
/// 2. Teacher scores the answer (any number of points, or "didn't answer").
/// 3. Reward progress, and the reward can be handed out if unlocked.
Future<void> runCall({
  required BuildContext context,
  required String sessionId,
  required String studentId,
  List<String> shuffleFrom = const [],
}) async {
  final store = context.read<RecitroStore>();
  final session = store.sessionById(sessionId);
  final student = store.studentById(studentId);
  final state = session?.studentStates[studentId];
  if (session == null || student == null || state == null) return;

  final note = switch (state.outcomeBeforeCall) {
    CallOutcome.answered => 'Already answered this session',
    CallOutcome.notAnswered => 'Didn\'t answer earlier',
    _ => state.priority ? 'Missed last session' : null,
  };

  final choice = await showPickReveal(
    context,
    picked: student.name,
    shuffleFrom: shuffleFrom,
    note: note,
  );
  if (!context.mounted) return;

  if (choice == RevealChoice.skip) {
    await store.skipCall(session);
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ScoreDialog(sessionId: sessionId, studentId: studentId),
  );
}

enum _Step { score, reward }

class _ScoreDialog extends StatefulWidget {
  const _ScoreDialog({required this.sessionId, required this.studentId});

  final String sessionId;
  final String studentId;

  @override
  State<_ScoreDialog> createState() => _ScoreDialogState();
}

class _ScoreDialogState extends State<_ScoreDialog> {
  _Step _step = _Step.score;
  int? _points;
  late final TextEditingController _rewardLabel = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _rewardLabel.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    final session = store.sessionById(widget.sessionId);
    final student = store.studentById(widget.studentId);
    final state = session?.studentStates[widget.studentId];
    if (session == null || student == null || state == null) {
      return const SizedBox.shrink();
    }
    _points ??= session.pointsPerAnswer;

    final Widget content = switch (_step) {
      _Step.score => _ScoreStep(
          name: student.name,
          defaultPoints: session.pointsPerAnswer,
          points: _points!,
          onChanged: (v) => setState(() => _points = v),
          onSave: () => _run(() async {
            await store.markAnswered(session, points: _points);
            _rewardLabel.text = session.rewardLabel;
            if (mounted) setState(() => _step = _Step.reward);
          }),
          onNoAnswer: () => _run(() async {
            await store.markNotAnswered(session);
            if (context.mounted) Navigator.of(context).pop();
          }),
        ),
      _Step.reward => RewardPanel(
          studentName: student.name,
          rewardLabel: session.rewardLabel,
          earned: state.pointsEarned,
          required: session.pointsRequiredForReward,
          canClaim: store.canClaimReward(session, widget.studentId),
          claimed: false,
          labelController: _rewardLabel,
          closeLabel: 'Done',
          onGive: () => _run(() async {
            await store.claimReward(
              session,
              widget.studentId,
              rewardLabel: _rewardLabel.text,
            );
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Reward given to ${student.name}')),
              );
            }
          }),
          onClose: () => Navigator.of(context).pop(),
        ),
    };

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.xl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Space.xl,
            Space.xl,
            Space.xl,
            Space.lg,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(key: ValueKey(_step), child: content),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreStep extends StatelessWidget {
  const _ScoreStep({
    required this.name,
    required this.defaultPoints,
    required this.points,
    required this.onChanged,
    required this.onSave,
    required this.onNoAnswer,
  });

  final String name;
  final int defaultPoints;
  final int points;
  final ValueChanged<int> onChanged;
  final VoidCallback onSave;
  final VoidCallback onNoAnswer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final presets = <int>{
      0,
      if (defaultPoints > 1) (defaultPoints / 2).round(),
      defaultPoints,
      defaultPoints * 2,
    }.toList()
      ..sort();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          name,
          textAlign: TextAlign.center,
          style: text.titleLarge,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          'Points for this answer',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: context.palette.muted),
        ),
        const SizedBox(height: Space.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.outlined(
              tooltip: 'Less',
              onPressed: points > 0 ? () => onChanged(points - 1) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 96,
              child: Text(
                '$points',
                textAlign: TextAlign.center,
                style: text.displaySmall,
              ),
            ),
            IconButton.outlined(
              tooltip: 'More',
              onPressed: points < RecitroStore.maxPointsPerCall
                  ? () => onChanged(points + 1)
                  : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        SegmentedButton<int>(
          showSelectedIcon: false,
          emptySelectionAllowed: true,
          segments: [
            for (final v in presets)
              ButtonSegment(value: v, label: Text('$v')),
          ],
          selected: {if (presets.contains(points)) points},
          onSelectionChanged: (s) {
            if (s.isNotEmpty) onChanged(s.first);
          },
        ),
        const SizedBox(height: Space.xl),
        FilledButton(
          key: const Key('saveScore'),
          onPressed: onSave,
          child: Text(points == 1 ? 'Give 1 point' : 'Give $points points'),
        ),
        const SizedBox(height: Space.xs),
        TextButton(
          onPressed: onNoAnswer,
          style: TextButton.styleFrom(foregroundColor: context.palette.danger),
          child: const Text('Didn\'t answer'),
        ),
      ],
    );
  }
}
