import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recitro_store.dart';
import '../flows/student_create_flow.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'student_detail_screen.dart';

class StudentsTab extends StatelessWidget {
  const StudentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    final students = [...store.students]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final readyTotal =
        students.fold<int>(0, (n, s) => n + store.claimableRewardCount(s.id));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: PageTitle(
            title: 'Students',
            subtitle: students.isEmpty
                ? 'Your class list.'
                : [
                    '${students.length} ${students.length == 1 ? 'student' : 'students'}',
                    if (readyTotal > 0)
                      '$readyTotal ${readyTotal == 1 ? 'reward' : 'rewards'} ready',
                  ].join(' · '),
          ),
        ),
        if (students.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No students yet',
              message: 'Add the students in your class to start calling them.',
              action: FilledButton.icon(
                onPressed: () => showStudentCreateFlow(context),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add student'),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Space.page,
              Space.lg,
              Space.page,
              96,
            ),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: Column(
                  children: [
                    for (var i = 0; i < students.length; i++) ...[
                      if (i > 0) const Divider(indent: 68),
                      _StudentRow(student: students[i]),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

enum _Action { rename, delete }

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student});

  final Student student;

  Future<void> _onAction(BuildContext context, _Action action) async {
    final store = context.read<RecitroStore>();
    switch (action) {
      case _Action.rename:
        await showStudentCreateFlow(context, student: student);
      case _Action.delete:
        final ok = await confirmDialog(
          context,
          title: 'Delete ${student.name}?',
          message: 'Their points and reward history will be removed.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (ok) await store.deleteStudent(student.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    final text = Theme.of(context).textTheme;
    final total = store.totalPointsForStudent(student.id);
    final ready = store.claimableRewardCount(student.id);
    final rewards = store.ledgerForStudent(student.id).length;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StudentDetailScreen(studentId: student.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.xs, Space.md),
        child: Row(
          children: [
            StudentAvatar(name: student.name),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$total pts · $rewards ${rewards == 1 ? 'reward' : 'rewards'}',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            if (ready > 0)
              Pill(
                label: '$ready ready',
                color: AppColors.amberInk,
                icon: Icons.redeem_rounded,
              ),
            PopupMenuButton<_Action>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.muted),
              onSelected: (a) => _onAction(context, a),
              itemBuilder: (_) => const [
                PopupMenuItem(value: _Action.rename, child: Text('Rename')),
                PopupMenuItem(value: _Action.delete, child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
