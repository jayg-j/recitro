import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/name_list.dart';
import '../data/recitro_store.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';

/// Adds students one at a time or from a pasted list, or renames [student]
/// when given.
Future<void> showStudentCreateFlow(
  BuildContext context, {
  Student? student,
  bool paste = false,
  String? courseId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _StudentDialog(
      student: student,
      startWithPaste: paste,
      courseId: courseId,
    ),
  );
}

enum _Mode { single, paste }

class _StudentDialog extends StatefulWidget {
  const _StudentDialog({
    this.student,
    this.startWithPaste = false,
    this.courseId,
  });

  final Student? student;
  final bool startWithPaste;

  /// Course new students join (defaults to the first course).
  final String? courseId;

  @override
  State<_StudentDialog> createState() => _StudentDialogState();
}

class _StudentDialogState extends State<_StudentDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.student?.name ?? '');
  final _list = TextEditingController();
  final _focus = FocusNode();
  final _formKey = GlobalKey<FormState>();
  late _Mode _mode = widget.startWithPaste ? _Mode.paste : _Mode.single;
  int _added = 0;

  bool get _renaming => widget.student != null;

  @override
  void initState() {
    super.initState();
    _list.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _list.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<bool> _submitSingle() async {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    final store = context.read<RecitroStore>();
    if (_renaming) {
      await store.updateStudent(widget.student!.id, _name.text);
    } else {
      await store.addStudent(_name.text, courseId: widget.courseId);
      setState(() => _added++);
    }
    return true;
  }

  Future<void> _submitList(ParsedNames parsed) async {
    if (parsed.names.isEmpty) return;
    await context
        .read<RecitroStore>()
        .addStudents(parsed.names, courseId: widget.courseId);
    if (!mounted) return;
    final n = parsed.names.length;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Added $n ${n == 1 ? 'student' : 'students'}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final store = context.watch<RecitroStore>();
    final parsed = parseNameList(
      _list.text,
      existing: (widget.courseId == null
              ? store.students
              : store.studentsInCourse(widget.courseId!))
          .map((s) => s.name),
    );
    final paste = !_renaming && _mode == _Mode.paste;

    return AlertDialog(
      // Narrower outer margin than the default so the mode switch fits on
      // small phones; wide screens are capped by the content width below.
      insetPadding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.xl,
      ),
      title: Text(_renaming ? 'Rename student' : 'Add students'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_renaming) ...[
                  SegmentedButton<_Mode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _Mode.single,
                        label: Text('One by one'),
                      ),
                      ButtonSegment(
                        value: _Mode.paste,
                        label: Text('Paste a list'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.first),
                  ),
                  const SizedBox(height: Space.lg),
                ],
                if (paste)
                  ..._pasteFields(text, parsed)
                else
                  ..._singleFields(text),
              ],
            ),
          ),
        ),
      ),
      actions: paste ? _pasteActions(parsed) : _singleActions(),
    );
  }

  List<Widget> _singleFields(TextTheme text) => [
        Form(
          key: _formKey,
          child: TextFormField(
            key: const Key('studentName'),
            controller: _name,
            focusNode: _focus,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction:
                _renaming ? TextInputAction.done : TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter a name' : null,
            onFieldSubmitted: (_) async {
              if (!await _submitSingle() || !mounted) return;
              if (_renaming) {
                if (mounted) Navigator.of(context).pop();
              } else {
                _name.clear();
                _focus.requestFocus();
              }
            },
          ),
        ),
        if (_added > 0) ...[
          const SizedBox(height: Space.sm),
          Text(
            '$_added added. Type another name or tap Done.',
            style: text.bodySmall,
          ),
        ],
      ];

  List<Widget> _pasteFields(TextTheme text, ParsedNames parsed) {
    final n = parsed.names.length;
    final skipped = parsed.alreadyInClass;
    final String summary;
    if (_list.text.trim().isEmpty) {
      summary = 'One name per line. Numbers and bullets are removed.';
    } else if (n == 0) {
      summary = skipped > 0
          ? 'Everyone on this list is already in your class.'
          : 'No names found yet.';
    } else {
      summary = [
        '$n ${n == 1 ? 'new student' : 'new students'}',
        if (skipped > 0) '$skipped already in class',
      ].join(' · ');
    }

    return [
      TextField(
        key: const Key('nameList'),
        controller: _list,
        autofocus: true,
        minLines: 6,
        maxLines: 10,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'Andrea Santos\nBenjamin Cruz\nCarla Reyes',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: Space.sm),
      Text(summary, style: text.bodySmall),
    ];
  }

  List<Widget> _singleActions() {
    if (_renaming) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (await _submitSingle() && mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ];
    }
    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(_added > 0 ? 'Done' : 'Cancel'),
      ),
      FilledButton(
        onPressed: () async {
          if (await _submitSingle() && mounted) {
            _name.clear();
            _focus.requestFocus();
          }
        },
        child: const Text('Add'),
      ),
    ];
  }

  List<Widget> _pasteActions(ParsedNames parsed) {
    final n = parsed.names.length;
    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('addList'),
        onPressed: n == 0 ? null : () => _submitList(parsed),
        child: Text(n <= 1 ? 'Add' : 'Add $n'),
      ),
    ];
  }
}
