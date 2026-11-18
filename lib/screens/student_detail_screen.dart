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
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.xxl),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.page),
            child: Row(
              children: [
                StudentAvatar(name: student.name, size: 64),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Text(student.name, style: text.headlineSmall),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.page),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Stat(label: 'points earned', value: '$total'),
                    ),
                    Expanded(
                      child: Stat(
                        label: 'rewards received',
                        value: '${history.length}',
                      ),
                    ),
                    Expanded(
                      child: Stat(
                        label: 'in progress',
                        value: '${inProgress.length}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (inProgress.isNotEmpty) ...[
            SectionHeader('Rewards in progress', count: inProgress.length),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.page),
              child: Card(
                child: Column(
                  children: [
                    for (var i = 0; i < inProgress.length; i++) ...[
                      if (i > 0) const Divider(),
                      _ProgressRow(
                        session: inProgress[i],
                        studentId: studentId,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          SectionHeader('Reward history', count: history.length),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.page),
              child: Text(
                'No rewards yet. Rewards appear here once you give them.',
                style: text.bodySmall,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.page),
              child: Card(
                child: Column(
                  children: [
                    for (var i = 0; i < history.length; i++) ...[
                      if (i > 0) const Divider(indent: 56),
                      ListTile(
                        leading: const Icon(
                          Icons.military_tech_rounded,
                          color: AppColors.amberInk,
                        ),
                        title: Text(history[i].rewardLabel),
                        subtitle: Text(
                          '${history[i].sessionName} · ${_date(history[i].earnedAt)}',
                        ),
                        trailing: Text(
                          '+${history[i].points}',
                          style: text.titleMedium?.copyWith(
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _date(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
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
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.rewardLabel, style: text.titleSmall),
                    Text(session.name, style: text.bodySmall),
                  ],
                ),
              ),
              if (canClaim)
                FilledButton.icon(
                  onPressed: () => showRewardDialog(
                    context: context,
                    sessionId: session.id,
                    studentId: studentId,
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.navy,
                  ),
                  icon: const Icon(Icons.redeem_rounded, size: 18),
                  label: const Text('Give'),
                )
              else
                Text(
                  '${state.pointsEarned}/${session.pointsRequiredForReward} pts',
                  style: text.labelMedium?.copyWith(color: AppColors.muted),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          PointsProgress(
            earned: state.pointsEarned,
            required: session.pointsRequiredForReward,
          ),
        ],
      ),
    );
  }
}
