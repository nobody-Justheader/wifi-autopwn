# WiFi Generation Detection & Multi-Standard Support
#
# Comprehensive coverage of all WiFi standards from legacy to WiFi 7
#
# WiFi Generations Timeline:
# - WiFi 0 (1997): 802.11 (2 Mbps)
# - WiFi 1 (1999): 802.11b (11 Mbps, 2.4GHz)
# - WiFi 2 (1999): 802.11a (54 Mbps, 5GHz)
# - WiFi 3 (2003): 802.11g (54 Mbps, 2.4GHz)
# - WiFi 4 (2009): 802.11n (600 Mbps, 2.4/5GHz)
# - WiFi 5 (2014): 802.11ac (3.5 Gbps, 5GHz)
# - WiFi 6 (2019): 802.11ax (9.6 Gbps, 2.4/5GHz, WPA3)
# - WiFi 6E (2020): 802.11ax (6GHz band)
# - WiFi 7 (2024): 802.11be (46 Gbps, 2.4/5/6GHz)
#
# References:
# - https://www.wi-fi.org/discover-wi-fi/wi-fi-certified-6
# - https://www.ieee802.org/11/
# - CVE-2024-20017 (MediaTek WiFi 6 RCE)
# - BREAK Attack on WiFi 7 MU-MIMO

detect_wifi_generation() {
    local bssid="$1"
    local channel="$2"
    
    log_info "Detecting WiFi generation/standard..."
    
    # Analyze beacon frames for capabilities
    local scan_file="${OUTPUT_DIR}/scan-01-01.csv"
    
    if [ ! -f "$scan_file" ]; then
        log_warning "No scan data available"
        return 1
    fi
    
    # Extract max speed (MB) from scan
    local max_speed=$(grep "$bssid" "$scan_file" | awk -F',' '{print $5}' | tr -d ' ')
    
    # Determine standard based on max speed
    # This is approximate - real detection requires beacon frame analysis
    local wifi_gen=""
    local standard=""
    local band=""
    
    # Channel-based band detection
    if [ "$channel" -le 14 ]; then
        band="2.4GHz"
    elif [ "$channel" -le 165 ]; then
        band="5GHz"
    elif [ "$channel" -ge 1 ]; then
        band="6GHz (WiFi 6E/7)"
    fi
    
    # Speed-based generation detection (simplified)
    if [ "$max_speed" -eq 11 ]; then
        wifi_gen="WiFi 1"
        standard="802.11b"
    elif [ "$max_speed" -eq 54 ]; then
        if [ "$band" = "5GHz" ]; then
            wifi_gen="WiFi 2"
            standard="802.11a"
        else
            wifi_gen="WiFi 3"
            standard="802.11g"
        fi
    elif [ "$max_speed" -gt 54 ] && [ "$max_speed" -le 600 ]; then
        wifi_gen="WiFi 4"
        standard="802.11n"
    elif [ "$max_speed" -gt 600 ] && [ "$max_speed" -le 3500 ]; then
        wifi_gen="WiFi 5"
        standard="802.11ac"
    elif [ "$max_speed" -gt 3500 ]; then
        if [ "$band" = "6GHz (WiFi 6E/7)" ]; then
            wifi_gen="WiFi 6E/7"
            standard="802.11ax/be"
        else
            wifi_gen="WiFi 6"
            standard="802.11ax"
        fi
    else
        wifi_gen="Unknown"
        standard="Unknown"
    fi
    
    # Store detected generation
    TARGET_WIFI_GEN="$wifi_gen"
    TARGET_STANDARD="$standard"
    TARGET_BAND="$band"
    
    echo ""
    log_success "WiFi Generation Detected:"
    echo "  Generation: $wifi_gen"
    echo "  Standard: $standard"
    echo "  Band: $band"
    echo "  Max Speed: ${max_speed} Mbps"
    echo ""
    
    # Recommend appropriate attacks based on generation
    recommend_attacks_for_generation "$wifi_gen" "$standard"
}

