# 🌐 Cloudflare DNS Guardian

**Cloudflare DNS Guardian** es un sistema de protección automática para registros DNS críticos en Cloudflare. Está diseñado para:

- 🛡️ **Prevenir fallos por eliminación o corrupción de registros.**
- 🔁 **Revisar y reparar registros cada día automáticamente.**
- ⚡ **Restaurar rápidamente entornos en caso de desastre.**

---

## 🚀 Instalación rápida

```bash
git clone https://github.com/vhgalvez/cloudflare-dns-guardian.git
cd cloudflare-dns-guardian

# Dar permisos de ejecución
sudo chmod +x install.sh bootstrap_dns.sh check_and_repair_dns.sh

# Instalar el sistema (instala scripts + timer systemd)
sudo ./install.sh
```

---

## 🔧 Bootstrap inicial (una sola vez)

Ejecuta una vez para crear los registros base:

```bash
sudo bootstrap_dns.sh
```

Este script:
- Crea `A` records para `socialdevs.site` y `public.socialdevs.site` si no existen.
- Crea el `CNAME` `www → socialdevs.site`.

---

## ⏱️ Activar vigilancia automática

Habilita el timer de vigilancia diaria:

```bash
sudo systemctl enable dns-guardian.timer
sudo systemctl start dns-guardian.timer
sudo systemctl status dns-guardian.timer
```

El servicio ejecuta `check_and_repair_dns.sh` todos los días a las **00:00**, validando y recreando los registros si han sido eliminados o modificados.

---

## 📁 Archivos incluidos

| Archivo                    | Descripción                                                       |
|----------------------------|-------------------------------------------------------------------|
| `install.sh`               | Instala los scripts en el sistema y configura `systemd`           |
| `bootstrap_dns.sh`         | Crea los registros base (solo una vez)                            |
| `check_and_repair_dns.sh`  | Revisa diariamente los registros y los repara si faltan o fallan  |
| `dns-guardian.service`     | Servicio systemd que ejecuta el script de verificación            |
| `dns-guardian.timer`       | Timer que ejecuta el servicio todos los días                      |

---

## 📝 Requisitos

- Cuenta activa en [Cloudflare](https://cloudflare.com/)
- Token de API con permisos para gestionar DNS
- El siguiente archivo `.env` en `/etc/cloudflare-ddns/` con:

```ini
CF_API_TOKEN=your_token_here
CF_ZONE_NAME=socialdevs.site
CF_RECORDS=socialdevs.site,public.socialdevs.site
```

---

## 📋 Ver logs

Puedes verificar el comportamiento con:

```bash
sudo journalctl -u dns-guardian.service -n 50 --no-pager
```
