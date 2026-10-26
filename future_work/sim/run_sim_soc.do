# =============================================================================
# Script:   run_sim_soc.do
# Project:  Complete SoC Multi-Level Memory Hierarchy Simulation
# Standard: ModelSim / QuestaSim Simulation Script
# =============================================================================

vlib work
vmap work work

# 1. Compile Core BDI Cache IP Modules
vlog -work work ../../rtl/bdi_cache/l2_ram_block.v
vlog -work work ../../rtl/bdi_cache/l2_bdi_compressor.v
vlog -work work ../../rtl/bdi_cache/l2_bdi_decompressor.v
vlog -work work ../../rtl/bdi_cache/l2_hazard_interlock_unit.v
vlog -work work ../../rtl/bdi_cache/l2_cache_storage_array.v
vlog -work work ../../rtl/bdi_cache/l2_adaptive_power_governor.v
vlog -work work ../../rtl/bdi_cache/l2_csr_control_bank.v
vlog -work work ../../rtl/bdi_cache/l2_pipeline_input_stage.v
vlog -work work ../../rtl/bdi_cache/l2_bdi_cache_top.v

# 2. Compile SoC Memory Hierarchy Modules
vlog -work work ../rtl/l1_dcache_core.v
vlog -work work ../rtl/l1_l2_bus_arbiter.v
vlog -work work ../rtl/l2_hardware_prefetcher.v
vlog -work work ../rtl/l2_cache_controller.v
vlog -work work ../rtl/soc_cache_subsystem.v

# 3. Compile Verification Testbenches
vlog -work work ../tb/tb_l2_cache_controller.v
vlog -work work ../tb/tb_soc_cache_random_fuzz.v
vlog -work work ../tb/tb_soc_cache_subsystem.v

# 4. Run Dedicated Controller & MSHR Unit Testbench
vsim -c -t 1ps -onfinish stop work.tb_l2_cache_controller
run -all

# 5. Run Random Memory Stress & Fuzzing Testbench
vsim -c -t 1ps -onfinish stop work.tb_soc_cache_random_fuzz
run -all

# 6. Run Complete Multi-Level SoC Hierarchy Integration Testbench
vsim -c -t 1ps -onfinish stop work.tb_soc_cache_subsystem
run -all

quit -f
