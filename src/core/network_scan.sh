# Network Scanning and Target Selection Functions

scan_networks() {
    log_info "Scanning for WiFi networks (press Ctrl+C after ~30 seconds)..."
    log_warning "Let it run for at least 20-30 seconds to discover networks"
    
    mkdir -p "$OUTPUT_DIR"
    local scan_file="$OUTPUT_DIR/scan-01"
    
    # Remove old scan files
    rm -f "$OUTPUT_DIR"/scan-* 2>/dev/null
    
    echo ""
    log_info "Starting airodump-ng..."
    echo -e "${YELLOW}Press Ctrl+C when you see your target network${NC}"
    echo ""
    
    # Run airodump-ng and capture output
    timeout 30 airodump-ng "$MONITOR_INTERFACE" -w "$scan_file" --output-format csv 2>/dev/null || true
    
    # Wait a moment for file to be written
    sleep 2
    
    if [ ! -f "${scan_file}-01.csv" ]; then
        log_error "Scan file not created. Retrying..."
        airodump-ng "$MONITOR_INTERFACE" -w "$scan_file" --output-format csv &
        local pid=$!
        sleep 20
        kill $pid 2>/dev/null || true
        sleep 2
    fi
}

parse_and_select_target() {
    local scan_file="${OUTPUT_DIR}/scan-01-01.csv"
    
    if [ ! -f "$scan_file" ]; then
        log_error "Scan results not found"
        exit 1
    fi
    
    # Display filter options
    echo ""
    log_info "Network Filter Options:"
    echo ""
    echo "  1) Show all networks"
    echo "  2) Show only WPA/WPA2 networks (recommended)"
    echo "  3) Show networks with signal > -70 dBm"
    echo "  4) Custom filter"
    echo ""
    
    read -p "Select filter option [2]: " filter_choice
    filter_choice=${filter_choice:-2}
    
    local min_power=-100
    local encryption_filter=""
    
    case $filter_choice in
        1)
            log_info "Showing all networks"
            ;;
        2)
            encryption_filter="WPA"
            log_info "Filtering for WPA/WPA2 networks only"
            ;;
        3)
            min_power=-70
            log_info "Filtering for networks with signal > -70 dBm"
            ;;
        4)
            read -p "Minimum signal strength (e.g., -70): " min_power
            min_power=${min_power:--100}
            read -p "Encryption filter (WPA/WEP/OPN, or leave blank): " encryption_filter
            ;;
    esac
    
    echo ""
    log_info "Sort Options:"
    echo ""
    echo "  1) Sort by signal strength (strongest first)"
    echo "  2) Sort by channel"
    echo "  3) No sorting (order discovered)"
    echo ""
    
    read -p "Select sort option [1]: " sort_choice
    sort_choice=${sort_choice:-1}
    
    log_info "Parsing networks from scan..."
    echo ""
    
    # Parse CSV and collect networks
    local networks=()
    local network_details=()
    
    while IFS=, read -r bssid first_seen last_seen channel speed privacy cipher auth power beacons iv lan_ip id_length essid key; do
        # Skip header and empty lines
        if [[ "$bssid" =~ ^[0-9A-F]{2}:[0-9A-F]{2} ]]; then
            # Clean up fields
            bssid=$(echo "$bssid" | tr -d ' ')
            channel=$(echo "$channel" | tr -d ' ')
            power=$(echo "$power" | tr -d ' ')
            essid=$(echo "$essid" | tr -d ' ')
            privacy=$(echo "$privacy" | tr -d ' ')
            
            # Skip if no ESSID
            if [ -z "$essid" ] || [ "$essid" == "" ]; then
                essid="<Hidden SSID>"
            fi
            
            # Apply encryption filter
            if [ -n "$encryption_filter" ]; then
                if [[ ! "$privacy" =~ $encryption_filter ]]; then
                    continue
                fi
            fi
            
            # Apply signal strength filter
            if [ -n "$power" ] && [ "$power" -lt "$min_power" ]; then
                continue
            fi
            
            # Store network info with all details
            network_details+=("$power|$channel|$bssid|$essid|$privacy")
        fi
    done < "$scan_file"
    
    if [ ${#network_details[@]} -eq 0 ]; then
        log_error "No networks found matching filter criteria"
        log_warning "Try different filter options"
        
        read -p "Scan again? (y/n): " retry
        if [ "$retry" = "y" ] || [ "$retry" = "Y" ]; then
            scan_networks
            parse_and_select_target
        else
            cleanup_and_exit
        fi
        return
    fi
    
    # Sort networks based on choice
    case $sort_choice in
        1)
            # Sort by signal strength (strongest first = highest number)
            IFS=$'\n' network_details=($(sort -t'|' -k1 -rn <<< "${network_details[*]}"))
            ;;
        2)
            # Sort by channel
            IFS=$'\n' network_details=($(sort -t'|' -k2 -n <<< "${network_details[*]}"))
            ;;
        3)
            # No sorting
            ;;
    esac
    
    # Display networks
    log_success "Available networks (${#network_details[@]} found):"
    echo ""
    printf "  ${CYAN}%-4s %-18s  %-4s  %-6s  %-12s  %s${NC}\n" "NUM" "BSSID" "CH" "POWER" "ENCRYPTION" "ESSID"
    printf "  ${CYAN}%-4s %-18s  %-4s  %-6s  %-12s  %s${NC}\n" "---" "------------------" "----" "------" "------------" "-----"
    
    local i=1
    for network in "${network_details[@]}"; do
        local power=$(echo "$network" | cut -d'|' -f1)
        local channel=$(echo "$network" | cut -d'|' -f2)
        local bssid=$(echo "$network" | cut -d'|' -f3)
        local essid=$(echo "$network" | cut -d'|' -f4)
        local privacy=$(echo "$network" | cut -d'|' -f5)
        
        # Color code by signal strength
        local power_color="${RED}"
        if [ "$power" -gt -60 ]; then
            power_color="${GREEN}"
        elif [ "$power" -gt -70 ]; then
            power_color="${YELLOW}"
        fi
        
        printf "  ${GREEN}[%2d]${NC} %-18s  ${BLUE}%-4s${NC}  ${power_color}%-6s${NC}  ${MAGENTA}%-12s${NC}  %s\n" \
            "$i" "$bssid" "$channel" "$power" "$privacy" "$essid"
        ((i++))
    done
    
    echo ""
    
    # Select target
    while true; do
        read -p "Select target network number (or 'r' to rescan): " selection
        
        if [ "$selection" = "r" ] || [ "$selection" = "R" ]; then
            scan_networks
            parse_and_select_target
            return
        fi
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#network_details[@]}" ]; then
            local network="${network_details[$((selection-1))]}"
            TARGET_BSSID=$(echo "$network" | cut -d'|' -f3)
            TARGET_CHANNEL=$(echo "$network" | cut -d'|' -f2)
            TARGET_ESSID=$(echo "$network" | cut -d'|' -f4)
            local target_enc=$(echo "$network" | cut -d'|' -f5)
            
            echo ""
            log_success "Selected Target:"
            log_success "  ESSID: $TARGET_ESSID"
            log_success "  BSSID: $TARGET_BSSID"
            log_success "  Channel: $TARGET_CHANNEL"
            log_success "  Encryption: $target_enc"
            echo ""
            
            # Update statistics
            STATS_NETWORKS_FOUND=${#network_details[@]}
            
            read -p "Proceed with this target? (y/n): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                break
            else
                echo ""
                log_info "Selection cancelled, choose again..."
                echo ""
            fi
        else
            log_error "Invalid selection"
        fi
    done
}
