# Statistics Tracking and Reporting Module

initialize_statistics() {
    STATS_START_TIME=$(date +%s)
    STATS_NETWORKS_FOUND=0
    STATS_NETWORKS_ATTACKED=0
    STATS_NETWORKS_CRACKED=0
    STATS_WPS_ATTEMPTS=0
    STATS_EVIL_TWIN_CAPTURES=0
}

update_statistics() {
    # Called after key events
    save_statistics_json
}

save_statistics_json() {
    local stats_file="$OUTPUT_DIR/statistics.json"
    local elapsed=$(($(date +%s) - STATS_START_TIME))
    
    cat > "$stats_file" << EOF
{
  "session_start": "$(date -d @$STATS_START_TIME '+%Y-%m-%d %H:%M:%S')",
  "elapsed_seconds": $elapsed,
  "networks_found": $STATS_NETWORKS_FOUND,
  "networks_attacked": $STATS_NETWORKS_ATTACKED,
  "networks_cracked": $STATS_NETWORKS_CRACKED,
  "wps_attempts": $STATS_WPS_ATTEMPTS,
  "evil_twin_captures": $STATS_EVIL_TWIN_CAPTURES,
  "success_rate": "$(awk "BEGIN {if ($STATS_NETWORKS_ATTACKED>0) print ($STATS_NETWORKS_CRACKED/$STATS_NETWORKS_ATTACKED*100); else print 0}")%"
}
EOF
}

display_statistics() {
    local elapsed=$(($(date +%s) - STATS_START_TIME))
    local hours=$((elapsed / 3600))
    local mins=$(((elapsed % 3600) / 60))
    local secs=$((elapsed % 60))
    
    echo ""
    log_info "═══════════════════════════════════════════"
    log_info "  SESSION STATISTICS"
    log_info "═══════════════════════════════════════════"
    echo "  Runtime: ${hours}h ${mins}m ${secs}s"
    echo "  Networks Found: $STATS_NETWORKS_FOUND"
    echo "  Networks Attacked: $STATS_NETWORKS_ATTACKED"
    echo "  Networks Cracked: $STATS_NETWORKS_CRACKED"
    echo "  WPS Attempts: $STATS_WPS_ATTEMPTS"
    echo "  Evil Twin Captures: $STATS_EVIL_TWIN_CAPTURES"
    
    if [ $STATS_NETWORKS_ATTACKED -gt 0 ]; then
        local success_rate=$(awk "BEGIN {print ($STATS_NETWORKS_CRACKED/$STATS_NETWORKS_ATTACKED*100)}")
        echo "  Success Rate: ${success_rate}%"
    fi
    
    log_info "═══════════════════════════════════════════"
    echo ""
}
