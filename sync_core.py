"""Sincronización de la configuración de Arco entre equipos (sin dependencias de Qt).

Dos destinos posibles para el archivo ``arco-config.json``:

* **Google Drive**, en la carpeta oculta de la aplicación (``appDataFolder``). Solo pide el
  permiso ``drive.appdata``: Arco no puede ver ni tocar ningún otro archivo de tu Drive.
* **Una carpeta sincronizada** (Google Drive para escritorio, OneDrive, Dropbox, Syncthing…).

Formato del archivo::

    {"app": "arco", "format": 1, "updatedAt": <ms>, "device": "<id>", "deviceName": "...",
     "data": {"clocks": [{...ajustes del reloj 1...}, {...reloj 2...}]}}

Las posiciones de los relojes no se guardan: dependen de los monitores de cada equipo.
"""
from __future__ import annotations

import base64
import hashlib
import json
import os
import secrets
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Callable

FILE_NAME = "arco-config.json"
FORMAT = 1

SCOPES = "openid email https://www.googleapis.com/auth/drive.appdata"
AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_URL = "https://oauth2.googleapis.com/token"
REVOKE_URL = "https://oauth2.googleapis.com/revoke"
FILES_URL = "https://www.googleapis.com/drive/v3/files"
UPLOAD_URL = "https://www.googleapis.com/upload/drive/v3/files"


class SyncError(Exception):
    """Error que se muestra al usuario, en español y en inglés."""

    def __init__(self, es: str, en: str = ""):
        super().__init__(es)
        self.es = es
        self.en = en or es

    def text(self, lang: str) -> str:
        return self.en if lang == "en" else self.es


class AuthExpired(SyncError):
    """La sesión de Google ya no es válida: hay que volver a iniciar sesión."""


# ---------------------------------------------------------------- datos

def normalize(data: dict) -> str:
    """JSON canónico de los ajustes (claves ordenadas) para comparar versiones."""
    return json.dumps(data, sort_keys=True, ensure_ascii=False, separators=(",", ":"))


def digest(data: dict) -> str:
    return hashlib.sha256(normalize(data).encode("utf-8")).hexdigest()


def effective(local: dict, remote: dict | None, sync_count: bool) -> dict:
    """Lo que este equipo debe subir.

    Si no se sincroniza el número de relojes y la nube tiene más relojes que este equipo,
    se conservan los relojes que sobran (para no borrar los del otro equipo).
    """
    clocks = list(local.get("clocks", []))
    if not sync_count and remote:
        extra = remote.get("data", {}).get("clocks", [])
        if len(extra) > len(clocks):
            clocks += extra[len(clocks):]
    return {"clocks": clocks}


def make_doc(data: dict, stamp: float, device: str, device_name: str) -> dict:
    return {"app": "arco", "format": FORMAT, "updatedAt": int(stamp), "device": device,
            "deviceName": device_name, "data": data}


def valid_doc(doc) -> bool:
    return (isinstance(doc, dict) and doc.get("app") == "arco"
            and isinstance(doc.get("data"), dict) and isinstance(doc["data"].get("clocks"), list))


def decide(local: dict | None, local_stamp: float, remote: dict | None, sync_count: bool) -> str:
    """Qué hacer en un ciclo de sincronización.

    Devuelve ``"push"`` (subir lo de este equipo), ``"pull"`` (aplicar lo de la nube)
    o ``"same"`` (no hay nada que hacer). Gana la versión modificada más recientemente;
    un equipo que nunca ha sincronizado tiene ``local_stamp = 0`` y recibe lo de la nube.
    """
    if remote is None or not valid_doc(remote):
        return "push" if local is not None else "same"
    if local is None:
        return "pull"
    if digest(effective(local, remote, sync_count)) == digest(remote["data"]):
        return "same"
    return "pull" if remote.get("updatedAt", 0) > local_stamp else "push"


# ---------------------------------------------------------------- HTTP

def http(method: str, url: str, data: bytes | None = None, headers: dict | None = None,
         timeout: float = 20) -> tuple[int, bytes]:
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()
    except (urllib.error.URLError, OSError) as e:
        raise SyncError("Sin conexión con Google; se reintentará.", "No connection to Google; will retry.") from e


def _form(d: dict) -> bytes:
    return urllib.parse.urlencode(d).encode("ascii")


FORM = {"Content-Type": "application/x-www-form-urlencoded"}


# ---------------------------------------------------------------- destinos

