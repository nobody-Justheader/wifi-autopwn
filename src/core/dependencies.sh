# Dependency Checking and Tool Verification

check_dependencies() {
    log_info "Checking required tools..."
    
    local tools=("airmon-ng" "airodump-ng" "aireplay-ng" "aircrack-ng")
    local missing=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        log_info "Install with: sudo apt install aircrack-ng"
        exit 1
    fi
    
    log_success "All required tools found"
    
    # Check for optional advanced tools
    local optional_tools=("hcxdumptool" "hcxpcapngtool" "hashcat" "reaver" "bully" "macchanger" "hostapd" "dnsmasq")
    local missing_optional=()
    
    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_optional+=("$tool")
        else
            # Enable features based on available tools
            case "$tool" in
                reaver|bully) FEATURE_WPS=true ;;
                macchanger) FEATURE_MAC_RANDOM=true ;;
                hostapd|dnsmasq) FEATURE_EVIL_TWIN=true ;;
            esac
        fi
    done
    
    if [ ${#missing_optional[@]} -gt 0 ]; then
        log_warning "Optional tools missing: ${missing_optional[*]}"
        log_info "For full features, install:"
        log_info "  sudo apt install hcxtools hashcat reaver macchanger hostapd dnsmasq"
        echo ""
    else
        log_success "All optional tools found - Full feature set available!"
    fi
    
    # Check for 5GHz support
    check_5ghz_support
}

check_5ghz_support() {
    if [ -n "$INTERFACE" ] && iw list 2>/dev/null | grep -A 10 "Band 2" | grep -q "5[0-9][0-9][0-9] MHz"; then
        FEATURE_5GHZ=true
        log_success "5GHz band support detected"
    fi
}

check_wordlist() {
    # If wordlist already specified via -w flag, verify it exists
    if [ -n "$WORDLIST" ]; then
        if [ ! -f "$WORDLIST" ]; then
            log_error "Specified wordlist not found: $WORDLIST"
            exit 1
        fi
        log_success "Using wordlist: $WORDLIST"
        return
    fi
    
    log_info "Auto-detecting wordlist..."
    
    # Priority order: WiFi-specific wordlists first, then general wordlists
    local wordlist_candidates=(
        "/usr/share/wordlists/wifite.txt"
        "/usr/share/seclists/Passwords/WiFi-WPA/probable-v2-wpa-top4800.txt"
        "/usr/share/wordlists/fasttrack.txt"
        "/usr/share/wordlists/rockyou.txt"
        "/usr/share/wordlists/rockyou.txt.gz"
    )
    
    for candidate in "${wordlist_candidates[@]}"; do
        if [ -f "$candidate" ]; then
            # Handle compressed rockyou
            if [[ "$candidate" == *.gz ]]; then
                local extracted="${candidate%.gz}"
                if [ -f "$extracted" ]; then
                    WORDLIST="$extracted"
                    log_success "Using wordlist: $WORDLIST"
                    return
                else
                    log_info "Found compressed wordlist, extracting..."
                    gunzip -k "$candidate" 2>/dev/null && {
                       WORDLIST="$extracted"
                        log_success "Using wordlist: $WORDLIST"
                        return
                    }
                fi
            else
                WORDLIST="$candidate"
                log_success "Using wordlist: $WORDLIST"
                return
            fi
        fi
    done
    
    # No wordlist found
    log_error "No wordlist found on system"
    echo ""
    log_info "Install wordlists with:"
    log_info "  sudo apt install wordlists   # Kali Linux"
    log_info "  sudo apt install seclists    # SecLists collection"
    echo ""
    log_info "Or download rockyou.txt manually:"
    log_info "  wget https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt"
    echo ""
    read -p "Enter path to custom wordlist (or press Enter to exit): " WORDLIST
    
    if [ -z "$WORDLIST" ]; then
        log_error "No wordlist provided. Exiting."
        exit 1
    fi
    
    if [ ! -f "$WORDLIST" ]; then
        log_error "Wordlist not found: $WORDLIST"
        exit 1
    fi
    
    log_success "Using wordlist: $WORDLIST"
}
