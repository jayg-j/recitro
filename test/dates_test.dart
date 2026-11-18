import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recitro/widgets/dates.dart';

void main() {
  final now = DateTime(2026, 11, 19, 15, 0);

  Future<String?> label(WidgetTester tester, DateTime date) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            result = sessionDateLabel(context, date, now: now);
            return const SizedBox();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('today and yesterday include the time', (tester) async {
    expect(await label(tester, DateTime(2026, 11, 19, 9, 30)), 'Today, 9:30 AM');
    expect(
      await label(tester, DateTime(2026, 11, 18, 14, 5)),
      'Yesterday, 2:05 PM',
    );
  });

  testWidgets('earlier this year shows weekday and date', (tester) async {
    expect(await label(tester, DateTime(2026, 11, 14, 8)), 'Sat, Nov 14');
  });

  testWidgets('other years include the year', (tester) async {
    expect(await label(tester, DateTime(2025, 11, 14, 8)), 'Nov 14, 2025');
  });

  testWidgets('unknown (old data) dates show nothing', (tester) async {
    expect(
      await label(tester, DateTime.fromMillisecondsSinceEpoch(0)),
      isNull,
    );
  });
}
