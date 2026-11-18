import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recitro_store.dart';
import '../flows/session_form_screen.dart';
import '../flows/student_create_flow.dart';
import '../models/recitation_session.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'session_detail_screen.dart';

class SessionsTab extends StatelessWidget {
  const SessionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    // Newest first.
    final sessions = store.sessions.reversed.toList(growable: false);
    final missed = store.studentsMissedInLatestSession().length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: PageTitle(
            title: 'Sessions',
            subtitle: sessions.isEmpty
                ? 'Run a recitation and call students one by one.'
                : '${sessions.length} ${sessions.length == 1 ? 'session' : 'sessions'} · newest first',
          ),
        ),
        if (sessions.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.auto_stories_rounded,
              title: 'No sessions yet',
              message: store.students.isEmpty
                  ? 'Add your students first, then start a session.'
                  : 'Start a session to begin calling students.',
              action: store.students.isEmpty
                  ? FilledButton.icon(
                      onPressed: () => showStudentCreateFlow(context),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Add students'),
                    )
                  : FilledButton.icon(
                      onPressed: () => openSessionForm(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New session'),
                    ),
            ),
          )
        else ...[
          if (missed > 0)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Space.page,
                Space.md,
                Space.page,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: NoticeCard(
                  icon: Icons.flag_rounded,
                  title: '$missed ${missed == 1 ? 'student hasn\'t' : 'students haven\'t'} been called yet',
                  message:
                      'In "${sessions.first.name}". If you start a new session, they will be called first.',
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Space.page,
              Space.lg,
              Space.page,
              96,
            ),
            sliver: SliverList.separated(
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.md),
              itemBuilder: (context, index) => _SessionCard(
                session: sessions[index],
                isLatest: index == 0,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.isLatest});

  final RecitationSession session;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    final text = Theme.of(context).textTheme;
    final total = store.students.length;
    final called = store.calledCount(session);
    final priority = store.priorityWaitingCount(session);
    final done = total > 0 && called >= total;

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SessionDetailScreen(sessionId: session.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.name,
                      style: text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isLatest) ...[
                    const SizedBox(width: Space.sm),
                    const Pill(label: 'Latest', color: AppColors.teal),
                  ],
                  const SizedBox(width: Space.xs),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: Space.xs),
              Text(
                '${session.rewardLabel} · ${session.pointsPerAnswer} pts per answer · ${session.pointsRequiredForReward} to earn',
                style: text.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Space.md),
              PointsProgress(earned: called, required: total == 0 ? 1 : total),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      done ? 'Everyone called' : '$called of $total called',
                      style:
                          text.labelMedium?.copyWith(color: AppColors.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (priority > 0)
                    Pill(
                      label: '$priority priority',
                      color: AppColors.navy,
                      icon: Icons.flag_rounded,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
