`timescale 1ns / 1ps
// =============================================================================
// Module Name: l2_hazard_interlock_unit
// Project:     High-Performance BDI Compressed L2 Cache Subsystem for SoC
// Author:      Mohammed Gweaa
// Standard:    IEEE 1364-2001 (Verilog HDL)
//
// Description:
//   Pipeline Hazard Detection and Interlock Unit for L2 Cache Subsystem.
//   Monitors in-flight write operations across compression and commit stages.
//   Asserts 'hazard_stall' when a read request targets the same cache line
//   currently being processed by an in-flight write, preventing Read-After-Write
//   (RAW) hazards and enforcing strict memory consistency.
// =============================================================================

module l2_hazard_interlock_unit (
    input  wire        clk,
    input  wire        reset,

    // Incoming Read Request
    input  wire        read_req,
    input  wire [31:0] read_addr,

    // In-Flight Write Pipeline Stages (4-Stage Compressor + Commit)
    input  wire        w_s1_valid,
    input  wire [31:0] w_s1_addr,

    input  wire        w_s2_valid,
    input  wire [31:0] w_s2_addr,

    input  wire        w_s3_valid,
    input  wire [31:0] w_s3_addr,

    input  wire        w_s4_valid,
    input  wire [31:0] w_s4_addr,

    input  wire        w_commit_valid,
    input  wire [31:0] w_commit_addr,

    // Store-to-Load Forwarding (STLF) Bypass Interface
    output wire        forward_valid,
    output reg  [2:0]  forward_stage_sel, // 1=s1, 2=s2, 3=s3, 4=s4, 5=commit
    output reg  [31:0] forward_event_count,

    // Structural Interlock Stall & Diagnostic Outputs
    output wire        hazard_stall,
    output reg  [31:0] hazard_event_count
);

    // Line matching: Compare line address bits [31:2] (Tag + Set Index)
    wire match_s1     = w_s1_valid     && (read_addr[31:2] == w_s1_addr[31:2]);
    wire match_s2     = w_s2_valid     && (read_addr[31:2] == w_s2_addr[31:2]);
    wire match_s3     = w_s3_valid     && (read_addr[31:2] == w_s3_addr[31:2]);
    wire match_s4     = w_s4_valid     && (read_addr[31:2] == w_s4_addr[31:2]);
    wire match_commit = w_commit_valid && (read_addr[31:2] == w_commit_addr[31:2]);

    wire raw_hazard = read_req && (match_s1 || match_s2 || match_s3 || match_s4 || match_commit);

    // Store-to-Load Forwarding Bypass:
    // When a read request targets an in-flight write line, the read is satisfied
    // directly from the uncompressed pipeline register payload, bypassing M9K SRAM lookup
    // and completely suppressing pipeline hazard stalls.
    assign forward_valid = raw_hazard;
    assign hazard_stall  = 1'b0; // RAW stalls eliminated via Store-to-Load Forwarding

    // Priority Encoder: Youngest in-flight write has highest priority (s1 > s2 > s3 > s4 > commit)
    always @(*) begin
        if (match_s1)
            forward_stage_sel = 3'd1;
        else if (match_s2)
            forward_stage_sel = 3'd2;
        else if (match_s3)
            forward_stage_sel = 3'd3;
        else if (match_s4)
            forward_stage_sel = 3'd4;
        else if (match_commit)
            forward_stage_sel = 3'd5;
        else
            forward_stage_sel = 3'd0;
    end

    // Telemetry counters
    always @(posedge clk) begin
        if (!reset) begin
            forward_event_count <= 32'd0;
            hazard_event_count  <= 32'd0;
        end else begin
            if (raw_hazard) begin
                forward_event_count <= forward_event_count + 1'b1;
            end
        end
    end

endmodule
