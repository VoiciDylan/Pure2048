import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';
import '../models/tile.dart';
import 'access_screen.dart';

// ─────────────────────────────────────────────
// 每个 Tile 独立管理自己的动画
// ─────────────────────────────────────────────
class _TileWidget extends StatefulWidget {
  final Tile tile;
  final double size;
  const _TileWidget({required Key key, required this.tile, required this.size})
      : super(key: key);

  @override
  State<_TileWidget> createState() => _TileWidgetState();
}

class _TileWidgetState extends State<_TileWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    if (widget.tile.isNew) {
      // 新生成：从 0 缩放到 1
      _ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 180));
      _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
      _ctrl.forward();
    } else if (widget.tile.isMerged) {
      // 合并：弹出 pulse：1 → 1.15 → 1
      _ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 160));
      _scale = TweenSequence<double>([
        TweenSequenceItem(
            tween: Tween(begin: 0.0, end: 1.15)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 60),
        TweenSequenceItem(
            tween: Tween(begin: 1.15, end: 1.0)
                .chain(CurveTween(curve: Curves.easeIn)),
            weight: 40),
      ]).animate(_ctrl);
      _ctrl.forward();
    } else {
      // 普通移动：无独立动画，用 AnimatedPositioned 处理位移
      _ctrl = AnimationController(vsync: this, duration: Duration.zero);
      _scale = const AlwaysStoppedAnimation(1.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tile;
    final fontSize = t.value >= 1000
        ? widget.size * 0.28
        : t.value >= 100
            ? widget.size * 0.34
            : widget.size * 0.44;

    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _tileColor(t.value),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          '${t.value}',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: t.value <= 4 ? const Color(0xFF776E65) : Colors.white,
          ),
        ),
      ),
    );
  }

  static Color _tileColor(int v) {
    switch (v) {
      case 2:    return const Color(0xFFEEE4DA);
      case 4:    return const Color(0xFFEDE0C8);
      case 8:    return const Color(0xFFF2B179);
      case 16:   return const Color(0xFFF59563);
      case 32:   return const Color(0xFFF67C5F);
      case 64:   return const Color(0xFFF65E3B);
      case 128:  return const Color(0xFFEDCF72);
      case 256:  return const Color(0xFFEDCC61);
      case 512:  return const Color(0xFFEDC850);
      case 1024: return const Color(0xFFEDC53F);
      case 2048: return const Color(0xFFEDC22E);
      default:   return const Color(0xFF3C3A32);
    }
  }
}

// ─────────────────────────────────────────────
// 主游戏页面
// ─────────────────────────────────────────────
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState _game;
  bool _inputLocked = false;

  // 隐藏入口
  int _tapCount = 0;
  DateTime? _lastTapTime;

  // 滑动追踪
  Offset? _panStart;
  Offset? _panEnd;

  // 键盘焦点
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initGame();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _focusNode.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft)  { _handleSlide(SlideDirection.left);  return true; }
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) { _handleSlide(SlideDirection.right); return true; }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp)    { _handleSlide(SlideDirection.up);    return true; }
    if (e.logicalKey == LogicalKeyboardKey.arrowDown)  { _handleSlide(SlideDirection.down);  return true; }
    return false;
  }

  Future<void> _initGame() async {
    final prefs = await SharedPreferences.getInstance();
    final best = prefs.getInt('best') ?? 0;
    setState(() => _game = GameState.initial(best));
  }

  Future<void> _saveBest(int best) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('best', best);
  }

  void _handleSlide(SlideDirection dir) {
    if (_inputLocked) return;
    final next = _game.slide(dir);
    if (identical(next, _game)) return;
    _inputLocked = true;
    setState(() => _game = next);
    if (next.best > _game.best) _saveBest(next.best);
    // 动画结束后解锁（滑动 120ms + 新 tile 出现 180ms，取最长）
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _inputLocked = false);
    });
  }

  void _restart() {
    setState(() => _game = GameState.initial(_game.best));
    _inputLocked = false;
  }

  void _onScoreTap() {
    final now = DateTime.now();
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!) > const Duration(seconds: 3)) {
      _tapCount = 0;
    }
    _tapCount++;
    _lastTapTime = now;
    if (_tapCount >= 7) {
      _tapCount = 0;
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const AccessScreen()));
    }
  }

  // ── Build ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8EF),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) {
            _panStart = d.globalPosition;
            _panEnd   = d.globalPosition;
          },
          onPanUpdate: (d) => _panEnd = d.globalPosition,
          onPanEnd: (_) {
            if (_panStart == null || _panEnd == null) return;
            final dx = _panEnd!.dx - _panStart!.dx;
            final dy = _panEnd!.dy - _panStart!.dy;
            if (dx.abs() < 10 && dy.abs() < 10) return;
            if (dx.abs() > dy.abs()) {
              if (dx > 0) { _handleSlide(SlideDirection.right); }
              else        { _handleSlide(SlideDirection.left);  }
            } else {
              if (dy > 0) { _handleSlide(SlideDirection.down); }
              else        { _handleSlide(SlideDirection.up);   }
            }
            _panStart = null;
            _panEnd   = null;
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              _buildHint(),
              const SizedBox(height: 12),
              _buildBoard(),
              if (_game.isOver)   _buildOverlay('Game Over!'),
              if (_game.hasWon && !_game.isOver) _buildOverlay('You Win!'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('2048',
              style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF776E65))),
          Row(children: [
            _scoreCard('SCORE', _game.score, tappable: true),
            const SizedBox(width: 8),
            _scoreCard('BEST', _game.best),
          ]),
        ],
      ),
    );
  }

  Widget _scoreCard(String label, int value, {bool tappable = false}) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFBBADA0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFFEEE4DA), fontSize: 11, fontWeight: FontWeight.bold)),
        Text('$value',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ]),
    );
    return tappable ? GestureDetector(onTap: _onScoreTap, child: card) : card;
  }

  Widget _buildHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Join the tiles, get to 2048!',
              style: TextStyle(color: Color(0xFF776E65), fontSize: 13)),
          GestureDetector(
            onTap: _restart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFF8F7A66),
                  borderRadius: BorderRadius.circular(4)),
              child: const Text('New Game',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          // 4 格 + 5 个间距(含外边距) = w，间距固定8
          // Container 自身有 padding 8，所以内部: w - 16 = 4*cell + 3*gap
          final cellSize = (w - 16 - 8 * 3) / 4;
          final gap = 8.0;
          final pad = 8.0;

          double left(int c) => pad + c * (cellSize + gap);
          double top(int r)  => pad + r * (cellSize + gap);

          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFBBADA0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(children: [
              // 背景格
              for (int r = 0; r < 4; r++)
                for (int c = 0; c < 4; c++)
                  Positioned(
                    top:    top(r),
                    left:   left(c),
                    width:  cellSize,
                    height: cellSize,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFCDC1B4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
              // 数字格
              for (final tile in _game.tiles)
                AnimatedPositioned(
                  key: ValueKey(tile.id),
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeInOut,
                  top:    top(tile.row),
                  left:   left(tile.col),
                  width:  cellSize,
                  height: cellSize,
                  child: _TileWidget(
                    key: ValueKey('w_${tile.id}'),
                    tile: tile,
                    size: cellSize,
                  ),
                ),
            ]),
          );
        }),
      ),
    );
  }

  Widget _buildOverlay(String msg) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEEE4DA).withValues(alpha: 0.93),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Text(msg,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF776E65))),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _restart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFF8F7A66),
                  borderRadius: BorderRadius.circular(4)),
              child: const Text('Try Again',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}
