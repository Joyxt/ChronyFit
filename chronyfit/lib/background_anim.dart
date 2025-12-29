import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class BackgroundAnim extends StatefulWidget {
  final Widget child;

  const BackgroundAnim({super.key, required this.child});

  @override
  State<BackgroundAnim> createState() => _BackgroundAnimState();
}

class _BackgroundAnimState extends State<BackgroundAnim>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _time = 0.0;
  FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker((elapsed) {
      setState(() {
        _time = elapsed.inMilliseconds / 1000.0;
      });
    });
    _ticker.start();
  }

  Future<void> _loadShader() async {
    try {
      // Chemin vers le Shader
      final program = await FragmentProgram.fromAsset(
        'shaders/background.frag',
      );
      setState(() {
        _program = program;
      });
    } catch (e) {
      debugPrint('Erreur shader background: $e');
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_program == null) {
      // Fond de secours si le shader ne charge pas
      return Container(color: const Color(0xFF1E1E1E), child: widget.child);
    }

    return CustomPaint(
      painter: BackgroundPainter(
        shader: _program!.fragmentShader(),
        time: _time,
      ),
      child: widget.child,
    );
  }
}

class BackgroundPainter extends CustomPainter {
  final FragmentShader shader;
  final double time;

  BackgroundPainter({required this.shader, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant BackgroundPainter oldDelegate) =>
      oldDelegate.time != time;
}
