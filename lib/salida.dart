import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/api.dart';
import 'sesion.dart';
import 'theme.dart';

/// Salida rápida: borra todo lo de la sesión y cierra la app.
Future<void> salirRapido() async {
  Sesion.instancia.borrarTodo();
  if (usaApi) {
    // Borra también las evidencias y el PDF guardados en el backend; si no responde, se sale igual.
    await ResguardaApi.borrarTodo().catchError((_) {});
  }
  await SystemNavigator.pop();
}

Future<void> llamar(String numero) => launchUrl(Uri(scheme: 'tel', path: numero));

/// Botón compacto de salida rápida para las barras superiores.
class BotonSalir extends StatelessWidget {
  const BotonSalir({super.key, this.claro = true});
  final bool claro;

  @override
  Widget build(BuildContext context) {
    final color = claro ? Colors.white : Paleta.anil;
    return TextButton.icon(
      onPressed: salirRapido,
      icon: Icon(Icons.visibility_off_outlined, size: 18, color: color),
      label: Text('Salir', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      style: ButtonStyle(
        overlayColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.pressed)
              ? color.withValues(alpha: 0.24)
              : s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)
                  ? color.withValues(alpha: 0.12)
                  : null,
        ),
      ),
    );
  }
}
