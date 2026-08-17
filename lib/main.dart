import 'dart:math';

import 'package:flutter/material.dart';

import 'privacy_policy_page.dart';

void main() {
  runApp(const LuckyGamesApp());
}

class LuckyGamesApp extends StatelessWidget {
  const LuckyGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Candy Clash',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5A7A),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class GameProgress extends ChangeNotifier {
  int unlockedLevel = 1;
  final Map<int, int> stars = {};

  void complete(int level, int earnedStars) {
    stars[level] = max(stars[level] ?? 0, earnedStars);
    unlockedLevel = max(unlockedLevel, min(30, level + 1));
    notifyListeners();
  }
}

final gameProgress = GameProgress();

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFBED1),
                  Color(0xFFFFF2B7),
                  Color(0xFFBFEFFF)
                ],
              ),
            ),
          ),
          ...List.generate(10, (index) {
            final icons = CandyType.values;
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final wave = sin((_controller.value + index / 10) * pi * 2);
                return Positioned(
                  left:
                      (index * 73.0) % (MediaQuery.sizeOf(context).width + 20) -
                          20,
                  top: 32 + index * 66 + wave * 13,
                  child: Opacity(
                    opacity: 0.22,
                    child: Transform.rotate(
                      angle: wave * .2,
                      child: CandyIcon(
                          type: icons[index % icons.length], size: 44),
                    ),
                  ),
                );
              },
            );
          }),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .88),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 24,
                            offset: Offset(0, 10))
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'img/icon-1024.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Candy Clash',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF6D315C),
                      letterSpacing: 2,
                      shadows: [Shadow(color: Colors.white, blurRadius: 8)],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Swap · Match · Conquer 30 Levels',
                      style: TextStyle(fontSize: 16, color: Color(0xFF865778))),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MapPage()),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5278),
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: const Color(0x88FF5278),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 34),
                          SizedBox(width: 8),
                          Text('PLAY NOW',
                              style: TextStyle(
                                  fontSize: 21, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyPage(),
                      ),
                    ),
                    icon: const Icon(Icons.privacy_tip_outlined, size: 19),
                    label: const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Tap two neighboring candies to swap',
                      style: TextStyle(color: Color(0xFF97657E))),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MapTheme {
  const MapTheme(this.name, this.subtitle, this.icon, this.colors);
  final String name;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
}

const mapThemes = [
  MapTheme('EASY', 'Sunny Meadows · Relaxed challenge', Icons.park_rounded,
      [Color(0xFF8DE2A5), Color(0xFFE8FFD5)]),
  MapTheme('HARD', 'Frozen Peaks · Tough challenge', Icons.ac_unit_rounded,
      [Color(0xFF83D7F4), Color(0xFFE5F9FF)]),
  MapTheme('HELL', 'Inferno Citadel · Extreme challenge', Icons.castle_rounded,
      [Color(0xFFC99BFF), Color(0xFFFFDAFA)]),
];

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  @override
  void initState() {
    super.initState();
    gameProgress.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    gameProgress.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: min(2, (gameProgress.unlockedLevel - 1) ~/ 10),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Adventure Maps',
              style: TextStyle(fontWeight: FontWeight.w800)),
          centerTitle: true,
          bottom: TabBar(
            tabs: [
              for (final map in mapThemes)
                Tab(icon: Icon(map.icon), text: map.name)
            ],
          ),
        ),
        body: TabBarView(
          children:
              List.generate(3, (mapIndex) => LevelMap(mapIndex: mapIndex)),
        ),
      ),
    );
  }
}

class LevelMap extends StatelessWidget {
  const LevelMap({super.key, required this.mapIndex});
  final int mapIndex;

