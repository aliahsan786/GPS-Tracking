import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_tracking/widgets/common/primary_button.dart';

// The default counter test was removed along with MyApp. We now have a
// real app behind MultiProvider + secure storage + Hive, so a top-level
// smoke test would need fakes for every service. Keeping a small widget
// test here instead until we add proper provider test helpers.
void main() {
  testWidgets('PrimaryButton renders its label and fires onPressed',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PrimaryButton(
          label: 'Start Tracking',
          onPressed: () => tapped++,
        ),
      ),
    ));

    expect(find.text('Start Tracking'), findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(tapped, 1);
  });

  testWidgets('PrimaryButton disables when onPressed is null',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PrimaryButton(label: 'Start Tracking', onPressed: null),
      ),
    ));

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });
}
