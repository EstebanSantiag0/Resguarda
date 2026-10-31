import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sesion.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import '../widgets/pressable.dart';

const _maxBytes = 12 * 1024 * 1024; // mismo límite que el backend

class Evidencias extends StatefulWidget {
  const Evidencias({super.key});

  @override
  State<Evidencias> createState() => _EvidenciasState();
}

class _EvidenciasState extends State<Evidencias> {
  final _sesion = Sesion.instancia;
  final _nota = TextEditingController();
  String _tipo = tiposEvidencia.first;
  bool _cargando = false;
  String? _estado;

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    setState(() {
      _cargando = true;
      _estado = null;
    });
    try {
      final archivos = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'heic', 'gif', 'pdf'],
      );
      if (archivos.isEmpty) return;
      final nuevas = <Evidencia>[];
      var repetidas = 0;
      var grandes = 0;
      for (final a in archivos) {
        final bytes = await a.readAsBytes();
        if (bytes.length > _maxBytes) {
          grandes++;
          continue;
        }
        final e = Evidencia(
          nombre: a.name,
          registrada: DateTime.now(),
          sha256: sha256.convert(bytes).toString(),
          bytes: bytes,
          tipo: _tipo,
          nota: _nota.text.trim(),
        );
        if (_sesion.agregarEvidencia(e)) {
          nuevas.add(e);
        } else {
          repetidas++;
        }
      }
      _estado = [
        if (nuevas.length == 1) 'Listo. Guardamos el archivo en este dispositivo.\nComprobante SHA-256: ${nuevas.first.sha256}',
        if (nuevas.length > 1) 'Listo. Guardamos ${nuevas.length} archivos con su comprobante SHA-256.',
        if (repetidas > 0) '$repetidas archivo(s) ya estaban registrados.',
        if (grandes > 0) '$grandes archivo(s) exceden 12 MB y no se registraron.',
      ].join('\n');
      if (nuevas.isNotEmpty) _nota.clear();
    } catch (e) {
      _estado = 'No se pudo abrir el archivo: $e';
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _sesion,
      builder: (context, _) => Pagina(children: [
        const Aparecer(
          child: Portada(
            ceja: 'Tu evidencia',
            titulo: 'Registra lo que ya conservaste.',
            texto: 'Sube capturas de la publicación, del perfil y de los mensajes. No subas las imágenes íntimas. '
                'Si cambia un solo pixel, el comprobante SHA-256 ya no coincide.',
          ),
        ),
        Aparecer(
          orden: 1,
          child: Tarjeta(
            pista: 'Para el demo, usa solo archivos ficticios. Los archivos se quedan en la memoria de este dispositivo '
                'y se borran al salir.',
            children: [
              const Text('¿Qué es?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 7),
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                items: [for (final t in tiposEvidencia) DropdownMenuItem(value: t, child: Text(t))],
                onChanged: (v) => setState(() => _tipo = v ?? _tipo),
              ),
              const SizedBox(height: 16),
              const Text('Nota opcional', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 7),
              TextField(
                controller: _nota,
                maxLength: 250,
                decoration: const InputDecoration(hintText: 'Ejemplo: mensaje recibido en la tarde.'),
              ),
              const SizedBox(height: 6),
              Boton('Elegir archivo y generar comprobante',
                  icono: Icons.add_photo_alternate_outlined, cargando: _cargando, onTap: _agregar),
              if (_estado != null) ...[
                const SizedBox(height: 12),
                SelectableText(_estado!, style: const TextStyle(fontSize: 13, color: Paleta.gris)),
              ],
            ],
          ),
        ),
        Tarjeta(
          ceja: 'Registradas',
          titulo: _sesion.evidencias.isEmpty ? 'Todavía no registras evidencias' : '${_sesion.evidencias.length} evidencia(s)',
          pista: _sesion.evidencias.isEmpty ? null : 'Toca una evidencia para copiar su comprobante completo.',
          children: [for (final e in _sesion.evidencias) _Fila(key: ValueKey(e.sha256), evidencia: e)],
        ),
      ]),
    );
  }
}

/// Fila que aparece con una marca de "verificado"; al tocarla copia el comprobante completo.
class _Fila extends StatelessWidget {
  const _Fila({super.key, required this.evidencia});
  final Evidencia evidencia;

  @override
  Widget build(BuildContext context) {
    final hora = TimeOfDay.fromDateTime(evidencia.registrada).format(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: movimiento(context, 420),
      curve: Curves.easeOutBack,
      builder: (_, t, hijo) => Opacity(opacity: t.clamp(0, 1), child: Transform.scale(scale: 0.94 + 0.06 * t, child: hijo)),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(
            child: Pressable(
              onTap: () {
                Clipboard.setData(ClipboardData(text: evidencia.sha256));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comprobante copiado.')));
              },
              colorHover: Paleta.verdeSuave,
              semantica: 'Copiar comprobante de ${evidencia.nombre}',
              child: Row(children: [
                const Icon(Icons.verified_outlined, color: Paleta.verde),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(evidencia.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${evidencia.tipo} · $hora · ${evidencia.sha256.substring(0, 16)}…',
                        style: const TextStyle(fontSize: 13, color: Paleta.gris)),
                    if (evidencia.nota.isNotEmpty)
                      Text(evidencia.nota, style: const TextStyle(fontSize: 13, color: Paleta.gris)),
                  ]),
                ),
                const Icon(Icons.copy_rounded, size: 18, color: Paleta.ciruela),
              ]),
            ),
          ),
          IconButton(
            tooltip: 'Quitar ${evidencia.nombre}',
            onPressed: () => Sesion.instancia.quitarEvidencia(evidencia),
            icon: const Icon(Icons.delete_outline, color: Paleta.gris),
            style: IconButton.styleFrom(hoverColor: Paleta.rojoSuave, highlightColor: Paleta.rojoSuave),
          ),
        ]),
      ),
    );
  }
}
