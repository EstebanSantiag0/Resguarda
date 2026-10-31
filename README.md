<p align="center"><img src="assets/icon/logo.png" width="120" alt="Logo de Resguarda"></p>

# Resguarda

**Primeros pasos ante violencia digital en Oaxaca, sin crear cuenta y sin guardar nada al salir.**

Resguarda transforma un incidente breve en un plan de resguardo verificable: pregunta primero si hay
peligro, clasifica la situación, muestra una checklist basada en fuentes oficiales, registra evidencias
con su comprobante SHA-256 y exporta un expediente portable. Gemma (local o en la nube) organiza el
relato y responde dudas en un chat; las acciones sensibles salen de reglas verificables, no del modelo.

Proyecto del **Hacktoberfest Hack Day Oaxaca 2026**. App Flutter (Android, iOS y web) + backend
FastAPI con Gemma en Ollama.

> Resguarda no presenta denuncias, no determina delitos y no sustituye servicios de emergencia,
> acompañamiento especializado ni asesoría legal.

## Recorrido
1. **¿Estás en peligro ahora?** Si la respuesta es sí o "no estoy segura": llamar al **911**,
   denuncia anónima **089** y la opción de continuar solo si es seguro.
2. **Cuéntame solo lo esencial.** Elige la situación (amenazas, contenido íntimo, sextorsión, cuenta
   comprometida o suplantación), escribe lo que pasó sin datos identificables y marca si ya tienes
   evidencia o si tu cuenta puede estar comprometida.
3. **Tu plan personal.** Prioridad, acción inmediata, checklist marcable, **resumen para pedir ayuda**
   (editable), rutas de apoyo (911, Secretaría de las Mujeres de Oaxaca 951 454 0508, Centros de
   Justicia para las Mujeres) y fuentes oficiales.
4. **Evidencias.** Tipo (captura, mensaje, correo…), nota opcional y comprobante **SHA-256**
   calculado en el dispositivo. Toca una evidencia para copiar su comprobante.
5. **Expediente.** `expediente-resguarda.zip` armado en el teléfono:
   ```text
   expediente-resguarda.zip
   ├── expediente-resguarda.pdf   relato, resumen, plan, rutas y evidencias
   ├── manifest.json              metadatos, hashes, plan y fecha de exportación
   ├── fuentes.md                 fuentes oficiales y fecha de revisión
   └── evidencias/
   ```
   También: solo el PDF, y un **borrador de denuncia** (Gemma, o una plantilla con `[COMPLETAR]` si
   no hay modelo) para compartir o copiar.
6. **Pregunta a Resguarda.** Chat con Gemma que solo usa las fuentes de `assets/conocimiento/`.
7. **Salir / Borrar todo.** Borra relato, plan, conversación y evidencias (y los archivos del backend).

## Cómo correrla

```bash
flutter pub get --offline
flutter run --release                     # sin modelo: plan con reglas locales y expediente funcionan igual
```

Elige **una** fuente de modelo con `--dart-define`:

| Opción | Comando | Privacidad |
|---|---|---|
| **Backend de Resguarda** (recomendado) | `--dart-define=RESGUARDA_API=http://IP_DE_LA_LAPTOP:8000` | Local |
| **Ollama en la laptop** | `--dart-define=OLLAMA_URL=http://IP:11434 --dart-define=OLLAMA_MODEL=gemma3:1b` | Local |
| **Google AI Studio** | `--dart-define=GEMMA_API_KEY=TU_LLAVE --dart-define=GEMMA_MODEL=gemma-3-27b-it` | El relato sale a Google |

El encabezado muestra cuál se usa ("Procesamiento local", "Gemma en la nube" o "Sin conexión").

### Backend (FastAPI + Gemma en Ollama)
```bash
ollama pull gemma3:1b && ollama serve
cd backend && uv sync          # o: python -m venv .venv && .venv/bin/pip install fastapi uvicorn python-multipart
MODEL_NAME=gemma3:1b uv run uvicorn app.main:app --host 127.0.0.1 --port 8000
```
Abre `http://localhost:8000` para la versión web del prototipo. Para el celular, permite la IP de la
laptop: `ALLOWED_HOSTS=localhost,127.0.0.1,IP_DE_LA_LAPTOP ... --host 0.0.0.0` y úsalo solo en el
hotspot propio (no tiene contraseña). Detalles en [`backend/README.md`](backend/README.md).

### Para que abra rápido
- Presenten con `--release` (o instalen `build/app/outputs/flutter-apk/app-release.apk`).
- Web: `flutter build web --release --no-web-resources-cdn`; sin esa opción el navegador descarga
  el motor gráfico de internet al abrir.
- El ícono se ve de inmediato sobre el mismo fondo claro de la app (Android, iOS y web), sin destellos.
  Para regenerar íconos: `dart run flutter_launcher_icons`.

## Antes de presentarla
- **No subas la llave de la API** ni la pegues en el código: solo con `--dart-define`.
- Usa únicamente historias y archivos **ficticios** en la demostración.
- `assets/conocimiento/contactos.md` aún tiene datos **PENDIENTE VERIFICAR** (Fiscalía, policía
  cibernética). Llénenlos solo con fuentes oficiales. Las rutas y fuentes de `rutas_de_apoyo.md` y
  `fuentes.md` se revisaron el 31 de octubre de 2026.
- El SHA-256 detecta cambios respecto al archivo registrado; por sí solo no es cadena de custodia.

## Estructura
| Archivo | Qué hace |
|---|---|
| `lib/screens/inicio.dart` | ¿Estás en peligro? 911, 089 y acceso a evidencias. |
| `lib/screens/relato.dart` | Triage: situación, relato y casillas. |
| `lib/screens/plan_personal.dart` | Plan, rutas de apoyo, evidencia, chat y fuentes. |
| `lib/screens/evidencias.dart` | Evidencias con tipo, nota y SHA-256. |
| `lib/screens/expediente.dart` | `.zip`, PDF y borrador de denuncia. |
| `lib/screens/chat.dart` | Chat con Gemma. |
| `lib/plan.dart` | Situaciones, fuentes, rutas y reglas del plan. |
| `lib/services/expediente.dart` | Generador de PDF y `.zip`. |
| `lib/services/gemma.dart` · `api.dart` | Backend, Ollama o Google AI Studio. |
| `lib/widgets/comunes.dart` · `pressable.dart` | Encabezado con logo, tarjetas y botones con estados. |
| `backend/` | FastAPI + Ollama, versión web del prototipo. |

## Diseño
Lienzo claro, tarjetas blancas y **ciruela** como acento (combina con el morado del logo); verde para
lo privado y verificado, rojo para emergencia. Todos los botones tienen estados hover, presionado y
foco, y las animaciones se desactivan si el sistema pide reducir movimiento.

## Licencia
Backend: [Apache-2.0](backend/LICENSE).

## Autoría
La idea, el diseño del proyecto y su desarrollo son de **Esteban Santiago** y su equipo del Hack Day
Oaxaca (incluido el prototipo web de `backend/`). Claude (IA de Anthropic) ayudó a generar el código
base de la app y a redactar esta documentación.
