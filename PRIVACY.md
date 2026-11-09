# Política de privacidad de Arco

Arco es un reloj de escritorio de código abierto. No tiene servidores propios y no recopila, vende ni comparte datos personales.

## Qué datos usa

- **Configuración del reloj** (colores, estilos, formatos, horario de jornada). Se guarda en tu equipo.
- **Sincronización opcional con Google.** Si inicias sesión con tu cuenta de Google, Arco guarda un único archivo, `arco-config.json`, con esa configuración en la carpeta oculta de la aplicación en tu Google Drive. Solo Arco puede leerlo.
- **Tu dirección de correo de Google**, únicamente para mostrar en los ajustes con qué cuenta has iniciado sesión.

## Permisos de Google

Arco solicita estos permisos:

- `drive.appdata`: leer y escribir su propio archivo de configuración. No da acceso a tus documentos, fotos ni otros archivos de Drive.
- `openid` y `email`: identificar la cuenta conectada.

El permiso de acceso se guarda en tu equipo (registro de Windows del usuario) y nunca se envía a terceros. Al pulsar «Cerrar sesión» en Arco, el permiso se revoca. También puedes revocarlo en cualquier momento desde https://myaccount.google.com/permissions.

El uso de la información recibida de las API de Google se ajusta a la [Política de datos de usuario de los servicios de las API de Google](https://developers.google.com/terms/api-services-user-data-policy), incluidos los requisitos de uso limitado.

## Eliminar tus datos

Desinstalar Arco borra el programa y su configuración local queda en el registro de Windows del usuario. Para borrar la configuración sincronizada, en Google Drive ve a **Configuración → Administrar aplicaciones → Arco → Opciones → Eliminar datos ocultos de la aplicación**.

## Contacto

Para preguntas sobre esta política, abre un *issue* en el repositorio del proyecto.
