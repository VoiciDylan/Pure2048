import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/msg.dart';
import '../services/store_svc.dart';

String _fmtTime(int ts) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ts);
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class ChannelScreen extends StatefulWidget {
  final String nodeId;
  final String nick;
  const ChannelScreen({super.key, required this.nodeId, required this.nick});

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen>
    with WidgetsBindingObserver {
  late final StoreSvc _svc;
  late final AudioRecorder _recorder;
  late final AudioPlayer _player;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String _selfId = '';
  bool _isCapturing = false;
  String? _activeAudioId;   // which voice msg is playing
  String? _tmpPath;
  final Set<String> _markedRead = {}; // avoid re-marking on every stream event

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _svc = StoreSvc(widget.nodeId);
    _recorder = AudioRecorder();
    _player = AudioPlayer();
    _player.onPlayerComplete.listen((_) => setState(() => _activeAudioId = null));
    _loadSelfId();
  }

  Future<void> _loadSelfId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('_uid');
    if (id == null) {
      id = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      await prefs.setString('_uid', id);
    }
    setState(() => _selfId = id!);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && mounted) {
      _recorder.cancel();
      _player.stop();
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recorder.dispose();
    _player.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Text send ──────────────────────────────────────────────
  Future<void> _sendText() async {
    final txt = _inputCtrl.text.trim();
    if (txt.isEmpty) return;
    _inputCtrl.clear();
    await _svc.push(Msg(
      id: '',
      body: txt,
      src: _selfId,
      nick: widget.nick,
      ts: DateTime.now().millisecondsSinceEpoch,
    ));
    _scrollToBottom();
  }

  // ── Voice capture ──────────────────────────────────────────
  Future<void> _startCapture() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;
    final dir = await getTemporaryDirectory();
    _tmpPath = '${dir.path}/v_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _tmpPath!,
    );
    setState(() => _isCapturing = true);
    HapticFeedback.mediumImpact();
  }

  Future<void> _stopCapture() async {
    if (!_isCapturing) return;
    final path = await _recorder.stop();
    setState(() => _isCapturing = false);
    HapticFeedback.lightImpact();
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;

    // Upload and push
    final name = '${DateTime.now().millisecondsSinceEpoch}.m4a';
    final url = await _svc.uploadVoice(file, name);
    await _svc.push(Msg(
      id: '',
      body: '',
      src: _selfId,
      nick: widget.nick,
      ts: DateTime.now().millisecondsSinceEpoch,
      voiceRef: url,
    ));
    _scrollToBottom();
  }

  Future<void> _cancelCapture() async {
    await _recorder.cancel();
    setState(() => _isCapturing = false);
  }

  // ── Audio playback ─────────────────────────────────────────
  Future<void> _togglePlay(Msg m) async {
    if (_activeAudioId == m.id) {
      await _player.stop();
      setState(() => _activeAudioId = null);
      return;
    }
    await _player.stop();
    setState(() => _activeAudioId = m.id);
    await _player.play(UrlSource(m.voiceRef!));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF8EF),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios, color: Color(0xFF8F7A66), size: 20),
        ),
        title: Text(
          widget.nodeId,
          style: const TextStyle(color: Color(0xFFBBADA0), fontSize: 14, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(child: _buildList()),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<List<Msg>>(
      stream: _svc.stream(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFBBADA0), strokeWidth: 2));
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return const Center(
            child: Text('· · ·', style: TextStyle(color: Color(0xFFCDC1B4), fontSize: 24, letterSpacing: 8)),
          );
        }
        // Mark incoming messages as read (only once per message ID)
        if (_selfId.isNotEmpty) {
          for (final m in items) {
            if (m.src != _selfId && !_markedRead.contains(m.id)) {
              _markedRead.add(m.id);
              _svc.markRead(m.id, _selfId);
            }
          }
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: items.length,
          itemBuilder: (_, i) => _buildBubble(items[i]),
        );
      },
    );
  }

  Widget _buildBubble(Msg m) {
    final isSelf = m.src == _selfId;
    final timeStr = _fmtTime(m.ts);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender nickname (others only)
          if (!isSelf)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(m.nick,
                  style: const TextStyle(color: Color(0xFFBBADA0), fontSize: 11)),
            ),
          // Bubble row
          Row(
            mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Read status + time (left of bubble for self, hidden for others)
              if (isSelf) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      m.isReadBy(_selfId) ? '已读' : '未读',
                      style: TextStyle(
                        fontSize: 10,
                        color: m.isReadBy(_selfId)
                            ? const Color(0xFF8F7A66)
                            : const Color(0xFFCDC1B4),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(timeStr,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFFCDC1B4))),
                  ],
                ),
                const SizedBox(width: 6),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.62),
                child: Container(
                  padding: m.isVoice
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                      : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelf
                        ? const Color(0xFFEDC850)
                        : const Color(0xFFEEE4DA),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isSelf ? 16 : 4),
                      bottomRight: Radius.circular(isSelf ? 4 : 16),
                    ),
                  ),
                  child: m.isVoice ? _voiceContent(m) : _textContent(m),
                ),
              ),
              // Time (right of bubble for others)
              if (!isSelf) ...[
                const SizedBox(width: 6),
                Text(timeStr,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFFCDC1B4))),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _textContent(Msg m) {
    return Text(m.body, style: const TextStyle(color: Color(0xFF776E65), fontSize: 15));
  }

  Widget _voiceContent(Msg m) {
    final isPlaying = _activeAudioId == m.id;
    return GestureDetector(
      onTap: () => _togglePlay(m),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
            color: const Color(0xFF776E65),
            size: 22,
          ),
          const SizedBox(width: 6),
          // Simple waveform placeholder
          Row(
            children: List.generate(
              12,
              (i) => Container(
                width: 3,
                height: (4 + (i % 4) * 4).toDouble(),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: isPlaying
                      ? const Color(0xFF8F7A66)
                      : const Color(0xFFBBADA0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8EF),
        border: Border(top: BorderSide(color: Color(0xFFEEE4DA), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              style: const TextStyle(color: Color(0xFF776E65), fontSize: 15),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendText(),
              decoration: InputDecoration(
                hintText: '···',
                hintStyle: const TextStyle(color: Color(0xFFCDC1B4)),
                filled: true,
                fillColor: const Color(0xFFEEE4DA),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button (shows when text is not empty)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _inputCtrl,
            builder: (context, val, child) {
              if (val.text.trim().isNotEmpty) {
                return GestureDetector(
                  onTap: _sendText,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDC850),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                  ),
                );
              }
              // Voice button
              return GestureDetector(
                onLongPressStart: (_) => _startCapture(),
                onLongPressEnd: (_) => _stopCapture(),
                onLongPressCancel: () => _cancelCapture(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isCapturing ? const Color(0xFFF65E3B) : const Color(0xFFBBADA0),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _isCapturing ? Icons.stop_rounded : Icons.mic_none_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
