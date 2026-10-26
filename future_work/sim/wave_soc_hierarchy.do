# =============================================================================
# Waveform Macro: wave_soc_hierarchy.do
# Module:         tb_soc_cache_subsystem (Complete Multi-Level Memory Hierarchy)
# Hierarchy:      CPU (Wishbone) <-> L1-D <-> Arbiter <-> BDI L2 <-> DRAM
# Author:         Mohammed Gweaa
# =============================================================================

vsim -voptargs=+acc -t 1ps work.tb_soc_cache_subsystem

onerror {resume}
catch {delete wave *}

# --- 1. SYSTEM CLOCK & RESET ---
add wave -noupdate -divider {=== 1. CLOCK & RESET ===}
add wave -noupdate -label {Clock}                               /tb_soc_cache_subsystem/clk
add wave -noupdate -label {Reset}                               /tb_soc_cache_subsystem/reset

# --- 2. CPU LOAD/STORE UNIT (WISHBONE INTERFACE) ---
add wave -noupdate -divider {=== 2. CPU LOAD/STORE UNIT (LSU) ===}
add wave -noupdate -label {CPU Cyc}                             /tb_soc_cache_subsystem/cpu_d_cyc
add wave -noupdate -label {CPU Strobe}                          /tb_soc_cache_subsystem/cpu_d_stb
add wave -noupdate -label {CPU Write Enable}                    /tb_soc_cache_subsystem/cpu_d_we
add wave -noupdate -radix hexadecimal -label {CPU Address [31:0]} /tb_soc_cache_subsystem/cpu_d_adr
add wave -noupdate -radix hexadecimal -label {CPU Write Data}   /tb_soc_cache_subsystem/cpu_d_dat_w
add wave -noupdate -radix hexadecimal -label {CPU Read Data}    /tb_soc_cache_subsystem/cpu_d_dat_r
add wave -noupdate -label {CPU Ack (Completed)}                 /tb_soc_cache_subsystem/cpu_d_ack
add wave -noupdate -label {CPU Stall}                           /tb_soc_cache_subsystem/cpu_d_stall

# --- 3. L1 DATA CACHE CORE ---
add wave -noupdate -divider {=== 3. L1 DATA CACHE CORE ===}
add wave -noupdate -label {L1-D Hit}                            /tb_soc_cache_subsystem/dut/l1_data_cache/l1_hit
add wave -noupdate -radix unsigned -label {L1 FSM State}        /tb_soc_cache_subsystem/dut/l1_data_cache/state
add wave -noupdate -radix unsigned -label {L1 Cumulative Hits}  /tb_soc_cache_subsystem/dbg_l1d_hits
add wave -noupdate -radix unsigned -label {L1 Cumulative Misses} /tb_soc_cache_subsystem/dbg_l1d_misses
add wave -noupdate -label {L1->L2 Req Valid}                    /tb_soc_cache_subsystem/dut/l1_data_cache/l2_req_valid
add wave -noupdate -label {L1->L2 Req Write (Dirty Evict)}      /tb_soc_cache_subsystem/dut/l1_data_cache/l2_req_write
add wave -noupdate -radix hexadecimal -label {L1->L2 Req Addr}  /tb_soc_cache_subsystem/dut/l1_data_cache/l2_req_addr
add wave -noupdate -radix hexadecimal -label {L1->L2 Req Data}  /tb_soc_cache_subsystem/dut/l1_data_cache/l2_req_wdata

# --- 4. L1-L2 BUS ARBITER ---
add wave -noupdate -divider {=== 4. L1-L2 BUS ARBITER ===}
add wave -noupdate -label {L1-I Grant}                          /tb_soc_cache_subsystem/dut/upstream_arbiter/grant_l1i
add wave -noupdate -radix unsigned -label {Arbiter State}       /tb_soc_cache_subsystem/dut/upstream_arbiter/arb_state

# --- 5. L2 BDI CACHE CONTROLLER & CORE ---
add wave -noupdate -divider {=== 5. L2 BDI CACHE CORE ===}
add wave -noupdate -label {L2 Core Hit}                         /tb_soc_cache_subsystem/dut/l2_adapter_inst/core_hit
add wave -noupdate -label {L2 Core Miss}                        /tb_soc_cache_subsystem/dut/l2_adapter_inst/core_miss
add wave -noupdate -radix unsigned -label {L2 Controller State} /tb_soc_cache_subsystem/dut/l2_adapter_inst/state
add wave -noupdate -radix unsigned -label {L2 Cumulative Hits}  /tb_soc_cache_subsystem/dbg_l2_hits
add wave -noupdate -radix unsigned -label {L2 Cumulative Misses} /tb_soc_cache_subsystem/dbg_l2_misses
add wave -noupdate -label {L2 Hazard Stall}                     /tb_soc_cache_subsystem/dut/l2_adapter_inst/hazard_stall
add wave -noupdate -radix unsigned -label {L2 Associativity}    /tb_soc_cache_subsystem/dbg_l2_associativity

# --- 6. DRAM MAIN MEMORY INTERFACE ---
add wave -noupdate -divider {=== 6. DRAM MAIN MEMORY BUS ===}
add wave -noupdate -label {DRAM Mem Req}                        /tb_soc_cache_subsystem/mem_req
add wave -noupdate -label {DRAM Mem Write (1=Evict, 0=Refill)}  /tb_soc_cache_subsystem/mem_we
add wave -noupdate -radix hexadecimal -label {DRAM Mem Addr}    /tb_soc_cache_subsystem/mem_addr
add wave -noupdate -radix hexadecimal -label {DRAM Write Data}  /tb_soc_cache_subsystem/mem_wdata
add wave -noupdate -radix hexadecimal -label {DRAM Read Data}   /tb_soc_cache_subsystem/mem_rdata
add wave -noupdate -label {DRAM Ready Ack}                      /tb_soc_cache_subsystem/mem_ready

# Run full hierarchy simulation
run -all

# Formatting
configure wave -namecolwidth 280
configure wave -valuecolwidth 180
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

wave zoomfull
