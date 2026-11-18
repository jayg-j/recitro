import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recitro_store.dart';
import '../models/call_outcome.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// Shows a student's reward progress for one session. When the reward is
/// unlocked, the teacher can confirm (or change) what they give and hand it
/// out.
Future<void> showRewardDialog({
  required BuildContext context,
  required String sessionId,
  required String studentId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _RewardDialog(sessionId: sessionId, studentId: studentId),
  );
}

class _RewardDialog extends StatefulWidget {
  const _RewardDialog({required this.sessionId, required this.studentId});

  final String sessionId;
  final String studentId;

  @override
  State<_RewardDialog> createState() => _RewardDialogState();
}

class _RewardDialogState extends State<_RewardDialog> {
  TextEditingController? _label;

  @override
  void dispose() {
    _label?.dispose();
    super.dispose();
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
    _label ??= TextEditingController(text: session.rewardLabel);

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
          child: RewardPanel(
            studentName: student.name,
            rewardLabel: session.rewardLabel,
            earned: state.pointsEarned,
            required: session.pointsRequiredForReward,
            canClaim: store.canClaimReward(session, widget.studentId),
            claimed:
                state.rewardClaimed && state.outcome == CallOutcome.answered,
            labelController: _label!,
            onGive: () async {
              await store.claimReward(
                session,
                widget.studentId,
                rewardLabel: _label!.text,
              );
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Reward given to ${student.name}')),
                );
              }
            },
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}

/// Reward progress + hand-out controls. Used in the reward dialog and as the
/// last step of the call flow.
class RewardPanel extends StatelessWidget {
  const RewardPanel({
    super.key,
    required this.studentName,
    required this.rewardLabel,
    required this.earned,
    required this.required,
    required this.canClaim,
    required this.claimed,
    required this.labelController,
    required this.onGive,
    required this.onClose,
    this.closeLabel = 'Close',
  });

  final String studentName;
  final String rewardLabel;
  final int earned;
  final int required;
  final bool canClaim;
  final bool claimed;
  final TextEditingController labelController;
  final Future<void> Function() onGive;
  final VoidCallback onClose;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final remaining = (required - earned).clamp(0, required);

    final String message;
    if (claimed) {
      message = 'Reward already given.';
    } else if (canClaim) {
      message = 'Earned $rewardLabel.';
    } else {
      message =
          '$remaining more ${remaining == 1 ? 'point' : 'points'} to earn $rewardLabel.';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(studentName, style: text.titleLarge),
        const SizedBox(height: Space.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$earned', style: text.displaySmall),
            const SizedBox(width: 6),
            Text(
              '/ $required pts',
              style: text.titleMedium?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        ProgressBar(value: earned, max: required),
        const SizedBox(height: Space.sm),
        Text(message, style: text.bodyMedium?.copyWith(
          color: AppColors.muted,
        )),
        if (canClaim) ...[
          const SizedBox(height: Space.xl),
          TextField(
            controller: labelController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Reward to give'),
          ),
          const SizedBox(height: Space.lg),
          FilledButton(
            key: const Key('giveReward'),
            onPressed: onGive,
            child: const Text('Give reward'),
          ),
          const SizedBox(height: Space.xs),
          TextButton(
            key: const Key('rewardClose'),
            onPressed: onClose,
            child: const Text('Later'),
          ),
        ] else ...[
          const SizedBox(height: Space.xl),
          FilledButton(
            key: const Key('rewardClose'),
            onPressed: onClose,
            child: Text(closeLabel),
          ),
        ],
      ],
    );
  }
}
