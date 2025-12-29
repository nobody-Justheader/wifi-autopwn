# Hashcat GPU-Accelerated Cracking Module
#
# References:
# - https://hashcat.net/hashcat/
# - https://hashcat.net/wiki/doku.php?id=mask_attack
# - Hash mode 22000: WPA-PBKDF2-PMKID+EAPOL (WPA/WPA2/WPA3)
# - Hash mode 22001: WPA-PMK-PMKID+EAPOL (precomputed PMK)

crack_hashcat() {
    if [ ! -f "$HASHCAT_HASH_FILE" ]; then
        log_error "Hashcat hash file not found"
        return 1
    fi
    
    if ! command -v hashcat &> /dev/null; then
        log_error "Hashcat not installed"
        log_info "Install with: sudo apt install hashcat"
        return 1
    fi
    
    log_info "Hashcat Attack Modes:"
    echo "  1) Dictionary attack (fast, wordlist-based)"
    echo "  2) Mask attack (bruteforce with patterns)"
    echo "  3) Hybrid (wordlist + mask)"
    echo "  4) Combinator (combine two wordlists)"
    echo ""
    
    read -p "Select attack mode [1]: " mode
    mode=${mode:-1}
    
    case $mode in
        1) hashcat_dictionary ;;
        2) hashcat_mask ;;
        3) hashcat_hybrid ;;
        4) hashcat_combinator ;;
        *) log_error "Invalid selection"; return 1 ;;
    esac
}

hashcat_dictionary() {
    log_info "Hashcat dictionary attack..."
    log_info "Using wordlist: $WORDLIST"
    
    hashcat -m 22000 "$HASHCAT_HASH_FILE" "$WORDLIST" -o "$OUTPUT_DIR/hashcat_cracked.txt" --force
    
    check_hashcat_results
}

hashcat_mask() {
    log_info "Hashcat mask attack (bruteforce with patterns)..."
    
    # Offer country-specific patterns
    echo ""
    echo "Use country-specific password pattern? (y/n)"
    read -p "[n]: " use_country
    
    local mask=""
    if [ "$use_country" = "y" ]; then
        mask=$(select_country_pattern)
    else
        read -p "Enter mask (e.g., ?l?l?l?l?d?d?d?d for aaaabbbb): " mask
    fi
    
    hashcat -m 22000 "$HASHCAT_HASH_FILE" -a 3 "$mask" -o "$OUTPUT_DIR/hashcat_cracked.txt" --force
    
    check_hashcat_results
}

hashcat_hybrid() {
    log_info "Hashcat hybrid attack (wordlist + mask)..."
    
    read -p "Enter mask suffix (e.g., ?d?d?d for 3 digits): " mask
    
    hashcat -m 22000 "$HASHCAT_HASH_FILE" -a 6 "$WORDLIST" "$mask" -o "$OUTPUT_DIR/hashcat_cracked.txt" --force
    
    check_hashcat_results
}

hashcat_combinator() {
    log_info "Hashcat combinator attack..."
    
    hashcat -m 22000 "$HASHCAT_HASH_FILE" -a 1 "$WORDLIST" "$WORDLIST" -o "$OUTPUT_DIR/hashcat_cracked.txt" --force
    
    check_hashcat_results
}

check_hashcat_results() {
    if [ -f "$OUTPUT_DIR/hashcat_cracked.txt" ] && [ -s "$OUTPUT_DIR/hashcat_cracked.txt" ]; then
        local password=$(tail -1 "$OUTPUT_DIR/hashcat_cracked.txt" | cut -d':' -f2-)
        
        log_success "═══════════════════════════════════════════"
        log_success "PASSWORD CRACKED (Hashcat GPU)!"
        log_success "  Network: $TARGET_ESSID"
        log_success "  Password: $password"
        log_success "═══════════════════════════════════════════"
        
        STATS_NETWORKS_CRACKED=$((STATS_NETWORKS_CRACKED + 1))
        return 0
    else
        log_error "Password not cracked"
        return 1
    fi
}
