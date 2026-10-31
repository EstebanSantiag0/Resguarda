/// Triage y plan de resguardo. Las acciones sensibles (emergencia, checklist, rutas y fuentes)
/// salen de estas reglas fijas; Gemma solo aporta un resumen breve que se valida antes de usarlo.
/// Es la misma lógica que `backend/app/main.py` (`build_plan`), para que la app funcione sin backend.
library;

class Fuente {
  const Fuente(this.titulo, this.editor, this.url);
  final String titulo;
  final String editor;
  final String url;

  Map<String, String> toJson() => {'title': titulo, 'publisher': editor, 'url': url};
  factory Fuente.fromJson(Map<String, dynamic> j) =>
      Fuente('${j['title'] ?? ''}', '${j['publisher'] ?? ''}', '${j['url'] ?? ''}');
}

const fuentes = {
  'evidence': Fuente('Guía local para conservar evidencia', 'Resguarda · fuentes oficiales revisadas',
      'https://www.diputados.gob.mx/LeyesBiblio/pdf/LGAMVLV.pdf'),
  'support': Fuente('Atención a mujeres en situación de violencia', 'Secretaría de las Mujeres de Oaxaca',
      'https://www.oaxaca.gob.mx/sm/'),
  'emergency': Fuente('Emergencias 911', 'Gobierno de México', 'https://www.gob.mx/911'),
  'justice': Fuente('Centros de Justicia para las Mujeres', 'CONAVIM',
      'https://www.gob.mx/conavim/acciones-y-programas/centros-de-justicia-para-las-mujeres'),
  'legal': Fuente('Marco legal de consulta', 'Cámara de Diputados', 'https://www.diputados.gob.mx/LeyesBiblio/pdf/CPF.pdf'),
};

class Incidente {
  const Incidente({
    required this.id,
    required this.opcion,
    required this.detalle,
    required this.etiqueta,
    required this.contexto,
    required this.pasos,
    required this.fuentes,
  });

  final String id; // mismo identificador que el backend
  final String opcion; // texto del botón, en primera persona
  final String detalle;
  final String etiqueta; // título del plan
  final String contexto; // se le indica al modelo para orientar la conversación
  final List<String> pasos;
  final List<String> fuentes;
}

const incidentes = [
  Incidente(
    id: 'threats',
    opcion: 'Me están presionando o amenazando',
    detalle: 'Mensajes intimidantes, acoso o chantaje.',
    etiqueta: 'Amenazas o acoso',
    contexto: 'acoso o amenazas en línea',
    pasos: [
      'Conserva capturas completas de los mensajes.',
      'Guarda el perfil, URL o identificador de quien envió el mensaje.',
      'Registra fecha y hora de recepción antes de bloquear o reportar.',
    ],
    fuentes: ['evidence', 'support'],
  ),
  Incidente(
    id: 'intimate_content',
    opcion: 'Compartieron o amenazan con compartir contenido íntimo',
    detalle: 'Difusión sin mi permiso (Ley Olimpia).',
    etiqueta: 'Difusión de contenido íntimo',
    contexto: 'difusión de imágenes íntimas sin consentimiento (Ley Olimpia)',
    pasos: [
      'Conserva la publicación, perfil y URL sin redistribuir el contenido.',
      'Guarda capturas donde se vean fecha, cuenta y plataforma.',
      'Conserva archivos originales y evita editarlos.',
    ],
    fuentes: ['evidence', 'legal', 'support'],
  ),
  Incidente(
    id: 'sextortion',
    opcion: 'Me piden fotos o dinero a cambio de no publicar algo',
    detalle: 'Sextorsión o chantaje con contenido íntimo.',
    etiqueta: 'Sextorsión',
    contexto: 'extorsión sexual (sextorsión) o grooming',
    pasos: [
      'Conserva mensajes, cuentas, enlaces y solicitudes recibidas.',
      'No compartas códigos de verificación ni más contenido íntimo.',
      'Evita negociar bajo presión; busca acompañamiento especializado.',
    ],
    fuentes: ['evidence', 'support'],
  ),
  Incidente(
    id: 'account',
    opcion: 'Alguien tomó o intentó tomar mi cuenta',
    detalle: 'Acceso no autorizado o pérdida de control.',
    etiqueta: 'Cuenta comprometida',
    contexto: 'cuenta comprometida o acceso no autorizado',
    pasos: [
      'Cambia la contraseña desde un dispositivo confiable.',
      'Activa autenticación de dos factores y revisa sesiones abiertas.',
      'Guarda correos o avisos de inicio de sesión antes de eliminarlos.',
    ],
    fuentes: ['evidence'],
  ),
  Incidente(
    id: 'impersonation',
    opcion: 'Alguien se hace pasar por mí',
    detalle: 'Perfil falso o uso de mi identidad.',
    etiqueta: 'Suplantación de identidad',
    contexto: 'suplantación de identidad',
    pasos: [
      'Guarda el enlace o identificador del perfil que suplanta.',
      'Captura publicaciones, mensajes y fecha de consulta.',
      'Conserva el perfil original para comparar la información pública.',
    ],
    fuentes: ['evidence', 'support'],
  ),
];

