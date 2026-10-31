import 'package:flutter/material.dart';

import '../salida.dart';
import '../services/gemma.dart';
import '../plan.dart';
import '../sesion.dart';
import '../theme.dart';
import '../widgets/burbuja.dart';
import '../widgets/comunes.dart' show Logo;
import 'expediente.dart';
import 'evidencias.dart';

class Chat extends StatefulWidget {
  const Chat({super.key});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final _sesion = Sesion.instancia;
  final _entrada = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _sesion.addListener(_bajar);
  }

  @override
  void dispose() {
    _sesion.removeListener(_bajar);
    _entrada.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _bajar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: movimiento(context, 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _enviar() async {
    final texto = _entrada.text.trim();
    if (texto.isEmpty || _sesion.pensando) return;
    _entrada.clear();
    _sesion.agregarMensaje(Mensaje(true, texto));
    _sesion.ponerPensando(true);
    try {
      final respuesta = await Gemma.responder(_sesion.mensajes, _sesion.incidente);
      _sesion.agregarMensaje(Mensaje(false, respuesta));
    } catch (e) {
      debugPrint('Error del modelo: $e');
      _sesion.agregarMensaje(Mensaje(false, respuestaSinConexion));
    } finally {
      _sesion.ponerPensando(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Row(children: [Logo(tamano: 30), SizedBox(width: 10), Flexible(child: Text('Pregunta a Resguarda'))]),
        actions: [
          IconButton(
            tooltip: 'Evidencias',
            icon: const Icon(Icons.fingerprint),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Evidencias())),
          ),
          IconButton(
            tooltip: 'Expediente',
            icon: const Icon(Icons.folder_zip_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Expediente())),
          ),
          const BotonSalir(),
        ],
      ),
      body: ListenableBuilder(
        listenable: _sesion,
        builder: (context, _) {
          final mensajes = _sesion.mensajes;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(margenLateral(context) - 6, 16, margenLateral(context) - 6, 8),
                  children: [
                    if (mensajes.isEmpty) _Bienvenida(incidente: _sesion.incidente),
                    for (final m in mensajes) Burbuja(key: ObjectKey(m), mensaje: m),
                    if (_sesion.pensando) const Escribiendo(),
                  ],
                ),
              ),
              _Entrada(controlador: _entrada, alEnviar: _enviar, ocupado: _sesion.pensando),
            ],
          );
        },
      ),
    );
  }
}

class _Bienvenida extends StatelessWidget {
  const _Bienvenida({this.incidente});
  final Incidente? incidente;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lo que te pasa no es tu culpa.', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Pregúntame qué guardar como prueba, cómo reportar en cada red social o dónde pedir ayuda. '
            'Evita nombres, contraseñas, direcciones o teléfonos.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (incidente != null) ...[
            const SizedBox(height: 12),
            Text('Elegiste: ${incidente!.opcion}', style: const TextStyle(color: Paleta.ciruela, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _Entrada extends StatelessWidget {
  const _Entrada({required this.controlador, required this.alEnviar, required this.ocupado});
  final TextEditingController controlador;
  final VoidCallback alEnviar;
  final bool ocupado;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Paleta.linea))),
      padding: EdgeInsets.fromLTRB(margenLateral(context) - 6, 10, margenLateral(context) - 12, MediaQuery.of(context).padding.bottom + 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controlador,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => alEnviar(),
              decoration: const InputDecoration(
                hintText: 'Escribe o dicta con el micrófono del teclado',
                border: InputBorder.none,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: movimiento(context, 180),
            transitionBuilder: (hijo, a) => ScaleTransition(scale: a, child: hijo),
            child: ocupado
                ? const Padding(
                    key: ValueKey('ocupado'),
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
                  )
                : IconButton.filled(
                    key: const ValueKey('enviar'),
                    tooltip: 'Enviar',
                    onPressed: alEnviar,
                    icon: const Icon(Icons.arrow_upward),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((s) =>
                          s.contains(WidgetState.pressed) || s.contains(WidgetState.hovered)
                              ? Paleta.ciruelaOscura
                              : Paleta.ciruela),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
