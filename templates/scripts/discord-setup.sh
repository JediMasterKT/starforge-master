#!/usr/bin/env bash
#
# discord-setup.sh - Automated Discord integration setup for StarForge
#
# Sets up Discord channels and webhooks for agent notifications.
# User creates server manually, then this script automates the rest.
#

set -euo pipefail

# Check bash version (need 4.0+ for associative arrays)
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "❌ Error: Bash 4.0+ required (found ${BASH_VERSION})"
    echo ""
    echo "Your system has an outdated bash version."
    echo ""
    echo "To upgrade:"
    echo "  macOS: brew install bash"
    echo "  Linux: Usually bash 4+ is already installed"
    echo ""
    echo "After installing, ensure new bash is in your PATH:"
    echo "  which bash  # Should show /usr/local/bin/bash or similar"
    echo ""
    exit 1
fi

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
ARROW="${CYAN}→${NC}"

# Discord API
DISCORD_API_BASE="https://discord.com/api/v10"

# Channel names for StarForge agents
declare -a CHANNEL_NAMES=(
    "orchestrator"
    "senior-engineer"
    "junior-dev-a"
    "junior-dev-b"
    "junior-dev-c"
    "junior-dev-d"
    "qa-engineer"
    "tpm-agent"
)

# Global associative arrays for storing IDs and URLs
declare -A CHANNEL_IDS
declare -A WEBHOOK_URLS

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Utility Functions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log_info() {
    echo -e "${BLUE}ℹ${NC}  $1" >&2
}

log_success() {
    echo -e "${CHECK} $1" >&2
}

log_error() {
    echo -e "${CROSS} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}⚠${NC}  $1" >&2
}

