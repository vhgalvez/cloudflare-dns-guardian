#!/usr/bin/env bash
# install.sh — Instala Cloudflare-DNS-Guardian (bootstrap + watchdog)
# © 2025 @vhgalvez · MIT

set -euo pipefail
IFS=$'\n\t'

ROOT_DIR=$(cd -- "$(dirname "$0")" && pwd)
SRC_BOOT="$ROOT_DIR/bootstrap_dns.sh"
SRC_REPAIR="$ROOT_DIR/check_and_repair_dns.sh"

BOOT_DST="/usr/local/bin/bootstrap_dns.sh"
REPAIR_DST="/usr/local/bin/check_and_repair_dns.sh"

SERVICE="/etc/systemd/system/dns-guardian.service"
TIMER="/etc/systemd/system/dns-guardian.timer"

log(){ printf '[%(%F %T)T] %b\n' -1 "$*"; }

# 1. Privilegios
[[ $EUID -eq 0 ]] || exec sudo -E -- "$0" "$@"

# 2. Dependencias
for p in curl jq; do
  command -v "$p" >/dev/null || { echo "Falta $p, instálalo y reintenta"; exit 1; }
done

# 3. Copiar scripts
install -Dm755 "$SRC_BOOT"   "$BOOT_DST"
install -Dm755 "$SRC_REPAIR" "$REPAIR_DST"

# 4. Unidades systemd
cat >"$SERVICE" <<'EOF'
[Unit]
Description=DNS Guardian: verifica y repara registros Cloudflare críticos

[Service]
Type=oneshot
ExecStart=/usr/local/bin/check_and_repair_dns.sh
EOF

cat >"$TIMER" <<'EOF'
[Unit]
Description=Ejecución diaria de DNS Guardian

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now dns-guardian.timer

log "✅ Instalación completada"
log "Puedes ejecutar ahora:  sudo bootstrap_dns.sh   (una sola vez)"