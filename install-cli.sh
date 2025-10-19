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

# Detect user's actual shell (not the script's shell)
USER_SHELL=$(basename "$SHELL")

echo "Detected shell: $USER_SHELL"
echo ""

# Determine which config files to update
RC_FILES=()

if [ "$USER_SHELL" = "zsh" ]; then
    RC_FILES+=("$HOME/.zshrc")
elif [ "$USER_SHELL" = "bash" ]; then
    if [ -f "$HOME/.bash_profile" ]; then
        RC_FILES+=("$HOME/.bash_profile")
    else
        RC_FILES+=("$HOME/.bashrc")
    fi
else
    # Unknown shell, add to common files that exist
    [ -f "$HOME/.zshrc" ] && RC_FILES+=("$HOME/.zshrc")
    [ -f "$HOME/.bashrc" ] && RC_FILES+=("$HOME/.bashrc")
    [ -f "$HOME/.bash_profile" ] && RC_FILES+=("$HOME/.bash_profile")
fi

# Fallback: if no RC files found, use .profile
if [ ${#RC_FILES[@]} -eq 0 ]; then
    RC_FILES+=("$HOME/.profile")
fi

# Check if already in PATH
if echo "$PATH" | grep -q "$STARFORGE_DIR/bin"; then
    echo -e "${GREEN}✅ StarForge already in PATH${NC}"
else
    # Add to all relevant RC files
    for RC_FILE in "${RC_FILES[@]}"; do
        # Only add if not already present in this file
        if ! grep -q "starforge-master/bin" "$RC_FILE" 2>/dev/null; then
            echo "" >> "$RC_FILE"
            echo "# StarForge CLI" >> "$RC_FILE"
            echo "export PATH=\"$STARFORGE_DIR/bin:\$PATH\"" >> "$RC_FILE"
            echo -e "${GREEN}✅ Added StarForge to PATH in $RC_FILE${NC}"
        else
            echo -e "${GREEN}✅ StarForge already in $RC_FILE${NC}"
        fi
    done
fi

echo ""
echo -e "${YELLOW}To use StarForge immediately, run:${NC}"
if [ "$USER_SHELL" = "zsh" ]; then
    echo "  source ~/.zshrc"
elif [ "$USER_SHELL" = "bash" ]; then
    if [ -f "$HOME/.bash_profile" ]; then
        echo "  source ~/.bash_profile"
    else
        echo "  source ~/.bashrc"
    fi
else
    echo "  source ~/.zshrc  (or your shell's config file)"
fi
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
