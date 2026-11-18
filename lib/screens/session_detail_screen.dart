import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recitro_store.dart';
import '../flows/session_form_screen.dart';
import '../models/call_outcome.dart';
import '../models/recitation_session.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';
import '../widgets/call_flow_dialog.dart';
import '../widgets/reward_center_dialog.dart';
import '../widgets/ui.dart';
import 'student_detail_screen.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Resume a call that was in progress when the app closed.
      final pending =
          context.read<RecitroStore>().sessionById(widget.sessionId)
              ?.pendingStudentId;
      if (pending != null) _openCallFlow(pending);
    });
  }

  Future<void> _openCallFlow(String studentId) async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    await showCallFlowDialog(
      context: context,
      sessionId: widget.sessionId,
      studentId: studentId,
    );
    _dialogOpen = false;
  }

  Future<void> _callNext() async {
    final store = context.read<RecitroStore>();
    final session = store.sessionById(widget.sessionId);
    if (session == null) return;
    final id = await store.pickRandomStudent(session);
    if (id != null && mounted) await _openCallFlow(id);
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
      title: 'Delete session?',
      message:
          '"${session.name}" and its call history will be removed. Rewards '
          'already given stay on each student\'s record.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final store = context.read<RecitroStore>();
    Navigator.of(context).pop();
    await store.deleteSession(session.id);
  }

  void _showStudentActions(Student student) {
    final store = context.read<RecitroStore>();
    final session = store.sessionById(widget.sessionId);
    if (session == null) return;
    final state = session.studentStates[student.id];
    final canClaim = store.canClaimReward(session, student.id);
    final busy = session.pendingStudentId != null;
    final text = Theme.of(context).textTheme;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.page,
                  0,
                  Space.page,
                  Space.md,
                ),
                child: Row(
                  children: [
                    StudentAvatar(name: student.name, size: 44),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(student.name, style: text.titleMedium),
                          Text(
                            _statusLine(store, session, student.id),
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                enabled: !busy,
                leading: const Icon(Icons.record_voice_over_rounded),
                title: Text('Call ${student.name.split(' ').first} now'),
                subtitle: Text(
                  state?.outcome == CallOutcome.notCalled
                      ? 'Skip the random pick and call this student.'
                      : 'Call again in this session.',
                ),
                onTap: () {
                  Navigator.pop(sheet);
                  _callSpecific(student.id);
                },
              ),
              if (canClaim)
                ListTile(
                  leading: const Icon(
                    Icons.redeem_rounded,
                    color: AppColors.amberInk,
                  ),
                  title: const Text('Give reward'),
                  subtitle: Text(session.rewardLabel),
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
                leading: const Icon(Icons.person_rounded),
                title: const Text('View student'),
                onTap: () {
                  Navigator.pop(sheet);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StudentDetailScreen(studentId: student.id),
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

  static String _statusLine(
    RecitroStore store,
    RecitationSession session,
    String studentId,
  ) {
    final state = session.studentStates[studentId];
    if (state == null) return '';
    final pts = '${state.pointsEarned}/${session.pointsRequiredForReward} pts';
    return switch (state.outcome) {
      CallOutcome.notCalled => store.isPriority(session, studentId)
          ? 'Not called last session'
          : 'Waiting to be called',
      CallOutcome.pending => 'Being called now',
      CallOutcome.answered => state.rewardClaimed && state.pointsEarned == 0
          ? 'Answered · reward given'
          : 'Answered · $pts',
      CallOutcome.notAnswered => 'Didn\'t answer',
    };
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    final session = store.sessionById(widget.sessionId);
    final text = Theme.of(context).textTheme;

    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final students = store.students;
    final priority = <Student>[];
    final waiting = <Student>[];
    final called = <Student>[];
    for (final s in students) {
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
    final calledCount = store.calledCount(session);

    return Scaffold(
      appBar: AppBar(
        title: Text(session.name),
        actions: [
          IconButton(
            tooltip: 'Edit session',
            onPressed: () => openSessionForm(context, session: session),
            icon: const Icon(Icons.tune_rounded),
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
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  Space.page,
                  Space.md,
                  Space.page,
                  Space.md,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: FilledButton.icon(
                  onPressed: canCall ? _callNext : null,
                  icon: const Icon(Icons.casino_rounded),
                  label: Text(
                    canCall
                        ? (priority.isNotEmpty
                            ? 'Call next · priority first'
                            : 'Call next student')
                        : 'Everyone has been called',
                  ),
                ),
              ),
            ),
      body: students.isEmpty
          ? const EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No students yet',
              message: 'Add students from the Students tab to start calling.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: Space.xl),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.page,
                    Space.sm,
                    Space.page,
                    0,
                  ),
                  child: _SummaryCard(
                    session: session,
                    called: calledCount,
                    total: students.length,
                  ),
                ),
                if (priority.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.page,
                      Space.md,
                      Space.page,
                      0,
                    ),
                    child: NoticeCard(
                      icon: Icons.flag_rounded,
                      title: 'Priority students go first',
                      message: session.previousSessionName == null
                          ? 'These students weren\'t called in the previous session.'
                          : 'These students weren\'t called in "${session.previousSessionName}".',
                    ),
                  ),
                if (priority.isNotEmpty) ...[
                  SectionHeader('Priority', count: priority.length),
                  _StudentGroup(
                    students: priority,
                    session: session,
                    onTap: _showStudentActions,
                  ),
                ],
                if (waiting.isNotEmpty) ...[
                  SectionHeader('Waiting', count: waiting.length),
                  _StudentGroup(
                    students: waiting,
                    session: session,
                    onTap: _showStudentActions,
                  ),
                ],
                if (called.isNotEmpty) ...[
                  SectionHeader('Called', count: called.length),
                  _StudentGroup(
                    students: called,
                    session: session,
                    onTap: _showStudentActions,
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.page,
                    Space.lg,
                    Space.page,
                    0,
                  ),
                  child: Text(
                    'Tap a student to call them directly or give a reward.',
                    style: text.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.session,
    required this.called,
    required this.total,
  });

  final RecitationSession session;
  final int called;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rules = <String>[
      if (session.allowRecallUnanswered) 'Re-calls students who didn\'t answer',
      if (session.allowRecallAnswered) 'May re-call students who answered',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.military_tech_rounded,
                    color: AppColors.amberInk,
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('REWARD', style: text.labelSmall),
                      Text(
                        session.rewardLabel,
                        style: text.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            Row(
              children: [
                Expanded(
                  child: Stat(
                    label: 'pts per answer',
                    value: '${session.pointsPerAnswer}',
                  ),
                ),
                Expanded(
                  child: Stat(
                    label: 'pts to earn',
                    value: '${session.pointsRequiredForReward}',
                  ),
                ),
                Expanded(
                  child: Stat(label: 'called', value: '$called/$total'),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            PointsProgress(earned: called, required: total == 0 ? 1 : total),
            if (rules.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Text(rules.join(' · '), style: text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _StudentGroup extends StatelessWidget {
  const _StudentGroup({
    required this.students,
    required this.session,
    required this.onTap,
  });

  final List<Student> students;
  final RecitationSession session;
  final ValueChanged<Student> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.page),
      child: Card(
        child: Column(
          children: [
            for (var i = 0; i < students.length; i++) ...[
              if (i > 0) const Divider(indent: 68),
              _StudentRow(
                student: students[i],
                session: session,
                onTap: () => onTap(students[i]),
              ),
            ],
          ],
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
    final showProgress = outcome == CallOutcome.answered &&
        state != null &&
        !(state.rewardClaimed && state.pointsEarned == 0);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md,
        ),
        child: Row(
          children: [
            StudentAvatar(
              name: student.name,
              background: outcome == CallOutcome.pending
                  ? AppColors.amber
                  : null,
            ),
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
                  Row(
                    children: [
                      Icon(
                        outcomeIcon(outcome),
                        size: 14,
                        color: outcomeColor(outcome),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _SessionDetailScreenState._statusLine(
                            store,
                            session,
                            student.id,
                          ),
                          style: text.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (showProgress) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 140,
                      child: PointsProgress(
                        earned: state.pointsEarned,
                        required: session.pointsRequiredForReward,
                        height: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (canClaim)
              FilledButton.tonalIcon(
                onPressed: () => showRewardDialog(
                  context: context,
                  sessionId: session.id,
                  studentId: student.id,
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: Space.md),
                  backgroundColor: AppColors.amber.withValues(alpha: 0.25),
                  foregroundColor: AppColors.amberInk,
                ),
                icon: const Icon(Icons.redeem_rounded, size: 18),
                label: const Text('Reward'),
              )
            else if (store.isPriority(session, student.id))
              const PriorityPill(),
          ],
        ),
      ),
    );
  }
}
