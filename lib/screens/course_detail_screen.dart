import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recitro_store.dart';
import '../flows/course_form.dart';
import '../flows/session_form_screen.dart';
import '../flows/student_create_flow.dart';
import '../models/course.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'student_detail_screen.dart';

/// One course: its subjects and its students.
class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _delete(Course course) async {
    final store = context.read<RecitroStore>();
    final students = store.studentsInCourse(course.id).length;
    final sessions = store.sessionsInCourse(course.id).length;
    final ok = await confirmDialog(
      context,
      title: 'Delete ${course.name}?',
      message: 'This removes its $students '
          '${students == 1 ? 'student' : 'students'} and $sessions '
          '${sessions == 1 ? 'session' : 'sessions'}. Rewards already given '
          'stay on record.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    Navigator.of(context).pop();
    await store.deleteCourse(course.id);
  }

  Future<void> _addSubject(Course course) async {
    final name = await showSubjectDialog(context);
    if (name == null || name.isEmpty || !mounted) return;
    await context.read<RecitroStore>().addSubject(course.id, name);
  }

  void _subjectActions(Course course, String subject) {
    final store = context.read<RecitroStore>();
    showModalBottomSheet<void>(
      context: context,
      constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.page,
                  0,
                  Space.page,
                  Space.sm,
                ),
                child: Text(
                  subject,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('Start a session'),
                onTap: () {
                  Navigator.pop(sheet);
                  openSessionForm(
                    context,
                    courseId: course.id,
                    subject: subject,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename'),
                onTap: () async {
                  Navigator.pop(sheet);
                  final name =
                      await showSubjectDialog(context, initial: subject);
                  if (name != null && name.isNotEmpty) {
                    await store.renameSubject(course.id, subject, name);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline_rounded),
                title: const Text('Remove from course'),
                subtitle: const Text('Past sessions keep their subject.'),
                onTap: () {
                  Navigator.pop(sheet);
                  store.removeSubject(course.id, subject);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    final course = store.courseById(widget.courseId);
    final text = Theme.of(context).textTheme;
    if (course == null) return const Scaffold(body: SizedBox.shrink());

    final all = [...store.studentsInCourse(course.id)]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final shown = all
        .where((s) => matchesQuery(_search.text, [s.name]))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(course.name),
        actions: [
          IconButton(
            tooltip: 'Rename course',
            onPressed: () => showCourseForm(context, course: course),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete course',
            onPressed: () => _delete(course),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: Space.xs),
        ],
      ),
      bottomNavigationBar: all.isEmpty
          ? null
          : BottomAction(
              child: FilledButton.icon(
                key: const Key('startSession'),
                style: primaryActionStyle(),
                onPressed: () => openSessionForm(context, courseId: course.id),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('Start a session'),
              ),
            ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.xl),
          children: [
            SectionHeader('Subjects', count: course.subjects.length),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.page),
              child: Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final s in course.subjects)
                    ActionChip(
                      label: Text(s),
                      onPressed: () => _subjectActions(course, s),
                    ),
                  ActionChip(
                    key: const Key('addSubject'),
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add subject'),
                    onPressed: () => _addSubject(course),
                  ),
                ],
              ),
            ),
            SectionHeader(
              'Students',
              count: all.length,
              caption: null,
            ),
            if (all.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No students in this course yet.',
                      style: text.bodyMedium?.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    Wrap(
                      spacing: Space.sm,
                      children: [
                        FilledButton(
                          key: const Key('addStudents'),
                          onPressed: () => showStudentCreateFlow(
                            context,
                            courseId: course.id,
                          ),
                          child: const Text('Add students'),
                        ),
                        OutlinedButton(
                          onPressed: () => showStudentCreateFlow(
                            context,
                            courseId: course.id,
                            paste: true,
                          ),
                          child: const Text('Paste a list'),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.page,
                  0,
                  Space.page,
                  Space.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SearchField(
                        controller: _search,
                        hint: 'Search students',
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    IconButton.filledTonal(
                      key: const Key('addStudents'),
                      tooltip: 'Add students',
                      onPressed: () => showStudentCreateFlow(
                        context,
                        courseId: course.id,
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                    ),
                  ],
                ),
              ),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.page),
                  child: Text(
                    'No students match "${_search.text.trim()}".',
                    style: text.bodyMedium?.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                )
              else
                GroupCard(
                  children: [for (final s in shown) _StudentRow(student: s)],
                ),
            ],
          ],
        ),
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
    final p = context.palette;
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
                          color: ready > 0 ? p.accentInk : p.muted,
                          fontWeight:
                              ready > 0 ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<_Action>(
                tooltip: 'More',
                icon: Icon(Icons.more_vert_rounded, color: p.muted, size: 20),
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
