#!/bin/bash

(
    cd /tmp
    rm -rf neovim
    git clone https://github.com/neovim/neovim
    cd neovim
    git checkout stable
    make CMAKE_BUILD_TYPE=release CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=/opt/nvim"
    sudo make install
)

cp -R .config-nvim ~/.config/nvim

if [[ "$EDITOR" != "nvim" ]]; then
    echo "export EDITOR=nvim" >> ~/.bashrc
fi

if [[ "$PATH" != *"/opt/nvim/bin"* ]]; then
    echo 'export PATH="$PATH:/opt/nvim/bin"' >> ~/.bashrc
    echo "Make sure you run 'source ~/.bashrc'"
fi
