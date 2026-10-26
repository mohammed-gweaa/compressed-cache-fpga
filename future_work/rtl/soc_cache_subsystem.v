`timescale 1ns / 1ps
// =============================================================================
// Module Name: soc_cache_subsystem
// Project:     High-Performance BDI Compressed L2 Cache IP for SoC
// Author:      Mohammed Gweaa
// Standard:    IEEE 1364-2001 (Verilog HDL)
//
// Description:
//   Complete Multi-Level Memory Hierarchy Subsystem for RISC-V SoC.
//   Integrates:
//     1. l1_dcache_core: Ultra-Fast 1-Cycle L1 Data Cache for CPU LSU.
//     2. l1_l2_bus_arbiter: Multi-Port Arbiter (L1-I + L1-D).
//     3. l2_cache_controller: 256-Bit Line Level-2 Cache Controller.
//     4. l2_bdi_cache_top: 8-Way Synchronous BDI Compressed Array (M9K).
//
// Operation Flow:
//   CPU <──1 cycle──> L1-D <──5-7 cycles──> BDI L2 <──Burst──> External DRAM
// =============================================================================

module soc_cache_subsystem (
    input  wire        clk,
    input  wire        reset,

    // ── CPU Data Port (Wishbone B4 Slave connected to CPU LSU) ───────────
    input  wire [31:0] cpu_d_adr_i,
    input  wire [31:0] cpu_d_dat_i,
    input  wire [3:0]  cpu_d_sel_i,
    input  wire        cpu_d_we_i,
    input  wire        cpu_d_cyc_i,
    input  wire        cpu_d_stb_i,
    output wire [31:0] cpu_d_dat_o,
    output wire        cpu_d_ack_o,
    output wire        cpu_d_stall_o,

    // ── CPU Instruction Port (Direct L1-I Cache Refill Channel) ──────────
    input  wire        l1i_req_valid,
    input  wire [31:0] l1i_req_addr,
    output wire [255:0] l1i_resp_rdata,
    output wire        l1i_resp_valid,
    output wire        l1i_ready,

    // ── External Memory Interface (Master to DRAM Controller) ────────────
    output wire        mem_req_o,
    output wire        mem_we_o,
    output wire [31:0] mem_addr_o,
    output wire [255:0] mem_wdata_o,
    input  wire [255:0] mem_rdata_i,
    input  wire        mem_ready_i,

    // ── System Management (CSR) Interface ────────────────────────────────
    input  wire [31:0] csr_address,
    input  wire [31:0] csr_wdata,
    input  wire        csr_we,
    output wire [31:0] csr_rdata,

    // ── Hierarchy Telemetry & Performance Counters ───────────────────────
    output wire [31:0] dbg_l1d_hits,
    output wire [31:0] dbg_l1d_misses,
    output wire [31:0] dbg_l2_hits,
    output wire [31:0] dbg_l2_misses,
    output wire [1:0]  dbg_l2_associativity
);

    // Interconnect wires between L1-D and Arbiter
    wire        l1d_arb_req_valid;
    wire [31:0] l1d_arb_req_addr;
    wire        l1d_arb_req_write;
    wire [255:0] l1d_arb_req_wdata;
    wire [255:0] l1d_arb_resp_rdata;
    wire        l1d_arb_resp_valid;
    wire        l1d_arb_ready;

    // Interconnect wires between Arbiter and L2 Adapter
    wire        arb_l2_req_valid;
    wire [31:0] arb_l2_req_addr;
    wire        arb_l2_req_write;
    wire [255:0] arb_l2_req_wdata;
    wire [255:0] arb_l2_resp_rdata;
    wire        arb_l2_resp_valid;
    wire        arb_l2_ready;

    // -------------------------------------------------------------------------
    // 1. Level-1 Data Cache (1-Cycle Latency to CPU)
    // -------------------------------------------------------------------------
    l1_dcache_core l1_data_cache (
        .clk           (clk),
        .reset         (reset),

        // CPU Interface
        .cpu_adr_i     (cpu_d_adr_i),
        .cpu_dat_i     (cpu_d_dat_i),
        .cpu_sel_i     (cpu_d_sel_i),
        .cpu_we_i      (cpu_d_we_i),
        .cpu_cyc_i     (cpu_d_cyc_i),
        .cpu_stb_i     (cpu_d_stb_i),
        .cpu_dat_o     (cpu_d_dat_o),
        .cpu_ack_o     (cpu_d_ack_o),
        .cpu_stall_o   (cpu_d_stall_o),

        // L2 Channel
        .l2_req_valid  (l1d_arb_req_valid),
        .l2_req_addr   (l1d_arb_req_addr),
        .l2_req_write  (l1d_arb_req_write),
        .l2_req_wdata  (l1d_arb_req_wdata),
        .l2_resp_rdata (l1d_arb_resp_rdata),
        .l2_resp_valid (l1d_arb_resp_valid),
        .l2_ready      (l1d_arb_ready),

        // Diagnostics
        .dbg_l1_hits   (dbg_l1d_hits),
        .dbg_l1_misses (dbg_l1d_misses)
    );

    // -------------------------------------------------------------------------
    // 2. Upstream Multi-Port Arbiter (L1-I and L1-D)
    // -------------------------------------------------------------------------
    l1_l2_bus_arbiter upstream_arbiter (
        .clk           (clk),
        .reset         (reset),

        // Port 0: L1-I
        .l1i_req_valid (l1i_req_valid),
        .l1i_req_addr  (l1i_req_addr),
        .l1i_resp_rdata(l1i_resp_rdata),
        .l1i_resp_valid(l1i_resp_valid),
        .l1i_ready     (l1i_ready),

        // Port 1: L1-D
        .l1d_req_valid (l1d_arb_req_valid),
        .l1d_req_addr  (l1d_arb_req_addr),
        .l1d_req_write (l1d_arb_req_write),
        .l1d_req_wdata (l1d_arb_req_wdata),
        .l1d_resp_rdata(l1d_arb_resp_rdata),
        .l1d_resp_valid(l1d_arb_resp_valid),
        .l1d_ready     (l1d_arb_ready),

        // Downstream to L2 Adapter
        .l2_req_valid  (arb_l2_req_valid),
        .l2_req_addr   (arb_l2_req_addr),
        .l2_req_write  (arb_l2_req_write),
        .l2_req_wdata  (arb_l2_req_wdata),
        .l2_resp_rdata (arb_l2_resp_rdata),
        .l2_resp_valid (arb_l2_resp_valid),
        .l2_ready      (arb_l2_ready)
    );

    // -------------------------------------------------------------------------
    // 3. Level-2 Cache Subsystem (BDI Compressed 8-Way M9K Array)
    // -------------------------------------------------------------------------
    l2_cache_controller l2_adapter_inst (
        .clk                      (clk),
        .reset                    (reset),

        // Upstream Interface (from Arbiter)
        .l1_req_valid             (arb_l2_req_valid),
        .l1_req_addr              (arb_l2_req_addr),
        .l1_req_write             (arb_l2_req_write),
        .l1_req_wdata             (arb_l2_req_wdata),
        .l2_resp_rdata            (arb_l2_resp_rdata),
        .l2_resp_valid            (arb_l2_resp_valid),
        .l2_ready                 (arb_l2_ready),

        // Downstream Interface (to DRAM Controller)
        .mem_req_o                (mem_req_o),
        .mem_we_o                 (mem_we_o),
        .mem_addr_o               (mem_addr_o),
        .mem_wdata_o              (mem_wdata_o),
        .mem_rdata_i              (mem_rdata_i),
        .mem_ready_i              (mem_ready_i),

        // CSR & Diagnostics
        .csr_address              (csr_address),
        .csr_wdata                (csr_wdata),
        .csr_we                   (csr_we),
        .csr_rdata                (csr_rdata),
        .dbg_l2_hit_count         (dbg_l2_hits),
        .dbg_l2_miss_count        (dbg_l2_misses),
        .dbg_current_associativity(dbg_l2_associativity),
        .dbg_prefetch_hit_count   (),
        .dbg_hum_hit_count        ()
    );

endmodule
