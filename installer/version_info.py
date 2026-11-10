"""Genera el recurso de versión de Windows para PyInstaller (--version-file).

    python installer/version_info.py 1.4.0 version_info.txt

Un .exe con nombre de producto, empresa y versión levanta menos falsos positivos en los
antivirus que uno sin metadatos, y Windows muestra esos datos en Propiedades → Detalles.
"""
import sys

TEMPLATE = """VSVersionInfo(
  ffi=FixedFileInfo(filevers={v}, prodvers={v}, mask=0x3f, flags=0x0, OS=0x40004,
                    fileType=0x1, subtype=0x0, date=(0, 0)),
  kids=[
    StringFileInfo([StringTable('040904B0', [
      StringStruct('CompanyName', 'Arco'),
      StringStruct('FileDescription', 'Arco Reloj'),
      StringStruct('FileVersion', '{s}'),
      StringStruct('InternalName', 'ArcoReloj'),
      StringStruct('LegalCopyright', 'MIT License'),
      StringStruct('OriginalFilename', 'ArcoReloj.exe'),
      StringStruct('ProductName', 'Arco Reloj'),
      StringStruct('ProductVersion', '{s}')])]),
    VarFileInfo([VarStruct('Translation', [1033, 1200])])
  ]
)
"""


def main() -> None:
    s = sys.argv[1].lstrip("vV") if len(sys.argv) > 1 else "0.0.0"
    nums = [int(p) if p.isdigit() else 0 for p in s.split(".")[:4]]
    nums += [0] * (4 - len(nums))
    out = sys.argv[2] if len(sys.argv) > 2 else "version_info.txt"
    with open(out, "w", encoding="utf-8") as f:
        f.write(TEMPLATE.format(v=tuple(nums), s=s))


if __name__ == "__main__":
    main()
