import 'dart:ui';

import 'package:flutter/material.dart';

/// Greca escalonada (como las de Mitla) bordada con puntada corrida.
/// Se "cose" una sola vez al abrir la app.
class GrecaBordada extends StatefulWidget {
  const GrecaBordada({super.key, this.color = Colors.white, this.alto = 26});
  final Color color;
  final double alto;

  @override
  State<GrecaBordada> createState() => _GrecaBordadaState();
}

class _GrecaBordadaState extends State<GrecaBordada> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.alto,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _GrecaPainter(Curves.easeInOutCubic.transform(_c.value), widget.color),
        ),
      ),
    );
  }
}

class _GrecaPainter extends CustomPainter {
  _GrecaPainter(this.progreso, this.color);
  final double progreso;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final u = h / 3; // unidad de la greca
    final ruta = Path()..moveTo(0, h);
    double x = 0;
    while (x < size.width) {
      ruta
        ..lineTo(x + u, h)
        ..lineTo(x + u, u)
        ..lineTo(x + 3 * u, u)
        ..lineTo(x + 3 * u, 2 * u)
        ..lineTo(x + 2 * u, 2 * u)
        ..moveTo(x + 3 * u, h)
        ..lineTo(x + 4 * u, h);
      x += 4 * u;
    }
    final pincel = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Puntada corrida: segmentos de 5 px con huecos de 4 px, hasta donde va el progreso.
    final metricas = ruta.computeMetrics().toList();
    final total = metricas.fold<double>(0, (s, m) => s + m.length);
    var restante = total * progreso;
    for (final PathMetric m in metricas) {
      if (restante <= 0) break;
      final limite = restante.clamp(0, m.length).toDouble();
      for (double d = 0; d < limite; d += 9) {
        canvas.drawPath(m.extractPath(d, (d + 5).clamp(0, limite).toDouble()), pincel);
      }
      restante -= m.length;
    }
  }

  @override
  bool shouldRepaint(_GrecaPainter old) => old.progreso != progreso || old.color != color;
}
