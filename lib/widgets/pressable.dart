import 'package:flutter/material.dart';

import '../theme.dart';

/// Superficie tocable con estados: hover (mouse), presionado (dedo), foco (teclado).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.color = Colors.white,
    this.colorHover,
    this.borde = Paleta.hilo,
    this.radio = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    this.semantica,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color? colorHover;
  final Color borde;
  final double radio;
  final EdgeInsets padding;
  final String? semantica;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hover = false;
  bool _presionado = false;
  bool _foco = false;

  @override
  Widget build(BuildContext context) {
    final activo = widget.onTap != null;
    final resaltado = activo && (_hover || _foco);
    return Semantics(
      button: true,
      label: widget.semantica,
      child: FocusableActionDetector(
        enabled: activo,
        mouseCursor: activo ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _foco = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: activo ? (_) => setState(() => _presionado = true) : null,
          onTapUp: activo ? (_) => setState(() => _presionado = false) : null,
          onTapCancel: () => setState(() => _presionado = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _presionado ? 0.97 : 1,
            duration: movimiento(context, 110),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: movimiento(context, 180),
              curve: Curves.easeOut,
              padding: widget.padding,
              transform: Matrix4.translationValues(0, resaltado && !_presionado ? -2 : 0, 0),
              decoration: BoxDecoration(
                color: resaltado ? (widget.colorHover ?? widget.color) : widget.color,
                borderRadius: BorderRadius.circular(widget.radio),
                border: Border.all(
                  color: _foco ? Paleta.anil : (resaltado ? Paleta.anil.withValues(alpha: 0.45) : widget.borde),
                  width: _foco ? 2.5 : 1.2,
                ),
                boxShadow: [
                  if (resaltado && !_presionado)
                    BoxShadow(color: Paleta.anil.withValues(alpha: 0.14), blurRadius: 14, offset: const Offset(0, 6)),
                ],
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
