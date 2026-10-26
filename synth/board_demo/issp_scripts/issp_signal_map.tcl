# ==============================================================================
# File:        issp_signal_map.tcl
# Target:      Terasic DE2i-150 FPGA Board (Intel Cyclone IV GX EP4CGX150DF31C7)
# Module:      l2_bdi_cache_board_demo (Instance: "BDIL2")
# Author:      Mohammed Adel Gweaa | University of Tripoli
# Description:
#   Master In-System Sources and Probes (ISSP) Signal Mapping & Decoding Library.
#   Provides bitfield unpacking, profile translation, and ASCII dashboard formatting
#   for live hardware JTAG telemetry and automated testing.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Hardware Bitfield Definitions
# ------------------------------------------------------------------------------
# Source Bus (Host -> FPGA): Total 357 bits
#   [255:0]   : Data In (256-bit cache line)
#   [287:256] : Byte Address (32-bit)
#   [288]     : Write Enable (1=Write, 0=Read)
#   [289]     : Is Refill (1=DRAM Line Refill, 0=CPU Core Access)
#   [290]     : Request Toggle (Toggles state to trigger 1-cycle synchronous pulse)
#   [291]     : Soft Reset (Active-Low: 1=Normal, 0=Assert Reset)
#   [323:292] : CSR MMIO Address (32-bit)
#   [355:324] : CSR MMIO Write Data (32-bit)
#   [356]     : CSR MMIO Write Enable (1=Write CSR)

# Probe Bus (FPGA -> Host): Total 320 bits
#   [255:0]   : Cache Line Data Out (256-bit)
#   [256]     : Cache Hit (1=Hit)
#   [257]     : Cache Miss (1=Miss)
#   [258]     : Response Valid (1=Valid)
#   [259]     : Store-to-Load Forwarding (STLF) Real-Time Bypass Active
#   [260]     : Dynamic Compression Bypass (DCB) Active
#   [261]     : Eviction Valid (Dirty line push to DRAM)
#   [293:262] : Eviction Address (32-bit)
#   [303:294] : Telemetry Access Counter (10-bit)
#   [313:304] : Telemetry Miss Counter (10-bit)
#   [315:314] : Dynamic Associativity Selection (00=1-Way, 01=2-Way, 10=4-Way, 11=8-Way)
#   [318:316] : Active BDI Compression Profile ID (0..7)
#   [319]     : STLF Latched Bypass Event

# ------------------------------------------------------------------------------
# 2. Conversion and Bitfield Helper Procedures
# ------------------------------------------------------------------------------

# Converts a binary bit string to a padded hexadecimal string
proc bdi_bin_to_hex {bin_str num_hex_digits} {
    # Pad binary string on left to multiple of 4
    set pad_len [expr {(4 - ([string length $bin_str] % 4)) % 4}]
    set padded_bin [string repeat "0" $pad_len]$bin_str
    
    set hex_str ""
    for {set i 0} {$i < [string length $padded_bin]} {incr i 4} {
        set nibble [string range $padded_bin $i [expr {$i + 3}]]
        switch $nibble {
            "0000" { append hex_str "0" }
            "0001" { append hex_str "1" }
            "0010" { append hex_str "2" }
            "0011" { append hex_str "3" }
            "0100" { append hex_str "4" }
            "0101" { append hex_str "5" }
            "0110" { append hex_str "6" }
            "0111" { append hex_str "7" }
            "1000" { append hex_str "8" }
            "1001" { append hex_str "9" }
            "1010" { append hex_str "A" }
            "1011" { append hex_str "B" }
            "1100" { append hex_str "C" }
            "1101" { append hex_str "D" }
            "1110" { append hex_str "E" }
            "1111" { append hex_str "F" }
            default { append hex_str "0" }
        }
    }
    # Adjust to required number of hex digits
    if {[string length $hex_str] > $num_hex_digits} {
        set hex_str [string range $hex_str [expr {[string length $hex_str] - $num_hex_digits}] end]
    } elseif {[string length $hex_str] < $num_hex_digits} {
        set hex_str [string repeat "0" [expr {$num_hex_digits - [string length $hex_str]}]$hex_str]
    }
    return $hex_str
}

# Converts a hexadecimal string to a binary string with exact bit width
proc bdi_hex_to_bin {hex_str num_bits} {
    # Remove any 0x or underscores
    set clean_hex [string map {"0x" "" "0X" "" "_" ""} $hex_str]
    set bin_str ""
    for {set i 0} {$i < [string length $clean_hex]} {incr i} {
        set ch [string index $clean_hex $i]
        switch -nocase $ch {
            "0" { append bin_str "0000" }
            "1" { append bin_str "0001" }
            "2" { append bin_str "0010" }
            "3" { append bin_str "0011" }
            "4" { append bin_str "0100" }
            "5" { append bin_str "0101" }
            "6" { append bin_str "0110" }
            "7" { append bin_str "0111" }
            "8" { append bin_str "1000" }
            "9" { append bin_str "1001" }
            "a" { append bin_str "1010" }
            "b" { append bin_str "1011" }
            "c" { append bin_str "1100" }
            "d" { append bin_str "1101" }
            "e" { append bin_str "1110" }
            "f" { append bin_str "1111" }
            default { append bin_str "0000" }
        }
    }
    # Pad or slice to num_bits
    if {[string length $bin_str] > $num_bits} {
        return [string range $bin_str [expr {[string length $bin_str] - $num_bits}] end]
    } elseif {[string length $bin_str] < $num_bits} {
        return [string repeat "0" [expr {$num_bits - [string length $bin_str]}]$bin_str]
    }
    return $bin_str
}

