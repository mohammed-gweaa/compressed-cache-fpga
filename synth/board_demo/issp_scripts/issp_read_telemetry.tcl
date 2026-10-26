# ==============================================================================
# Script:      issp_read_telemetry.tcl
# Target:      Terasic DE2i-150 FPGA Board (Intel Cyclone IV GX EP4CGX150DF31C7)
# Module:      l2_bdi_cache_board_demo (Instance: "BDIL2")
# Author:      Mohammed Adel Gweaa | University of Tripoli
# Description:
#   Reads real-time hardware telemetry from the BDI L2 Cache core via ISSP probes
#   over the USB-Blaster JTAG cable. Unpacks all 320 bits into a formatted
#   live engineering dashboard.
#
# Usage:
#   quartus_stp -t issp_read_telemetry.tcl
# ==============================================================================

# Locate script directory and source helper library
set script_dir [file dirname [info script]]
source [file join $script_dir "issp_signal_map.tcl"]

puts "================================================================================"
puts "  CONNECTING TO DE2i-150 FPGA VIA USB-BLASTER JTAG...                           "
puts "================================================================================"

# Enumerate JTAG chain
set hw_list [get_hardware_names]
if {[llength $hw_list] == 0} {
    puts "ERROR: No Altera/Intel USB-Blaster hardware detected!"
    puts "Please verify that the USB-Blaster cable is plugged in and drivers are loaded."
    exit 1
}
set hardware_name [lindex $hw_list 0]
set device_list [get_device_names -hardware_name $hardware_name]
if {[llength $device_list] == 0} {
    puts "ERROR: No JTAG devices detected on hardware $hardware_name!"
    exit 1
}
set device_name [lindex $device_list 0]

puts "Hardware: $hardware_name"
puts "Target Device: $device_name (EP4CGX150)"
puts "Acquiring In-System Sources and Probes (ISSP) bus..."

# Open ISSP Session
start_insystem_source_probe -device_name $device_name -hardware_name $hardware_name

# Read 320-bit probe data from instance 0 (BDIL2)
set raw_probe_bits [read_probe_data -instance_index 0]

# Close ISSP Session
end_insystem_source_probe

# Unpack and render dashboard
set telemetry_dict [bdi_unpack_probes $raw_probe_bits]
puts [bdi_format_dashboard $telemetry_dict "LIVE HARDWARE TELEMETRY REPORT"]
puts "Telemetry acquisition successful."
