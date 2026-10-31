import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/api.dart';
import 'sesion.dart';
import 'theme.dart';

/// Borra todo lo de la sesión (y del backend, si se usa). No toca el historial del navegador
/// ni archivos que la persona ya haya descargado o compartido.
Future<void> borrarTodo() async {
  Sesion.instancia.borrarTodo();
  if (usaApi) {
    // Si el backend no responde, se borra igual lo local.
    await ResguardaApi.borrarTodo().catchError((_) {});
  }
}

/// Salida rápida: borra todo y cierra la app (en web regresa al inicio, porque no puede cerrarse).
Future<void> salirRapido(BuildContext context) async {
  final navegador = Navigator.of(context);
  await borrarTodo();
  navegador.popUntil((r) => r.isFirst);
  if (!kIsWeb) await SystemNavigator.pop();
}

Future<void> llamar(String numero) => launchUrl(Uri(scheme: 'tel', path: numero));

Future<void> abrir(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Botón compacto de salida rápida para los encabezados.
class BotonSalir extends StatelessWidget {
  const BotonSalir({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Salida rápida: borra todo y cierra Resguarda',
      child: TextButton.icon(
        onPressed: () => salirRapido(context),
        icon: const Icon(Icons.visibility_off_outlined, size: 18, color: Paleta.tinta),
        label: const Text('Salir', style: TextStyle(color: Paleta.tinta, fontWeight: FontWeight.w700)),
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.pressed)
                ? Paleta.neutroHover
                : s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)
                    ? Paleta.neutro
                    : null,
          ),
        ),
      ),
    );
  }
}
