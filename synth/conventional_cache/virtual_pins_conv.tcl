# ==============================================================================
# Script:      virtual_pins_conv.tcl
# Design:      l2_conventional_cache_top (Baseline Uncompressed L2 Cache)
# Target:      Intel Cyclone IV GX EP4CGX150DF31C7
# Tool:        Quartus Prime Standard Edition (22.1std or later)
# Author:      Mohammed Adel Gweaa | University of Tripoli
# Description:
#   Assigns all primary I/O ports as virtual pins except clock ('clk') to enable
#   rigorous, unbiased, and package-independent synthesis comparison
#   against the BDI compressed L2 cache (996 I/O pins virtualized).
# ==============================================================================

post_message -type info "Applying Virtual Pin Constraints to l2_conventional_cache_top I/O ports..."

# Top-Level Inputs
set_instance_assignment -name VIRTUAL_PIN ON -to reset
set_instance_assignment -name VIRTUAL_PIN ON -to request_valid
set_instance_assignment -name VIRTUAL_PIN ON -to address[*]
set_instance_assignment -name VIRTUAL_PIN ON -to write
set_instance_assignment -name VIRTUAL_PIN ON -to is_refill
set_instance_assignment -name VIRTUAL_PIN ON -to data_in[*]
set_instance_assignment -name VIRTUAL_PIN ON -to cpu_mmio_address[*]
set_instance_assignment -name VIRTUAL_PIN ON -to cpu_mmio_wdata[*]
set_instance_assignment -name VIRTUAL_PIN ON -to cpu_mmio_wen
set_instance_assignment -name VIRTUAL_PIN ON -to evict_ack

# Top-Level Outputs
set_instance_assignment -name VIRTUAL_PIN ON -to cpu_mmio_rdata[*]
set_instance_assignment -name VIRTUAL_PIN ON -to data_out[*]
set_instance_assignment -name VIRTUAL_PIN ON -to hit
set_instance_assignment -name VIRTUAL_PIN ON -to miss
set_instance_assignment -name VIRTUAL_PIN ON -to response_valid
set_instance_assignment -name VIRTUAL_PIN ON -to hazard_stall
set_instance_assignment -name VIRTUAL_PIN ON -to dcb_bypass_active
set_instance_assignment -name VIRTUAL_PIN ON -to evict_valid
set_instance_assignment -name VIRTUAL_PIN ON -to evict_address[*]
set_instance_assignment -name VIRTUAL_PIN ON -to evict_data[*]
set_instance_assignment -name VIRTUAL_PIN ON -to dbg_access_count[*]
set_instance_assignment -name VIRTUAL_PIN ON -to dbg_miss_count[*]
set_instance_assignment -name VIRTUAL_PIN ON -to dbg_current_sel[*]
set_instance_assignment -name VIRTUAL_PIN ON -to dbg_epoch_done
set_instance_assignment -name VIRTUAL_PIN ON -to dbg_hazard_count[*]

# Preserve physical clock pin
set_instance_assignment -name VIRTUAL_PIN OFF -to clk
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clk

post_message -type info "Virtual Pin Constraints successfully applied: All I/O virtualized except 'clk'."
