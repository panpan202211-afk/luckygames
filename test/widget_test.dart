import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_games/main.dart';

void main() {
  testWidgets('home page opens the map', (tester) async {
    await tester.pumpWidget(const LuckyGamesApp());
    expect(find.text('Candy Clash'), findsOneWidget);
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
  });
}
