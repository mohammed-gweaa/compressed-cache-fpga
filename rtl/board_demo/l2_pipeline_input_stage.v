`timescale 1ns / 1ps
// =============================================================================
// Module Name: l2_pipeline_input_stage
// Project:     High-Performance BDI Compressed L2 Cache Subsystem for SoC
// Author:      Mohammed Gweaa
// Standard:    IEEE 1364-2001 (Verilog HDL)
//
// Description:
//   L2 Cache Pipeline Input Staging and Synchronization Stage.
//   Aligns control signals (address, selection, write-enable) with the 3-cycle
//   pipelined compressor payload latency, ensuring simultaneous arrival at the
//   L2 cache storage array.
// =============================================================================

module l2_pipeline_input_stage (
    input  wire        clk,
    input  wire        reset,

    // Unsynchronized Frontend Inputs
    input  wire [31:0] address_in,
    input  wire [1:0]  selection_in,
    input  wire        write_in,
    input  wire [255:0] data_uncompressed_in,

    // Synchronized Outputs
    output wire [31:0] address_sync,
    output wire [1:0]  selection_sync,
    output wire        write_sync,

    // Compressed Outputs (from Pipelined BDI Compressor)
    output wire [255:0] compressed_data_out,
    output wire [2:0]   compress_type_out,
    output wire [14:0]  compress_marks_out,
    output wire        dcb_bypass_active
);

    // 4-Stage Synchronization Delay Registers (Retimed to match 4-stage BDI compressor)
    reg [31:0] addr_d1, addr_d2, addr_d3, addr_d4;
    reg [1:0]  sel_d1,  sel_d2,  sel_d3,  sel_d4;
    reg        we_d1,   we_d2,   we_d3,   we_d4;

    always @(posedge clk) begin
        if (!reset) begin
            addr_d1 <= 32'd0; addr_d2 <= 32'd0; addr_d3 <= 32'd0; addr_d4 <= 32'd0;
            sel_d1  <= 2'd0;  sel_d2  <= 2'd0;  sel_d3  <= 2'd0;  sel_d4  <= 2'd0;
            we_d1   <= 1'b0;  we_d2   <= 1'b0;  we_d3   <= 1'b0;  we_d4   <= 1'b0;
        end else begin
            addr_d1 <= address_in;  addr_d2 <= addr_d1; addr_d3 <= addr_d2; addr_d4 <= addr_d3;
            sel_d1  <= selection_in;sel_d2  <= sel_d1;  sel_d3  <= sel_d2;  sel_d4  <= sel_d3;
            we_d1   <= write_in;    we_d2   <= we_d1;   we_d3   <= we_d2;   we_d4   <= we_d3;
        end
    end

    assign address_sync   = addr_d4;
    assign selection_sync = sel_d4;
    assign write_sync     = we_d4;

    // Integrated Pipelined BDI Compressor
    l2_bdi_compressor compressor_inst (
        .clk              (clk),
        .reset            (reset),
        .uncompressed_data(data_uncompressed_in),
        .compressed_data  (compressed_data_out),
        .compress_type    (compress_type_out),
        .compress_marks   (compress_marks_out),
        .dcb_bypass_active(dcb_bypass_active)
    );

endmodule
