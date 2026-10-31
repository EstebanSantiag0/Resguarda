import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../plan.dart';
import '../sesion.dart';

const avisoExpediente = 'Expediente orientativo. No es una denuncia, dictamen legal ni cadena de custodia formal.';

/// Expediente portable, igual al del prototipo web:
/// expediente-resguarda.zip
/// ├── expediente-resguarda.pdf
/// ├── manifest.json
/// ├── fuentes.md
/// └── evidencias/
Uint8List crearZip({
  required String relato,
  required PlanResguardo? plan,
  required List<Evidencia> evidencias,
  required String fuentesMd,
  DateTime? ahora,
}) {
  final fecha = (ahora ?? DateTime.now()).toUtc();
  final manifiesto = {
    'generated_at': fecha.toIso8601String(),
    'notice': avisoExpediente,
    'plan': plan?.toJson() ?? <String, Object>{},
    'evidence': [for (final e in evidencias) e.toJson()],
  };
  final zip = Archive()
    ..addFile(ArchiveFile.bytes('expediente-resguarda.pdf', crearPdf(relato: relato, plan: plan, evidencias: evidencias, ahora: fecha)))
    ..addFile(ArchiveFile.string('manifest.json', const JsonEncoder.withIndent('  ').convert(manifiesto)))
    ..addFile(ArchiveFile.string('fuentes.md', fuentesMd));
  for (var i = 0; i < evidencias.length; i++) {
    zip.addFile(ArchiveFile.bytes('evidencias/${i + 1}_${nombreSeguro(evidencias[i].nombre)}', evidencias[i].bytes));
  }
  return ZipEncoder().encodeBytes(zip);
}

String nombreSeguro(String nombre) => nombre.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

/// PDF de texto mínimo (Helvetica, WinAnsi), sin paquetes extra: funciona sin internet.
Uint8List crearPdf({
  required String relato,
  required PlanResguardo? plan,
  required List<Evidencia> evidencias,
  DateTime? ahora,
}) {
  final fecha = (ahora ?? DateTime.now()).toUtc();
  final lineas = <String>[
    'RESGUARDA — EXPEDIENTE ORIENTATIVO',
    'Generado: ${fecha.toIso8601String().substring(0, 19).replaceFirst('T', ' ')} UTC',
    '',
    'Este documento no es una denuncia ni asesoría legal.',
    '',
    'Relato:',
    ...envolver(relato.trim().isEmpty ? 'Sin relato registrado.' : relato.trim()),
  ];
  if (plan != null) {
    lineas
      ..addAll(['', 'Situación: ${plan.etiqueta} · Prioridad: ${plan.prioridad}', '', 'Resumen para pedir ayuda:'])
      ..addAll(envolver(plan.resumen.isEmpty ? 'Sin resumen generado.' : plan.resumen))
      ..addAll(['', 'Plan de resguardo:']);
    for (final p in plan.pasos) {
      lineas.addAll(envolver('- $p'));
    }
    lineas.addAll(['', 'Rutas de apoyo:']);
    for (final r in plan.rutas) {
      lineas.addAll(envolver('- ${r.titulo}: ${r.detalle}'));
    }
  }
  lineas.addAll(['', 'Evidencias registradas:']);
  if (evidencias.isEmpty) lineas.add('Sin evidencias registradas.');
  for (final e in evidencias) {
    lineas.addAll(envolver(
        '- ${e.nombre} | Tipo: ${e.tipo} | ${e.registrada.toUtc().toIso8601String()} | SHA-256: ${e.sha256}'));
    if (e.nota.isNotEmpty) lineas.addAll(envolver('  Nota: ${e.nota}'));
  }
  return _pdfDeLineas(lineas);
}

/// Ajuste de línea por palabras (como textwrap de Python); corta palabras más largas que el ancho.
List<String> envolver(String texto, {int ancho = 82}) {
  final salida = <String>[];
  for (final parrafo in texto.split('\n')) {
    var actual = '';
    for (var palabra in parrafo.split(RegExp(r'\s+')).where((p) => p.isNotEmpty)) {
      while (palabra.length > ancho) {
        if (actual.isNotEmpty) {
          salida.add(actual);
          actual = '';
        }
        salida.add(palabra.substring(0, ancho));
        palabra = palabra.substring(ancho);
      }
      if (actual.isEmpty) {
        actual = palabra;
      } else if (actual.length + 1 + palabra.length <= ancho) {
        actual = '$actual $palabra';
      } else {
        salida.add(actual);
        actual = palabra;
      }
    }
    if (actual.isNotEmpty) salida.add(actual);
  }
  return salida;
}

