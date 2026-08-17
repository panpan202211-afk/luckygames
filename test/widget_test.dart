import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_games/main.dart';
import 'package:lucky_games/privacy_policy_page.dart';

void main() {
  testWidgets('home page opens the map', (tester) async {
    await tester.pumpWidget(const LuckyGamesApp());
    expect(find.text('Lucky Games'), findsOneWidget);
    await tester.tap(find.text('PLAY NOW'));
    await tester.pumpAndSettle();
    expect(find.text('Adventure Maps'), findsOneWidget);
    expect(find.text('EASY'), findsWidgets);
  });

  test('level targets and map difficulty scale correctly', () {
    expect(LevelConfig.forLevel(1).target, 6500);
    expect(LevelConfig.forLevel(10).target, 20000);
    expect(LevelConfig.forLevel(11).target, 21500);
    expect(LevelConfig.forLevel(21).target, 36500);
    expect(LevelConfig.forLevel(1).moves,
        greaterThan(LevelConfig.forLevel(11).moves));
    expect(LevelConfig.forLevel(11).moves,
        greaterThan(LevelConfig.forLevel(21).moves));
    expect(LevelConfig.forLevel(1).iceTiles, 0);
    expect(LevelConfig.forLevel(11).iceTiles, greaterThan(0));
    expect(LevelConfig.forLevel(21).bombTurns, greaterThan(0));
  });

  test('privacy API response resolves a validated HTTPS URL', () {
    expect(
      parsePrivacyPolicyUrl(
        '{"code":"0","url":"https://sites.google.com/view/cashnote3"}',
      ).toString(),
      'https://sites.google.com/view/cashnote3',
    );
    expect(
      () => parsePrivacyPolicyUrl('{"code":"1","url":"https://x.test"}'),
      throwsFormatException,
    );
  });
}
