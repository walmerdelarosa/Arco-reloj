# Firma de código en Windows

Mientras el instalador no esté firmado, Windows SmartScreen muestra «Windows protegió su PC» y algunos antivirus lo marcan como sospechoso (los ejecutables hechos con PyInstaller sin firma dan falsos positivos con frecuencia).

La compilación ya está preparada: en cuanto haya un certificado, GitHub Actions firma `ArcoReloj.exe`, el instalador y el desinstalador con `installer/sign.ps1`. Sin certificado, todo sigue funcionando y se publica sin firmar.

## Qué falta: conseguir un certificado

Un certificado de firma de código lo emite una autoridad de certificación después de verificar tu identidad; no se puede generar en el repositorio. Desde 2023 las autoridades ya no entregan certificados como archivo `.pfx`: la clave privada debe estar en un token USB o en un HSM en la nube. Opciones para un desarrollador individual:

| Opción | Costo | Notas |
|---|---|---|
| **SignPath Foundation** (proyectos de código abierto) | Gratis | Requiere licencia aprobada por OSI (el README dice MIT, pero falta el archivo `LICENSE`), repositorio público, 2FA en GitHub y una página de «política de firma». El certificado sale a nombre de SignPath Foundation, no al tuyo. Se integra con su propia acción de GitHub, que reemplazaría el paso «Firma del ejecutable». <https://signpath.org> |
| **Certificado OV para persona natural** (Certum, SSL.com, Sectigo y revendedores) | Pago anual | Firma en la nube (Certum SimplySign, SSL.com eSigner…). Algunas permiten firmar desde GitHub Actions; otras requieren un equipo propio con el complemento instalado. Revisa precios y requisitos actuales en cada proveedor. |
| **Azure Artifact Signing** (antes Trusted Signing) | Suscripción mensual | Hoy solo admite personas naturales de Estados Unidos y Canadá; no está disponible desde Colombia como individuo. |

## Activarlo en GitHub

En **Settings → Secrets and variables → Actions** crea uno de estos juegos de secretos:

- `SIGN_PFX_BASE64` y `SIGN_PFX_PASSWORD`: certificado `.pfx` en base64 (`[Convert]::ToBase64String([IO.File]::ReadAllBytes("cert.pfx"))`). Sirve para certificados antiguos o para probar con uno autofirmado (este último no quita el aviso en otros equipos).
- `SIGN_CERT_SHA1`: huella de un certificado instalado en el almacén de Windows, para un runner propio con el token o el complemento del proveedor en la nube.
- Opcional: `SIGN_TIMESTAMP_URL` si el proveedor indica otro servidor de sello de tiempo.

Si el proveedor usa su propia herramienta en lugar de `signtool`, basta con cambiar `installer/sign.ps1`: el flujo de trabajo y el instalador lo llaman a él para todo.

## Mientras tanto

- Firmar no quita el aviso de inmediato: SmartScreen también se basa en la reputación del archivo, que crece con las descargas.
- Si un antivirus marca una versión, envíala como falso positivo: Microsoft Defender en <https://www.microsoft.com/wdsi/filesubmission>; los demás antivirus tienen formularios equivalentes.
- La compilación ya reduce falsos positivos: el `.exe` lleva nombre de producto y versión, y no se comprime con UPX.
