import 'dart:convert';
import 'dart:typed_data';

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

  static Future<String> chat(String mensaje) async {
    final r = await http
        .post(_ruta('/api/chat'),
            headers: _encabezados, body: jsonEncode({'message': mensaje}))
        .timeout(const Duration(seconds: 120));
    final datos = _json(r);
    final fuentes = (datos['sources'] as List? ?? []).cast<String>();
    final respuesta = (datos['answer'] as String).trim();
    return fuentes.isEmpty ? respuesta : '$respuesta\n\nFuentes: ${fuentes.join(', ')}';
  }

  /// Guarda la captura en el backend para que aparezca en el expediente PDF.
  static Future<String> subirEvidencia(String nombre, Uint8List bytes) async {
    final solicitud = http.MultipartRequest('POST', _ruta('/api/evidence'))
      ..headers['X-Resguarda'] = '1'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: nombre));
    final r = await http.Response.fromStream(await solicitud.send().timeout(const Duration(seconds: 60)));
    return _json(r)['sha256'] as String;
  }

  static Future<Uint8List> expediente(String resumen) async {
    final r = await http
        .post(_ruta('/api/report'),
            headers: _encabezados, body: jsonEncode({'summary': resumen}))
        .timeout(const Duration(seconds: 60));
    if (r.statusCode != 200) throw Exception('El backend respondió ${r.statusCode}');
    return r.bodyBytes;
  }

  static Future<void> borrarTodo() async {
    await http.post(_ruta('/api/delete-all'), headers: const {'X-Resguarda': '1'}).timeout(const Duration(seconds: 5));
  }
}
