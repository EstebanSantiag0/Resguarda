import 'package:flutter/material.dart';

import '../sesion.dart';
import '../theme.dart';

/// Burbuja de chat que entra deslizándose desde su lado.
class Burbuja extends StatelessWidget {
  const Burbuja({super.key, required this.mensaje});
  final Mensaje mensaje;

  @override
  Widget build(BuildContext context) {
    final propia = mensaje.deUsuaria;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: movimiento(context, 260),
      curve: Curves.easeOutCubic,
      builder: (_, t, hijo) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset((propia ? 16 : -16) * (1 - t), 6 * (1 - t)), child: hijo),
      ),
      child: Align(
        alignment: propia ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              color: propia ? Paleta.ciruela : Colors.white,
              border: propia ? null : Border.all(color: Paleta.linea),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(propia ? 16 : 4),
                bottomRight: Radius.circular(propia ? 4 : 16),
              ),
            ),
            child: SelectableText(
              mensaje.texto,
              style: TextStyle(color: propia ? Colors.white : Paleta.tinta, fontSize: 15.5, height: 1.45),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tres puntadas que se van marcando mientras el modelo responde.
class Escribiendo extends StatefulWidget {
  const Escribiendo({super.key});

  @override
  State<Escribiendo> createState() => _EscribiendoState();
}

class _EscribiendoState extends State<Escribiendo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Paleta.linea),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Semantics(
          label: 'Resguarda está escribiendo',
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final fase = ((_c.value * 3) - i).clamp(0.0, 1.0);
                final activo = MediaQuery.of(context).disableAnimations || fase > 0 && fase < 1;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 12,
                  height: 3,
                  decoration: BoxDecoration(
                    color: activo ? Paleta.ciruela : Paleta.linea,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
