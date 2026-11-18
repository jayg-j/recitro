import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:recitro/data/recitro_store.dart';
import 'package:recitro/main.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '.';
}

void expectNoLayoutErrors(WidgetTester tester, String where) {
  final error = tester.takeException();
  if (error == null) return;
  final details =
      error is FlutterError ? error.toStringDeep() : error.toString();
  fail('Layout error ($where):\n$details');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _FakePathProvider();

  testWidgets('call flow works end to end on a phone-sized screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = RecitroStore();
    await tester.runAsync(() async {
      await store.addStudent('Ann Santos');
      await store.addStudent('Ben Cruz');
      await store.addStudent('Cy Reyes');
      final day1 = await store.addSession(
        name: 'Science — Day 1',
        pointsPerAnswer: 5,
        pointsRequiredForReward: 5,
        rewardLabel: 'Sticker',
        allowRecallUnanswered: false,
        allowRecallAnswered: false,
      );
      await store.callStudent(day1, store.students.first.id);
      await store.markAnswered(day1);
      await store.addSession(
        name: 'Science — Day 2',
        pointsPerAnswer: 5,
        pointsRequiredForReward: 5,
        rewardLabel: 'Sticker',
        allowRecallUnanswered: false,
        allowRecallAnswered: false,
      );
    });

    // Taps whose handlers write to disk need real async time.
    Future<void> tapAndSettle(Finder f) async {
      await tester.runAsync(() async {
        await tester.tap(f);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expectNoLayoutErrors(tester, 'after tapping ${f.describeMatch(Plurality.one)}');
    }

    await tester.pumpWidget(RecitroApp(store: store));
    await tester.pumpAndSettle();
    expectNoLayoutErrors(tester, 'home screen');

    expect(find.text('Sessions'), findsWidgets);
    expect(find.text('Science — Day 2'), findsOneWidget);

    await tapAndSettle(find.text('Science — Day 2'));
    expect(find.text('Priority students go first'), findsOneWidget);
    expect(find.text('Call next · priority first'), findsOneWidget);

    await tapAndSettle(find.text('Call next · priority first'));
    expect(find.text('NOW CALLING'), findsOneWidget);

    await tapAndSettle(find.text('Let them answer'));
    expect(find.text('SCORE'), findsOneWidget);

    await tapAndSettle(find.text('Give 5 points'));
    expect(find.text('Give reward'), findsOneWidget);

    await tapAndSettle(find.text('Give reward'));
    expect(store.ledger.length, 1);

    // Edit form opens and renders.
    await tapAndSettle(find.byTooltip('Edit session'));
    expect(find.text('Edit session'), findsOneWidget);
    await tapAndSettle(find.byTooltip('Close'));

    await tapAndSettle(find.byTooltip('Back'));
    await tapAndSettle(find.text('Students'));
    expect(find.text('Ann Santos'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
