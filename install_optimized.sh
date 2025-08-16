#!/bin/bash

#=============================================================================
# WebHackingTools Optimized v4.0 Enhanced
# High-performance, reliable security tools installer
#=============================================================================

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
LOGS_DIR="${SCRIPT_DIR}/logs"

# Colors
declare -r RED='\033[00;31m'
declare -r GREEN='\033[00;32m'
declare -r YELLOW='\033[00;33m'
declare -r BLUE='\033[00;34m'
declare -r PURPLE='\033[00;35m'
declare -r CYAN='\033[00;36m'
declare -r WHITE='\033[01;37m'
declare -r RESTORE='\033[0m'

# Progress tracking
declare -i INSTALLED_COUNT=0
declare -i FAILED_COUNT=0
declare -i SKIPPED_COUNT=0
declare -a INSTALLED_TOOLS=()
declare -a FAILED_TOOLS=()
declare -a SKIPPED_TOOLS=()

# Load configuration
load_config() {
    local defaults_file="${CONFIG_DIR}/.env.defaults"
    
    if [[ -f "$defaults_file" ]]; then
        source "$defaults_file"
    fi
    
    # Set defaults
    : ${TOOLS_DIRECTORY:="/opt/security-tools"}
    : ${LOG_DIR:="${LOGS_DIR}"}
    : ${PARALLEL_JOBS:=4}
    : ${MAX_RETRIES:=3}
    : ${SKIP_INSTALLED:=true}
    
    mkdir -p "$TOOLS_DIRECTORY" "$LOG_DIR"
    LOG_FILE="${LOG_DIR}/install_$(date +%Y%m%d_%H%M%S).log"
    touch "$LOG_FILE"
}

# Logging
log() {
    local level="$1"
    shift
    local message="$*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        ERROR) echo -e "${RED}[ERROR]${RESTORE} $message" >&2 ;;
        WARN) echo -e "${YELLOW}[WARN]${RESTORE} $message" ;;
        SUCCESS) echo -e "${GREEN}[✓]${RESTORE} $message" ;;
        *) echo -e "${CYAN}[INFO]${RESTORE} $message" ;;
    esac
}

# Show banner
show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${RESTORE}"
    echo -e "${CYAN}║        WebHackingTools Optimized v4.0 Enhanced - Fast Installer     ║${RESTORE}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESTORE}"
    echo -e "\nLog file: ${LOG_FILE}"
    echo -e "Tools directory: ${TOOLS_DIRECTORY}\n"
}

# Check requirements
check_requirements() {
    log "INFO" "Checking system requirements..."
    
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "This script must be run as root"
        exit 1
    fi
    
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        log "ERROR" "No internet connectivity"
        exit 1
    fi
    
    log "SUCCESS" "System check passed"
}

# Check if installed
is_installed() {
    local tool="$1"
    if command -v "$tool" &>/dev/null; then
        return 0
    fi
    # Also check in common paths
    if [[ -f "/usr/local/bin/$tool" ]] || [[ -f "$HOME/go/bin/$tool" ]] || [[ -f "$TOOLS_DIRECTORY/$tool/$tool" ]]; then
        return 0
    fi
    return 1
}

# Install tool - modified to continue on error
install_tool() {
    local tool_name="$1"
    local install_cmd="$2"
    local fallback_cmd="${3:-}"
    
    if [[ "$SKIP_INSTALLED" == "true" ]] && is_installed "$tool_name"; then
        log "INFO" "$tool_name already installed"
        SKIPPED_TOOLS+=("$tool_name")
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        return 0
    fi
    
    log "INFO" "Installing $tool_name..."
    
    # Try main installation command
    if eval "$install_cmd" >> "$LOG_FILE" 2>&1; then
        log "SUCCESS" "$tool_name installed"
        INSTALLED_TOOLS+=("$tool_name")
        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        return 0
    elif [[ -n "$fallback_cmd" ]]; then
        # Try fallback command
        if eval "$fallback_cmd" >> "$LOG_FILE" 2>&1; then
            log "SUCCESS" "$tool_name installed (fallback)"
            INSTALLED_TOOLS+=("$tool_name")
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
            return 0
        fi
    fi
    
    log "ERROR" "Failed to install $tool_name"
    FAILED_TOOLS+=("$tool_name")
    FAILED_COUNT=$((FAILED_COUNT + 1))
    return 1 || true  # Continue even on failure
}