recommend_attacks_for_generation() {
    local wifi_gen="$1"
    local standard="$2"
    
    log_info "Recommended attacks for $wifi_gen ($standard):"
    echo ""
    
    case "$wifi_gen" in
        "WiFi 1"|"WiFi 2"|"WiFi 3")
            # Legacy WiFi - WEP era
            echo "  ✓ WEP Attacks (legacy encryption)"
            echo "    - ARP request replay"
            echo "    - Chopchop attack"
            echo "    - Fragmentation attack"
            echo "    - Caffe Latte (client-side)"
            echo ""
            echo "  ⚠ Warning: WEP is completely broken"
            ;;
        
        "WiFi 4"|"WiFi 5")
            # WPA/WPA2 era
            echo "  ✓ WPA/WPA2 Attacks"
            echo "    - PMKID attack (fast, clientless)"
            echo "    - Handshake capture + crack"
            echo "    - WPS attacks (if enabled)"
            echo "      • Pixie Dust"
            echo "      • PIN brute-force"
            echo ""
            echo "  ✓ Advanced Attacks"
            echo "    - KRACK (Key Reinstallation)"
            echo "    - FragAttacks"
            echo "    - Evil Twin / Captive Portal"
            ;;
        
        "WiFi 6")
            # WPA2/WPA3 mixed
            echo "  ✓ WPA2/WPA3 Attacks"
            echo "    - PMKID attack (WPA2 networks)"
            echo "    - WPA3 Dragonblood (if WPA3)"
            echo "      • Downgrade to WPA2 (transition mode)"
            echo "      • Side-channel attacks"
            echo "    - FragAttacks (affects all WiFi)"
            echo ""
            echo "  ⚠ Note: WPA3-only networks more secure"
            ;;
        
        "WiFi 6E/7")
            # Mandatory WPA3, 6GHz
            echo "  ✓ WPA3 Attacks (mandatory on 6GHz)"
            echo "    - Dragonblood attacks"
            echo "      • CVE-2019-13377 (side-channel)"
            echo "      • DoS attacks"
            echo "    - SSID Confusion (CVE-2023-52424)"
            echo "    - BREAK Attack (WiFi 7 MU-MIMO)"
            echo "    - FragAttacks"
            echo "    - Evil Twin (require WPA3 enterprise creds)"
            echo ""
            echo "  ⚠ Advanced: Requires WPA3 tools"
            echo "  ⚠ 6GHz: No WPA2 backward compatibility"
            ;;
        
        *)
            echo "  Unknown generation - try standard attacks"
            ;;
    esac
    
    echo ""
}

# 5GHz / 6GHz Band Support
enable_multi_band_support() {
    log_info "Enabling multi-band WiFi support..."
    
    # Check adapter capabilities
    if ! iw list 2>/dev/null | grep -q "Band 2"; then
        log_warning "5GHz band not supported by adapter"
        FEATURE_5GHZ=false
    else
        log_success "5GHz band supported"
        FEATURE_5GHZ=true
    fi
    
    # Check for 6GHz (WiFi 6E/7)
    if iw list 2>/dev/null | grep -A 10 "Band" | grep -q "6[0-9][0-9][0-9] MHz"; then
        log_success "6GHz band supported (WiFi 6E/7)"
        FEATURE_6GHZ=true
    else
        log_info "6GHz band not available (WiFi 6E/7 requires compatible hardware)"
        FEATURE_6GHZ=false
    fi
}

