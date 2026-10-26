`timescale 1ns / 1ps
// =============================================================================
// Module Name: l2_cache_controller
// Project:     High-Performance BDI Compressed L2 Cache IP for SoC
// Author:      Mohammed Gweaa
// Standard:    IEEE 1364-2001 (Verilog HDL)
//
// Description:
//   Advanced Level-2 (L2) Cache Controller and Protocol Bus Adapter.
//   Bridges Upstream L1 Caches (L1-I and L1-D via 256-bit Line Interface) to the
//   Synchronous 8-Way BDI Compressed Cache Core (l2_bdi_cache_top) and Downstream
//   External Memory (DRAM Controller).
//
// Advanced Features & Architectural Breakthroughs:
//   1. Full 256-Bit Line Granularity: Eliminates Sub-Word RMW entirely.
//   2. 5-Cycle Fast-Path L2 Read Hits: Deterministic cycle-accurate delivery.
//   3. Non-Blocking MSHR Hit-Under-Miss Engine: While an L2 miss is fetching
//      from DRAM, incoming read requests targeting hitting lines are serviced
//      immediately without stalling the upstream core.
//   4. Stream & Stride Hardware Data Prefetch Engine: Automatically anticipates
//      sequential memory streams, pre-populating lines into a Prefetch Stream
//      Buffer (PSB) to deliver 1-cycle hits on regular memory trajectories.
//   5. Robust Request Latching: Upstream demand requests are captured safely
//      across speculative prefetch intervals, ensuring zero dropped transactions.
// =============================================================================

module l2_cache_controller (
    input  wire        clk,
    input  wire        reset,

    // ── Upstream Interface (from L1 Caches / L1-to-L2 Arbiter) ───────────
    input  wire        l1_req_valid,
    input  wire [31:0] l1_req_addr,      // Line-aligned address ({addr[31:5], 5'b0})
    input  wire        l1_req_write,     // 0 = L1 Read Refill, 1 = L1 Dirty Write-Back
    input  wire [255:0] l1_req_wdata,    // Full 256-bit line from L1
    output reg  [255:0] l2_resp_rdata,   // Full 256-bit line delivered to L1
    output reg         l2_resp_valid,    // 1-cycle pulse when read line is ready
    output wire        l2_ready,         // High when L2 can accept a new request

    // ── Downstream Memory Interface (to External DRAM Controller) ────────
    output reg         mem_req_o,
    output reg         mem_we_o,
    output reg  [31:0] mem_addr_o,
    output reg  [255:0] mem_wdata_o,
    input  wire [255:0] mem_rdata_i,
    input  wire        mem_ready_i,

    // ── CSR & Hardware Telemetry Interface ───────────────────────────────
    input  wire [31:0] csr_address,
    input  wire [31:0] csr_wdata,
    input  wire        csr_we,
    output wire [31:0] csr_rdata,
    output wire [31:0] dbg_l2_hit_count,
    output wire [31:0] dbg_l2_miss_count,
    output wire [1:0]  dbg_current_associativity,
    output wire [31:0] dbg_prefetch_hit_count,
    output reg  [31:0] dbg_hum_hit_count
);

    // Cache Core Control and Data Wires
    reg          core_req_valid;
    reg  [31:0]  core_address;
    reg          core_write;
    reg          core_is_refill;
    reg  [255:0] core_data_in;

    wire [255:0] core_data_out;
    wire         core_hit;
    wire         core_miss;
    wire         core_resp_valid;
    wire         hazard_stall;

    wire         core_evict_valid;
    wire [31:0]  core_evict_address;
    wire [255:0] core_evict_data;
    reg          core_evict_ack;

    // CSR Control Flags from L2 Core
    wire prefetch_en;
    wire mshr_en;
    wire workload_mode;

    reg [31:0] l2_hit_counter;
    reg [31:0] l2_miss_counter;
    assign dbg_l2_hit_count  = l2_hit_counter;
    assign dbg_l2_miss_count = l2_miss_counter;

    // -------------------------------------------------------------------------
    // 1. Instantiation of the BDI Compressed Cache Core (l2_bdi_cache_top)
    // -------------------------------------------------------------------------
    l2_bdi_cache_top l2_core (
        .clk               (clk),
        .reset             (reset),

        // 256-bit Line Interface
        .request_valid     (core_req_valid),
        .address           (core_address),
        .write             (core_write),
        .is_refill         (core_is_refill),
        .data_in           (core_data_in),

        // CSR MMIO Interface
        .cpu_mmio_address  (csr_address),
        .cpu_mmio_wdata    (csr_wdata),
        .cpu_mmio_wen      (csr_we),
        .cpu_mmio_rdata    (csr_rdata),

        // Response Interface (5-Cycle Deterministic Output)
        .data_out          (core_data_out),
        .hit               (core_hit),
        .miss              (core_miss),
        .response_valid    (core_resp_valid),
        .hazard_stall      (hazard_stall),
        .dcb_bypass_active (),

        // Coherent Eviction Interface
        .evict_valid       (core_evict_valid),
        .evict_address     (core_evict_address),
        .evict_data        (core_evict_data),
        .evict_ack         (core_evict_ack),

        // Diagnostics & Control
        .dbg_access_count  (),
        .dbg_miss_count    (),
        .dbg_current_sel   (dbg_current_associativity),
        .dbg_epoch_done    (),
        .dbg_hazard_count  (),
        .prefetch_en       (prefetch_en),
        .mshr_en           (mshr_en),
        .workload_mode     (workload_mode)
    );

    // -------------------------------------------------------------------------
    // 2. Hardware Stride / Stream Prefetch Engine
    // -------------------------------------------------------------------------
    wire        pfetch_req;
    wire [31:0] pfetch_addr;
    reg         pfetch_ack;
    reg         dram_pdata_valid;
    reg  [31:0] dram_pdata_addr;
    reg  [255:0] dram_pdata_line;
    wire        psb_hit;
    wire [255:0] psb_data;
    wire [31:0] dbg_pfetch_issues;

    wire active_l1_req_valid;
    wire [31:0] active_l1_req_addr;
    wire        active_l1_req_write;
    wire [255:0] active_l1_req_wdata;

    l2_hardware_prefetcher prefetch_engine (
        .clk                     (clk),
        .reset                   (reset),
        .prefetch_enable         (prefetch_en),
        .access_valid            (active_l1_req_valid),
        .access_addr             (active_l1_req_addr),
        .access_write            (active_l1_req_write),
        .prefetch_req_o          (pfetch_req),
        .prefetch_addr_o         (pfetch_addr),
        .prefetch_ack_i          (pfetch_ack),
        .dram_pdata_valid        (dram_pdata_valid),
        .dram_pdata_addr         (dram_pdata_addr),
        .dram_pdata_line         (dram_pdata_line),
        .query_addr              (active_l1_req_addr),
        .psb_hit                 (psb_hit),
        .psb_data                (psb_data),
        .dbg_prefetch_issue_count(dbg_pfetch_issues),
        .dbg_prefetch_hit_count  (dbg_prefetch_hit_count)
    );

    // -------------------------------------------------------------------------
    // 3. Controller Finite State Machine (FSM) with Non-Blocking MSHR
    // -------------------------------------------------------------------------
    localparam STATE_IDLE          = 3'd0;
    localparam STATE_LOOKUP_WAIT   = 3'd1;
    localparam STATE_DRAM_EVICT    = 3'd2;
    localparam STATE_DRAM_REFILL   = 3'd3;
    localparam STATE_WRITE_COMMIT  = 3'd4;
    localparam STATE_PREFETCH_FILL = 3'd5;

    reg [2:0]  state;
    reg [2:0]  write_commit_cnt;
    reg [31:0] latched_addr;
    reg [255:0] latched_wdata;
    reg        pending_evict_is_read_miss;

    // Non-Blocking Miss Status Holding Register (MSHR) Entry
    reg        mshr_valid;
    reg [31:0] mshr_addr;

    // Hit-Under-Miss (HUM) Concurrent Probe Tracking
    reg        hum_probe_active;
    reg [31:0] hum_probe_addr;
    reg        dram_fill_pending;
    reg [255:0] dram_fill_data;

    // Pending Request Queue Register (guarantees zero dropped requests during prefetch)
    reg        pending_req_valid;
    reg [31:0] pending_req_addr;
    reg        pending_req_write;
    reg [255:0] pending_req_wdata;

    assign active_l1_req_valid = pending_req_valid ? 1'b1 : l1_req_valid;
    assign active_l1_req_addr  = pending_req_valid ? pending_req_addr : l1_req_addr;
    assign active_l1_req_write = pending_req_valid ? pending_req_write : l1_req_write;
    assign active_l1_req_wdata = pending_req_valid ? pending_req_wdata : l1_req_wdata;

    // Ready signal: Ready when IDLE and no hazard, or when non-blocking MSHR accepts HUM
    wire can_accept_hum = mshr_en && (state == STATE_DRAM_REFILL) && !hum_probe_active && !dram_fill_pending && !l1_req_write;
    assign l2_ready = ((state == STATE_IDLE) && !hazard_stall && !core_evict_valid && !pending_req_valid) || can_accept_hum;

    always @(posedge clk) begin
        if (!reset) begin
            state                      <= STATE_IDLE;
            write_commit_cnt           <= 3'd0;
            l2_resp_rdata              <= 256'd0;
            l2_resp_valid              <= 1'b0;
            mem_req_o                  <= 1'b0;
            mem_we_o                   <= 1'b0;
            mem_addr_o                 <= 32'd0;
            mem_wdata_o                <= 256'd0;
            core_req_valid             <= 1'b0;
            core_address               <= 32'd0;
            core_write                 <= 1'b0;
            core_is_refill             <= 1'b0;
            core_data_in               <= 256'd0;
            core_evict_ack             <= 1'b0;
            latched_addr               <= 32'd0;
            latched_wdata              <= 256'd0;
            pending_evict_is_read_miss <= 1'b0;
            l2_hit_counter             <= 32'd0;
            l2_miss_counter            <= 32'd0;
            mshr_valid                 <= 1'b0;
            mshr_addr                  <= 32'd0;
            hum_probe_active           <= 1'b0;
            hum_probe_addr             <= 32'd0;
            dram_fill_pending          <= 1'b0;
            dram_fill_data             <= 256'd0;
            dbg_hum_hit_count          <= 32'd0;
            pfetch_ack                 <= 1'b0;
            dram_pdata_valid           <= 1'b0;
            dram_pdata_addr            <= 32'd0;
            dram_pdata_line            <= 256'd0;
            pending_req_valid          <= 1'b0;
            pending_req_addr           <= 32'd0;
            pending_req_write          <= 1'b0;
            pending_req_wdata          <= 256'd0;
        end else begin
            core_req_valid   <= 1'b0;
            core_evict_ack   <= 1'b0;
            l2_resp_valid    <= 1'b0;
            pfetch_ack       <= 1'b0;
            dram_pdata_valid <= 1'b0;

            // Capture incoming L1 request if state is currently busy with prefetch
            if (l1_req_valid && (state == STATE_PREFETCH_FILL) && !pending_req_valid) begin
                pending_req_valid <= 1'b1;
                pending_req_addr  <= l1_req_addr;
                pending_req_write <= l1_req_write;
                pending_req_wdata <= l1_req_wdata;
            end

            case (state)
                STATE_IDLE: begin
                    hum_probe_active <= 1'b0;

                    // 1. Check for autonomous L2 victim eviction first
                    if (core_evict_valid) begin
                        mem_req_o                  <= 1'b1;
                        mem_we_o                   <= 1'b1;
                        mem_addr_o                 <= core_evict_address;
                        mem_wdata_o                <= core_evict_data;
                        pending_evict_is_read_miss <= 1'b0;
                        state                      <= STATE_DRAM_EVICT;
                    end
                    // 2. Process active or pending L1 request
                    else if (active_l1_req_valid && !hazard_stall) begin
                        latched_addr      <= {active_l1_req_addr[31:5], 5'b00000};
                        latched_wdata     <= active_l1_req_wdata;
                        pending_req_valid <= 1'b0;

                        if (!active_l1_req_write) begin
                            // Fast check: Prefetch Stream Buffer Hit
                            if (psb_hit) begin
                                l2_resp_rdata  <= psb_data;
                                l2_resp_valid  <= 1'b1;
                                l2_hit_counter <= l2_hit_counter + 1'b1;
                                state          <= STATE_IDLE;
                            end else begin
                                // Issue L2 tag lookup
                                core_req_valid <= 1'b1;
                                core_address   <= {active_l1_req_addr[31:5], 5'b00000};
                                core_write     <= 1'b0;
                                core_is_refill <= 1'b0;
                                state          <= STATE_LOOKUP_WAIT;
                            end
                        end else begin
                            // L1 Dirty Write-Back: Enters BDI compressor pipeline
                            core_req_valid   <= 1'b1;
                            core_address     <= {active_l1_req_addr[31:5], 5'b00000};
                            core_write       <= 1'b1;
                            core_is_refill   <= 1'b0;
                            core_data_in     <= active_l1_req_wdata;
                            write_commit_cnt <= 3'd5;
                            state            <= STATE_WRITE_COMMIT;
                        end
                    end
                    // 3. Speculative Background Hardware Prefetch Issue
                    else if (prefetch_en && pfetch_req && !active_l1_req_valid) begin
                        mem_req_o   <= 1'b1;
                        mem_we_o    <= 1'b0;
                        mem_addr_o  <= pfetch_addr;
                        pfetch_ack  <= 1'b1;
                        state       <= STATE_PREFETCH_FILL;
                    end
                end

                STATE_LOOKUP_WAIT: begin
                    if (core_resp_valid) begin
                        if (core_hit) begin
                            // L2 Read Hit: Deliver decompressed line to L1
                            l2_hit_counter <= l2_hit_counter + 1'b1;
                            l2_resp_rdata  <= core_data_out;
                            l2_resp_valid  <= 1'b1;
                            state          <= STATE_IDLE;
                        end else if (core_miss) begin
                            // L2 Read Miss: Allocate MSHR and fetch from DRAM
                            l2_miss_counter <= l2_miss_counter + 1'b1;
                            mshr_valid      <= 1'b1;
                            mshr_addr       <= latched_addr;

                            if (core_evict_valid) begin
                                mem_req_o                  <= 1'b1;
                                mem_we_o                   <= 1'b1;
                                mem_addr_o                 <= core_evict_address;
                                mem_wdata_o                <= core_evict_data;
                                pending_evict_is_read_miss <= 1'b1;
                                state                      <= STATE_DRAM_EVICT;
                            end else begin
                                mem_req_o  <= 1'b1;
                                mem_we_o   <= 1'b0;
                                mem_addr_o <= latched_addr;
                                state      <= STATE_DRAM_REFILL;
                            end
                        end
                    end
                end

                STATE_DRAM_EVICT: begin
                    if (mem_ready_i) begin
                        mem_req_o      <= 1'b0;
                        mem_we_o       <= 1'b0;
                        core_evict_ack <= 1'b1;

                        if (pending_evict_is_read_miss) begin
                            mem_req_o  <= 1'b1;
                            mem_we_o   <= 1'b0;
                            mem_addr_o <= latched_addr;
                            state      <= STATE_DRAM_REFILL;
                        end else begin
                            state      <= STATE_IDLE;
                        end
                    end
                end

                STATE_DRAM_REFILL: begin
                    // ── Non-Blocking MSHR Hit-Under-Miss (HUM) Evaluation ───────
                    if (can_accept_hum && l1_req_valid) begin
                        if (l1_req_addr[31:5] != mshr_addr[31:5]) begin
                            if (psb_hit) begin
                                l2_resp_rdata     <= psb_data;
                                l2_resp_valid     <= 1'b1;
                                l2_hit_counter    <= l2_hit_counter + 1'b1;
                                dbg_hum_hit_count <= dbg_hum_hit_count + 1'b1;
                            end else begin
                                core_req_valid   <= 1'b1;
                                core_address     <= {l1_req_addr[31:5], 5'b00000};
                                core_write       <= 1'b0;
                                core_is_refill   <= 1'b0;
                                hum_probe_active <= 1'b1;
                                hum_probe_addr   <= l1_req_addr;
                            end
                        end
                    end

                    // Capture concurrent Hit-Under-Miss response from core
                    if (hum_probe_active && core_resp_valid) begin
                        hum_probe_active <= 1'b0;
                        if (core_hit) begin
                            l2_resp_rdata     <= core_data_out;
                            l2_resp_valid     <= 1'b1;
                            l2_hit_counter    <= l2_hit_counter + 1'b1;
                            dbg_hum_hit_count <= dbg_hum_hit_count + 1'b1;
                        end
                    end

                    // DRAM Refill Transaction Completion / Arbitration
                    if (mem_ready_i) begin
                        mem_req_o <= 1'b0;
                        if (hum_probe_active) begin
                            // HUM probe is currently accessing core array; buffer DRAM line to avoid collision
                            dram_fill_pending <= 1'b1;
                            dram_fill_data    <= mem_rdata_i;
                        end else begin
                            mshr_valid       <= 1'b0;
                            l2_resp_rdata    <= mem_rdata_i;
                            l2_resp_valid    <= 1'b1;
                            core_req_valid   <= 1'b1;
                            core_address     <= latched_addr;
                            core_write       <= 1'b1;
                            core_is_refill   <= 1'b1;
                            core_data_in     <= mem_rdata_i;
                            write_commit_cnt <= 3'd5;
                            state            <= STATE_WRITE_COMMIT;
                        end
                    end else if (dram_fill_pending && !hum_probe_active) begin
                        // Release buffered DRAM refill immediately after HUM probe concludes
                        dram_fill_pending <= 1'b0;
                        mshr_valid        <= 1'b0;
                        l2_resp_rdata     <= dram_fill_data;
                        l2_resp_valid     <= 1'b1;
                        core_req_valid    <= 1'b1;
                        core_address      <= latched_addr;
                        core_write        <= 1'b1;
                        core_is_refill    <= 1'b1;
                        core_data_in      <= dram_fill_data;
                        write_commit_cnt  <= 3'd5;
                        state             <= STATE_WRITE_COMMIT;
                    end
                end

                STATE_PREFETCH_FILL: begin
                    if (mem_ready_i) begin
                        mem_req_o        <= 1'b0;
                        dram_pdata_valid <= 1'b1;
                        dram_pdata_addr  <= mem_addr_o;
                        dram_pdata_line  <= mem_rdata_i;
                        state            <= STATE_IDLE;
                    end
                end

                STATE_WRITE_COMMIT: begin
                    if (write_commit_cnt > 3'd1) begin
                        write_commit_cnt <= write_commit_cnt - 1'b1;
                    end else begin
                        state <= STATE_IDLE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
