# Inicio de sesión con Google

[English](google-sync.md)

La opción **Cuenta de Google** necesita un ID de cliente OAuth propio del proyecto. Sin él, la app funciona igual y la sincronización ofrece solo la carpeta sincronizada.

Arco usa únicamente el permiso `drive.appdata`: guarda `arco-config.json` en una carpeta oculta del Drive del usuario que solo Arco puede leer. Google lo clasifica como *no sensible*, así que no hace falta pasar la verificación de la app.

## 1. Crear las credenciales

1. Entra en [Google Cloud Console](https://console.cloud.google.com/) y crea un proyecto (por ejemplo, «Arco»).
2. **APIs y servicios → Biblioteca**: activa **Google Drive API**.
3. **Google Auth Platform → Branding**: nombre de la app y correo de soporte. Para publicarla, añade también la página principal (`https://github.com/<usuario>/Arco-reloj`), la política de privacidad (`…/blob/main/PRIVACY.md`) y el dominio autorizado `github.com`. No subas logotipo: obliga a verificar la app.
4. **Público**: tipo *Externo*. Pulsa **Publicar app** para pasarla a *En producción*.
   En modo *Prueba* solo pueden entrar los usuarios de prueba que añadas, y la sesión caduca a los 7 días.
5. **Acceso a datos**: añade los permisos `openid`, `.../auth/userinfo.email` y `.../auth/drive.appdata`.
6. **Clientes → Crear cliente**: tipo **App de escritorio**. Descarga el JSON.

En las apps de escritorio el «secreto del cliente» no es confidencial (viaja dentro del programa); Google lo trata así. Aun así, no lo subas al repositorio.

## 2. Usarlas

**En los releases de GitHub.** En el repositorio, *Settings → Secrets and variables → Actions*, crea:

| Secreto | Valor |
|---|---|
| `GOOGLE_CLIENT_ID` | `client_id` del JSON |
| `GOOGLE_CLIENT_SECRET` | `client_secret` del JSON |

El flujo *Release Windows* los incluye en el instalador.

**En local.** Guarda el JSON descargado como `google_oauth.json` junto a `arco.py` (está en `.gitignore`). `build_windows.bat` y `build_installer.bat` lo incluyen si existe. También sirven las variables de entorno `ARCO_GOOGLE_CLIENT_ID` y `ARCO_GOOGLE_CLIENT_SECRET`.

## Cómo funciona

- Inicio de sesión de app de escritorio: OAuth 2.0 con PKCE y redirección a `127.0.0.1`. Se abre el navegador; Arco no ve la contraseña.
- El token de renovación se guarda en el registro de Windows del usuario (`HKCU\Software\Arco\Arco Reloj\sync`). «Cerrar sesión» lo revoca.
- Los cambios se suben unos segundos después de hacerlos y la nube se consulta cada 3 minutos. Si dos equipos cambian a la vez, gana el cambio más reciente.
- Las posiciones de los relojes no se sincronizan.
