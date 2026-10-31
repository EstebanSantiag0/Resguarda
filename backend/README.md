<p align="center"><img src="app/logo.png" width="96" alt="Logo de Resguarda"></p>

# Resguarda (backend y versión web)

**Navegador local de evidencia digital para situaciones de violencia digital.**

Resguarda transforma un incidente breve en un plan de resguardo verificable: clasifica el contexto con Gemma ejecutado localmente, muestra una checklist basada en fuentes locales, registra archivos con SHA-256 y exporta un expediente portable.

> Resguarda no presenta denuncias, no determina delitos y no sustituye servicios de emergencia, acompañamiento especializado ni asesoría legal.

## Demo rápida

```bash
# Instala las dependencias de la aplicación
uv sync

# Una vez: instala Ollama y descarga un modelo Gemma local
ollama pull gemma3:1b

# Ejecuta la aplicación
MODEL_NAME="gemma3:1b" uv run uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Abre `http://localhost:8000`. Para la demostración usa únicamente historias y archivos ficticios.

## Recorrido del producto

1. Selecciona el tipo de incidente: amenazas, contenido íntimo, sextorsión, suplantación o cuenta comprometida.
2. Responde preguntas de triage sin datos identificables.
3. Gemma genera un resumen local y Resguarda lo valida; la app compone el plan de seguridad y evidencia con reglas deterministas.
4. Registra evidencias locales: archivo, fecha y SHA-256.
5. Descarga `expediente-resguarda.zip` con PDF, manifiesto JSON, evidencias y fuentes.

## Qué demuestra la IA

Gemma es una parte importante, pero delimitada: convierte el contexto opcional en un resumen breve y estructurado que Resguarda valida antes de usar. Las acciones sensibles (emergencia, privacidad, checklist y fuentes) se controlan mediante lógica verificable de la aplicación, no con texto libre del modelo.

Esto evita usar un modelo pequeño como autoridad legal y convierte la inferencia local en un **harness de seguridad reutilizable**.

## Contenido del expediente

```text
expediente-resguarda.zip
├── expediente-resguarda.pdf
├── manifest.json
├── fuentes.md
└── evidencias/
```

El manifiesto almacena metadatos, hashes, plan y fecha de exportación. El SHA-256 permite detectar cambios respecto al archivo registrado por la aplicación; por sí solo no es una cadena de custodia formal.

## Arquitectura

```text
Interfaz local ──▶ FastAPI ──▶ Ollama + Gemma (localhost)
                      ├── documentos/   fuentes curadas
                      ├── data/evidence/ archivos y manifiesto
                      └── data/reports/  PDF y ZIP locales
```

| Ruta | Función |
| --- | --- |
| `POST /api/plan` | Triage y plan de resguardo validado |
| `POST /api/evidence` | Registra archivo y calcula SHA-256 |
| `POST /api/export` | Exporta ZIP portable |
| `POST /api/delete-all` | Borra archivos creados por Resguarda |
| `POST /api/chat` | Orientación con Gemma sobre fuentes locales (la usa el chat de la app) |

## Seguridad

- **CSRF:** todo `POST /api/*` exige el encabezado `X-Resguarda: 1` (lo mandan la web y la app Flutter).
  Una página ajena no puede enviarlo sin pasar por CORS, que solo acepta orígenes locales
  (`CORS_ORIGIN_REGEX` para agregar otros).
- **DNS rebinding:** solo se aceptan peticiones a `ALLOWED_HOSTS` (por defecto `localhost,127.0.0.1`).
  Para usarlo desde el celular: `ALLOWED_HOSTS=localhost,127.0.0.1,IP_DE_LA_LAPTOP` y `--host 0.0.0.0`,
  solo en una red propia: no tiene contraseña.
- **Evidencias solo en la laptop:** `/api/evidence`, `/api/export` y `/api/report` responden solo a
  `127.0.0.1`/`::1`. Aunque el backend escuche en la red, nadie más en el Wi-Fi puede subir ni descargar
  evidencias. La app Flutter no los usa: arma el expediente en el teléfono.

## Fuentes y límites

- Las fuentes locales están en [`documents/`](documents/) y se mantienen según [`DOCUMENTOS.md`](DOCUMENTOS.md).
- Antes de cualquier uso fuera del demo, una persona responsable debe verificar vigencia, enlaces, rutas de atención y contenido jurídico.
- La descarga inicial del modelo requiere internet. Después de descargarse, Gemma y Resguarda operan localmente.
- Para un dispositivo con capacidad suficiente, se recomienda una variante Gemma instruccional más grande (por ejemplo `gemma4`): `MODEL_NAME=gemma4`.

## Modelo y licencia

- **Modelo:** Gemma ejecutado localmente con [Ollama](https://ollama.com/).
- **Modelo de demo:** `gemma3:1b`.
- Verificar los términos de la variante Gemma distribuida antes de redistribuir los pesos.

## Licencia

Código: [Apache-2.0](LICENSE). La app móvil está en la raíz del repositorio (ver el [README principal](../README.md)).
