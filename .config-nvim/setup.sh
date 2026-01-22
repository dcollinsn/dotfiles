#!/bin/bash
# Neovim setup script

set -e

echo "================================"
echo "Neovim Configuration Setup"
echo "================================"
echo ""

# Check if Neovim is installed
if ! command -v nvim &> /dev/null; then
    echo "❌ Neovim is not installed!"
    echo ""
    echo "Install Neovim first:"
    echo "  Ubuntu/Debian: sudo apt install neovim"
    echo "  macOS: brew install neovim"
    echo "  Arch: sudo pacman -S neovim"
    exit 1
fi

# Check Neovim version
NVIM_VERSION=$(nvim --version | head -n1 | cut -d' ' -f2 | cut -d'v' -f2)
echo "✓ Neovim version: $NVIM_VERSION"

# Check for required tools
echo ""
echo "Checking for optional dependencies..."

if command -v rg &> /dev/null; then
    echo "✓ ripgrep installed"
else
    echo "⚠ ripgrep not found (recommended for Telescope grep)"
    echo "  Install: sudo apt install ripgrep (or brew install ripgrep)"
fi

if command -v node &> /dev/null; then
    echo "✓ Node.js installed"
else
    echo "⚠ Node.js not found (needed for some LSP servers)"
fi

if command -v git &> /dev/null; then
    echo "✓ Git installed"
else
    echo "❌ Git is required for plugin management"
    exit 1
fi

# Create undo directory
echo ""
echo "Creating undo directory..."
mkdir -p ~/.config/nvim/undo
echo "✓ Undo directory created"

# Backup existing config if present (shouldn't be, but just in case)
if [ -f ~/.config/nvim/init.vim ]; then
    echo ""
    echo "⚠ Found existing init.vim"
    echo "  Backing up to init.vim.backup"
    mv ~/.config/nvim/init.vim ~/.config/nvim/init.vim.backup
fi

echo ""
echo "================================"
echo "Setup Complete!"
echo "================================"
echo ""
echo "Next steps:"
echo "  1. Launch Neovim: nvim"
echo "  2. Wait for plugins to install automatically"
echo "  3. Quit and restart: :qa"
echo "  4. Run health check: :checkhealth"
echo "  5. Install LSP servers: :Mason"
echo ""
echo "For Python development:"
echo "  - Install pyright: :MasonInstall pyright"
echo "  - Install black: pip install black"
echo "  - Install isort: pip install isort"
echo "  - Install flake8: pip install flake8"
echo ""
echo "Documentation:"
echo "  - README.md: ~/.config/nvim/README.md"
echo "  - Migration guide: ~/.config/nvim/MIGRATION.md"
echo ""
echo "Enjoy your new Neovim setup! 🚀"
