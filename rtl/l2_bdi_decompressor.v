`timescale 1ns / 1ps
// =============================================================================
// Module Name: l2_bdi_decompressor
// Project:     High-Performance BDI Compressed L2 Cache Subsystem for SoC
// Author:      Mohammed Gweaa
// Standard:    IEEE 1364-2001 (Verilog HDL)
//
// Description:
//   Pure single-cycle combinational decompressor for fast read-hit path.
//   Reconstructs the full 256-bit uncompressed cache line from the base
//   and deltas across all 6 supported profiles:
//     - Type 0: Uncompressed Direct Passthrough
//     - Type 1: Base8 + 8-bit Delta (B8-Δ1)
//     - Type 2: Base8 + 16-bit Delta (B8-Δ2)
//     - Type 3: All-Zeros Line
//     - Type 4: Base4 + 8-bit Delta (B4-Δ1)
//     - Type 5: Same-Value Line (Repeated 32-bit word)
// =============================================================================

module l2_bdi_decompressor (
    input  wire [255:0] compressed_data,
    input  wire [2:0]   compress_type,
    input  wire [14:0]  compress_marks,
    output reg  [255:0] decompressed_data
);

    reg [63:0] base8;
    reg [31:0] base4;

    always @(*) begin
        decompressed_data = 256'd0;
        base8 = compressed_data[63:0];
        base4 = compressed_data[31:0];

        case (compress_type)
            3'd3: begin
                // Type 3: All-Zeros Line
                decompressed_data = 256'd0;
            end

            3'd5: begin
                // Type 5: Same-Value Line (Repeated 32-bit word)
                decompressed_data = {base4, base4, base4, base4, base4, base4, base4, base4};
            end

            3'd1: begin
                // Type 1: Base8 + 8-bit Delta (B8-Δ1)
                decompressed_data[63:0]    = base8;
                decompressed_data[127:64]  = (compress_marks[0] == 1'b0) ? base8 - compressed_data[79:72]  : base8 + compressed_data[79:72];
                decompressed_data[191:128] = (compress_marks[1] == 1'b0) ? base8 - compressed_data[87:80]  : base8 + compressed_data[87:80];
                decompressed_data[255:192] = (compress_marks[2] == 1'b0) ? base8 - compressed_data[95:88]  : base8 + compressed_data[95:88];
            end

            3'd2: begin
                // Type 2: Base8 + 16-bit Delta (B8-Δ2)
                decompressed_data[63:0]    = base8;
                decompressed_data[127:64]  = (compress_marks[0] == 1'b0) ? base8 - compressed_data[79:64]  : base8 + compressed_data[79:64];
                decompressed_data[191:128] = (compress_marks[1] == 1'b0) ? base8 - compressed_data[95:80]  : base8 + compressed_data[95:80];
                decompressed_data[255:192] = (compress_marks[2] == 1'b0) ? base8 - compressed_data[111:96] : base8 + compressed_data[111:96];
            end

            3'd4: begin
                // Type 4: Base4 + 8-bit Delta (B4-Δ1)
                decompressed_data[31:0]    = base4;
                decompressed_data[63:32]   = (compress_marks[0] == 1'b0) ? base4 - compressed_data[47:40] : base4 + compressed_data[47:40];
                decompressed_data[95:64]   = (compress_marks[1] == 1'b0) ? base4 - compressed_data[55:48] : base4 + compressed_data[55:48];
                decompressed_data[127:96]  = (compress_marks[2] == 1'b0) ? base4 - compressed_data[63:56] : base4 + compressed_data[63:56];
                decompressed_data[159:128] = (compress_marks[3] == 1'b0) ? base4 - compressed_data[71:64] : base4 + compressed_data[71:64];
                decompressed_data[191:160] = (compress_marks[4] == 1'b0) ? base4 - compressed_data[79:72] : base4 + compressed_data[79:72];
                decompressed_data[223:192] = (compress_marks[5] == 1'b0) ? base4 - compressed_data[87:80] : base4 + compressed_data[87:80];
                decompressed_data[255:224] = (compress_marks[6] == 1'b0) ? base4 - compressed_data[95:88] : base4 + compressed_data[95:88];
            end

            default: begin
                // Type 0: Uncompressed Direct Passthrough
                decompressed_data = compressed_data;
            end
        endcase
    end

endmodule
