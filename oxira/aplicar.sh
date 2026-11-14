#!/usr/bin/env bash
# OXIVIEW Remote: marca, servidor y llave sobre el código base. Se corre desde la raíz del repo.
set -euo pipefail
SERVIDOR="remote.oxira.net.pe"
LLAVE="WeGa86SknBPYnn8Tqj24bNsQXoV7Lx2e5qv+7jmfXTo="
NOMBRE="OxiView"
M=oxira/marca

c=libs/hbb_common/src/config.rs
sed -i "s|pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[\"rs-ny.rustdesk.com\"\];|pub const RENDEZVOUS_SERVERS: \&[\&str] = \&[\"$SERVIDOR\"];|" $c
sed -i "s|pub const RS_PUB_KEY: &str = \".*\";|pub const RS_PUB_KEY: \&str = \"$LLAVE\";|" $c
sed -i "s|RwLock::new(\"RustDesk\".to_owned())|RwLock::new(\"$NOMBRE\".to_owned())|" $c
grep -q "\"$SERVIDOR\"" $c && grep -q "$LLAVE" $c && grep -q "\"$NOMBRE\"" $c || { echo "FALLO parche config.rs"; exit 1; }

# API propia: registro de cada PC (heartbeat/sysinfo) y aviso de versiones nuevas
API="https://$SERVIDOR"
sed -i "s|    \"https://admin.rustdesk.com\".to_owned()|    \"$API\".to_owned()|" src/common.rs
sed -i "s|const URL: \&str = \"https://api.rustdesk.com/version/latest\";|const URL: \&str = \"$API/version/latest\";|" libs/hbb_common/src/lib.rs
grep -q "\"$API\".to_owned()" src/common.rs && grep -q "$API/version/latest" libs/hbb_common/src/lib.rs || { echo "FALLO parche API"; exit 1; }

# Textos de Windows
r=flutter/windows/runner/Runner.rc
sed -i 's|"Purslane Tech Pte. Ltd."|"OXIRA S.A.C."|; s|"RustDesk Remote Desktop"|"OXIVIEW Remote"|; s|"ProductName", "RustDesk"|"ProductName", "OXIVIEW Remote"|; s|Copyright © 2026 Purslane Tech Pte. Ltd. All rights reserved.|OXIRA S.A.C. Basado en software AGPL-3.0.|' $r
sed -i 's|std::wstring app_name = L"RustDesk";|std::wstring app_name = L"'$NOMBRE'";|' flutter/windows/runner/main.cpp
sed -i 's|^ProductName = "RustDesk"|ProductName = "OXIVIEW Remote"|; s|^FileDescription = "RustDesk Remote Desktop"|FileDescription = "OXIVIEW Remote"|; s|^LegalCopyright = .*|LegalCopyright = "OXIRA S.A.C. Basado en software AGPL-3.0."|' Cargo.toml

# Íconos
cp $M/icon.ico res/icon.ico
cp $M/icon.ico res/tray-icon.ico
cp $M/icon.ico flutter/windows/runner/resources/app_icon.ico
cp $M/256.png res/icon.png
cp $M/32.png res/32x32.png
cp $M/64.png res/64x64.png
cp $M/128.png res/128x128.png
cp $M/256.png res/128x128@2x.png
cp $M/icon.svg res/icon.svg 2>/dev/null || true
cp $M/icon.svg flutter/assets/icon.svg
for f in flutter/assets/icon.png flutter/assets/logo.png; do [ -f "$f" ] && cp $M/512.png "$f"; done
echo "OXIRA: parche aplicado ($NOMBRE -> $SERVIDOR)"
