import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recitro_store.dart';
import '../models/course.dart';
import '../theme/app_theme.dart';

/// Creates a course (name + optional subjects), or renames [course].
/// Returns the created or edited course id.
Future<String?> showCourseForm(BuildContext context, {Course? course}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CourseDialog(course: course),
  );
}

class _CourseDialog extends StatefulWidget {
  const _CourseDialog({this.course});

  final Course? course;

  @override
  State<_CourseDialog> createState() => _CourseDialogState();
}

class _CourseDialogState extends State<_CourseDialog> {
  late final _name = TextEditingController(text: widget.course?.name ?? '');
  final _subjects = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool get _editing => widget.course != null;

  @override
  void dispose() {
    _name.dispose();
    _subjects.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final store = context.read<RecitroStore>();
    if (_editing) {
      await store.renameCourse(widget.course!.id, _name.text);
      if (mounted) Navigator.of(context).pop(widget.course!.id);
      return;
    }
    final subjects = _subjects.text.split(RegExp(r'[,\n]'));
    final course = await store.addCourse(_name.text, subjects: subjects);
    if (mounted) Navigator.of(context).pop(course.id);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.xl,
      ),
      title: Text(_editing ? 'Rename course' : 'New course'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SizedBox(
          width: double.maxFinite,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('courseName'),
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Course or section',
                    hintText: 'BSIT 2-A, Grade 7 – Rizal',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name the course' : null,
                ),
                if (!_editing) ...[
                  const SizedBox(height: Space.md),
                  TextFormField(
                    key: const Key('courseSubjects'),
                    controller: _subjects,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Subjects (optional)',
                      hintText: 'Math, Science, English',
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    'Separate subjects with commas. You can add more later.',
                    style: text.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('saveCourse'),
          onPressed: _save,
          child: Text(_editing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

/// Simple one-field dialog for adding or renaming a subject.
Future<String?> showSubjectDialog(
  BuildContext context, {
  String? initial,
}) {
  final controller = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(initial == null ? 'Add subject' : 'Rename subject'),
      content: TextField(
        key: const Key('subjectName'),
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Subject'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: Text(initial == null ? 'Add' : 'Save'),
        ),
      ],
    ),
  );
}
