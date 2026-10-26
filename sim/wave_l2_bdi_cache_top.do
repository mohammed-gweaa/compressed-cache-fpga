# =============================================================================
# Waveform Configuration: wave_l2_bdi_cache_top.do
# Project:     High-Performance BDI Compressed L2 Cache Subsystem
# Author:      Mohammed Gweaa
# Target:      Intel Cyclone IV / ModelSim & QuestaSim GUI
# Description: Exhaustive, fully annotated hierarchical waveform display
#              covering all 17 architectural scenarios and every internal probe.
# =============================================================================

# 1. Ensure Library and Compile Core Subsystem
vlib work
vmap work work

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

# 2. Start Simulation with Full Signal Visibility
vsim -voptargs=+acc -t 1ps work.tb_l2_bdi_cache_top

onerror {resume}
catch {delete wave *}

# =============================================================================
# 1. VERIFICATION BANNER & TEST SEQUENCE TRACKER
# =============================================================================
add wave -noupdate -divider {=== 1. TEST TRACKER & STATUS ===}
add wave -noupdate -radix unsigned    -label {Test Number}                 /tb_l2_bdi_cache_top/test_num
add wave -noupdate -radix ascii       -label {Active Test Description}     /tb_l2_bdi_cache_top/test_name
add wave -noupdate -radix unsigned    -label {Tests Passed}                /tb_l2_bdi_cache_top/pass_count
add wave -noupdate -radix unsigned    -label {Tests Failed}                /tb_l2_bdi_cache_top/fail_count
add wave -noupdate -radix unsigned    -label {Read Latency Cycles}         /tb_l2_bdi_cache_top/cycle_counter

# =============================================================================
# 2. MASTER CLOCK & SYSTEM RESET
# =============================================================================
add wave -noupdate -divider {=== 2. CLOCK & RESET ===}
add wave -noupdate -label {50MHz Clock}                                    /tb_l2_bdi_cache_top/clk
add wave -noupdate -label {Active-Low Reset}                              /tb_l2_bdi_cache_top/reset

# =============================================================================
# 3. CORE REQUEST INTERFACE (CPU / MEMORY BUS)
# =============================================================================
add wave -noupdate -divider {=== 3. REQUEST INTERFACE ===}
add wave -noupdate -label {Request Valid}                                  /tb_l2_bdi_cache_top/request_valid
add wave -noupdate -radix hexadecimal -label {Request Address [31:0]}      /tb_l2_bdi_cache_top/address
add wave -noupdate -label {Write Enable (1=Write, 0=Read)}                /tb_l2_bdi_cache_top/write
add wave -noupdate -label {Refill Line Flag}                              /tb_l2_bdi_cache_top/is_refill
add wave -noupdate -radix hexadecimal -label {Request Data In [255:0]}     /tb_l2_bdi_cache_top/data_in

# =============================================================================
# 4. STORE-TO-LOAD FORWARDING (STLF) & RAW HAZARD INTERLOCK
# =============================================================================
add wave -noupdate -divider {=== 4. STLF BYPASS & RAW INTERLOCK ===}
add wave -noupdate -label {Hazard Stall (Zero-Stall = 0)}                  /tb_l2_bdi_cache_top/hazard_stall
add wave -noupdate -label {STLF Bypass Trigger (fwd_valid)}               /tb_l2_bdi_cache_top/uut/fwd_valid
add wave -noupdate -radix unsigned -label {Forward Stage (1:S1..5:Commit)} /tb_l2_bdi_cache_top/uut/fwd_stage_sel
add wave -noupdate -radix hexadecimal -label {STLF Forwarded Data}        /tb_l2_bdi_cache_top/uut/fwd_selected_data
add wave -noupdate -label {Write S1 Valid}                                /tb_l2_bdi_cache_top/uut/w_s1_valid
add wave -noupdate -label {Write S2 Valid}                                /tb_l2_bdi_cache_top/uut/w_s2_valid
add wave -noupdate -label {Write S3 Valid}                                /tb_l2_bdi_cache_top/uut/w_s3_valid
add wave -noupdate -label {Write S4 Valid}                                /tb_l2_bdi_cache_top/uut/w_s4_valid
add wave -noupdate -label {Write Commit Valid}                            /tb_l2_bdi_cache_top/uut/w_commit_valid
add wave -noupdate -radix unsigned -label {Cumulative STLF Events}         /tb_l2_bdi_cache_top/uut/hazard_detector/forward_event_count

