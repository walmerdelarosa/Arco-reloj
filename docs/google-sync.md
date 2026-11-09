# Sign in with Google

[Español](google-sync.es.md)

The **Google account** sync option needs an OAuth client ID owned by the project. Without it, the app works the same and sync offers only the synced-folder option.

Arco requests only the `drive.appdata` scope: it stores `arco-config.json` in a hidden app folder in the user's Drive that only Arco can read. Google classifies this scope as *non-sensitive*, so the app does not need to go through verification.

## 1. Create the credentials

1. Open [Google Cloud Console](https://console.cloud.google.com/) and create a project (for example, "Arco").
2. **APIs & Services → Library**: enable **Google Drive API**.
3. **Google Auth Platform → Branding**: app name and support email. To publish, also add the home page (`https://github.com/<user>/Arco-reloj`), the privacy policy (`…/blob/main/PRIVACY.md`) and `github.com` as an authorized domain. Do not upload a logo: it makes verification mandatory.
4. **Audience**: *External*. Click **Publish app** to move it to *In production*.
   In *Testing*, only the test users you add can sign in, and sessions expire after 7 days.
5. **Data access**: add the scopes `openid`, `.../auth/userinfo.email` and `.../auth/drive.appdata`.
6. **Clients → Create client**: type **Desktop app**. Download the JSON.

For desktop apps the "client secret" is not confidential (it ships inside the program), and Google treats it that way. Still, do not commit it.

## 2. Use them

**In GitHub releases.** In the repository, go to *Settings → Secrets and variables → Actions* and create:

| Secret | Value |
|---|---|
| `GOOGLE_CLIENT_ID` | `client_id` from the JSON |
| `GOOGLE_CLIENT_SECRET` | `client_secret` from the JSON |

The *Release Windows* workflow bundles them into the installer.

**Locally.** Save the downloaded JSON as `google_oauth.json` next to `arco.py` (it is in `.gitignore`). `build_windows.bat` and `build_installer.bat` include it when present. The environment variables `ARCO_GOOGLE_CLIENT_ID` and `ARCO_GOOGLE_CLIENT_SECRET` also work.

## How it works

- Desktop sign-in: OAuth 2.0 with PKCE and a `127.0.0.1` redirect. The browser opens; Arco never sees the password.
- The refresh token is stored in the user's Windows registry (`HKCU\Software\Arco\Arco Reloj\sync`). "Sign out" revokes it.
- Changes are uploaded a few seconds after you make them and the cloud copy is checked every 3 minutes. If two devices change at the same time, the most recent change wins.
- Clock positions are not synced.
