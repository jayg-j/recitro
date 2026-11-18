import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recitro_store.dart';
import '../flows/session_form_screen.dart';
import '../flows/student_create_flow.dart';
import '../models/recitation_session.dart';
import '../theme/app_theme.dart';
import '../widgets/dates.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/ui.dart';
import 'session_detail_screen.dart';

class SessionsTab extends StatelessWidget {
  const SessionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    final sessions = store.sessions.reversed.toList(growable: false);

    if (sessions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ContentWidth(
            child: PageTitle(title: 'Sessions', trailing: SettingsButton()),
          ),
          Expanded(
            child: store.students.isEmpty
                ? EmptyState(
                    title: 'Add your class first',
                    message: 'Once your students are in, you can start a session and call them one at a time.',
                    action: FilledButton(
                      onPressed: () => showStudentCreateFlow(context),
                      child: const Text('Add students'),
                    ),
                  )
                : EmptyState(
                    title: 'No sessions yet',
                    message: 'Start one when you\'re ready to call students.',
                    action: FilledButton(
                      onPressed: () => openSessionForm(context),
                      child: const Text('New session'),
                    ),
                  ),
          ),
        ],
      );
    }

    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const PageTitle(title: 'Sessions', trailing: SettingsButton()),
          const SizedBox(height: Space.md),
          for (final session in sessions)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.page,
                0,
                Space.page,
                Space.md,
              ),
              child: _SessionCard(session: session),
            ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final RecitationSession session;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    final text = Theme.of(context).textTheme;
    final total = store.students.length;
    final called = store.calledCount(session);
    final priority = store.priorityWaitingCount(session);
    final date = sessionDateLabel(context, session.createdAt);

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
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      session.name,
                      style: text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (date != null) ...[
                    const SizedBox(width: Space.md),
                    Text(date, style: text.bodySmall),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Reward: ${session.rewardLabel}',
                style: text.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Space.lg),
              ProgressBar(value: called, max: total, height: 4),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      total > 0 && called >= total
                          ? 'Everyone called'
                          : '$called of $total called',
                      style: text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (priority > 0)
                    Text(
                      '$priority missed last time',
                      style: text.bodySmall?.copyWith(
                        color: context.palette.primary,
                        fontWeight: FontWeight.w600,
                      ),
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
