import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class RunBackgroundAnim extends StatefulWidget {
  final Widget child;

  const RunBackgroundAnim({super.key, required this.child});

  @override
  State<RunBackgroundAnim> createState() => _RunBackgroundAnimState();
}

class _RunBackgroundAnimState extends State<RunBackgroundAnim>
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
      // CHARGEMENT DU NOUVEAU SHADER
      final program = await FragmentProgram.fromAsset(
        'shaders/run_background.frag',
      );
      setState(() {
        _program = program;
      });
    } catch (e) {
      debugPrint('Erreur shader run: $e');
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
      return Container(
        color: const Color(0xFF050010), // Fond de secours violet sombre
        child: widget.child,
      );
    }

    return CustomPaint(
      painter: RunShaderPainter(
        shader: _program!.fragmentShader(),
        time: _time,
      ),
      child: widget.child,
    );
  }
}

class RunShaderPainter extends CustomPainter {
  final FragmentShader shader;
  final double time;

  RunShaderPainter({required this.shader, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant RunShaderPainter oldDelegate) =>
      oldDelegate.time != time;
}
