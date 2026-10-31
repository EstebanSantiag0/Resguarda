from __future__ import annotations

import hashlib
import json
import os
import re
import secrets
import textwrap
import urllib.error
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Annotated

from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse
from starlette.middleware.trustedhost import TrustedHostMiddleware

ROOT = Path(__file__).resolve().parents[1]
DOCUMENTS = ROOT / "documents"
EVIDENCE_DIR = ROOT / "data" / "evidence"
REPORTS_DIR = ROOT / "data" / "reports"
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://127.0.0.1:11434/api/chat")
MODEL_NAME = os.getenv("MODEL_NAME", "gemma3:1b")

app = FastAPI(title="Resguarda", docs_url=None, redoc_url=None)

# Solo se aceptan peticiones dirigidas a estos nombres (bloquea DNS rebinding). Para usarla desde
# el celular agrega la IP de la laptop: ALLOWED_HOSTS=localhost,127.0.0.1,192.168.x.x
app.add_middleware(TrustedHostMiddleware, allowed_hosts=os.getenv("ALLOWED_HOSTS", "localhost,127.0.0.1").split(","))


@app.middleware("http")
async def require_app_header(request: Request, call_next):
    # Un formulario o fetch "simple" de otra página no puede mandar este encabezado sin pasar por
    # CORS, así que ninguna página ajena puede borrar ni subir evidencias (CSRF).
    if request.method == "POST" and request.url.path.startswith("/api/") and request.headers.get("x-resguarda") != "1":
        return JSONResponse({"detail": "Solicitud rechazada."}, status_code=403)
    return await call_next(request)


# Evidencias y expedientes solo desde la laptop misma: aunque el backend escuche en la red
# (--host 0.0.0.0 para el celular), nadie más en el Wi-Fi puede subir, ni descargar archivos.
# La app Flutter no los necesita: arma el expediente en el teléfono.
LOOPBACK_ONLY = {"/api/evidence", "/api/export", "/api/report"}


@app.middleware("http")
async def loopback_only(request: Request, call_next):
    client = request.client.host if request.client else ""
    if request.url.path in LOOPBACK_ONLY and client not in {"127.0.0.1", "::1"}:
        return JSONResponse({"detail": "Disponible solo en este equipo."}, status_code=403)
    return await call_next(request)


# La app Flutter web corre en otro puerto (flutter run -d chrome); solo se aceptan orígenes locales.
# Otros orígenes se pueden agregar con CORS_ORIGIN_REGEX (por ejemplo, la IP de la laptop).
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=os.getenv("CORS_ORIGIN_REGEX", r"http://(localhost|127\.0\.0\.1)(:\d+)?"),
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "X-Resguarda"],
)

SOURCES = {
    "evidence": {
        "title": "Guía local para conservar evidencia",
        "publisher": "Resguarda · fuentes oficiales revisadas",
        "url": "https://www.diputados.gob.mx/LeyesBiblio/pdf/LGAMVLV.pdf",
    },
    "support": {
        "title": "Atención a mujeres en situación de violencia",
        "publisher": "Secretaría de las Mujeres de Oaxaca",
        "url": "https://www.oaxaca.gob.mx/sm/",
    },
    "emergency": {
        "title": "Emergencias 911",
        "publisher": "Gobierno de México",
        "url": "https://www.gob.mx/911",
    },
    "justice": {
        "title": "Centros de Justicia para las Mujeres",
        "publisher": "CONAVIM",
        "url": "https://www.gob.mx/conavim/acciones-y-programas/centros-de-justicia-para-las-mujeres",
    },
    "legal": {
        "title": "Marco legal de consulta",
        "publisher": "Cámara de Diputados",
        "url": "https://www.diputados.gob.mx/LeyesBiblio/pdf/CPF.pdf",
    },
}