class FolderBackend:
    """Guarda el archivo en una carpeta que otro programa mantiene sincronizada."""

    def __init__(self, folder: str):
        self.path = Path(folder) / FILE_NAME

    def describe(self) -> str:
        return "la carpeta"

    def read(self) -> dict | None:
        if not self.path.parent.is_dir():
            raise SyncError("No se encuentra la carpeta de sincronización.", "The sync folder was not found.")
        try:
            return json.loads(self.path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            return None
        except (OSError, ValueError) as e:
            raise SyncError(f"No se pudo leer {FILE_NAME}: {e}", f"Could not read {FILE_NAME}: {e}") from e

    def write(self, doc: dict) -> None:
        tmp = self.path.with_name(FILE_NAME + ".tmp")
        try:
            tmp.write_text(json.dumps(doc, ensure_ascii=False, indent=1), encoding="utf-8")
            os.replace(tmp, self.path)
        except OSError as e:
            raise SyncError(f"No se pudo escribir en la carpeta: {e}", f"Could not write to the folder: {e}") from e


class GoogleDriveBackend:
    """Archivo en la carpeta oculta de la aplicación en Google Drive (permiso drive.appdata)."""

    def __init__(self, client_id: str, client_secret: str, refresh_token: str,
                 transport: Callable = http):
        self.client_id = client_id
        self.client_secret = client_secret
        self.refresh_token = refresh_token
        self.http = transport
        self._access = ""
        self._expiry = 0.0
        self._file_id = ""

    def _token(self) -> str:
        if self._access and time.time() < self._expiry - 60:
            return self._access
        status, body = self.http("POST", TOKEN_URL, _form({
            "client_id": self.client_id, "client_secret": self.client_secret,
            "refresh_token": self.refresh_token, "grant_type": "refresh_token"}), FORM)
        if status in (400, 401):
            raise AuthExpired("La sesión de Google caducó o se revocó. Vuelve a iniciar sesión.",
                              "Your Google session expired or was revoked. Sign in again.")
        if status != 200:
            raise SyncError(f"Google rechazó la renovación de la sesión ({status}).", f"Google refused to renew the session ({status}).")
        j = json.loads(body)
        self._access = j["access_token"]
        self._expiry = time.time() + float(j.get("expires_in", 3600))
        return self._access

    def _api(self, method: str, url: str, data: bytes | None = None, ctype: str = "") -> tuple[int, bytes]:
        for attempt in (0, 1):
            headers = {"Authorization": "Bearer " + self._token()}
            if ctype:
                headers["Content-Type"] = ctype
            status, body = self.http(method, url, data, headers)
            if status == 401 and attempt == 0:
                self._access = ""          # token caducado antes de tiempo: renovar y repetir
                continue
            return status, body
        return status, body

    @staticmethod
    def _check(status: int, body: bytes, what: tuple) -> None:
        if 200 <= status < 300:
            return
        if status == 403 and b"accessNotConfigured" in body:
            raise SyncError("La API de Google Drive no está activada en el proyecto de Google Cloud.",
                            "The Google Drive API is not enabled in the Google Cloud project.")
        raise SyncError(f"Google Drive respondió {status} al {what[0]}.", f"Google Drive returned {status} while trying to {what[1]}.")

    def _find(self) -> str:
        if self._file_id:
            return self._file_id
        q = urllib.parse.urlencode({
            "spaces": "appDataFolder",
            "q": f"name = '{FILE_NAME}' and trashed = false",
            "fields": "files(id,modifiedTime)",
            "orderBy": "modifiedTime desc",
            "pageSize": "10"})
        status, body = self._api("GET", f"{FILES_URL}?{q}")
        self._check(status, body, ("buscar la configuración", "find the settings"))
        files = json.loads(body).get("files", [])
        self._file_id = files[0]["id"] if files else ""
        return self._file_id

    def describe(self) -> str:
        return "Google Drive"

    def read(self) -> dict | None:
        fid = self._find()
        if not fid:
            return None
        status, body = self._api("GET", f"{FILES_URL}/{fid}?alt=media")
        if status == 404:
            self._file_id = ""
            return None
        self._check(status, body, ("descargar la configuración", "download the settings"))
        try:
            return json.loads(body.decode("utf-8"))
        except ValueError:
            return None

    def write(self, doc: dict) -> None:
        data = json.dumps(doc, ensure_ascii=False, indent=1).encode("utf-8")
        fid = self._find()
        if fid:
            status, body = self._api("PATCH", f"{UPLOAD_URL}/{fid}?uploadType=media", data, "application/json")
            if status != 404:
                self._check(status, body, ("subir la configuración", "upload the settings"))
                return
            self._file_id = ""
        b = "arco" + secrets.token_hex(12)
        meta = json.dumps({"name": FILE_NAME, "parents": ["appDataFolder"]})
        payload = (f"--{b}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n{meta}\r\n"
                   f"--{b}\r\nContent-Type: application/json\r\n\r\n").encode("utf-8") + data + f"\r\n--{b}--\r\n".encode()
        status, body = self._api("POST", f"{UPLOAD_URL}?uploadType=multipart&fields=id", payload,
                                 f"multipart/related; boundary={b}")
        self._check(status, body, ("crear la configuración", "create the settings"))
        self._file_id = json.loads(body)["id"]


# ---------------------------------------------------------------- inicio de sesión

def load_client(*folders: Path) -> tuple[str, str]:
    """Credenciales OAuth de la app («ID de cliente» de tipo Escritorio).

    Se leen de las variables ARCO_GOOGLE_CLIENT_ID / ARCO_GOOGLE_CLIENT_SECRET o de
    ``google_oauth.json`` (el archivo que descarga Google Cloud, o {"client_id", "client_secret"}).
    En las apps de escritorio el «secreto» no es confidencial: Google lo trata como público.
    """
    cid = os.environ.get("ARCO_GOOGLE_CLIENT_ID", "")
    sec = os.environ.get("ARCO_GOOGLE_CLIENT_SECRET", "")
    if cid:
        return cid, sec
    for folder in folders:
        p = Path(folder) / "google_oauth.json"
        try:
            j = json.loads(p.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        j = j.get("installed", j)
        if j.get("client_id"):
            return j["client_id"], j.get("client_secret", "")
    return "", ""


def _email_from_id_token(id_token: str) -> str:
    try:
        part = id_token.split(".")[1]
        part += "=" * (-len(part) % 4)
        return json.loads(base64.urlsafe_b64decode(part)).get("email", "")
    except (IndexError, ValueError):
        return ""


_DONE_PAGE = """<!doctype html><meta charset="utf-8"><title>Arco</title>
<body style="font-family:system-ui,sans-serif;background:#15161b;color:#e8e8ee;display:grid;place-items:center;height:90vh">
<div style="text-align:center"><h2>{title}</h2><p>{text}</p></div></body>"""


def google_login(client_id: str, client_secret: str, open_url: Callable[[str], object],
                 cancelled: Callable[[], bool] = lambda: False, timeout: float = 300,
                 transport: Callable = http, lang: str = "es") -> tuple[str, str]:
    """Inicio de sesión de app de escritorio (OAuth 2.0 con PKCE y redirección a 127.0.0.1).

    Abre el navegador, espera la respuesta en un puerto local y devuelve (refresh_token, email).
    """
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(16)
    result: dict = {}

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if "state" not in qs:
                self.send_response(404)
                self.end_headers()
                return
            if qs["state"][0] != state:
                result["error"] = "state"
            elif "code" in qs:
                result["code"] = qs["code"][0]
            else:
                result["error"] = qs.get("error", ["cancelado"])[0]
            ok = "code" in result
            en = lang == "en"
            if ok:
                title, text = ("Done", "You can close this tab and go back to Arco.") if en else \
                              ("Listo", "Ya puedes cerrar esta pestaña y volver a Arco.")
            else:
                title, text = ("Sign-in not completed", "You can close this tab and try again.") if en else \
                              ("No se completó el inicio de sesión", "Puedes cerrar esta pestaña e intentarlo de nuevo.")
            page = _DONE_PAGE.format(title=title, text=text)
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(page.encode("utf-8"))

        def log_message(self, *args):
            pass

    server = HTTPServer(("127.0.0.1", 0), Handler)
    server.timeout = 0.5
    redirect = f"http://127.0.0.1:{server.server_address[1]}"
    try:
        open_url(AUTH_URL + "?" + urllib.parse.urlencode({
            "client_id": client_id, "redirect_uri": redirect, "response_type": "code",
            "scope": SCOPES, "code_challenge": challenge, "code_challenge_method": "S256",
            "state": state, "access_type": "offline", "prompt": "consent"}))
        deadline = time.time() + timeout
        while not result and time.time() < deadline and not cancelled():
            server.handle_request()
    finally:
        server.server_close()

    if "code" not in result:
        detail = f" ({result['error']})." if result.get("error") else "."
        if cancelled() or not result:
            raise SyncError("Inicio de sesión cancelado.", "Sign-in cancelled.")
        raise SyncError("Google no autorizó el acceso" + detail, "Google did not grant access" + detail)

    status, body = transport("POST", TOKEN_URL, _form({
        "code": result["code"], "client_id": client_id, "client_secret": client_secret,
        "redirect_uri": redirect, "grant_type": "authorization_code", "code_verifier": verifier}), FORM)
    if status != 200:
        raise SyncError(f"Google rechazó el inicio de sesión ({status}).", f"Google rejected the sign-in ({status}).")
    j = json.loads(body)
    if not j.get("refresh_token"):
        raise SyncError("Google no devolvió un permiso duradero; vuelve a intentarlo.", "Google did not return a long-lived grant; please try again.")
    return j["refresh_token"], _email_from_id_token(j.get("id_token", ""))


def google_revoke(token: str, transport: Callable = http) -> None:
    try:
        transport("POST", REVOKE_URL, _form({"token": token}), FORM, 10)
    except SyncError:
        pass
