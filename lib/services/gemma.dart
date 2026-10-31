import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../plan.dart';
import '../sesion.dart';
import 'api.dart';

/// Configuración al compilar:
///   --dart-define=GEMMA_API_KEY=...      (Google AI Studio)
///   --dart-define=GEMMA_MODEL=...        (por defecto gemma-3-27b-it)
///   --dart-define=OLLAMA_URL=http://IP:11434  --dart-define=OLLAMA_MODEL=...  (modelo local en la laptop)
///   --dart-define=RESGUARDA_API=http://IP:8000  (backend de Resguarda, ver services/api.dart)
const _apiKey = String.fromEnvironment('GEMMA_API_KEY');
const _modelo = String.fromEnvironment('GEMMA_MODEL', defaultValue: 'gemma-3-27b-it');
const _ollamaUrl = String.fromEnvironment('OLLAMA_URL');
const _ollamaModelo = String.fromEnvironment('OLLAMA_MODEL', defaultValue: 'gemma3:1b');

const _archivos = ['skills.md', 'evidencia.md', 'plataformas.md', 'rutas_de_apoyo.md', 'contactos.md', 'fuentes.md'];

/// Texto honesto para el indicador del encabezado: dónde se procesa el relato.
String get modoModelo {
  if (usaApi || _ollamaUrl.isNotEmpty) return 'Procesamiento local';
  if (_apiKey.isNotEmpty) return 'Gemma en la nube';
  return 'Sin conexión: reglas locales';
}

bool get modoPrivado => usaApi || _ollamaUrl.isNotEmpty || _apiKey.isEmpty;

const respuestaSinConexion = 'No pude conectar con el asistente, pero esto puedes hacer ya:\n\n'
    '• No borres mensajes ni publicaciones: son tu prueba.\n'
    '• Toma capturas donde se vean el contenido, el perfil, la fecha y la hora.\n'
    '• Guarda el enlace del perfil y de la publicación.\n'
    '• No pagues ni negocies con quien te extorsiona.\n'
    '• Registra tus capturas en "Evidencias" para obtener su comprobante SHA-256.\n\n'
    'Si estás en peligro, llama al 911. Denuncia anónima: 089.';

class Gemma {
  static String? _instrucciones;

  /// Reglas (skills.md) + documentos verificados, cargados desde assets.
  static Future<String> _sistema(Incidente? i) async {
    if (_instrucciones == null) {
      final partes = <String>[];
      for (final a in _archivos) {
        partes.add(await rootBundle.loadString('assets/conocimiento/$a'));
      }
      _instrucciones = '${partes.first}\n\n# FUENTES\n${partes.skip(1).join('\n\n')}';
    }
    final tema = i == null ? '' : '\n\nLa persona eligió: "${i.opcion}" (${i.contexto}).';
    return '$_instrucciones$tema';
  }

  static Future<String> responder(List<Mensaje> historial, Incidente? i, {String? instruccionFinal}) async {
    if (usaApi && instruccionFinal == null) {
      // El backend no guarda conversación: se le manda todo el relato de la persona.
      return ResguardaApi.chat(historial.where((m) => m.deUsuaria).map((m) => m.texto).join('\n'));
    }
    final sistema = await _sistema(i);
    final turnos = [
      ...historial,
      if (instruccionFinal != null) Mensaje(true, instruccionFinal),
    ];
    if (_ollamaUrl.isNotEmpty) return _ollama(sistema, turnos);
    if (_apiKey.isEmpty) {
      throw Exception('Sin modelo: compila con GEMMA_API_KEY, OLLAMA_URL o RESGUARDA_API');
    }
    return _google(sistema, turnos);
  }

  /// Arma el plan: reglas fijas + un resumen breve de Gemma validado. Si el modelo no responde
  /// o su salida no pasa la validación, el plan sale igual, solo con las reglas.
  static Future<PlanResguardo> crearPlan(Sesion s) async {
    final incidente = s.incidente!;
    if (usaApi) {
      try {
        return PlanResguardo.fromJson(await ResguardaApi.plan(
          incidente: incidente.id,
          riesgoInmediato: s.riesgoInmediato,
          tieneEvidencia: s.tieneEvidencia,
          cuentaComprometida: s.cuentaComprometida,
          relato: s.relato,
        ));
      } catch (e) {
        debugPrint('El backend no respondió el plan: $e');
      }
    }
    MapaIncidente? mapa;
    if (s.relato.trim().isNotEmpty && (_ollamaUrl.isNotEmpty || _apiKey.isNotEmpty)) {
      try {
        mapa = await _extraerMapa(incidente, s.relato.trim()).timeout(const Duration(seconds: 45));
      } catch (e) {
        debugPrint('Gemma no pudo resumir el relato: $e');
      }
    }
    return construirPlan(
      incidente: incidente,
      riesgoInmediato: s.riesgoInmediato,
      tieneEvidencia: s.tieneEvidencia,
      cuentaComprometida: s.cuentaComprometida,
      mapa: mapa,
    );
  }

