import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sesion.dart';
import '../theme.dart';
import '../widgets/pressable.dart';

class Evidencias extends StatefulWidget {
  const Evidencias({super.key});

  @override
  State<Evidencias> createState() => _EvidenciasState();
}

class _EvidenciasState extends State<Evidencias> {
  final _sesion = Sesion.instancia;
  bool _cargando = false;

  Future<void> _agregar() async {
    setState(() => _cargando = true);
    try {
      final archivos = await FilePicker.pickFiles(type: FileType.image);
      var repetidas = 0;
      for (final a in archivos) {
        final huella = sha256.convert(await a.readAsBytes()).toString();
        if (!_sesion.agregarEvidencia(Evidencia(a.name, DateTime.now(), huella))) repetidas++;
      }
      if (repetidas > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$repetidas captura(s) ya estaban registradas.')),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Evidencias')),
      body: ListenableBuilder(
        listenable: _sesion,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Sube capturas de la publicación, del perfil y de los mensajes. No subas las imágenes íntimas.',
              style: texto.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Cada captura recibe una huella digital (SHA-256). Si alguien cambia un solo pixel, la huella ya no coincide.',
              style: texto.bodyMedium?.copyWith(color: Paleta.tinta.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 18),
            Pressable(
              onTap: _cargando ? null : _agregar,
              color: Paleta.cantera,
              colorHover: const Color(0xFF4F7161),
              borde: Paleta.cantera,
              semantica: 'Agregar capturas',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _cargando
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_photo_alternate_outlined, color: Colors.white),
                  const SizedBox(width: 10),
                  const Text('Agregar capturas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (_sesion.evidencias.isEmpty)
              Text('Todavía no registras capturas.', style: texto.bodyMedium)
            else
              for (final e in _sesion.evidencias) _Fila(key: ValueKey(e.sha256), evidencia: e),
          ],
        ),
      ),
    );
  }
}

/// Fila que aparece con una marca de "verificado"; al tocarla copia la huella completa.
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
        child: Pressable(
          onTap: () {
            Clipboard.setData(ClipboardData(text: evidencia.sha256));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Huella copiada.')));
          },
          colorHover: const Color(0xFFF4F8F6),
          semantica: 'Copiar huella de ${evidencia.nombre}',
          child: Row(
            children: [
              const Icon(Icons.verified_outlined, color: Paleta.cantera),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(evidencia.nombre, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('Registrada a las $hora · ${evidencia.sha256.substring(0, 16)}…',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.copy_rounded, size: 18, color: Paleta.anil),
            ],
          ),
        ),
      ),
    );
  }
}
