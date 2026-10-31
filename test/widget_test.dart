import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resguarda/main.dart';
import 'package:resguarda/plan.dart';
import 'package:resguarda/services/expediente.dart';
import 'package:resguarda/sesion.dart';

void main() {
  setUp(Sesion.instancia.borrarTodo);

  testWidgets('Inicio pregunta por el peligro y muestra el 911', (tester) async {
    await tester.pumpWidget(const Resguarda());
    await tester.pumpAndSettle();
    expect(find.text('¿Estás en peligro ahora?'), findsOneWidget);
    expect(find.text('Llamar al 911'), findsNothing);
    await tester.tap(find.text('Sí o no estoy segura'));
    await tester.pumpAndSettle();
    expect(find.text('Llamar al 911'), findsOneWidget);
    expect(find.text('Denuncia anónima 089'), findsOneWidget);
    expect(Sesion.instancia.riesgoInmediato, isTrue);
  });

  testWidgets('Recorrido: triage → plan con reglas locales (sin modelo)', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const Resguarda());
    await tester.pumpAndSettle();
    await tester.tap(find.text('No, puedo continuar'));
    await tester.pumpAndSettle();

    // Sin elegir situación, avisa.
    await tester.tap(find.text('Ver qué puedo hacer ahora'));
    await tester.pumpAndSettle();
    expect(find.text('Elige la opción que más se parezca a tu situación.'), findsOneWidget);

    await tester.tap(find.text('Alguien se hace pasar por mí'));
    await tester.tap(find.text('También creo que mi cuenta puede estar comprometida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver qué puedo hacer ahora'));
    await tester.pumpAndSettle();

    expect(find.text('Suplantación de identidad'), findsOneWidget);
    expect(find.text('Preservar antes de responder'), findsOneWidget);
    expect(find.textContaining('Protege la cuenta'), findsOneWidget);
    expect(find.text('Dónde pedir orientación'), findsOneWidget);
    expect(find.textContaining('951 454 0508'), findsOneWidget);
  });

  group('Plan', () {
    final amenazas = incidentePorId('threats')!;

    test('riesgo inmediato agrega la ruta del 911 primero', () {
      final p = construirPlan(incidente: amenazas, riesgoInmediato: true, tieneEvidencia: true, cuentaComprometida: false);
      expect(p.prioridad, 'Atención inmediata');
      expect(p.rutas.first.telefono, '911');
    });

    test('sin evidencia, el primer paso es registrar los datos básicos', () {
      final p = construirPlan(incidente: amenazas, riesgoInmediato: false, tieneEvidencia: false, cuentaComprometida: false);
      expect(p.pasos.first, startsWith('Registra la fecha'));
      expect(p.rutas.any((r) => r.telefono == '911'), isFalse);
    });

    test('la salida de Gemma se valida antes de usarla', () {
      expect(MapaIncidente.validar({'summary': 'corto'}), isNull);
      expect(MapaIncidente.validar({'summary': 'Le escribió @usuario con amenazas por mensaje directo'}), isNull);
      final ok = MapaIncidente.validar(
          {'summary': 'Recibe mensajes con amenazas de publicar fotos.', 'platform': 'Instagram', 'needs_account_protection': true});
      expect(ok, isNotNull);
      final p = construirPlan(incidente: amenazas, riesgoInmediato: false, tieneEvidencia: true, cuentaComprometida: false, mapa: ok);
      expect(p.resumen, ok!.resumen);
      expect(p.pasos.last, startsWith('Protege la cuenta'));
    });

    test('el plan del backend se lee con sus teléfonos', () {
      final p = construirPlan(incidente: amenazas, riesgoInmediato: true, tieneEvidencia: true, cuentaComprometida: false);
      final copia = PlanResguardo.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(copia.pasos, p.pasos);
      expect(copia.rutas.map((r) => r.telefono), ['911', '9514540508', null]);
    });
  });

  group('Expediente', () {
    final evidencia = Evidencia(
      nombre: 'captura (1).png',
      registrada: DateTime.utc(2026, 10, 31, 12),
      sha256: 'a' * 64,
      bytes: Uint8List.fromList([1, 2, 3]),
      nota: 'Mensaje recibido en la tarde',
    );
    final plan = construirPlan(
        incidente: incidentePorId('sextortion')!, riesgoInmediato: false, tieneEvidencia: true, cuentaComprometida: false);

    test('el PDF es válido y usa WinAnsi para los acentos', () {
      final pdf = crearPdf(relato: 'Me piden dinero — “urgente”', plan: plan, evidencias: [evidencia]);
      final texto = latin1.decode(pdf);
      expect(texto, startsWith('%PDF-1.4'));
      expect(texto, endsWith('%%EOF'));
      expect(texto, contains('/Encoding /WinAnsiEncoding'));
      expect(pdf, containsAllInOrder([0x97])); // raya —
      expect(texto, contains('Sextorsión'));
      expect(texto, contains('captura \\(1\\).png')); // paréntesis escapados
    });

    test('el PDF crece a varias páginas', () {
      final pdf = latin1.decode(crearPdf(relato: List.filled(200, 'palabra').join('\n'), plan: null, evidencias: []));
      expect(RegExp(r'/Type /Page ').allMatches(pdf).length, greaterThan(3));
    });

    test('el .zip trae PDF, manifiesto, fuentes y evidencias', () {
      final zip = ZipDecoder().decodeBytes(
          crearZip(relato: 'Relato', plan: plan, evidencias: [evidencia], fuentesMd: '# Fuentes'));
      expect(zip.files.map((f) => f.name),
          containsAll(['expediente-resguarda.pdf', 'manifest.json', 'fuentes.md', 'evidencias/1_captura__1_.png']));
      final manifiesto = jsonDecode(utf8.decode(zip.findFile('manifest.json')!.content)) as Map<String, dynamic>;
      expect(manifiesto['evidence'][0]['sha256'], 'a' * 64);
      expect(manifiesto['plan']['incident_label'], 'Sextorsión');
    });

    test('envolver respeta el ancho y corta palabras largas', () {
      final lineas = envolver('${'x' * 100} hola mundo', ancho: 40);
      expect(lineas.every((l) => l.length <= 40), isTrue);
      expect(lineas.last, 'xxxxxxxxxxxxxxxxxxxx hola mundo');
    });

    test('la plantilla de denuncia marca lo que falta', () {
      final b = borradorPlantilla(relato: '', plan: plan, evidencias: []);
      expect(b, contains('[COMPLETAR'));
    });
  });
}
