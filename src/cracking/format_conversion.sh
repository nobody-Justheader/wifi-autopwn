# Format Conversion Module - CAP/PCAPNG to Hashcat HC22000
#
# Converts various capture formats to hashcat-compatible hash files
# References:
# - https://hashcat.net/wiki/doku.php?id=cracking_wpawpa2
# - https://github.com/hashcat/hashcat/blob/master/docs/readme.txt
#
# Supported formats:
#  - CAP (airodump-ng) → HC22000 (hashcat 22000/22001)
#  - PCAPNG (hcxdumptool) → HC22000
#  - Legacy HCCAPX → HC22000

convert_to_hashcat() {
    local input_file="$1"
    local output_file="$2"
    
    if [ ! -f "$input_file" ]; then
        log_error "Input file not found: $input_file"
        return 1
    fi
    
    log_info "Converting capture to hashcat format..."
    
    # Prefer hcxpcapngtool (modern, supports all formats)
    if command -v hcxpcapngtool &> /dev/null; then
        hcxpcapngtool -o "$output_file" "$input_file" > /dev/null 2>&1
        
        if [ -f "$output_file" ] && [ -s "$output_file" ]; then
            log_success "Converted to hashcat format: $output_file"
            return 0
        fi
    fi
    
    # Fallback to cap2hashcat (if available)
    if command -v cap2hashcat &> /dev/null; then
        cap2hashcat "$input_file" "$output_file" > /dev/null 2>&1
        
        if [ -f "$output_file" ] && [ -s "$output_file" ]; then
            log_success "Converted with cap2hashcat: $output_file"
            return 0
        fi
    fi
    
    log_error "Conversion failed - install hcxtools"
    return 1
}
