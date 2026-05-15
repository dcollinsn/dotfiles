sudo pacman -S pyenv nvm discord
pamac install synology-drive slack-desktop

source /usr/share/nvm/init-nvm.sh

pyenv install 3.11
pyenv install 3.13

nvm install node

cp zshrc ~/.zshrc
cp p10k.zsh ~/.p10k.zsh
