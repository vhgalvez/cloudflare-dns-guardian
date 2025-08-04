

# Cloudflare DNS Guardian

Este proyecto permite gestionar registros DNS en Cloudflare de forma automática, creando y eliminando registros según sea necesario.

```bash
git clone https://github.com/tuusuario/cloudflare-dns-guardian.git
cd cloudflare-dns-guardian
sudo chmod +x install.sh
sudo chmod +x bootstrap_dns.sh
sudo chmod +x check_and_repair_dns.sh
sudo ./install.sh             # instala scripts + systemd.timer
sudo bootstrap_dns.sh         # (una vez) crea registros base

sudo systemctl enable dns-guardian.timer
sudo systemctl start dns-guardian.timer
sudo systemctl status dns-guardian.timer



```