# Decodes 3-bit BDI profile ID to human-readable academic profile name
proc bdi_decode_profile {profile_id dcb_active} {
    if {$dcb_active == 1} {
        return "DCB Bypass (Uncompressed 256-bit Fallback)"
    }
    switch $profile_id {
        0 { return "Type 0: Incompressible Fallback (256-bit)" }
        1 { return "Type 1: Base8 + 8-bit Delta (B8-D1, 96-bit, 2.67:1)" }
        2 { return "Type 2: Base8 + 16-bit Delta (B8-D2, 112-bit, 2.29:1)" }
        3 { return "Type 3: All-Zeros Line (0-bit payload, 8.00:1)" }
        4 { return "Type 4: Base4 + 8-bit Delta (B4-D1, 96-bit, 2.67:1)" }
        5 { return "Type 5: Same-Value Line (Repeated 32-bit Word, 8.00:1)" }
        6 { return "Type 6: Sparse Low-Delta Pointer Vector (Base2-D1)" }
        7 { return "Type 7: Zero / Dense Compact Representation" }
        default { return "Unknown Profile ($profile_id)" }
    }
}

# Decodes 2-bit associativity selection to human-readable mode
proc bdi_decode_associativity {assoc_bits} {
    switch $assoc_bits {
        "00" { return "1-Way Direct Mapped (Test Mode)" }
        "01" { return "2-Way Set Associative (Minimal Power)" }
        "10" { return "4-Way Set Associative (Low-Power Governed Mode)" }
        "11" { return "8-Way Set Associative (Maximum Performance Mode)" }
        default { return "Unknown Associativity ($assoc_bits)" }
    }
}

# ------------------------------------------------------------------------------
# 3. Probe Bitstring Parser
# ------------------------------------------------------------------------------
# Unpacks 320-bit probe bitstring returned by read_probe_data into a Tcl dict
proc bdi_unpack_probes {raw_probe_bits} {
    # Quartus returns probe bits as MSB...LSB (bit 319 at index 0, bit 0 at index 319)
    # Ensure length is 320
    set total_len [string length $raw_probe_bits]
    if {$total_len < 320} {
        set raw_probe_bits [string repeat "0" [expr {320 - $total_len}]]$raw_probe_bits
    }
    
    # Reverse string so index equals bit position [0..319]
    set bit_rev ""
    for {set i [expr {[string length $raw_probe_bits] - 1}]} {$i >= 0} {incr i -1} {
        append bit_rev [string index $raw_probe_bits $i]
    }
    
    # Extract fields by bit index
    set data_out_bin    [string range $bit_rev 0 255]
    set hit_bit         [string index $bit_rev 256]
    set miss_bit        [string index $bit_rev 257]
    set resp_valid_bit  [string index $bit_rev 258]
    set stlf_fwd_bit    [string index $bit_rev 259]
    set dcb_bypass_bit  [string index $bit_rev 260]
    set evict_valid_bit [string index $bit_rev 261]
    set evict_addr_bin  [string range $bit_rev 262 293]
    set access_cnt_bin  [string range $bit_rev 294 303]
    set miss_cnt_bin    [string range $bit_rev 304 313]
    set assoc_sel_bin   [string range $bit_rev 314 315]
    set comp_type_bin   [string range $bit_rev 316 318]
    set latched_stlf_bit [string index $bit_rev 319]
    
    # Convert binary to hex/integer
    # Data out: reverse back to MSB..LSB before hex conversion
    set data_msb_lsb ""
    for {set i [expr {[string length $data_out_bin] - 1}]} {$i >= 0} {incr i -1} {
        append data_msb_lsb [string index $data_out_bin $i]
    }
    set data_out_hex [bdi_bin_to_hex $data_msb_lsb 64]
    
    # Eviction Address
    set evict_msb_lsb ""
    for {set i [expr {[string length $evict_addr_bin] - 1}]} {$i >= 0} {incr i -1} {
        append evict_msb_lsb [string index $evict_addr_bin $i]
    }
    set evict_addr_hex "0x[bdi_bin_to_hex $evict_msb_lsb 8]"
    
    # Access and Miss counts
    scan [bdi_bin_to_hex $access_cnt_bin 4] "%x" access_count
    scan [bdi_bin_to_hex $miss_cnt_bin 4] "%x" miss_count
    scan [bdi_bin_to_hex $comp_type_bin 1] "%x" comp_type_id
    
    # Calculate Hit Ratio
    set hit_count [expr {$access_count - $miss_count}]
    if {$access_count > 0} {
        set hit_ratio [format "%.2f%%" [expr {($hit_count * 100.0) / $access_count}]]
    } else {
        set hit_ratio "N/A (0 Accesses)"
    }
    
    # Return structured dict
    dict set res data_hex       $data_out_hex
    dict set res hit            $hit_bit
    dict set res miss           $miss_bit
    dict set res resp_valid     $resp_valid_bit
    dict set res stlf_fwd       $stlf_fwd_bit
    dict set res latched_stlf   $latched_stlf_bit
    dict set res dcb_bypass     $dcb_bypass_bit
    dict set res evict_valid    $evict_valid_bit
    dict set res evict_addr     $evict_addr_hex
    dict set res access_count   $access_count
    dict set res miss_count     $miss_count
    dict set res hit_count      $hit_count
    dict set res hit_ratio      $hit_ratio
    dict set res assoc_bits     $assoc_sel_bin
    dict set res assoc_str      [bdi_decode_associativity $assoc_sel_bin]
    dict set res comp_type_id   $comp_type_id
    dict set res comp_profile   [bdi_decode_profile $comp_type_id $dcb_bypass_bit]
    
    return $res
}