# =============================================================================
# 5. PIPELINED BDI COMPRESSOR ENGINE (4 STAGES + DCB)
# =============================================================================
add wave -noupdate -divider {=== 5. BDI COMPRESSION ENGINE ===}
add wave -noupdate -radix hexadecimal -label {Compressor Input (256-bit)}  /tb_l2_bdi_cache_top/uut/compressor/uncompressed_data
add wave -noupdate -label {Zero Line Detected}                             /tb_l2_bdi_cache_top/uut/compressor/s1_is_zero
add wave -noupdate -label {Same-Word Pattern Detected}                     /tb_l2_bdi_cache_top/uut/compressor/s1_is_same_word
add wave -noupdate -label {B8-Delta1 Valid (Type 1)}                       /tb_l2_bdi_cache_top/uut/compressor/s2_c1_valid
add wave -noupdate -label {B8-Delta2 Valid (Type 2)}                       /tb_l2_bdi_cache_top/uut/compressor/s2_c2_valid
add wave -noupdate -label {B4-Delta1 Valid (Type 4)}                       /tb_l2_bdi_cache_top/uut/compressor/s2_c4_valid
add wave -noupdate -radix unsigned -label {Winning Profile (0..5)}         /tb_l2_bdi_cache_top/uut/compressor/compress_type
add wave -noupdate -radix hexadecimal -label {Compressed Payload}          /tb_l2_bdi_cache_top/uut/compressor/compressed_data
add wave -noupdate -radix binary -label {Delta Sign Marks [14:0]}          /tb_l2_bdi_cache_top/uut/compressor/compress_marks
add wave -noupdate -label {DCB Filter Active (Dynamic Bypass)}             /tb_l2_bdi_cache_top/dcb_bypass_active

