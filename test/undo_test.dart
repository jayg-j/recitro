import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recitro/data/recitro_store.dart';
import 'package:recitro/main.dart';
import 'package:recitro/models/call_outcome.dart';

void main() {
  Future<RecitroStore> openSession(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // In-memory store: no disk I/O, so plain taps work on the test clock.
    final store = RecitroStore(persist: false);
    await store.addStudent('Ann Santos');
    await store.addSession(
      name: 'Quiz',
      pointsPerAnswer: 5,
      pointsRequiredForReward: 10,
      rewardLabel: 'Sticker',
      allowRecallUnanswered: false,
      allowRecallAnswered: false,
    );
    await tester.pumpWidget(RecitroApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiz'));
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('undo after skip reopens the call', (tester) async {
    final store = await openSession(tester);
    final ann = store.students.first.id;

    await tap(tester, find.byKey(const Key('callNext')));
    await tap(tester, find.byKey(const Key('skipCall')));
    expect(find.text('Skipped Ann. Back in the queue.'), findsOneWidget);
    expect(store.sessions.first.studentStates[ann]!.outcome,
        CallOutcome.notCalled);

    await tap(tester, find.byKey(const Key('undo')));
    // Back on the reveal, ready to let Ann answer.
    expect(find.byKey(const Key('letAnswer')), findsOneWidget);
    expect(store.sessions.first.pendingStudentId, ann);

    await tap(tester, find.byKey(const Key('letAnswer')));
    expect(find.text('Points for this answer'), findsOneWidget);
  });

  testWidgets('undo after didn\'t answer goes back to scoring',
      (tester) async {
    final store = await openSession(tester);
    final ann = store.students.first.id;

    await tap(tester, find.byKey(const Key('callNext')));
    await tap(tester, find.byKey(const Key('letAnswer')));
    await tap(tester, find.text('Didn\'t answer'));
    expect(find.text('Ann didn\'t answer.'), findsOneWidget);
    expect(store.sessions.first.studentStates[ann]!.outcome,
        CallOutcome.notAnswered);

    await tap(tester, find.byKey(const Key('undo')));
    expect(find.text('Points for this answer'), findsOneWidget);

    await tap(tester, find.byKey(const Key('saveScore')));
    final state = store.sessions.first.studentStates[ann]!;
    expect(state.outcome, CallOutcome.answered);
    expect(state.pointsEarned, 5);
  });

  testWidgets('message disappears on its own if not used', (tester) async {
    await openSession(tester);
    await tap(tester, find.byKey(const Key('callNext')));
    await tap(tester, find.byKey(const Key('skipCall')));
    expect(find.byKey(const Key('undo')), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('undo')), findsNothing);
  });
}