  @override
  Widget build(BuildContext context) {
    final theme = mapThemes[mapIndex];
    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: theme.colors)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
            child: Row(
              children: [
                Icon(theme.icon, color: const Color(0xFF5D4565), size: 40),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(theme.name,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF503B58))),
                  Text(theme.subtitle,
                      style: const TextStyle(color: Color(0xFF715C78))),
                ]),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(22),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.25,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 18),
              itemCount: 10,
              itemBuilder: (context, index) {
                final level = mapIndex * 10 + index + 1;
                final unlocked = level <= gameProgress.unlockedLevel;
                final stars = gameProgress.stars[level] ?? 0;
                return InkWell(
                  onTap: unlocked
                      ? () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => GamePage(level: level)))
                      : null,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: unlocked
                          ? Colors.white.withValues(alpha: .92)
                          : Colors.white.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: unlocked
                          ? const [
                              BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 6))
                            ]
                          : null,
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          unlocked
                              ? Text('$level',
                                  style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFFF5278)))
                              : const Icon(Icons.lock_rounded,
                                  color: Color(0xFF93899A), size: 30),
                          const SizedBox(height: 4),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                  3,
                                  (i) => Icon(Icons.star_rounded,
                                      size: 20,
                                      color: i < stars
                                          ? const Color(0xFFFFB52E)
                                          : const Color(0xFFD9D2DC)))),
                        ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum CandyType { heart, star, flower, moon, drop }

class LevelConfig {
  const LevelConfig({required this.moves, required this.target});
  final int moves;
  final int target;

  factory LevelConfig.forLevel(int level) {
    final local = (level - 1) % 10;
    final map = (level - 1) ~/ 10;
    const startingMoves = [28, 22, 17];
    final baseTarget = 650 + (level - 1) * 150;
    return LevelConfig(
      moves: max(10, startingMoves[map] - local ~/ 2),
      target: baseTarget * 10,
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.level});
  final int level;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  static const int rows = 8;
  static const int cols = 7;
  final Random _random = Random();
  late List<int> _board;
  late LevelConfig _config;
  int _moves = 0;
  int _score = 0;
  int? _selected;
  Set<int> _clearing = {};
  bool _busy = false;
  bool _ended = false;
  String _comboText = '';

  @override
  void initState() {
    super.initState();
    _startLevel();
  }

  void _startLevel() {
    _config = LevelConfig.forLevel(widget.level);
    _moves = _config.moves;
    _score = 0;
    _selected = null;
    _clearing = {};
    _busy = false;
    _ended = false;
    _comboText = '';
    _board = List.filled(rows * cols, 0);
    for (var i = 0; i < _board.length; i++) {
      var value = _random.nextInt(CandyType.values.length);
      while (_wouldCreateInitialMatch(i, value)) {
        value = _random.nextInt(CandyType.values.length);
      }
      _board[i] = value;
    }
  }

  bool _wouldCreateInitialMatch(int index, int value) {
    final row = index ~/ cols;
    final col = index % cols;
    if (col >= 2 && _board[index - 1] == value && _board[index - 2] == value) {
      return true;
    }
    if (row >= 2 &&
        _board[index - cols] == value &&
        _board[index - cols * 2] == value) {
      return true;
    }
    return false;
  }

  bool _adjacent(int a, int b) {
    final ar = a ~/ cols, ac = a % cols;
    final br = b ~/ cols, bc = b % cols;
    return (ar - br).abs() + (ac - bc).abs() == 1;
  }

  Future<void> _tapTile(int index) async {
    if (_busy || _ended || _board[index] < 0) return;
    if (_selected == null) {
      setState(() => _selected = index);
      return;
    }
    if (_selected == index) {
      setState(() => _selected = null);
      return;
    }
    if (!_adjacent(_selected!, index)) {
      setState(() => _selected = index);
      return;
    }
    final first = _selected!;
    setState(() {
      _busy = true;
      _selected = null;
      final temp = _board[first];
      _board[first] = _board[index];
      _board[index] = temp;
    });
    await Future<void>.delayed(const Duration(milliseconds: 210));
    final matches = _findMatches();
    if (matches.isEmpty) {
      setState(() {
        final temp = _board[first];
        _board[first] = _board[index];
        _board[index] = temp;
      });
      await Future<void>.delayed(const Duration(milliseconds: 210));
      if (mounted) setState(() => _busy = false);
      return;
    }
    _moves--;
    await _resolveBoard(matches);
    if (!mounted) return;
    setState(() => _busy = false);
    await _checkEnd();
  }