# =============================================================================
# 6. CACHE STORAGE ARRAY: TAG MATCHING & MULTI-WAY SELECTION
# =============================================================================
add wave -noupdate -divider {=== 6. TAG LOOKUP & WAY SELECTION ===}
add wave -noupdate -radix unsigned -label {Set Index [5:0]}                /tb_l2_bdi_cache_top/uut/cache_array/index
add wave -noupdate -radix hexadecimal -label {Target Tag [23:0]}           /tb_l2_bdi_cache_top/uut/cache_array/tag_d
add wave -noupdate -radix binary -label {Associativity Mode (1W..8W)}     /tb_l2_bdi_cache_top/uut/cache_array/selection_signal_d
add wave -noupdate -label {Way 1 Match A}                                  /tb_l2_bdi_cache_top/uut/cache_array/match1_A
add wave -noupdate -label {Way 1 Match B}                                  /tb_l2_bdi_cache_top/uut/cache_array/match1_B
add wave -noupdate -label {Way 2 Match A}                                  /tb_l2_bdi_cache_top/uut/cache_array/match2_A
add wave -noupdate -label {Way 2 Match B}                                  /tb_l2_bdi_cache_top/uut/cache_array/match2_B
add wave -noupdate -label {Way 3 Match A}                                  /tb_l2_bdi_cache_top/uut/cache_array/match3_A
add wave -noupdate -label {Way 3 Match B}                                  /tb_l2_bdi_cache_top/uut/cache_array/match3_B
add wave -noupdate -label {Way 4 Match A}                                  /tb_l2_bdi_cache_top/uut/cache_array/match4_A
add wave -noupdate -label {Way 4 Match B}                                  /tb_l2_bdi_cache_top/uut/cache_array/match4_B
add wave -noupdate -label {Way 5 Match A}                                  /tb_l2_bdi_cache_top/uut/cache_array/match5_A
add wave -noupdate -label {Way 5 Match B}                                  /tb_l2_bdi_cache_top/uut/cache_array/match5_B
add wave -noupdate -label {Way 6 Match A}                                  /tb_l2_bdi_cache_top/uut/cache_array/match6_A
add wave -noupdate -label {Way 6 Match B}                                  /tb_l2_bdi_cache_top/uut/cache_array/match6_B
add wave -noupdate -label {Way 7 Match A}                                  /tb_l2_bdi_cache_top/uut/cache_array/match7_A
add wave -noupdate -label {Way 7 Match B}                                  /tb_l2_bdi_cache_top/uut/cache_array/match7_B
add wave -noupdate -label {Way 8 Match A}                                  /tb_l2_bdi_cache_top/uut/cache_array/match8_A
add wave -noupdate -label {Way 8 Match B}                                  /tb_l2_bdi_cache_top/uut/cache_array/match8_B
add wave -noupdate -label {Array Cache Hit Raw}                            /tb_l2_bdi_cache_top/uut/cache_array/cache_hit
add wave -noupdate -label {Array Cache Miss Raw}                           /tb_l2_bdi_cache_top/uut/cache_array/cache_miss
add wave -noupdate -radix unsigned -label {Accessed Way (0..7)}            /tb_l2_bdi_cache_top/uut/cache_array/access_way
add wave -noupdate -radix unsigned -label {Tree-PLRU Victim Way}           /tb_l2_bdi_cache_top/uut/cache_array/replace_way_r

# =============================================================================
# 7. DUAL SUB-BLOCK PACKING (SLOTS A & B COHABITATION)
# =============================================================================
add wave -noupdate -divider {=== 7. DUAL SUB-BLOCK PACKING ===}
add wave -noupdate -label {Hit Compressed Slot A}                          /tb_l2_bdi_cache_top/uut/cache_array/hit_compressed_A_r
add wave -noupdate -label {Hit Compressed Slot B (Cohabitation)}           /tb_l2_bdi_cache_top/uut/cache_array/hit_compressed_B_r
add wave -noupdate -label {Hit Uncompressed Line}                          /tb_l2_bdi_cache_top/uut/cache_array/hit_uncompressed_r
add wave -noupdate -label {Way 1 Slot A Valid}                             /tb_l2_bdi_cache_top/uut/cache_array/valid_out_A1
add wave -noupdate -label {Way 1 Slot B Valid (Cohabitation)}             /tb_l2_bdi_cache_top/uut/cache_array/valid_out_B1
add wave -noupdate -label {Way 1 Uncompressed Marker}                      /tb_l2_bdi_cache_top/uut/cache_array/uncomp_out_1
add wave -noupdate -label {Way 1 Slot A Dirty}                             /tb_l2_bdi_cache_top/uut/cache_array/dirty_out_A1
add wave -noupdate -label {Way 1 Slot B Dirty}                             /tb_l2_bdi_cache_top/uut/cache_array/dirty_out_B1

# =============================================================================
# 8. 5-CYCLE READ & COMBINATIONAL DECOMPRESSION PIPELINE
# =============================================================================
add wave -noupdate -divider {=== 8. 5-CYCLE READ PIPELINE ===}
add wave -noupdate -label {Cycle 1: Read Admitted}                         /tb_l2_bdi_cache_top/uut/read_admitted
add wave -noupdate -radix binary -label {Read Valid Shift Pipe [3:0]}      /tb_l2_bdi_cache_top/uut/read_valid_pipe
add wave -noupdate -label {Cycle 3: Array Tag Hit Registered}              /tb_l2_bdi_cache_top/uut/hit_stage
add wave -noupdate -radix hexadecimal -label {Cycle 3: Compressed SRAM Data} /tb_l2_bdi_cache_top/uut/compressed_data_stage
add wave -noupdate -radix unsigned -label {Cycle 3: Compression Profile}   /tb_l2_bdi_cache_top/uut/compress_type_stage
add wave -noupdate -radix hexadecimal -label {Cycle 4: Reconstituted Line} /tb_l2_bdi_cache_top/uut/decompressed_stage
add wave -noupdate -label {Cycle 4: Decompressor Hit Stage}                /tb_l2_bdi_cache_top/uut/hit_stage2

