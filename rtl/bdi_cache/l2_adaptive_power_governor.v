`timescale 1ns / 1ps
// =============================================================================
// Module Name: l2_adaptive_power_governor
// Project:     High-Performance BDI Compressed L2 Cache Subsystem for SoC
// Author:      Mohammed Gweaa
// Standard:    IEEE 1364-2001 (Verilog HDL)
//
// Description:
//   Dynamic L2 Cache Power & Associativity Governor (Epoch Controller).
//   Monitors L2 cache miss rates over sliding operational windows (epochs).
//   Dynamically throttles active ways to reduce dynamic switching power when
//   the workload exhibits low miss rates (< 5%), and expands associativity up
//   to full 8-way when miss rates spike (> 15%).
// =============================================================================

module l2_adaptive_power_governor #(
    parameter integer EPOCH_SIZE  = 1024,
    parameter integer THRESH_LOW  = 51,   // ~5% of EPOCH_SIZE
    parameter integer THRESH_HIGH = 153   // ~15% of EPOCH_SIZE
)(
    input  wire        clk,
    input  wire        reset,

    // Cache Activity Signals
    input  wire        cache_hit,
    input  wire        cache_miss,

    // Software Override Inputs (from CSR Bank)
    input  wire        sw_override_en,
    input  wire [1:0]  sw_sel,

    // Controlled Associativity Output (00=1W, 01=2W, 10=4W, 11=8W)
    output reg  [1:0]  selection_out,

    // Diagnostic Probes
    output wire [9:0]  dbg_access_count,
    output wire [9:0]  dbg_miss_count,
    output wire        dbg_epoch_done
);

    reg [9:0] access_count;
    reg [9:0] miss_count;
    reg [9:0] epoch_miss_latch;
    reg       epoch_boundary;

    assign dbg_access_count = access_count;
    assign dbg_miss_count   = miss_count;
    assign dbg_epoch_done   = epoch_boundary;

    // Epoch Window Counter Logic
    always @(posedge clk) begin
        if (!reset) begin
            access_count     <= 10'd0;
            miss_count       <= 10'd0;
            epoch_miss_latch <= 10'd0;
            epoch_boundary   <= 1'b0;
        end else begin
            epoch_boundary   <= 1'b0;

            if (cache_hit || cache_miss) begin
                if (access_count == (EPOCH_SIZE - 1)) begin
                    access_count     <= 10'd0;
                    miss_count       <= 10'd0;
                    epoch_miss_latch <= miss_count + (cache_miss ? 10'd1 : 10'd0);
                    epoch_boundary   <= 1'b1;
                end else begin
                    access_count <= access_count + 10'd1;
                    if (cache_miss)
                        miss_count <= miss_count + 10'd1;
                end
            end
        end
    end

    // Associativity Adjustment FSM
    reg [1:0] current_sel;

    always @(posedge clk) begin
        if (!reset) begin
            current_sel <= 2'b11; // Default to full 8-way performance mode
        end else if (epoch_boundary && !sw_override_en) begin
            if (epoch_miss_latch < THRESH_LOW) begin
                // Low miss rate: Throttle associativity down to conserve power
                case (current_sel)
                    2'b11: current_sel <= 2'b10; // 8-Way -> 4-Way
                    2'b10: current_sel <= 2'b01; // 4-Way -> 2-Way
                    2'b01: current_sel <= 2'b00; // 2-Way -> 1-Way
                    2'b00: current_sel <= 2'b00; // Floor limit
                endcase
            end else if (epoch_miss_latch > THRESH_HIGH) begin
                // High miss rate: Scale associativity up to recover performance
                case (current_sel)
                    2'b00: current_sel <= 2'b01; // 1-Way -> 2-Way
                    2'b01: current_sel <= 2'b10; // 2-Way -> 4-Way
                    2'b10: current_sel <= 2'b11; // 4-Way -> 8-Way
                    2'b11: current_sel <= 2'b11; // Ceiling limit
                endcase
            end
        end
    end

    always @(*) begin
        if (sw_override_en)
            selection_out = sw_sel;
        else
            selection_out = current_sel;
    end

endmodule
