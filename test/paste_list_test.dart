import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recitro/data/recitro_store.dart';
import 'package:recitro/main.dart';

void main() {
  /// Opens Courses → the course page.
  Future<void> openCourse(
    WidgetTester tester,
    RecitroStore store,
    String course,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RecitroApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Courses').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(course));
    await tester.pumpAndSettle();
  }

  testWidgets('paste a list into an empty course', (tester) async {
    final store = RecitroStore(persist: false);
    final course = await store.addCourse('BSIT 2-A');
    await openCourse(tester, store, 'BSIT 2-A');

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
    expect(store.studentsInCourse(course.id).map((s) => s.name),
        ['Andrea Santos', 'Benjamin Cruz', 'Carla Reyes']);
    expect(find.text('Added 3 students'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skips students already in the course only', (tester) async {
    final store = RecitroStore(persist: false);
    final a = await store.addCourse('A');
    final b = await store.addCourse('B');
    await store.addStudent('Andrea Santos', courseId: a.id);
    await store.addStudent('Benjamin Cruz', courseId: b.id);
    await openCourse(tester, store, 'A');

    await tester.tap(find.byKey(const Key('addStudents')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste a list'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('nameList')),
      'andrea santos\nBenjamin Cruz',
    );
    await tester.pumpAndSettle();
    // Benjamin is in course B, so he's new for course A.
    expect(find.text('1 new student · 1 already in class'), findsOneWidget);

    await tester.tap(find.byKey(const Key('addList')));
    await tester.pumpAndSettle();
    expect(store.studentsInCourse(a.id).length, 2);
    expect(store.studentsInCourse(b.id).length, 1);
  });

  testWidgets('add is disabled until there is a name', (tester) async {
    final store = RecitroStore(persist: false);
    await store.addCourse('A');
    await openCourse(tester, store, 'A');
    await tester.tap(find.text('Paste a list'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('addList')),
    );
    expect(button.onPressed, isNull);
  });
}
