# Arquitectura

Mismo recorrido que el prototipo web del Hack Day (`backend/app/index.html`), en Flutter:

```
Inicio: ¿estás en peligro? ──▶ Relato (triage) ──▶ Plan personal ──┬──▶ Evidencias (SHA-256, tipo, nota)
   └─ 911 / 089                   5 situaciones      checklist        ├──▶ Expediente (.zip / PDF, borrador)
                                  + relato opcional  rutas de apoyo   ├──▶ Chat con Gemma
                                                     fuentes          └──▶ Borrar todo
```

- **Plan** (`lib/plan.dart`): reglas fijas (pasos, prioridad, rutas, fuentes), iguales a `build_plan`
  del backend. Gemma solo aporta un resumen breve que `MapaIncidente.validar` revisa (longitud,
  palabras prohibidas, `@`); si falla, el plan sale igual, solo con reglas.
- **Modelo** (`lib/services/gemma.dart`), en este orden: backend de Resguarda (`RESGUARDA_API`) →
  Ollama (`OLLAMA_URL`) → Google AI Studio (`GEMMA_API_KEY`) → sin modelo (reglas + respuesta fija).
  El encabezado dice honestamente dónde se procesa el relato.
- **Expediente** (`lib/services/expediente.dart`): PDF de texto (Helvetica + WinAnsi, sin paquetes)
  y `.zip` con `archive`: `expediente-resguarda.pdf`, `manifest.json`, `fuentes.md`, `evidencias/`.
  Se arma en el teléfono; no hace falta el backend.
- **Estado**: `Sesion` (ChangeNotifier singleton) en memoria, incluidos los bytes de las evidencias;
  "Salir" y "Borrar archivos de Resguarda" llaman a `borrarTodo()` (y a `/api/delete-all` si hay backend).
- **Conocimiento**: `skills.md` + documentos de `assets/conocimiento/` se pegan completos como
  instrucciones del chat (son pocos KB; no hace falta RAG en el teléfono).
- **Gemma en Google**: no admite *system instruction*, por eso las reglas van al inicio del primer turno.
- **Backend** (`backend/`): FastAPI + Ollama, con `TrustedHostMiddleware` (DNS rebinding),
  encabezado `X-Resguarda` obligatorio en POST (CSRF) y CORS solo para orígenes locales.
- **Android**: permiso INTERNET, `usesCleartextTraffic` (Ollama/backend por HTTP en la red local) y
  `<queries>` para abrir el marcador `tel:`.
- **Paquetes**: solo los que ya estaban en la caché de pub (http, crypto, url_launcher,
  file_picker, share_plus, archive), porque el internet del evento era muy lento.