# Install dependencies
install_dependencies() {
    log "INFO" "Installing system dependencies..."
    
    apt-get update -y >> "$LOG_FILE" 2>&1 || true
    
    local packages=("curl" "wget" "git" "build-essential" "python3" "python3-pip" "jq" "ruby" "ruby-dev" "libssl-dev" "libffi-dev" "python3-dev" "libxml2-dev" "libxslt1-dev" "zlib1g-dev" "libpcap-dev" "libgmp-dev" "unzip")
    
    for pkg in "${packages[@]}"; do
        install_tool "$pkg" "apt-get install -y $pkg" || true
    done
    
    # Install Go
    if ! is_installed "go"; then
        install_tool "golang" \
            "cd /tmp && wget -q https://dl.google.com/go/go1.21.7.linux-amd64.tar.gz && tar -C /usr/local -xzf go1.21.7.linux-amd64.tar.gz && ln -sf /usr/local/go/bin/go /usr/local/bin/go" || true
    fi
    
    # Install Rust
    if ! is_installed "cargo"; then
        install_tool "rust" \
            "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && source $HOME/.cargo/env" || true
    fi
    
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.cargo/bin
    export GOPATH=$HOME/go
    mkdir -p $HOME/go/bin
}

# Install subdomain enumeration tools
install_subdomain_tools() {
    log "INFO" "Installing subdomain enumeration tools..."
    
    install_tool "subfinder" \
        "go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest && ln -sf $HOME/go/bin/subfinder /usr/local/bin/" || true
    
    install_tool "assetfinder" \
        "go install -v github.com/tomnomnom/assetfinder@latest && ln -sf $HOME/go/bin/assetfinder /usr/local/bin/" || true
    
    install_tool "findomain" \
        "cd /tmp && wget -q https://github.com/findomain/findomain/releases/latest/download/findomain-linux.zip && unzip -q findomain-linux.zip && mv findomain /usr/local/bin/ && chmod +x /usr/local/bin/findomain" || true
    
    install_tool "github-subdomains" \
        "go install -v github.com/gwen001/github-subdomains@latest && ln -sf $HOME/go/bin/github-subdomains /usr/local/bin/" || true
    
    install_tool "amass" \
        "go install -v github.com/owasp-amass/amass/v4/...@latest && ln -sf $HOME/go/bin/amass /usr/local/bin/" || true
    
    install_tool "crobat" \
        "go install -v github.com/cgboal/sonarsearch/cmd/crobat@latest && ln -sf $HOME/go/bin/crobat /usr/local/bin/" || true
}

# Install DNS tools
install_dns_tools() {
    log "INFO" "Installing DNS resolution tools..."
    
    install_tool "massdns" \
        "cd /tmp && git clone https://github.com/blechschmidt/massdns.git && cd massdns && make && cp bin/massdns /usr/local/bin/" || true
    
    install_tool "puredns" \
        "go install -v github.com/d3mondev/puredns/v2@latest && ln -sf $HOME/go/bin/puredns /usr/local/bin/" || true
}

# Install screenshot tools
install_screenshot_tools() {
    log "INFO" "Installing screenshot and visual recon tools..."
    
    install_tool "aquatone" \
        "cd /tmp && wget -q https://github.com/michenriksen/aquatone/releases/download/v1.7.0/aquatone_linux_amd64_1.7.0.zip && unzip -q aquatone_linux_amd64_1.7.0.zip && mv aquatone /usr/local/bin/ && chmod +x /usr/local/bin/aquatone" \
        "go install -v github.com/michenriksen/aquatone@latest && ln -sf $HOME/go/bin/aquatone /usr/local/bin/" || true
    
    install_tool "gowitness" \
        "go install -v github.com/sensepost/gowitness@latest && ln -sf $HOME/go/bin/gowitness /usr/local/bin/" || true
}

# Install HTTP probing tools
install_http_tools() {
    log "INFO" "Installing HTTP probing and analysis tools..."
    
    install_tool "httpx" \
        "go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest && ln -sf $HOME/go/bin/httpx /usr/local/bin/" || true
    
    install_tool "httprobe" \
        "go install -v github.com/tomnomnom/httprobe@latest && ln -sf $HOME/go/bin/httprobe /usr/local/bin/" || true
}

# Install web crawling tools
install_crawling_tools() {
    log "INFO" "Installing web crawling and spider tools..."
    
    install_tool "gospider" \
        "go install -v github.com/jaeles-project/gospider@latest && ln -sf $HOME/go/bin/gospider /usr/local/bin/" || true
    
    install_tool "hakrawler" \
        "go install -v github.com/hakluke/hakrawler@latest && ln -sf $HOME/go/bin/hakrawler /usr/local/bin/" || true
    
    install_tool "gau" \
        "go install -v github.com/lc/gau/v2/cmd/gau@latest && ln -sf $HOME/go/bin/gau /usr/local/bin/" || true
}

