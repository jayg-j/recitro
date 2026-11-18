import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/name_list.dart';
import '../data/recitro_store.dart';
import '../models/course.dart';
import '../models/recitation_session.dart';
import '../screens/session_detail_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Opens the form to create a session (optionally for [courseId] and
/// [subject]), or edit [session] when given.
///
/// A new session is opened right away, or handed to [onCreated] when the
/// caller shows sessions itself (the tablet side-by-side layout).
Future<void> openSessionForm(
  BuildContext context, {
  RecitationSession? session,
  String? courseId,
  String? subject,
  ValueChanged<String>? onCreated,
}) async {
  final createdId = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SessionFormScreen(
        session: session,
        courseId: courseId,
        subject: subject,
      ),
    ),
  );
  if (createdId == null || !context.mounted) return;
  if (onCreated != null) {
    onCreated(createdId);
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SessionDetailScreen(sessionId: createdId),
    ),
  );
}

class SessionFormScreen extends StatefulWidget {
  const SessionFormScreen({
    super.key,
    this.session,
    this.courseId,
    this.subject,
  });

  final RecitationSession? session;
  final String? courseId;
  final String? subject;

  @override
  State<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends State<SessionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _course;
  late final TextEditingController _subject;
  late final TextEditingController _name;
  late final TextEditingController _reward;
  late final TextEditingController _points;
  late final TextEditingController _threshold;
  late bool _recallUnanswered;
  late bool _recallAnswered;
  String? _courseError;

  bool get _editing => widget.session != null;

  @override
  void initState() {
    super.initState();
    final store = context.read<RecitroStore>();
    final s = widget.session;
    final presetCourse = store.courseById(
          s?.courseId ?? widget.courseId ?? '',
        ) ??
        (store.courses.length == 1 ? store.courses.single : null);

    _course = TextEditingController(text: presetCourse?.name ?? '');
    _subject = TextEditingController(text: s?.subject ?? widget.subject ?? '');
    _name = TextEditingController(text: s?.name ?? '');
    _reward = TextEditingController(text: s?.rewardLabel ?? '');
    _points = TextEditingController(text: '${s?.pointsPerAnswer ?? 5}');
    _threshold =
        TextEditingController(text: '${s?.pointsRequiredForReward ?? 10}');
    _recallUnanswered = s?.allowRecallUnanswered ?? false;
    _recallAnswered = s?.allowRecallAnswered ?? false;

    _course.addListener(() => setState(() => _courseError = null));
    _subject.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _course.dispose();
    _subject.dispose();
    _name.dispose();
    _reward.dispose();
    _points.dispose();
    _threshold.dispose();
    super.dispose();
  }

  /// The existing course matching what's typed, if any.
  Course? _matchedCourse(RecitroStore store) {
    final key = nameKey(_course.text);
    if (key.isEmpty) return null;
    for (final c in store.courses) {
      if (nameKey(c.name) == key) return c;
    }
    return null;
  }

  String? _positive(String? v) {
    final n = int.tryParse(v ?? '');
    if (n == null || n < 1) return 'Enter a number of 1 or more';
    return null;
  }

