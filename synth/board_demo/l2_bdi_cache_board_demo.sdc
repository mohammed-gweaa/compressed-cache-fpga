# =============================================================================
# Synopsys Design Constraints (SDC) for l2_bdi_cache_board_demo
# Target Device: Terasic DE2i-150 (Intel Cyclone IV GX EP4CGX150DF31C7)
# Module:        l2_bdi_cache_board_demo
# Operating Target: 50.00 MHz (Period = 20.000 ns) on CLOCK_50
# Author:        Mohammed Adel Gweaa | University of Tripoli
# =============================================================================

# Primary 50 MHz Master Oscillator from On-Board Crystal (PIN_AJ16)
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
derive_clock_uncertainty

# Input Delays for Pushbuttons and Slide Switches (Board Travel Time: 3.0 ns)
set_input_delay -clock CLOCK_50 3.000 [get_ports {KEY[*] SW[*]}]

# Output Delays for Visual Displays (LEDs and 7-Segment Common-Anode Displays: 3.0 ns)
set_output_delay -clock CLOCK_50 3.000 [get_ports {HEX*[*] LEDG[*] LEDR[*]}]

# False paths for asynchronous reset deassertion
set_false_path -from [get_ports {KEY[3] SW[17]}] -to *
