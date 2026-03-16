import 'dart:math';
import 'tile.dart';

enum SlideDirection { up, down, left, right }

int _idCounter = 0;
String _newId() => '${++_idCounter}';

class GameState {
  final List<Tile> tiles;
  final int score;
  final int best;
  final bool isOver;
  final bool hasWon;

  const GameState({
    required this.tiles,
    required this.score,
    required this.best,
    this.isOver = false,
    this.hasWon = false,
  });

  static GameState initial(int savedBest) {
    final empty = GameState(tiles: [], score: 0, best: savedBest);
    return empty._withNewTile()._withNewTile();
  }

  List<List<int>> _toIntGrid() {
    final g = List.generate(4, (_) => List<int>.filled(4, 0));
    for (final t in tiles) {
      g[t.row][t.col] = t.value;
    }
    return g;
  }

  List<List<String?>> _toIdGrid() {
    final g = List.generate(4, (_) => List<String?>.filled(4, null));
    for (final t in tiles) {
      g[t.row][t.col] = t.id;
    }
    return g;
  }

  List<List<Tile?>> toGrid() {
    final g = List.generate(4, (_) => List<Tile?>.filled(4, null));
    for (final t in tiles) {
      g[t.row][t.col] = t;
    }
    return g;
  }

  int _getV(List<List<int>> g, int i, int j, SlideDirection dir) {
    switch (dir) {
      case SlideDirection.left:  return g[i][j];
      case SlideDirection.right: return g[i][3 - j];
      case SlideDirection.up:    return g[j][i];
      case SlideDirection.down:  return g[3 - j][i];
    }
  }

  String? _getS(List<List<String?>> g, int i, int j, SlideDirection dir) {
    switch (dir) {
      case SlideDirection.left:  return g[i][j];
      case SlideDirection.right: return g[i][3 - j];
      case SlideDirection.up:    return g[j][i];
      case SlideDirection.down:  return g[3 - j][i];
    }
  }

  void _setV(List<List<int>> g, int i, int j, SlideDirection dir, int v) {
    switch (dir) {
      case SlideDirection.left:  g[i][j] = v;
      case SlideDirection.right: g[i][3 - j] = v;
      case SlideDirection.up:    g[j][i] = v;
      case SlideDirection.down:  g[3 - j][i] = v;
    }
  }

  void _setS(List<List<String?>> g, int i, int j, SlideDirection dir, String? v) {
    switch (dir) {
      case SlideDirection.left:  g[i][j] = v;
      case SlideDirection.right: g[i][3 - j] = v;
      case SlideDirection.up:    g[j][i] = v;
      case SlideDirection.down:  g[3 - j][i] = v;
    }
  }

  GameState slide(SlideDirection dir) {
    final origVals = _toIntGrid();
    final origIds  = _toIdGrid();

    final nextVals    = List.generate(4, (_) => List<int>.filled(4, 0));
    final nextIds     = List.generate(4, (_) => List<String?>.filled(4, null));
    final nextMerged  = List.generate(4, (_) => List<bool>.filled(4, false));
    int gained = 0;

    for (int i = 0; i < 4; i++) {
      final vals = <int>[];
      final ids  = <String?>[];
      for (int j = 0; j < 4; j++) {
        final v = _getV(origVals, i, j, dir);
        if (v != 0) {
          vals.add(v);
          ids.add(_getS(origIds, i, j, dir));
        }
      }

      final mVals = <int>[];
      final mIds  = <String?>[];
      final mFlag = <bool>[];
      int j = 0;
      while (j < vals.length) {
        if (j + 1 < vals.length && vals[j] == vals[j + 1]) {
          final nv = vals[j] * 2;
          mVals.add(nv);
          mIds.add(_newId());
          mFlag.add(true);
          gained += nv;
          j += 2;
        } else {
          mVals.add(vals[j]);
          mIds.add(ids[j]);
          mFlag.add(false);
          j++;
        }
      }

      while (mVals.length < 4) {
        mVals.add(0);
        mIds.add(null);
        mFlag.add(false);
      }

      for (int j = 0; j < 4; j++) {
        _setV(nextVals, i, j, dir, mVals[j]);
        _setS(nextIds,  i, j, dir, mIds[j]);
        if (mFlag[j]) {
          // set merged flag on result grid
          switch (dir) {
            case SlideDirection.left:  nextMerged[i][j] = true;
            case SlideDirection.right: nextMerged[i][3 - j] = true;
            case SlideDirection.up:    nextMerged[j][i] = true;
            case SlideDirection.down:  nextMerged[3 - j][i] = true;
          }
        }
      }
    }

    bool moved = false;
    outer:
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        if (origVals[r][c] != nextVals[r][c]) {
          moved = true;
          break outer;
        }
      }
    }

    if (!moved) return this;

    final newTiles = <Tile>[];
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        if (nextVals[r][c] != 0) {
          newTiles.add(Tile(
            id: nextIds[r][c]!,
            row: r,
            col: c,
            value: nextVals[r][c],
            isMerged: nextMerged[r][c],
          ));
        }
      }
    }

    final newScore = score + gained;
    final newBest  = newScore > best ? newScore : best;
    final nextState = GameState(
      tiles: newTiles,
      score: newScore,
      best: newBest,
    )._withNewTile();

    return nextState.copyWith(
      hasWon: nextState.tiles.any((t) => t.value == 2048),
      isOver: nextState._checkGameOver(),
    );
  }

  GameState _withNewTile() {
    final g = _toIntGrid();
    final empty = <List<int>>[];
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        if (g[r][c] == 0) empty.add([r, c]);
      }
    }
    if (empty.isEmpty) return this;
    final pos = empty[Random().nextInt(empty.length)];
    final value = Random().nextDouble() < 0.9 ? 2 : 4;
    return copyWith(tiles: [
      ...tiles,
      Tile(id: _newId(), row: pos[0], col: pos[1], value: value, isNew: true),
    ]);
  }

  bool _checkGameOver() {
    final g = _toIntGrid();
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        if (g[r][c] == 0) return false;
        if (c + 1 < 4 && g[r][c] == g[r][c + 1]) return false;
        if (r + 1 < 4 && g[r][c] == g[r + 1][c]) return false;
      }
    }
    return true;
  }

  GameState copyWith({
    List<Tile>? tiles,
    int? score,
    int? best,
    bool? isOver,
    bool? hasWon,
  }) {
    return GameState(
      tiles: tiles ?? this.tiles,
      score: score ?? this.score,
      best: best ?? this.best,
      isOver: isOver ?? this.isOver,
      hasWon: hasWon ?? this.hasWon,
    );
  }
}
