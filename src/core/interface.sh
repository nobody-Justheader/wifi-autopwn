# Interface Management Functions

list_interfaces() {
    log_info "Available wireless interfaces:"
    echo ""
    
    local interfaces=($(iw dev | grep Interface | awk '{print $2}'))
    
    if [ ${#interfaces[@]} -eq 0 ]; then
        log_error "No wireless interfaces found"
        exit 1
    fi
    
    local i=1
    for iface in "${interfaces[@]}"; do
        local driver=$(ethtool -i "$iface" 2>/dev/null | grep driver | awk '{print $2}')
        echo -e "  ${GREEN}[$i]${NC} $iface (Driver: $driver)"
        ((i++))
    done
    
    echo ""
}

select_interface() {
    list_interfaces
    
    local interfaces=($(iw dev | grep Interface | awk '{print $2}'))
    
    while true; do
        read -p "Select interface number [1]: " selection
        selection=${selection:-1}
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#interfaces[@]}" ]; then
            INTERFACE="${interfaces[$((selection-1))]}"
            log_success "Selected interface: $INTERFACE"
            break
        else
            log_error "Invalid selection"
        fi
    done
}

enable_monitor_mode() {
    log_info "Enabling monitor mode on $INTERFACE..."
    
    # Kill interfering processes
    airmon-ng check kill > /dev/null 2>&1
    
    # Start monitor mode
    airmon-ng start "$INTERFACE" > /dev/null 2>&1
    
    # Get monitor interface name
    MONITOR_INTERFACE=$(iw dev | grep -A 1 "Interface" | grep "type monitor" -B 1 | grep Interface | awk '{print $2}' | head -1)
    
    if [ -z "$MONITOR_INTERFACE" ]; then
        log_error "Failed to enable monitor mode"
        exit 1
    fi
    
    log_success "Monitor mode enabled: $MONITOR_INTERFACE"
}

disable_monitor_mode() {
    if [ -n "$MONITOR_INTERFACE" ]; then
        log_info "Disabling monitor mode..."
        airmon-ng stop "$MONITOR_INTERFACE" > /dev/null 2>&1
        log_success "Monitor mode disabled"
    fi
}

restore_mac_address() {
    # Placeholder for MAC randomization restore
    return 0
}
