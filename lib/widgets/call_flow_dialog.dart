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
          note: switch (state.outcomeBeforeCall) {
            CallOutcome.answered => 'Already answered this session',
            CallOutcome.notAnswered => 'Didn\'t answer earlier',
            _ => state.priority ? 'Missed last session' : null,
          },
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

class _CalledStep extends StatelessWidget {
  const _CalledStep({
    required this.name,
    required this.note,
    required this.onAnswer,
    required this.onSkip,
  });

  final String name;
  final String? note;
  final VoidCallback onAnswer;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: StudentAvatar(name: name, size: 64, highlighted: true)),
        const SizedBox(height: Space.lg),
        Text(name, textAlign: TextAlign.center, style: text.headlineSmall),
        const SizedBox(height: Space.xs),
        Text(
          note ?? 'Your turn to answer',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: Space.xl),
        FilledButton(
          key: const Key('letAnswer'),
          onPressed: onAnswer,
          child: const Text('Let them answer'),
        ),
        const SizedBox(height: Space.xs),
        TextButton(onPressed: onSkip, child: const Text('Skip for now')),
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
          style: text.bodyMedium?.copyWith(color: AppColors.muted),
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
          style: TextButton.styleFrom(foregroundColor: AppColors.red),
          child: const Text('Didn\'t answer'),
        ),
      ],
    );
  }
}
