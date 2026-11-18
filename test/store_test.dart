import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:recitro/data/recitro_store.dart';
import 'package:recitro/models/call_outcome.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '.';
}

Future<void> _answerOnce(RecitroStore store, String sessionId) async {
  final session = store.sessionById(sessionId)!;
  await store.pickRandomStudent(session);
  await store.markAnswered(store.sessionById(sessionId)!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _FakePathProvider();

  test('ledger keeps points after session deleted', () async {
    final store = RecitroStore();
    await store.addStudent('Ada');
    await store.addSession(
      name: 'Quiz',
      pointsPerAnswer: 5,
      pointsRequiredForReward: 5,
      rewardLabel: 'Star',
      allowRecallUnanswered: false,
      allowRecallAnswered: false,
    );
    final session = store.sessions.first;
    final studentId = store.students.first.id;
    await _answerOnce(store, session.id);
    await store.claimReward(store.sessionById(session.id)!, studentId);

    expect(store.totalPointsForStudent(studentId), 5);
    await store.deleteSession(session.id);
    expect(store.totalPointsForStudent(studentId), 5);
    expect(store.sessions, isEmpty);
  });

  test('answered without claim has no ledger points', () async {
    final store = RecitroStore();
    await store.addStudent('Bo');
    await store.addSession(
      name: 'Drill',
      pointsPerAnswer: 3,
      pointsRequiredForReward: 10,
      rewardLabel: 'Badge',
      allowRecallUnanswered: true,
      allowRecallAnswered: false,
    );
    final session = store.sessions.first;
    final studentId = store.students.first.id;
    await _answerOnce(store, session.id);

    expect(store.totalPointsForStudent(studentId), 0);
    final state = store.sessionById(session.id)!.studentStates[studentId];
    expect(state?.outcome, CallOutcome.answered);
    expect(state?.pointsEarned, 3);
    expect(state?.rewardClaimed, false);
    expect(store.canClaimReward(store.sessionById(session.id)!, studentId),
        isFalse);
  });

  test('points accumulate across recalls until threshold', () async {
    final store = RecitroStore();
    await store.addStudent('Cal');
    await store.addSession(
      name: 'Recall',
      pointsPerAnswer: 5,
      pointsRequiredForReward: 10,
      rewardLabel: 'Candy',
      allowRecallUnanswered: false,
      allowRecallAnswered: true,
    );
    final session = store.sessions.first;
    final studentId = store.students.first.id;

    await _answerOnce(store, session.id);
    var s = store.sessionById(session.id)!;
    expect(s.studentStates[studentId]!.pointsEarned, 5);
    expect(store.canClaimReward(s, studentId), isFalse);

    await store.pickRandomStudent(s);
    await store.markAnswered(store.sessionById(session.id)!);
    s = store.sessionById(session.id)!;
    expect(s.studentStates[studentId]!.pointsEarned, 10);
    expect(store.canClaimReward(s, studentId), isTrue);

    await store.claimReward(s, studentId);
    expect(store.totalPointsForStudent(studentId), 10);
  });

  test('claim blocked below threshold', () async {
    final store = RecitroStore();
    await store.addStudent('Dee');
    await store.addSession(
      name: 'S',
      pointsPerAnswer: 5,
      pointsRequiredForReward: 10,
      rewardLabel: 'R',
      allowRecallUnanswered: false,
      allowRecallAnswered: false,
    );
    final session = store.sessions.first;
    final studentId = store.students.first.id;
    await _answerOnce(store, session.id);

    final ok =
        await store.claimReward(store.sessionById(session.id)!, studentId);
    expect(ok, isFalse);
    expect(store.totalPointsForStudent(studentId), 0);
  });

  Future<void> addBasicSession(RecitroStore store, String name) =>
      store.addSession(
        name: name,
        pointsPerAnswer: 5,
        pointsRequiredForReward: 10,
        rewardLabel: 'Sticker',
        allowRecallUnanswered: false,
        allowRecallAnswered: false,
      );

  test('students not called last session get priority and go first',
      () async {
    final store = RecitroStore();
    await store.addStudent('Ann');
    await store.addStudent('Ben');
    await store.addStudent('Cy');
    await addBasicSession(store, 'Day 1');
    final day1 = store.sessions.first;
    final ann = store.students[0].id;
    final ben = store.students[1].id;
    final cy = store.students[2].id;

    // Only Ann is called on day 1.
    await store.callStudent(day1, ann);
    await store.markAnswered(day1);

    expect(store.studentsMissedInLatestSession().map((s) => s.id),
        unorderedEquals([ben, cy]));

    await addBasicSession(store, 'Day 2');
    final day2 = store.sessions.last;
    expect(day2.previousSessionName, 'Day 1');
    expect(store.isPriority(day2, ann), isFalse);
    expect(store.isPriority(day2, ben), isTrue);
    expect(store.isPriority(day2, cy), isTrue);

    // The first two random picks must be the priority students.
    final first = await store.pickRandomStudent(day2);
    await store.markAnswered(day2);
    final second = await store.pickRandomStudent(day2);
    await store.markAnswered(day2);
    expect([first, second], unorderedEquals([ben, cy]));
    expect(await store.pickRandomStudent(day2), ann);
  });

  test('skipping keeps the student waiting and carries priority', () async {
    final store = RecitroStore();
    await store.addStudent('Ann');
    await addBasicSession(store, 'Day 1');
    final day1 = store.sessions.first;
    final ann = store.students.first.id;

    await store.pickRandomStudent(day1);
    await store.skipCall(day1);
    expect(day1.pendingStudentId, isNull);
    expect(day1.studentStates[ann]!.outcome, CallOutcome.notCalled);
    expect(store.hasCallableStudents(day1), isTrue);

    await addBasicSession(store, 'Day 2');
    expect(store.isPriority(store.sessions.last, ann), isTrue);
  });

  test('teacher sets the score and can rename the reward', () async {
    final store = RecitroStore();
    await store.addStudent('Ann');
    await addBasicSession(store, 'Quiz');
    final s = store.sessions.first;
    final ann = store.students.first.id;

    await store.callStudent(s, ann);
    await store.markAnswered(s, points: 12);
    expect(s.studentStates[ann]!.pointsEarned, 12);
    expect(store.canClaimReward(s, ann), isTrue);

    await store.claimReward(s, ann, rewardLabel: 'Extra recess');
    expect(store.ledgerForStudent(ann).single.rewardLabel, 'Extra recess');
    expect(store.ledgerForStudent(ann).single.points, 12);
  });

  test('zero points records an answer without progress', () async {
    final store = RecitroStore();
    await store.addStudent('Ann');
    await addBasicSession(store, 'Quiz');
    final s = store.sessions.first;
    final ann = store.students.first.id;

    await store.callStudent(s, ann);
    await store.markAnswered(s, points: 0);
    expect(s.studentStates[ann]!.outcome, CallOutcome.answered);
    expect(s.studentStates[ann]!.pointsEarned, 0);
  });

  test('undo reopens a skipped or unanswered call', () async {
    final store = RecitroStore();
    await store.addStudent('Ann');
    await store.addStudent('Ben');
    await addBasicSession(store, 'Quiz');
    final s = store.sessions.first;
    final ann = store.students.first.id;

    // Didn't answer -> undo puts Ann back into the call.
    await store.callStudent(s, ann);
    await store.markNotAnswered(s);
    expect(await store.reopenCall(s, ann, before: CallOutcome.notCalled),
        isTrue);
    expect(s.pendingStudentId, ann);
    expect(s.studentStates[ann]!.outcome, CallOutcome.pending);

    // Skipping the reopened call returns Ann to waiting, not "didn't answer".
    await store.skipCall(s);
    expect(s.studentStates[ann]!.outcome, CallOutcome.notCalled);

    // Undo is refused while someone else is being called.
    final ben = store.students[1].id;
    await store.callStudent(s, ben);
    expect(await store.reopenCall(s, ann, before: CallOutcome.notCalled),
        isFalse);
    expect(s.pendingStudentId, ben);
  });

  test('answered recall uses lower pick weight', () async {
    final store = RecitroStore();
    await store.addStudent('A');
    await store.addSession(
      name: 'S',
      pointsPerAnswer: 1,
      pointsRequiredForReward: 1,
      rewardLabel: 'R',
      allowRecallUnanswered: false,
      allowRecallAnswered: true,
    );
    final session = store.sessions.first;
    final a = store.students.first.id;
    await _answerOnce(store, session.id);
    await store.claimReward(store.sessionById(session.id)!, a);

    await store.addStudent('B');
    final fresh = store.sessionById(session.id)!;
    final b = store.students[1].id;

    expect(
      store.pickWeightForStudent(fresh, store.studentById(a)!),
      RecitroStore.answeredRecallPickWeight,
    );
    expect(
      store.pickWeightForStudent(fresh, store.studentById(b)!),
      RecitroStore.primaryPickWeight,
    );
    expect(
      store.pickWeightForStudent(fresh, store.studentById(b)!),
      greaterThan(store.pickWeightForStudent(fresh, store.studentById(a)!)),
    );
  });
}