  String _defaultName(String subject) {
    final date = MaterialLocalizations.of(context)
        .formatShortMonthDay(DateTime.now());
    return '${subject.isEmpty ? 'Session' : subject} · $date';
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    final courseOk = _editing || _course.text.trim().isNotEmpty;
    if (!courseOk) {
      setState(() => _courseError = 'Choose a course or type a new one');
    }
    if (!formOk || !courseOk) return;

    final store = context.read<RecitroStore>();
    final subject = _subject.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final name =
        _name.text.trim().isEmpty ? _defaultName(subject) : _name.text.trim();
    final points = int.parse(_points.text);
    final threshold = int.parse(_threshold.text);
    final reward = _reward.text.trim();

    if (_editing) {
      await store.updateSession(
        widget.session!.id,
        name: name,
        pointsPerAnswer: points,
        pointsRequiredForReward: threshold,
        rewardLabel: reward,
        allowRecallUnanswered: _recallUnanswered,
        allowRecallAnswered: _recallAnswered,
        subject: subject,
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // Reuse a course typed with different capitals; otherwise create it.
    final course = await store.courseNamed(_course.text);
    final created = await store.addSession(
      name: name,
      pointsPerAnswer: points,
      pointsRequiredForReward: threshold,
      rewardLabel: reward,
      allowRecallUnanswered: _recallUnanswered,
      allowRecallAnswered: _recallAnswered,
      courseId: course.id,
      subject: subject,
    );
    if (mounted) Navigator.of(context).pop(created.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final course = _editing
        ? store.courseById(widget.session!.courseId)
        : _matchedCourse(store);
    final newCourse = !_editing && course == null && _course.text.trim().isNotEmpty;
    final subject = _subject.text.trim();
    final newSubject = subject.isNotEmpty &&
        !(course?.subjects.any((s) => nameKey(s) == nameKey(subject)) ??
            false);
    final missed = _editing || course == null
        ? 0
        : store.studentsMissedInLatestSession(course.id, subject).length;
    final studentCount =
        course == null ? 0 : store.studentsInCourse(course.id).length;

    final String note;
    if (newCourse) {
      note = 'A new course "${_course.text.trim()}" will be created. '
          'Add its students from the Courses tab.';
    } else if (course != null && studentCount == 0 && !_editing) {
      note = '${course.name} has no students yet. Add them from the '
          'Courses tab.';
    } else if (missed > 0) {
      note = '$missed ${missed == 1 ? 'student' : 'students'} missed the last '
          '${subject.isEmpty ? '' : '$subject '}session and will be called '
          'first.';
    } else {
      note = 'Anyone not called this session goes first next time.';
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_editing ? 'Edit session' : 'New session'),
      ),
      bottomNavigationBar: BottomAction(
        child: FilledButton(
          key: const Key('createSession'),
          style: primaryActionStyle(),
          onPressed: _save,
          child: Text(_editing ? 'Save changes' : 'Create session'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.only(bottom: Space.xl),
            children: [
              const SectionHeader('Class'),
              _Group(
                children: [
                  if (_editing)
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Course',
                        enabled: false,
                      ),
                      child: Text(course?.name ?? '—', style: text.bodyLarge),
                    )
                  else
                    _Picker(
                      key: const Key('coursePicker'),
                      controller: _course,
                      label: 'Course',
                      hint: 'BSIT 2-A, Grade 7 – Rizal',
                      options: [for (final c in store.courses) c.name],
                      errorText: _courseError,
                      helper: newCourse ? 'New course' : null,
                    ),
                  const SizedBox(height: Space.md),
                  _Picker(
                    key: const Key('subjectPicker'),
                    controller: _subject,
                    label: 'Subject',
                    hint: 'Math, Science…',
                    options: course?.subjects ?? const [],
                    helper: newSubject && course != null
                        ? 'New subject for ${course.name}'
                        : null,
                  ),
                  const SizedBox(height: Space.md),
                  TextFormField(
                    key: const Key('sessionName'),
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Session name (optional)',
                      hintText: _defaultName(subject),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    note,
                    style: text.bodySmall?.copyWith(
                      color: missed > 0 || newCourse || studentCount == 0
                          ? p.ink
                          : p.muted,
                    ),
                  ),
                ],
              ),
              const SectionHeader('Reward'),
              _Group(
                children: [
                  TextFormField(
                    key: const Key('rewardName'),
                    controller: _reward,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'What students earn',
                      hintText: 'Sticker, homework pass, extra recess…',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Decide what students earn'
                        : null,
                  ),
                  const SizedBox(height: Space.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _points,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Points per answer',
                          ),
                          validator: _positive,
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: TextFormField(
                          controller: _threshold,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Points to earn it',
                          ),
                          validator: _positive,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    'You can give more or fewer points each time you score.',
                    style: text.bodySmall,
                  ),
                ],
              ),
              const SectionHeader('Calling'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.page),
                child: Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _recallUnanswered,
                        onChanged: (v) =>
                            setState(() => _recallUnanswered = v),
                        title: const Text('Call again if not answered'),
                      ),
                      const Divider(indent: Space.lg),
                      SwitchListTile(
                        value: _recallAnswered,
                        onChanged: (v) => setState(() => _recallAnswered = v),
                        title: const Text('Call again after answering'),
                        subtitle: const Text('Picked less often'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text field with suggestions: pick an existing value from the list, or
/// type a new one.
class _Picker extends StatelessWidget {
  const _Picker({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.options,
    this.errorText,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final List<String> options;
  final String? errorText;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => DropdownMenu<String>(
        controller: controller,
        width: constraints.maxWidth,
        // Same look as the other fields (the menu's default fill is tinted).
        inputDecorationTheme: Theme.of(context)
            .inputDecorationTheme
            .copyWith(fillColor: context.palette.surface),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(context.palette.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        label: Text(label),
        hintText: hint,
        helperText: helper,
        errorText: errorText,
        requestFocusOnTap: true,
        enableFilter: true,
        // Typing a name that isn't listed keeps the text (a new entry).
        menuHeight: 280,
        textInputAction: TextInputAction.next,
        dropdownMenuEntries: [
          for (final o in options) DropdownMenuEntry(value: o, label: o),
        ],
        onSelected: (v) {
          if (v != null) controller.text = v;
        },
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
