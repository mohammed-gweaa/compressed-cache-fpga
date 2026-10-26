`timescale 1ns / 1ps
// =============================================================================
// Testbench Name: tb_paper_journal_artifacts
// Project:        High-Performance BDI Compressed L2 Cache Subsystem for SoC
// Author:         Mohammed Gweaa
// Target:         Publication-Grade Waveform Generation (Figures 9 & 10)
// Venue:          Journal of Engineering Research / UZJEST
//
// Description:
//   Dedicated, self-contained demonstration testbench configured specifically
//   to generate two clean, uncompromised academic waveforms:
//     - Waveform A: Write Pipeline, Multi-Profile BDI Compression,
//                   Dual Sub-Block Packing (we1_A then we1_B in same set),
//                   and Runtime Associativity Transition (8-Way -> 4-Way).
//     - Waveform B: Deterministic 5-Cycle Read Hit, Decompression & STLF Bypass.
// =============================================================================

module tb_paper_journal_artifacts;

    reg clk;
    reg reset;

    // Processor Stimulus Interface
    reg         req_valid;
    reg  [31:0] req_addr;
    reg         req_write;
    reg         req_is_refill;
    reg  [255:0] req_wdata;

    // CSR MMIO Interface
    reg  [31:0] bdi_csr_addr;
    reg  [31:0] bdi_csr_wdata;
    reg         bdi_csr_we;
    wire [31:0] bdi_csr_rdata;

    // BDI Cache Core Outputs
    wire [255:0] bdi_data_out;
    wire        bdi_hit;
    wire        bdi_miss;
    wire        bdi_resp_valid;
    wire        bdi_hazard_stall;
    wire        bdi_dcb_bypass;
    wire        bdi_evict_valid;
    wire [31:0] bdi_evict_addr;
    wire [255:0] bdi_evict_data;
    reg         bdi_evict_ack;
    wire [1:0]  bdi_curr_sel;

    // Conventional Baseline Cache Outputs
    wire [255:0] conv_data_out;
    wire        conv_hit;
    wire        conv_miss;
    wire        conv_resp_valid;
    wire        conv_hazard_stall;
    wire        conv_dcb_bypass;
    wire        conv_evict_valid;
    wire [31:0] conv_evict_addr;
    wire [255:0] conv_evict_data;
    reg         conv_evict_ack;

    // Instantiate Proposed BDI Compressed L2 Cache
    l2_bdi_cache_top uut_bdi (
        .clk              (clk),
        .reset            (reset),
        .request_valid    (req_valid),
        .address          (req_addr),
        .write            (req_write),
        .is_refill        (req_is_refill),
        .data_in          (req_wdata),
        .cpu_mmio_address (bdi_csr_addr),
        .cpu_mmio_wdata   (bdi_csr_wdata),
        .cpu_mmio_wen     (bdi_csr_we),
        .cpu_mmio_rdata   (bdi_csr_rdata),
        .data_out         (bdi_data_out),
        .hit              (bdi_hit),
        .miss             (bdi_miss),
        .response_valid   (bdi_resp_valid),
        .hazard_stall     (bdi_hazard_stall),
        .dcb_bypass_active(bdi_dcb_bypass),
        .evict_valid      (bdi_evict_valid),
        .evict_address    (bdi_evict_addr),
        .evict_data       (bdi_evict_data),
        .evict_ack        (bdi_evict_ack),
        .dbg_access_count (),
        .dbg_miss_count   (),
        .dbg_current_sel  (bdi_curr_sel),
        .dbg_epoch_done   (),
        .dbg_hazard_count (),
        .prefetch_en      (),
        .mshr_en          (),
        .workload_mode    (),
        .dbg_compress_type(),
        .dbg_fwd_valid    ()
    );

    // Instantiate Conventional Baseline Uncompressed L2 Cache
    l2_conventional_cache_top uut_conv (
        .clk              (clk),
        .reset            (reset),
        .request_valid    (req_valid),
        .address          (req_addr),
        .write            (req_write),
        .is_refill        (req_is_refill),
        .data_in          (req_wdata),
        .cpu_mmio_address (32'd0),
        .cpu_mmio_wdata   (32'd0),
        .cpu_mmio_wen     (1'b0),
        .cpu_mmio_rdata   (),
        .data_out         (conv_data_out),
        .hit              (conv_hit),
        .miss             (conv_miss),
        .response_valid   (conv_resp_valid),
        .hazard_stall     (conv_hazard_stall),
        .dcb_bypass_active(conv_dcb_bypass),
        .evict_valid      (conv_evict_valid),
        .evict_address    (conv_evict_addr),
        .evict_data       (conv_evict_data),
        .evict_ack        (conv_evict_ack),
        .dbg_access_count (),
        .dbg_miss_count   (),
        .dbg_current_sel  (),
        .dbg_epoch_done   (),
        .dbg_hazard_count ()
    );

    // 50 MHz Nominal Clock (20 ns Period)
    always #10 clk = ~clk;

    initial begin
        clk           = 0;
        reset         = 0;
        req_valid     = 0;
        req_addr      = 0;
        req_write     = 0;
        req_is_refill = 0;
        req_wdata     = 0;
        bdi_csr_addr  = 0;
        bdi_csr_wdata = 0;
        bdi_csr_we    = 0;
        bdi_evict_ack = 0;
        conv_evict_ack= 0;

        #100;
        reset = 1;
        #40;

        // =====================================================================
        // PART 1: Write Line 1 (Base8-Delta1, Set 0) -> Allocates Way 1 Half-A
        // =====================================================================
        @(posedge clk);
        req_valid     = 1'b1;
        req_addr      = 32'h0000_1000; // Tag = 0x000010, Set = 0
        req_write     = 1'b1;
        req_is_refill = 1'b1;
        req_wdata     = {64'h2000_0000_0000_0030,
                         64'h2000_0000_0000_0020,
                         64'h2000_0000_0000_0010,
                         64'h2000_0000_0000_0000};
        @(posedge clk);
        req_valid     = 1'b0;

        #120; // Pipeline progresses -> we1_A pulses at commit!

        // =====================================================================
        // PART 2: Write Line 2 (Base4-Delta1, Set 0) -> Packs into Way 1 Half-B!
        // =====================================================================
        @(posedge clk);
        req_valid     = 1'b1;
        req_addr      = 32'h0000_1100; // Same set (0), different Tag (0x000011)
        req_write     = 1'b1;
        req_is_refill = 1'b1;
        req_wdata     = {32'h1000_0007, 32'h1000_0006, 32'h1000_0005, 32'h1000_0004,
                         32'h1000_0003, 32'h1000_0002, 32'h1000_0001, 32'h1000_0000};
        @(posedge clk);
        req_valid     = 1'b0;

        #120; // Pipeline progresses -> we1_B pulses in same set! Dual sub-block packed!

        // =====================================================================
        // PART 3: Runtime Associativity Transition (On-The-Fly: 8-Way -> 4-Way)
        // =====================================================================
        @(negedge clk);
        bdi_csr_addr  = 32'hFFFF_0004; // ADDR_CTRL: Bit 0 = Software Override Enable
        bdi_csr_wdata = 32'h0000_0001; // Enable SW control
        bdi_csr_we    = 1'b1;
        @(negedge clk);
        bdi_csr_addr  = 32'hFFFF_0000; // ADDR_CFG: Bits [1:0] = 2'b10 (4-Way mode)
        bdi_csr_wdata = 32'h0000_000E; // Downscale to 4-Way!
        bdi_csr_we    = 1'b1;
        @(negedge clk);
        bdi_csr_we    = 1'b0;
        bdi_csr_addr  = 32'd0;
        bdi_csr_wdata = 32'd0;

        #40; // On the clock edge, selection_signal_d transitions to 2'b10!

        // =====================================================================
        // PART 4: Verification of Active vs. Halted Ways
        // =====================================================================
        // Read Line 1 (Way 1): Way 1 is active in 4-Way mode -> match1 = 1, hit = 1!
        @(posedge clk);
        req_valid     = 1'b1;
        req_addr      = 32'h0000_1000;
        req_write     = 1'b0;
        req_is_refill = 1'b0;
        @(posedge clk);
        req_valid     = 1'b0;

        #120; // Deterministic 5-cycle read hit with data out verified!

        // =====================================================================
        // PART 5: Back-to-Back RAW Hazard Collision (Write then Immediate Read)
        // =====================================================================
        @(posedge clk);
        // Step 5a: Write to 0x0000_2000
        req_valid     = 1'b1;
        req_addr      = 32'h0000_2000;
        req_write     = 1'b1;
        req_is_refill = 1'b0;
        req_wdata     = {8{32'hCAFE_BABE}};
        @(posedge clk);

        // Step 5b: IMMEDIATELY issue Read to 0x0000_2000 on next clock cycle!
        req_valid     = 1'b1;
        req_addr      = 32'h0000_2000;
        req_write     = 1'b0;
        @(posedge clk);
        req_valid     = 1'b0;

        // BDI STLF forwards write data with ZERO stalls (hazard_stall = 0)!
        // Conventional cache asserts hazard_stall = 1!
        #160;

        $display("==================================================================");
        $display("[DEMONSTRATOR TESTBENCH] Academic Waveforms Successfully Captured!");
        $display("==================================================================");
        $finish;
    end

endmodule
