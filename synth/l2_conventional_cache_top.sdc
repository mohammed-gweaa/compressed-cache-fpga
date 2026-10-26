# =============================================================================
# Synopsys Design Constraints (SDC) for l2_conventional_cache_top
# Target Device: Intel Cyclone IV GX EP4CGX150DF31C7 (Speed Grade C7)
# Operating Target: 50.00 MHz (Period = 20.000 ns)
# Physical Verification: Slow 1200mV 85C Worst-Case Industrial Corner
# Setup Slack: +5.498 ns (MET) | Fmax = 68.96 MHz
# =============================================================================

create_clock -name clk -period 20.000 [get_ports {clk}]
derive_clock_uncertainty
set_input_delay -clock clk 0.000 [remove_from_collection [all_inputs] [get_ports {clk}]]
set_output_delay -clock clk 0.000 [all_outputs]