# =============================================================================
# 9. PRIMARY CACHE RESPONSE INTERFACE (OUTPUT TO CORE)
# =============================================================================
add wave -noupdate -divider {=== 9. RESPONSE INTERFACE (CYCLE 5) ===}
add wave -noupdate -label {Response Valid (Output Strobe)}                 /tb_l2_bdi_cache_top/response_valid
add wave -noupdate -label {Deterministic Cache Hit}                        /tb_l2_bdi_cache_top/hit
add wave -noupdate -label {Deterministic Cache Miss}                       /tb_l2_bdi_cache_top/miss
add wave -noupdate -radix hexadecimal -label {Final Output Data [255:0]}    /tb_l2_bdi_cache_top/data_out

# =============================================================================
# 10. SAFE ATOMIC EVICTION & DRAM WRITEBACK
# =============================================================================
add wave -noupdate -divider {=== 10. EVICTION & DRAM WRITEBACK ===}
add wave -noupdate -label {Evict Valid Strobe}                             /tb_l2_bdi_cache_top/evict_valid
add wave -noupdate -radix hexadecimal -label {Evict DRAM Address}          /tb_l2_bdi_cache_top/evict_address
add wave -noupdate -radix hexadecimal -label {Evict Dirty Payload}         /tb_l2_bdi_cache_top/evict_data
add wave -noupdate -label {Memory Controller Ack}                          /tb_l2_bdi_cache_top/evict_ack

# =============================================================================
# 11. CSR MMIO CONTROL BANK & ADAPTIVE POWER GOVERNANCE
# =============================================================================
add wave -noupdate -divider {=== 11. CSR MMIO & TELEMETRY ===}
add wave -noupdate -radix hexadecimal -label {CSR MMIO Address}            /tb_l2_bdi_cache_top/cpu_mmio_address
add wave -noupdate -radix hexadecimal -label {CSR MMIO Write Data}         /tb_l2_bdi_cache_top/cpu_mmio_wdata
add wave -noupdate -label {CSR MMIO Write Enable}                          /tb_l2_bdi_cache_top/cpu_mmio_wen
add wave -noupdate -radix hexadecimal -label {CSR MMIO Read Data}          /tb_l2_bdi_cache_top/cpu_mmio_rdata
add wave -noupdate -radix binary -label {Active Associativity Sel [1:0]}  /tb_l2_bdi_cache_top/dbg_current_sel
add wave -noupdate -label {Hardware Prefetcher Enable}                     /tb_l2_bdi_cache_top/prefetch_en
add wave -noupdate -label {Non-Blocking MSHR Enable}                       /tb_l2_bdi_cache_top/mshr_en
add wave -noupdate -label {Workload Mode (0=General, 1=AI)}                /tb_l2_bdi_cache_top/workload_mode
add wave -noupdate -radix unsigned -label {Cumulative Access Counter}      /tb_l2_bdi_cache_top/dbg_access_count
add wave -noupdate -radix unsigned -label {Cumulative Miss Counter}        /tb_l2_bdi_cache_top/dbg_miss_count

# =============================================================================
# SIMULATION EXECUTION & WAVE WINDOW FORMATTING
# =============================================================================
run -all

configure wave -namecolwidth 300
configure wave -valuecolwidth 180
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

wave zoomfull
