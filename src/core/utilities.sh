# Utility Functions - Logging, Prompts, Checks

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    WiFi Auto-PWN v${VERSION}                        ║"
    echo "║          Automated WiFi Penetration Testing Tool            ║"
    echo "║    PMKID + Handshake + WPS + Evil Twin | GPU Accelerated    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${BLUE}[*]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

legal_warning() {
    echo ""
    log_warning "═══════════════════════════════════════════════"
    log_warning "         LEGAL AND ETHICAL WARNING"
    log_warning "═══════════════════════════════════════════════"
    echo ""
    echo "This tool is intended for:"
    echo "  • Authorized penetration testing"
    echo "  • Educational purposes on your own networks"
    echo "  • Security research with proper authorization"
    echo ""
    echo "Unauthorized access to networks is ILLEGAL and may"
    echo "result in criminal prosecution."
    echo ""
    read -p "Do you have authorization to test this network? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_error "Authorization not confirmed. Exiting."
        exit 1
    fi
    echo ""
}

cleanup_and_exit() {
    echo ""
    log_info "Cleaning up..."
    
    # Kill any remaining processes
    pkill airodump-ng 2>/dev/null || true
    pkill aireplay-ng 2>/dev/null || true
    pkill hcxdumptool 2>/dev/null || true
    pkill reaver 2>/dev/null || true
    pkill bully 2>/dev/null || true
    pkill hostapd 2>/dev/null || true
    pkill dnsmasq 2>/dev/null || true
    
    # Disable monitor mode
    disable_monitor_mode
    
    # Restore MAC if randomized
    restore_mac_address
    
    log_success "Cleanup complete"
    exit 0
}

# Trap Ctrl+C
trap cleanup_and_exit SIGINT SIGTERM