# Enhanced scanning with band specification
scan_networks_multi_band() {
    log_info "Multi-Band Network Scanner"
    echo ""
    echo "Select scanning mode:"
    echo "  1) 2.4GHz only (WiFi 1/3/4)"
    echo "  2) 5GHz only (WiFi 2/4/5/6)"
    
    if [ "$FEATURE_6GHZ" = true ]; then
        echo "  3) 6GHz only (WiFi 6E/7)"
        echo "  4) All bands (2.4 + 5 + 6 GHz)"
    else
        echo "  3) Both bands (2.4 + 5 GHz)"
    fi
    echo ""
    
    read -p "Select mode [4]: " band_mode
    band_mode=${band_mode:-4}
    
    local band_arg=""
    
    case $band_mode in
        1)
            band_arg="--band bg"
            log_info "Scanning 2.4GHz band only..."
            ;;
        2)
            band_arg="--band a"
            log_info "Scanning 5GHz band only..."
            ;;
        3)
            if [ "$FEATURE_6GHZ" = true ]; then
                band_arg="--band 6g"
                log_info "Scanning 6GHz band only..."
            else
                band_arg=""
                log_info "Scanning both 2.4GHz and 5GHz..."
            fi
            ;;
        4)
            band_arg=""
            log_info "Scanning all available bands..."
            ;;
    esac
    
    # Run enhanced scan
    mkdir -p "$OUTPUT_DIR"
    local scan_file="$OUTPUT_DIR/scan-01"
    
    rm -f "$OUTPUT_DIR"/scan-* 2>/dev/null
    
    # Standard scan (airodump-ng doesn't have direct band filter, use channel range)
    timeout 30 airodump-ng "$MONITOR_INTERFACE" -w "$scan_file" --output-format csv 2>/dev/null || true
    
    sleep 2
}

# Generation-specific attack selector
attack_by_wifi_generation() {
    # Detect generation first
    detect_wifi_generation "$TARGET_BSSID" "$TARGET_CHANNEL"
    
    echo ""
    read -p "Use recommended attacks for this generation? (y/n): " use_recommended
    
    if [ "$use_recommended" = "y" ] || [ "$use_recommended" = "Y" ]; then
        case "$TARGET_WIFI_GEN" in
            "WiFi 1"|"WiFi 2"|"WiFi 3")
                # Legacy WEP
                attack_wep
                ;;
            
            "WiFi 4"|"WiFi 5")
                # WPA/WPA2
                if attack_pmkid; then
                    crack_hashcat || crack_password
                else
                    capture_handshake && crack_password
                fi
                ;;
            
            "WiFi 6")
                # Try WPA3 downgrade first, then PMKID
                if attack_dragonblood; then
                    :
                else
                    attack_pmkid && crack_hashcat
                fi
                ;;
            
            "WiFi 6E/7")
                # Advanced WPA3 attacks  
                log_warning "WiFi 6E/7 requires advanced WPA3 attack tools"
                select_novel_attack
                ;;
            
            *)
                log_info "Unknown generation - showing all attack options"
                return 1
                ;;
        esac
    else
        return 1
    fi
}

# WiFi 6/7 specific attack notes
attack_wifi6e_wifi7() {
    log_info "WiFi 6E/7 Attack Considerations"
    echo ""
    echo "WiFi 6E (6GHz) and WiFi 7 Characteristics:"
    echo "  • Mandatory WPA3 (no WPA2 fallback on 6GHz)"
    echo "  • Enhanced Open (OWE) required"
    echo "  • Protected Management Frames (PMF) mandatory"
    echo "  • GCMP-256 encryption (WiFi 7)"
    echo "  • Beacon Protection (WiFi 7)"
    echo ""
    
    echo "Known Vulnerabilities:"
    echo "  • CVE-2019-13377: WPA3 Dragonblood"
    echo "  • CVE-2023-52424: SSID Confusion"
    echo "  • CVE-2024-20017: MediaTek WiFi 6 RCE"
    echo "  • BREAK Attack: MU-MIMO manipulation (WiFi 7)"
    echo ""
    
    echo "Attack Vectors:"
    echo "  1. Dragonblood (WPA3 downgrade/DoS)"
    echo "  2. SSID Confusion (evil twin variant)"
    echo "  3. FragAttacks (standard-level flaws)"
    echo "  4. Social engineering / Evil Twin"
    echo ""
    
    log_warning "Most attacks require specialized tools and vulnerable firmware"
    
    read -p "Proceed with novel attacks? (y/n): " proceed
    
    if [ "$proceed" = "y" ]; then
        select_novel_attack
    fi
}
