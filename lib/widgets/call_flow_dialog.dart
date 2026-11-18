import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recitro_store.dart';
import '../models/call_outcome.dart';
import '../theme/app_theme.dart';
import 'reward_center_dialog.dart';
import 'ui.dart';

/// The teacher's flow for one called student:
/// 1. Decide whether the student answers now (or skip them for later).
/// 2. Score the answer (any number of points, or "didn't answer").
/// 3. See reward progress and hand out the reward if unlocked.
Future<void> showCallFlowDialog({
  required BuildContext context,
  required String sessionId,
  required String studentId,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CallFlowDialog(sessionId: sessionId, studentId: studentId),
  );
}

enum _Step { called, score, reward }

class _CallFlowDialog extends StatefulWidget {
  const _CallFlowDialog({required this.sessionId, required this.studentId});

  final String sessionId;
  final String studentId;

  @override
  State<_CallFlowDialog> createState() => _CallFlowDialogState();
}

class _CallFlowDialogState extends State<_CallFlowDialog> {
  _Step _step = _Step.called;
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
      _Step.called => _CalledStep(
          name: student.name,
          priority: state.priority &&
              (state.outcomeBeforeCall ?? CallOutcome.notCalled) ==
                  CallOutcome.notCalled,
          previousOutcome: state.outcomeBeforeCall,
          onAnswer: () => setState(() => _step = _Step.score),
          onSkip: () => _run(() async {
            await store.skipCall(session);
            if (context.mounted) Navigator.of(context).pop();
          }),
        ),
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
          sessionName: session.name,
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
      insetPadding: const EdgeInsets.all(Space.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(key: ValueKey(_step), child: content),
          ),
        ),
      ),
    );
  }
}

class _CalledStep extends StatelessWidget {
  const _CalledStep({
    required this.name,
    required this.priority,
    required this.previousOutcome,
    required this.onAnswer,
    required this.onSkip,
  });

  final String name;
  final bool priority;
  final CallOutcome? previousOutcome;
  final VoidCallback onAnswer;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final note = switch (previousOutcome) {
      CallOutcome.answered => 'Called again — already answered this session.',
      CallOutcome.notAnswered => 'Called again — didn\'t answer earlier.',
      _ => priority
          ? 'Wasn\'t called last session, so they go first.'
          : null,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'NOW CALLING',
          textAlign: TextAlign.center,
          style: text.labelSmall,
        ),
        const SizedBox(height: Space.lg),
        Center(
          child: StudentAvatar(
            name: name,
            size: 88,
            background: AppColors.amber,
            foreground: AppColors.navy,
          ),
        ),
        const SizedBox(height: Space.lg),
        Text(name, textAlign: TextAlign.center, style: text.headlineSmall),
        if (priority) ...[
          const SizedBox(height: Space.sm),
          const Center(child: PriorityPill()),
        ],
        if (note != null) ...[
          const SizedBox(height: Space.sm),
          Text(note, textAlign: TextAlign.center, style: text.bodySmall),
        ],
        const SizedBox(height: Space.xl),
        FilledButton.icon(
          onPressed: onAnswer,
          icon: const Icon(Icons.record_voice_over_rounded),
          label: const Text('Let them answer'),
        ),
        const SizedBox(height: Space.sm),
        OutlinedButton(
          onPressed: onSkip,
          child: const Text('Skip for now'),
        ),
        const SizedBox(height: Space.sm),
        Text(
          'Skipped students stay in the queue. If they aren\'t called this '
          'session, they get priority next session.',
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
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

    String presetLabel(int v) {
      if (v == 0) return 'No points';
      if (v == defaultPoints) return 'Full · $v';
      if (v < defaultPoints) return 'Partial · $v';
      return 'Bonus · $v';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('SCORE', textAlign: TextAlign.center, style: text.labelSmall),
        const SizedBox(height: Space.sm),
        Text(
          'How did $name do?',
          textAlign: TextAlign.center,
          style: text.titleLarge,
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
              width: 120,
              child: Column(
                children: [
                  Text(
                    '$points',
                    textAlign: TextAlign.center,
                    style: text.displaySmall,
                  ),
                  Text(
                    points == 1 ? 'point' : 'points',
                    style: text.bodySmall,
                  ),
                ],
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
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final v in presets)
              ChoiceChip(
                label: Text(presetLabel(v)),
                selected: points == v,
                onSelected: (_) => onChanged(v),
              ),
          ],
        ),
        const SizedBox(height: Space.xl),
        FilledButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.check_rounded),
          label: Text('Give $points ${points == 1 ? 'point' : 'points'}'),
        ),
        const SizedBox(height: Space.sm),
        OutlinedButton(
          onPressed: onNoAnswer,
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
          child: const Text('Didn\'t answer'),
        ),
      ],
    );
  }
}
