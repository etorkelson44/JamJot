import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/widgets/maestro_tour_bus.dart';

void main() {
  testWidgets('tour bus renders still, runs on tap, and settles',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: MaestroTourBus(width: 96)))));
    await tester.pump();
    expect(find.byType(MaestroTourBus), findsOneWidget);
    // Idle: three layers, no exhaust puffs.
    expect(find.byType(Image), findsNWidgets(3));

    // Tap starts the run: exhaust puffs appear during it.
    await tester.tap(find.byType(MaestroTourBus), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byType(Image).evaluate().length, greaterThan(3));

    // A second tap mid-run is ignored (no exception, still running).
    await tester.tap(find.byType(MaestroTourBus), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));

    // After the full run the bus settles back to its still frame.
    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pump();
    expect(find.byType(Image), findsNWidgets(3));
  });
}
