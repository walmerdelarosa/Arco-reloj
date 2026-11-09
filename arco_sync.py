"""Servicio de sincronización expuesto a QML como «sync».

La red y los archivos se tocan en un hilo aparte; todo el estado se modifica en el hilo
principal. QML informa de la configuración local con report() y aplica la remota cuando
llega la señal remoteConfig.
"""
from __future__ import annotations

import json
import socket
import threading
import time
import uuid
import webbrowser
from pathlib import Path

from PySide6.QtCore import Property, QObject, QSettings, QTimer, QUrl, Signal, Slot

import sync_core as core

PULL_EVERY_MS = {"google": 180_000, "folder": 60_000}
PUSH_DELAY_MS = 4_000


class SyncService(QObject):
    stateChanged = Signal()
    remoteConfig = Signal(str, arguments=["json"])   # QML aplica estos ajustes
    requestLocal = Signal()                           # QML responde llamando a report()
    _post = Signal(object)                            # ejecuta una función en el hilo principal

    def __init__(self, client_folders: list[Path], ui=None, enabled: bool = True):
        super().__init__()
        self._ui = ui
        if ui is not None:
            ui.changed.connect(self.stateChanged.emit)     # el estado se muestra en el idioma elegido
        self._post.connect(self._call)
        self._enabled = enabled
        self._client_id, self._client_secret = core.load_client(*client_folders)
        s = QSettings()
        s.beginGroup("sync")
        self._mode = str(s.value("mode", "off"))
        self._folder = str(s.value("folder", ""))
        self._refresh = str(s.value("refreshToken", ""))
        self._account = str(s.value("account", ""))
        self._sync_count = s.value("syncCount", False, type=bool)
        self._device = str(s.value("deviceId", "")) or uuid.uuid4().hex
        self._stamp = float(s.value("localStamp", 0))
        self._synced = str(s.value("syncedHash", ""))
        s.endGroup()
        self._save("deviceId", self._device)

        self._local: dict | None = None
        self._remote: dict | None = None
        self._status = ("Desactivada.", "Off.")
        self._last = ""
        self._busy = False
        self._again = False
        self._logging_in = False
        self._cancel_login = False
        self._backend = None
        self._google = None       # se conserva entre ciclos para reutilizar el token

        self._pull_timer = QTimer(self)
        self._pull_timer.timeout.connect(self.syncNow)
        self._push_timer = QTimer(self)
        self._push_timer.setSingleShot(True)
        self._push_timer.timeout.connect(self.syncNow)
        self._configure()

    @Slot(object)
    def _call(self, fn) -> None:
        fn()

    # ------------------------------------------------------------ propiedades para QML
    def _g_mode(self): return self._mode
    def _lang(self) -> str:
        return self._ui.lang if self._ui is not None else "es"

    def _g_status(self): return self._status[1] if self._lang() == "en" else self._status[0]
    def _g_account(self): return self._account
    def _g_folder(self): return self._folder
    def _g_google(self): return bool(self._client_id)
    def _g_busy(self): return self._busy or self._logging_in
    def _g_login(self): return self._logging_in
    def _g_count(self): return self._sync_count
    def _g_last(self): return self._last
    def _g_ready(self): return self._backend is not None

    mode = Property(str, _g_mode, notify=stateChanged)
    status = Property(str, _g_status, notify=stateChanged)
    account = Property(str, _g_account, notify=stateChanged)
    folder = Property(str, _g_folder, notify=stateChanged)
    googleAvailable = Property(bool, _g_google, notify=stateChanged)
    busy = Property(bool, _g_busy, notify=stateChanged)
    loggingIn = Property(bool, _g_login, notify=stateChanged)
    syncCount = Property(bool, _g_count, notify=stateChanged)
    lastSync = Property(str, _g_last, notify=stateChanged)
    ready = Property(bool, _g_ready, notify=stateChanged)

    # ------------------------------------------------------------ utilidades
    def _save(self, key: str, value) -> None:
        s = QSettings()
        s.setValue("sync/" + key, value)

    def _set_status(self, es: str, en: str = "") -> None:
        self._status = (es, en or es)
        self.stateChanged.emit()

    def _configure(self) -> None:
        """Crea el destino según el modo elegido y programa las comprobaciones."""
        self._backend = None
        if self._mode == "google" and self._client_id and self._refresh:
            if not self._google or self._google.refresh_token != self._refresh:
                self._google = core.GoogleDriveBackend(self._client_id, self._client_secret, self._refresh)
            self._backend = self._google
        elif self._mode == "folder" and self._folder:
            self._backend = core.FolderBackend(self._folder)

        if self._mode == "off":
            self._status = ("Desactivada.", "Off.")
        elif self._mode == "google" and not self._client_id:
            self._status = ("Esta versión no incluye acceso a Google. Usa una carpeta sincronizada.",
                            "This build has no Google access. Use a synced folder instead.")
        elif self._mode == "google" and not self._refresh:
            self._status = ("Inicia sesión con tu cuenta de Google.", "Sign in with your Google account.")
        elif self._mode == "folder" and not self._folder:
            self._status = ("Elige la carpeta donde guardar la configuración.", "Choose the folder where settings are stored.")
        elif self._backend:
            self._status = ("Conectando…", "Connecting…")

        self._pull_timer.stop()
        if self._backend and self._enabled:
            self._pull_timer.start(PULL_EVERY_MS[self._mode])
        self.stateChanged.emit()

    def _run(self, work, done) -> None:
        """Ejecuta work() en otro hilo y done(resultado, error) en el principal."""
        self._busy = True
        self.stateChanged.emit()

        def target():
            try:
                res, err = work(), None
            except Exception as e:          # noqa: BLE001 – cualquier fallo se muestra al usuario
                res, err = None, e
            self._post.emit(lambda: self._finish(done, res, err))

        threading.Thread(target=target, daemon=True).start()

    def _finish(self, done, res, err) -> None:
        self._busy = False
        if isinstance(err, core.AuthExpired):
            self._refresh = ""
            self._save("refreshToken", "")
            self._configure()
        if err is not None:
            if isinstance(err, core.SyncError):
                self._set_status(err.es, err.en)
            else:
                self._set_status(f"Error inesperado: {err}", f"Unexpected error: {err}")
        else:
            done(res)
        if self._again:
            self._again = False
            QTimer.singleShot(0, self.syncNow)

    def _mark_synced(self, data: dict) -> None:
        self._synced = core.digest(data)
        self._save("syncedHash", self._synced)
        self._last = time.strftime("%H:%M")
        if isinstance(self._backend, core.FolderBackend):
            self._set_status(f"Sincronizado con la carpeta a las {self._last}.", f"Synced with the folder at {self._last}.")
        else:
            self._set_status(f"Sincronizado con Google Drive a las {self._last}.", f"Synced with Google Drive at {self._last}.")

    def _doc(self, data: dict) -> dict:
        return core.make_doc(data, self._stamp, self._device, socket.gethostname())

    # ------------------------------------------------------------ llamadas desde QML
    @Slot(str)
    def report(self, json_text: str) -> None:
        """QML envía la configuración actual de todos los relojes (sin posiciones)."""
        try:
            data = json.loads(json_text)
        except ValueError:
            return
        changed = self._local is None or core.normalize(data) != core.normalize(self._local)
        self._local = data
        if not changed:
            return
        eff = core.effective(data, self._remote, self._sync_count)
        if self._synced and core.digest(eff) != self._synced:
            self._stamp = time.time() * 1000          # cambio hecho en este equipo
            self._save("localStamp", self._stamp)
            if self._backend and self._enabled:
                self._push_timer.start(PUSH_DELAY_MS)

    @Slot()
    def start(self) -> None:
        if self._backend and self._enabled:
            QTimer.singleShot(1500, self.syncNow)

    @Slot()
    def syncNow(self) -> None:
        self._sync(force=None)

    @Slot()
    def pushNow(self) -> None:
        self._sync(force="push")

    @Slot()
    def pullNow(self) -> None:
        self._sync(force="pull")

    def _sync(self, force) -> None:
        if not self._backend or not self._enabled:
            return
        if self._busy:
            self._again = True
            return
        self.requestLocal.emit()                     # QML llama a report() de inmediato
        if self._local is None:
            return
        backend = self._backend
        self._set_status("Sincronizando…", "Syncing…")
        self._run(backend.read, lambda remote: self._after_read(remote, force))

    def _after_read(self, remote, force) -> None:
        if remote is not None and not core.valid_doc(remote):
            remote = None
        self._remote = remote
        action = force or core.decide(self._local, self._stamp, remote, self._sync_count)
        if action == "pull" and remote is None:
            self._set_status("Todavía no hay configuración guardada en la nube.", "There are no saved settings in the cloud yet.")
            return
        if action == "pull":
            data = remote["data"]
            self._stamp = float(remote.get("updatedAt", 0))
            self._save("localStamp", self._stamp)
            self._mark_synced(data)
            self.remoteConfig.emit(json.dumps(data, ensure_ascii=False))
            # QML ya aplicó los ajustes; si este equipo no pudo reproducirlos igual
            # (p. ej. tiene más relojes), report() lo detecta y sube el resultado.
            self._local = None
            self.requestLocal.emit()
            return
        if action == "same":
            self._mark_synced(remote["data"])
            return
        if force == "push" or self._stamp == 0:
            self._stamp = time.time() * 1000
            self._save("localStamp", self._stamp)
        data = core.effective(self._local, remote, self._sync_count)
        doc = self._doc(data)
        backend = self._backend
        self._run(lambda: backend.write(doc), lambda _: (setattr(self, "_remote", doc), self._mark_synced(data)))

    @Slot(str)
    def setMode(self, mode: str) -> None:
        if mode not in ("off", "google", "folder") or mode == self._mode:
            return
        self._mode = mode
        self._save("mode", mode)
        self._configure()
        self.start()

    @Slot(str)
    def setFolder(self, folder: str) -> None:
        path = QUrl(folder).toLocalFile() if folder.startswith("file:") else folder
        if not path:
            return
        self._folder = path
        self._save("folder", path)
        self._mode = "folder"
        self._save("mode", "folder")
        self._configure()
        self.start()

    @Slot(bool)
    def setSyncCount(self, on: bool) -> None:
        self._sync_count = bool(on)
        self._save("syncCount", self._sync_count)
        self.stateChanged.emit()

    @Slot()
    def login(self) -> None:
        if self._logging_in or not self._client_id:
            return
        self._logging_in = True
        self._cancel_login = False
        self._set_status("Completa el inicio de sesión en el navegador…", "Finish signing in in your browser…")
        cid, sec, lang = self._client_id, self._client_secret, self._lang()

        def work():
            return core.google_login(cid, sec, webbrowser.open, lambda: self._cancel_login, lang=lang)

        def done(res):
            self._refresh, self._account = res
            self._save("refreshToken", self._refresh)
            self._save("account", self._account)
            self._mode = "google"
            self._save("mode", "google")
            self._configure()
            self.start()

        def finish_wrapper(res, err):
            self._logging_in = False
            self._finish(done, res, err)

        self.stateChanged.emit()

        def target():
            try:
                res, err = work(), None
            except Exception as e:  # noqa: BLE001
                res, err = None, e
            self._post.emit(lambda: finish_wrapper(res, err))

        threading.Thread(target=target, daemon=True).start()

    @Slot()
    def cancelLogin(self) -> None:
        self._cancel_login = True

    @Slot()
    def logout(self) -> None:
        token = self._refresh
        if token:
            threading.Thread(target=core.google_revoke, args=(token,), daemon=True).start()
        self._refresh = ""
        self._account = ""
        self._google = None
        self._save("refreshToken", "")
        self._save("account", "")
        self._configure()
