import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recitro_store.dart';
import '../flows/session_form_screen.dart';
import '../flows/student_create_flow.dart';
import '../models/call_outcome.dart';
import '../models/recitation_session.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';
import '../widgets/call_flow_dialog.dart';
import '../widgets/reward_center_dialog.dart';
import '../widgets/ui.dart';
import 'student_detail_screen.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.sessionId,
    this.embedded = false,
    this.onClosed,
  });

  final String sessionId;

  /// Shown inside the tablet side-by-side layout rather than as its own
  /// page: no back button, and deleting calls [onClosed] instead of popping.
  final bool embedded;
  final VoidCallback? onClosed;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool _dialogOpen = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Resume a call that was in progress when the app closed.
      final pending = context
          .read<RecitroStore>()
          .sessionById(widget.sessionId)
          ?.pendingStudentId;
      if (pending != null) _openCallFlow(pending);
    });
  }

  Future<void> _openCallFlow(
    String studentId, {
    List<String> shuffleFrom = const [],
  }) async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    await runCall(
      context: context,
      sessionId: widget.sessionId,
      studentId: studentId,
      shuffleFrom: shuffleFrom,
    );
    _dialogOpen = false;
  }

  /// Picks a student at random and shows the pick landing on them.
  Future<void> _pickRandom() async {
    final store = context.read<RecitroStore>();
    final session = store.sessionById(widget.sessionId);
    if (session == null) return;
    final candidates =
        store.pickPool(session).keys.map((s) => s.name).toList();
    final id = await store.pickRandomStudent(session);
    if (id != null && mounted) {
      await _openCallFlow(id, shuffleFrom: candidates);
    }
  }

  Future<void> _callSpecific(String studentId) async {
    final store = context.read<RecitroStore>();
    final session = store.sessionById(widget.sessionId);
    if (session == null) return;
    if (await store.callStudent(session, studentId) && mounted) {
      await _openCallFlow(studentId);
    }
  }

  Future<void> _delete(RecitationSession session) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this session?',
      message: 'Rewards already given stay on each student\'s record.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final store = context.read<RecitroStore>();
    if (widget.embedded) {
      widget.onClosed?.call();
    } else {
      Navigator.of(context).pop();
    }
    await store.deleteSession(session.id);
  }

  void _showStudentActions(Student student) {
    final store = context.read<RecitroStore>();
    final session = store.sessionById(widget.sessionId);
    if (session == null) return;
    final canClaim = store.canClaimReward(session, student.id);
    final busy = session.pendingStudentId != null;
    final text = Theme.of(context).textTheme;

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
                child: Text(student.name, style: text.titleMedium),
              ),
              ListTile(
                enabled: !busy,
                leading: const Icon(Icons.record_voice_over_outlined),
                title: const Text('Call now'),
                onTap: () {
                  Navigator.pop(sheet);
                  _callSpecific(student.id);
                },
              ),
              if (canClaim)
                ListTile(
                  leading: const Icon(Icons.redeem_outlined),
                  title: const Text('Give reward'),
                  onTap: () {
                    Navigator.pop(sheet);
                    showRewardDialog(
                      context: context,
                      sessionId: session.id,
                      studentId: student.id,
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('View profile'),
                onTap: () {
                  Navigator.pop(sheet);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          StudentDetailScreen(studentId: student.id),
                    ),
                  );
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
    final session = store.sessionById(widget.sessionId);

    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final students = store.studentsFor(session);
    final course = store.courseById(session.courseId);
    final query = _search.text;
    final priority = <Student>[];
    final waiting = <Student>[];
    final called = <Student>[];
    for (final s in students) {
      if (!matchesQuery(query, [s.name])) continue;
      final outcome =
          session.studentStates[s.id]?.outcome ?? CallOutcome.notCalled;
      if (outcome == CallOutcome.notCalled ||
          outcome == CallOutcome.pending) {
        (store.isPriority(session, s.id) ? priority : waiting).add(s);
      } else {
        called.add(s);
      }
    }

    final canCall = store.hasCallableStudents(session);

    final noMatches =
        priority.isEmpty && waiting.isEmpty && called.isEmpty;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(session.name),
        actions: [
          IconButton(
            tooltip: 'Edit session',
            onPressed: () => openSessionForm(context, session: session),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete session',
            onPressed: () => _delete(session),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: Space.xs),
        ],
      ),
      bottomNavigationBar: students.isEmpty
          ? null
          : BottomAction(
              child: FilledButton.icon(
                key: const Key('callNext'),
                style: primaryActionStyle(),
                onPressed: canCall ? _pickRandom : null,
                icon: const Icon(Icons.shuffle_rounded, size: 20),
                label: Text(
                  canCall || session.pendingStudentId != null
                      ? 'Pick a random student'
                      : 'Everyone\'s been called',
                ),
              ),
            ),
      body: students.isEmpty
          ? EmptyState(
              title: 'No students yet',
              message: 'Add the students in ${course?.name ?? 'this course'} '
                  'to start calling.',
              action: FilledButton(
                onPressed: () => showStudentCreateFlow(
                  context,
                  courseId: session.courseId,
                ),
                child: const Text('Add students'),
              ),
            )
          : ContentWidth(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Space.xl),
                children: [
                  _Summary(
                    session: session,
                    courseName: course?.name,
                    called: store.calledCount(session),
                    total: students.length,
                  ),
                  if (students.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.page,
                        Space.md,
                        Space.page,
                        0,
                      ),
                      child: SearchField(
                        key: const Key('studentSearch'),
                        controller: _search,
                        hint: 'Search students',
                      ),
                    ),
                  if (noMatches)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.page,
                        Space.xl,
                        Space.page,
                        0,
                      ),
                      child: Text(
                        'No students match "${query.trim()}".',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.palette.muted,
                            ),
                      ),
                    ),
                  if (priority.isNotEmpty) ...[
                    SectionHeader(
                      'Priority',
                      count: priority.length,
                      caption: 'Called first',
                    ),
                    _rows(priority, session),
                  ],
                  if (waiting.isNotEmpty) ...[
                    SectionHeader('Waiting', count: waiting.length),
                    _rows(waiting, session),
                  ],
                  if (called.isNotEmpty) ...[
                    SectionHeader('Called', count: called.length),
                    _rows(called, session),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _rows(List<Student> list, RecitationSession session) => GroupCard(
        children: [
          for (final s in list)
            _StudentRow(
              student: s,
              session: session,
              onTap: () => _showStudentActions(s),
            ),
        ],
      );
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.session,
    required this.courseName,
    required this.called,
    required this.total,
  });

  final RecitationSession session;
  final String? courseName;
  final int called;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final where = [
      if (courseName != null) courseName!,
      if (session.subject.isNotEmpty) session.subject,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.sm, Space.page, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (where.isNotEmpty) ...[
                Text(where, style: text.titleSmall),
                const SizedBox(height: Space.md),
              ],
              Text('Reward', style: text.bodySmall),
              Text(session.rewardLabel, style: text.titleMedium),
              const SizedBox(height: Space.lg),
              Row(
                children: [
                  Expanded(
                    child: Stat(
                      label: 'Per answer',
                      value: '${session.pointsPerAnswer}',
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Stat(
                      label: 'To earn',
                      value: '${session.pointsRequiredForReward}',
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Stat(label: 'Called', value: '$called/$total'),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              ProgressBar(value: called, max: total, height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.session,
    required this.onTap,
  });

  final Student student;
  final RecitationSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    final text = Theme.of(context).textTheme;
    final state = session.studentStates[student.id];
    final outcome = state?.outcome ?? CallOutcome.notCalled;
    final canClaim = store.canClaimReward(session, student.id);

    final String? status = switch (outcome) {
      CallOutcome.pending => 'Being called',
      CallOutcome.notAnswered => 'Didn\'t answer',
      CallOutcome.answered => state!.rewardClaimed && state.pointsEarned == 0
          ? 'Reward given'
          : '${state.pointsEarned} of ${session.pointsRequiredForReward} pts',
      CallOutcome.notCalled => null,
    };
    final statusColor =
        outcome == CallOutcome.notAnswered ? context.palette.danger : context.palette.muted;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: 10,
          ),
          child: Row(
            children: [
              StudentAvatar(
                name: student.name,
                size: 36,
                highlighted: outcome == CallOutcome.pending,
              ),
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
                    if (status != null)
                      Text(
                        status,
                        style: text.bodySmall?.copyWith(color: statusColor),
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
                    studentId: student.id,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: context.palette.accentInk,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Give reward'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
