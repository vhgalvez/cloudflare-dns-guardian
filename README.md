

# Cloudflare DNS Guardian

Este proyecto permite gestionar registros DNS en Cloudflare de forma automática, creando y eliminando registros según sea necesario.

```bash
git clone https://github.com/tuusuario/cloudflare-dns-guardian.git
cd cloudflare-dns-guardian
sudo ./install.sh             # instala scripts + systemd.timer
sudo bootstrap_dns.sh         # (una vez) crea registros base
sudo systemctl enable cloudflare-dns-guardian.timer
sudo systemctl start cloudflare-dns-guardian.timer
sudo systemctl status cloudflare-dns-guardian.timer
```