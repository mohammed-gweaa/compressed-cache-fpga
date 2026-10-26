# =============================================================================
# Waveform 2: 5-Cycle Read Hit Latency, Decompression Reconstitution & Zero-Stall STLF
# Paper Figure: Figure 10 (Academic Publication Waveform B)
# Style: Pure Natural Green Waveform (EDA Industry Standard - Zero Custom Colors)
# =============================================================================

vlib work
vmap work work

# 1. Compile Design and Testbench
vlog -work work ../rtl/bdi_cache/l2_bdi_compressor.v
vlog -work work ../rtl/bdi_cache/l2_bdi_decompressor.v
vlog -work work ../rtl/bdi_cache/l2_hazard_interlock_unit.v
vlog -work work ../rtl/bdi_cache/l2_csr_control_bank.v
vlog -work work ../rtl/bdi_cache/l2_adaptive_power_governor.v
vlog -work work ../rtl/bdi_cache/l2_ram_block.v
vlog -work work ../rtl/bdi_cache/l2_cache_storage_array.v
vlog -work work ../rtl/bdi_cache/l2_pipeline_input_stage.v
vlog -work work ../rtl/bdi_cache/l2_bdi_cache_top.v
vlog -work work ../rtl/conventional_cache/l2_conventional_cache_top.v
vlog -work work ../tb/paper_artifacts/tb_paper_journal_artifacts.v

# 2. Launch Simulation with full signal visibility
vsim -voptargs=+acc work.tb_paper_journal_artifacts

# Clear old wave and add configured signals
onerror {resume}
delete wave *

# --- 1. CPU READ REQUEST INTERFACE ---
add wave -noupdate -divider {=== 1. CPU READ REQUEST INTERFACE ===}
add wave -noupdate -label {clk}                                   /tb_paper_journal_artifacts/clk
add wave -noupdate -label {req_valid}                             /tb_paper_journal_artifacts/req_valid
add wave -noupdate -label {req_write (0=Read, 1=Write)}           /tb_paper_journal_artifacts/req_write
add wave -noupdate -radix hexadecimal -label {read_addr [31:0]}   /tb_paper_journal_artifacts/req_addr

# --- 2. DETERMINISTIC 5-CYCLE READ HIT PROGRESSION ---
add wave -noupdate -divider {=== 2. 5-CYCLE READ HIT & DECOMPRESSION ===}
add wave -noupdate -label {cycle1_read_admitted}                  /tb_paper_journal_artifacts/uut_bdi/read_admitted
add wave -noupdate -radix binary      -label {read_valid_pipe [3:0] (Shift_Pipeline)} /tb_paper_journal_artifacts/uut_bdi/read_valid_pipe
add wave -noupdate -label {cycle3_tag_hit_raw}                    /tb_paper_journal_artifacts/uut_bdi/hit_stage
add wave -noupdate -radix hexadecimal -label {cycle3_compressed_from_sram [255:0]} /tb_paper_journal_artifacts/uut_bdi/compressed_data_stage
add wave -noupdate -radix unsigned    -label {cycle3_compress_type [2:0] (1=B8D1)}   /tb_paper_journal_artifacts/uut_bdi/compress_type_stage
add wave -noupdate -radix hexadecimal -label {cycle4_decompressed_comb [255:0]}     /tb_paper_journal_artifacts/uut_bdi/decompressed_stage
add wave -noupdate -label {cycle5_resp_valid (Pulse)}             /tb_paper_journal_artifacts/bdi_resp_valid
add wave -noupdate -label {cycle5_hit_verified}                   /tb_paper_journal_artifacts/bdi_hit
add wave -noupdate -radix hexadecimal -label {cycle5_verified_data_out [255:0]}      /tb_paper_journal_artifacts/bdi_data_out

# --- 3. ZERO-STALL STLF RAW BYPASS RESOLUTION ---
add wave -noupdate -divider {=== 3. ZERO-STALL STLF RAW BYPASS RESOLUTION ===}
add wave -noupdate -label {bdi_hazard_stall (ZERO STALL = 0)}     /tb_paper_journal_artifacts/bdi_hazard_stall
add wave -noupdate -label {conv_hazard_stall (STALLED = 1)}       /tb_paper_journal_artifacts/conv_hazard_stall
add wave -noupdate -radix unsigned    -label {stlf_fwd_stage_sel [2:0] (1=Match_S1)} /tb_paper_journal_artifacts/uut_bdi/fwd_stage_sel
add wave -noupdate -radix hexadecimal -label {stlf_bypassed_data_out [255:0]}        /tb_paper_journal_artifacts/uut_bdi/fwd_selected_data

# Run simulation
run 900ns

# Layout Configuration & Zooming
configure wave -namecolwidth 310
configure wave -valuecolwidth 180
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

wave zoomrange 460ns 880ns
