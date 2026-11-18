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

    if (students.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ContentWidth(child: PageTitle(title: 'Students')),
          Expanded(
            child: EmptyState(
              title: 'No students yet',
              message: 'Add the students in your class to start calling them.',
              action: FilledButton(
                onPressed: () => showStudentCreateFlow(context),
                child: const Text('Add students'),
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
          PageTitle(
            title: 'Students',
            subtitle: '${students.length} in class',
          ),
          const SizedBox(height: Space.md),
          GroupCard(
            children: [for (final s in students) _StudentRow(student: s)],
          ),
        ],
      ),
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
          title: 'Remove ${student.name}?',
          message: 'Their points and reward history will be deleted.',
          confirmLabel: 'Remove',
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

    final String? subtitle = ready > 0
        ? (ready == 1 ? 'Reward ready' : '$ready rewards ready')
        : total > 0
            ? '$total pts earned'
            : null;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StudentDetailScreen(studentId: student.id),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 8, Space.xs, 8),
          child: Row(
            children: [
              StudentAvatar(name: student.name, size: 36),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      student.name,
                      style: text.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color:
                              ready > 0 ? context.palette.accentInk : context.palette.muted,
                          fontWeight:
                              ready > 0 ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<_Action>(
                tooltip: 'More',
                icon: Icon(Icons.more_vert_rounded,
                    color: context.palette.muted, size: 20),
                onSelected: (a) => _onAction(context, a),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: _Action.rename, child: Text('Rename')),
                  PopupMenuItem(value: _Action.delete, child: Text('Remove')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
