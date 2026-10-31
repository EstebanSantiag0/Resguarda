import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/expediente.dart';
import '../services/gemma.dart';
import '../sesion.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'plan_personal.dart' show confirmarBorrado;

/// Paso 3: expediente portable (.zip con PDF, manifiesto, fuentes y evidencias) y borrador de denuncia.
class Expediente extends StatefulWidget {
  const Expediente({super.key});

  @override
  State<Expediente> createState() => _ExpedienteState();
}

class _ExpedienteState extends State<Expediente> {
  final _sesion = Sesion.instancia;
  bool _armando = false;
  bool _redactando = false;
  String? _borrador;
  String? _aviso;

  Future<void> _compartir(Uint8List bytes, String nombre, String tipo) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: tipo, name: nombre)],
      fileNameOverrides: [nombre],
      subject: 'Expediente Resguarda',
    ));
  }

  Future<void> _exportar({required bool soloPdf}) async {
    setState(() {
      _armando = true;
      _aviso = null;
    });
    try {
      final relato = _sesion.relatoCompleto;
      if (soloPdf) {
        await _compartir(crearPdf(relato: relato, plan: _sesion.plan, evidencias: _sesion.evidencias),
            'expediente-resguarda.pdf', 'application/pdf');
      } else {
        final fuentesMd = await rootBundle.loadString('assets/conocimiento/fuentes.md');
        await _compartir(
          crearZip(relato: relato, plan: _sesion.plan, evidencias: _sesion.evidencias, fuentesMd: fuentesMd),
          'expediente-resguarda.zip',
          'application/zip',
        );
      }
    } catch (e) {
      setState(() => _aviso = 'No se pudo preparar el expediente: $e');
    } finally {
      if (mounted) setState(() => _armando = false);
    }
  }

  Future<void> _redactar() async {
    setState(() {
      _redactando = true;
      _aviso = null;
    });
    final plantilla = borradorPlantilla(relato: _sesion.relatoCompleto, plan: _sesion.plan, evidencias: _sesion.evidencias);
    try {
      if (!puedeRedactar) {
        _borrador = plantilla;
        return;
      }
      final historial = _sesion.mensajes.isNotEmpty ? _sesion.mensajes : [Mensaje(true, _sesion.relatoCompleto)];
      _borrador = await Gemma.responder(
        historial,
        _sesion.incidente,
        instruccionFinal: 'Con base en lo que conté, escribe el borrador de denuncia siguiendo el formato indicado '
            'en tus reglas. Solo el borrador, sin comentarios.',
      );
    } catch (e) {
      debugPrint('No se pudo redactar con Gemma: $e');
      _borrador = plantilla;
      _aviso = 'Gemma no respondió; te dejamos una plantilla con tu relato para completar.';
    } finally {
      if (mounted) setState(() => _redactando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _sesion.evidencias.length;
    final sinRelato = _sesion.relatoCompleto.trim().isEmpty;
    final documento = _borrador == null ? null : documentoBorrador(_borrador!, _sesion.evidencias);
    return Pagina(children: [
      const Aparecer(
        child: Portada(
          ceja: 'Expediente',
          titulo: 'Prepara tu expediente para pedir ayuda.',
          texto: 'Junta tu resumen, tu plan, tus evidencias con su comprobante SHA-256 y las fuentes oficiales '
              'en un solo archivo. Se arma en este dispositivo.',
        ),
      ),
      Aparecer(
        orden: 1,
        child: Tarjeta(
          ceja: 'Qué incluye',
          titulo: 'expediente-resguarda.zip',
          children: [
            const _Contenido(Icons.picture_as_pdf_outlined, 'expediente-resguarda.pdf', 'Relato, resumen, plan, rutas y evidencias.'),
            const _Contenido(Icons.data_object, 'manifest.json', 'Metadatos, hashes, plan y fecha de exportación.'),
            const _Contenido(Icons.menu_book_outlined, 'fuentes.md', 'Fuentes oficiales y fecha de revisión.'),
            _Contenido(Icons.folder_outlined, 'evidencias/', n == 0 ? 'Sin evidencias registradas.' : '$n archivo(s).'),
            const SizedBox(height: 16),
            Boton('Descargar expediente (.zip)', icono: Icons.download_rounded, cargando: _armando,
                onTap: () => _exportar(soloPdf: false)),
            const SizedBox(height: 10),
            Boton('Solo el PDF', estilo: Estilo.secundario, onTap: _armando ? null : () => _exportar(soloPdf: true)),
            const SizedBox(height: 14),
            const Text(
              'El SHA-256 permite detectar cambios respecto al archivo registrado; por sí solo no es una cadena de '
              'custodia formal. Este expediente no es una denuncia ni asesoría legal.',
              style: letraFina,
            ),
          ],
        ),
      ),
      Aparecer(
        orden: 2,
        child: Tarjeta(
          ceja: 'Si decides denunciar',
          titulo: 'Borrador de denuncia',
          pista: 'Un texto en primera persona para llevar a la Fiscalía o a quien te acompañe. '
              'Revísalo: donde falte un dato dice [COMPLETAR].',
          children: [
            if (sinRelato)
              const Text('Primero cuenta qué pasó en el paso anterior o en el chat.',
                  style: TextStyle(color: Paleta.rojo, fontWeight: FontWeight.w600))
            else
              Boton(_borrador == null ? 'Generar borrador' : 'Generar de nuevo',
                  icono: Icons.edit_note, estilo: Estilo.secundario, cargando: _redactando, onTap: _redactar),
            if (_aviso != null) ...[
              const SizedBox(height: 12),
              Text(_aviso!, style: const TextStyle(color: Paleta.rojo)),
            ],
            AnimatedSize(
              duration: movimiento(context, 320),
              curve: Curves.easeOutCubic,
              child: documento == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Paleta.lienzo,
                            border: Border.all(color: Paleta.linea),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: SelectableText(documento, style: Theme.of(context).textTheme.bodyMedium),
                        ),
                        const SizedBox(height: 12),
                        FilaBotones(
                          izquierda: Boton('Compartir',
                              icono: Icons.ios_share,
                              estilo: Estilo.contorno,
                              onTap: () => SharePlus.instance
                                  .share(ShareParams(text: documento, subject: 'Borrador de denuncia'))),
                          derecha: Boton('Copiar', icono: Icons.copy_rounded, estilo: Estilo.contorno, onTap: () {
                            Clipboard.setData(ClipboardData(text: documento));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Borrador copiado.')));
                          }),
                        ),
                      ]),
                    ),
            ),
          ],
        ),
      ),
      Aparecer(
        orden: 3,
        child: Tarjeta(
          ceja: 'Al terminar',
          titulo: 'Borrar todo',
          pista: 'Borra relato, plan, conversación y evidencias de Resguarda. No borra el historial del navegador '
              'ni copias que ya descargaste o compartiste.',
          children: [Boton('Borrar archivos de Resguarda', estilo: Estilo.contorno, onTap: () => confirmarBorrado(context))],
        ),
      ),
    ]);
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido(this.icono, this.nombre, this.detalle);
  final IconData icono;
  final String nombre;
  final String detalle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icono, size: 20, color: Paleta.ciruela),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$nombre  ', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: detalle, style: const TextStyle(color: Paleta.gris)),
            ])),
          ),
        ]),
      );
}
