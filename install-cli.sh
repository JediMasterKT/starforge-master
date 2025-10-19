#!/bin/bash
# Install StarForge CLI to PATH

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

STARFORGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🚀 Installing StarForge CLI${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Determine shell
if [ -n "$ZSH_VERSION" ]; then
    SHELL_NAME="zsh"
    RC_FILE="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_NAME="bash"
    if [ -f "$HOME/.bash_profile" ]; then
        RC_FILE="$HOME/.bash_profile"
    else
        RC_FILE="$HOME/.bashrc"
    fi
else
    SHELL_NAME="unknown"
    RC_FILE="$HOME/.profile"
fi

echo "Detected shell: $SHELL_NAME"
echo "Config file: $RC_FILE"
echo ""

# Check if already in PATH
if echo "$PATH" | grep -q "$STARFORGE_DIR/bin"; then
    echo -e "${GREEN}✅ StarForge already in PATH${NC}"
else
    # Add to PATH in shell config
    echo "" >> "$RC_FILE"
    echo "# StarForge CLI" >> "$RC_FILE"
    echo "export PATH=\"$STARFORGE_DIR/bin:\$PATH\"" >> "$RC_FILE"

    echo -e "${GREEN}✅ Added StarForge to PATH in $RC_FILE${NC}"
fi

echo ""
echo -e "${YELLOW}To use StarForge immediately, run:${NC}"
echo "  source $RC_FILE"
echo ""
echo -e "${YELLOW}Or open a new terminal${NC}"
echo ""
echo -e "${GREEN}Then verify installation:${NC}"
echo "  starforge help"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Installation complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
