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
      insetPadding: const EdgeInsets.all(Space.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          child: RewardPanel(
            studentName: student.name,
            sessionName: session.name,
            rewardLabel: session.rewardLabel,
            earned: state.pointsEarned,
            required: session.pointsRequiredForReward,
            canClaim: store.canClaimReward(session, widget.studentId),
            claimed: state.rewardClaimed &&
                state.outcome == CallOutcome.answered,
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
                  SnackBar(
                    content: Text('Reward given to ${student.name}'),
                  ),
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
    required this.sessionName,
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
  final String sessionName;
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (canClaim ? AppColors.amber : AppColors.navy)
                    .withValues(alpha: canClaim ? 1 : 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                canClaim ? Icons.redeem_rounded : Icons.military_tech_rounded,
                color: canClaim ? AppColors.navy : AppColors.navy,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(studentName, style: text.titleLarge),
                  Text(sessionName, style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$earned', style: text.displaySmall),
            Padding(
              padding: const EdgeInsets.only(left: Space.xs, bottom: 6),
              child: Text('/ $required pts', style: text.titleMedium?.copyWith(
                color: AppColors.muted,
              )),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        PointsProgress(earned: earned, required: required, height: 8),
        const SizedBox(height: Space.sm),
        Text(
          claimed
              ? 'Reward already given for these points.'
              : canClaim
                  ? 'Reward unlocked.'
                  : '$remaining more ${remaining == 1 ? 'point' : 'points'} to earn "$rewardLabel".',
          style: text.bodySmall,
        ),
        if (canClaim) ...[
          const SizedBox(height: Space.xl),
          TextField(
            controller: labelController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Reward to give',
              helperText: 'Change it if you are giving something different.',
            ),
          ),
          const SizedBox(height: Space.lg),
          FilledButton.icon(
            onPressed: onGive,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.navy,
            ),
            icon: const Icon(Icons.redeem_rounded),
            label: const Text('Give reward'),
          ),
          const SizedBox(height: Space.sm),
          TextButton(onPressed: onClose, child: const Text('Later')),
        ] else ...[
          const SizedBox(height: Space.xl),
          FilledButton(onPressed: onClose, child: Text(closeLabel)),
        ],
      ],
    );
  }
}
