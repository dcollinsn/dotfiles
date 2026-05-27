sudo pacman -Syu iwd

sudo install -Dm644 /dev/stdin /etc/NetworkManager/conf.d/wifi_backend.conf <<'EOF'
[device]
wifi.backend=iwd
EOF

sudo systemctl stop NetworkManager
sudo systemctl stop wpa_supplicant.service
sudo systemctl disable wpa_supplicant.service
sudo systemctl enable --now iwd.service
sudo systemctl restart NetworkManager
nmcli radio wifi on
