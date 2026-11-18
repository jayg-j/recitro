import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recitro_store.dart';
import '../models/call_outcome.dart';
import '../models/recitation_session.dart';
import '../theme/app_theme.dart';
import '../widgets/reward_center_dialog.dart';
import '../widgets/ui.dart';

class StudentDetailScreen extends StatelessWidget {
  const StudentDetailScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    final student = store.studentById(studentId);
    final text = Theme.of(context).textTheme;

    if (student == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final total = store.totalPointsForStudent(studentId);
    final history = store.ledgerForStudent(studentId);

    final inProgress = <RecitationSession>[];
    for (final session in store.sessions.reversed) {
      final state = session.studentStates[studentId];
      if (state != null &&
          state.outcome == CallOutcome.answered &&
          !state.rewardClaimed &&
          state.pointsEarned > 0) {
        inProgress.add(session);
      }
    }

    return Scaffold(
      appBar: AppBar(),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.xxl),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.page),
              child: Row(
                children: [
                  StudentAvatar(name: student.name, size: 56),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name, style: text.headlineSmall),
                        if (history.isNotEmpty)
                          Text(
                            '$total pts earned · ${history.length} '
                            '${history.length == 1 ? 'reward' : 'rewards'}',
                            style: text.bodyMedium?.copyWith(
                              color: context.palette.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (inProgress.isNotEmpty) ...[
              const SectionHeader('In progress'),
              GroupCard(
                indent: Space.lg,
                children: [
                  for (final s in inProgress)
                    _ProgressRow(session: s, studentId: studentId),
                ],
              ),
            ],
            const SectionHeader('Rewards received'),
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.page),
                child: Text('None yet.', style: text.bodyMedium?.copyWith(
                  color: context.palette.muted,
                )),
              )
            else
              GroupCard(
                indent: Space.lg,
                children: [
                  for (final e in history)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.lg,
                        vertical: Space.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.rewardLabel, style: text.bodyLarge),
                                Text(
                                  '${e.sessionName} · ${_date(e.earnedAt)}',
                                  style: text.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: Space.md),
                          Text(
                            '+${e.points}',
                            style: text.titleSmall?.copyWith(
                              color: context.palette.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.session, required this.studentId});

  final RecitationSession session;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    final text = Theme.of(context).textTheme;
    final state = session.studentStates[studentId]!;
    final canClaim = store.canClaimReward(session, studentId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.sm,
        Space.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.rewardLabel, style: text.bodyLarge),
                    Text(
                      session.name,
                      style: text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (canClaim)
                TextButton(
                  onPressed: () => showRewardDialog(
                    context: context,
                    sessionId: session.id,
                    studentId: studentId,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: context.palette.accentInk,
                  ),
                  child: const Text('Give reward'),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: Space.sm),
                  child: Text(
                    '${state.pointsEarned}/${session.pointsRequiredForReward}',
                    style: text.bodySmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Padding(
            padding: const EdgeInsets.only(right: Space.sm),
            child: ProgressBar(
              value: state.pointsEarned,
              max: session.pointsRequiredForReward,
              height: 4,
            ),
          ),
        ],
      ),
    );
  }
}
