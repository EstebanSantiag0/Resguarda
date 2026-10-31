# Arquitectura

```
Inicio (situaciones, 911/089) ──▶ Chat ──▶ Gemma.responder()
   │                               │          ├─ Google AI Studio (GEMMA_API_KEY, GEMMA_MODEL)
   │                               │          └─ Ollama en la laptop (OLLAMA_URL, OLLAMA_MODEL)
   └──▶ Evidencias (SHA-256)  ◀────┤
                                   └──▶ Denuncia (borrador + evidencias → compartir/copiar)
```

- **Estado**: `Sesion` (ChangeNotifier singleton) en memoria; `borrarTodo()` en "Salir".
- **Conocimiento**: `skills.md` + documentos de `assets/conocimiento/` se pegan completos como
  instrucciones (son pocos KB; no hace falta RAG en el teléfono).
- **Gemma en Google**: no admite *system instruction*, por eso las reglas van al inicio del primer turno.
- **Sin conexión**: si falla el modelo, el chat responde `respuestaSinConexion` con pasos básicos.
- **Android**: permiso INTERNET, `usesCleartextTraffic` (Ollama por HTTP en la red local) y
  `<queries>` para abrir el marcador `tel:`.
- **Paquetes**: solo los que ya estaban en la caché de pub (http, crypto, url_launcher,
  file_picker, share_plus), porque el internet del evento era muy lento.
