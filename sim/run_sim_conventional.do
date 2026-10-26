# =============================================================================
# Script:   run_sim_conventional.do
# Project:  Conventional Baseline L2 Cache (Uncompressed 8-Way Tree-PLRU)
# Standard: ModelSim / QuestaSim Simulation Script
# =============================================================================

vlib work
vmap work work

# 1. Compile Conventional L2 Cache Core
vlog -work work ../rtl/conventional_cache/l2_conventional_cache_top.v

# 2. Compile Verification Testbenches
vlog -work work ../tb/conventional_cache/tb_l2_conventional_cache_top.v

# 3. Run Standalone Conventional Cache Testbench
vsim -c -t 1ps -onfinish stop work.tb_l2_conventional_cache_power
run -all

quit -f
