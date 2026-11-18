import 'package:flutter_test/flutter_test.dart';
import 'package:recitro/data/recitro_store.dart';
import 'package:recitro/models/call_outcome.dart';

void main() {
  Future<String> session(
    RecitroStore store,
    String courseId,
    String subject,
  ) async {
    final s = await store.addSession(
      name: '$subject session',
      pointsPerAnswer: 5,
      pointsRequiredForReward: 10,
      rewardLabel: 'Star',
      allowRecallUnanswered: false,
      allowRecallAnswered: false,
      courseId: courseId,
      subject: subject,
    );
    return s.id;
  }

  test('sessions only include their course\'s students', () async {
    final store = RecitroStore(persist: false);
    final a = await store.addCourse('BSIT 2-A');
    final b = await store.addCourse('Grade 7 - Rizal');
    await store.addStudents(['Ana', 'Ben'], courseId: a.id);
    await store.addStudents(['Cy'], courseId: b.id);

    final s = store.sessionById(await session(store, a.id, 'Math'))!;
    expect(store.studentsFor(s).map((x) => x.name), ['Ana', 'Ben']);
    expect(s.studentStates.length, 2);

    // Random picks never leave the course.
    for (var i = 0; i < 2; i++) {
      final id = await store.pickRandomStudent(s);
      expect(store.studentById(id!)!.courseId, a.id);
      await store.markAnswered(s);
    }
    expect(await store.pickRandomStudent(s), isNull);
  });

  test('new subject on a session is added to the course', () async {
    final store = RecitroStore(persist: false);
    final a = await store.addCourse('BSIT 2-A', subjects: ['Math']);
    await session(store, a.id, 'Science');
    expect(store.courseById(a.id)!.subjects, ['Math', 'Science']);

    // Same subject in a different case isn't duplicated.
    await session(store, a.id, 'science');
    expect(store.courseById(a.id)!.subjects, ['Math', 'Science']);
  });

  test('priority carries over within the same course and subject', () async {
    final store = RecitroStore(persist: false);
    final a = await store.addCourse('BSIT 2-A');
    await store.addStudents(['Ana', 'Ben'], courseId: a.id);
    final ana = store.students[0].id;
    final ben = store.students[1].id;

    final math1 = store.sessionById(await session(store, a.id, 'Math'))!;
    await store.callStudent(math1, ana);
    await store.markAnswered(math1);

    // A Science session in between doesn't affect Math priority.
    await session(store, a.id, 'Science');

    final math2 = store.sessionById(await session(store, a.id, 'Math'))!;
    expect(store.isPriority(math2, ben), isTrue);
    expect(store.isPriority(math2, ana), isFalse);
    expect(math2.previousSessionName, 'Math session');

    // The first Science session had no previous Science session.
    final sci = store.sessions[1];
    expect(sci.studentStates.values.any((s) => s.priority), isFalse);
  });

  test('new students join only their course\'s sessions', () async {
    final store = RecitroStore(persist: false);
    final a = await store.addCourse('A');
    final b = await store.addCourse('B');
    final sa = store.sessionById(await session(store, a.id, 'Math'))!;
    final sb = store.sessionById(await session(store, b.id, 'Math'))!;

    await store.addStudent('Dee', courseId: a.id);
    final dee = store.students.single.id;
    expect(sa.studentStates[dee]?.outcome, CallOutcome.notCalled);
    expect(sb.studentStates.containsKey(dee), isFalse);
  });

  test('renaming a subject updates its sessions', () async {
    final store = RecitroStore(persist: false);
    final a = await store.addCourse('A');
    final s = store.sessionById(await session(store, a.id, 'Sci'))!;
    await store.renameSubject(a.id, 'Sci', 'Science');
    expect(s.subject, 'Science');
    expect(store.courseById(a.id)!.subjects, ['Science']);
  });

  test('deleting a course removes its students and sessions', () async {
    final store = RecitroStore(persist: false);
    final a = await store.addCourse('A');
    final b = await store.addCourse('B');
    await store.addStudents(['Ana'], courseId: a.id);
    await store.addStudents(['Ben'], courseId: b.id);
    await session(store, a.id, 'Math');
    await session(store, b.id, 'Math');

    await store.deleteCourse(a.id);
    expect(store.courses.map((c) => c.name), ['B']);
    expect(store.students.map((s) => s.name), ['Ben']);
    expect(store.sessions.length, 1);
  });

  test('no course given uses a default "My class" course', () async {
    final store = RecitroStore(persist: false);
    await store.addStudent('Ana');
    expect(store.courses.single.name, RecitroStore.defaultCourseName);
    expect(store.students.single.courseId, store.courses.single.id);
  });
}
