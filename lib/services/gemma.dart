import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../sesion.dart';

/// Configuración al compilar:
///   --dart-define=GEMMA_API_KEY=...      (Google AI Studio)
///   --dart-define=GEMMA_MODEL=...        (por defecto gemma-3-27b-it)
///   --dart-define=OLLAMA_URL=http://IP:11434  --dart-define=OLLAMA_MODEL=...  (modelo local en la laptop)
const _apiKey = String.fromEnvironment('GEMMA_API_KEY');
const _modelo = String.fromEnvironment('GEMMA_MODEL', defaultValue: 'gemma-3-27b-it');
const _ollamaUrl = String.fromEnvironment('OLLAMA_URL');
const _ollamaModelo = String.fromEnvironment('OLLAMA_MODEL', defaultValue: 'gemma3:1b');

const _archivos = ['skills.md', 'evidencia.md', 'plataformas.md', 'contactos.md'];

const respuestaSinConexion = 'No pude conectar con el asistente, pero esto puedes hacer ya:\n\n'
    '• No borres mensajes ni publicaciones: son tu prueba.\n'
    '• Toma capturas donde se vean el contenido, el perfil, la fecha y la hora.\n'
    '• Guarda el enlace del perfil y de la publicación.\n'
    '• No pagues ni negocies con quien te extorsiona.\n'
    '• Sube tus capturas en "Evidencias" para registrarlas con su huella digital.\n\n'
    'Si estás en peligro, llama al 911. Denuncia anónima: 089.';

class Gemma {
  static String? _instrucciones;

  /// Reglas (skills.md) + documentos verificados, cargados desde assets.
  static Future<String> _sistema(Situacion? s) async {
    if (_instrucciones == null) {
      final partes = <String>[];
      for (final a in _archivos) {
        partes.add(await rootBundle.loadString('assets/conocimiento/$a'));
      }
      _instrucciones = '${partes.first}\n\n# FUENTES\n${partes.skip(1).join('\n\n')}';
    }
    final tema = s == null ? '' : '\n\nLa persona eligió: "${s.titulo}" (${s.contexto}).';
    return '$_instrucciones$tema';
  }

  static Future<String> responder(List<Mensaje> historial, Situacion? s, {String? instruccionFinal}) async {
    final sistema = await _sistema(s);
    final turnos = [
      ...historial,
      if (instruccionFinal != null) Mensaje(true, instruccionFinal),
    ];
    if (_ollamaUrl.isNotEmpty) return _ollama(sistema, turnos);
    if (_apiKey.isEmpty) {
      throw Exception('Falta la llave: compila con --dart-define=GEMMA_API_KEY=tu_llave');
    }
    return _google(sistema, turnos);
  }

  static Future<String> _google(String sistema, List<Mensaje> turnos) async {
    // Gemma en la API de Google no acepta "system instruction": va al inicio del primer turno.
    final contenidos = <Map<String, Object>>[];
    for (var i = 0; i < turnos.length; i++) {
      final m = turnos[i];
      final texto = i == 0 ? '$sistema\n\n---\n\n${m.texto}' : m.texto;
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
            'generationConfig': {'temperature': 0.2},
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (r.statusCode != 200) {
      throw Exception('El modelo $_modelo respondió ${r.statusCode}: ${r.body}');
    }
    final datos = jsonDecode(r.body) as Map<String, dynamic>;
    final partes = (datos['candidates'] as List).first['content']['parts'] as List;
    return partes.map((p) => p['text'] ?? '').join().trim();
  }

  static Future<String> _ollama(String sistema, List<Mensaje> turnos) async {
    final r = await http
        .post(
          Uri.parse('$_ollamaUrl/api/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': _ollamaModelo,
            'stream': false,
            'options': {'temperature': 0.2, 'num_ctx': 8192},
            'messages': [
              {'role': 'system', 'content': sistema},
              for (final m in turnos) {'role': m.deUsuaria ? 'user' : 'assistant', 'content': m.texto},
            ],
          }),
        )
        .timeout(const Duration(seconds: 120));
    if (r.statusCode != 200) throw Exception('Ollama respondió ${r.statusCode}: ${r.body}');
    return ((jsonDecode(r.body) as Map<String, dynamic>)['message']['content'] as String).trim();
  }
}
