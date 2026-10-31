from __future__ import annotations

import hashlib
import json
import os
import re
import textwrap
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Annotated

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse

ROOT = Path(__file__).resolve().parents[1]
DOCUMENTS = ROOT / "documents"
EVIDENCE_DIR = ROOT / "data" / "evidence"
REPORTS_DIR = ROOT / "data" / "reports"
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://127.0.0.1:11434/api/chat")
MODEL_NAME = os.getenv("MODEL_NAME", "gemma4")

app = FastAPI(title="Resguarda", docs_url=None, redoc_url=None)

# La app Flutter web corre en otro puerto (flutter run -d chrome); solo se aceptan orígenes locales.
# Otros orígenes se pueden agregar con CORS_ORIGIN_REGEX (por ejemplo, la IP de la laptop).
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=os.getenv("CORS_ORIGIN_REGEX", r"http://(localhost|127\.0\.0\.1)(:\d+)?"),
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)


def load_sources() -> list[dict[str, str]]:
    return [
        {"name": path.name, "text": path.read_text(encoding="utf-8")}
        for path in DOCUMENTS.glob("*.md")
    ]


def retrieve(query: str, limit: int = 3) -> list[dict[str, str]]:
    terms = set(re.findall(r"[a-záéíóúñü]{4,}", query.lower()))
    ranked: list[tuple[int, dict[str, str]]] = []
    for source in load_sources():
        chunks = [part.strip() for part in source["text"].split("\n\n") if part.strip()]
        for chunk in chunks:
            score = sum(term in chunk.lower() for term in terms)
            if score:
                ranked.append((score, {"name": source["name"], "text": chunk}))
    return [chunk for _, chunk in sorted(ranked, key=lambda item: item[0], reverse=True)[:limit]]


def ollama_answer(message: str, sources: list[dict[str, str]]) -> str:
    context = "\n\n".join(f"[{item['name']}]\n{item['text']}" for item in sources)
    system = """Eres Resguarda, una asistente privada que funciona localmente. Responde en español mexicano, con empatía y brevedad. Usa SOLO las fuentes locales proporcionadas. No determines delitos ni des asesoría legal. Si la fuente no basta, dilo claramente. NUNCA solicites, sugieras recopilar ni repitas nombres, fechas de nacimiento, contraseñas, ubicación, historial de navegación, teléfonos u otros datos personales. No inventes evidencia que no exista en las fuentes. Da únicamente acciones de protección y conservación de evidencia. Escribe texto plano, sin Markdown, con tres secciones: Orientación inmediata, Evidencia a conservar y Siguiente paso. Si hay riesgo inmediato, recomienda contactar servicios de emergencia locales o una red de apoyo."""
    payload = json.dumps({
        "model": MODEL_NAME,
        "stream": False,
        "options": {"temperature": 0},
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": f"Fuentes locales:\n{context}\n\nSituación: {message}"},
        ],
    }).encode()
    request = urllib.request.Request(OLLAMA_URL, data=payload, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=90) as response:
            answer = json.loads(response.read())["message"]["content"].strip()
            unsafe_patterns = (
                "fecha de nacimiento",
                "historial de navegación",
                "contraseña",
                "número telefónico",
                "información de la persona",
                "información sobre la persona",
                "para la investigación",
            )
            if not answer or any(pattern in answer.lower() for pattern in unsafe_patterns):
                return grounded_fallback(sources)
            return answer
    except (urllib.error.URLError, TimeoutError, KeyError, json.JSONDecodeError) as error:
        raise HTTPException(503, f"No se pudo conectar al modelo local ({MODEL_NAME}). Verifica Ollama y el modelo. Detalle: {error}")


def grounded_fallback(sources: list[dict[str, str]]) -> str:
    """Safe, source-derived fallback when a small model suggests unsafe collection."""
    guidance = next((item["text"] for item in sources if "Conservación de evidencia" in item["text"]), sources[0]["text"])
    return (
        "Orientación inmediata:\n"
        "Guarda primero la información relevante y evita responder si eso puede aumentar el riesgo.\n\n"
        "Evidencia a conservar:\n"
        f"{guidance}\n\n"
        "Siguiente paso:\n"
        "Revisa las fuentes mostradas y busca acompañamiento especializado. Esta orientación no sustituye atención de emergencia ni asesoría legal."
    )


