# ==============================================================================
# Script:      virtual_pins_bdi.tcl
# Design:      l2_bdi_cache_top (BDI-Compressed L2 Cache Core)
# Target:      Intel Cyclone IV GX EP4CGX150DF31C7
# Tool:        Quartus Prime Standard Edition (22.1std or later)
# Author:      Mohammed Adel Gweaa | University of Tripoli
# Description:
#   Assigns all primary I/O ports as virtual pins except clock ('clk') to enable
#   accurate core logic synthesis, placement, routing, and timing closure
#   without physical FPGA pin package limitations (999 I/O pins).
# ==============================================================================

post_message -type info "Applying Virtual Pin Constraints to l2_bdi_cache_top I/O ports..."

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
set_instance_assignment -name VIRTUAL_PIN ON -to prefetch_en
set_instance_assignment -name VIRTUAL_PIN ON -to mshr_en
set_instance_assignment -name VIRTUAL_PIN ON -to workload_mode

# Preserve physical clock pin
set_instance_assignment -name VIRTUAL_PIN OFF -to clk
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clk

post_message -type info "Virtual Pin Constraints successfully applied: All I/O virtualized except 'clk'."
