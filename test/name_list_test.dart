import 'package:flutter_test/flutter_test.dart';
import 'package:recitro/data/name_list.dart';

void main() {
  test('one name per line, trims and skips blanks', () {
    final r = parseNameList('  Ana Santos \n\n Ben   Cruz\n   \nCy Reyes');
    expect(r.names, ['Ana Santos', 'Ben Cruz', 'Cy Reyes']);
  });

  test('strips numbering and bullets', () {
    final r = parseNameList(
      '1. Ana Santos\n2) Ben Cruz\n3 Cy Reyes\n- Dee Lim\n• Eli Tan\n'
      '10.Gio Uy',
    );
    expect(r.names, [
      'Ana Santos',
      'Ben Cruz',
      'Cy Reyes',
      'Dee Lim',
      'Eli Tan',
      'Gio Uy',
    ]);
  });

  test('keeps initials', () {
    final r = parseNameList('J. Rizal\nA. Mabini');
    expect(r.names, ['J. Rizal', 'A. Mabini']);
  });

  test('keeps "Surname, First" as one student', () {
    final r = parseNameList('DELA CRUZ, JUAN\nSantos, Ana Marie');
    expect(r.names, ['DELA CRUZ, JUAN', 'Santos, Ana Marie']);
  });

  test('spreadsheet rows keep the name column', () {
    final r = parseNameList('No.\tName\tSection\n1\tAna Santos\t7-A\n'
        '2\tBen Cruz\t7-A');
    // The header row is skipped; real rows yield names.
    expect(r.names, ['Ana Santos', 'Ben Cruz']);
  });

  test('skips a heading line above a plain list', () {
    final r = parseNameList('Name of Learner\nAna Santos\nBen Cruz');
    expect(r.names, ['Ana Santos', 'Ben Cruz']);
  });

  test('skips repeats and students already in class', () {
    final r = parseNameList(
      'Ana Santos\nana  santos\nBen Cruz\nCy Reyes',
      existing: ['BEN CRUZ'],
    );
    expect(r.names, ['Ana Santos', 'Cy Reyes']);
    expect(r.alreadyInClass, 1);
  });

  test('ignores lines without letters', () {
    final r = parseNameList('12345\n---\nAna Santos\n2.');
    expect(r.names, ['Ana Santos']);
  });
}
