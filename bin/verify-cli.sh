#!/bin/bash
# StarForge CLI Verification Script
# Verifies that starforge command is accessible globally

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Emoji
CHECK="✅"
ERROR="❌"
WARN="⚠️ "
INFO="ℹ️ "

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔍 StarForge CLI Verification${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Determine user's actual shell
USER_SHELL=$(basename "$SHELL")

echo "Detected shell: $USER_SHELL"

# Determine primary config file
if [ "$USER_SHELL" = "zsh" ]; then
    RC_FILE="$HOME/.zshrc"
elif [ "$USER_SHELL" = "bash" ]; then
    if [ -f "$HOME/.bash_profile" ]; then
        RC_FILE="$HOME/.bash_profile"
    else
        RC_FILE="$HOME/.bashrc"
    fi
else
    RC_FILE="$HOME/.profile"
fi

echo "Primary config file: $RC_FILE"
echo ""

# Check 1: Is StarForge in PATH config?
echo -e "${INFO}Checking PATH configuration..."

# Check all common config files
CONFIG_FILES=("$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile")
FOUND_IN=""

for config in "${CONFIG_FILES[@]}"; do
    if [ -f "$config" ] && grep -q "starforge-master/bin" "$config" 2>/dev/null; then
        FOUND_IN="$config"
        echo -e "${CHECK} StarForge found in $config"
        STARFORGE_PATH=$(grep "starforge-master/bin" "$config" | head -1)
        echo "   $STARFORGE_PATH"
        break
    fi
done

if [ -z "$FOUND_IN" ]; then
    echo -e "${ERROR} StarForge NOT found in any shell config"
    echo ""
    echo -e "${YELLOW}To fix: Run the install-cli.sh script${NC}"
    echo "  cd ~/starforge-master"
    echo "  bash install-cli.sh"
    exit 1
fi

echo ""

# Check 2: Is StarForge in current PATH?
echo -e "${INFO}Checking current PATH..."
if echo "$PATH" | grep -q "starforge-master/bin"; then
    echo -e "${CHECK} StarForge is in current PATH"
else
    echo -e "${WARN}StarForge NOT in current PATH"
    echo ""
    echo -e "${YELLOW}To fix: Source your shell config${NC}"
    echo "  source $RC_FILE"
    echo ""
    echo "Or open a new terminal"
    echo ""
fi

echo ""

# Check 3: Can we run starforge command?
echo -e "${INFO}Testing starforge command..."
if command -v starforge &> /dev/null; then
    STARFORGE_LOCATION=$(which starforge)
    echo -e "${CHECK} starforge command is available"
    echo "   Location: $STARFORGE_LOCATION"

    # Test that it runs
    if starforge help > /dev/null 2>&1; then
        echo -e "${CHECK} starforge help works"
    else
        echo -e "${ERROR} starforge command exists but doesn't run properly"
    fi
else
    echo -e "${ERROR} starforge command NOT available"
    echo ""
    echo -e "${YELLOW}To fix: Source your shell config${NC}"
    echo "  source $RC_FILE"
    echo ""
    echo "Then verify:"
    echo "  starforge help"
fi

echo ""

# Check 4: Verify starforge-master exists
echo -e "${INFO}Checking starforge-master installation..."
if [ -d "$HOME/starforge-master" ]; then
    echo -e "${CHECK} starforge-master directory exists"

    # Check if it's a git repo
    if [ -d "$HOME/starforge-master/.git" ]; then
        echo -e "${CHECK} starforge-master is a git repository"

        # Check for remote
        cd "$HOME/starforge-master"
        if git remote get-url origin &> /dev/null; then
            REMOTE_URL=$(git remote get-url origin)
            echo -e "${CHECK} GitHub remote configured: $REMOTE_URL"
        else
            echo -e "${WARN}No GitHub remote configured"
        fi
        cd - > /dev/null
    else
        echo -e "${WARN}starforge-master is not a git repository"
    fi
else
    echo -e "${ERROR} starforge-master directory NOT found at $HOME/starforge-master"
    echo ""
    echo -e "${YELLOW}Expected location: $HOME/starforge-master${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Final summary
if command -v starforge &> /dev/null && starforge help > /dev/null 2>&1; then
    echo -e "${CHECK} ${GREEN}StarForge CLI is working correctly!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "You can now use starforge from anywhere:"
    echo "  starforge help"
    echo "  starforge install"
    echo "  starforge update"
    echo ""
else
    echo -e "${WARN} ${YELLOW}StarForge CLI needs configuration${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo ""
    echo "1. Source your shell config:"
    echo "   source $RC_FILE"
    echo ""
    echo "2. Verify it works:"
    echo "   starforge help"
    echo ""
    echo "3. If that doesn't work, run install-cli.sh again:"
    echo "   cd ~/starforge-master"
    echo "   bash install-cli.sh"
    echo ""
fi
