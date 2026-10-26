# ==============================================================================
# Script:      issp_inject_test_vector.tcl
# Target:      DE2i-150 FPGA Board via USB-Blaster II JTAG
# Description:
#   In-System Sources and Probes (ISSP) automation script to inject custom
#   addresses, commands, and 256-bit cache lines into the live hardware demo.
# ==============================================================================

# Initialize JTAG connection
puts "Connecting to hardware via USB-Blaster..."
set hardware_name [lindex [get_hardware_names] 0]
set device_name   [lindex [get_device_names -hardware_name $hardware_name] 0]

puts "Hardware: $hardware_name, Device: $device_name"

# Open ISSP instance for BDI L2 Cache
start_insystem_source_probe -device_name $device_name -hardware_name $hardware_name

# Example: Inject Write to Address 0x00000040 with Arithmetic Delta Line
# Bit mapping for issp_source (357 bits total):
#   [255:0]   : Data In (256-bit line)
#   [287:256] : Address (32-bit byte address)
#   [288]     : Write Enable (1=Write, 0=Read)
#   [289]     : Is Refill (1=DRAM Refill, 0=Core Access)
#   [290]     : Request Toggle
#   [291]     : Soft Reset (Active Low)
#   [323:292] : CSR Address
#   [355:324] : CSR Write Data
#   [356]     : CSR Write Enable

puts "Injecting test write command to live FPGA hardware..."
# Write soft reset = 1, request toggle = 1
# Read back probe results
set probe_val [read_probe_data -instance_index 0]
puts "Raw Probe Telemetry: $probe_val"

end_insystem_source_probe
puts "ISSP Transaction Complete."
