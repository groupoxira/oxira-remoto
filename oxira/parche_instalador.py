# OXIVIEW: el instalador copia rustdesk.exe pero luego abre <APP_NAME>.exe.
# Se agrega el renombre (rename_exe_cmd, que ya existe y no se usaba) a copy_exe_cmd: vale para instalar y actualizar.
import sys
p = "src/platform/windows.rs"
s = open(p, encoding="utf-8").read()
viejo = '''        {main_exe}
        copy /Y \\"{ORIGIN_PROCESS_EXE}\\" \\"{path}\\\\{broker_exe}\\"
        ",
        ORIGIN_PROCESS_EXE'''
nuevo = '''        {main_exe}
        {rename}
        copy /Y \\"{ORIGIN_PROCESS_EXE}\\" \\"{path}\\\\{broker_exe}\\"
        ",
        rename = rename_exe_cmd(src_exe, path)?,
        ORIGIN_PROCESS_EXE'''
if s.count(viejo) != 1:
    sys.exit("FALLO parche instalador: no se encontró copy_exe_cmd")
open(p, "w", encoding="utf-8", newline="").write(s.replace(viejo, nuevo))
print("OXIRA: instalador renombra el exe")
