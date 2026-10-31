import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paleta del prototipo del Hack Day: lienzo claro, tarjetas blancas y ciruela como acento
/// (combina con el morado del logo). Verde = privado/verificado, rojo = emergencia.
class Paleta {
  static const ciruela = Color(0xFF642548); // acento principal, botones
  static const ciruelaOscura = Color(0xFF481A33); // hover / presionado
  static const ciruelaSuave = Color(0xFFF4E9EE); // seleccionado, fondos suaves
  static const tinta = Color(0xFF17212B); // texto
  static const gris = Color(0xFF667085); // texto secundario
  static const lienzo = Color(0xFFF7F7F8); // fondo
  static const linea = Color(0xFFD9DEE6); // bordes
  static const verde = Color(0xFF17603B);
  static const verdeSuave = Color(0xFFE8F5ED);
  static const rojo = Color(0xFFB42318);
  static const rojoOscuro = Color(0xFF8E1C14);
  static const rojoSuave = Color(0xFFFFF0EF);
  static const neutro = Color(0xFFEEF0F3); // botón secundario
  static const neutroHover = Color(0xFFDFE4EA);
}

/// Duración de animaciones; cero si el sistema pide reducir movimiento.
Duration movimiento(BuildContext context, int ms) =>
    MediaQuery.of(context).disableAnimations ? Duration.zero : Duration(milliseconds: ms);

/// Margen lateral: 16 px en el celular; en web o tableta centra el contenido a 760 px de ancho.
double margenLateral(BuildContext context) => math.max(16, (MediaQuery.sizeOf(context).width - 760) / 2);

ThemeData temaResguarda() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'NotoSans',
    colorScheme: ColorScheme.fromSeed(
      seedColor: Paleta.ciruela,
      primary: Paleta.ciruela,
      secondary: Paleta.verde,
      error: Paleta.rojo,
      surface: Paleta.lienzo,
      onSurface: Paleta.tinta,
    ),
    scaffoldBackgroundColor: Paleta.lienzo,
  );
  return base.copyWith(
    textTheme: base.textTheme
        .copyWith(
          displaySmall: const TextStyle(fontWeight: FontWeight.w700, fontSize: 32, height: 1.15, letterSpacing: -1.2),
          headlineSmall: const TextStyle(fontWeight: FontWeight.w700, fontSize: 21, height: 1.25, letterSpacing: -0.4),
          titleMedium: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.35),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.55),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
          labelSmall: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.1),
        )
        .apply(fontFamily: 'NotoSans', bodyColor: Paleta.tinta, displayColor: Paleta.tinta),
    appBarTheme: const AppBarTheme(
      backgroundColor: Paleta.lienzo,
      foregroundColor: Paleta.tinta,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontFamily: 'NotoSans', fontSize: 19, fontWeight: FontWeight.w700, color: Paleta.tinta),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Paleta.linea)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Paleta.linea)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Paleta.ciruela, width: 2)),
      hintStyle: const TextStyle(color: Paleta.gris),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Paleta.ciruela : null),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: Paleta.tinta),
  );
}
