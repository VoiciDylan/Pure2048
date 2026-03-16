import 'package:flutter/material.dart';
import 'game_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    _ctrl.forward();

    // Navigate to game after splash
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const GameScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8EF),
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: _buildLogo(),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 2048 tile
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFFEDC22E),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEDC22E).withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            '2048',
            style: TextStyle(
              color: Colors.white,
              fontSize: 52,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Pure2048',
          style: TextStyle(
            color: Color(0xFF8F7A66),
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}
