import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'channel_screen.dart';

class AccessScreen extends StatefulWidget {
  const AccessScreen({super.key});

  @override
  State<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends State<AccessScreen> {
  final _codeCtrl = TextEditingController();
  final _nickCtrl = TextEditingController();
  String _hint = '';
  int _step = 0; // 0=输入暗号, 1=输入昵称

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nickCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final input = _codeCtrl.text.trim();
    if (input.length < 6) {
      setState(() => _hint = 'Invalid');
      return;
    }
    // 加载上次昵称
    final prefs = await SharedPreferences.getInstance();
    final savedNick = prefs.getString('_nick') ?? '';
    _nickCtrl.text = savedNick;
    setState(() { _step = 1; _hint = ''; });
  }

  Future<void> _enter() async {
    final nick = _nickCtrl.text.trim();
    if (nick.isEmpty) {
      setState(() => _hint = 'Please enter a name');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('_nick', nick);
    await prefs.setString('_k', _codeCtrl.text.trim());
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChannelScreen(
          nodeId: _codeCtrl.text.trim(),
          nick: nick,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8EF),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _step == 0 ? _buildCodeStep() : _buildNickStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeStep() {
    return Column(
      key: const ValueKey(0),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('——',
            style: TextStyle(fontSize: 28, color: Color(0xFFBBADA0), letterSpacing: 8)),
        const SizedBox(height: 32),
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 12,
          obscureText: true,
          style: const TextStyle(fontSize: 24, letterSpacing: 6, color: Color(0xFF776E65)),
          decoration: const InputDecoration(
            counterText: '',
            border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFBBADA0))),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFBBADA0))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8F7A66))),
            hintText: '· · · · · ·',
            hintStyle: TextStyle(color: Color(0xFFCDC1B4), letterSpacing: 8),
          ),
          onSubmitted: (_) => _verifyCode(),
        ),
        const SizedBox(height: 24),
        _primaryBtn('→', _verifyCode),
        if (_hint.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_hint, style: const TextStyle(color: Color(0xFFF65E3B), fontSize: 13)),
        ],
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text('←', style: TextStyle(color: Color(0xFFBBADA0), fontSize: 22)),
        ),
      ],
    );
  }

  Widget _buildNickStep() {
    return Column(
      key: const ValueKey(1),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('昵称',
            style: TextStyle(fontSize: 16, color: Color(0xFFBBADA0), letterSpacing: 4)),
        const SizedBox(height: 24),
        TextField(
          controller: _nickCtrl,
          textAlign: TextAlign.center,
          maxLength: 10,
          autofocus: true,
          style: const TextStyle(fontSize: 20, color: Color(0xFF776E65)),
          decoration: const InputDecoration(
            counterText: '',
            border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFBBADA0))),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFBBADA0))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8F7A66))),
            hintText: 'Name',
            hintStyle: TextStyle(color: Color(0xFFCDC1B4)),
          ),
          onSubmitted: (_) => _enter(),
        ),
        const SizedBox(height: 24),
        _primaryBtn('→', _enter),
        if (_hint.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_hint, style: const TextStyle(color: Color(0xFFF65E3B), fontSize: 13)),
        ],
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () => setState(() { _step = 0; _hint = ''; }),
          child: const Text('←', style: TextStyle(color: Color(0xFFBBADA0), fontSize: 22)),
        ),
      ],
    );
  }

  Widget _primaryBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF8F7A66),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 22)),
      ),
    );
  }
}
