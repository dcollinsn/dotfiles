sudo pacman -S pyenv nvm discord
pamac install synology-drive slack-desktop

source /usr/share/nvm/init-nvm.sh

pyenv install 3.11
pyenv install 3.13

nvm install node

cp zshrc ~/.zshrc
cp p10k.zsh ~/.p10k.zsh

sudo cp timezone /etc/NetworkManager/dispatcher.d/09-timezone
sudo chmod +x /etc/NetworkManager/dispatcher.d/09-timezone
sudo systemctl enable ntpdate

# Disable PAM faillock account lockouts while retaining the distro-managed PAM configuration.
sudo sed -i -E 's/^[[:space:]]*#?[[:space:]]*deny[[:space:]]*=.*/deny = 0/' /etc/security/faillock.conf
if ! sudo grep -qE '^[[:space:]]*deny[[:space:]]*=[[:space:]]*0([[:space:]]|$)' /etc/security/faillock.conf; then
  echo 'deny = 0' | sudo tee -a /etc/security/faillock.conf >/dev/null
fi
sudo faillock --reset