# ------------------------------------------------------------------------------
# 4. Formatted ASCII Dashboard Generator
# ------------------------------------------------------------------------------
proc bdi_format_dashboard {res_dict {title "BDI L2 CACHE HARDWARE TELEMETRY DASHBOARD"}} {
    set lines {}
    lappend lines "================================================================================"
    lappend lines "  $title"
    lappend lines "  Target: Terasic DE2i-150 FPGA | Clock: 50.00 MHz | JTAG ISSP Instance: BDIL2"
    lappend lines "================================================================================"
    
    # Status Indicators
    set hit_flag       [dict get $res_dict hit]
    set miss_flag      [dict get $res_dict miss]
    set valid_flag     [dict get $res_dict resp_valid]
    set stlf_flag      [dict get $res_dict stlf_fwd]
    set latched_stlf   [dict get $res_dict latched_stlf]
    set dcb_flag       [dict get $res_dict dcb_bypass]
    set evict_flag     [dict get $res_dict evict_valid]
    
    set hit_str   [expr {$hit_flag ? "HIT (1)" : "---"}]
    set miss_str  [expr {$miss_flag ? "MISS (1)" : "---"}]
    set valid_str [expr {$valid_flag ? "VALID (1)" : "WAITING (0)"}]
    set stlf_str  [expr {$stlf_flag ? "ACTIVE (ZERO-STALL BYPASS)" : ($latched_stlf ? "LATCHED RECENT EVENT" : "INACTIVE")}]
    set dcb_str   [expr {$dcb_flag ? "BYPASS TRIGGERED (HIGH ENTROPY)" : "OFF (COMPRESSION ACTIVE)"}]
    set evict_str [expr {$evict_flag ? "EVICTING DIRTY LINE TO DRAM" : "IDLE"}]
    
    lappend lines [format "  %-24s : %-15s | %-24s : %s" "Cache Response" "$hit_str $miss_str" "Pipeline Status" $valid_str]
    lappend lines [format "  %-24s : %-15s | %-24s : %s" "STLF Hazard Bypass" $stlf_str "Dynamic Bypass (DCB)" $dcb_str]
    lappend lines [format "  %-24s : %-15s | %-24s : %s" "Eviction Controller" $evict_str "Eviction DRAM Address" [dict get $res_dict evict_addr]]
    lappend lines "--------------------------------------------------------------------------------"
    lappend lines "  ARCHITECTURAL CONFIGURATION & BDI METRICS:"
    lappend lines [format "  %-24s : %s" "BDI Compression" [dict get $res_dict comp_profile]]
    lappend lines [format "  %-24s : %s" "Power Governor State" [dict get $res_dict assoc_str]]
    lappend lines "--------------------------------------------------------------------------------"
    lappend lines "  HARDWARE PERFORMANCE COUNTERS:"
    lappend lines [format "  Total Accesses : %-8d | Total Misses : %-8d | Total Hits : %-8d" [dict get $res_dict access_count] [dict get $res_dict miss_count] [dict get $res_dict hit_count]]
    lappend lines [format "  Live Hit Ratio : %s" [dict get $res_dict hit_ratio]]
    lappend lines "--------------------------------------------------------------------------------"
    lappend lines "  256-BIT CACHE LINE DATA OUT (8 x 32-bit Words):"
    
    set full_hex [dict get $res_dict data_hex]
    # Slice 64-char hex string into 8 x 8-char words (Word 7 down to Word 0)
    for {set w 7} {$w >= 0} {incr w -1} {
        set word_start [expr {(7 - $w) * 8}]
        set word_val [string range $full_hex $word_start [expr {$word_start + 7}]]
        lappend lines [format "    Word %d [0x%02X..0x%02X]: 0x%s" $w [expr {$w * 4 + 3}] [expr {$w * 4}] $word_val]
    }
    lappend lines "================================================================================"
    return [join $lines "\n"]
}
