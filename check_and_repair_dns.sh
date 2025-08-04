#!/usr/bin/env bash
# check_and_repair_dns.sh — Verifica y repara registros críticos en Cloudflare
# © 2025 @vhgalvez · MIT
# Uso: sudo check_and_repair_dns.sh (o con systemd.timer)

set -euo pipefail
IFS=$'\n\t'

ENV_FILE="/etc/cloudflare-ddns/.env"
LOG_FILE="/var/log/cloudflare-dns-guardian.log"
log(){ printf '[%(%F %T)T] [CHK] %b\n' -1 "$*" | tee -a "$LOG_FILE"; }

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

repair(){
  local host=$1 type=$2 desired=$3 prox=$4
  rec=$(curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=$type&name=$host&match=all&per_page=1")
  if [[ $(echo "$rec" | jq '.result | length') -eq 0 ]]; then
    log "⚠️  Falta $host ($type); creando"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
      -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
      --data "{\"type\":\"$type\",\"name\":\"$host\",\"content\":\"$desired\",\"ttl\":$TTL,\"proxied\":$prox}" >/dev/null
    log "✅  $host ($type) creado"
    return
  fi
  id=$(echo "$rec" | jq -r '.result[0].id')
  val=$(echo "$rec" | jq -r '.result[0].content')
  if [[ "$val" != "$desired" ]]; then
    log "🔄  Corrigiendo $host ($type): $val → $desired"
    curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$id" \
      -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
      --data "{\"type\":\"$type\",\"name\":\"$host\",\"content\":\"$desired\",\"ttl\":$TTL,\"proxied\":$prox}" >/dev/null
    log "✅  $host ($type) actualizado"
  else
    log "✓  $host ($type) OK"
  fi
}

IFS=',' read -ra HOSTS <<< "$RECORD_NAMES"
for h in "${HOSTS[@]}"; do repair "$h" "A" "$IPV4" "$PROXIED"; done
repair "www" "CNAME" "$CNAME_TARGET" true

log "🏁 Verificación concluida"
