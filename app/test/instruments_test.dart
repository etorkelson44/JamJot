import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/models/instruments.dart';
import 'package:jamjot/widgets/instrument_picker.dart';

List<String> names(String q) => searchInstruments(q).map((i) => i.name).toList();

void main() {
  group('instrument list', () {
    test('has the 34 approved instruments with unique keys', () {
      expect(kInstrumentCatalog.length, 34);
      expect(kInstrumentCatalog.map((i) => i.key).toSet().length, 34);
    });

    test('"vio" finds Violin, Viola and Cello', () {
      expect(names('vio'), ['Violin', 'Viola', 'Cello']);
    });

    test('every typed word matches the start of a word', () {
      expect(names('fre h'), ['French horn']);
      expect(names('  FRENCH-horn '), ['French horn']);
      expect(names('orn'), isEmpty);
    });

    test('nicknames', () {
      expect(names('sax'), ['Saxophone']);
      expect(names('uke'), ['Ukulele']);
      expect(names('quads'), ['Tenor drums']);
      expect(names('marimba'), ['Mallet percussion']);
      expect(names('keys'), ['Piano']);
      expect(names('guitar'),
          containsAll(['Acoustic guitar', 'Electric guitar', 'Bass guitar']));
      expect(names('horn'), containsAll(['French horn', 'Mellophone']));
      expect(names('bass'),
          containsAll(['Double bass', 'Bass guitar', 'Bass clarinet', 'Bass drum']));
      expect(names('percussion'),
          containsAll(['Drums', 'Snare drum', 'Timpani', 'Mallet percussion']));
    });

    test('shows all matches, no cap', () {
      expect(names('drums').length, greaterThan(5));
    });

    test('saved values map to pictures without rewriting', () {
      expect(resolveInstrument('Guitar').key, 'acoustic_guitar');
      expect(resolveInstrument('Drums').key, 'drums');
      expect(resolveInstrument('piano').key, 'piano');
      expect(resolveInstrument('Keyboard').key, 'piano');
      expect(resolveInstrument('Electric guitar').key, 'electric_guitar');
      expect(resolveInstrument('Kazoo').key, 'other');
      expect(resolveInstrument(null).key, 'other');
    });

    test('did you mean offers close spellings', () {
      expect(didYouMean('clarnet').map((i) => i.name), contains('Clarinet'));
      expect(didYouMean('trumpit').map((i) => i.name), contains('Trumpet'));
      expect(didYouMean('kazoo'), isEmpty);
      expect(didYouMean('violine').length, lessThanOrEqualTo(3));
    });

    test('tidies typed names', () {
      expect(tidyInstrumentName('  KAZOO!!  '), 'Kazoo');
      expect(tidyInstrumentName('steel   PAN'), 'Steel pan');
    });

    test('blocks rude words, names, numbers and emails', () {
      expect(instrumentInputProblem('kazoo'), isNull);
      expect(instrumentInputProblem('steel pan'), isNull);
      expect(instrumentInputProblem('shell'), isNull);
      expect(instrumentInputProblem('poop'), isNotNull);
      expect(instrumentInputProblem('Olivia'), isNotNull);
      expect(instrumentInputProblem('my name is Max'), isNotNull);
      expect(instrumentInputProblem('555 1234'), isNotNull);
      expect(instrumentInputProblem('kid@example.com'), isNotNull);
    });
  });

  group('instrument search box', () {
    Future<List<String>> pump(WidgetTester tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: InstrumentSearchField(onChosen: chosen.add, autofocus: true),
        ),
      ));
      return chosen;
    }

    testWidgets('typing shows matches; Enter picks the only one',
        (tester) async {
      final chosen = await pump(tester);
      await tester.enterText(find.byType(TextField), 'vio');
      await tester.pumpAndSettle();
      expect(find.text('Violin'), findsOneWidget);
      expect(find.text('Viola'), findsOneWidget);
      expect(find.text('Cello'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'tromb');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen, ['Trombone']);
    });

    testWidgets('arrows wrap and Enter picks the highlighted one',
        (tester) async {
      final chosen = await pump(tester);
      await tester.enterText(find.byType(TextField), 'vio');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // wraps to last
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen, ['Cello']);
    });

    testWidgets('Esc clears', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'vio');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Violin'), findsNothing);
    });

    testWidgets('no match offers to add the tidied name', (tester) async {
      final chosen = await pump(tester);
      await tester.enterText(find.byType(TextField), '  KAZOO! ');
      await tester.pumpAndSettle();
      expect(find.textContaining('"Kazoo" isn\'t on our list yet.'),
          findsOneWidget);
      await tester.tap(find.text('Yes, add it'));
      await tester.pumpAndSettle();
      expect(chosen, ['Kazoo']);
    });

    testWidgets('typos show Did you mean', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'clarnet');
      await tester.pumpAndSettle();
      expect(find.text('Did you mean...?'), findsOneWidget);
      expect(find.text('Clarinet'), findsOneWidget);
    });

    testWidgets('the outline is just the search bar when empty',
        (tester) async {
      await pump(tester);
      final empty = tester.getSize(find.byType(InstrumentSearchField)).height;
      await tester.enterText(find.byType(TextField), 'vio');
      await tester.pumpAndSettle();
      final three = tester.getSize(find.byType(InstrumentSearchField)).height;
      await tester.enterText(find.byType(TextField), 'viola');
      await tester.pumpAndSettle();
      final two = tester.getSize(find.byType(InstrumentSearchField)).height;
      expect(empty, lessThan(80));
      expect(three, greaterThan(two));
      expect(two, greaterThan(empty));
    });
  });

  testWidgets('picker shows the choice with a Change link', (tester) async {
    var value = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => InstrumentPicker(
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'harmon');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harmonica'));
    await tester.pumpAndSettle();
    expect(value, ['Harmonica']);
    expect(find.text('Change'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
