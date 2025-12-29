# Global Variables and Configuration

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Network configuration
INTERFACE=""
MONITOR_INTERFACE=""
TARGET_BSSID=""
TARGET_CHANNEL=""
TARGET_ESSID=""
TARGET_MAC_RANDOM=""

# WiFi Generation Detection
TARGET_WIFI_GEN=""      # WiFi 1-7
TARGET_STANDARD=""      # 802.11a/b/g/n/ac/ax/be
TARGET_BAND=""          # 2.4GHz / 5GHz / 6GHz

# Attack configuration
ATTACK_MODE=""  # handshake, pmkid, wps, evil_twin, wep, batch
CRACK_METHOD=""  # aircrack or hashcat
DEAUTH_COUNT=10
CAPTURE_DURATION=60

# File paths - Auto-create in portable location
OUTPUT_DIR="${OUTPUT_DIR:-./wifi-captures}"
HANDSHAKE_FILE=""
PMKID_FILE=""
HASHCAT_HASH_FILE=""
WORDLIST=""
CONFIG_FILE=""
SESSION_ID=""

# Session state
RESUME_MODE=false

# Statistics
STATS_NETWORKS_FOUND=0
STATS_NETWORKS_ATTACKED=0
STATS_NETWORKS_CRACKED=0
STATS_START_TIME=0
STATS_WPS_ATTEMPTS=0
STATS_EVIL_TWIN_CAPTURES=0

# Feature flags
FEATURE_5GHZ=false
FEATURE_6GHZ=false
FEATURE_MAC_RANDOM=false
FEATURE_WPS=false
FEATURE_EVIL_TWIN=false
FEATURE_WEP=false

# Version
VERSION="1.0"
BUILD_DATE="$(date +%Y%m%d)"

# Auto-setup function
auto_setup() {
    # Create output directory if it doesn't exist
    mkdir -p "$OUTPUT_DIR" 2>/dev/null || {
        # Fallback to /tmp if current directory not writable
        OUTPUT_DIR="/tmp/wifi-captures-$$"
        mkdir -p "$OUTPUT_DIR"
        log_warning "Using temp directory: $OUTPUT_DIR"
    }
    
    # Ensure we have write permissions
    if [ ! -w "$OUTPUT_DIR" ]; then
        log_error "Cannot write to output directory: $OUTPUT_DIR"
        exit 1
    fi
}