INCIDENTS = {
    "threats": {
        "label": "Amenazas o acoso",
        "steps": ["Conserva capturas completas de los mensajes.", "Guarda el perfil, URL o identificador de quien envió el mensaje.", "Registra fecha y hora de recepción antes de bloquear o reportar."],
        "sources": ["evidence", "support"],
    },
    "intimate_content": {
        "label": "Difusión de contenido íntimo",
        "steps": ["Conserva la publicación, perfil y URL sin redistribuir el contenido.", "Guarda capturas donde se vean fecha, cuenta y plataforma.", "Conserva archivos originales y evita editarlos."],
        "sources": ["evidence", "legal", "support"],
    },
    "sextortion": {
        "label": "Sextorsión",
        "steps": ["Conserva mensajes, cuentas, enlaces y solicitudes recibidas.", "No compartas códigos de verificación ni más contenido íntimo.", "Evita negociar bajo presión; busca acompañamiento especializado."],
        "sources": ["evidence", "support"],
    },
    "impersonation": {
        "label": "Suplantación de identidad",
        "steps": ["Guarda el enlace o identificador del perfil que suplanta.", "Captura publicaciones, mensajes y fecha de consulta.", "Conserva el perfil original para comparar la información pública."],
        "sources": ["evidence", "support"],
    },
    "account": {
        "label": "Cuenta comprometida",
        "steps": ["Cambia la contraseña desde un dispositivo confiable.", "Activa autenticación de dos factores y revisa sesiones abiertas.", "Guarda correos o avisos de inicio de sesión antes de eliminarlos."],
        "sources": ["evidence"],
    },
}


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
                "aquí tienes",
                "**",
            )
            if not answer or any(pattern in answer.lower() for pattern in unsafe_patterns):
                return grounded_fallback(sources)
            return answer
    except (urllib.error.URLError, TimeoutError, KeyError, json.JSONDecodeError) as error:
        raise HTTPException(503, f"No se pudo conectar al modelo local ({MODEL_NAME}). Verifica Ollama y el modelo. Detalle: {error}")


def gemma_extract(incident: str, notes: str) -> dict[str, object] | None:
    """Use Gemma locally to extract a bounded, non-authoritative incident map."""
    if not notes:
        return None
    schema = {
        "type": "object",
        "properties": {
            "summary": {"type": "string", "maxLength": 180},
            "platform": {"type": "string", "maxLength": 40},
            "needs_account_protection": {"type": "boolean"},
        },
        "required": ["summary", "platform", "needs_account_protection"],
    }
    prompt = (
        "Extrae un mapa breve y neutral de un incidente de violencia digital. "
        "No des consejo legal, no solicites datos, no inventes hechos. "
        "No copies nombres, usuarios, teléfonos, ubicaciones, fechas exactas ni contenido íntimo. "
        f"Categoría seleccionada: {INCIDENTS[incident]['label']}. Relato: {notes[:500]}"
    )
    payload = json.dumps({
        "model": MODEL_NAME,
        "stream": False,
        "format": schema,
        "options": {"temperature": 0},
        "messages": [{"role": "user", "content": prompt}],
    }).encode()
    request = urllib.request.Request(OLLAMA_URL, data=payload, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            result = json.loads(json.loads(response.read())["message"]["content"])
    except (urllib.error.URLError, TimeoutError, KeyError, TypeError, json.JSONDecodeError):
        return None
    summary = str(result.get("summary", "")).strip()
    platform = str(result.get("platform", "No especificada")).strip()
    forbidden = ("contraseña", "fecha de nacimiento", "ubicación", "teléfono", "nombre completo", "@")
    if not 10 <= len(summary) <= 220 or any(word in summary.lower() for word in forbidden):
        return None
    return {
        "summary": summary,
        "platform": platform[:40],
        "needs_account_protection": bool(result.get("needs_account_protection")),
    }


def build_plan(incident: str, immediate_risk: bool, evidence_available: bool, account_compromised: bool, notes: str) -> dict[str, object]:
    definition = INCIDENTS[incident]
    steps = list(definition["steps"])
    if not evidence_available:
        steps.insert(0, "Registra la fecha, hora, plataforma y cuenta involucrada; no intentes obtener evidencia si te pone en riesgo.")
    if account_compromised and incident != "account":
        steps.append("Protege la cuenta: cambia contraseña desde un dispositivo confiable y revisa sesiones abiertas.")
    extraction = gemma_extract(incident, notes)
    needs_account_protection = account_compromised or bool(extraction and extraction["needs_account_protection"])
    if needs_account_protection and incident != "account" and not any("Protege la cuenta" in step for step in steps):
        steps.append("Protege la cuenta: cambia contraseña desde un dispositivo confiable y revisa sesiones abiertas.")
    handoff = extraction["summary"] if extraction else (
        f"La persona solicita orientación inicial sobre {definition['label'].lower()}. "
        "Resguarda recomienda conservar evidencia y buscar acompañamiento cuando se sienta lista."
    )
    support_routes = []
    if immediate_risk:
        support_routes.append({
            "title": "Si hay peligro inmediato, llama al 911",
            "detail": "No necesitas terminar este expediente antes de pedir ayuda.",
            "url": SOURCES["emergency"]["url"],
        })
    support_routes.extend([
        {
            "title": "Pide orientación y acompañamiento en Oaxaca",
            "detail": "Secretaría de las Mujeres de Oaxaca · 951 454 0508. Confirma horario y ruta antes de acudir.",
            "url": SOURCES["support"]["url"],
        },
        {
            "title": "Si decides buscar acceso a la justicia",
            "detail": "Consulta los Centros de Justicia para las Mujeres y confirma la ruta local vigente antes de acudir.",
            "url": SOURCES["justice"]["url"],
        },
    ])
    return {
        "incident_label": definition["label"],
        "priority": "Atención inmediata" if immediate_risk else "Preservar antes de responder",
        "immediate_action": "Si hay peligro físico inmediato, llama al 911 o busca una red de apoyo cercana." if immediate_risk else "Conserva primero la información relevante. Evita responder si hacerlo puede aumentar el riesgo.",
        "steps": steps,
        "sources": [SOURCES[source] for source in definition["sources"]],
        "handoff": handoff,
        "incident_map": extraction or {"platform": "No especificada", "needs_account_protection": account_compromised},
        "model_status": "Gemma local organizó el relato y Resguarda validó la salida" if extraction else "Plan seguro generado con reglas locales; Gemma no añadió datos",
        "support_routes": support_routes,
    }


def grounded_fallback(sources: list[dict[str, str]]) -> str:
    """Safe, source-derived fallback when a small model suggests unsafe collection."""
    guidance = next((item["text"] for item in sources if "Conservación de evidencia" in item["text"]), sources[0]["text"])
    guidance = re.sub(r"^#+\s+.*\n", "", guidance).strip()
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
    return text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)").encode("cp1252", "replace").decode("cp1252")


