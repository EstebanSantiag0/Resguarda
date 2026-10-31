# CLAUDE.md — Resguarda (Flutter)

Mobile version of Resguarda (Hack Day Oaxaca, 2026-10-31). Python/Gradio prototype lives in
`~/resguarda`. See `docs/architecture.md`.

## Rules
- Address the user as **Esteban**. App text and docs in Spanish.
- Never commit API keys; the Gemma key comes only from `--dart-define=GEMMA_API_KEY`.
- `assets/conocimiento/` holds only verified text; mark unknowns `PENDIENTE VERIFICAR`.
- Internet is slow at the venue: add packages with `flutter pub add --offline` (only cached ones).
- Keep hover/pressed/focus states (`Pressable`) and respect `MediaQuery.disableAnimations`
  via `movimiento()` in `lib/theme.dart`.
- README ends with the Autoría section.

## Commands
- `flutter analyze`, `flutter test`
- `flutter run --dart-define=GEMMA_API_KEY=... [--dart-define=GEMMA_MODEL=...]`
- Local model: `--dart-define=OLLAMA_URL=http://IP:11434 --dart-define=OLLAMA_MODEL=...`
