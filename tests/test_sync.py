"""Pruebas del núcleo de sincronización (sin Qt ni red): python tests/test_sync.py"""
import json
import sys
import tempfile
import threading
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import sync_core as core  # noqa: E402

A = {"clocks": [{"style": 0, "cText": "#FFFFFF", "oYear": 1}]}
B = {"clocks": [{"style": 7, "cText": "#FFFFFF", "oYear": 0.5}]}
TWO = {"clocks": [{"style": 7}, {"style": 5}]}


def doc(data, stamp):
    return core.make_doc(data, stamp, "otro", "PC")


# ---------- decisiones ----------
assert core.normalize({"b": 1, "a": 2}) == core.normalize({"a": 2, "b": 1})
assert core.decide(A, 0, None, True) == "push"                 # nube vacía: subir
assert core.decide(A, 0, doc(B, 100), True) == "pull"          # equipo nuevo: recibe la nube
assert core.decide(A, 500, doc(B, 100), True) == "push"        # cambio local más reciente
assert core.decide(A, 50, doc(B, 100), True) == "pull"         # cambio remoto más reciente
assert core.decide(A, 50, doc(A, 100), True) == "same"
assert core.decide(A, 0, {"basura": 1}, True) == "push"        # archivo inválido: se reemplaza
assert core.decide(None, 0, doc(B, 1), True) == "pull"

# número de relojes: sin sincronizarlo, se conservan los relojes extra de la nube
one = {"clocks": [{"style": 7}]}
assert core.effective(one, doc(TWO, 1), False) == TWO
assert core.effective(one, doc(TWO, 1), True) == one
assert core.decide(one, 5, doc(TWO, 1), False) == "same"
assert core.decide(one, 5, doc(TWO, 1), True) == "push"

# ---------- carpeta ----------
with tempfile.TemporaryDirectory() as d:
    f = core.FolderBackend(d)
    assert f.read() is None
    f.write(doc(A, 1))
    assert f.read()["data"] == A
    assert not (Path(d) / (core.FILE_NAME + ".tmp")).exists()
    try:
        core.FolderBackend(str(Path(d) / "no-existe")).read()
        raise AssertionError("debía fallar")
    except core.SyncError:
        pass


# ---------- Google Drive simulado ----------
class FakeGoogle:
    def __init__(self):
        self.files = {}
        self.tokens_issued = 0
        self.revoked = False
        self.expire_next = False
        self.calls = []

    def __call__(self, method, url, data=None, headers=None, timeout=20):
        u = urllib.parse.urlparse(url)
        self.calls.append((method, u.path))
        if url.startswith(core.TOKEN_URL):
            form = urllib.parse.parse_qs(data.decode())
            if form.get("refresh_token") == ["revocado"]:
                return 400, b'{"error":"invalid_grant"}'
            if form["grant_type"] == ["authorization_code"]:
                assert form["code_verifier"][0] and form["code"] == ["CODIGO"]
                idt = "x." + __import__("base64").urlsafe_b64encode(b'{"email":"ana@gmail.com"}').decode().rstrip("=") + ".y"
                return 200, json.dumps({"access_token": "T", "expires_in": 3600, "refresh_token": "R", "id_token": idt}).encode()
            self.tokens_issued += 1
            return 200, json.dumps({"access_token": f"T{self.tokens_issued}", "expires_in": 3600}).encode()
        if url.startswith(core.REVOKE_URL):
            self.revoked = True
            return 200, b""
        assert headers["Authorization"].startswith("Bearer T")
        if self.expire_next:
            self.expire_next = False
            return 401, b"{}"
        if method == "GET" and u.path.endswith("/files"):
            q = urllib.parse.parse_qs(u.query)
            assert q["spaces"] == ["appDataFolder"]
            return 200, json.dumps({"files": [{"id": k} for k in self.files]}).encode()
        if method == "GET":
            fid = u.path.rsplit("/", 1)[1]
            return (200, self.files[fid]) if fid in self.files else (404, b"")
        if method == "PATCH":
            fid = u.path.rsplit("/", 1)[1]
            if fid not in self.files:
                return 404, b""
            self.files[fid] = data
            return 200, b"{}"
        if method == "POST" and "multipart" in headers["Content-Type"]:
            boundary = headers["Content-Type"].split("boundary=")[1]
            parts = data.split(f"--{boundary}".encode())
            meta = json.loads(parts[1].split(b"\r\n\r\n", 1)[1])
            assert meta == {"name": core.FILE_NAME, "parents": ["appDataFolder"]}
            body = parts[2].split(b"\r\n\r\n", 1)[1].rsplit(b"\r\n", 1)[0]
            fid = f"f{len(self.files) + 1}"
            self.files[fid] = body
            return 200, json.dumps({"id": fid}).encode()
        raise AssertionError((method, url))


