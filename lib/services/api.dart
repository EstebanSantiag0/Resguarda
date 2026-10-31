import 'dart:convert';

import 'package:http/http.dart' as http;

/// Backend de Resguarda (FastAPI + Gemma en Ollama, carpeta `backend/`).
/// Se activa al compilar con --dart-define=RESGUARDA_API=http://IP:8000
const apiUrl = String.fromEnvironment('RESGUARDA_API');
bool get usaApi => apiUrl.isNotEmpty;

class ResguardaApi {
  static Uri _ruta(String ruta) => Uri.parse('$apiUrl$ruta');

  /// El backend rechaza cualquier POST sin este encabezado (protección contra CSRF).
  static const _encabezados = {'Content-Type': 'application/json', 'X-Resguarda': '1'};

  /// FastAPI responde JSON sin "charset"; se decodifica como UTF-8 para no romper acentos.
  static Map<String, dynamic> _json(http.Response r) {
    final datos = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (r.statusCode != 200) throw Exception(datos['detail'] ?? 'Error ${r.statusCode}');
    return datos;
  }

  static Future<Map<String, dynamic>> _post(String ruta, Map<String, Object> cuerpo, Duration limite) async =>
      _json(await http.post(_ruta(ruta), headers: _encabezados, body: jsonEncode(cuerpo)).timeout(limite));

  static Future<String> chat(String mensaje) async {
    final datos = await _post('/api/chat', {'message': mensaje}, const Duration(seconds: 120));
    final fuentes = (datos['sources'] as List? ?? []).cast<String>();
    final respuesta = (datos['answer'] as String).trim();
    return fuentes.isEmpty ? respuesta : '$respuesta\n\nFuentes: ${fuentes.join(', ')}';
  }

  /// Triage y plan validado por el backend (mismas reglas que `lib/plan.dart`).
  static Future<Map<String, dynamic>> plan({
    required String incidente,
    required bool riesgoInmediato,
    required bool tieneEvidencia,
    required bool cuentaComprometida,
    required String relato,
  }) =>
      _post(
        '/api/plan',
        {
          'incident': incidente,
          'immediate_risk': riesgoInmediato,
          'evidence_available': tieneEvidencia,
          'account_compromised': cuentaComprometida,
          'notes': relato,
        },
        const Duration(seconds: 90),
      );

  static Future<void> borrarTodo() async {
    await http.post(_ruta('/api/delete-all'), headers: const {'X-Resguarda': '1'}).timeout(const Duration(seconds: 5));
  }
}