# Install scanning tools
install_scanning_tools() {
    log "INFO" "Installing port and service scanning tools..."
    
    install_tool "nmap" "apt-get install -y nmap" || true
    
    install_tool "masscan" "apt-get install -y masscan" || true
    
    install_tool "naabu" \
        "go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest && ln -sf $HOME/go/bin/naabu /usr/local/bin/" || true
}

# Install vulnerability scanning tools
install_vuln_tools() {
    log "INFO" "Installing vulnerability scanning tools..."
    
    install_tool "nuclei" \
        "go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest && ln -sf $HOME/go/bin/nuclei /usr/local/bin/" || true
    
    install_tool "jaeles" \
        "go install -v github.com/jaeles-project/jaeles@latest && ln -sf $HOME/go/bin/jaeles /usr/local/bin/" || true
    
    install_tool "Corsy" \
        "cd $TOOLS_DIRECTORY && rm -rf Corsy && git clone https://github.com/s0md3v/Corsy.git && cd Corsy && pip3 install requests" || true
    
    install_tool "SSRFmap" \
        "cd $TOOLS_DIRECTORY && rm -rf SSRFmap && git clone https://github.com/swisskyrepo/SSRFmap.git && cd SSRFmap && pip3 install -r requirements.txt" || true
    
    install_tool "Gopherus" \
        "cd $TOOLS_DIRECTORY && rm -rf Gopherus && git clone https://github.com/tarunkant/Gopherus.git && chmod +x Gopherus/gopherus.py" || true
    
    install_tool "NoSQLMap" \
        "pip3 install nosqlmap" \
        "cd $TOOLS_DIRECTORY && rm -rf NoSQLMap && git clone https://github.com/codingo/NoSQLMap.git" || true
}

# Install fuzzing tools
install_fuzzing_tools() {
    log "INFO" "Installing fuzzing and brute-forcing tools..."
    
    install_tool "ffuf" \
        "go install -v github.com/ffuf/ffuf/v2@latest && ln -sf $HOME/go/bin/ffuf /usr/local/bin/" || true
    
    install_tool "arjun" \
        "pip3 install arjun" || true
    
    install_tool "kiterunner" \
        "cd /tmp && wget -q https://github.com/assetnote/kiterunner/releases/download/v1.0.2/kiterunner_1.0.2_linux_amd64.tar.gz && tar xzf kiterunner_1.0.2_linux_amd64.tar.gz && mv kr /usr/local/bin/kiterunner && chmod +x /usr/local/bin/kiterunner" \
        "go install -v github.com/assetnote/kiterunner/cmd/kr@latest && ln -sf $HOME/go/bin/kr /usr/local/bin/kiterunner" || true
    
    install_tool "dirsearch" \
        "cd $TOOLS_DIRECTORY && rm -rf dirsearch && git clone https://github.com/maurosoria/dirsearch.git && cd dirsearch && pip3 install -r requirements.txt && ln -sf $TOOLS_DIRECTORY/dirsearch/dirsearch.py /usr/local/bin/dirsearch && chmod +x /usr/local/bin/dirsearch" || true
}

# Install JavaScript analysis tools
install_js_tools() {
    log "INFO" "Installing JavaScript analysis tools..."
    
    install_tool "LinkFinder" \
        "cd $TOOLS_DIRECTORY && rm -rf LinkFinder && git clone https://github.com/GerbenJavado/LinkFinder.git && cd LinkFinder && pip3 install -r requirements.txt" || true
    
    install_tool "SecretFinder" \
        "cd $TOOLS_DIRECTORY && rm -rf SecretFinder && git clone https://github.com/m4ll0k/SecretFinder.git && cd SecretFinder && pip3 install -r requirements.txt" || true
}

# Install CMS scanning tools
install_cms_tools() {
    log "INFO" "Installing CMS scanning tools..."
    
    install_tool "wpscan" \
        "gem install wpscan" || true
    
    install_tool "droopescan" \
        "pip3 install droopescan" || true
}

