# 🛡️ Resguarda

Asistente local y sin conexión para orientación inicial frente a violencia digital. Recupera información de documentos locales, usa un modelo Gemma ejecutado con Ollama, registra evidencias con SHA-256 y genera un PDF orientativo.

> **Límite importante:** no sustituye servicios de emergencia, acompañamiento especializado ni asesoría legal. No determina delitos. La descarga inicial del modelo requiere internet; después de descargarlo, la aplicación funciona en la red local sin enviar el relato a un servicio externo.

## Demo rápida

```bash
# Terminal 1: instalar dependencias de la aplicación
uv sync

# Terminal 2: una vez instalado Ollama y descargado el modelo
ollama pull gemma4
ollama serve

# Terminal 1: iniciar Resguarda
uv run uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Abre `http://127.0.0.1:8000`.

Si el modelo disponible tiene otro nombre, cambia la variable antes de iniciar:

```bash
MODEL_NAME=gemma3:4b uv run uvicorn app.main:app
```

## Cómo funciona

1. La aplicación hace recuperación local sobre archivos Markdown en `documents/`.
2. Envía únicamente los fragmentos encontrados y la pregunta al servidor local de Ollama (`127.0.0.1`).
3. Gemma redacta una orientación con límites de seguridad y fuentes mostradas.
4. Las evidencias permanecen en `data/evidence/`, con fecha y SHA-256.
5. El PDF se genera localmente y puede borrarse junto con las evidencias.

## Modelo y dependencias

- **Modelo:** Gemma ejecutado localmente con [Ollama](https://ollama.com/). Consultar los términos/licencia de la variante exacta descargada antes de distribuirla.
- **Dependencias:** FastAPI, Uvicorn y python-multipart.
- **RAG:** búsqueda léxica local sobre documentos curados. En una siguiente versión puede sustituirse por embeddings locales, sin cambiar el principio de privacidad.

## Fuentes

Los archivos en `documents/` son demostrativos. Antes de uso real, deben sustituirse por fuentes verificadas, vigentes y contextualizadas para Oaxaca, incluyendo enlaces, fecha de consulta y responsable de curaduría.

## Privacidad y límites

- No subas evidencia real durante la demostración.
- Usa casos ficticios y capturas simuladas.
- No uses Resguarda como almacenamiento forense definitivo: el hash demuestra integridad respecto al archivo guardado por la app, no certifica por sí solo cadena de custodia.
- La app no ofrece “salida rápida” capaz de borrar el historial del navegador; el botón de borrado elimina solo los archivos que creó Resguarda.

## Licencia

Apache-2.0. Ver [LICENSE](LICENSE).
