# 🛡️ Resguarda (app móvil)

App Flutter (Android/iOS) de **orientación legal ante violencia digital** en Oaxaca: difusión de
imágenes íntimas sin consentimiento (Ley Olimpia), acoso, sextorsión y suplantación de identidad.
Proyecto del **Hacktoberfest Hack Day Oaxaca 2026**.

## Qué hace
1. **¿Qué está pasando?** La persona elige su situación.
2. **Cuéntame**: chat con Gemma que valida, explica, dice qué evidencia guardar y dónde denunciar.
   Sus reglas están en `assets/conocimiento/skills.md` y solo usa los datos de
   `assets/conocimiento/*.md`.
3. **Evidencias**: registra capturas con su **huella SHA-256** (se calcula en el teléfono).
4. **Preparar denuncia**: borrador generado con la conversación + lista de evidencias, para
   compartir o copiar.
5. **Salir**: borra todo lo de la sesión y cierra la app. **911** y **089** siempre visibles.

Nada se guarda en el teléfono: todo vive en memoria mientras la app está abierta.

## Cómo correrla paso a paso
1. Conecta el celular Android por USB con la **depuración USB** activada
   (Ajustes → Acerca del teléfono → toca 7 veces "Número de compilación" → Opciones de desarrollador).
2. Verifica que Flutter lo ve:
   ```bash
   flutter devices
   ```
3. Instala dependencias (ya están en caché, no necesita internet):
   ```bash
   flutter pub get --offline
   ```
4. Ejecuta con **una** de estas dos opciones de modelo:

   **A. Gemma en Google AI Studio** (necesita internet en el celular):
   ```bash
   flutter run --dart-define=GEMMA_API_KEY=TU_LLAVE --dart-define=GEMMA_MODEL=gemma-3-27b-it
   ```
   Cambia `GEMMA_MODEL` por el nombre exacto del modelo Gemma que tengan en AI Studio.

   **B. Modelo local en la laptop con Ollama** (sin internet, celular y laptop en la misma red):
   ```bash
   OLLAMA_HOST=0.0.0.0 ollama serve          # en la laptop
   flutter run --dart-define=OLLAMA_URL=http://IP_DE_LA_LAPTOP:11434 --dart-define=OLLAMA_MODEL=gemma3:1b
   ```

Si el modelo no responde, el chat muestra pasos básicos de seguridad que no dependen de internet.

## ⚠️ Antes de presentarla
- **No subas la llave de la API a GitHub** ni la pegues en el código: pásala solo con `--dart-define`.
  Quien tenga el APK puede extraerla; para producción hace falta un servidor intermedio.
- Con la opción A, el relato **sí sale del teléfono** hacia Google. Díganlo con honestidad en el pitch;
  la opción B (o un modelo dentro del teléfono) es la versión privada.
- `assets/conocimiento/contactos.md` aún tiene datos **PENDIENTE VERIFICAR** (Fiscalía, policía
  cibernética). Llénenlos solo con fuentes oficiales.

## Estructura
| Archivo | Qué hace |
|---|---|
| `lib/screens/inicio.dart` | Pantalla de inicio: situaciones, evidencias, barra de emergencia. |
| `lib/screens/chat.dart` | Chat con el modelo. |
| `lib/screens/evidencias.dart` | Capturas con huella SHA-256. |
| `lib/screens/denuncia.dart` | Borrador de denuncia para compartir o copiar. |
| `lib/services/gemma.dart` | Conexión con Google AI Studio u Ollama. |
| `lib/widgets/pressable.dart` | Botones con estados hover, presionado y foco. |
| `lib/widgets/greca.dart` | Greca bordada animada del encabezado. |
| `lib/theme.dart` | Paleta (añil, grana cochinilla, cantera) y tipografía. |

## Diseño
Colores de los tintes naturales de Oaxaca: **añil** (identidad), **grana cochinilla** (emergencia),
**cantera verde** (evidencia verificada). Títulos en Noto Serif Display. El encabezado tiene una
greca escalonada que se "borda" con puntada corrida al abrir la app; las opciones entran justo
después. Las animaciones se desactivan si el teléfono tiene activado "reducir movimiento".

## Autoría
La idea, el diseño del proyecto y su desarrollo son de **Esteban Santiago** y su equipo del Hack Day.
Claude (IA de Anthropic) ayudó a generar el código base de la app y a redactar esta documentación.
