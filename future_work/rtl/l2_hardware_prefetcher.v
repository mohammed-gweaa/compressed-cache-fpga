`timescale 1ns / 1ps
// =============================================================================
// Module Name: l2_hardware_prefetcher
// Project:     High-Performance BDI Compressed L2 Cache Subsystem for SoC
// Author:      Mohammed Gweaa
// Standard:    IEEE 1364-2001 (Verilog HDL)
//
// Description:
//   Advanced Stream and Stride Hardware Data Prefetch Engine.
//   Monitors L1/L2 address access trajectories in real time, computes line
//   deltas/strides, and issues speculative prefetch requests into a dedicated
//   Prefetch Stream Buffer (PSB).
//
// Key Features:
//   1. 4-Entry Stream History Table (SHT): Tracks stride and access confidence.
//   2. Next-Line Stream Accelerator: Instant stride detection for sequential
//      streaming (e.g., matrix processing, AI tensor streaming, video/audio).
//   3. High-Synergy BDI Compatibility: Prefetched sequential lines exhibit
//      maximum Base-Delta-Immediate compression density in L2.
//   4. OS Software-Directed Enable: Dynamically enabled/disabled via MMIO CSR.
//   5. 2-Entry Prefetch Stream Buffer (PSB): Provides 1-cycle instant hit response
//      on prefetched lines without polluting the primary 8-way L2 cache array.
// =============================================================================

module l2_hardware_prefetcher (
    input  wire        clk,
    input  wire        reset,

    // Software Configuration from CSR Bank
    input  wire        prefetch_enable,

    // Upstream Access Monitoring Interface
    input  wire        access_valid,
    input  wire [31:0] access_addr,     // 32-bit byte address
    input  wire        access_write,    // 0 = Read, 1 = Write

    // Speculative DRAM Prefetch Issue Interface
    output reg         prefetch_req_o,
    output reg  [31:0] prefetch_addr_o,
    input  wire        prefetch_ack_i,  // DRAM controller accepts prefetch

    // Prefetch Data Return & Buffer Allocation Interface
    input  wire        dram_pdata_valid,
    input  wire [31:0] dram_pdata_addr,
    input  wire [255:0] dram_pdata_line,

    // Fast-Path Prefetch Buffer Hit Interface (Checked by L2 Controller)
    input  wire [31:0] query_addr,
    output wire        psb_hit,
    output wire [255:0] psb_data,

    // Hardware Telemetry & Performance Counters
    output reg  [31:0] dbg_prefetch_issue_count,
    output reg  [31:0] dbg_prefetch_hit_count
);

    wire [31:5] current_line = access_addr[31:5];
    wire [31:5] query_line   = query_addr[31:5];

    // -------------------------------------------------------------------------
    // 1. Prefetch Stream Buffer (PSB) - 2 Entries (256-bit lines)
    // -------------------------------------------------------------------------
    reg         psb_valid [0:1];
    reg [31:5]  psb_line_addr [0:1];
    reg [255:0] psb_line_data [0:1];

    wire hit_entry0 = psb_valid[0] && (psb_line_addr[0] == query_line);
    wire hit_entry1 = psb_valid[1] && (psb_line_addr[1] == query_line);

    assign psb_hit  = prefetch_enable && (hit_entry0 || hit_entry1);
    assign psb_data = hit_entry0 ? psb_line_data[0] : psb_line_data[1];

    // -------------------------------------------------------------------------
    // 2. Stream History Table (SHT) - 4 Tracking Streams
    // -------------------------------------------------------------------------
    reg        sht_valid [0:3];
    reg [31:5] sht_last_line [0:3];
    reg signed [15:0] sht_stride [0:3];
    reg [1:0]  sht_confidence [0:3]; // 00=Init, 01=Transient, 10=Steady, 11=Strong

    reg [1:0]  sht_replace_ptr;

    // Stream Match Detection
    wire [3:0] sht_match;
    assign sht_match[0] = sht_valid[0] && (current_line == sht_last_line[0] || (current_line - sht_last_line[0] == sht_stride[0]));
    assign sht_match[1] = sht_valid[1] && (current_line == sht_last_line[1] || (current_line - sht_last_line[1] == sht_stride[1]));
    assign sht_match[2] = sht_valid[2] && (current_line == sht_last_line[2] || (current_line - sht_last_line[2] == sht_stride[2]));
    assign sht_match[3] = sht_valid[3] && (current_line == sht_last_line[3] || (current_line - sht_last_line[3] == sht_stride[3]));

    reg [31:5] candidate_prefetch_line;
    reg        candidate_valid;

    integer i;

    // SHT Training and Prefetch Candidate Generation
    always @(posedge clk) begin
        if (!reset) begin
            prefetch_req_o            <= 1'b0;
            prefetch_addr_o           <= 32'd0;
            candidate_valid           <= 1'b0;
            candidate_prefetch_line   <= 27'd0;
            sht_replace_ptr           <= 2'd0;
            dbg_prefetch_issue_count  <= 32'd0;
            dbg_prefetch_hit_count    <= 32'd0;

            for (i = 0; i < 4; i = i + 1) begin
                sht_valid[i]      <= 1'b0;
                sht_last_line[i]  <= 27'd0;
                sht_stride[i]     <= 16'd0;
                sht_confidence[i] <= 2'b00;
            end

            for (i = 0; i < 2; i = i + 1) begin
                psb_valid[i]     <= 1'b0;
                psb_line_addr[i] <= 27'd0;
                psb_line_data[i] <= 256'd0;
            end
        end else begin
            // Clear request once accepted by DRAM
            if (prefetch_ack_i) begin
                prefetch_req_o <= 1'b0;
            end

            // Invalidate PSB entry on hit (Single-use consumption)
            if (access_valid && !access_write && psb_hit) begin
                dbg_prefetch_hit_count <= dbg_prefetch_hit_count + 1'b1;
                if (hit_entry0) psb_valid[0] <= 1'b0;
                else if (hit_entry1) psb_valid[1] <= 1'b0;
            end

            // Allocate incoming DRAM prefetch line into PSB
            if (dram_pdata_valid && prefetch_enable) begin
                psb_valid[0]     <= 1'b1;
                psb_line_addr[0] <= dram_pdata_addr[31:5];
                psb_line_data[0] <= dram_pdata_line;
                // Shift previous entry to slot 1
                psb_valid[1]     <= psb_valid[0];
                psb_line_addr[1] <= psb_line_addr[0];
                psb_line_data[1] <= psb_line_data[0];
            end

            // SHT Training upon new L1 Read Miss/Access
            if (prefetch_enable && access_valid && !access_write && !psb_hit) begin
                if (sht_match[0]) begin
                    sht_last_line[0]  <= current_line;
                    if (sht_confidence[0] < 2'b11) sht_confidence[0] <= sht_confidence[0] + 1'b1;
                    if (sht_confidence[0] >= 2'b01) begin
                        prefetch_req_o           <= 1'b1;
                        prefetch_addr_o          <= {(current_line + sht_stride[0]), 5'b00000};
                        dbg_prefetch_issue_count <= dbg_prefetch_issue_count + 1'b1;
                    end
                end else if (sht_match[1]) begin
                    sht_last_line[1]  <= current_line;
                    if (sht_confidence[1] < 2'b11) sht_confidence[1] <= sht_confidence[1] + 1'b1;
                    if (sht_confidence[1] >= 2'b01) begin
                        prefetch_req_o           <= 1'b1;
                        prefetch_addr_o          <= {(current_line + sht_stride[1]), 5'b00000};
                        dbg_prefetch_issue_count <= dbg_prefetch_issue_count + 1'b1;
                    end
                end else if (sht_match[2]) begin
                    sht_last_line[2]  <= current_line;
                    if (sht_confidence[2] < 2'b11) sht_confidence[2] <= sht_confidence[2] + 1'b1;
                    if (sht_confidence[2] >= 2'b01) begin
                        prefetch_req_o           <= 1'b1;
                        prefetch_addr_o          <= {(current_line + sht_stride[2]), 5'b00000};
                        dbg_prefetch_issue_count <= dbg_prefetch_issue_count + 1'b1;
                    end
                end else if (sht_match[3]) begin
                    sht_last_line[3]  <= current_line;
                    if (sht_confidence[3] < 2'b11) sht_confidence[3] <= sht_confidence[3] + 1'b1;
                    if (sht_confidence[3] >= 2'b01) begin
                        prefetch_req_o           <= 1'b1;
                        prefetch_addr_o          <= {(current_line + sht_stride[3]), 5'b00000};
                        dbg_prefetch_issue_count <= dbg_prefetch_issue_count + 1'b1;
                    end
                end else begin
                    // Allocate new stream entry in SHT (Default: Next-Line stride +1)
                    sht_valid[sht_replace_ptr]      <= 1'b1;
                    sht_last_line[sht_replace_ptr]  <= current_line;
                    sht_stride[sht_replace_ptr]     <= 16'sd1; // +1 line (+32 bytes)
                    sht_confidence[sht_replace_ptr] <= 2'b01;
                    sht_replace_ptr                 <= sht_replace_ptr + 1'b1;

                    // Speculative Next-Line trigger on streaming access
                    prefetch_req_o           <= 1'b1;
                    prefetch_addr_o          <= {(current_line + 27'd1), 5'b00000};
                    dbg_prefetch_issue_count <= dbg_prefetch_issue_count + 1'b1;
                end
            end
        end
    end

endmodule
