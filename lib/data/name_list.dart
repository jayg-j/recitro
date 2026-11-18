/// Result of reading a pasted class list.
class ParsedNames {
  const ParsedNames({required this.names, required this.alreadyInClass});

  /// New names to add, in the order they were pasted.
  final List<String> names;

  /// Names skipped because a student with that name already exists.
  final int alreadyInClass;
}

// Numbers ("1.", "2)", "3 ") and bullets. Letters are not treated as
// markers, so initials like "J. Rizal" are kept.
final _leadingMarker = RegExp(r'^\s*(?:\d+[.)\]:-]\s*|\d+\s+|[-*•·–—]\s*)');
final _spaces = RegExp(r'\s+');
final _hasLetter = RegExp(r'[^\W\d_]', unicode: true);

/// Column headings that show up when a list is copied from a spreadsheet.
const _headings = {
  'name',
  'names',
  'full name',
  'fullname',
  'student',
  'students',
  'student name',
  'name of student',
  'learner',
  'learners',
  'learner name',
  'name of learner',
  'section',
  'no.',
  'no',
};

/// Collapses whitespace and compares case-insensitively.
String nameKey(String name) =>
    name.trim().replaceAll(_spaces, ' ').toLowerCase();

/// Reads one name per line from pasted text.
///
/// - Strips list numbering and bullets ("1.", "2)", "3 ", "-", "•").
/// - For spreadsheet rows (tab-separated), keeps the longest cell that
///   contains letters, so "No. | Name | Section" yields the name.
/// - Commas are kept, so "Dela Cruz, Juan" stays one student.
/// - Skips blank lines, lines without letters, repeats within the paste,
///   and names already in [existing].
ParsedNames parseNameList(String text, {Iterable<String> existing = const []}) {
  final seen = {for (final e in existing) nameKey(e)};
  final names = <String>[];
  var alreadyInClass = 0;
  final pasted = <String>{};

  for (final rawLine in text.split(RegExp(r'\r?\n'))) {
    var line = rawLine;
    if (line.contains('\t')) {
      final cells = line
          .split('\t')
          .map((c) => c.trim())
          .where(_hasLetter.hasMatch)
          .where((c) => !_headings.contains(nameKey(c)))
          .toList();
      if (cells.isEmpty) continue;
      cells.sort((a, b) => b.length.compareTo(a.length));
      line = cells.first;
    }
    line = line.replaceFirst(_leadingMarker, '');
    line = line.trim().replaceAll(_spaces, ' ');
    if (line.isEmpty || !_hasLetter.hasMatch(line)) continue;

    final key = nameKey(line);
    if (_headings.contains(key)) continue;
    if (!pasted.add(key)) continue; // repeated in the paste
    if (seen.contains(key)) {
      alreadyInClass++;
      continue;
    }
    names.add(line);
  }
  return ParsedNames(names: names, alreadyInClass: alreadyInClass);
}
