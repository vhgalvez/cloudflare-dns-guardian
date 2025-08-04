#!/usr/bin/env bash
# bootstrap_dns.sh — Crea registros DNS base en Cloudflare
# © 2025 @vhgalvez · MIT
# Uso: sudo bootstrap_dns.sh

set -euo pipefail
IFS=$'\n\t'

ENV_FILE="/etc/cloudflare-ddns/.env"
LOG_FILE="/var/log/cloudflare-dns-guardian.log"
log(){ printf '[%(%F %T)T] [BOOT] %b\n' -1 "$*" | tee -a "$LOG_FILE"; }

[[ -f $ENV_FILE ]] || { echo "❌ Falta $ENV_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${TTL:=300}"
: "${PROXIED:=false}"
: "${CNAME_TARGET:=$ZONE_NAME}"

[[ -n ${CF_API_TOKEN:-} ]] || { log "CF_API_TOKEN vacío"; exit 1; }
[[ -n ${ZONE_NAME:-}    ]] || { log "ZONE_NAME vacío";    exit 1; }
[[ -n ${RECORD_NAMES:-} ]] || { log "RECORD_NAMES vacío"; exit 1; }

ZONE_ID=$(curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME&status=active&match=all" |
  jq -r '.result[0].id') || true

[[ -n $ZONE_ID && $ZONE_ID != null ]] || { log "Zona no encontrada"; exit 1; }

IPV4=$(curl -s https://1.1.1.1/cdn-cgi/trace | grep '^ip=' | cut -d= -f2 || true)
[[ $IPV4 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { log "IP pública inválida"; exit 1; }

create_record(){
  local host=$1 type=$2 value=$3 prox=$4
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
    --data "{\"type\":\"$type\",\"name\":\"$host\",\"content\":\"$value\",\"ttl\":$TTL,\"proxied\":$prox}" \
    | jq -e '.success' >/dev/null && log "✅  $host ($type) creado"
}

# A/AAAA iniciales
IFS=',' read -ra HOSTS <<< "$RECORD_NAMES"
for H in "${HOSTS[@]}"; do
  exists=$(curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$H&match=all" |
    jq '.result | length')
  [[ $exists -eq 0 ]] && { log "🔧 Creando $H (A)"; create_record "$H" "A" "$IPV4" "$PROXIED"; } \
                       || log "➡️  $H ya existe (skip)"
done

# CNAME www
exists_www=$(curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=CNAME&name=www.$ZONE_NAME&match=all" |
  jq '.result | length')
[[ $exists_www -eq 0 ]] && { log "🔧 Creando CNAME www → $CNAME_TARGET"; create_record "www" "CNAME" "$CNAME_TARGET" true; } \
                         || log "➡️  CNAME www ya existe (skip)"

log "🏁 Bootstrap finalizado"