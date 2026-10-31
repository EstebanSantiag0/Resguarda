import 'package:flutter/foundation.dart';

class Mensaje {
  Mensaje(this.deUsuaria, this.texto);
  final bool deUsuaria;
  final String texto;
}

class Evidencia {
  Evidencia(this.nombre, this.registrada, this.sha256);
  final String nombre;
  final DateTime registrada;
  final String sha256;
}

class Situacion {
  const Situacion(this.titulo, this.contexto);
  final String titulo;
  final String contexto; // se le indica al modelo para orientar la conversación
}

const situaciones = [
  Situacion('Están compartiendo mis fotos o videos íntimos', 'difusión de imágenes íntimas sin consentimiento (Ley Olimpia)'),
  Situacion('Me acosan o me amenazan por internet', 'acoso o amenazas en línea'),
  Situacion('Me piden fotos o me extorsionan con ellas', 'extorsión sexual (sextorsión) o grooming'),
  Situacion('Alguien se hace pasar por mí', 'suplantación de identidad'),
  Situacion('Otra cosa, solo quiero orientarme', 'orientación general sobre violencia digital'),
];

/// Todo vive en memoria: al salir de la app no queda nada guardado.
class Sesion extends ChangeNotifier {
  Sesion._();
  static final instancia = Sesion._();

  Situacion? situacion;
  final mensajes = <Mensaje>[];
  final evidencias = <Evidencia>[];
  bool pensando = false;

  void iniciar(Situacion s) {
    situacion = s;
    mensajes.clear();
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

  void borrarTodo() {
    situacion = null;
    mensajes.clear();
    evidencias.clear();
    pensando = false;
    notifyListeners();
  }
}
