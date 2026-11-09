import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/widgets/jammed_up.dart';

void main() {
  Future<void> pump(WidgetTester t, Widget child) => t.pumpWidget(
      MaterialApp(home: Scaffold(body: child)));

  testWidgets('full page shows the message, directions and both buttons',
      (t) async {
    var retried = 0, home = 0;
    await pump(t, JammedUp(onRetry: () => retried++, onHome: () => home++));
    expect(find.text(JammedUp.message), findsOneWidget);
    expect(find.text(JammedUp.directions), findsOneWidget);
    await t.tap(find.text('Try again'));
    await t.tap(find.text('Back to start'));
    expect(retried, 1);
    expect(home, 1);
  });

  testWidgets('an address that does not exist offers only Back to start',
      (t) async {
    await pump(t, JammedUp(onHome: () {}));
    expect(find.text(JammedUp.message), findsOneWidget);
    expect(find.text(JammedUp.directionsLost), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Back to start'), findsOneWidget);
  });

  testWidgets('small and tiny slots get words only, no Maestro', (t) async {
    await pump(
        t,
        const Center(
            child: SizedBox(
                width: 320,
                height: 160,
                child: JammedUp(onRetry: _noop))));
    expect(find.text(JammedUp.smallTitle), findsOneWidget);
    expect(
        find.text('${JammedUp.smallNote} ${JammedUp.smallFixRetry}'),
        findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text(JammedUp.message), findsNothing);
    expect(find.byType(Image), findsNothing);

    await pump(
        t,
        const Center(
            child: SizedBox(width: 60, height: 60, child: JammedUp())));
    expect(find.text(JammedUp.smallTitle), findsOneWidget);
    expect(find.text(JammedUp.tinyNote), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}

void _noop() {}
