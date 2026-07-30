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