def create_pdf(summary: str, plan: dict[str, object] | None = None) -> Path:
    lines = ["RESGUARDA — EXPEDIENTE ORIENTATIVO", "", "Este documento no es una denuncia ni asesoría legal.", "", "Relato:"]
    lines.extend(textwrap.wrap(summary, width=82) or ["Sin relato registrado."])
    if plan:
        lines.extend(["", "Resumen para pedir ayuda:"])
        lines.extend(textwrap.wrap(str(plan.get("handoff", "Sin resumen generado.")), width=82))
        lines.extend(["", "Plan de resguardo:"])
        for step in plan.get("steps", []):
            lines.extend(textwrap.wrap(f"- {step}", width=82))
        lines.extend(["", "Rutas de apoyo:"])
        for route in plan.get("support_routes", []):
            lines.extend(textwrap.wrap(f"- {route.get('title', '')}: {route.get('detail', '')}", width=82))
    lines.extend(["", "Evidencias registradas:"])
    for item in evidence_manifest():
        evidence_line = f"- {item['filename']} | Tipo: {item.get('evidence_type', 'No especificado')} | {item['created_at']} | SHA-256: {item['sha256']}"
        lines.extend(textwrap.wrap(evidence_line, width=82, break_long_words=True, break_on_hyphens=True))
        if item.get("note"):
            lines.extend(textwrap.wrap(f"  Nota: {item['note']}", width=82))

    # Keep a readable top margin and create as many pages as needed.
    page_lines = [lines[index:index + 45] for index in range(0, len(lines), 45)] or [["Sin contenido."]]
    page_count = len(page_lines)
    font_object = 3 + page_count
    content_start = font_object + 1
    page_refs = " ".join(f"{3 + index} 0 R" for index in range(page_count))
    objects = [
        "<< /Type /Catalog /Pages 2 0 R >>",
        f"<< /Type /Pages /Kids [{page_refs}] /Count {page_count} >>",
    ]
    for index in range(page_count):
        content_object = content_start + index
        objects.append(
            f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
            f"/Resources << /Font << /F1 {font_object} 0 R >> >> /Contents {content_object} 0 R >>"
        )
    objects.append("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>")
    for chunk in page_lines:
        content = "BT /F1 11 Tf 50 760 Td 15 TL " + " ".join(f"({escape_pdf(line)}) Tj T*" for line in chunk) + " ET"
        objects.append(f"<< /Length {len(content.encode('cp1252'))} >>\nstream\n{content}\nendstream")
    pdf = "%PDF-1.4\n"
    offsets = [0]
    for index, obj in enumerate(objects, 1):
        offsets.append(len(pdf.encode("cp1252")))
        pdf += f"{index} 0 obj\n{obj}\nendobj\n"
    startxref = len(pdf.encode("cp1252"))
    pdf += f"xref\n0 {len(objects) + 1}\n0000000000 65535 f \n" + "".join(f"{offset:010d} 00000 n \n" for offset in offsets[1:])
    pdf += f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{startxref}\n%%EOF"
    report = REPORTS_DIR / "expediente-resguarda.pdf"
    report.write_bytes(pdf.encode("cp1252"))
    return report