Incidente? incidentePorId(String id) {
  for (final i in incidentes) {
    if (i.id == id) return i;
  }
  return null;
}

class Ruta {
  const Ruta(this.titulo, this.detalle, this.url, {this.telefono});
  final String titulo;
  final String detalle;
  final String url;
  final String? telefono; // para el botón "Llamar"

  Map<String, String> toJson() => {'title': titulo, 'detail': detalle, 'url': url};

  /// El backend no manda el teléfono aparte: se toma del texto.
  factory Ruta.fromJson(Map<String, dynamic> j) {
    final titulo = '${j['title'] ?? ''}';
    final detalle = '${j['detail'] ?? ''}';
    final numero = RegExp(r'\b\d{3} \d{3} \d{4}\b').firstMatch(detalle)?.group(0);
    final telefono = titulo.contains('911') ? '911' : numero?.replaceAll(' ', '');
    return Ruta(titulo, detalle, '${j['url'] ?? ''}', telefono: telefono);
  }
}

/// Mapa breve que Gemma extrae del relato (ya validado).
class MapaIncidente {
  const MapaIncidente({required this.resumen, required this.plataforma, required this.protegerCuenta});
  final String resumen;
  final String plataforma;
  final bool protegerCuenta;

  static const _prohibidas = ['contraseña', 'fecha de nacimiento', 'ubicación', 'teléfono', 'nombre completo', '@'];

  /// Valida la salida del modelo; devuelve null si no es segura o no tiene la forma esperada.
  static MapaIncidente? validar(Map<String, dynamic> j) {
    final resumen = '${j['summary'] ?? ''}'.trim();
    var plataforma = '${j['platform'] ?? 'No especificada'}'.trim();
    if (resumen.length < 10 || resumen.length > 220) return null;
    if (_prohibidas.any(resumen.toLowerCase().contains)) return null;
    if (plataforma.isEmpty) plataforma = 'No especificada';
    if (plataforma.length > 40) plataforma = plataforma.substring(0, 40);
    return MapaIncidente(resumen: resumen, plataforma: plataforma, protegerCuenta: j['needs_account_protection'] == true);
  }
}

const _pasoCuenta = 'Protege la cuenta: cambia contraseña desde un dispositivo confiable y revisa sesiones abiertas.';

class PlanResguardo {
  PlanResguardo({
    required this.etiqueta,
    required this.prioridad,
    required this.accionInmediata,
    required this.pasos,
    required this.fuentes,
    required this.resumen,
    required this.plataforma,
    required this.estadoModelo,
    required this.rutas,
  });

