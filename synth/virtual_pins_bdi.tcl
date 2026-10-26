# ==============================================================================
# Script:      virtual_pins_bdi.tcl
# Design:      l2_bdi_cache_top (BDI-Compressed L2 Cache Core)
# Target:      Intel Cyclone IV GX EP4CGX150DF31C7
# Tool:        Quartus Prime Standard Edition (22.1std or later)
# Author:      Mohammed Gweaa
# Description:
#   Assigns all I/O ports as virtual pins except clock ('clk') to enable
#   accurate core logic synthesis, placement, routing, and timing closure
#   without physical FPGA pin package limitations (999 I/O pins).
# ==============================================================================

post_message -type info "Applying Virtual Pin Constraints to l2_bdi_cache_top..."

# Set all design ports to Virtual Pins
set_instance_assignment -name VIRTUAL_PIN ON -to *

# Exclude clock from virtual pins to preserve clock tree routing & PLL networks
set_instance_assignment -name VIRTUAL_PIN OFF -to clk

# Ensure clock net is assigned to standard 3.3-V LVTTL or 2.5 V
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clk

post_message -type info "Virtual Pin Constraints successfully applied: All I/O virtualized except 'clk'."
