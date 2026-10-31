import 'package:flutter/material.dart';

import '../plan.dart';
import '../services/gemma.dart';
import '../sesion.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import '../widgets/pressable.dart';
import 'plan_personal.dart';

/// Paso 1: triage sin datos identificables.
class Relato extends StatefulWidget {
  const Relato({super.key});

  @override
  State<Relato> createState() => _RelatoState();
}

class _RelatoState extends State<Relato> {
  final _sesion = Sesion.instancia;
  late final _notas = TextEditingController(text: _sesion.relato);
  bool _cargando = false;
  bool _faltaIncidente = false;

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  Future<void> _crearPlan() async {
    if (_sesion.incidente == null) {
      setState(() => _faltaIncidente = true);
      return;
    }
    setState(() => _cargando = true);
    _sesion.relato = _notas.text.trim();
    try {
      _sesion.guardarPlan(await Gemma.crearPlan(_sesion));
      if (mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlanPersonal()));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: _sesion,
      builder: (context, _) => Pagina(children: [
        const Aparecer(
          child: Portada(
            ceja: 'Primer paso',
            titulo: 'Cuéntame solo lo esencial.',
            texto: 'Escribe con tus palabras. Evita nombres, contraseñas, direcciones, teléfonos o contenido íntimo.',
          ),
        ),
        Aparecer(
          orden: 1,
          child: Tarjeta(
            titulo: '¿Qué necesitas resolver?',
            children: [
              for (final i in incidentes) ...[
                _Opcion(
                  incidente: i,
                  elegida: _sesion.incidente == i,
                  onTap: () {
                    _sesion.elegirIncidente(i);
                    setState(() => _faltaIncidente = false);
                  },
                ),
                const SizedBox(height: 10),
              ],
              if (_faltaIncidente)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('Elige la opción que más se parezca a tu situación.',
                      style: TextStyle(color: Paleta.rojo, fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 8),
              Text('Lo que pasó (opcional)', style: t.titleMedium?.copyWith(fontSize: 14)),
              const SizedBox(height: 7),
              TextField(
                controller: _notas,
                maxLength: 500,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Ejemplo: recibí mensajes donde me presionan y amenazan con publicar fotos.',
                ),
              ),
              _Casilla(
                valor: _sesion.tieneEvidencia,
                texto: 'Ya tengo mensajes, capturas o archivos guardados',
                onChanged: (v) => setState(() => _sesion.tieneEvidencia = v),
              ),
              _Casilla(
                valor: _sesion.cuentaComprometida,
                texto: 'También creo que mi cuenta puede estar comprometida',
                onChanged: (v) => setState(() => _sesion.cuentaComprometida = v),
              ),
              const SizedBox(height: 14),
              Boton(_cargando ? 'Organizando tu información…' : 'Ver qué puedo hacer ahora',
                  cargando: _cargando, onTap: _crearPlan),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({required this.incidente, required this.elegida, required this.onTap});
  final Incidente incidente;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: elegida,
      child: Pressable(
        onTap: onTap,
        color: elegida ? Paleta.ciruelaSuave : Colors.white,
        colorHover: elegida ? Paleta.ciruelaSuave : const Color(0xFFFBFAFB),
        borde: elegida ? Paleta.ciruela : Paleta.linea,
        radio: 12,
        padding: const EdgeInsets.all(15),
        semantica: incidente.opcion,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(incidente.opcion,
                  style: TextStyle(fontWeight: FontWeight.w700, color: elegida ? Paleta.ciruelaOscura : Paleta.tinta)),
              const SizedBox(height: 2),
              Text(incidente.detalle, style: const TextStyle(fontSize: 13, color: Paleta.gris)),
            ]),
          ),
          AnimatedOpacity(
            opacity: elegida ? 1 : 0,
            duration: movimiento(context, 160),
            child: const Icon(Icons.check_circle, color: Paleta.ciruela),
          ),
        ]),
      ),
    );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({required this.valor, required this.texto, required this.onChanged});
  final bool valor;
  final String texto;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        hoverColor: Paleta.neutro,
        onTap: () => onChanged(!valor),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Checkbox(value: valor, onChanged: (v) => onChanged(v ?? false)),
            Expanded(child: Text(texto, style: const TextStyle(fontSize: 14))),
          ]),
        ),
      ),
    );
  }
}
