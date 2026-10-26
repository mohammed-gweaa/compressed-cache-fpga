`timescale 1ns / 1ps
// =============================================================================
// Module Name: l2_bdi_cache_top
// Project:     High-Performance BDI Compressed L2 Cache Subsystem for SoC
// Author:      Mohammed Gweaa
// Standard:    IEEE 1364-2001 (Verilog HDL)
//
// Description:
//   Top-Level Core of the Production-Grade BDI Compressed Level-2 (L2) Cache.
//   Integrates:
//     1. Fast-Path Decoupled Read Pipeline (5-Cycle Deterministic Read Hit Latency)
//     2. Pipeline RAW Hazard Detection & Interlock Unit (l2_hazard_interlock_unit)
//     3. Full-Spectrum BDI Compressor & Dynamic Bypass (l2_bdi_compressor)
//     4. Synchronous Dual-Sub-Block Cache Array with PLRU (l2_cache_storage_array)
//     5. Dual Dirty-Bit Tracking and Retimed Atomic Eviction Controller
//     6. Autonomous Associativity Scaling Governor (l2_adaptive_power_governor)
//     7. Memory-Mapped Control & Status Register Bank (l2_csr_control_bank)
//     8. Single-Cycle Combinational Decompressor (l2_bdi_decompressor)
// =============================================================================

module l2_bdi_cache_top (
    input  wire        clk,
    input  wire        reset,

    // Primary Processor / Memory Interface (256-bit Line Interface)
    input  wire        request_valid,
    input  wire [31:0] address,
    input  wire        write,
    input  wire        is_refill,
    input  wire [255:0] data_in,

    // CSR MMIO Software-Directed Control Interface
    input  wire [31:0] cpu_mmio_address,
    input  wire [31:0] cpu_mmio_wdata,
    input  wire        cpu_mmio_wen,
    output wire [31:0] cpu_mmio_rdata,

    // Primary Cache Response Interface (5-Cycle Deterministic Latency)
    output reg  [255:0] data_out,
    output reg         hit,
    output reg         miss,
    output reg         response_valid,
    output wire        hazard_stall,
    output wire        dcb_bypass_active,

    // Safe Atomic Eviction Interface (To External Memory / DRAM Controller)
    output wire        evict_valid,
    output wire [31:0] evict_address,
    output wire [255:0] evict_data,
    input  wire        evict_ack,

    // Telemetry and Hardware Diagnostic Probes
    output wire [9:0]  dbg_access_count,
    output wire [9:0]  dbg_miss_count,
    output wire [1:0]  dbg_current_sel,
    output wire        dbg_epoch_done,
    output wire [31:0] dbg_hazard_count,

    // Software-Directed OS Control Flags from CSR Bank
    output wire        prefetch_en,
    output wire        mshr_en,
    output wire        workload_mode,

    // Real-Time Hardware Diagnostic Telemetry Probes
    output wire [2:0]  dbg_compress_type,
    output wire        dbg_fwd_valid
);


    // -------------------------------------------------------------------------
    // 1. Pipeline Hazard Tracking & Store-to-Load Forwarding (STLF) Logic
    // -------------------------------------------------------------------------
    reg [31:0]  w_s1_addr, w_s2_addr, w_s3_addr, w_s4_addr, w_commit_addr;
    reg         w_s1_valid, w_s2_valid, w_s3_valid, w_s4_valid, w_commit_valid;
    reg         w_s1_refill, w_s2_refill, w_s3_refill, w_s4_refill, w_commit_refill;
    reg [255:0] w_s1_data, w_s2_data, w_s3_data, w_s4_data, w_commit_data;

    wire read_req_active  = request_valid & ~write;
    wire write_req_active = request_valid & write;

    wire        fwd_valid;
    wire [2:0]  fwd_stage_sel;
    wire [31:0] fwd_event_count;

    l2_hazard_interlock_unit hazard_detector (
        .clk                (clk),
        .reset              (reset),
        .read_req           (read_req_active),
        .read_addr          (address),
        .w_s1_valid         (w_s1_valid),
        .w_s1_addr          (w_s1_addr),
        .w_s2_valid         (w_s2_valid),
        .w_s2_addr          (w_s2_addr),
        .w_s3_valid         (w_s3_valid),
        .w_s3_addr          (w_s3_addr),
        .w_s4_valid         (w_s4_valid),
        .w_s4_addr          (w_s4_addr),
        .w_commit_valid     (w_commit_valid),
        .w_commit_addr      (w_commit_addr),
        .forward_valid      (fwd_valid),
        .forward_stage_sel  (fwd_stage_sel),
        .forward_event_count(fwd_event_count),
        .hazard_stall       (hazard_stall),
        .hazard_event_count (dbg_hazard_count)
    );

    // In-flight write tracking across 4 compressor pipeline stages + commit stage
    always @(posedge clk) begin
        if (!reset) begin
            w_s1_valid <= 1'b0; w_s1_addr <= 32'd0; w_s1_refill <= 1'b0; w_s1_data <= 256'd0;
            w_s2_valid <= 1'b0; w_s2_addr <= 32'd0; w_s2_refill <= 1'b0; w_s2_data <= 256'd0;
            w_s3_valid <= 1'b0; w_s3_addr <= 32'd0; w_s3_refill <= 1'b0; w_s3_data <= 256'd0;
            w_s4_valid <= 1'b0; w_s4_addr <= 32'd0; w_s4_refill <= 1'b0; w_s4_data <= 256'd0;
            w_commit_valid <= 1'b0; w_commit_addr <= 32'd0; w_commit_refill <= 1'b0; w_commit_data <= 256'd0;
        end else begin
            w_s1_valid  <= write_req_active;
            w_s1_addr   <= address;
            w_s1_refill <= is_refill;
            w_s1_data   <= data_in;

            w_s2_valid  <= w_s1_valid;
            w_s2_addr   <= w_s1_addr;
            w_s2_refill <= w_s1_refill;
            w_s2_data   <= w_s1_data;

            w_s3_valid  <= w_s2_valid;
            w_s3_addr   <= w_s2_addr;
            w_s3_refill <= w_s2_refill;
            w_s3_data   <= w_s2_data;

            w_s4_valid  <= w_s3_valid;
            w_s4_addr   <= w_s3_addr;
            w_s4_refill <= w_s3_refill;
            w_s4_data   <= w_s3_data;

            w_commit_valid  <= w_s4_valid;
            w_commit_addr   <= w_s4_addr;
            w_commit_refill <= w_s4_refill;
            w_commit_data   <= w_s4_data;
        end
    end

    // Store-to-Load Forwarding Multiplexer: select newest matching uncompressed data
    wire [255:0] fwd_selected_data = 
        (fwd_stage_sel == 3'd1) ? w_s1_data :
        (fwd_stage_sel == 3'd2) ? w_s2_data :
        (fwd_stage_sel == 3'd3) ? w_s3_data :
        (fwd_stage_sel == 3'd4) ? w_s4_data :
                                  w_commit_data;

    // -------------------------------------------------------------------------
    // 2. CSR Bank & Dynamic Epoch Associativity Governance
    // -------------------------------------------------------------------------
    wire cache_hit_raw;
    wire cache_miss_raw;
    wire [1:0] csr_sel;
    wire       csr_override_en;
    wire       csr_flush_req;

    l2_csr_control_bank csr_bank (
        .clk              (clk),
        .reset            (reset),
        .cpu_address      (cpu_mmio_address),
        .cpu_write_data   (cpu_mmio_wdata),
        .cpu_write_en     (cpu_mmio_wen),
        .cpu_read_data    (cpu_mmio_rdata),
        .cache_hit        (cache_hit_raw),
        .cache_miss       (cache_miss_raw),
        .sel_out          (csr_sel),
        .override_en_out  (csr_override_en),
        .flush_req        (csr_flush_req),
        .prefetch_en_out  (prefetch_en),
        .mshr_en_out      (mshr_en),
        .workload_mode_out(workload_mode)
    );

    wire [1:0] epoch_sel;

    l2_adaptive_power_governor #(
        .EPOCH_SIZE  (1024),
        .THRESH_LOW  (51),
        .THRESH_HIGH (153)
    ) epoch_pmic (
        .clk             (clk),
        .reset           (reset),
        .cache_hit       (cache_hit_raw),
        .cache_miss      (cache_miss_raw),
        .sw_override_en  (csr_override_en),
        .sw_sel          (csr_sel),
        .selection_out   (epoch_sel),
        .dbg_access_count(dbg_access_count),
        .dbg_miss_count  (dbg_miss_count),
        .dbg_epoch_done  (dbg_epoch_done)
    );

    wire [1:0] final_sel = csr_override_en ? csr_sel : epoch_sel;
    assign dbg_current_sel = final_sel;

    // -------------------------------------------------------------------------
    // 3. Pipelined BDI Compressor Engine
    // -------------------------------------------------------------------------
    wire [255:0] compressed_data_out;
    wire [2:0]   compress_type_out;
    wire [14:0]  compress_marks_out;

    l2_bdi_compressor compressor (
        .clk              (clk),
        .reset            (reset),
        .uncompressed_data(data_in),
        .compressed_data  (compressed_data_out),
        .compress_type    (compress_type_out),
        .compress_marks   (compress_marks_out),
        .dcb_bypass_active(dcb_bypass_active)
    );

    // -------------------------------------------------------------------------
    // 4. Fast-Path Decoupled Read Routing & Store-to-Load Forwarding Bypass
    // -------------------------------------------------------------------------
    wire write_commit_now = w_s4_valid;
    // When Store-to-Load Forwarding is active, the read is satisfied from the
    // write pipeline bypass and does NOT access the M9K cache array.
    wire read_admitted    = read_req_active && !hazard_stall && (fwd_valid || !write_commit_now);
    wire cache_read_req   = read_admitted && !fwd_valid;

    wire [31:0]  cache_addr     = write_commit_now ? w_s4_addr : address;
    wire [1:0]   cache_sel      = final_sel;
    wire         cache_write_en = write_commit_now;
    wire [255:0] cache_din      = compressed_data_out;
    wire [2:0]   cache_type_in  = compress_type_out;
    wire [14:0]  cache_marks_in = compress_marks_out;

    // -------------------------------------------------------------------------
    // 5. Synchronous Cache Core Array
    // -------------------------------------------------------------------------
    wire [255:0] compressed_data_from_cache;
    wire [2:0]   compress_type_from_cache;
    wire [14:0]  compress_marks_from_cache;
    wire         core_evict_valid;
    wire [31:0]  core_evict_address;
    wire [255:0] core_evict_data;

    l2_cache_storage_array cache_array (
        .clk               (clk),
        .reset             (reset),
        .address           (cache_addr),
        .selection_signal  (cache_sel),
        .write             (cache_write_en),
        .read_req          (cache_read_req),
        .is_refill         (w_s4_refill),
        .data_in           (cache_din),
        .compress_type_in  (cache_type_in),
        .compress_marks_in (cache_marks_in),
        .out               (compressed_data_from_cache),
        .compress_type_out (compress_type_from_cache),
        .compress_marks_out(compress_marks_from_cache),
        .hit               (cache_hit_raw),
        .miss              (cache_miss_raw),
        .evict_valid       (core_evict_valid),
        .evict_address     (core_evict_address),
        .evict_data        (core_evict_data),
        .evict_ack         (evict_ack)
    );

    assign evict_valid   = core_evict_valid;
    assign evict_address = core_evict_address;
    assign evict_data    = core_evict_data;

    // -------------------------------------------------------------------------
    // 6. Decompression Engine & Deterministic 5-Cycle Output Stage
    // -------------------------------------------------------------------------
    reg [255:0] compressed_data_stage;
    reg [2:0]   compress_type_stage;
    reg [14:0]  compress_marks_stage;
    reg         hit_stage;
    reg         miss_stage;

    wire [255:0] decompressed_stage;
    reg  [255:0] decompressed_stage_reg;
    reg          hit_stage2;
    reg          miss_stage2;

    l2_bdi_decompressor decoder (
        .compressed_data  (compressed_data_stage),
        .compress_type    (compress_type_stage),
        .compress_marks   (compress_marks_stage),
        .decompressed_data(decompressed_stage)
    );

    // 4-stage shift registers for read validation and Store-to-Load Forwarding tracking
    reg [3:0]   read_valid_pipe;
    reg [3:0]   fwd_valid_pipe;
    reg [255:0] fwd_data_pipe_0, fwd_data_pipe_1, fwd_data_pipe_2, fwd_data_pipe_3;

    always @(posedge clk) begin
        if (!reset) begin
            compressed_data_stage  <= 256'd0;
            compress_type_stage    <= 3'd0;
            compress_marks_stage   <= 15'd0;
            hit_stage              <= 1'b0;
            miss_stage             <= 1'b0;

            decompressed_stage_reg <= 256'd0;
            hit_stage2             <= 1'b0;
            miss_stage2            <= 1'b0;

            data_out               <= 256'd0;
            hit                    <= 1'b0;
            miss                   <= 1'b0;
            response_valid         <= 1'b0;
            read_valid_pipe        <= 4'd0;
            fwd_valid_pipe         <= 4'd0;
            fwd_data_pipe_0        <= 256'd0;
            fwd_data_pipe_1        <= 256'd0;
            fwd_data_pipe_2        <= 256'd0;
            fwd_data_pipe_3        <= 256'd0;
        end else begin
            read_valid_pipe <= {read_valid_pipe[2:0], read_admitted};
            response_valid  <= read_valid_pipe[3];

            // Pipelined Store-to-Load Forwarding tracking
            fwd_valid_pipe  <= {fwd_valid_pipe[2:0], (read_admitted && fwd_valid)};
            fwd_data_pipe_0 <= fwd_selected_data;
            fwd_data_pipe_1 <= fwd_data_pipe_0;
            fwd_data_pipe_2 <= fwd_data_pipe_1;
            fwd_data_pipe_3 <= fwd_data_pipe_2;

            // Cycle 3: Capture synchronous core array outputs
            compressed_data_stage <= compressed_data_from_cache;
            compress_type_stage   <= compress_type_from_cache;
            compress_marks_stage  <= compress_marks_from_cache;
            hit_stage             <= cache_hit_raw;
            miss_stage            <= cache_miss_raw;

            // Cycle 4: Register after combinational decompressor
            decompressed_stage_reg <= decompressed_stage;
            hit_stage2             <= hit_stage;
            miss_stage2            <= miss_stage;

            // Cycle 5: Final output presentation (Bypassed if Store-to-Load Forwarding Hit)
            if (fwd_valid_pipe[3]) begin
                data_out <= fwd_data_pipe_3;
                hit      <= 1'b1;
                miss     <= 1'b0;
            end else begin
                data_out <= decompressed_stage_reg;
                hit      <= hit_stage2;
                miss     <= miss_stage2;
            end
        end
    end
    assign dbg_compress_type = compress_type_out;
    assign dbg_fwd_valid     = fwd_valid;

endmodule
