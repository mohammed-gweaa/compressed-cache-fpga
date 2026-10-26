`timescale 1ns / 1ps
// =============================================================================
// Module Name: l2_conventional_cache_top
// Project:     Baseline Benchmark Architecture for Level-2 Cache Comparative Study
// Author:      Mohammed Gweaa
// Standard:    IEEE 1364-2001 (Verilog HDL)
//
// Description:
//   Standard Conventional (Uncompressed) 8-Way Set-Associative Level-2 Cache.
//   Serves as the rigorous physical baseline for evaluating the BDI Compressed
//   L2 Cache under identical silicon capacity (16 KB) and bus parameters.
//
// Baseline Architectural Characteristics:
//   1. Uncompressed 256-Bit Ways: Physical SRAM capacity strictly equals 16 KB.
//      Fixed 1-to-1 line mapping (Maximum 512 lines; No virtual expansion).
//   2. 3-Cycle Read Hit Latency: Direct synchronous SRAM read with tag-way mux.
//   3. Standard RAW Hazard Detection: Asserts 'hazard_stall' on Read-After-Write
//      conflicts, forcing upstream pipeline stalls (No STLF bypass).
//   4. Fixed 8-Way Associativity: Static tree-PLRU replacement without dynamic
//      power governance or way-halting throttling.
//   5. 100% Embedded M9K Block RAM Compatible.
// =============================================================================

module l2_conventional_cache_top (
    input  wire        clk,
    input  wire        reset,

    // Primary Core Interface (256-bit Line Interface)
    input  wire        request_valid,
    input  wire [31:0] address,
    input  wire        write,
    input  wire        is_refill,
    input  wire [255:0] data_in,

    // CSR MMIO Software-Directed Control Interface (Dummy for interface parity)
    input  wire [31:0] cpu_mmio_address,
    input  wire [31:0] cpu_mmio_wdata,
    input  wire        cpu_mmio_wen,
    output wire [31:0] cpu_mmio_rdata,

    // Primary Cache Response Interface
    output reg  [255:0] data_out,
    output reg         hit,
    output reg         miss,
    output reg         response_valid,
    output wire        hazard_stall,
    output wire        dcb_bypass_active,

    // Safe Atomic Eviction Interface
    output reg         evict_valid,
    output reg  [31:0] evict_address,
    output reg  [255:0] evict_data,
    input  wire        evict_ack,

    // Telemetry and Hardware Diagnostic Probes
    output reg  [9:0]  dbg_access_count,
    output reg  [9:0]  dbg_miss_count,
    output wire [1:0]  dbg_current_sel,
    output wire        dbg_epoch_done,
    output reg  [31:0] dbg_hazard_count
);

    assign dcb_bypass_active = 1'b0;
    assign dbg_current_sel   = 2'b11; // Fixed 8-way associativity
    assign dbg_epoch_done    = 1'b0;
    assign cpu_mmio_rdata    = 32'd0;

    // Address Partitioning: [10:5] Set Index (6b, 64 sets)
    wire [5:0] req_set = address[10:5];

    // -------------------------------------------------------------------------
    // 1. Storage Arrays: 8 Ways of Data (256-bit) and Tags (21-bit)
    // -------------------------------------------------------------------------
    (* ramstyle = "M9K" *) reg [255:0] data_ram0 [0:63];
    (* ramstyle = "M9K" *) reg [255:0] data_ram1 [0:63];
    (* ramstyle = "M9K" *) reg [255:0] data_ram2 [0:63];
    (* ramstyle = "M9K" *) reg [255:0] data_ram3 [0:63];
    (* ramstyle = "M9K" *) reg [255:0] data_ram4 [0:63];
    (* ramstyle = "M9K" *) reg [255:0] data_ram5 [0:63];
    (* ramstyle = "M9K" *) reg [255:0] data_ram6 [0:63];
    (* ramstyle = "M9K" *) reg [255:0] data_ram7 [0:63];

    reg [20:0] tag_ram0 [0:63];
    reg [20:0] tag_ram1 [0:63];
    reg [20:0] tag_ram2 [0:63];
    reg [20:0] tag_ram3 [0:63];
    reg [20:0] tag_ram4 [0:63];
    reg [20:0] tag_ram5 [0:63];
    reg [20:0] tag_ram6 [0:63];
    reg [20:0] tag_ram7 [0:63];

    reg valid_ram0 [0:63];
    reg valid_ram1 [0:63];
    reg valid_ram2 [0:63];
    reg valid_ram3 [0:63];
    reg valid_ram4 [0:63];
    reg valid_ram5 [0:63];
    reg valid_ram6 [0:63];
    reg valid_ram7 [0:63];

    reg dirty_ram0 [0:63];
    reg dirty_ram1 [0:63];
    reg dirty_ram2 [0:63];
    reg dirty_ram3 [0:63];
    reg dirty_ram4 [0:63];
    reg dirty_ram5 [0:63];
    reg dirty_ram6 [0:63];
    reg dirty_ram7 [0:63];

    reg [6:0] plru_tree [0:63];

    integer init_idx;
    initial begin
        for (init_idx = 0; init_idx < 64; init_idx = init_idx + 1) begin
            data_ram0[init_idx] = 256'd0; data_ram1[init_idx] = 256'd0;
            data_ram2[init_idx] = 256'd0; data_ram3[init_idx] = 256'd0;
            data_ram4[init_idx] = 256'd0; data_ram5[init_idx] = 256'd0;
            data_ram6[init_idx] = 256'd0; data_ram7[init_idx] = 256'd0;

            tag_ram0[init_idx] = 21'd0; tag_ram1[init_idx] = 21'd0;
            tag_ram2[init_idx] = 21'd0; tag_ram3[init_idx] = 21'd0;
            tag_ram4[init_idx] = 21'd0; tag_ram5[init_idx] = 21'd0;
            tag_ram6[init_idx] = 21'd0; tag_ram7[init_idx] = 21'd0;

            valid_ram0[init_idx] = 1'b0; valid_ram1[init_idx] = 1'b0;
            valid_ram2[init_idx] = 1'b0; valid_ram3[init_idx] = 1'b0;
            valid_ram4[init_idx] = 1'b0; valid_ram5[init_idx] = 1'b0;
            valid_ram6[init_idx] = 1'b0; valid_ram7[init_idx] = 1'b0;

            dirty_ram0[init_idx] = 1'b0; dirty_ram1[init_idx] = 1'b0;
            dirty_ram2[init_idx] = 1'b0; dirty_ram3[init_idx] = 1'b0;
            dirty_ram4[init_idx] = 1'b0; dirty_ram5[init_idx] = 1'b0;
            dirty_ram6[init_idx] = 1'b0; dirty_ram7[init_idx] = 1'b0;

            plru_tree[init_idx] = 7'd0;
        end
    end

    // -------------------------------------------------------------------------
    // 2. Standard RAW Hazard Detection (Pipeline Interlock Stall)
    // -------------------------------------------------------------------------
    reg        in_flight_write_valid;
    reg [31:0] in_flight_write_addr;

    wire raw_hazard = request_valid && !write && in_flight_write_valid &&
                      (address[31:5] == in_flight_write_addr[31:5]);

    assign hazard_stall = raw_hazard;

    // -------------------------------------------------------------------------
    // 3. Tree-PLRU Replacement Logic
    // -------------------------------------------------------------------------
    function [2:0] get_victim_way;
        input [6:0] tree;
        reg v0, v1, v2;
        begin
            v2 = tree[0];
            v1 = tree[0] ? tree[2] : tree[1];
            v0 = tree[0] ? (tree[2] ? tree[6] : tree[5]) : (tree[1] ? tree[4] : tree[3]);
            get_victim_way = {v2, v1, v0};
        end
    endfunction

    function [6:0] update_plru;
        input [6:0] tree;
        input [2:0] access_way;
        reg [6:0] next_tree;
        begin
            next_tree = tree;
            next_tree[0] = ~access_way[2];
            if (access_way[2]) begin
                next_tree[2] = ~access_way[1];
                if (access_way[1])
                    next_tree[6] = ~access_way[0];
                else
                    next_tree[5] = ~access_way[0];
            end else begin
                next_tree[1] = ~access_way[1];
                if (access_way[1])
                    next_tree[4] = ~access_way[0];
                else
                    next_tree[3] = ~access_way[0];
            end
            update_plru = next_tree;
        end
    endfunction

    // -------------------------------------------------------------------------
    // 4. Synchronous Read and Write Pipeline
    // -------------------------------------------------------------------------
    reg [31:0]  pipe_addr_r1;
    reg         pipe_valid_r1;
    reg         pipe_write_r1;

    reg [255:0] read_data_way [0:7];
    reg [20:0]  read_tag_way  [0:7];
    reg         read_val_way  [0:7];
    reg         read_dir_way  [0:7];

    // Stage 1 -> Stage 2: Synchronous SRAM Access
    always @(posedge clk) begin
        if (!reset) begin
            pipe_valid_r1 <= 1'b0;
            pipe_addr_r1  <= 32'd0;
            pipe_write_r1 <= 1'b0;
            in_flight_write_valid <= 1'b0;
            in_flight_write_addr  <= 32'd0;
            dbg_access_count      <= 10'd0;
            dbg_hazard_count      <= 32'd0;
        end else begin
            // Track in-flight write
            if (request_valid && write) begin
                in_flight_write_valid <= 1'b1;
                in_flight_write_addr  <= address;
            end else begin
                in_flight_write_valid <= 1'b0;
            end

            if (raw_hazard) begin
                dbg_hazard_count <= dbg_hazard_count + 1'b1;
            end

            // Cycle 1: Latch read request
            if (request_valid && !hazard_stall) begin
                pipe_valid_r1 <= 1'b1;
                pipe_addr_r1  <= address;
                pipe_write_r1 <= write;
                dbg_access_count <= dbg_access_count + 1'b1;

                // Synchronous SRAM Read across all 8 ways
                read_data_way[0] <= data_ram0[req_set];
                read_data_way[1] <= data_ram1[req_set];
                read_data_way[2] <= data_ram2[req_set];
                read_data_way[3] <= data_ram3[req_set];
                read_data_way[4] <= data_ram4[req_set];
                read_data_way[5] <= data_ram5[req_set];
                read_data_way[6] <= data_ram6[req_set];
                read_data_way[7] <= data_ram7[req_set];

                read_tag_way[0]  <= tag_ram0[req_set];
                read_tag_way[1]  <= tag_ram1[req_set];
                read_tag_way[2]  <= tag_ram2[req_set];
                read_tag_way[3]  <= tag_ram3[req_set];
                read_tag_way[4]  <= tag_ram4[req_set];
                read_tag_way[5]  <= tag_ram5[req_set];
                read_tag_way[6]  <= tag_ram6[req_set];
                read_tag_way[7]  <= tag_ram7[req_set];

                read_val_way[0]  <= valid_ram0[req_set];
                read_val_way[1]  <= valid_ram1[req_set];
                read_val_way[2]  <= valid_ram2[req_set];
                read_val_way[3]  <= valid_ram3[req_set];
                read_val_way[4]  <= valid_ram4[req_set];
                read_val_way[5]  <= valid_ram5[req_set];
                read_val_way[6]  <= valid_ram6[req_set];
                read_val_way[7]  <= valid_ram7[req_set];

                read_dir_way[0]  <= dirty_ram0[req_set];
                read_dir_way[1]  <= dirty_ram1[req_set];
                read_dir_way[2]  <= dirty_ram2[req_set];
                read_dir_way[3]  <= dirty_ram3[req_set];
                read_dir_way[4]  <= dirty_ram4[req_set];
                read_dir_way[5]  <= dirty_ram5[req_set];
                read_dir_way[6]  <= dirty_ram6[req_set];
                read_dir_way[7]  <= dirty_ram7[req_set];
            end else begin
                pipe_valid_r1 <= 1'b0;
            end
        end
    end

    // Stage 2 -> Stage 3: Tag Comparison, Match Evaluation & Write-Back Execution
    wire [20:0] check_tag = pipe_addr_r1[31:11];
    wire [5:0]  check_set = pipe_addr_r1[10:5];

    wire match0 = read_val_way[0] && (read_tag_way[0] == check_tag);
    wire match1 = read_val_way[1] && (read_tag_way[1] == check_tag);
    wire match2 = read_val_way[2] && (read_tag_way[2] == check_tag);
    wire match3 = read_val_way[3] && (read_tag_way[3] == check_tag);
    wire match4 = read_val_way[4] && (read_tag_way[4] == check_tag);
    wire match5 = read_val_way[5] && (read_tag_way[5] == check_tag);
    wire match6 = read_val_way[6] && (read_tag_way[6] == check_tag);
    wire match7 = read_val_way[7] && (read_tag_way[7] == check_tag);

    wire tag_hit = match0 || match1 || match2 || match3 ||
                   match4 || match5 || match6 || match7;

    reg [2:0] hit_way_enc;
    always @(*) begin
        if (match0) hit_way_enc = 3'd0;
        else if (match1) hit_way_enc = 3'd1;
        else if (match2) hit_way_enc = 3'd2;
        else if (match3) hit_way_enc = 3'd3;
        else if (match4) hit_way_enc = 3'd4;
        else if (match5) hit_way_enc = 3'd5;
        else if (match6) hit_way_enc = 3'd6;
        else hit_way_enc = 3'd7;
    end

    wire [2:0] victim_way = get_victim_way(plru_tree[check_set]);
    wire [2:0] write_target_way = tag_hit ? hit_way_enc : victim_way;

    always @(posedge clk) begin
        if (!reset) begin
            data_out       <= 256'd0;
            hit            <= 1'b0;
            miss           <= 1'b0;
            response_valid <= 1'b0;
            evict_valid    <= 1'b0;
            evict_address  <= 32'd0;
            evict_data     <= 256'd0;
            dbg_miss_count <= 10'd0;
        end else begin
            response_valid <= 1'b0;
            hit            <= 1'b0;
            miss           <= 1'b0;

            if (evict_ack) begin
                evict_valid <= 1'b0;
            end

            if (pipe_valid_r1) begin
                if (!pipe_write_r1) begin
                    // ── Read Transaction ──────────────────────────────────────
                    response_valid <= 1'b1;
                    if (tag_hit) begin
                        hit      <= 1'b1;
                        miss     <= 1'b0;
                        data_out <= read_data_way[hit_way_enc];
                        plru_tree[check_set] <= update_plru(plru_tree[check_set], hit_way_enc);
                    end else begin
                        hit  <= 1'b0;
                        miss <= 1'b1;
                        dbg_miss_count <= dbg_miss_count + 1'b1;
                    end
                end else begin
                    // ── Write Transaction ─────────────────────────────────────
                    if (!tag_hit) begin
                        // Evict victim if valid and dirty
                        if (read_val_way[victim_way] && read_dir_way[victim_way]) begin
                            evict_valid   <= 1'b1;
                            evict_address <= {read_tag_way[victim_way], check_set, 5'b00000};
                            evict_data    <= read_data_way[victim_way];
                        end
                    end

                    // Update PLRU
                    plru_tree[check_set] <= update_plru(plru_tree[check_set], write_target_way);

                    // Dedicated M9K Write port per way
                    case (write_target_way)
                        3'd0: begin
                            data_ram0[check_set]  <= data_in;
                            tag_ram0[check_set]   <= check_tag;
                            valid_ram0[check_set] <= 1'b1;
                            dirty_ram0[check_set] <= ~is_refill;
                        end
                        3'd1: begin
                            data_ram1[check_set]  <= data_in;
                            tag_ram1[check_set]   <= check_tag;
                            valid_ram1[check_set] <= 1'b1;
                            dirty_ram1[check_set] <= ~is_refill;
                        end
                        3'd2: begin
                            data_ram2[check_set]  <= data_in;
                            tag_ram2[check_set]   <= check_tag;
                            valid_ram2[check_set] <= 1'b1;
                            dirty_ram2[check_set] <= ~is_refill;
                        end
                        3'd3: begin
                            data_ram3[check_set]  <= data_in;
                            tag_ram3[check_set]   <= check_tag;
                            valid_ram3[check_set] <= 1'b1;
                            dirty_ram3[check_set] <= ~is_refill;
                        end
                        3'd4: begin
                            data_ram4[check_set]  <= data_in;
                            tag_ram4[check_set]   <= check_tag;
                            valid_ram4[check_set] <= 1'b1;
                            dirty_ram4[check_set] <= ~is_refill;
                        end
                        3'd5: begin
                            data_ram5[check_set]  <= data_in;
                            tag_ram5[check_set]   <= check_tag;
                            valid_ram5[check_set] <= 1'b1;
                            dirty_ram5[check_set] <= ~is_refill;
                        end
                        3'd6: begin
                            data_ram6[check_set]  <= data_in;
                            tag_ram6[check_set]   <= check_tag;
                            valid_ram6[check_set] <= 1'b1;
                            dirty_ram6[check_set] <= ~is_refill;
                        end
                        3'd7: begin
                            data_ram7[check_set]  <= data_in;
                            tag_ram7[check_set]   <= check_tag;
                            valid_ram7[check_set] <= 1'b1;
                            dirty_ram7[check_set] <= ~is_refill;
                        end
                    endcase
                end
            end
        end
    end

endmodule