g = FakeGoogle()
drive = core.GoogleDriveBackend("cid", "sec", "R", transport=g)
assert drive.read() is None
drive.write(doc(A, 1))                       # crea el archivo (multipart)
assert len(g.files) == 1 and drive.read()["data"] == A
drive.write(doc(B, 2))                       # lo actualiza (PATCH)
assert len(g.files) == 1 and drive.read()["data"] == B
assert g.tokens_issued == 1                  # el token se reutiliza
g.expire_next = True
assert drive.read()["data"] == B and g.tokens_issued == 2   # 401: renueva y repite

# otro equipo con la misma cuenta ve el mismo archivo
drive2 = core.GoogleDriveBackend("cid", "sec", "R", transport=g)
assert drive2.read()["data"] == B

# archivo borrado desde otro lado: se vuelve a crear
g.files.clear()
drive.write(doc(A, 3))
assert len(g.files) == 1 and drive.read()["data"] == A

try:
    core.GoogleDriveBackend("cid", "sec", "revocado", transport=g).read()
    raise AssertionError("debía pedir volver a iniciar sesión")
except core.AuthExpired:
    pass

core.google_revoke("R", transport=g)
assert g.revoked


# ---------- inicio de sesión (navegador simulado) ----------
def browser(approve=True, wrong_state=False):
    def open_url(url):
        q = urllib.parse.parse_qs(urllib.parse.urlparse(url).query)
        assert q["code_challenge_method"] == ["S256"] and "drive.appdata" in q["scope"][0]
        assert q["redirect_uri"][0].startswith("http://127.0.0.1:")
        state = "otro" if wrong_state else q["state"][0]
        params = {"state": state, "code": "CODIGO"} if approve else {"state": state, "error": "access_denied"}
        target = q["redirect_uri"][0] + "/?" + urllib.parse.urlencode(params)

        def hit():
            with urllib.request.urlopen(target) as r:
                assert "Arco" in r.read().decode()
        threading.Thread(target=hit, daemon=True).start()
    return open_url


import os  # noqa: E402
os.environ["NO_PROXY"] = "127.0.0.1"
refresh, email = core.google_login("cid", "sec", browser(), timeout=10, transport=g)
assert (refresh, email) == ("R", "ana@gmail.com")
for kw in ({"approve": False}, {"wrong_state": True}):
    try:
        core.google_login("cid", "sec", browser(**kw), timeout=10, transport=g)
        raise AssertionError("debía fallar")
    except core.SyncError as e:
        assert "no autorizó" in str(e)
try:
    core.google_login("cid", "sec", lambda url: None, cancelled=lambda: True, timeout=10, transport=g)
    raise AssertionError("debía cancelarse")
except core.SyncError as e:
    assert "cancelado" in str(e)

# ---------- credenciales ----------
with tempfile.TemporaryDirectory() as d:
    assert core.load_client(Path(d)) == ("", "")
    (Path(d) / "google_oauth.json").write_text(json.dumps({"installed": {"client_id": "X", "client_secret": "Y"}}))
    assert core.load_client(Path(d)) == ("X", "Y")

print("OK – sincronización")
