# ==============================================================================
# Script:      issp_inject_test_vector.tcl
# Target:      Terasic DE2i-150 FPGA Board (Intel Cyclone IV GX EP4CGX150DF31C7)
# Module:      l2_bdi_cache_board_demo (Instance: "BDIL2")
# Author:      Mohammed Adel Gweaa | University of Tripoli
# Description:
#   Interactive In-System Sources and Probes (ISSP) Stimulus Injection Console.
#   Allows users to inject custom 256-bit cache lines, trigger reads/writes,
#   test Store-to-Load Forwarding (STLF), and switch associativity over JTAG.
#
# Usage:
#   quartus_stp -t issp_inject_test_vector.tcl
# ==============================================================================

set script_dir [file dirname [info script]]
source [file join $script_dir "issp_signal_map.tcl"]

# Global persistent toggle state
set ::bdi_req_toggle_state 0

# ------------------------------------------------------------------------------
# Stimulus Packing Procedure (357 bits)
# ------------------------------------------------------------------------------
proc bdi_pack_source {data_hex addr_hex is_write is_refill req_toggle soft_reset_n csr_addr csr_wdata csr_we} {
    # Unpack fields into binary strings
    # [255:0]   : data_in (256 bits)
    set bin_data      [bdi_hex_to_bin $data_hex 256]
    # [287:256] : address (32 bits)
    set bin_addr      [bdi_hex_to_bin $addr_hex 32]
    # [288]     : write enable
    set bin_write     [expr {$is_write ? "1" : "0"}]
    # [289]     : is_refill
    set bin_refill    [expr {$is_refill ? "1" : "0"}]
    # [290]     : req_toggle
    set bin_toggle    [expr {$req_toggle ? "1" : "0"}]
    # [291]     : soft_reset_n (active low)
    set bin_reset_n   [expr {$soft_reset_n ? "1" : "0"}]
    # [323:292] : csr_addr (32 bits)
    set bin_csr_addr  [bdi_hex_to_bin $csr_addr 32]
    # [355:324] : csr_wdata (32 bits)
    set bin_csr_wdata [bdi_hex_to_bin $csr_wdata 32]
    # [356]     : csr_we
    set bin_csr_we    [expr {$csr_we ? "1" : "0"}]
    
    # Concatenate in MSB...LSB order for Quartus ISSP write_source_data:
    # Bit 356 down to Bit 0:
    set source_stream "${bin_csr_we}${bin_csr_wdata}${bin_csr_addr}${bin_reset_n}${bin_toggle}${bin_refill}${bin_write}${bin_addr}${bin_data}"
    return $source_stream
}

# ------------------------------------------------------------------------------
# Core Transaction Execution Procedure
# ------------------------------------------------------------------------------
proc bdi_exec_transaction {data_hex addr_hex is_write is_refill {csr_addr "0"} {csr_wdata "0"} {csr_we 0}} {
    # Toggle request bit
    set ::bdi_req_toggle_state [expr {1 - $::bdi_req_toggle_state}]
    
    set source_bits [bdi_pack_source $data_hex $addr_hex $is_write $is_refill $::bdi_req_toggle_state 1 $csr_addr $csr_wdata $csr_we]
    
    # Send to FPGA over JTAG
    write_source_data -instance_index 0 -value $source_bits
    
    # Wait 20 ms for hardware execution & latching
    after 20
    
    # Read back 320-bit telemetry probes
    set probe_bits [read_probe_data -instance_index 0]
    return [bdi_unpack_probes $probe_bits]
}

# ------------------------------------------------------------------------------
# User-Callable API Procedures
# ------------------------------------------------------------------------------

# 1. Write a 256-bit cache line (CPU Write or DRAM Line Refill)
proc bdi_write {addr_hex data_hex {is_refill 0}} {
    set op_name [expr {$is_refill ? "DRAM Refill Write" : "CPU Core Write"}]
    puts "\n>>> Executing $op_name to Address 0x$addr_hex..."
    set res [bdi_exec_transaction $data_hex $addr_hex 1 $is_refill]
    puts [bdi_format_dashboard $res "WRITE TRANSACTION RESULT"]
    return $res
}

