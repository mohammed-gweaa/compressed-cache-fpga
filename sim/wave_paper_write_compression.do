# =============================================================================
# Waveform 1: Write Pipeline, Multi-Profile BDI Compression & Way-Halting
# Paper Figure: Figure 9 (Academic Publication Waveform A)
# Style: Pure Natural Green Waveform (EDA Industry Standard - Zero Custom Colors)
# Features:
#   1. Sequential write enable pulses in the SAME set: we1_A then we1_B (Dual Sub-Block Packing).
#   2. Dynamic runtime transition of associativity: 8-Way (11) -> 4-Way (10) at t=510ns.
#   3. Immediate runtime halting and masking of Ways 5 to 8 for dynamic power saving.
# =============================================================================

vlib work
vmap work work

# 1. Compile Design and Testbench
vlog -work work ../rtl/l2_bdi_compressor.v
vlog -work work ../rtl/l2_bdi_decompressor.v
vlog -work work ../rtl/l2_hazard_interlock_unit.v
vlog -work work ../rtl/l2_csr_control_bank.v
vlog -work work ../rtl/l2_adaptive_power_governor.v
vlog -work work ../rtl/l2_ram_block.v
vlog -work work ../rtl/l2_cache_storage_array.v
vlog -work work ../rtl/l2_pipeline_input_stage.v
vlog -work work ../rtl/l2_bdi_cache_top.v
vlog -work work ../rtl/l2_conventional_cache_top.v
vlog -work work ../tb/tb_paper_journal_artifacts.v

# 2. Launch Simulation with full signal visibility
vsim -voptargs=+acc work.tb_paper_journal_artifacts

# Clear old wave and add configured signals
onerror {resume}
delete wave *

# --- 1. CPU WRITE REQUEST INTERFACE ---
add wave -noupdate -divider {=== 1. CPU WRITE REQUEST INTERFACE ===}
add wave -noupdate -label {clk}                                   /tb_paper_journal_artifacts/clk
add wave -noupdate -label {reset_n}                               /tb_paper_journal_artifacts/reset
add wave -noupdate -label {req_valid}                             /tb_paper_journal_artifacts/req_valid
add wave -noupdate -label {req_write}                             /tb_paper_journal_artifacts/req_write
add wave -noupdate -radix hexadecimal -label {req_addr [31:0]}    /tb_paper_journal_artifacts/req_addr
add wave -noupdate -radix hexadecimal -label {uncompressed_data_in [255:0]} /tb_paper_journal_artifacts/req_wdata

# --- 2. 4-STAGE BDI COMPRESSION ENGINE INTERNALS ---
add wave -noupdate -divider {=== 2. BDI COMPRESSION ENGINE INTERNALS ===}
add wave -noupdate -radix hexadecimal -label {s1_base8_candidate [63:0]}   /tb_paper_journal_artifacts/uut_bdi/compressor/s1_base8
add wave -noupdate -radix hexadecimal -label {s1_base4_candidate [31:0]}   /tb_paper_journal_artifacts/uut_bdi/compressor/s1_base4
add wave -noupdate -radix binary      -label {compress_marks [14:0]}        /tb_paper_journal_artifacts/uut_bdi/compressor/compress_marks
add wave -noupdate -radix unsigned    -label {compress_type [2:0] (1=B8D1, 4=B4D1, 5=SameWord, 0=Type0)} /tb_paper_journal_artifacts/uut_bdi/compressor/compress_type
add wave -noupdate -radix hexadecimal -label {compressed_payload_out [255:0]} /tb_paper_journal_artifacts/uut_bdi/compressor/compressed_data
add wave -noupdate -label {dcb_bypass_active}                               /tb_paper_journal_artifacts/uut_bdi/compressor/dcb_bypass_active

# --- 3. DUAL SUB-BLOCK ALLOCATION (SAME SET) ---
add wave -noupdate -divider {=== 3. DUAL SUB-BLOCK ALLOCATION (SAME SET) ===}
add wave -noupdate -label {write_commit_pulse}                    /tb_paper_journal_artifacts/uut_bdi/write_commit_now
add wave -noupdate -radix hexadecimal -label {array_target_addr [31:0]}     /tb_paper_journal_artifacts/uut_bdi/cache_addr
add wave -noupdate -radix hexadecimal -label {array_write_data [255:0]}     /tb_paper_journal_artifacts/uut_bdi/cache_din
add wave -noupdate -label {way1_write_half_A (Line 1 Allocated)}  /tb_paper_journal_artifacts/uut_bdi/cache_array/we1_A
add wave -noupdate -label {way1_write_half_B (Line 2 Packed)}     /tb_paper_journal_artifacts/uut_bdi/cache_array/we1_B

# --- 4. RUNTIME ASSOCIATIVITY TRANSITION & WAY-HALTING ---
add wave -noupdate -divider {=== 4. RUNTIME TRANSITION & WAY-HALTING ===}
add wave -noupdate -radix binary      -label {associativity_csr [1:0] (11=8Way, 10=4Way)} /tb_paper_journal_artifacts/uut_bdi/dbg_current_sel
add wave -noupdate -radix binary      -label {active_associativity_state [1:0]} /tb_paper_journal_artifacts/uut_bdi/cache_array/selection_signal_d
add wave -noupdate -label {way1_match (Active_in_4W)}             /tb_paper_journal_artifacts/uut_bdi/cache_array/match1
add wave -noupdate -label {way5_halted (Disabled_in_4W)}          /tb_paper_journal_artifacts/uut_bdi/cache_array/match5
add wave -noupdate -label {way6_halted (Disabled_in_4W)}          /tb_paper_journal_artifacts/uut_bdi/cache_array/match6
add wave -noupdate -label {way7_halted (Disabled_in_4W)}          /tb_paper_journal_artifacts/uut_bdi/cache_array/match7
add wave -noupdate -label {way8_halted (Disabled_in_4W)}          /tb_paper_journal_artifacts/uut_bdi/cache_array/match8

# Run simulation
run 620ns

# Layout Configuration & Zooming
configure wave -namecolwidth 320
configure wave -valuecolwidth 180
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

wave zoomrange 110ns 580ns
