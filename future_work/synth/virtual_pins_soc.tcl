# ==============================================================================
# Script:      virtual_pins_soc.tcl
# Design:      soc_cache_subsystem (Full Multi-Level Memory Hierarchy)
# Target:      Intel Cyclone IV GX EP4CGX150DF31C7
# Tool:        Quartus Prime Standard Edition (22.1std or later)
# Author:      Mohammed Gweaa
# Description:
#   Assigns all I/O ports as virtual pins except clock ('clk') to enable
#   synthesis of the complete multi-level SoC subsystem (1,172 I/O pins).
# ==============================================================================

post_message -type info "Applying Virtual Pin Constraints to soc_cache_subsystem..."

# Set all design ports to Virtual Pins
set_instance_assignment -name VIRTUAL_PIN ON -to *

# Exclude clock from virtual pins
set_instance_assignment -name VIRTUAL_PIN OFF -to clk

# Set clock standard
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clk

post_message -type info "Virtual Pin Constraints successfully applied: All I/O virtualized except 'clk'."
