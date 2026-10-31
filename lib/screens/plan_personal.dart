import 'package:flutter/material.dart';

import '../plan.dart';
import '../salida.dart';
import '../sesion.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'chat.dart';
import 'evidencias.dart';
import 'expediente.dart';

/// Paso 2: plan de resguardo, rutas de apoyo, evidencia, expediente y fuentes.
class PlanPersonal extends StatefulWidget {
  const PlanPersonal({super.key});

  @override
  State<PlanPersonal> createState() => _PlanPersonalState();
}

class _PlanPersonalState extends State<PlanPersonal> {
  final _sesion = Sesion.instancia;
  late final _resumen = TextEditingController(text: _sesion.plan?.resumen ?? '');

  @override
  void dispose() {
    _resumen.dispose();
    super.dispose();
  }

  void _ir(Widget pantalla) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _sesion,
      builder: (context, _) {
        final plan = _sesion.plan;
        if (plan == null) return const Pagina(children: [Portada(titulo: 'Todavía no hay un plan.')]);
        final t = Theme.of(context).textTheme;
        final urgente = plan.prioridad == 'Atención inmediata';
        return Pagina(children: [
          const Aparecer(
            child: Portada(
              ceja: 'Tu plan personal',
              titulo: 'Esto es lo primero que puedes hacer.',
              texto: 'Lee con calma. Puedes guardar evidencia sin tomar decisiones legales en este momento.',
            ),
          ),
          Aparecer(
            orden: 1,
            child: Tarjeta(children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: urgente ? Paleta.rojoSuave : Paleta.ciruelaSuave,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(plan.prioridad,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: urgente ? Paleta.rojo : Paleta.ciruelaOscura)),
                ),
              ),
              const SizedBox(height: 8),
              Semantics(header: true, child: Text(plan.etiqueta, style: t.headlineSmall)),
              const SizedBox(height: 6),
              Text(plan.accionInmediata, style: t.bodyLarge),
              if (urgente) ...[
                const SizedBox(height: 12),
                Boton('Llamar al 911', icono: Icons.call, estilo: Estilo.peligro, onTap: () => llamar('911')),
              ],
              const SizedBox(height: 22),
              Text('Haz esto ahora', style: t.titleMedium?.copyWith(fontSize: 17)),
              const SizedBox(height: 6),
              for (var i = 0; i < plan.pasos.length; i++)
                _Paso(texto: plan.pasos[i], hecho: _sesion.pasosHechos.contains(i), onTap: () => _sesion.alternarPaso(i)),
              const SizedBox(height: 22),
              Text('Resumen para pedir ayuda', style: t.titleMedium?.copyWith(fontSize: 17)),
              const SizedBox(height: 4),
              Text('Puedes editarlo antes de exportar. No es una denuncia.',
                  style: t.bodyMedium?.copyWith(color: Paleta.gris)),
              const SizedBox(height: 10),
              TextField(
                controller: _resumen,
                maxLength: 500,
                minLines: 3,
                maxLines: 8,
                onChanged: (v) => plan.resumen = v.trim(),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Paleta.verdeSuave,
                  border: Border(left: BorderSide(color: Paleta.verde, width: 3)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5, right: 8),
                    child: Icon(Icons.circle, size: 8, color: Paleta.verde),
                  ),
                  Expanded(child: Text(plan.estadoModelo, style: const TextStyle(fontSize: 13, color: Paleta.verde))),
                ]),
              ),
            ]),
          ),
          Aparecer(
            orden: 2,
            child: Tarjeta(
              ceja: 'Cuando estés lista',
              titulo: 'Dónde pedir orientación',
              pista: 'Resguarda no puede presentar una denuncia. Estas rutas oficiales pueden orientarte '
                  'sobre el siguiente paso.',
              children: [
                for (var i = 0; i < plan.rutas.length; i++) _RutaApoyo(ruta: plan.rutas[i], ultima: i == plan.rutas.length - 1),
              ],
            ),
          ),
          Aparecer(
            orden: 3,
            child: Tarjeta(
              ceja: 'Tu evidencia',
              titulo: 'Registra lo que ya conservaste',
              pista: 'Cada archivo recibe un comprobante SHA-256 y se queda en este dispositivo. '
                  'No subas las imágenes íntimas: bastan capturas de la publicación o del mensaje.',
              children: [
                Text(
                  _sesion.evidencias.isEmpty
                      ? 'Todavía no registras evidencias.'
                      : '${_sesion.evidencias.length} evidencia(s) registrada(s) con su comprobante.',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: _sesion.evidencias.isEmpty ? Paleta.gris : Paleta.verde),
                ),
                const SizedBox(height: 14),
                Boton('Guardar evidencia y generar comprobante',
                    icono: Icons.fingerprint, estilo: Estilo.secundario, onTap: () => _ir(const Evidencias())),
                const SizedBox(height: 10),
                Boton('Preparar expediente para pedir ayuda',
                    icono: Icons.folder_zip_outlined, onTap: () => _ir(const Expediente())),
                const SizedBox(height: 10),
                Boton('Borrar archivos de Resguarda',
                    estilo: Estilo.contorno, onTap: () => confirmarBorrado(context)),
                const SizedBox(height: 14),
                const Text(
                  'El expediente contiene un resumen, evidencia registrada, hashes y fuentes. '
                  'No reemplaza una denuncia ni una cadena de custodia formal.',
                  style: letraFina,
                ),
              ],
            ),
          ),
          Aparecer(
            orden: 4,
            child: Tarjeta(
              ceja: '¿Tienes dudas?',
              titulo: 'Pregunta a Resguarda',
              pista: 'Chatea con Gemma sobre tu situación: qué guardar, cómo reportar en cada red social '
                  'y dónde pedir ayuda. Solo usa fuentes verificadas.',
              children: [
                Boton('Abrir chat', icono: Icons.chat_bubble_outline, estilo: Estilo.secundario, onTap: () => _ir(const Chat())),
              ],
            ),
          ),
          Aparecer(
            orden: 5,
            child: Tarjeta(
              ceja: 'Información que usamos',
              titulo: 'Fuentes oficiales',
              children: [for (final f in plan.fuentes) _FuenteOficial(fuente: f)],
            ),
          ),
        ]);
      },
    );
  }
}