def create_bundle(summary: str, plan: dict[str, object]) -> Path:
    report = create_pdf(summary, plan)
    manifest = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "notice": "Expediente orientativo. No es una denuncia, dictamen legal ni cadena de custodia formal.",
        "plan": plan,
        "evidence": evidence_manifest(),
    }
    bundle = REPORTS_DIR / "expediente-resguarda.zip"
    with zipfile.ZipFile(bundle, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.write(report, report.name)
        archive.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2))
        archive.write(DOCUMENTS / "fuentes.md", "fuentes.md")
        for item in evidence_manifest():
            evidence = EVIDENCE_DIR / item["filename"]
            if evidence.is_file():
                archive.write(evidence, f"evidencias/{evidence.name}")
    return bundle


@app.get("/", response_class=HTMLResponse)
def home() -> str:
    return (ROOT / "app" / "index.html").read_text(encoding="utf-8")


@app.get("/logo.png")
def logo() -> FileResponse:
    return FileResponse(ROOT / "app" / "logo.png", media_type="image/png")


@app.post("/api/chat")
def chat(body: dict[str, str]) -> dict[str, object]:
    message = body.get("message", "").strip()
    if not message:
        raise HTTPException(400, "Escribe una situación para continuar.")
    sources = retrieve(message)
    if not sources:
        return {"answer": "No encontré una fuente local suficiente para orientar esta situación. Evita compartir datos personales aquí y busca acompañamiento especializado.", "sources": []}
    return {"answer": ollama_answer(message, sources), "sources": list(dict.fromkeys(item["name"] for item in sources))}


@app.post("/api/plan")
def plan(body: dict[str, object]) -> dict[str, object]:
    incident = str(body.get("incident", ""))
    if incident not in INCIDENTS:
        raise HTTPException(400, "Selecciona el tipo de incidente.")
    notes = str(body.get("notes", "")).strip()
    if len(notes) > 500:
        raise HTTPException(400, "Describe la situación en menos de 500 caracteres.")
    result = build_plan(
        incident,
        bool(body.get("immediate_risk")),
        bool(body.get("evidence_available")),
        bool(body.get("account_compromised")),
        notes,
    )
    return result


@app.post("/api/evidence")
async def add_evidence(
    file: Annotated[UploadFile, File()],
    evidence_type: Annotated[str, Form()] = "Captura",
    note: Annotated[str, Form()] = "",
) -> dict[str, str]:
    if not file.filename:
        raise HTTPException(400, "Selecciona un archivo.")
    data = await file.read()
    if len(data) > 12 * 1024 * 1024:
        raise HTTPException(413, "El archivo excede 12 MB.")
    if len(note) > 250:
        raise HTTPException(400, "La nota no puede exceder 250 caracteres.")
    safe_name = re.sub(r"[^A-Za-z0-9._-]", "_", Path(file.filename).name)
    saved = EVIDENCE_DIR / f"{datetime.now().strftime('%Y%m%d-%H%M%S')}_{secrets.token_hex(3)}_{safe_name}"
    saved.write_bytes(data)
    item = {
        "filename": saved.name,
        "sha256": hashlib.sha256(data).hexdigest(),
        "created_at": datetime.now(timezone.utc).isoformat(),
        "evidence_type": evidence_type[:60] or "No especificado",
        "note": note.strip(),
    }
    manifest = evidence_manifest()
    manifest.append(item)
    write_manifest(manifest)
    return item


@app.post("/api/report")
def report(body: dict[str, str]) -> FileResponse:
    return FileResponse(create_pdf(body.get("summary", "")).resolve(), media_type="application/pdf", filename="expediente-resguarda.pdf")


@app.post("/api/export")
def export_bundle(body: dict[str, object]) -> FileResponse:
    plan_data = body.get("plan", {})
    if not isinstance(plan_data, dict):
        raise HTTPException(400, "El plan de resguardo no es válido.")
    bundle = create_bundle(str(body.get("summary", "")), plan_data)
    return FileResponse(bundle.resolve(), media_type="application/zip", filename="expediente-resguarda.zip")


@app.post("/api/delete-all")
def delete_all() -> dict[str, bool]:
    for path in EVIDENCE_DIR.iterdir():
        if path.is_file() and path.name != ".gitkeep":
            path.unlink()
    for path in REPORTS_DIR.iterdir():
        if path.is_file() and path.name != ".gitkeep":
            path.unlink()
    return {"deleted": True}