// Caracteres fuera de Latin-1 que sí existen en WinAnsiEncoding.
const _winAnsi = {
  '—': 0x97, '–': 0x96, '“': 0x93, '”': 0x94, '‘': 0x91, '’': 0x92, '•': 0x95, '…': 0x85, '€': 0x80, //
};

List<int> _codificar(String texto) {
  final bytes = <int>[];
  for (final r in texto.runes) {
    final c = String.fromCharCode(r);
    final b = _winAnsi[c] ?? (r < 0x80 || (r >= 0xA0 && r <= 0xFF) ? r : 0x3F); // "?" si no existe
    if (b == 0x28 || b == 0x29 || b == 0x5C) bytes.add(0x5C); // escapa ( ) \
    bytes.add(b);
  }
  return bytes;
}

Uint8List _pdfDeLineas(List<String> lineas) {
  const porPagina = 45;
  final paginas = <List<String>>[
    for (var i = 0; i < lineas.length; i += porPagina)
      lineas.sublist(i, i + porPagina > lineas.length ? lineas.length : i + porPagina),
  ];
  if (paginas.isEmpty) paginas.add(['Sin contenido.']);
  final n = paginas.length;
  final fuente = 3 + n;
  final kids = [for (var i = 0; i < n; i++) '${3 + i} 0 R'].join(' ');
  final objetos = <List<int>>[
    latin1.encode('<< /Type /Catalog /Pages 2 0 R >>'),
    latin1.encode('<< /Type /Pages /Kids [$kids] /Count $n >>'),
    for (var i = 0; i < n; i++)
      latin1.encode('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
          '/Resources << /Font << /F1 $fuente 0 R >> >> /Contents ${fuente + 1 + i} 0 R >>'),
    latin1.encode('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>'),
    for (final pagina in paginas) _flujo(pagina),
  ];
  final pdf = BytesBuilder()..add(latin1.encode('%PDF-1.4\n'));
  final offsets = <int>[];
  for (var i = 0; i < objetos.length; i++) {
    offsets.add(pdf.length);
    pdf
      ..add(latin1.encode('${i + 1} 0 obj\n'))
      ..add(objetos[i])
      ..add(latin1.encode('\nendobj\n'));
  }
  final xref = pdf.length;
  pdf.add(latin1.encode('xref\n0 ${objetos.length + 1}\n0000000000 65535 f \n'
      '${offsets.map((o) => '${o.toString().padLeft(10, '0')} 00000 n \n').join()}'
      'trailer\n<< /Size ${objetos.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF'));
  return pdf.takeBytes();
}

List<int> _flujo(List<String> lineas) {
  final contenido = BytesBuilder()..add(latin1.encode('BT /F1 11 Tf 50 760 Td 15 TL '));
  for (final l in lineas) {
    contenido
      ..addByte(0x28)
      ..add(_codificar(l))
      ..add(latin1.encode(') Tj T* '));
  }
  contenido.add(latin1.encode('ET'));
  final bytes = contenido.takeBytes();
  return [...latin1.encode('<< /Length ${bytes.length} >>\nstream\n'), ...bytes, ...latin1.encode('\nendstream')];
}

/// Borrador de denuncia sin modelo: solo usa lo que la persona escribió; lo demás queda en [COMPLETAR].
String borradorPlantilla({required String relato, required PlanResguardo? plan, required List<Evidencia> evidencias}) {
  final hechos = relato.trim().isEmpty ? '[COMPLETAR: qué pasó, cuándo y dónde]' : relato.trim();
  final plataforma = plan == null || plan.plataforma == 'No especificada' ? '[COMPLETAR]' : plan.plataforma;
  final anexos = evidencias.isEmpty
      ? '[COMPLETAR: capturas, enlaces o mensajes que conservas]'
      : [for (var i = 0; i < evidencias.length; i++) '${i + 1}. ${evidencias[i].tipo}: ${evidencias[i].nombre}'].join('\n');
  return 'Hechos\n$hechos\n\n'
      'Medios digitales involucrados\nPlataforma: $plataforma\nPerfiles o enlaces: [COMPLETAR]\n\n'
      'Evidencias que se anexan\n$anexos\n\n'
      'Petición\nSolicito que se investiguen estos hechos y que se retire el contenido.';
}

String documentoBorrador(String borrador, List<Evidencia> evidencias) {
  final lista = evidencias.isEmpty
      ? 'Sin evidencias registradas.'
      : evidencias.map((e) => '- ${e.nombre} (${e.tipo}, registrada ${e.registrada.toIso8601String()})\n  SHA-256: ${e.sha256}').join('\n');
  return 'BORRADOR DE DENUNCIA — generado con Resguarda (orientativo, no es asesoría legal)\n\n'
      '$borrador\n\nEVIDENCIAS ANEXAS\n$lista';
}