/// Pide confirmación, borra todo y regresa al inicio.
Future<void> confirmarBorrado(BuildContext context) async {
  final si = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('¿Borrar todo?'),
      content: const Text('Se borran tu relato, tu plan, la conversación y las evidencias registradas en Resguarda. '
          'No se borran el historial del navegador ni archivos que ya descargaste o compartiste.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Paleta.rojo),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Borrar todo'),
        ),
      ],
    ),
  );
  if (si != true || !context.mounted) return;
  final navegador = Navigator.of(context);
  final mensajero = ScaffoldMessenger.of(context);
  await borrarTodo();
  navegador.popUntil((r) => r.isFirst);
  mensajero.showSnackBar(const SnackBar(content: Text('Archivos de Resguarda borrados.')));
}

class _Paso extends StatelessWidget {
  const _Paso({required this.texto, required this.hecho, required this.onTap});
  final String texto;
  final bool hecho;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: hecho,
      button: true,
      label: texto,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        hoverColor: Paleta.ciruelaSuave.withValues(alpha: 0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDF0F3)))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedContainer(
              duration: movimiento(context, 160),
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 2, right: 10),
              decoration: BoxDecoration(
                color: hecho ? Paleta.ciruela : Colors.white,
                border: Border.all(color: Paleta.ciruela, width: 1.5),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(Icons.check, size: 14, color: hecho ? Colors.white : Paleta.ciruela),
            ),
            Expanded(
              child: Text(texto,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: hecho ? Paleta.gris : Paleta.tinta,
                    decoration: hecho ? TextDecoration.lineThrough : null,
                  )),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RutaApoyo extends StatelessWidget {
  const _RutaApoyo({required this.ruta, required this.ultima});
  final Ruta ruta;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          border: ultima ? null : const Border(bottom: BorderSide(color: Color(0xFFEDF0F3)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ruta.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(ruta.detalle, style: const TextStyle(fontSize: 14, color: Paleta.gris)),
        Wrap(spacing: 4, children: [
          if (ruta.telefono != null)
            TextButton.icon(
              onPressed: () => llamar(ruta.telefono!),
              icon: const Icon(Icons.call, size: 16),
              label: Text('Llamar al ${ruta.telefono}'),
            ),
          if (ruta.url.isNotEmpty)
            TextButton.icon(
              onPressed: () => abrir(ruta.url),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Ver sitio oficial'),
            ),
        ]),
      ]),
    );
  }
}

class _FuenteOficial extends StatelessWidget {
  const _FuenteOficial({required this.fuente});
  final Fuente fuente;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(border: Border.all(color: Paleta.linea), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(fuente.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(fuente.editor, style: const TextStyle(fontSize: 13, color: Paleta.gris)),
        TextButton(
          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
          onPressed: () => abrir(fuente.url),
          child: const Text('Abrir fuente oficial'),
        ),
      ]),
    );
  }
}