  Set<int> _findMatches() {
    final result = <int>{};
    for (var row = 0; row < rows; row++) {
      var start = 0;
      for (var col = 1; col <= cols; col++) {
        final endRun = col == cols ||
            _board[row * cols + col] != _board[row * cols + start];
        if (endRun) {
          if (_board[row * cols + start] >= 0 && col - start >= 3) {
            for (var i = start; i < col; i++) {
              result.add(row * cols + i);
            }
          }
          start = col;
        }
      }
    }
    for (var col = 0; col < cols; col++) {
      var start = 0;
      for (var row = 1; row <= rows; row++) {
        final endRun = row == rows ||
            _board[row * cols + col] != _board[start * cols + col];
        if (endRun) {
          if (_board[start * cols + col] >= 0 && row - start >= 3) {
            for (var i = start; i < row; i++) {
              result.add(i * cols + col);
            }
          }
          start = row;
        }
      }
    }
    return result;
  }

  Future<void> _resolveBoard(Set<int> matches) async {
    var combo = 1;
    var current = matches;
    while (current.isNotEmpty && mounted) {
      setState(() {
        _clearing = current;
        _comboText = combo > 1 ? '${combo}x COMBO!' : '';
        _score += current.length * 50 * combo;
      });
      await Future<void>.delayed(const Duration(milliseconds: 360));
      if (!mounted) return;
      setState(() {
        for (final i in current) {
          _board[i] = -1;
        }
        _clearing = {};
      });
      _collapseAndRefill();
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 330));
      current = _findMatches();
      combo++;
    }
    if (mounted) setState(() => _comboText = '');
  }

  void _collapseAndRefill() {
    for (var col = 0; col < cols; col++) {
      final values = <int>[];
      for (var row = rows - 1; row >= 0; row--) {
        final value = _board[row * cols + col];
        if (value >= 0) values.add(value);
      }
      var valueIndex = 0;
      for (var row = rows - 1; row >= 0; row--) {
        _board[row * cols + col] = valueIndex < values.length
            ? values[valueIndex++]
            : _random.nextInt(CandyType.values.length);
      }
    }
  }

  Future<void> _checkEnd() async {
    if (_score >= _config.target) {
      _ended = true;
      final stars = _moves >= _config.moves * .5 ? 3 : (_moves > 0 ? 2 : 1);
      gameProgress.complete(widget.level, stars);
      await _showResult(won: true, stars: stars);
    } else if (_moves <= 0) {
      _ended = true;
      await _showResult(won: false, stars: 0);
    }
  }

  Future<void> _showResult({required bool won, required int stars}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Column(children: [
          Icon(won ? Icons.emoji_events_rounded : Icons.refresh_rounded,
              color: won ? const Color(0xFFFFB52E) : const Color(0xFF7E6A88),
              size: 64),
          Text(won ? 'LEVEL COMPLETE!' : 'TRY AGAIN',
              style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (won)
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    3,
                    (i) => Icon(Icons.star_rounded,
                        color: i < stars
                            ? const Color(0xFFFFB52E)
                            : const Color(0xFFE1DCE3),
                        size: 40))),
          const SizedBox(height: 12),
          Text('Score $_score / Target ${_config.target}',
              style: const TextStyle(fontSize: 16)),
        ]),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text('MAP')),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (won && widget.level < 30) {
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => GamePage(level: widget.level + 1)));
              } else {
                setState(_startLevel);
              }
            },
            child: Text(won && widget.level < 30 ? 'NEXT LEVEL' : 'RETRY'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final map = mapThemes[(widget.level - 1) ~/ 10];
    return Scaffold(
      backgroundColor: map.colors.last,
      appBar: AppBar(
        backgroundColor: map.colors.first,
        title: Text('${map.name} · LEVEL ${widget.level}',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(children: [
                _StatCard(
                    icon: Icons.directions_walk_rounded,
                    label: 'MOVES',
                    value: '$_moves',
                    color: const Color(0xFF5B8DEF)),
                const SizedBox(width: 10),
                _StatCard(
                    icon: Icons.auto_awesome_rounded,
                    label: 'SCORE',
                    value: '$_score',
                    color: const Color(0xFFFF5278)),
                const SizedBox(width: 10),
                _StatCard(
                    icon: Icons.flag_rounded,
                    label: 'TARGET',
                    value: '${_config.target}',
                    color: const Color(0xFF7CB342)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    value: min(1, _score / _config.target),
                    minHeight: 10,
                    backgroundColor: Colors.white70,
                    color: const Color(0xFFFFB52E)),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Center(
                child: LayoutBuilder(builder: (context, constraints) {
                  final boardWidth = min(constraints.maxWidth - 20,
                      (constraints.maxHeight - 10) * cols / rows);
                  return SizedBox(
                    width: boardWidth,
                    height: boardWidth * rows / cols,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: const Color(0x445B4167),
                              borderRadius: BorderRadius.circular(22),
                              border:
                                  Border.all(color: Colors.white, width: 3)),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols),
                            itemCount: rows * cols,
                            itemBuilder: (context, index) {
                              final clearing = _clearing.contains(index);
                              final selected = _selected == index;
                              return GestureDetector(
                                onTap: () => _tapTile(index),
                                child: AnimatedContainer(
                                  key: ValueKey('cell-$index-${_board[index]}'),
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutBack,
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: .58),
                                    borderRadius: BorderRadius.circular(13),
                                    border: selected
                                        ? Border.all(
                                            color: const Color(0xFFFFB52E),
                                            width: 3)
                                        : null,
                                  ),
                                  child: AnimatedScale(
                                    scale: clearing ? 0 : 1,
                                    duration: const Duration(milliseconds: 330),
                                    curve: Curves.easeInBack,
                                    child: AnimatedRotation(
                                      turns: clearing ? .35 : 0,
                                      duration:
                                          const Duration(milliseconds: 330),
                                      child: _board[index] >= 0
                                          ? CandyIcon(
                                              type: CandyType
                                                  .values[_board[index]],
                                              size: 38)
                                          : const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        IgnorePointer(
                          child: AnimatedScale(
                            scale: _comboText.isEmpty ? .5 : 1,
                            duration: const Duration(milliseconds: 250),
                            child: AnimatedOpacity(
                              opacity: _comboText.isEmpty ? 0 : 1,
                              duration: const Duration(milliseconds: 180),
                              child: Text(_comboText,
                                  style: const TextStyle(
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                            color: Color(0xAAFF3E72),
                                            blurRadius: 12,
                                            offset: Offset(0, 4))
                                      ])),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Swap neighboring candies to match 3 or more',
                  style: TextStyle(color: Color(0xFF715C78), fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .86),
            borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          Text(value,
              style: TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF75687A))),
        ]),
      ),
    );
  }
}

class CandyIcon extends StatelessWidget {
  const CandyIcon({super.key, required this.type, required this.size});
  final CandyType type;
  final double size;

  static const colors = [
    Color(0xFFFF4F74),
    Color(0xFFFFB52E),
    Color(0xFF9C67F3),
    Color(0xFF42B7E9),
    Color(0xFF55C98B)
  ];
  static const icons = [
    Icons.favorite_rounded,
    Icons.star_rounded,
    Icons.local_florist_rounded,
    Icons.dark_mode_rounded,
    Icons.water_drop_rounded
  ];

  @override
  Widget build(BuildContext context) {
    final index = type.index;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: RadialGradient(
              center: const Alignment(-.35, -.4),
              colors: [Colors.white, colors[index]],
              stops: const [.02, .78]),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: colors[index].withValues(alpha: .35),
                blurRadius: 5,
                offset: const Offset(0, 3))
          ],
        ),
        child: Icon(icons[index],
            color:
                index == 1 ? Colors.white : Colors.white.withValues(alpha: .94),
            size: size * .64),
      ),
    );
  }
}
