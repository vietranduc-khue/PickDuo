import 'dart:math';
import 'package:flutter/material.dart' hide Wallet;
import 'package:flutter/services.dart'; 
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/particles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:games_services/games_services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  BrowserContextMenu.disableContextMenu(); 

  runApp(const GameApp());
}

class GameApp extends StatefulWidget {
  const GameApp({super.key});

  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> with TickerProviderStateMixin {
  MainGame? _game;
  String _currentScreen = 'menu'; 
  int _finalScore = 0;
  int _bestScore = 0;
  bool _isNewRecord = false;

  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _loadBestScore();
    _initAppleGameCenter();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _initAppleGameCenter() async {
    try {
      await GamesServices.signIn();
    } catch (e) {
      debugPrint('Game Center Sign In Error: $e');
    }
  }

  Future<void> _loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bestScore = prefs.getInt('pickduo_best_score') ?? 0;
    });
  }

  Future<void> _updateBestScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    if (score > _bestScore) {
      _bestScore = score;
      _isNewRecord = true;
      await prefs.setInt('pickduo_best_score', _bestScore);
      
      try {
        await GamesServices.submitScore(
          score: Score(
            androidLeaderboardID: '',
            iOSLeaderboardID: 'pickduo_leaderboard_id',
            value: _bestScore,
          ),
        );
      } catch (e) {
        debugPrint('Game Center Submit Score Error: $e');
      }
    } else {
      _isNewRecord = false;
    }
  }

  void _startGame() {
    setState(() {
      _isNewRecord = false;
      _game = MainGame(
        speedFactor: 2.2, 
        spawnInterval: 0.9, 
        onGameOver: (score) async {
          await _updateBestScore(score);
          setState(() {
            _finalScore = score;
            _currentScreen = 'gameover';
          });
        },
      );
      _currentScreen = 'game';
    });
  }
   @override
  Widget build(BuildContext context) {
    bool isBannerEnabled = false; 
    bool isRestorePurchaseEnabled = false; 

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: true,
          bottom: true,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    IndexedStack(
                      index: _currentScreen == 'menu' ? 0 : (_currentScreen == 'game' ? 1 : 2),
                      children: [
                        GestureDetector(
                          onTap: _startGame,
                          behavior: HitTestBehavior.opaque,
                          child: Stack(
                            children: [
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('PickDuo', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 3)),
                                    const SizedBox(height: 10),
                                    Text('BEST SCORE: $_bestScore', style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 80),
                                    const Text('TAP TO PLAY', style: TextStyle(color: Colors.grey, fontSize: 16, letterSpacing: 2, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              if (isRestorePurchaseEnabled)
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: TextButton(
                                    onPressed: _handleRestorePurchase,
                                    style: TextButton.styleFrom(foregroundColor: Colors.white38),
                                    child: const Text('Restore Purchase', style: TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _currentScreen == 'game' && _game != null
                            ? Stack(
                                children: [
                                  GameWidget<MainGame>(
                                    game: _game!,
                                    overlayBuilderMap: {
                                      'GameUIOverlay': (context, MainGame gameInstance) {
                                        return Positioned(
                                          top: 20, left: 15, right: 15,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              ValueListenableBuilder<int>(
                                                valueListenable: gameInstance.scoreNotifier,
                                                builder: (context, score, child) => Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                                                  child: Text('SCORE: $score', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                              ValueListenableBuilder<int>(
                                                valueListenable: gameInstance.livesNotifier,
                                                builder: (context, lives, child) => Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                                                  child: Text('LIVES: X ${max(0, lives)}', style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                              ValueListenableBuilder<double>(
                                                valueListenable: gameInstance.timeNotifier,
                                                builder: (context, gameTime, child) => Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                                                  child: Text('SURVIVED: ${gameTime.toStringAsFixed(1)}s', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    },
                                    initialActiveOverlays: const ['GameUIOverlay'],
                                  ),
                                  Positioned(bottom: 20, left: 15, child: _buildBinIndicator('DRAG LEFT\nGREEN', Colors.green)),
                                  Positioned(bottom: 20, right: 15, child: _buildBinIndicator('DRAG RIGHT\nBLUE', Colors.blue)),
                                ],
                              )
                            : const SizedBox(),
                            GestureDetector(
                          onTap: _startGame,
                          behavior: HitTestBehavior.opaque,
                          child: Stack(
                            children: [
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('GAME OVER', style: TextStyle(color: Colors.red, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 2)),
                                    const SizedBox(height: 40),
                                    Text('SCORE: $_finalScore', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 15),
                                    AnimatedBuilder(
                                      animation: _glowController,
                                      builder: (context, child) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: _isNewRecord ? [
                                              BoxShadow(
                                                color: Colors.amber.withOpacity(_glowController.value * 0.5),
                                                blurRadius: 15.0 + _glowController.value * 15.0,
                                                spreadRadius: 2.0 + _glowController.value * 4.0,
                                              )
                                            ] : [],
                                            border: _isNewRecord ? Border.all(color: Colors.amber.withOpacity(0.8), width: 1.5) : null,
                                            color: _isNewRecord ? Colors.amber.withOpacity(0.1) : Colors.transparent,
                                          ),
                                          child: Column(
                                            children: [
                                              if (_isNewRecord)
                                                const Text('NEW BEST RECORD!', style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                              Text('BEST SCORE: $_bestScore', style: TextStyle(color: _isNewRecord ? Colors.amber : Colors.amber.withOpacity(0.8), fontSize: 24, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 60),
                                    const Text('TRY AGAIN', style: TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 10),
                                    const Text('(Tap anywhere to play again)', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_currentScreen != 'game' && isBannerEnabled)
                Container(
                  width: double.infinity,
                  height: 50,
                  color: Colors.grey.withOpacity(0.2),
                  alignment: Alignment.center,
                  child: const Text('--- GOOGLE ADMOB BANNER AD PLACEHOLDER ---', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleRestorePurchase() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Restoring purchases... No previous purchases found.', textAlign: TextAlign.center),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.blueGrey,
      ),
    );
  }

  Widget _buildBinIndicator(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.2), border: Border.all(color: color, width: 2), borderRadius: BorderRadius.circular(8)),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }
}
class MainGame extends FlameGame with HasCollisionDetection, DragCallbacks {
  final double speedFactor;
  final double spawnInterval;
  final Function(int) onGameOver;

  final scoreNotifier = ValueNotifier<int>(0);
  final livesNotifier = ValueNotifier<int>(3);
  final timeNotifier = ValueNotifier<double>(0.0);

  late Timer _spawnTimer;
  double gameTime = 0.0;
  bool _isEngineStopped = false;
  final Random _random = Random();

  MainGame({
    required this.speedFactor,
    required this.spawnInterval,
    required this.onGameOver,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _spawnTimer = Timer(_getSpawnIntervalRange(), onTick: _spawnRecyclingItem, repeat: true);
  }

  double _getSpawnIntervalRange() {
    double minS = 0.85; double maxS = 1.20;
    if (gameTime <= 10.0) {
      minS = 0.85; maxS = 1.20;
    } else if (gameTime <= 22.0) {
      minS = 0.70; maxS = 1.00;
    } else if (gameTime <= 25.0) {
      minS = 1.60; maxS = 2.10; 
    } else if (gameTime <= 42.0) {
      minS = 0.55; maxS = 0.80;
    } else if (gameTime <= 45.0) {
      minS = 1.60; maxS = 2.10; 
    } else if (gameTime <= 60.0) {
      minS = 0.40; maxS = 0.60;
    } else {
      double overTime = gameTime - 60.0;
      double densityBoost = (overTime / 2.0).floor() * 0.015;
      minS = max(0.20, 0.35 - densityBoost); 
      maxS = max(0.35, 0.50 - densityBoost);
    }
    return minS + _random.nextDouble() * (maxS - minS);
  }

  void _spawnRecyclingItem() {
    if (_isEngineStopped) return;

    double minSpeed = 1.35; double maxSpeed = 1.70;
    double straightChance = 0.70;

    if (gameTime <= 10.0) {
      minSpeed = 1.35; maxSpeed = 1.70; straightChance = 0.70;
    } else if (gameTime <= 22.0) {
      minSpeed = 1.60; maxSpeed = 2.00; straightChance = 0.55;
    } else if (gameTime <= 25.0) {
      minSpeed = 0.75; maxSpeed = 1.00; straightChance = 0.85; 
    } else if (gameTime <= 42.0) {
      minSpeed = 1.95; maxSpeed = 2.40; straightChance = 0.40;
    } else if (gameTime <= 45.0) {
      minSpeed = 0.75; maxSpeed = 1.00; straightChance = 0.85; 
    } else if (gameTime <= 60.0) {
      minSpeed = 2.30; maxSpeed = 2.80; straightChance = 0.30;
    } else {
      double overTime = gameTime - 60.0;
      double dynamicBoost = (overTime / 2.0).floor() * 0.08;
      minSpeed = 2.60 + dynamicBoost; 
      maxSpeed = 3.20 + dynamicBoost; 
      straightChance = 0.25; 
    }

    double itemSpeedFactor = minSpeed + _random.nextDouble() * (maxSpeed - minSpeed);
    bool shouldBeStraight = _random.nextDouble() < straightChance;

    final isOrganic = _random.nextBool();
    final item = FallingItem(
      isOrganic: isOrganic,
      speedFactor: itemSpeedFactor * 125, 
      gameWidth: size.x,
      forceStraight: shouldBeStraight,
    );
    add(item);

    _spawnTimer.limit = _getSpawnIntervalRange();
  }

  void createBurstParticles(Vector2 position, Color color) {
    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: 20, 
          lifespan: 0.4, 
          generator: (i) {
            final angle = _random.nextDouble() * 2 * pi;
            final speed = 80 + _random.nextDouble() * 120;
            return AcceleratedParticle(
              position: position.clone(),
              speed: Vector2(cos(angle) * speed, sin(angle) * speed),
              acceleration: Vector2(0, 200), 
              child: CircleParticle(
                radius: 2 + _random.nextDouble() * 4, 
                paint: Paint()..color = color.withOpacity(0.9),
              ),
            );
          },
        ),
      ),
    );
  }

  void _triggerGameOver() {
    _isEngineStopped = true;
    _spawnTimer.stop();
    children.whereType<FallingItem>().forEach((item) => item.removeFromParent());
    onGameOver(scoreNotifier.value);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_isEngineStopped) {
      gameTime += dt;
      timeNotifier.value = gameTime;
      _spawnTimer.update(dt);
    }
  }
}
class FallingItem extends PositionComponent with HasGameRef<MainGame>, DragCallbacks {
  final bool isOrganic;
  final double speedFactor;
  final double gameWidth;
  final bool forceStraight;

  final Random _random = Random();
  bool _isDragged = false;

  late int _trajectoryType; 
  late double _startX;
  late double _diagonalDirection; 
  late double _waveAmplitude; 
  late double _waveFrequency; 
  double _timeElapsed = 0.0;

  final List<Vector2> _historyPositions = [];
  final int _maxHistoryLength = 4;

  FallingItem({
    required this.isOrganic,
    required this.speedFactor,
    required this.gameWidth,
    required this.forceStraight,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = Vector2(90, 130); 
    _startX = _random.nextDouble() * (gameWidth - size.x);
    position = Vector2(_startX, -size.y);

    if (forceStraight) {
      _trajectoryType = 0; 
    } else {
      _trajectoryType = 1 + _random.nextInt(3); 
    }

    _diagonalDirection = _random.nextBool() ? 1.0 : -1.0;
    _waveAmplitude = 18.0 + _random.nextDouble() * 22.0; 
    _waveFrequency = 4.5 + _random.nextDouble() * 3.5;   
  }

  @override
  void render(Canvas canvas) {
    if (gameRef.gameTime > 60.0 && !_isDragged) {
      for (int i = 0; i < _historyPositions.length; i++) {
        final trailPos = _historyPositions[i];
        final relativeOffset = trailPos - position; 
        final opacity = (i + 1) * 0.15; 
        canvas.save();
        canvas.translate(relativeOffset.x, relativeOffset.y);
        _drawSingleBottle(canvas, opacity);
        canvas.restore();
      }
    }
    _drawSingleBottle(canvas, 1.0);
  }

  void _drawSingleBottle(Canvas canvas, double globalOpacity) {
    final themeColor = isOrganic ? Colors.green : Colors.blue;
    double offsetX = (size.x - 40) / 2;
    double offsetY = (size.y - 80) / 2;

    final bodyRect = Rect.fromLTWH(offsetX, offsetY + 18, 40, 80 - 18);
    final rrect = RRect.fromRectAndRadius(bodyRect, const Radius.circular(8));

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          themeColor.shade300.withOpacity(0.9 * globalOpacity),
          themeColor.shade600.withOpacity(0.95 * globalOpacity),
          themeColor.shade900.withOpacity(0.9 * globalOpacity),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(bodyRect)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(rrect, bodyPaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.25 * globalOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(offsetX + 6, offsetY + 24), Offset(offsetX + 6, offsetY + 70), highlightPaint);

    final capRect = Rect.fromLTWH(offsetX + 14, offsetY, 12, 18);
    final capPaint = Paint()..color = Colors.white.withOpacity(globalOpacity)..style = PaintingStyle.fill;
    canvas.drawRect(capRect, capPaint);

    final labelRect = Rect.fromLTWH(2 + offsetX, offsetY + 80 * 0.4, 40 - 4, 80 * 0.25);
    final labelPaint = Paint()..color = Colors.white.withOpacity(0.95 * globalOpacity)..style = PaintingStyle.fill;
    canvas.drawRect(labelRect, labelPaint);

    final glowPulse = 0.7 + sin(_timeElapsed * 7.5) * 0.3; 
    final symbolPaint = Paint()
      ..color = themeColor.withOpacity(glowPulse * globalOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 + (glowPulse * 0.5);

    final center = Offset(offsetX + 20, offsetY + 80 * 0.525);
    final radius = 6.0 * (0.9 + glowPulse * 0.1); 
    
    final path = Path();
    final p1 = Offset(center.dx, center.dy - radius);
    final p2 = Offset(center.dx + radius * sin(pi / 3), center.dy + radius * cos(pi / 3));
    final p3 = Offset(center.dx - radius * sin(pi / 3), center.dy + radius * cos(pi / 3));

    path.moveTo(p1.dx, p1.dy);
    path.lineTo(p2.dx, p2.dy);
    path.lineTo(p3.dx, p3.dy);
    path.close();

    canvas.drawPath(path, symbolPaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef._isEngineStopped) return;

    _timeElapsed += dt;

    if (!_isDragged) {
      _historyPositions.add(position.clone());
      if (_historyPositions.length > _maxHistoryLength) {
        _historyPositions.removeAt(0);
      }

      position.y += speedFactor * dt; 

      switch (_trajectoryType) {
        case 0:
          break;
        case 1:
          position.x += _diagonalDirection * 55.0 * dt; 
          break;
        case 2:
          double wave = sin(_timeElapsed * _waveFrequency) * _waveAmplitude;
          position.x = (_startX - 20.0) + wave;
          break;
        case 3:
          double wave = sin(_timeElapsed * _waveFrequency) * _waveAmplitude;
          position.x = (_startX + 20.0) + wave;
          break;
      }

      if (position.x < 0) position.x = 0;
      if (position.x > gameWidth - size.x) position.x = gameWidth - size.x;

      if (position.y > gameRef.size.y) {
        removeFromParent();
        _reduceLife();
      }
    } else {
      _historyPositions.clear(); 
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _isDragged = true;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    position += event.localDelta;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _isDragged = false;

    final endX = position.x + size.x / 2;
    final isLeftZone = endX < gameRef.size.x / 2;
    final centerPosition = position + (size / 2);

    if (isOrganic) {
      if (isLeftZone) {
        gameRef.scoreNotifier.value += 10;
        gameRef.createBurstParticles(centerPosition, Colors.green);
        removeFromParent();
      } else {
        HapticFeedback.vibrate();
        removeFromParent();
        _reduceLife();
      }
    } else {
      if (!isLeftZone) {
        gameRef.scoreNotifier.value += 10;
        gameRef.createBurstParticles(centerPosition, Colors.blue);
        removeFromParent();
      } else {
        HapticFeedback.vibrate();
        removeFromParent();
        _reduceLife();
      }
    }
  }

  void _reduceLife() {
    if (gameRef.livesNotifier.value > 0) {
      gameRef.livesNotifier.value--;
      if (gameRef.livesNotifier.value == 0) {
        gameRef._triggerGameOver();
      }
    }
  }
}