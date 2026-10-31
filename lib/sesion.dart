import 'package:flutter/foundation.dart';

import 'plan.dart';

class Mensaje {
  Mensaje(this.deUsuaria, this.texto);
  final bool deUsuaria;
  final String texto;
}

const tiposEvidencia = ['Captura de pantalla', 'Mensaje exportado', 'Correo', 'Archivo original', 'Otro archivo'];

class Evidencia {
  Evidencia({
    required this.nombre,
    required this.registrada,
    required this.sha256,
    required this.bytes,
    this.tipo = 'Captura de pantalla',
    this.nota = '',
  });
  final String nombre;
  final DateTime registrada;
  final String sha256;
  final Uint8List bytes; // solo en memoria; se incluye en el expediente .zip
  final String tipo;
  final String nota;

  Map<String, String> toJson() => {
        'filename': nombre,
        'sha256': sha256,
        'created_at': registrada.toUtc().toIso8601String(),
        'evidence_type': tipo,
        'note': nota,
      };
}

/// Todo vive en memoria: al salir de la app no queda nada guardado.
class Sesion extends ChangeNotifier {
  Sesion._();
  static final instancia = Sesion._();

  // Triage
  bool riesgoInmediato = false;
  Incidente? incidente;
  String relato = '';
  bool tieneEvidencia = true;
  bool cuentaComprometida = false;

  // Plan
  PlanResguardo? plan;
  final pasosHechos = <int>{};

  // Chat y evidencias
  final mensajes = <Mensaje>[];
  final evidencias = <Evidencia>[];
  bool pensando = false;

  void marcarRiesgo(bool valor) {
    riesgoInmediato = valor;
    notifyListeners();
  }

  void elegirIncidente(Incidente i) {
    if (incidente != i) mensajes.clear(); // la conversación es sobre la situación elegida
    incidente = i;
    notifyListeners();
  }

  void guardarPlan(PlanResguardo p) {
    plan = p;
    pasosHechos.clear();
    notifyListeners();
  }

  void alternarPaso(int i) {
    if (!pasosHechos.remove(i)) pasosHechos.add(i);
    notifyListeners();
  }

  void agregarMensaje(Mensaje m) {
    mensajes.add(m);
    notifyListeners();
  }

  void ponerPensando(bool valor) {
    pensando = valor;
    notifyListeners();
  }

  bool agregarEvidencia(Evidencia e) {
    if (evidencias.any((x) => x.sha256 == e.sha256)) return false;
    evidencias.add(e);
    notifyListeners();
    return true;
  }

  void quitarEvidencia(Evidencia e) {
    evidencias.remove(e);
    notifyListeners();
  }

  /// Relato completo de la persona: lo que escribió en el triage y en el chat.
  String get relatoCompleto =>
      [relato, ...mensajes.where((m) => m.deUsuaria).map((m) => m.texto)].where((t) => t.trim().isNotEmpty).join('\n');

  void borrarTodo() {
    riesgoInmediato = false;
    incidente = null;
    relato = '';
    tieneEvidencia = true;
    cuentaComprometida = false;
    plan = null;
    pasosHechos.clear();
    mensajes.clear();
    evidencias.clear();
    pensando = false;
    notifyListeners();
  }
}
