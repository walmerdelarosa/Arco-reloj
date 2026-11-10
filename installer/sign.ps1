# Firma de código de Arco (Authenticode). Lo usan GitHub Actions y Inno Setup.
#
#   pwsh installer\sign.ps1 dist\ArcoReloj\ArcoReloj.exe [otro.exe ...]
#
# Elige el método según las variables de entorno (secretos de GitHub):
#   SIGN_PFX_BASE64 + SIGN_PFX_PASSWORD   certificado .pfx codificado en base64
#   SIGN_CERT_SHA1                        huella de un certificado ya instalado en el almacén de
#                                         Windows (token USB o HSM en la nube con su complemento
#                                         para signtool: Certum SimplySign, SSL.com eSigner CKA,
#                                         DigiCert KeyLocker…)
# Si no hay ninguno, no firma y termina sin error (las compilaciones siguen funcionando).
# Ver docs/code-signing.es.md.
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Files)

$ErrorActionPreference = "Stop"
$timestamp = if ($env:SIGN_TIMESTAMP_URL) { $env:SIGN_TIMESTAMP_URL } else { "http://timestamp.digicert.com" }

if (-not $env:SIGN_PFX_BASE64 -and -not $env:SIGN_CERT_SHA1) {
    Write-Host "Sin certificado configurado: no se firma ($($Files -join ', '))."
    exit 0
}

$signtool = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe" -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | Select-Object -First 1
if (-not $signtool) { throw "No se encontró signtool.exe (Windows SDK)." }

$common = @("sign", "/fd", "sha256", "/tr", $timestamp, "/td", "sha256", "/d", "Arco Reloj")
$pfx = $null
try {
    if ($env:SIGN_PFX_BASE64) {
        $pfx = Join-Path ([IO.Path]::GetTempPath()) ("arco-" + [guid]::NewGuid() + ".pfx")
        [IO.File]::WriteAllBytes($pfx, [Convert]::FromBase64String($env:SIGN_PFX_BASE64))
        $cert = @("/f", $pfx, "/p", $env:SIGN_PFX_PASSWORD)
    } else {
        $cert = @("/sha1", $env:SIGN_CERT_SHA1)
    }
    foreach ($f in $Files) {
        Write-Host "Firmando $f"
        # El servidor de sello de tiempo a veces falla: se reintenta.
        $ok = $false
        for ($i = 1; $i -le 3 -and -not $ok; $i++) {
            & $signtool.FullName @common @cert $f
            $ok = ($LASTEXITCODE -eq 0)
            if (-not $ok) { Start-Sleep -Seconds (5 * $i) }
        }
        if (-not $ok) { throw "No se pudo firmar $f" }
        & $signtool.FullName verify /pa $f | Out-Host
    }
} finally {
    if ($pfx -and (Test-Path $pfx)) { Remove-Item $pfx -Force }
}
