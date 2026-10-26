# ==============================================================================
# Script:      virtual_pins_conv.tcl
# Design:      l2_conventional_cache_top (Baseline Uncompressed L2 Cache)
# Target:      Intel Cyclone IV GX EP4CGX150DF31C7
# Tool:        Quartus Prime Standard Edition (22.1std or later)
# Author:      Mohammed Gweaa
# Description:
#   Assigns all I/O ports as virtual pins except clock ('clk') to enable
#   rigorous, unbiased, and package-independent synthesis comparison
#   against the BDI compressed L2 cache (996 I/O pins virtualized).
# ==============================================================================

post_message -type info "Applying Virtual Pin Constraints to l2_conventional_cache_top..."

# Set all design ports to Virtual Pins
set_instance_assignment -name VIRTUAL_PIN ON -to *

# Exclude clock from virtual pins to preserve clock tree routing
set_instance_assignment -name VIRTUAL_PIN OFF -to clk

# Ensure clock net is assigned to standard 3.3-V LVTTL or 2.5 V
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clk

post_message -type info "Virtual Pin Constraints successfully applied: All I/O virtualized except 'clk'."
