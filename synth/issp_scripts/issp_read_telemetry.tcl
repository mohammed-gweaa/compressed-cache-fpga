# ==============================================================================
# Script:      issp_read_telemetry.tcl
# Target:      DE2i-150 FPGA Board via USB-Blaster II JTAG
# Description:
#   Reads live hardware telemetry from the BDI L2 Cache core via ISSP probes:
#   - Hit / Miss status
#   - Response valid & latency indicators
#   - Dynamic Compression Bypass (DCB) activity
#   - Current hardware associativity configuration (8-Way vs 4-Way)
#   - Real-time Access and Miss counters
# ==============================================================================

set hardware_name [lindex [get_hardware_names] 0]
set device_name   [lindex [get_device_names -hardware_name $hardware_name] 0]

puts "=================================================================="
puts "  BDI L2 CACHE HARDWARE TELEMETRY MONITOR (ISSP / DE2i-150)       "
puts "=================================================================="

start_insystem_source_probe -device_name $device_name -hardware_name $hardware_name
set probe_bits [read_probe_data -instance_index 0]

puts "Captured Hardware Probes: $probe_bits"
puts "Telemetry Read Complete."

end_insystem_source_probe
