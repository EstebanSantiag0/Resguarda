import 'package:flutter/material.dart';

import '../salida.dart';
import '../services/gemma.dart';
import '../theme.dart';
import 'pressable.dart';

/// Página con el encabezado de Resguarda y el contenido centrado (máx. 760 px, como la web).
class Pagina extends StatelessWidget {
  const Pagina({super.key, required this.children, this.pie});
  final List<Widget> children;
  final Widget? pie;

  @override
  Widget build(BuildContext context) {
    final m = margenLateral(context);
    return Scaffold(
      body: SafeArea(
        bottom: pie == null,
        child: ListView(
          padding: EdgeInsets.fromLTRB(m, 18, m, 48),
          children: [const Encabezado(), const SizedBox(height: 26), ...children],
        ),
      ),
      bottomNavigationBar: pie,
    );
  }
}

/// Logo + nombre, indicador de privacidad y salida rápida. Si hay pantalla anterior, flecha de regreso.
class Encabezado extends StatelessWidget {
  const Encabezado({super.key});

  @override
  Widget build(BuildContext context) {
    final puedeVolver = Navigator.of(context).canPop();
    return Row(
      children: [
        if (puedeVolver)
          IconButton(
            tooltip: 'Regresar',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              foregroundColor: Paleta.tinta,
              hoverColor: Paleta.neutro,
              highlightColor: Paleta.neutroHover,
            ),
          ),
        const Logo(tamano: 38),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('Resguarda',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
        ),
        const _Indicador(),
        const BotonSalir(),
      ],
    );
  }
}

class Logo extends StatelessWidget {
  const Logo({super.key, this.tamano = 38});
  final double tamano;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(tamano * 0.28),
        child: Image.asset('assets/icon/logo.png', width: tamano, height: tamano, semanticLabel: 'Logo de Resguarda'),
      );
}

class _Indicador extends StatelessWidget {
  const _Indicador();

  @override
  Widget build(BuildContext context) {
    final color = modoPrivado ? Paleta.verde : Paleta.gris;
    // En pantallas angostas solo se ve el punto; el texto completo queda en el tooltip.
    final angosta = MediaQuery.sizeOf(context).width < 420;
    return Tooltip(
      message: modoPrivado
          ? '$modoModelo: tu relato no sale de este dispositivo o de la laptop del equipo.'
          : '$modoModelo: el relato se envía a Google para que Gemma responda.',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          if (!angosta) ...[
            const SizedBox(width: 7),
            Text(modoModelo, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          ],
        ]),
      ),
    );
  }
}

/// Título grande + texto de apoyo (como el "hero" de la web), al inicio de cada pantalla.
class Portada extends StatelessWidget {
  const Portada({super.key, this.ceja, required this.titulo, this.texto});
  final String? ceja;
  final String titulo;
  final String? texto;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (ceja != null) Ceja(ceja!),
      Semantics(header: true, child: Text(titulo, style: t.displaySmall)),
      if (texto != null) ...[
        const SizedBox(height: 10),
        Text(texto!, style: t.bodyLarge?.copyWith(color: Paleta.gris)),
      ],
    ]);
  }
}

class Ceja extends StatelessWidget {
  const Ceja(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(texto.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Paleta.ciruela)),
      );
}

class Tarjeta extends StatelessWidget {
  const Tarjeta({super.key, this.ceja, this.titulo, this.pista, required this.children});
  final String? ceja;
  final String? titulo;
  final String? pista;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 22),
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 540 ? 19 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Paleta.linea),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (ceja != null) Ceja(ceja!),
        if (titulo != null) Semantics(header: true, child: Text(titulo!, style: t.headlineSmall)),
        if (pista != null) ...[
          const SizedBox(height: 6),
          Text(pista!, style: t.bodyMedium?.copyWith(color: Paleta.gris)),
        ],
        if (titulo != null || pista != null) const SizedBox(height: 18),
        ...children,
      ]),
    );
  }
}

enum Estilo { primario, secundario, peligro, contorno }

/// Botón con estados hover/presionado/foco (Pressable) en los 4 estilos del prototipo web.
class Boton extends StatelessWidget {
  const Boton(this.texto, {super.key, required this.onTap, this.estilo = Estilo.primario, this.icono, this.cargando = false});
  final String texto;
  final VoidCallback? onTap;
  final Estilo estilo;
  final IconData? icono;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final (fondo, hover, letra, borde) = switch (estilo) {
      Estilo.primario => (Paleta.ciruela, Paleta.ciruelaOscura, Colors.white, Paleta.ciruela),
      Estilo.secundario => (Paleta.neutro, Paleta.neutroHover, Paleta.tinta, Paleta.neutro),
      Estilo.peligro => (Paleta.rojo, Paleta.rojoOscuro, Colors.white, Paleta.rojo),
      Estilo.contorno => (Colors.transparent, Paleta.ciruelaSuave, Paleta.ciruela, Paleta.ciruela),
    };
    final activo = onTap != null && !cargando;
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: Pressable(
        onTap: activo ? onTap : null,
        color: fondo,
        colorHover: hover,
        borde: borde,
        radio: 11,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        semantica: texto,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (cargando)
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: letra))
          else if (icono != null)
            Icon(icono, size: 20, color: letra),
          if (cargando || icono != null) const SizedBox(width: 9),
          Flexible(
            child: Text(texto,
                textAlign: TextAlign.center, style: TextStyle(color: letra, fontWeight: FontWeight.w700, fontSize: 15.5)),
          ),
        ]),
      ),
    );
  }
}

/// Dos botones lado a lado; en pantallas angostas, uno debajo del otro.
class FilaBotones extends StatelessWidget {
  const FilaBotones({super.key, required this.izquierda, required this.derecha});
  final Widget izquierda;
  final Widget derecha;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 540) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [izquierda, const SizedBox(height: 10), derecha]);
    }
    return Row(children: [Expanded(child: izquierda), const SizedBox(width: 10), Expanded(child: derecha)]);
  }
}

/// Aviso de color (rojo = riesgo, verde = listo).
class Aviso extends StatelessWidget {
  const Aviso({super.key, required this.child, this.peligro = false});
  final Widget child;
  final bool peligro;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: peligro ? Paleta.rojoSuave : Paleta.verdeSuave,
          borderRadius: BorderRadius.circular(12),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: peligro ? const Color(0xFF851B14) : Paleta.verde, height: 1.5),
          child: child,
        ),
      );
}

/// Entrada suave al cambiar de pantalla (sin animación si se pide reducir movimiento).
class Aparecer extends StatelessWidget {
  const Aparecer({super.key, required this.child, this.orden = 0});
  final Widget child;
  final int orden;

  @override
  Widget build(BuildContext context) {
    final duracion = movimiento(context, 320 + orden * 70);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duracion,
      curve: Curves.easeOutCubic,
      builder: (_, t, hijo) =>
          Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: hijo)),
      child: child,
    );
  }
}

const letraFina = TextStyle(fontSize: 12, color: Paleta.gris, height: 1.5);
