# Session Management - Config JSON for State Persistence
# Minimal implementation for session save/restore

save_session() {
    local session_file="$OUTPUT_DIR/session_$(date +%Y%m%d_%H%M%S).json"
    
    cat > "$session_file" << EOF
{
  "target_essid": "$TARGET_ESSID",
  "target_bssid": "$TARGET_BSSID",
  "target_channel": "$TARGET_CHANNEL",
  "attack_mode": "$ATTACK_MODE",
  "timestamp": "$(date)"
}
EOF
    
    log_info "Session saved: $session_file"
}

load_session() {
    local session_file="$1"
    
    if [ ! -f "$session_file" ]; then
        return 1
    fi
    
    # Simple grep-based JSON parsing (no jq dependency)
    TARGET_ESSID=$(grep "target_essid" "$session_file" | cut -d'"' -f4)
    TARGET_BSSID=$(grep "target_bssid" "$session_file" | cut -d'"' -f4)
    TARGET_CHANNEL=$(grep "target_channel" "$session_file" | cut -d'"' -f4)
    ATTACK_MODE=$(grep "attack_mode" "$session_file" | cut -d'"' -f4)
    
    log_success "Session restored"
}
