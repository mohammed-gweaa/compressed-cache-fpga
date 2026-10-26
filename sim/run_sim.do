# =============================================================================
# Script:   run_sim.do
# Project:  High-Performance BDI Compressed L2 Cache Subsystem (Pure L2 Cache)
# Standard: ModelSim / QuestaSim Simulation Script
# =============================================================================

vlib work
vmap work work

# 1. Compile Proposed BDI Compressed L2 Cache Subsystem
vlog -work work ../rtl/bdi_cache/l2_bdi_compressor.v
vlog -work work ../rtl/bdi_cache/l2_bdi_decompressor.v
vlog -work work ../rtl/bdi_cache/l2_hazard_interlock_unit.v
vlog -work work ../rtl/bdi_cache/l2_csr_control_bank.v
vlog -work work ../rtl/bdi_cache/l2_adaptive_power_governor.v
vlog -work work ../rtl/bdi_cache/l2_ram_block.v
vlog -work work ../rtl/bdi_cache/l2_cache_storage_array.v
vlog -work work ../rtl/bdi_cache/l2_pipeline_input_stage.v
vlog -work work ../rtl/bdi_cache/l2_bdi_cache_top.v

# 2. Compile Baseline Conventional L2 Cache
vlog -work work ../rtl/conventional_cache/l2_conventional_cache_top.v

# 3. Compile Physical Board Demo Wrapper
vlog -work work ../rtl/board_demo/l2_bdi_cache_board_demo.v

# 4. Compile Verification Testbenches
vlog -work work ../tb/bdi_cache/tb_l2_bdi_cache_top.v
vlog -work work ../tb/paper_artifacts/tb_paper_journal_artifacts.v
vlog -work work ../tb/comparative/tb_l2_comparative_stress_benchmark.v

# 3. Run Standalone L2 Core Testbench (STLF & 5-Cycle Latency)
vsim -c -t 1ps -onfinish stop work.tb_l2_bdi_cache_top
run -all

# 4. Run Journal Artifacts Verification
vsim -c -t 1ps -onfinish stop work.tb_paper_journal_artifacts
run -all

# 5. Run Head-to-Head Comparative Stress Benchmark
vsim -c -t 1ps -onfinish stop work.tb_l2_comparative_stress_benchmark
run -all

quit -f