  static Future<MapaIncidente?> _extraerMapa(Incidente i, String relato) async {
    final corto = relato.length > 500 ? relato.substring(0, 500) : relato;
    final prompt = 'Extrae un mapa breve y neutral de un incidente de violencia digital. '
        'No des consejo legal, no solicites datos, no inventes hechos. '
        'No copies nombres, usuarios, teléfonos, ubicaciones, fechas exactas ni contenido íntimo. '
        'Responde SOLO con JSON: {"summary": "máximo 180 caracteres", "platform": "red social o No especificada", '
        '"needs_account_protection": true o false}. '
        'Categoría seleccionada: ${i.etiqueta}. Relato: $corto';
    final texto = _ollamaUrl.isNotEmpty
        ? await _ollama(null, [Mensaje(true, prompt)], formato: _esquemaMapa, temperatura: 0)
        : await _google('', [Mensaje(true, prompt)], temperatura: 0);
    final inicio = texto.indexOf('{');
    final fin = texto.lastIndexOf('}');
    if (inicio < 0 || fin <= inicio) return null;
    final datos = jsonDecode(texto.substring(inicio, fin + 1));
    return datos is Map<String, dynamic> ? MapaIncidente.validar(datos) : null;
  }

  static const _esquemaMapa = {
    'type': 'object',
    'properties': {
      'summary': {'type': 'string', 'maxLength': 180},
      'platform': {'type': 'string', 'maxLength': 40},
      'needs_account_protection': {'type': 'boolean'},
    },
    'required': ['summary', 'platform', 'needs_account_protection'],
  };

  static Future<String> _google(String sistema, List<Mensaje> turnos, {double temperatura = 0.2}) async {
    // Gemma en la API de Google no acepta "system instruction": va al inicio del primer turno.
    final contenidos = <Map<String, Object>>[];
    for (var i = 0; i < turnos.length; i++) {
      final m = turnos[i];
      final texto = i == 0 && sistema.isNotEmpty ? '$sistema\n\n---\n\n${m.texto}' : m.texto;
      contenidos.add({
        'role': m.deUsuaria ? 'user' : 'model',
        'parts': [
          {'text': texto}
        ],
      });
    }
    final r = await http
        .post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_modelo:generateContent'),
          headers: {'Content-Type': 'application/json', 'x-goog-api-key': _apiKey},
          body: jsonEncode({
            'contents': contenidos,
            'generationConfig': {'temperature': temperatura},
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (r.statusCode != 200) {
      throw Exception('El modelo $_modelo respondió ${r.statusCode}: ${r.body}');
    }
    final datos = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final partes = (datos['candidates'] as List).first['content']['parts'] as List;
    return partes.map((p) => p['text'] ?? '').join().trim();
  }

  static Future<String> _ollama(String? sistema, List<Mensaje> turnos,
      {Map<String, Object>? formato, double temperatura = 0.2}) async {
    final r = await http
        .post(
          Uri.parse('$_ollamaUrl/api/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': _ollamaModelo,
            'stream': false,
            'format': ?formato,
            'options': {'temperature': temperatura, 'num_ctx': 8192},
            'messages': [
              if (sistema != null) {'role': 'system', 'content': sistema},
              for (final m in turnos) {'role': m.deUsuaria ? 'user' : 'assistant', 'content': m.texto},
            ],
          }),
        )
        .timeout(const Duration(seconds: 120));
    if (r.statusCode != 200) throw Exception('Ollama respondió ${r.statusCode}: ${r.body}');
    return ((jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>)['message']['content'] as String).trim();
  }
}

/// Hay un modelo directo (Google u Ollama) para redactar el borrador de denuncia.
bool get puedeRedactar => _ollamaUrl.isNotEmpty || _apiKey.isNotEmpty;
