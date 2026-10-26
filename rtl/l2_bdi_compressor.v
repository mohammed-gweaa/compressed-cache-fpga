`timescale 1ns / 1ps
// =============================================================================
// Module Name: l2_bdi_compressor
// Project:     High-Performance BDI Compressed L2 Cache Subsystem for SoC
// Author:      Mohammed Gweaa
// Standard:    IEEE 1364-2001 (Verilog HDL)
//
// Description:
//   Pipelined Base-Delta-Immediate (BDI) Compression Engine.
//   Supports 6 compression profiles:
//     - Type 0 (3'b000): Incompressible Fallback (256-bit payload)
//     - Type 1 (3'b001): Base8 + 8-bit Delta (B8-Δ1, 96-bit payload)
//     - Type 2 (3'b010): Base8 + 16-bit Delta (B8-Δ2, 112-bit payload)
//     - Type 3 (3'b011): All-Zeros Line (0-bit payload)
//     - Type 4 (3'b100): Base4 + 8-bit Delta (B4-Δ1, 96-bit payload)
//     - Type 5 (3'b101): Same-Value Line (Repeated 32-bit word, 32-bit payload)
//
// Features:
//   - 4-stage fully synchronous balanced pipeline (3 arithmetic stages + 1 registered output stage) for high Fmax.
//   - Dynamic Compression Bypass (DCB) with 4-bit saturating counter and
//     periodic probe window for incompressible workloads.
// =============================================================================

module l2_bdi_compressor (
    input  wire        clk,
    input  wire        reset,
    input  wire [255:0] uncompressed_data,

    output reg  [255:0] compressed_data,
    output reg  [2:0]   compress_type,
    output reg  [14:0]  compress_marks,
    output wire        dcb_bypass_active
);

    // -------------------------------------------------------------------------
    // Pipeline Stage 1: Base Extraction, Parallel Subtractions & Difference Marks
    // -------------------------------------------------------------------------
    reg [255:0] s1_uncompressed_data;
    reg [63:0]  s1_base8;
    reg [31:0]  s1_base4;
    reg [63:0]  s1_del8_1, s1_del8_2, s1_del8_3;
    reg         s1_mark8_1, s1_mark8_2, s1_mark8_3;
    reg [31:0]  s1_del4_1, s1_del4_2, s1_del4_3, s1_del4_4, s1_del4_5, s1_del4_6, s1_del4_7;
    reg         s1_mark4_1, s1_mark4_2, s1_mark4_3, s1_mark4_4, s1_mark4_5, s1_mark4_6, s1_mark4_7;
    reg         s1_is_zero;
    reg         s1_is_same_word;

    always @(posedge clk) begin
        if (!reset) begin
            s1_uncompressed_data <= 256'd0;
            s1_base8             <= 64'd0;
            s1_base4             <= 32'd0;
            s1_del8_1 <= 64'd0; s1_del8_2 <= 64'd0; s1_del8_3 <= 64'd0;
            s1_mark8_1 <= 1'b0; s1_mark8_2 <= 1'b0; s1_mark8_3 <= 1'b0;
            s1_del4_1 <= 32'd0; s1_del4_2 <= 32'd0; s1_del4_3 <= 32'd0; s1_del4_4 <= 32'd0;
            s1_del4_5 <= 32'd0; s1_del4_6 <= 32'd0; s1_del4_7 <= 32'd0;
            s1_mark4_1 <= 1'b0; s1_mark4_2 <= 1'b0; s1_mark4_3 <= 1'b0; s1_mark4_4 <= 1'b0;
            s1_mark4_5 <= 1'b0; s1_mark4_6 <= 1'b0; s1_mark4_7 <= 1'b0;
            s1_is_zero           <= 1'b0;
            s1_is_same_word      <= 1'b0;
        end else begin
            s1_uncompressed_data <= uncompressed_data;
            s1_base8             <= uncompressed_data[63:0];
            s1_base4             <= uncompressed_data[31:0];

            // Base8 Differences (8-byte units)
            s1_mark8_1 <= (uncompressed_data[63:0] <= uncompressed_data[127:64]);
            s1_del8_1  <= (uncompressed_data[63:0] <= uncompressed_data[127:64]) ?
                          (uncompressed_data[127:64] - uncompressed_data[63:0]) :
                          (uncompressed_data[63:0] - uncompressed_data[127:64]);

            s1_mark8_2 <= (uncompressed_data[63:0] <= uncompressed_data[191:128]);
            s1_del8_2  <= (uncompressed_data[63:0] <= uncompressed_data[191:128]) ?
                          (uncompressed_data[191:128] - uncompressed_data[63:0]) :
                          (uncompressed_data[63:0] - uncompressed_data[191:128]);

            s1_mark8_3 <= (uncompressed_data[63:0] <= uncompressed_data[255:192]);
            s1_del8_3  <= (uncompressed_data[63:0] <= uncompressed_data[255:192]) ?
                          (uncompressed_data[255:192] - uncompressed_data[63:0]) :
                          (uncompressed_data[63:0] - uncompressed_data[255:192]);

            // Base4 Differences (4-byte units)
            s1_mark4_1 <= (uncompressed_data[31:0] <= uncompressed_data[63:32]);
            s1_del4_1  <= (uncompressed_data[31:0] <= uncompressed_data[63:32]) ?
                          (uncompressed_data[63:32] - uncompressed_data[31:0]) :
                          (uncompressed_data[31:0] - uncompressed_data[63:32]);

            s1_mark4_2 <= (uncompressed_data[31:0] <= uncompressed_data[95:64]);
            s1_del4_2  <= (uncompressed_data[31:0] <= uncompressed_data[95:64]) ?
                          (uncompressed_data[95:64] - uncompressed_data[31:0]) :
                          (uncompressed_data[31:0] - uncompressed_data[95:64]);

            s1_mark4_3 <= (uncompressed_data[31:0] <= uncompressed_data[127:96]);
            s1_del4_3  <= (uncompressed_data[31:0] <= uncompressed_data[127:96]) ?
                          (uncompressed_data[127:96] - uncompressed_data[31:0]) :
                          (uncompressed_data[31:0] - uncompressed_data[127:96]);

            s1_mark4_4 <= (uncompressed_data[31:0] <= uncompressed_data[159:128]);
            s1_del4_4  <= (uncompressed_data[31:0] <= uncompressed_data[159:128]) ?
                          (uncompressed_data[159:128] - uncompressed_data[31:0]) :
                          (uncompressed_data[31:0] - uncompressed_data[159:128]);

            s1_mark4_5 <= (uncompressed_data[31:0] <= uncompressed_data[191:160]);
            s1_del4_5  <= (uncompressed_data[31:0] <= uncompressed_data[191:160]) ?
                          (uncompressed_data[191:160] - uncompressed_data[31:0]) :
                          (uncompressed_data[31:0] - uncompressed_data[191:160]);

            s1_mark4_6 <= (uncompressed_data[31:0] <= uncompressed_data[223:192]);
            s1_del4_6  <= (uncompressed_data[31:0] <= uncompressed_data[223:192]) ?
                          (uncompressed_data[223:192] - uncompressed_data[31:0]) :
                          (uncompressed_data[31:0] - uncompressed_data[223:192]);

            s1_mark4_7 <= (uncompressed_data[31:0] <= uncompressed_data[255:224]);
            s1_del4_7  <= (uncompressed_data[31:0] <= uncompressed_data[255:224]) ?
                          (uncompressed_data[255:224] - uncompressed_data[31:0]) :
                          (uncompressed_data[31:0] - uncompressed_data[255:224]);

            // Special Pattern Detectors
            s1_is_zero <= (uncompressed_data == 256'd0);
            s1_is_same_word <= (uncompressed_data[31:0]   == uncompressed_data[63:32])   &&
                               (uncompressed_data[63:32]  == uncompressed_data[95:64])   &&
                               (uncompressed_data[95:64]  == uncompressed_data[127:96])  &&
                               (uncompressed_data[127:96] == uncompressed_data[159:128]) &&
                               (uncompressed_data[159:128]== uncompressed_data[191:160]) &&
                               (uncompressed_data[191:160]== uncompressed_data[223:192]) &&
                               (uncompressed_data[223:192]== uncompressed_data[255:224]);
        end
    end

    // -------------------------------------------------------------------------
    // Pipeline Stage 2: Retiming Register - Range Bound Evaluation
    // -------------------------------------------------------------------------
    reg [255:0] s2_uncompressed_data;
    reg [63:0]  s2_base8;
    reg [31:0]  s2_base4;
    reg [63:0]  s2_del8_1, s2_del8_2, s2_del8_3;
    reg [31:0]  s2_del4_1, s2_del4_2, s2_del4_3, s2_del4_4, s2_del4_5, s2_del4_6, s2_del4_7;
    reg [14:0]  s2_marks8;
    reg [14:0]  s2_marks4;
    reg         s2_c1_valid, s2_c2_valid, s2_c4_valid;
    reg         s2_is_zero;
    reg         s2_is_same_word;

    always @(posedge clk) begin
        if (!reset) begin
            s2_uncompressed_data <= 256'd0;
            s2_base8             <= 64'd0;
            s2_base4             <= 32'd0;
            s2_del8_1 <= 64'd0; s2_del8_2 <= 64'd0; s2_del8_3 <= 64'd0;
            s2_del4_1 <= 32'd0; s2_del4_2 <= 32'd0; s2_del4_3 <= 32'd0; s2_del4_4 <= 32'd0;
            s2_del4_5 <= 32'd0; s2_del4_6 <= 32'd0; s2_del4_7 <= 32'd0;
            s2_marks8            <= 15'd0;
            s2_marks4            <= 15'd0;
            s2_c1_valid          <= 1'b0;
            s2_c2_valid          <= 1'b0;
            s2_c4_valid          <= 1'b0;
            s2_is_zero           <= 1'b0;
            s2_is_same_word      <= 1'b0;
        end else begin
            s2_uncompressed_data <= s1_uncompressed_data;
            s2_base8             <= s1_base8;
            s2_base4             <= s1_base4;
            s2_del8_1            <= s1_del8_1;
            s2_del8_2            <= s1_del8_2;
            s2_del8_3            <= s1_del8_3;
            s2_del4_1            <= s1_del4_1;
            s2_del4_2            <= s1_del4_2;
            s2_del4_3            <= s1_del4_3;
            s2_del4_4            <= s1_del4_4;
            s2_del4_5            <= s1_del4_5;
            s2_del4_6            <= s1_del4_6;
            s2_del4_7            <= s1_del4_7;
            s2_marks8            <= {12'd0, s1_mark8_3, s1_mark8_2, s1_mark8_1};
            s2_marks4            <= {8'd0, s1_mark4_7, s1_mark4_6, s1_mark4_5, s1_mark4_4, s1_mark4_3, s1_mark4_2, s1_mark4_1};

            // Fast bound checks (evaluating delta thresholds)
            s2_c1_valid <= (s1_del8_1 < 64'd256) && (s1_del8_2 < 64'd256) && (s1_del8_3 < 64'd256);
            s2_c2_valid <= (s1_del8_1 < 64'd65536) && (s1_del8_2 < 64'd65536) && (s1_del8_3 < 64'd65536);
            s2_c4_valid <= (s1_del4_1 < 32'd256) && (s1_del4_2 < 32'd256) && (s1_del4_3 < 32'd256) &&
                           (s1_del4_4 < 32'd256) && (s1_del4_5 < 32'd256) && (s1_del4_6 < 32'd256) &&
                           (s1_del4_7 < 32'd256);
            s2_is_zero      <= s1_is_zero;
            s2_is_same_word <= s1_is_same_word;
        end
    end

    // -------------------------------------------------------------------------
    // Pipeline Stage 3: Candidate Payload Assembly & Priority Decision
    // -------------------------------------------------------------------------
    reg [255:0] s3_uncompressed_data;
    reg [255:0] s3_compressed_payload;
    reg [2:0]   s3_compress_type;
    reg [14:0]  s3_compress_marks;
    reg         s3_is_compressible;

    always @(posedge clk) begin
        if (!reset) begin
            s3_uncompressed_data  <= 256'd0;
            s3_compressed_payload <= 256'd0;
            s3_compress_type      <= 3'd0;
            s3_compress_marks     <= 15'd0;
            s3_is_compressible    <= 1'b0;
        end else begin
            s3_uncompressed_data <= s2_uncompressed_data;
            s3_is_compressible   <= s2_is_zero || s2_is_same_word || s2_c1_valid || s2_c4_valid || s2_c2_valid;

            if (s2_is_zero) begin
                // Type 3: All-Zeros Line (0-bit payload)
                s3_compressed_payload <= 256'd0;
                s3_compress_type      <= 3'd3;
                s3_compress_marks     <= 15'd0;
            end else if (s2_c1_valid) begin
                // Type 1: Base8 + 8-bit Delta (B8-Δ1, 96-bit payload)
                s3_compressed_payload <= {160'd0, s2_del8_3[7:0], s2_del8_2[7:0], s2_del8_1[7:0], 8'd0, s2_base8};
                s3_compress_type      <= 3'd1;
                s3_compress_marks     <= s2_marks8;
            end else if (s2_c4_valid) begin
                // Type 4: Base4 + 8-bit Delta (B4-Δ1, 96-bit payload)
                s3_compressed_payload <= {160'd0, s2_del4_7[7:0], s2_del4_6[7:0], s2_del4_5[7:0], s2_del4_4[7:0],
                                          s2_del4_3[7:0], s2_del4_2[7:0], s2_del4_1[7:0], 8'd0, s2_base4};
                s3_compress_type      <= 3'd4;
                s3_compress_marks     <= s2_marks4;
            end else if (s2_is_same_word) begin
                // Type 5: Same-Value Line (Repeated 32-bit word, 32-bit payload)
                s3_compressed_payload <= {224'd0, s2_base4};
                s3_compress_type      <= 3'd5;
                s3_compress_marks     <= 15'd0;
            end else if (s2_c2_valid) begin
                // Type 2: Base8 + 16-bit Delta (B8-Δ2, 112-bit payload)
                s3_compressed_payload <= {144'd0, s2_del8_3[15:0], s2_del8_2[15:0], s2_del8_1[15:0], s2_base8};
                s3_compress_type      <= 3'd2;
                s3_compress_marks     <= s2_marks8;
            end else begin
                // Type 0: Incompressible Fallback (256-bit payload)
                s3_compressed_payload <= s2_uncompressed_data;
                s3_compress_type      <= 3'd0;
                s3_compress_marks     <= 15'd0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Dynamic Compression Bypass (DCB) Adaptive Filter
    // -------------------------------------------------------------------------
    reg [3:0] dcb_counter;
    reg [7:0] dcb_probe_timer;

    assign dcb_bypass_active = (dcb_counter <= 4'd2);

    always @(posedge clk) begin
        if (!reset) begin
            dcb_counter     <= 4'd8; // Neutral midpoint
            dcb_probe_timer <= 8'd0;
        end else begin
            dcb_probe_timer <= dcb_probe_timer + 1'b1;

            if (dcb_probe_timer == 8'd255) begin
                // Periodic probe window reset: Re-sample data stream entropy
                dcb_counter <= 4'd8;
            end else if (s3_is_compressible) begin
                if (dcb_counter < 4'd15)
                    dcb_counter <= dcb_counter + 1'b1;
            end else begin
                if (dcb_counter >= 4'd2)
                    dcb_counter <= dcb_counter - 4'd2;
                else
                    dcb_counter <= 4'd0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Pipeline Stage 4: Dynamic Bypass & Synchronized Final Output Presentation
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!reset) begin
            compressed_data <= 256'd0;
            compress_type   <= 3'd0;
            compress_marks  <= 15'd0;
        end else if (dcb_bypass_active) begin
            // Dynamic bypass active: Passthrough uncompressed raw data
            compressed_data <= s3_uncompressed_data;
            compress_type   <= 3'd0;
            compress_marks  <= 15'd0;
        end else begin
            compressed_data <= s3_compressed_payload;
            compress_type   <= s3_compress_type;
            compress_marks  <= s3_compress_marks;
        end
    end

endmodule


