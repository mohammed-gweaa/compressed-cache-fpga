# =============================================================================
# Waveform Configuration: wave_comprehensive_summary.do
# Project:     High-Performance BDI Compressed L2 Cache Subsystem
# Author:      Mohammed Gweaa | University of Tripoli
# Target:      Publication & Thesis Deliverables / High-Resolution PDF Export
# Total Time:  5070 ns (5.07 us) | Clock Period: 20 ns (50 MHz) | Cycles: ~254
# =============================================================================

vlib work
vmap work work

# 1. Compile Core Design & Testbench
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
vlog -work work ../tb/bdi_cache/tb_l2_bdi_cache_top.v

# 2. Launch Simulation with full signal visibility
vsim -voptargs=+acc -t 1ps work.tb_l2_bdi_cache_top

onerror {resume}
catch {delete wave *}

# =============================================================================
# GROUP 1: EXECUTIVE VERIFICATION TRACKER (17/17 ALL TESTS PASSED)
# =============================================================================
add wave -noupdate -divider {=== 1. TEST TRACKER & STATUS (17/17) ===}
add wave -noupdate -color {Yellow} -radix unsigned    -label {Test Case # (1 to 17)}         /tb_l2_bdi_cache_top/test_num
add wave -noupdate -color {Cyan}   -radix ascii       -label {Active Test Description}       /tb_l2_bdi_cache_top/test_name
add wave -noupdate -color {Green}  -radix unsigned    -label {Total Tests Passed}            /tb_l2_bdi_cache_top/pass_count
add wave -noupdate -color {Red}    -radix unsigned    -label {Total Tests Failed (MUST BE 0)} /tb_l2_bdi_cache_top/fail_count

# =============================================================================
# GROUP 2: MASTER CLOCK & RESET
# =============================================================================
add wave -noupdate -divider {=== 2. MASTER CLOCK & RESET ===}
add wave -noupdate -color {White}  -label {50MHz Clock (Period = 20ns)}                     /tb_l2_bdi_cache_top/clk
add wave -noupdate -color {Orange} -label {Active-Low Reset}                                 /tb_l2_bdi_cache_top/reset

# =============================================================================
# GROUP 3: CPU REQUEST INTERFACE (INPUTS)
# =============================================================================
add wave -noupdate -divider {=== 3. CPU REQUEST INTERFACE ===}
add wave -noupdate -color {Gold}   -label {Request Valid}                                    /tb_l2_bdi_cache_top/request_valid
add wave -noupdate -color {Gold}   -label {Write Enable (1=Write, 0=Read)}                   /tb_l2_bdi_cache_top/write
add wave -noupdate -color {Gold}   -label {Refill Line Strobe}                               /tb_l2_bdi_cache_top/is_refill
add wave -noupdate -radix hexadecimal -label {Request Address [31:0]}                        /tb_l2_bdi_cache_top/address
add wave -noupdate -radix hexadecimal -label {Write Data In [255:0]}                         /tb_l2_bdi_cache_top/data_in

# =============================================================================
# GROUP 4: L2 CACHE RESPONSE & 5-CYCLE READ LATENCY (OUTPUTS)
# =============================================================================
add wave -noupdate -divider {=== 4. L2 CACHE RESPONSE & 5-CYCLE READ HIT ===}
add wave -noupdate -color {Green}  -label {Response Valid Strobe}                            /tb_l2_bdi_cache_top/response_valid
add wave -noupdate -color {Green}  -label {Cache Hit (1=Hit)}                                /tb_l2_bdi_cache_top/hit
add wave -noupdate -color {Red}    -label {Cache Miss (1=Miss)}                              /tb_l2_bdi_cache_top/miss
add wave -noupdate -radix hexadecimal -label {Reconstituted Data Out [255:0]}                /tb_l2_bdi_cache_top/data_out

# =============================================================================
# GROUP 5: STORE-TO-LOAD FORWARDING (STLF) ZERO-STALL BYPASS
# =============================================================================
add wave -noupdate -divider {=== 5. STORE-TO-LOAD FORWARDING (STLF) ===}
add wave -noupdate -color {Red}    -label {Hazard Stall (ZERO STALL = 0)}                    /tb_l2_bdi_cache_top/hazard_stall
add wave -noupdate -radix unsigned -label {Forward Stage Sel (1=S1, 2=S2, 3=S3)}             /tb_l2_bdi_cache_top/uut/fwd_stage_sel
add wave -noupdate -radix hexadecimal -label {STLF Bypassed Data [255:0]}                    /tb_l2_bdi_cache_top/uut/fwd_selected_data

# =============================================================================
# GROUP 6: BDI COMPRESSION & DUAL SUB-BLOCK COHABITATION
# =============================================================================
add wave -noupdate -divider {=== 6. BDI COMPRESSION & COHABITATION ===}
add wave -noupdate -radix unsigned -label {BDI Profile Type (1=B8D1, 2=B8D2, 4=B4D1, 0=None)} /tb_l2_bdi_cache_top/uut/compressor/compress_type
add wave -noupdate -color {Orange} -label {DCB Bypass Active (Incompressible)}              /tb_l2_bdi_cache_top/dcb_bypass_active
add wave -noupdate -color {Cyan}   -label {Way 1 Write Half A (Slot A Packed)}               /tb_l2_bdi_cache_top/uut/cache_array/we1_A
add wave -noupdate -color {Cyan}   -label {Way 1 Write Half B (Slot B Packed)}               /tb_l2_bdi_cache_top/uut/cache_array/we1_B

# =============================================================================
# GROUP 7: ADAPTIVE POWER GOVERNANCE & TELEMETRY
# =============================================================================
add wave -noupdate -divider {=== 7. POWER GOVERNOR & RECONFIGURABLE WAYS ===}
add wave -noupdate -radix binary   -label {Active Associativity Sel (11=8W, 10=4W, 00=1W)}   /tb_l2_bdi_cache_top/dbg_current_sel
add wave -noupdate -label {Hardware Prefetcher Enable}                                       /tb_l2_bdi_cache_top/prefetch_en
add wave -noupdate -label {Non-Blocking MSHR Enable}                                         /tb_l2_bdi_cache_top/mshr_en

# =============================================================================
# GROUP 8: SAFE ATOMIC DRAM EVICTION INTERFACE
# =============================================================================
add wave -noupdate -divider {=== 8. DRAM EVICTION & WRITEBACK ===}
add wave -noupdate -color {Yellow} -label {Evict Request Strobe}                             /tb_l2_bdi_cache_top/evict_valid
add wave -noupdate -radix hexadecimal -label {Evict DRAM Address}                            /tb_l2_bdi_cache_top/evict_address
add wave -noupdate -color {Green}  -label {DRAM Controller Ack}                              /tb_l2_bdi_cache_top/evict_ack

# =============================================================================
# 3. RUN SIMULATION FOR EXACT DURATION (5070 ns)
# =============================================================================
run 5070ns

# Layout Configuration & Grid Formatting
configure wave -namecolwidth 320
configure wave -valuecolwidth 180
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

# Set Visual Zoom to Fit Complete Simulation
wave zoomfull
