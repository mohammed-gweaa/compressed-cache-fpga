`timescale 1ns / 1ps
// =============================================================================
// Module Name: l2_ram_block
// Project:     High-Performance BDI Compressed L2 Cache Subsystem for SoC
// Author:      Mohammed Gweaa
// Standard:    IEEE 1364-2001 (Verilog HDL)
//
// Description:
//   Synchronous True Dual-Port M9K/BRAM Memory Primitive (64 depth x 137 width).
//   Provides dedicated read and write ports with registered inputs and outputs,
//   inferred directly as embedded Block RAM (M9K) on Altera/Intel FPGAs.
// =============================================================================

module l2_ram_block (
    input  wire        clk,
    input  wire        rden,
    input  wire [5:0]  raddr,
    input  wire        wren,
    input  wire [5:0]  waddr,
    input  wire [136:0] din,
    output reg  [136:0] dout
);

    (* ramstyle = "M9K" *) reg [136:0] mem [0:63];
    integer ram_init_idx;

    initial begin
        dout = 137'b0;
        for (ram_init_idx = 0; ram_init_idx < 64; ram_init_idx = ram_init_idx + 1)
            mem[ram_init_idx] = 137'b0;
    end

    always @(posedge clk) begin
        if (wren)
            mem[waddr] <= din;
        if (rden)
            dout <= mem[raddr];
    end

endmodule
