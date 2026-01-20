#!/bin/bash
set -e

# ============================================
# ZEDCONFIG MASTER SETUP SCRIPT
# ============================================
# This script guides you through the complete setup process
# for a new device, with prompts at each stage.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# HELPER FUNCTIONS
# ============================================
print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}! $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

prompt_continue() {
    local message="${1:-Press Enter to continue...}"
    echo ""
    echo -e "${YELLOW}$message${NC}"
    read -r
}

prompt_yes_no() {
    local message="$1"
    local default="${2:-y}"

    if [[ "$default" == "y" ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    echo -e -n "${YELLOW}$message $prompt: ${NC}"
    read -r response

    if [[ -z "$response" ]]; then
        response="$default"
    fi

    [[ "$response" =~ ^[Yy]$ ]]
}

# ============================================
# ENVIRONMENT DETECTION
# ============================================
detect_environment() {
    IS_WSL=false
    IS_LINUX=false
    IS_MACOS=false

    if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null; then
        IS_WSL=true
        IS_LINUX=true
        ENV_NAME="WSL (Windows Subsystem for Linux)"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        IS_LINUX=true
        ENV_NAME="Native Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        IS_MACOS=true
        ENV_NAME="macOS"
    else
        ENV_NAME="Unknown ($OSTYPE)"
    fi
}

# ============================================
# MAIN SETUP FLOW
# ============================================
main() {
    clear
    print_header "ZEDCONFIG SETUP WIZARD"

    detect_environment
    echo "Detected Environment: $ENV_NAME"
    echo ""
    echo "This wizard will guide you through:"
    echo "  1. SSH key setup (for GitHub multi-account)"
    echo "  2. Adding SSH keys to GitHub"
    echo "  3. Installing development dependencies"
    echo "  4. Symlinking configuration files"
    echo "  5. GitHub CLI authentication"
    echo "  6. Verification"
    echo ""

    if [[ "$IS_WSL" == true ]]; then
        echo -e "${YELLOW}WSL Detected:${NC} This setup configures your Linux environment."
        echo "Zed will run on Windows but use this WSL environment for terminal."
        echo ""
    fi

    prompt_continue "Press Enter to begin setup..."

    # ==========================================
    # STEP 1: SSH SETUP
    # ==========================================
    print_header "STEP 1: SSH KEY SETUP"

    if [ -f ~/.ssh/id_ed25519_personal ] && [ -f ~/.ssh/id_ed25519_syntek ] && [ -f ~/.ssh/id_ed25519_mg ]; then
        print_success "SSH keys already exist"
        if prompt_yes_no "Skip SSH setup?" "y"; then
            echo "Skipping SSH setup..."
        else
            bash "$SCRIPT_DIR/ssh-setup.sh"
            prompt_continue "Press Enter after you've added the SSH keys to GitHub..."
        fi
    else
        echo "SSH keys need to be created for GitHub multi-account access."
        echo ""
        if prompt_yes_no "Run SSH setup now?" "y"; then
            bash "$SCRIPT_DIR/ssh-setup.sh"

            print_header "ACTION REQUIRED: Add SSH Keys to GitHub"
            echo "The public keys were displayed above."
            echo ""
            echo "For each GitHub account, you need to:"
            echo "  1. Log in to GitHub with that account"
            echo "  2. Go to Settings > SSH and GPG keys"
            echo "  3. Click 'New SSH key'"
            echo "  4. Paste the corresponding public key"
            echo ""
            echo "Accounts to configure:"
            echo "  • github-personal  → SamBailey6194"
            echo "  • github-syntek    → syntek-studio"
            echo "  • github-missionalgen → sam-missionalgen"
            echo ""

            prompt_continue "Press Enter after you've added ALL SSH keys to GitHub..."
        else
            print_warning "Skipping SSH setup. You'll need to set this up manually."
        fi
    fi

    # ==========================================
    # STEP 2: TEST SSH CONNECTIONS
    # ==========================================
    print_header "STEP 2: TEST SSH CONNECTIONS"

    echo "Testing SSH connections to GitHub..."
    echo ""

    echo "Testing github-personal..."
    if ssh -T git@github-personal 2>&1 | grep -q "successfully authenticated"; then
        print_success "github-personal connected"
    else
        ssh -T git@github-personal 2>&1 || true
    fi
    echo ""

    echo "Testing github-syntek..."
    if ssh -T git@github-syntek 2>&1 | grep -q "successfully authenticated"; then
        print_success "github-syntek connected"
    else
        ssh -T git@github-syntek 2>&1 || true
    fi
    echo ""

    echo "Testing github-missionalgen..."
    if ssh -T git@github-missionalgen 2>&1 | grep -q "successfully authenticated"; then
        print_success "github-missionalgen connected"
    else
        ssh -T git@github-missionalgen 2>&1 || true
    fi
    echo ""

    prompt_continue "Press Enter to continue (SSH errors above are okay if you see 'successfully authenticated')..."

    # ==========================================
    # STEP 3: INSTALL DEPENDENCIES
    # ==========================================
    print_header "STEP 3: INSTALL DEPENDENCIES"

    echo "This will install:"
    echo "  • System tools (git, curl, zsh, ripgrep, fd, bat, jq, entr)"
    echo "  • Oh My Zsh"
    echo "  • Node.js (via nvm) + npm packages (prettier, eslint, typescript)"
    echo "  • Python tools (ruff, basedpyright, pip-audit)"
    echo "  • Rust tools (clippy, rustfmt, rust-analyzer, just)"
    echo "  • GitHub CLI"
    echo ""

    if prompt_yes_no "Install dependencies now?" "y"; then
        bash "$SCRIPT_DIR/install.sh" --deps
        print_success "Dependencies installed"
    else
        print_warning "Skipping dependencies. Run './install.sh --deps' later."
    fi

    prompt_continue

    # ==========================================
    # STEP 4: SYMLINK CONFIGS
    # ==========================================
    print_header "STEP 4: SYMLINK CONFIGURATIONS"

    echo "This will symlink:"
    echo "  • Zed settings, keymap, and debug configs"
    echo "  • Git config (multi-account setup)"
    echo "  • Linter configs (prettier, eslint, ruff, pyright, etc.)"
    echo "  • Justfile"
    echo ""

    if prompt_yes_no "Symlink configurations now?" "y"; then
        bash "$SCRIPT_DIR/install.sh"
        print_success "Configurations symlinked"
    else
        print_warning "Skipping symlinks. Run './install.sh' later."
    fi

    prompt_continue

    # ==========================================
    # STEP 5: GITHUB CLI AUTH
    # ==========================================
    print_header "STEP 5: GITHUB CLI AUTHENTICATION"

    if command -v gh &>/dev/null; then
        if gh auth status &>/dev/null 2>&1; then
            print_success "GitHub CLI already authenticated"
        else
            echo "GitHub CLI needs to be authenticated."
            echo "This allows you to use 'gh' commands for PRs, issues, etc."
            echo ""

            if prompt_yes_no "Authenticate GitHub CLI now?" "y"; then
                echo ""
                echo "You'll be prompted to:"
                echo "  1. Choose GitHub.com"
                echo "  2. Choose SSH as preferred protocol"
                echo "  3. Authenticate via browser"
                echo ""
                gh auth login
                print_success "GitHub CLI authenticated"
            else
                print_warning "Skipping gh auth. Run 'gh auth login' later."
            fi
        fi
    else
        print_warning "GitHub CLI not installed. Run './install.sh --deps' first."
    fi

    prompt_continue

    # ==========================================
    # STEP 6: VERIFICATION
    # ==========================================
    print_header "STEP 6: VERIFICATION"

    echo "Running verification script to check everything is set up correctly..."
    echo ""

    bash "$SCRIPT_DIR/verify-setup.sh"

    # ==========================================
    # COMPLETE
    # ==========================================
    print_header "SETUP COMPLETE!"

    echo "Your development environment is ready."
    echo ""
    echo "Quick reference:"
    echo "  • Clone personal repos:      git clone git@github-personal:USER/repo.git ~/Repos/personal/repo"
    echo "  • Clone syntek repos:        git clone git@github-syntek:USER/repo.git ~/Repos/syntek/repo"
    echo "  • Clone missional-gen repos: git clone git@github-missionalgen:USER/repo.git ~/Repos/missional-gen/repo"
    echo ""
    echo "  • Re-run dependency install: ./install.sh --deps"
    echo "  • Re-run config symlinks:    ./install.sh"
    echo "  • Re-run verification:       ./verify-setup.sh"
    echo ""

    if [[ "$IS_WSL" == true ]]; then
        echo -e "${YELLOW}WSL Reminder:${NC}"
        echo "  Configure Zed on Windows to use WSL terminal:"
        echo '  "terminal": { "shell": { "program": "wsl.exe", "args": ["-d", "Ubuntu"] } }'
        echo ""
    fi

    echo "Happy coding!"
    echo ""
}

# Run main function
main "$@"
