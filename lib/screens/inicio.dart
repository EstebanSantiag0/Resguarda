import 'package:flutter/material.dart';

import '../salida.dart';
import '../sesion.dart';
import '../theme.dart';
import '../widgets/greca.dart';
import '../widgets/pressable.dart';
import 'chat.dart';
import 'evidencias.dart';

class Inicio extends StatelessWidget {
  const Inicio({super.key});

  void _abrirChat(BuildContext context, Situacion s) {
    Sesion.instancia.iniciar(s);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Chat()));
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final m = margenLateral(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: Paleta.anil,
              padding: EdgeInsets.fromLTRB(m, MediaQuery.of(context).padding.top + 8, m - 8, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Align(alignment: Alignment.centerRight, child: BotonSalir()),
                  const SizedBox(height: 12),
                  Text('Resguarda', style: texto.displaySmall?.copyWith(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    'Orientación privada si vives violencia digital. No necesitas cuenta y no se guarda nada al salir.',
                    style: texto.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 22),
                  const GrecaBordada(color: Color(0xFFE7B7C6)),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(m, 26, m, 8),
            sliver: SliverToBoxAdapter(child: Text('¿Qué está pasando?', style: texto.headlineSmall)),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: m),
            sliver: SliverList.separated(
              itemCount: situaciones.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _Entrada(
                orden: i,
                child: Pressable(
                  onTap: () => _abrirChat(context, situaciones[i]),
                  colorHover: const Color(0xFFF7F8FC),
                  semantica: situaciones[i].titulo,
                  child: Row(
                    children: [
                      Expanded(child: Text(situaciones[i].titulo, style: texto.titleMedium)),
                      const Icon(Icons.chevron_right, color: Paleta.anil),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(m, 14, m, 0),
            sliver: SliverToBoxAdapter(
              child: _Entrada(
                orden: situaciones.length,
                child: Pressable(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Evidencias())),
                  color: Colors.transparent,
                  colorHover: Colors.white,
                  semantica: 'Mis evidencias',
                  child: Row(
                    children: [
                      const Icon(Icons.fingerprint, color: Paleta.cantera),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Registrar mis capturas como evidencia', style: texto.titleMedium)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      // Siempre visible, sin necesidad de desplazarse.
      bottomNavigationBar: const _Emergencia(),
    );
  }
}

/// Entrada escalonada de las opciones, justo después de que termina la greca.
class _Entrada extends StatelessWidget {
  const _Entrada({required this.orden, required this.child});
  final int orden;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duracion = movimiento(context, 900 + orden * 90);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duracion,
      curve: Interval(duracion == Duration.zero ? 0 : 0.6, 1, curve: Curves.easeOutCubic),
      builder: (_, t, hijo) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: hijo),
      ),
      child: child,
    );
  }
}

class _Emergencia extends StatelessWidget {
  const _Emergencia();

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Paleta.hilo))),
      padding: EdgeInsets.fromLTRB(margenLateral(context), 12, margenLateral(context), MediaQuery.of(context).padding.bottom + 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Estás en peligro ahora?', style: texto.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: () => llamar('911'),
                  color: Paleta.grana,
                  colorHover: const Color(0xFF8A1238),
                  borde: Paleta.grana,
                  semantica: 'Llamar al 911',
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.call, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Llamar al 911', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Pressable(
                  onTap: () => llamar('089'),
                  colorHover: const Color(0xFFF7F8FC),
                  semantica: 'Denuncia anónima al 089',
                  child: const Text(
                    'Denuncia anónima 089',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600, color: Paleta.anil),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