def evidence_manifest() -> list[dict[str, str]]:
    manifest = EVIDENCE_DIR / "manifest.json"
    return json.loads(manifest.read_text()) if manifest.exists() else []


def write_manifest(items: list[dict[str, str]]) -> None:
    (EVIDENCE_DIR / "manifest.json").write_text(json.dumps(items, ensure_ascii=False, indent=2), encoding="utf-8")


def escape_pdf(text: str) -> str:
    return text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)").encode("latin-1", "replace").decode("latin-1")


def create_pdf(summary: str) -> Path:
    lines = ["RESGUARDA — EXPEDIENTE ORIENTATIVO", "", "Este documento no es una denuncia ni asesoría legal.", "", "Relato:"]
    lines.extend(textwrap.wrap(summary, width=88) or ["Sin relato registrado."])
    lines.extend(["", "Evidencias registradas:"])
    for item in evidence_manifest():
        lines.extend(textwrap.wrap(f"- {item['filename']} | {item['created_at']} | SHA-256: {item['sha256']}", width=88))
    content = "BT /F1 10 Tf 50 790 Td 13 TL " + " ".join(f"({escape_pdf(line)}) Tj T*" for line in lines[:52]) + " ET"
    objects = [
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
        "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        f"<< /Length {len(content.encode('latin-1'))} >>\nstream\n{content}\nendstream",
    ]
    pdf = "%PDF-1.4\n"
    offsets = [0]
    for index, obj in enumerate(objects, 1):
        offsets.append(len(pdf.encode("latin-1")))
        pdf += f"{index} 0 obj\n{obj}\nendobj\n"
    startxref = len(pdf.encode("latin-1"))
    pdf += f"xref\n0 {len(objects) + 1}\n0000000000 65535 f \n" + "".join(f"{offset:010d} 00000 n \n" for offset in offsets[1:])
    pdf += f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{startxref}\n%%EOF"
    report = REPORTS_DIR / "expediente-resguarda.pdf"
    report.write_bytes(pdf.encode("latin-1"))
    return report


@app.get("/", response_class=HTMLResponse)
def home() -> str:
    return (ROOT / "app" / "index.html").read_text(encoding="utf-8")


@app.post("/api/chat")
def chat(body: dict[str, str]) -> dict[str, object]:
    message = body.get("message", "").strip()
    if not message:
        raise HTTPException(400, "Escribe una situación para continuar.")
    sources = retrieve(message)
    if not sources:
        return {"answer": "No encontré una fuente local suficiente para orientar esta situación. Evita compartir datos personales aquí y busca acompañamiento especializado.", "sources": []}
    return {"answer": ollama_answer(message, sources), "sources": [item["name"] for item in sources]}


@app.post("/api/evidence")
async def add_evidence(file: Annotated[UploadFile, File()]) -> dict[str, str]:
    if not file.filename:
        raise HTTPException(400, "Selecciona un archivo.")
    data = await file.read()
    if len(data) > 12 * 1024 * 1024:
        raise HTTPException(413, "El archivo excede 12 MB.")
    safe_name = re.sub(r"[^A-Za-z0-9._-]", "_", Path(file.filename).name)
    saved = EVIDENCE_DIR / f"{datetime.now().strftime('%Y%m%d-%H%M%S')}_{safe_name}"
    saved.write_bytes(data)
    item = {"filename": saved.name, "sha256": hashlib.sha256(data).hexdigest(), "created_at": datetime.now(timezone.utc).isoformat()}
    manifest = evidence_manifest()
    manifest.append(item)
    write_manifest(manifest)
    return item


@app.post("/api/report")
def report(body: dict[str, str]) -> FileResponse:
    return FileResponse(create_pdf(body.get("summary", "")).resolve(), media_type="application/pdf", filename="expediente-resguarda.pdf")


@app.post("/api/delete-all")
def delete_all() -> dict[str, bool]:
    for path in EVIDENCE_DIR.iterdir():
        if path.is_file() and path.name != ".gitkeep":
            path.unlink()
    for path in REPORTS_DIR.iterdir():
        if path.is_file() and path.name != ".gitkeep":
            path.unlink()
    return {"deleted": True}
