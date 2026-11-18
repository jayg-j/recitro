import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recitro_store.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';

/// Adds a student, or renames [student] when given. When adding, the teacher
/// can keep adding names without closing the dialog.
Future<void> showStudentCreateFlow(
  BuildContext context, {
  Student? student,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _StudentDialog(student: student),
  );
}

class _StudentDialog extends StatefulWidget {
  const _StudentDialog({this.student});

  final Student? student;

  @override
  State<_StudentDialog> createState() => _StudentDialogState();
}

class _StudentDialogState extends State<_StudentDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.student?.name ?? '');
  final _focus = FocusNode();
  final _formKey = GlobalKey<FormState>();
  int _added = 0;

  bool get _renaming => widget.student != null;

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<bool> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    final store = context.read<RecitroStore>();
    if (_renaming) {
      await store.updateStudent(widget.student!.id, _name.text);
    } else {
      await store.addStudent(_name.text);
      setState(() => _added++);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(_renaming ? 'Rename student' : 'Add student'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
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
                if (!await _submit() || !context.mounted) return;
                if (_renaming) {
                  Navigator.of(context).pop();
                } else {
                  _name.clear();
                  _focus.requestFocus();
                }
              },
            ),
            if (_added > 0) ...[
              const SizedBox(height: Space.sm),
              Text(
                '$_added added. Type another name or tap Done.',
                style: text.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_renaming) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (await _submit() && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_added > 0 ? 'Done' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (await _submit() && context.mounted) {
                _name.clear();
                _focus.requestFocus();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ],
    );
  }
}