  final String etiqueta;
  final String prioridad;
  final String accionInmediata;
  final List<String> pasos;
  final List<Fuente> fuentes;
  String resumen; // la persona lo puede editar antes de exportar
  final String plataforma;
  final String estadoModelo;
  final List<Ruta> rutas;

  Map<String, Object> toJson() => {
        'incident_label': etiqueta,
        'priority': prioridad,
        'immediate_action': accionInmediata,
        'steps': pasos,
        'sources': [for (final f in fuentes) f.toJson()],
        'handoff': resumen,
        'incident_map': {'platform': plataforma},
        'model_status': estadoModelo,
        'support_routes': [for (final r in rutas) r.toJson()],
      };

  factory PlanResguardo.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> lista(String k) => [for (final x in (j[k] as List? ?? [])) (x as Map).cast<String, dynamic>()];
    final mapa = (j['incident_map'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PlanResguardo(
      etiqueta: '${j['incident_label'] ?? ''}',
      prioridad: '${j['priority'] ?? ''}',
      accionInmediata: '${j['immediate_action'] ?? ''}',
      pasos: [for (final p in (j['steps'] as List? ?? [])) '$p'],
      fuentes: [for (final f in lista('sources')) Fuente.fromJson(f)],
      resumen: '${j['handoff'] ?? ''}',
      plataforma: '${mapa['platform'] ?? 'No especificada'}',
      estadoModelo: '${j['model_status'] ?? ''}',
      rutas: [for (final r in lista('support_routes')) Ruta.fromJson(r)],
    );
  }
}

PlanResguardo construirPlan({
  required Incidente incidente,
  required bool riesgoInmediato,
  required bool tieneEvidencia,
  required bool cuentaComprometida,
  MapaIncidente? mapa,
}) {
  final pasos = [...incidente.pasos];
  if (!tieneEvidencia) {
    pasos.insert(0,
        'Registra la fecha, hora, plataforma y cuenta involucrada; no intentes obtener evidencia si te pone en riesgo.');
  }
  final protegerCuenta = cuentaComprometida || (mapa?.protegerCuenta ?? false);
  if (protegerCuenta && incidente.id != 'account') pasos.add(_pasoCuenta);

  return PlanResguardo(
    etiqueta: incidente.etiqueta,
    prioridad: riesgoInmediato ? 'Atención inmediata' : 'Preservar antes de responder',
    accionInmediata: riesgoInmediato
        ? 'Si hay peligro físico inmediato, llama al 911 o busca una red de apoyo cercana.'
        : 'Conserva primero la información relevante. Evita responder si hacerlo puede aumentar el riesgo.',
    pasos: pasos,
    fuentes: [for (final f in incidente.fuentes) fuentes[f]!],
    resumen: mapa?.resumen ??
        'La persona solicita orientación inicial sobre ${incidente.etiqueta.toLowerCase()}. '
            'Resguarda recomienda conservar evidencia y buscar acompañamiento cuando se sienta lista.',
    plataforma: mapa?.plataforma ?? 'No especificada',
    estadoModelo: mapa != null
        ? 'Gemma organizó el relato y Resguarda validó la salida'
        : 'Plan seguro generado con reglas locales; Gemma no añadió datos',
    rutas: [
      if (riesgoInmediato)
        Ruta('Si hay peligro inmediato, llama al 911', 'No necesitas terminar este expediente antes de pedir ayuda.',
            fuentes['emergency']!.url,
            telefono: '911'),
      Ruta('Pide orientación y acompañamiento en Oaxaca',
          'Secretaría de las Mujeres de Oaxaca · 951 454 0508. Confirma horario y ruta antes de acudir.',
          fuentes['support']!.url,
          telefono: '9514540508'),
      Ruta('Si decides buscar acceso a la justicia',
          'Consulta los Centros de Justicia para las Mujeres y confirma la ruta local vigente antes de acudir.',
          fuentes['justice']!.url),
    ],
  );
}
