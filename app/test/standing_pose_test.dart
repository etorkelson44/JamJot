import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/widgets/dressed_avatar.dart';
import 'package:jamjot/widgets/letter_avatar.dart';
import 'package:jamjot/widgets/standing_pose.dart';

void main() {
  setUp(clearStandingPoseCache);

  testWidgets('each free character draws its layered standing pose', (tester) async {
    for (final key in ['kiwi', 'strawberry', 'jalapeno']) {
      await tester.pumpWidget(MaterialApp(
          home: Center(child: StandingPose(avatarKey: key, size: 200))));
      await tester.runAsync(() => loadStandingPose(key));
      await tester.pump();
      final assets = tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => (i.image as AssetImage).assetName)
          .toList();
      expect(assets.length, greaterThanOrEqualTo(6), reason: key);
      expect(assets.first, 'assets/art/avatar_pose/${key}_standing/1_body.png');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('dressed avatar and profile tile use the standing pose', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Row(children: [
      DressedAvatar(avatarKey: 'kiwi', outfit: [], size: 120),
      LetterAvatar(name: 'Ben', avatarKey: null, starterDefault: true, size: 60),
    ]))));
    expect(find.byType(StandingPose), findsNWidgets(2));
  });
}
