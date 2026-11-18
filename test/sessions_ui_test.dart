import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recitro/data/recitro_store.dart';
import 'package:recitro/main.dart';
import 'package:recitro/screens/session_detail_screen.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester,
    RecitroStore store, {
    Size size = const Size(393, 852),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RecitroApp(store: store));
    await tester.pumpAndSettle();
  }

  Finder fieldIn(String key) => find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextField),
      );

  Future<RecitroStore> twoCourses() async {
    final store = RecitroStore(persist: false);
    final a = await store.addCourse('BSIT 2-A', subjects: ['Math']);
    final b = await store.addCourse('Grade 7 - Rizal', subjects: ['Science']);
    await store.addStudents(
      ['Andrea Santos', 'Benjamin Cruz', 'Carla Reyes'],
      courseId: a.id,
    );
    await store.addStudents(['Diego Mendoza'], courseId: b.id);
    await store.addSession(
      name: 'Algebra quiz',
      pointsPerAnswer: 5,
      pointsRequiredForReward: 10,
      rewardLabel: 'Star',
      allowRecallUnanswered: false,
      allowRecallAnswered: false,
      courseId: a.id,
      subject: 'Math',
    );
    await store.addSession(
      name: 'Cells review',
      pointsPerAnswer: 5,
      pointsRequiredForReward: 10,
      rewardLabel: 'Star',
      allowRecallUnanswered: false,
      allowRecallAnswered: false,
      courseId: b.id,
      subject: 'Science',
    );
    return store;
  }

  testWidgets('new session can create a new course and subject',
      (tester) async {
    final store = RecitroStore(persist: false);
    await store.addCourse('BSIT 2-A');
    await pumpApp(tester, store);

    await tester.tap(find.text('New session'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldIn('coursePicker'), 'BSIT 3-B');
    await tester.enterText(fieldIn('subjectPicker'), 'Physics');
    await tester.enterText(find.byKey(const Key('rewardName')), 'Sticker');
    await tester.pumpAndSettle();
    expect(find.text('New course'), findsOneWidget);

    await tester.tap(find.byKey(const Key('createSession')));
    await tester.pumpAndSettle();

    final course = store.courses.firstWhere((c) => c.name == 'BSIT 3-B');
    final session = store.sessions.single;
    expect(session.courseId, course.id);
    expect(session.subject, 'Physics');
    expect(course.subjects, ['Physics']);
    // Default name uses the subject.
    expect(session.name, startsWith('Physics · '));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sessions can be searched and filtered by course',
      (tester) async {
    final store = await twoCourses();
    await pumpApp(tester, store);
    expect(find.text('Algebra quiz'), findsOneWidget);
    expect(find.text('Cells review'), findsOneWidget);

    // Filter chip.
    final chip = find.widgetWithText(ChoiceChip, 'Grade 7 - Rizal');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('Algebra quiz'), findsNothing);
    expect(find.text('Cells review'), findsOneWidget);
    final all = find.widgetWithText(
      ChoiceChip,
      'All courses',
      skipOffstage: false,
    );
    await tester.ensureVisible(all);
    await tester.pumpAndSettle();
    await tester.tap(all);
    await tester.pumpAndSettle();

    // Search by subject.
    await tester.tap(find.byKey(const Key('searchSessions')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sessionSearch')), 'math');
    await tester.pumpAndSettle();
    expect(find.text('Algebra quiz'), findsOneWidget);
    expect(find.text('Cells review'), findsNothing);
  });

  testWidgets('students can be searched in a session', (tester) async {
    final store = await twoCourses();
    await pumpApp(tester, store);
    await tester.tap(find.text('Algebra quiz'));
    await tester.pumpAndSettle();

    // Only this course's students are listed.
    expect(find.text('Diego Mendoza'), findsNothing);
    expect(find.text('Andrea Santos'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('studentSearch')), 'cruz');
    await tester.pumpAndSettle();
    expect(find.text('Benjamin Cruz'), findsOneWidget);
    expect(find.text('Andrea Santos'), findsNothing);

    await tester.enterText(find.byKey(const Key('studentSearch')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No students match "zzz".'), findsOneWidget);
  });

  testWidgets('tablet shows list and session side by side', (tester) async {
    final store = await twoCourses();
    await pumpApp(tester, store, size: const Size(1100, 800));

    // Newest session is open next to the list.
    expect(find.byType(SessionDetailScreen), findsOneWidget);
    expect(find.text('Diego Mendoza'), findsOneWidget);

    // Selecting another session swaps the right pane, no page push.
    await tester.tap(find.text('Algebra quiz'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionDetailScreen), findsOneWidget);
    expect(find.text('Andrea Santos'), findsOneWidget);
    expect(find.text('Diego Mendoza'), findsNothing);
    expect(find.byTooltip('Back'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
