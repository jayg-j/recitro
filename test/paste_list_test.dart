import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recitro/data/recitro_store.dart';
import 'package:recitro/main.dart';

void main() {
  Future<void> openStudents(WidgetTester tester, RecitroStore store) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RecitroApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Students').last);
    await tester.pumpAndSettle();
  }

  testWidgets('paste a list from the empty Students page', (tester) async {
    final store = RecitroStore(persist: false);
    await openStudents(tester, store);

    await tester.tap(find.text('Paste a list'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('nameList')),
      '1. Andrea Santos\n2. Benjamin Cruz\n\n3. Carla Reyes\n',
    );
    await tester.pumpAndSettle();
    expect(find.text('3 new students'), findsOneWidget);

    await tester.tap(find.byKey(const Key('addList')));
    await tester.pumpAndSettle();
    expect(store.students.map((s) => s.name),
        ['Andrea Santos', 'Benjamin Cruz', 'Carla Reyes']);
    expect(find.text('Added 3 students'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skips students already in class', (tester) async {
    final store = RecitroStore(persist: false);
    await store.addStudent('Andrea Santos');
    await openStudents(tester, store);

    await tester.tap(find.byKey(const Key('addStudentFab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste a list'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('nameList')),
      'andrea santos\nBenjamin Cruz',
    );
    await tester.pumpAndSettle();
    expect(find.text('1 new student · 1 already in class'), findsOneWidget);

    await tester.tap(find.byKey(const Key('addList')));
    await tester.pumpAndSettle();
    expect(store.students.length, 2);
  });

  testWidgets('add is disabled until there is a name', (tester) async {
    final store = RecitroStore(persist: false);
    await openStudents(tester, store);
    await tester.tap(find.text('Paste a list'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('addList')),
    );
    expect(button.onPressed, isNull);
  });
}
