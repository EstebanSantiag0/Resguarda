import 'package:flutter/material.dart';

import '../plan.dart' show fuentes;
import '../salida.dart';
import '../sesion.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'evidencias.dart';
import 'relato.dart';

/// Paso 0: antes de pedir cualquier dato, se pregunta si hay peligro.
class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  bool _emergencia = false;

  void _continuar({required bool riesgo}) {
    Sesion.instancia.marcarRiesgo(riesgo);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Relato()));
  }

  @override
  Widget build(BuildContext context) {
    return Pagina(children: [
      const Aparecer(
        child: Portada(
          titulo: 'Vamos paso a paso.',
          texto: 'Resguarda te ayuda a organizar información y evidencia en este dispositivo. '
              'No necesitas saber de tecnología ni crear una cuenta.',
        ),
      ),
      Aparecer(
        orden: 1,
        child: Tarjeta(
          ceja: 'Antes de empezar',
          titulo: '¿Estás en peligro ahora?',
          pista: 'Tu seguridad es más importante que cualquier archivo o formulario.',
          children: [
            FilaBotones(
              izquierda: Boton('Sí o no estoy segura', estilo: Estilo.peligro, onTap: () {
                Sesion.instancia.marcarRiesgo(true);
                setState(() => _emergencia = true);
              }),
              derecha: Boton('No, puedo continuar', onTap: () => _continuar(riesgo: false)),
            ),
            AnimatedSize(
              duration: movimiento(context, 260),
              curve: Curves.easeOutCubic,
              child: !_emergencia
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Aviso(
                        peligro: true,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          const Text.rich(TextSpan(children: [
                            TextSpan(text: 'Busca ayuda ahora.\n', style: TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(text: 'Si hay peligro físico inmediato, llama al '),
                            TextSpan(text: '911', style: TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(
                                text: ' o contacta a una persona de confianza. '
                                    'No necesitas terminar este proceso.'),
                          ])),
                          const SizedBox(height: 14),
                          FilaBotones(
                            izquierda:
                                Boton('Llamar al 911', icono: Icons.call, estilo: Estilo.peligro, onTap: () => llamar('911')),
                            derecha: Boton('Denuncia anónima 089', estilo: Estilo.secundario, onTap: () => llamar('089')),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => abrir(fuentes['emergency']!.url),
                              child: const Text('Ver información oficial del 911'),
                            ),
                          ),
                          Boton('Continuar solo si es seguro',
                              estilo: Estilo.contorno, onTap: () => _continuar(riesgo: true)),
                        ]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      Aparecer(
        orden: 2,
        child: Tarjeta(
          ceja: '¿Ya tienes capturas?',
          titulo: 'Registra tu evidencia',
          pista: 'Cada archivo recibe un comprobante SHA-256 que ayuda a mostrar que no cambió después de registrarlo.',
          children: [
            Boton('Registrar evidencias',
                icono: Icons.fingerprint,
                estilo: Estilo.secundario,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Evidencias()))),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Salida rápida: toca «Salir» arriba en cualquier momento. Borra lo de esta sesión, '
        'pero no el historial del navegador ni copias que hayas descargado o compartido.',
        style: letraFina,
      ),
    ]);
  }
}