# Install bypass tools
install_bypass_tools() {
    log "INFO" "Installing bypass and evasion tools..."
    
    install_tool "bypass-403" \
        "cd $TOOLS_DIRECTORY && rm -rf bypass-403 && git clone https://github.com/iamj0ker/bypass-403.git && chmod +x bypass-403/bypass-403.sh && ln -sf $TOOLS_DIRECTORY/bypass-403/bypass-403.sh /usr/local/bin/bypass-403" || true
    
    install_tool "bruteforce-lfi" \
        "cd $TOOLS_DIRECTORY && rm -rf bruteforce-lfi && git clone https://github.com/n4xh4ck5/bruteforce-lfi.git" || true
}

# Install utility tools
install_utility_tools() {
    log "INFO" "Installing utility tools..."
    
    install_tool "anew" \
        "go install -v github.com/tomnomnom/anew@latest && ln -sf $HOME/go/bin/anew /usr/local/bin/" || true
    
    install_tool "unfurl" \
        "go install -v github.com/tomnomnom/unfurl@latest && ln -sf $HOME/go/bin/unfurl /usr/local/bin/" || true
    
    install_tool "qsreplace" \
        "go install -v github.com/tomnomnom/qsreplace@latest && ln -sf $HOME/go/bin/qsreplace /usr/local/bin/" || true
    
    install_tool "interlace" \
        "pip3 install interlace" \
        "cd $TOOLS_DIRECTORY && rm -rf Interlace && git clone https://github.com/codingo/Interlace.git && cd Interlace && python3 setup.py install" || true
    
    install_tool "tmux" "apt-get install -y tmux" || true
    
    install_tool "ripgrep" "apt-get install -y ripgrep" || true
    
    install_tool "subzy" \
        "go install -v github.com/PentestPad/subzy@latest && ln -sf $HOME/go/bin/subzy /usr/local/bin/" || true
}

# Show summary
show_summary() {
    echo -e "\n${PURPLE}═══════════════════════════════════════════════════════════${RESTORE}"
    echo -e "${WHITE}Installation Summary${RESTORE}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════${RESTORE}\n"
    
    echo -e "${GREEN}Successfully Installed:${RESTORE} $INSTALLED_COUNT"
    if [[ ${#INSTALLED_TOOLS[@]} -gt 0 ]]; then
        for tool in "${INSTALLED_TOOLS[@]}"; do
            echo -e "  ${GREEN}✓${RESTORE} $tool"
        done
    fi
    
    if [[ $SKIPPED_COUNT -gt 0 ]]; then
        echo -e "\n${YELLOW}Skipped (already installed):${RESTORE} $SKIPPED_COUNT"
        if [[ ${#SKIPPED_TOOLS[@]} -gt 0 ]]; then
            for tool in "${SKIPPED_TOOLS[@]}"; do
                echo -e "  ${YELLOW}○${RESTORE} $tool"
            done
        fi
    fi
    
    if [[ $FAILED_COUNT -gt 0 ]]; then
        echo -e "\n${RED}Failed:${RESTORE} $FAILED_COUNT"
        if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
            for tool in "${FAILED_TOOLS[@]}"; do
                echo -e "  ${RED}✗${RESTORE} $tool"
            done
        fi
    fi
    
    local total=$((INSTALLED_COUNT + SKIPPED_COUNT + FAILED_COUNT))
    if [[ $total -gt 0 ]]; then
        echo -e "\n${CYAN}Total Tools Processed: $total${RESTORE}"
        echo -e "${CYAN}Success Rate: $(( (INSTALLED_COUNT + SKIPPED_COUNT) * 100 / total ))%${RESTORE}"
    fi
    echo -e "\n${CYAN}Installation Log: $LOG_FILE${RESTORE}"
    echo -e "${CYAN}Tools Directory: $TOOLS_DIRECTORY${RESTORE}\n"
}

# Cleanup
cleanup() {
    apt-get clean &>/dev/null || true
    rm -f /tmp/*.{tar.gz,zip} 2>/dev/null || true
    rm -rf /tmp/{massdns,findomain*,aquatone*,kiterunner*} 2>/dev/null || true
}

trap cleanup EXIT

# Main
main() {
    load_config
    show_banner
    check_requirements
    
    log "INFO" "Starting enhanced installation with error handling..."
    
    # Install base dependencies
    install_dependencies
    
    # Install tools by category - continue even if category fails
    install_subdomain_tools || true
    install_dns_tools || true
    install_screenshot_tools || true
    install_http_tools || true
    install_crawling_tools || true
    install_scanning_tools || true
    install_vuln_tools || true
    install_fuzzing_tools || true
    install_js_tools || true
    install_cms_tools || true
    install_bypass_tools || true
    install_utility_tools || true
    
    show_summary
    
    log "INFO" "Installation process completed!"
}

main "$@"