spinner() {
    local pid=$1
    local message=$2
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " ${CYAN}%c${NC}  %s\r" "$spinstr" "$message"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
    done
    printf "    \r"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Core Functions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#
# get_bot_token
#
# Prompts user for Discord bot token and validates format.
# Returns: bot token via stdout
#
get_bot_token() {
    echo "" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "${BLUE}Step 1: Discord Bot Token${NC}" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo "" >&2
    echo "You need a Discord bot token to set up StarForge notifications." >&2
    echo "" >&2
    echo "To get your bot token:" >&2
    echo "  1. Go to https://discord.com/developers/applications" >&2
    echo "  2. Create a new application (or select existing)" >&2
    echo "  3. Go to 'Bot' section" >&2
    echo "  4. Click 'Reset Token' or 'Copy' to get your token" >&2
    echo "" >&2
    echo -e "${YELLOW}Note: Keep this token secret! Never commit it to git.${NC}" >&2
    echo "" >&2

    local bot_token=""
    while true; do
        read -sp "Paste your bot token: " bot_token
        echo "" >&2

        if [ -z "$bot_token" ]; then
            log_error "Bot token cannot be empty"
            continue
        fi

        # Strip whitespace and newlines
        bot_token=$(echo "$bot_token" | tr -d '[:space:]')

        # Basic validation: Discord bot tokens are usually 70+ characters
        if [ ${#bot_token} -lt 50 ]; then
            log_error "Token seems too short. Discord bot tokens are typically 70+ characters."
            continue
        fi

        if [ ${#bot_token} -gt 100 ]; then
            log_error "Token seems too long (${#bot_token} chars). Discord bot tokens are typically 70-72 characters."
            log_error "Make sure you're copying ONLY the token, not the page content."
            continue
        fi

        # Test token by making API call
        local response=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: Bot $bot_token" \
            "$DISCORD_API_BASE/users/@me")

        if [ "$response" = "200" ]; then
            log_success "Token validated"
            echo "$bot_token"
            return 0
        elif [ "$response" = "401" ]; then
            log_error "Invalid token. Please check and try again."
        else
            log_error "Could not validate token (HTTP $response). Check your internet connection."
        fi
    done
}

#
# get_server_id <bot_token>
#
# Prompts user for Discord server ID and validates bot is in that server.
# Returns: server ID via stdout
#
get_server_id() {
    local bot_token=$1

    # Get bot client ID to generate invite URL
    local bot_info=$(curl -s -H "Authorization: Bot $bot_token" \
        "$DISCORD_API_BASE/users/@me")
    local bot_client_id=$(echo "$bot_info" | jq -r '.id')
    local bot_invite_url="https://discord.com/oauth2/authorize?client_id=${bot_client_id}&permissions=536870912&scope=bot"

    echo "" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "${BLUE}Step 2: Create Discord Server${NC}" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo "" >&2
    echo "Please create a Discord server for StarForge:" >&2
    echo "" >&2
    echo "  1. Open Discord" >&2
    echo "  2. Click '+' (Create Server)" >&2
    echo "  3. Choose 'Create My Own'" >&2
    echo "  4. Name it: 'StarForge - $(basename "$PWD")'" >&2
    echo "" >&2

    read -p "Press Enter when you've created the server..." >&2

    echo "" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "${BLUE}Step 3: Invite Bot to Server${NC}" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo "" >&2
    echo "Now invite the StarForge bot to your server:" >&2
    echo "" >&2
    echo -e "  1. Click this link: ${CYAN}${bot_invite_url}${NC}" >&2
    echo "  2. Select your newly created server" >&2
    echo "  3. Click 'Authorize'" >&2
    echo "" >&2

    read -p "Press Enter when you've invited the bot..." >&2

    echo "" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "${BLUE}Step 4: Get Server ID${NC}" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo "" >&2
    echo "To get your server ID:" >&2
    echo "  1. Right-click your server icon" >&2
    echo "  2. Click 'Copy Server ID'" >&2
    echo "  3. Paste it below" >&2
    echo "" >&2
    echo -e "${YELLOW}Note: You need 'Developer Mode' enabled in Discord settings.${NC}" >&2
    echo "" >&2

    local server_id=""
    while true; do
        read -p "Paste your server ID: " server_id

        if [ -z "$server_id" ]; then
            log_error "Server ID cannot be empty"
            continue
        fi

        # Validate format: should be 17-20 digit number
        if ! [[ "$server_id" =~ ^[0-9]{17,20}$ ]]; then
            log_error "Invalid server ID format. Should be 17-20 digits."
            continue
        fi

        # Verify bot is in server
        log_info "Verifying bot is in server..."
        if verify_bot_in_server "$server_id" "$bot_token"; then
            log_success "Bot detected in server!"
            echo "$server_id"
            return 0
        else
            log_error "Bot not found in that server. Please check:"
            echo "  - Is the server ID correct?" >&2
            echo "  - Did you invite the bot using the link above?" >&2
            echo "  - Did you authorize the bot?" >&2
        fi
    done
}

#
# verify_bot_in_server <server_id> <bot_token>
#
# Checks if bot has successfully joined the specified server.
# Returns: 0 if bot is in server, 1 otherwise
#
verify_bot_in_server() {
    local server_id=$1
    local bot_token=$2

    local response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bot $bot_token" \
        "$DISCORD_API_BASE/guilds/$server_id")

    local http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "200" ]; then
        return 0
    else
        return 1
    fi
}

#
# create_channels <server_id> <bot_token>
#
# Creates 8 text channels for StarForge agents.
# Populates CHANNEL_IDS associative array.
# Returns: 0 on success, 1 on failure
#
create_channels() {
    local server_id=$1
    local bot_token=$2

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Step 5: Creating Channels${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    for channel_name in "${CHANNEL_NAMES[@]}"; do
        log_info "Creating #${channel_name}..."

        local payload=$(cat <<EOF
{
  "name": "${channel_name}",
  "type": 0,
  "topic": "StarForge ${channel_name} agent notifications"
}
EOF
)

        local response=$(curl -s -w "\n%{http_code}" \
            -X POST \
            -H "Authorization: Bot $bot_token" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "$DISCORD_API_BASE/guilds/$server_id/channels")

        local http_code=$(echo "$response" | tail -n1)
        local body=$(echo "$response" | sed '$d')

        if [ "$http_code" = "201" ] || [ "$http_code" = "200" ]; then
            local channel_id=$(echo "$body" | jq -r '.id')
            CHANNEL_IDS["$channel_name"]="$channel_id"
            log_success "#${channel_name} created"
        else
            log_error "Failed to create #${channel_name} (HTTP $http_code)"
            echo "$body" | jq -r '.message // "Unknown error"' >&2
            return 1
        fi

        # Rate limiting: wait 500ms between channel creations
        sleep 0.5
    done

    echo ""
    log_success "All channels created"
    return 0
}

#
# create_webhooks <bot_token>
#
# Creates webhooks for each channel created.
# Populates WEBHOOK_URLS associative array.
# Returns: 0 on success, 1 on failure
#
create_webhooks() {
    local bot_token=$1

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Step 6: Creating Webhooks${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    for channel_name in "${CHANNEL_NAMES[@]}"; do
        local channel_id="${CHANNEL_IDS[$channel_name]}"

        if [ -z "$channel_id" ]; then
            log_error "No channel ID for $channel_name"
            return 1
        fi

        log_info "Creating webhook for #${channel_name}..."

        local payload=$(cat <<EOF
{
  "name": "StarForge ${channel_name}"
}
EOF
)

        local response=$(curl -s -w "\n%{http_code}" \
            -X POST \
            -H "Authorization: Bot $bot_token" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "$DISCORD_API_BASE/channels/$channel_id/webhooks")

        local http_code=$(echo "$response" | tail -n1)
        local body=$(echo "$response" | sed '$d')

        if [ "$http_code" = "200" ]; then
            local webhook_id=$(echo "$body" | jq -r '.id')
            local webhook_token=$(echo "$body" | jq -r '.token')
            local webhook_url="https://discord.com/api/webhooks/${webhook_id}/${webhook_token}"
            WEBHOOK_URLS["$channel_name"]="$webhook_url"
            log_success "Webhook created for #${channel_name}"
        else
            log_error "Failed to create webhook for #${channel_name} (HTTP $http_code)"
            echo "$body" | jq -r '.message // "Unknown error"' >&2
            return 1
        fi

        # Rate limiting: wait 500ms between webhook creations
        sleep 0.5
    done

    echo ""
    log_success "All webhooks created"
    return 0
}

#
# generate_env_file
#
# Writes webhook URLs to .env file in project root.
# Backs up existing .env if present.
# Returns: 0 on success
#
generate_env_file() {
    local env_file=".env"

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Step 7: Creating .env File${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Backup existing .env
    if [ -f "$env_file" ]; then
        local backup_file="${env_file}.backup.$(date +%s)"
        log_info "Backing up existing .env to $backup_file"
        cp "$env_file" "$backup_file"
    fi

    # Write webhook URLs
    log_info "Writing webhook URLs to .env..."

    cat > "$env_file" << EOF
# StarForge Discord Webhook URLs
# Generated: $(date)
#
# DO NOT COMMIT THIS FILE TO GIT!
# These URLs are secrets that allow posting to your Discord channels.

EOF

    # Write each webhook URL
    for channel_name in "${CHANNEL_NAMES[@]}"; do
        local webhook_url="${WEBHOOK_URLS[$channel_name]}"
        local env_var_name="DISCORD_WEBHOOK_$(echo "$channel_name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"
        echo "${env_var_name}=\"${webhook_url}\"" >> "$env_file"
    done

    log_success ".env file created"

    # Ensure .env is in .gitignore
    if [ ! -f ".gitignore" ] || ! grep -q "^\.env$" ".gitignore" 2>/dev/null; then
        echo ".env" >> .gitignore
        log_success ".env added to .gitignore"
    fi

    return 0
}

#
# test_webhooks
#
# Sends test message to each webhook to verify they work.
# Returns: 0 if all tests pass, 1 if any fail
#
test_webhooks() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Step 8: Testing Webhooks${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local all_passed=true

    for channel_name in "${CHANNEL_NAMES[@]}"; do
        local webhook_url="${WEBHOOK_URLS[$channel_name]}"

        log_info "Testing #${channel_name}..."

        local payload=$(cat <<EOF
{
  "content": "✅ StarForge connected! This channel will receive notifications from the **${channel_name}** agent.",
  "username": "StarForge Setup"
}
EOF
)

        local http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "$webhook_url")

        if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
            log_success "#${channel_name} webhook working"
        else
            log_error "#${channel_name} webhook failed (HTTP $http_code)"
            all_passed=false
        fi

        # Rate limiting: wait 1 second between test messages
        sleep 1
    done

    echo ""
    if [ "$all_passed" = true ]; then
        log_success "All webhooks tested successfully"
        return 0
    else
        log_warn "Some webhooks failed. Check the errors above."
        return 1
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Function
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}      🎮 StarForge Discord Setup${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "This wizard will set up Discord notifications for StarForge."
    echo ""
    echo "What this does:"
    echo "  • Creates 8 channels in your Discord server"
    echo "  • Creates webhooks for agent notifications"
    echo "  • Saves configuration to .env file"
    echo ""
    echo "What you need:"
    echo "  • Discord account"
    echo "  • Discord bot token (we'll guide you)"
    echo "  • ~2 minutes"
    echo ""

    read -p "Ready to start? (y/n) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi

    # Step 1: Get bot token
    local bot_token=$(get_bot_token)
    if [ $? -ne 0 ]; then
        log_error "Failed to get bot token"
        exit 1
    fi

    # Step 2-4: Get server ID (includes server creation and bot invite)
    local server_id=$(get_server_id "$bot_token")
    if [ $? -ne 0 ]; then
        log_error "Failed to get server ID"
        exit 1
    fi

    # Step 5: Create channels
    if ! create_channels "$server_id" "$bot_token"; then
        log_error "Failed to create channels"
        exit 1
    fi

    # Step 6: Create webhooks
    if ! create_webhooks "$bot_token"; then
        log_error "Failed to create webhooks"
        exit 1
    fi

    # Step 7: Generate .env file
    if ! generate_env_file; then
        log_error "Failed to generate .env file"
        exit 1
    fi

    # Step 8: Test webhooks
    if ! test_webhooks; then
        log_warn "Some tests failed, but setup is complete"
        log_warn "Check Discord to see which channels received test messages"
    fi

    # Success summary
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}      🎉 Setup Complete!${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log_success "Discord server configured"
    log_success "8 channels created"
    log_success "8 webhooks created"
    log_success ".env file created"
    log_success "Test notifications sent"
    echo ""
    echo "Next steps:"
    echo "  • Check your Discord server for the test messages"
    echo "  • When agents work, they'll post updates to Discord"
    echo "  • Keep your .env file safe (never commit to git)"
    echo ""
    echo "Try it out:"
    echo -e "  ${CYAN}starforge use senior-engineer${NC}"
    echo ""
}

# Run main if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
