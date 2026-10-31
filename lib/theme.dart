import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paleta tomada de los tintes naturales de Oaxaca: añil y grana cochinilla.
class Paleta {
  static const anil = Color(0xFF23306B); // azul añil: identidad, encabezados
  static const grana = Color(0xFFA01642); // grana cochinilla: emergencia y acción principal
  static const cantera = Color(0xFF5E8371); // cantera verde: evidencia verificada
  static const nube = Color(0xFFEFF2F7); // fondo
  static const tinta = Color(0xFF161A2E); // texto
  static const hilo = Color(0xFFC9CFE0); // líneas y bordes
}

const fuenteTitulos = 'NotoSerifDisplay';

/// Duración de animaciones; cero si el sistema pide reducir movimiento.
Duration movimiento(BuildContext context, int ms) =>
    MediaQuery.of(context).disableAnimations ? Duration.zero : Duration(milliseconds: ms);

/// Margen lateral: 20 px en el celular; en web o tableta centra el contenido a 680 px de ancho.
double margenLateral(BuildContext context) => math.max(20, (MediaQuery.sizeOf(context).width - 680) / 2);

ThemeData temaResguarda() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'NotoSans',
    colorScheme: ColorScheme.fromSeed(
      seedColor: Paleta.anil,
      primary: Paleta.anil,
      secondary: Paleta.grana,
      surface: Paleta.nube,
      onSurface: Paleta.tinta,
    ),
    scaffoldBackgroundColor: Paleta.nube,
  );
  return base.copyWith(
    textTheme: base.textTheme
        .copyWith(
          displaySmall: const TextStyle(fontFamily: fuenteTitulos, fontWeight: FontWeight.w700, fontSize: 34, height: 1.1),
          headlineSmall: const TextStyle(fontFamily: fuenteTitulos, fontWeight: FontWeight.w500, fontSize: 24, height: 1.2),
          titleMedium: const TextStyle(fontFamily: 'NotoSans', fontWeight: FontWeight.w600, fontSize: 16, height: 1.35),
          bodyLarge: const TextStyle(fontFamily: 'NotoSans', fontSize: 16, height: 1.5),
          bodyMedium: const TextStyle(fontFamily: 'NotoSans', fontSize: 14, height: 1.45),
        )
        .apply(bodyColor: Paleta.tinta, displayColor: Paleta.tinta),
    appBarTheme: const AppBarTheme(
      backgroundColor: Paleta.anil,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(fontFamily: fuenteTitulos, fontSize: 21, fontWeight: FontWeight.w500, color: Colors.white),
    ),
  );
}
