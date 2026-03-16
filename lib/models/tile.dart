class Tile {
  final String id;
  final int row;
  final int col;
  final int value;
  final bool isNew;
  final bool isMerged;

  const Tile({
    required this.id,
    required this.row,
    required this.col,
    required this.value,
    this.isNew = false,
    this.isMerged = false,
  });

  Tile copyWith({
    String? id,
    int? row,
    int? col,
    int? value,
    bool? isNew,
    bool? isMerged,
  }) {
    return Tile(
      id: id ?? this.id,
      row: row ?? this.row,
      col: col ?? this.col,
      value: value ?? this.value,
      isNew: isNew ?? this.isNew,
      isMerged: isMerged ?? this.isMerged,
    );
  }
}
