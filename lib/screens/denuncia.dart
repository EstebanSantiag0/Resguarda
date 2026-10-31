import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api.dart';
import '../services/gemma.dart';
import '../sesion.dart';
import '../theme.dart';
import '../widgets/pressable.dart';

class Denuncia extends StatefulWidget {
  const Denuncia({super.key});

  @override
  State<Denuncia> createState() => _DenunciaState();
}

class _DenunciaState extends State<Denuncia> {
  final _sesion = Sesion.instancia;
  String? _borrador;
  String? _error;
  bool _cargando = false;

  Future<void> _generar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final texto = await Gemma.responder(
        _sesion.mensajes,
        _sesion.situacion,
        instruccionFinal: 'Con base en esta conversación, escribe el borrador de denuncia '
            'siguiendo el formato indicado en tus reglas. Solo el borrador, sin comentarios.',
      );
      setState(() => _borrador = texto);
    } catch (e) {
      setState(() => _error = 'No pude generar el borrador. Revisa la conexión o la llave de la API.\n$e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _descargarPdf() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final relato = _sesion.mensajes.where((m) => m.deUsuaria).map((m) => m.texto).join('\n');
      final pdf = await ResguardaApi.expediente(relato);
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(pdf, mimeType: 'application/pdf', name: 'expediente-resguarda.pdf')],
        fileNameOverrides: ['expediente-resguarda.pdf'],
        subject: 'Expediente Resguarda',
      ));
    } catch (e) {
      setState(() => _error = 'No pude generar el PDF. Revisa que el servidor de Resguarda esté encendido.\n$e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _documento() {
    final evidencias = _sesion.evidencias.isEmpty
        ? 'Sin evidencias registradas.'
        : _sesion.evidencias
            .map((e) => '- ${e.nombre} (registrada ${e.registrada.toIso8601String()})\n  SHA-256: ${e.sha256}')
            .join('\n');
    return 'BORRADOR DE DENUNCIA — generado con Resguarda (orientativo, no es asesoría legal)\n\n'
        '${_borrador ?? ''}\n\nEVIDENCIAS ANEXAS\n$evidencias';
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final sinRelato = !_sesion.mensajes.any((m) => m.deUsuaria);
    final explicacion = usaApi
        ? 'Armo un PDF con tu relato y la lista de tus evidencias con su huella digital. '
            'Revísalo antes de llevarlo a la Fiscalía.'
        : 'Armo un borrador con lo que me contaste y la lista de tus evidencias. '
            'Revísalo y llévalo a la Fiscalía.';
    return Scaffold(
      appBar: AppBar(title: const Text('Preparar denuncia')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(explicacion, style: texto.bodyLarge),
          const SizedBox(height: 18),
          if (sinRelato)
            Text('Primero cuéntame qué pasó en el chat.', style: texto.titleMedium?.copyWith(color: Paleta.grana))
          else
            Pressable(
              onTap: _cargando ? null : (usaApi ? _descargarPdf : _generar),
              color: Paleta.anil,
              colorHover: const Color(0xFF1A2454),
              borde: Paleta.anil,
              semantica: 'Generar borrador',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_cargando)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  else
                    const Icon(Icons.edit_note, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(usaApi ? 'Descargar expediente PDF' : (_borrador == null ? 'Generar borrador' : 'Generar de nuevo'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: Paleta.grana)),
          ],
          AnimatedSize(
            duration: movimiento(context, 320),
            curve: Curves.easeOutCubic,
            child: _borrador == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Paleta.hilo),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SelectableText(_documento(), style: texto.bodyMedium),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Pressable(
                                onTap: () => SharePlus.instance.share(ShareParams(text: _documento(), subject: 'Borrador de denuncia')),
                                colorHover: const Color(0xFFF7F8FC),
                                semantica: 'Compartir borrador',
                                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.ios_share, color: Paleta.anil, size: 20),
                                  SizedBox(width: 8),
                                  Text('Compartir', style: TextStyle(color: Paleta.anil, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Pressable(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: _documento()));
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(content: Text('Borrador copiado.')));
                                },
                                colorHover: const Color(0xFFF7F8FC),
                                semantica: 'Copiar borrador',
                                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.copy_rounded, color: Paleta.anil, size: 20),
                                  SizedBox(width: 8),
                                  Text('Copiar', style: TextStyle(color: Paleta.anil, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
