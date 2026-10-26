# =============================================================================
# Waveform Macro: wave_comparative_benchmark.do
# Module:         tb_l2_comparative_stress_benchmark
# Project:        BDI-Compressed L2 Cache vs Conventional L2 Cache Baseline
# Author:         Mohammed Gweaa
# =============================================================================

vsim -voptargs=+acc -t 1ps work.tb_l2_comparative_stress_benchmark

onerror {resume}
catch {delete wave *}

# --- 1. COMMON SYSTEM CLOCK & STIMULUS ---
add wave -noupdate -divider {=== 1. CLOCK & COMMON REQUEST STIMULUS ===}
add wave -noupdate -label {Clock}                                   /tb_l2_comparative_stress_benchmark/clk
add wave -noupdate -label {Reset}                                   /tb_l2_comparative_stress_benchmark/reset
add wave -noupdate -label {Request Valid}                           /tb_l2_comparative_stress_benchmark/req_valid
add wave -noupdate -label {Write (1=Write, 0=Read)}                 /tb_l2_comparative_stress_benchmark/req_write
add wave -noupdate -radix hexadecimal -label {Request Address [31:0]} /tb_l2_comparative_stress_benchmark/req_addr
add wave -noupdate -radix hexadecimal -label {Request Data In [255:0]} /tb_l2_comparative_stress_benchmark/req_wdata

# --- 2. BDI COMPRESSED L2 CACHE (OUR DESIGN) ---
add wave -noupdate -divider {=== 2. PROPOSED BDI COMPRESSED L2 ===}
add wave -noupdate -label {BDI Response Valid}                       /tb_l2_comparative_stress_benchmark/bdi_resp_valid
add wave -noupdate -label {BDI Hit (Green = High Throughput)}       /tb_l2_comparative_stress_benchmark/bdi_hit
add wave -noupdate -label {BDI Miss}                                /tb_l2_comparative_stress_benchmark/bdi_miss
add wave -noupdate -radix hexadecimal -label {BDI Data Out [255:0]} /tb_l2_comparative_stress_benchmark/bdi_data_out
add wave -noupdate -label {BDI Hazard Stall (0 = STLF Active)}      /tb_l2_comparative_stress_benchmark/bdi_hazard_stall
add wave -noupdate -label {BDI Dynamic Compression Bypass (DCB)}    /tb_l2_comparative_stress_benchmark/bdi_dcb_bypass
add wave -noupdate -label {BDI Capacity Eviction}                   /tb_l2_comparative_stress_benchmark/bdi_evict_valid
add wave -noupdate -radix hexadecimal -label {BDI Evict Addr}       /tb_l2_comparative_stress_benchmark/bdi_evict_addr
add wave -noupdate -radix unsigned -label {BDI Total Hits}          /tb_l2_comparative_stress_benchmark/total_bdi_hits
add wave -noupdate -radix unsigned -label {BDI STLF Bypass Count}   /tb_l2_comparative_stress_benchmark/total_bdi_stlf_bypasses

# --- 3. CONVENTIONAL UNCOMPRESSED L2 CACHE (BASELINE) ---
add wave -noupdate -divider {=== 3. CONVENTIONAL UNCOMPRESSED BASELINE ===}
add wave -noupdate -label {Conv Response Valid}                      /tb_l2_comparative_stress_benchmark/conv_resp_valid
add wave -noupdate -label {Conv Hit}                                /tb_l2_comparative_stress_benchmark/conv_hit
add wave -noupdate -label {Conv Miss}                               /tb_l2_comparative_stress_benchmark/conv_miss
add wave -noupdate -radix hexadecimal -label {Conv Data Out [255:0]} /tb_l2_comparative_stress_benchmark/conv_data_out
add wave -noupdate -label {Conv Hazard Stall (Stalled = Red)}       /tb_l2_comparative_stress_benchmark/conv_hazard_stall
add wave -noupdate -label {Conv Capacity Eviction}                  /tb_l2_comparative_stress_benchmark/conv_evict_valid
add wave -noupdate -radix hexadecimal -label {Conv Evict Addr}      /tb_l2_comparative_stress_benchmark/conv_evict_addr
add wave -noupdate -radix unsigned -label {Conv Total Hits}         /tb_l2_comparative_stress_benchmark/total_conv_hits
add wave -noupdate -radix unsigned -label {Conv Total Stall Cycles} /tb_l2_comparative_stress_benchmark/total_conv_stalls

# Run simulation
run -all

# Formatting
configure wave -namecolwidth 300
configure wave -valuecolwidth 180
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

wave zoomfull
