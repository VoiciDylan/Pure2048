class Msg {
  final String id;
  final String body;
  final String src;        // user uid
  final String nick;       // display nickname
  final int ts;
  final String? voiceRef;
  final Map<String, dynamic>? reads; // { userId: true }

  const Msg({
    required this.id,
    required this.body,
    required this.src,
    required this.nick,
    required this.ts,
    this.voiceRef,
    this.reads,
  });

  bool get isVoice => voiceRef != null && voiceRef!.isNotEmpty;

  /// Returns true if anyone other than [selfId] has read this message.
  bool isReadBy(String selfId) {
    if (reads == null) return false;
    return reads!.keys.any((k) => k != selfId);
  }

  factory Msg.fromMap(String id, Map<dynamic, dynamic> m) {
    return Msg(
      id: id,
      body: (m['b'] as String?) ?? '',
      src: (m['s'] as String?) ?? '',
      nick: (m['n'] as String?) ?? '?',
      ts: (m['t'] as int?) ?? 0,
      voiceRef: m['v'] as String?,
      reads: m['r'] != null
          ? Map<String, dynamic>.from(m['r'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'b': body,
    's': src,
    'n': nick,
    't': ts,
    if (voiceRef != null) 'v': voiceRef,
    // 'r' (reads) is written separately via markRead — not included on push
  };
}