# 2. Read from Cache
proc bdi_read {addr_hex} {
    puts "\n>>> Executing Cache Read from Address 0x$addr_hex..."
    # Dummy data 0
    set res [bdi_exec_transaction "0" $addr_hex 0 0]
    puts [bdi_format_dashboard $res "READ TRANSACTION RESULT"]
    return $res
}

# 3. Test Store-to-Load Forwarding (RAW Hazard Bypass)
proc bdi_test_raw_stlf {addr_hex data_hex} {
    puts "\n================================================================================"
    puts "  STORE-TO-LOAD FORWARDING (STLF) RAW HAZARD LIVE DEMONSTRATION                 "
    puts "================================================================================"
    puts "Step 1: Writing data line to Address 0x$addr_hex..."
    bdi_exec_transaction $data_hex $addr_hex 1 0
    
    puts "Step 2: Immediate Read from the exact same Address 0x$addr_hex (RAW Hazard)..."
    set res [bdi_exec_transaction "0" $addr_hex 0 0]
    puts [bdi_format_dashboard $res "STLF RAW HAZARD TELEMETRY"]
    
    if {[dict get $res stlf_fwd] == 1 || [dict get $res latched_stlf] == 1} {
        puts "\n>>> SUCCESS: Store-to-Load Forwarding (STLF) ZERO-STALL BYPASS CONFIRMED!"
        puts ">>> Data forwarded directly from write pipeline to read output with 0 stalls."
    } else {
        puts "\n>>> NOTE: Normal cache hit observed."
    }
    return $res
}

# 4. Set Hardware Associativity via CSR Bank (e.g. 8-Way vs 4-Way)
proc bdi_set_associativity {ways} {
    set val [expr {($ways == 4) ? 2 : 3}]
    puts "\n>>> Configuring Hardware Associativity to ${ways}-Way (CSR Write 0x00 = $val)..."
    set res [bdi_exec_transaction "0" "0" 0 0 "00000000" [format "%08X" $val] 1]
    puts "Associativity updated. Current state: [dict get $res assoc_str]"
    return $res
}

# ------------------------------------------------------------------------------
# Interactive Standalone Demo Runner
# ------------------------------------------------------------------------------
proc bdi_run_interactive_demo {} {
    set hw_list [get_hardware_names]
    if {[llength $hw_list] == 0} {
        puts "ERROR: No USB-Blaster hardware detected."
        return
    }
    set hw [lindex $hw_list 0]
    set dev [lindex [get_device_names -hardware_name $hw] 0]
    
    puts "Connecting to $dev on $hw..."
    start_insystem_source_probe -device_name $dev -hardware_name $hw
    
    puts "\n================================================================================"
    puts "  BDI L2 CACHE LIVE HARDWARE DEMO - INTERACTIVE TEST INJECTION                  "
    puts "================================================================================"
    
    # Test Vector A: Write Base8-Delta1 Compressed Line (Arithmetic Sequence)
    # Line: {0x00000007, 0x00000006, 0x00000005, 0x00000004, 0x00000003, 0x00000002, 0x00000001, 0x00000000}
    set b8d1_data "0000000700000006000000050000000400000003000000020000000100000000"
    bdi_write "00000020" $b8d1_data 1
    
    # Test Vector B: Read back from Address 0x00000020
    bdi_read "00000020"
    
    # Test Vector C: Store-to-Load Forwarding RAW Hazard Test
    set stlf_data "DEADBEEFCAFEBABE0123456789ABCDEF00112233445566778899AABBCCDDEEFF"
    bdi_test_raw_stlf "00000040" $stlf_data
    
    # Test Vector D: Dual Sub-Block Slot B Cohabitation (+16 bytes offset)
    set slot_b_data "1111111122222222333333334444444455555555666666667777777788888888"
    puts "\n>>> Testing Dual Sub-Block Slot B Cohabitation at Address 0x00000030 (+16B)..."
    bdi_write "00000030" $slot_b_data 1
    bdi_read "00000030"
    
    end_insystem_source_probe
    puts "\n>>> Interactive hardware test injection complete."
}

# Run demo if executed directly
if {[info exists quartus(args)] || [string match "*issp_inject_test_vector.tcl" [info script]]} {
    bdi_run_interactive_demo
}
