`timescale 1ns / 1ps
// =============================================================================
// Module Name: l2_cache_storage_array
// Project:     High-Performance BDI Compressed L2 Cache Subsystem for SoC
// Author:      Mohammed Gweaa
// Standard:    IEEE 1364-2001 (Verilog HDL)
//
// Description:
//   Synchronous 8-Way Set-Associative Dual-Sub-Block Compressed Cache Array.
//   Target Architecture: 100% Embedded RAM (Intel M9K / Block RAM) Compatible.
//
// Key Features:
//   1. Fully synchronous tag lookup (Cycle 1) and way-halted data access (Cycle 2).
//   2. Dual Sub-Block Packing (A/B halves): Packs up to two compressed lines into
//      a single 256-bit physical way, effectively doubling cache capacity.
//   3. Tree-PLRU (Pseudo Least Recently Used) 7-bit replacement policy per set.
//   4. Full Dual Dirty-Bit Tracking (1024 bits: 64 sets x 8 ways x 2 halves).
//   5. Coherent Victim Retiming Register & Atomic Eviction Handshake Interface.
// =============================================================================

module l2_cache_storage_array (
    input  wire        clk,
    input  wire        reset,

    // Processor / Pipeline Request Interface
    input  wire [31:0] address,
    input  wire [1:0]  selection_signal, // 00=1-way, 01=2-way, 10=4-way, 11=8-way
    input  wire        write,
    input  wire        read_req,
    input  wire        is_refill,
    input  wire [255:0] data_in,
    input  wire [2:0]   compress_type_in,
    input  wire [14:0]  compress_marks_in,

    // Read Response Interface
    output wire [255:0] out,
    output wire [2:0]   compress_type_out,
    output wire [14:0]  compress_marks_out,
    output wire        hit,
    output wire        miss,

    // Safe Atomic Eviction Interface
    output reg         evict_valid,
    output reg  [31:0] evict_address,
    output reg  [255:0] evict_data,
    input  wire        evict_ack
);

    wire [5:0] index = address[7:2];

    // -------------------------------------------------------------------------
    // 1. Data RAM Outputs from Dedicated Embedded RAM Blocks (M9K Compatible)
    // -------------------------------------------------------------------------
    wire [136:0] rmem1_A_out, rmem1_B_out, rmem2_A_out, rmem2_B_out;
    wire [136:0] rmem3_A_out, rmem3_B_out, rmem4_A_out, rmem4_B_out;
    wire [136:0] rmem5_A_out, rmem5_B_out, rmem6_A_out, rmem6_B_out;
    wire [136:0] rmem7_A_out, rmem7_B_out, rmem8_A_out, rmem8_B_out;

    // Synchronous Tag Arrays (Mapped to M9K Blocks)
    (* ramstyle = "M9K" *) reg [23:0] TAG_A_MEM1 [0:63]; (* ramstyle = "M9K" *) reg [23:0] TAG_B_MEM1 [0:63];
    (* ramstyle = "M9K" *) reg [23:0] TAG_A_MEM2 [0:63]; (* ramstyle = "M9K" *) reg [23:0] TAG_B_MEM2 [0:63];
    (* ramstyle = "M9K" *) reg [23:0] TAG_A_MEM3 [0:63]; (* ramstyle = "M9K" *) reg [23:0] TAG_B_MEM3 [0:63];
    (* ramstyle = "M9K" *) reg [23:0] TAG_A_MEM4 [0:63]; (* ramstyle = "M9K" *) reg [23:0] TAG_B_MEM4 [0:63];
    (* ramstyle = "M9K" *) reg [23:0] TAG_A_MEM5 [0:63]; (* ramstyle = "M9K" *) reg [23:0] TAG_B_MEM5 [0:63];
    (* ramstyle = "M9K" *) reg [23:0] TAG_A_MEM6 [0:63]; (* ramstyle = "M9K" *) reg [23:0] TAG_B_MEM6 [0:63];
    (* ramstyle = "M9K" *) reg [23:0] TAG_A_MEM7 [0:63]; (* ramstyle = "M9K" *) reg [23:0] TAG_B_MEM7 [0:63];
    (* ramstyle = "M9K" *) reg [23:0] TAG_A_MEM8 [0:63]; (* ramstyle = "M9K" *) reg [23:0] TAG_B_MEM8 [0:63];

    // Status Trees (Valid and Compression Flags)
    reg [63:0] uncompressed_tree1; reg [63:0] valid_A_tree1; reg [63:0] valid_B_tree1;
    reg [63:0] uncompressed_tree2; reg [63:0] valid_A_tree2; reg [63:0] valid_B_tree2;
    reg [63:0] uncompressed_tree3; reg [63:0] valid_A_tree3; reg [63:0] valid_B_tree3;
    reg [63:0] uncompressed_tree4; reg [63:0] valid_A_tree4; reg [63:0] valid_B_tree4;
    reg [63:0] uncompressed_tree5; reg [63:0] valid_A_tree5; reg [63:0] valid_B_tree5;
    reg [63:0] uncompressed_tree6; reg [63:0] valid_A_tree6; reg [63:0] valid_B_tree6;
    reg [63:0] uncompressed_tree7; reg [63:0] valid_A_tree7; reg [63:0] valid_B_tree7;
    reg [63:0] uncompressed_tree8; reg [63:0] valid_A_tree8; reg [63:0] valid_B_tree8;

    // Dual Dirty-Bit Status Trees (64 sets x 8 ways x 2 halves)
    reg [63:0] dirty_A_tree1; reg [63:0] dirty_B_tree1;
    reg [63:0] dirty_A_tree2; reg [63:0] dirty_B_tree2;
    reg [63:0] dirty_A_tree3; reg [63:0] dirty_B_tree3;
    reg [63:0] dirty_A_tree4; reg [63:0] dirty_B_tree4;
    reg [63:0] dirty_A_tree5; reg [63:0] dirty_B_tree5;
    reg [63:0] dirty_A_tree6; reg [63:0] dirty_B_tree6;
    reg [63:0] dirty_A_tree7; reg [63:0] dirty_B_tree7;
    reg [63:0] dirty_A_tree8; reg [63:0] dirty_B_tree8;

    // Initialization for clean power-up simulation state
    integer plru_idx;
    initial begin
        for (plru_idx = 0; plru_idx < 64; plru_idx = plru_idx + 1) begin
            TAG_A_MEM1[plru_idx] = 24'b0; TAG_B_MEM1[plru_idx] = 24'b0;
            TAG_A_MEM2[plru_idx] = 24'b0; TAG_B_MEM2[plru_idx] = 24'b0;
            TAG_A_MEM3[plru_idx] = 24'b0; TAG_B_MEM3[plru_idx] = 24'b0;
            TAG_A_MEM4[plru_idx] = 24'b0; TAG_B_MEM4[plru_idx] = 24'b0;
            TAG_A_MEM5[plru_idx] = 24'b0; TAG_B_MEM5[plru_idx] = 24'b0;
            TAG_A_MEM6[plru_idx] = 24'b0; TAG_B_MEM6[plru_idx] = 24'b0;
            TAG_A_MEM7[plru_idx] = 24'b0; TAG_B_MEM7[plru_idx] = 24'b0;
            TAG_A_MEM8[plru_idx] = 24'b0; TAG_B_MEM8[plru_idx] = 24'b0;
        end
    end

    // -------------------------------------------------------------------------
    // 2. Tree-PLRU Replacement Logic (Early Calculation for Critical Path)
    // -------------------------------------------------------------------------
    reg [6:0] plru_tree [0:63];
    integer plru_init_idx;
    initial begin
        for (plru_init_idx = 0; plru_init_idx < 64; plru_init_idx = plru_init_idx + 1)
            plru_tree[plru_init_idx] = 7'b0;
    end

    wire [6:0] early_plru = plru_tree[address[7:2]];
    wire [2:0] early_plru_way_8 =
        (early_plru[0] == 1'b0) ?
            ((early_plru[1] == 1'b0) ? (early_plru[3] == 1'b0 ? 3'd0 : 3'd1) : (early_plru[4] == 1'b0 ? 3'd2 : 3'd3)) :
            ((early_plru[2] == 1'b0) ? (early_plru[5] == 1'b0 ? 3'd4 : 3'd5) : (early_plru[6] == 1'b0 ? 3'd6 : 3'd7));

    wire [2:0] early_replace_way =
        (selection_signal == 2'b00) ? 3'd0 :
        (selection_signal == 2'b01) ? (early_plru[3] == 1'b0 ? 3'd0 : 3'd1) :
        (selection_signal == 2'b10) ? ((early_plru[1] == 1'b0) ? (early_plru[3] == 1'b0 ? 3'd0 : 3'd1) : (early_plru[4] == 1'b0 ? 3'd2 : 3'd3)) :
        early_plru_way_8;

    // Pipeline Input Delay Registers
    reg [31:0]  address_d;
    reg [1:0]   selection_signal_d;
    reg         write_d;
    reg         read_req_d;
    reg [255:0] data_in_d;
    reg [2:0]   compress_type_in_d;
    reg [14:0]  compress_marks_in_d;
    reg [2:0]   replace_way_r;

    // Tag Output Registers
    reg [23:0] tag_out_A1, tag_out_B1, tag_out_A2, tag_out_B2;
    reg [23:0] tag_out_A3, tag_out_B3, tag_out_A4, tag_out_B4;
    reg [23:0] tag_out_A5, tag_out_B5, tag_out_A6, tag_out_B6;
    reg [23:0] tag_out_A7, tag_out_B7, tag_out_A8, tag_out_B8;

    // Metadata Pipeline Registers
    reg match1_A_r, match1_B_r, match2_A_r, match2_B_r;
    reg match3_A_r, match3_B_r, match4_A_r, match4_B_r;
    reg match5_A_r, match5_B_r, match6_A_r, match6_B_r;
    reg match7_A_r, match7_B_r, match8_A_r, match8_B_r;
    reg uncomp_out_1_r, uncomp_out_2_r, uncomp_out_3_r, uncomp_out_4_r;
    reg uncomp_out_5_r, uncomp_out_6_r, uncomp_out_7_r, uncomp_out_8_r;
    reg         hit_r;
    reg         miss_r;

    // Status Output Registers
    reg valid_out_A1, valid_out_B1, uncomp_out_1;
    reg valid_out_A2, valid_out_B2, uncomp_out_2;
    reg valid_out_A3, valid_out_B3, uncomp_out_3;
    reg valid_out_A4, valid_out_B4, uncomp_out_4;
    reg valid_out_A5, valid_out_B5, uncomp_out_5;
    reg valid_out_A6, valid_out_B6, uncomp_out_6;
    reg valid_out_A7, valid_out_B7, uncomp_out_7;
    reg valid_out_A8, valid_out_B8, uncomp_out_8;

    // Dirty Bit Output Registers
    reg dirty_out_A1, dirty_out_B1;
    reg dirty_out_A2, dirty_out_B2;
    reg dirty_out_A3, dirty_out_B3;
    reg dirty_out_A4, dirty_out_B4;
    reg dirty_out_A5, dirty_out_B5;
    reg dirty_out_A6, dirty_out_B6;
    reg dirty_out_A7, dirty_out_B7;
    reg dirty_out_A8, dirty_out_B8;
    reg is_refill_d;

    wire [5:0]  index_d = address_d[7:2];
    wire [23:0] tag_d   = address_d[31:8];

    wire we1_A, we1_B, we2_A, we2_B, we3_A, we3_B, we4_A, we4_B;
    wire we5_A, we5_B, we6_A, we6_B, we7_A, we7_B, we8_A, we8_B;
    wire [136:0] write_data_A;
    wire [136:0] write_data_B;

    always @(posedge clk) begin
        // Cycle 1: Capture inputs & early PLRU
        address_d           <= address;
        selection_signal_d  <= selection_signal;
        write_d             <= write;
        read_req_d          <= read_req;
        is_refill_d         <= is_refill;
        data_in_d           <= data_in;
        compress_type_in_d  <= compress_type_in;
        compress_marks_in_d <= compress_marks_in;
        replace_way_r       <= early_replace_way;

        // Synchronous M9K Tag Reads
        tag_out_A1 <= TAG_A_MEM1[index]; tag_out_B1 <= TAG_B_MEM1[index];
        tag_out_A2 <= TAG_A_MEM2[index]; tag_out_B2 <= TAG_B_MEM2[index];
        tag_out_A3 <= TAG_A_MEM3[index]; tag_out_B3 <= TAG_B_MEM3[index];
        tag_out_A4 <= TAG_A_MEM4[index]; tag_out_B4 <= TAG_B_MEM4[index];
        tag_out_A5 <= TAG_A_MEM5[index]; tag_out_B5 <= TAG_B_MEM5[index];
        tag_out_A6 <= TAG_A_MEM6[index]; tag_out_B6 <= TAG_B_MEM6[index];
        tag_out_A7 <= TAG_A_MEM7[index]; tag_out_B7 <= TAG_B_MEM7[index];
        tag_out_A8 <= TAG_A_MEM8[index]; tag_out_B8 <= TAG_B_MEM8[index];

        // Synchronous Status Tree Reads
        valid_out_A1 <= valid_A_tree1[index]; valid_out_B1 <= valid_B_tree1[index]; uncomp_out_1 <= uncompressed_tree1[index];
        valid_out_A2 <= valid_A_tree2[index]; valid_out_B2 <= valid_B_tree2[index]; uncomp_out_2 <= uncompressed_tree2[index];
        valid_out_A3 <= valid_A_tree3[index]; valid_out_B3 <= valid_B_tree3[index]; uncomp_out_3 <= uncompressed_tree3[index];
        valid_out_A4 <= valid_A_tree4[index]; valid_out_B4 <= valid_B_tree4[index]; uncomp_out_4 <= uncompressed_tree4[index];
        valid_out_A5 <= valid_A_tree5[index]; valid_out_B5 <= valid_B_tree5[index]; uncomp_out_5 <= uncompressed_tree5[index];
        valid_out_A6 <= valid_A_tree6[index]; valid_out_B6 <= valid_B_tree6[index]; uncomp_out_6 <= uncompressed_tree6[index];
        valid_out_A7 <= valid_A_tree7[index]; valid_out_B7 <= valid_B_tree7[index]; uncomp_out_7 <= uncompressed_tree7[index];
        valid_out_A8 <= valid_A_tree8[index]; valid_out_B8 <= valid_B_tree8[index]; uncomp_out_8 <= uncompressed_tree8[index];

        // Synchronous Dirty Tree Reads
        dirty_out_A1 <= dirty_A_tree1[index]; dirty_out_B1 <= dirty_B_tree1[index];
        dirty_out_A2 <= dirty_A_tree2[index]; dirty_out_B2 <= dirty_B_tree2[index];
        dirty_out_A3 <= dirty_A_tree3[index]; dirty_out_B3 <= dirty_B_tree3[index];
        dirty_out_A4 <= dirty_A_tree4[index]; dirty_out_B4 <= dirty_B_tree4[index];
        dirty_out_A5 <= dirty_A_tree5[index]; dirty_out_B5 <= dirty_B_tree5[index];
        dirty_out_A6 <= dirty_A_tree6[index]; dirty_out_B6 <= dirty_B_tree6[index];
        dirty_out_A7 <= dirty_A_tree7[index]; dirty_out_B7 <= dirty_B_tree7[index];
        dirty_out_A8 <= dirty_A_tree8[index]; dirty_out_B8 <= dirty_B_tree8[index];
    end

    // -------------------------------------------------------------------------
    // 3. Tag Match Evaluation & Dynamic Associativity Gating
    // -------------------------------------------------------------------------
    wire match1_A = (tag_d == tag_out_A1) & valid_out_A1;
    wire match1_B = (tag_d == tag_out_B1) & valid_out_B1 & ~uncomp_out_1;
    wire match1   = match1_A | match1_B;

    wire match2_A = (tag_d == tag_out_A2) & valid_out_A2 & (selection_signal_d >= 2'b01);
    wire match2_B = (tag_d == tag_out_B2) & valid_out_B2 & ~uncomp_out_2 & (selection_signal_d >= 2'b01);
    wire match2   = match2_A | match2_B;

    wire match3_A = (tag_d == tag_out_A3) & valid_out_A3 & (selection_signal_d >= 2'b10);
    wire match3_B = (tag_d == tag_out_B3) & valid_out_B3 & ~uncomp_out_3 & (selection_signal_d >= 2'b10);
    wire match3   = match3_A | match3_B;

    wire match4_A = (tag_d == tag_out_A4) & valid_out_A4 & (selection_signal_d >= 2'b10);
    wire match4_B = (tag_d == tag_out_B4) & valid_out_B4 & ~uncomp_out_4 & (selection_signal_d >= 2'b10);
    wire match4   = match4_A | match4_B;

    wire match5_A = (tag_d == tag_out_A5) & valid_out_A5 & (selection_signal_d == 2'b11);
    wire match5_B = (tag_d == tag_out_B5) & valid_out_B5 & ~uncomp_out_5 & (selection_signal_d == 2'b11);
    wire match5   = match5_A | match5_B;

    wire match6_A = (tag_d == tag_out_A6) & valid_out_A6 & (selection_signal_d == 2'b11);
    wire match6_B = (tag_d == tag_out_B6) & valid_out_B6 & ~uncomp_out_6 & (selection_signal_d == 2'b11);
    wire match6   = match6_A | match6_B;

    wire match7_A = (tag_d == tag_out_A7) & valid_out_A7 & (selection_signal_d == 2'b11);
    wire match7_B = (tag_d == tag_out_B7) & valid_out_B7 & ~uncomp_out_7 & (selection_signal_d == 2'b11);
    wire match7   = match7_A | match7_B;

    wire match8_A = (tag_d == tag_out_A8) & valid_out_A8 & (selection_signal_d == 2'b11);
    wire match8_B = (tag_d == tag_out_B8) & valid_out_B8 & ~uncomp_out_8 & (selection_signal_d == 2'b11);
    wire match8   = match8_A | match8_B;

    wire cache_hit  = match1 | match2 | match3 | match4 | match5 | match6 | match7 | match8;
    wire cache_miss = ~cache_hit;

    assign hit  = hit_r;
    assign miss = miss_r;

    wire [2:0] access_way = cache_hit ?
        (match1 ? 3'd0 : match2 ? 3'd1 : match3 ? 3'd2 : match4 ? 3'd3 :
         match5 ? 3'd4 : match6 ? 3'd5 : match7 ? 3'd6 : 3'd7) : replace_way_r;

    wire alloc1 = cache_miss & (replace_way_r == 3'd0);
    wire alloc2 = cache_miss & (replace_way_r == 3'd1) & (selection_signal_d >= 2'b01);
    wire alloc3 = cache_miss & (replace_way_r == 3'd2) & (selection_signal_d >= 2'b10);
    wire alloc4 = cache_miss & (replace_way_r == 3'd3) & (selection_signal_d >= 2'b10);
    wire alloc5 = cache_miss & (replace_way_r == 3'd4) & (selection_signal_d == 2'b11);
    wire alloc6 = cache_miss & (replace_way_r == 3'd5) & (selection_signal_d == 2'b11);
    wire alloc7 = cache_miss & (replace_way_r == 3'd6) & (selection_signal_d == 2'b11);
    wire alloc8 = cache_miss & (replace_way_r == 3'd7) & (selection_signal_d == 2'b11);

    // -------------------------------------------------------------------------
    // 4. Sub-Block Packing & Write Enable Generation
    // -------------------------------------------------------------------------
    wire is_uncompressed = (compress_type_in_d == 3'b000);
    wire is_compressed   = ~is_uncompressed;

    wire can_pack_B_1 = valid_out_A1 & ~uncomp_out_1 & ~valid_out_B1;
    wire can_pack_B_2 = valid_out_A2 & ~uncomp_out_2 & ~valid_out_B2;
    wire can_pack_B_3 = valid_out_A3 & ~uncomp_out_3 & ~valid_out_B3;
    wire can_pack_B_4 = valid_out_A4 & ~uncomp_out_4 & ~valid_out_B4;
    wire can_pack_B_5 = valid_out_A5 & ~uncomp_out_5 & ~valid_out_B5;
    wire can_pack_B_6 = valid_out_A6 & ~uncomp_out_6 & ~valid_out_B6;
    wire can_pack_B_7 = valid_out_A7 & ~uncomp_out_7 & ~valid_out_B7;
    wire can_pack_B_8 = valid_out_A8 & ~uncomp_out_8 & ~valid_out_B8;

    assign we1_A = (write_d & match1_A) | (write_d & match1_B & is_uncompressed) | (write_d & alloc1 & (is_uncompressed | ~can_pack_B_1));
    assign we1_B = (write_d & match1_B) | (write_d & match1_A & (is_uncompressed | uncomp_out_1)) | (write_d & alloc1 & (is_uncompressed | can_pack_B_1));
    assign we2_A = (write_d & match2_A) | (write_d & match2_B & is_uncompressed) | (write_d & alloc2 & (is_uncompressed | ~can_pack_B_2));
    assign we2_B = (write_d & match2_B) | (write_d & match2_A & (is_uncompressed | uncomp_out_2)) | (write_d & alloc2 & (is_uncompressed | can_pack_B_2));
    assign we3_A = (write_d & match3_A) | (write_d & match3_B & is_uncompressed) | (write_d & alloc3 & (is_uncompressed | ~can_pack_B_3));
    assign we3_B = (write_d & match3_B) | (write_d & match3_A & (is_uncompressed | uncomp_out_3)) | (write_d & alloc3 & (is_uncompressed | can_pack_B_3));
    assign we4_A = (write_d & match4_A) | (write_d & match4_B & is_uncompressed) | (write_d & alloc4 & (is_uncompressed | ~can_pack_B_4));
    assign we4_B = (write_d & match4_B) | (write_d & match4_A & (is_uncompressed | uncomp_out_4)) | (write_d & alloc4 & (is_uncompressed | can_pack_B_4));
    assign we5_A = (write_d & match5_A) | (write_d & match5_B & is_uncompressed) | (write_d & alloc5 & (is_uncompressed | ~can_pack_B_5));
    assign we5_B = (write_d & match5_B) | (write_d & match5_A & (is_uncompressed | uncomp_out_5)) | (write_d & alloc5 & (is_uncompressed | can_pack_B_5));
    assign we6_A = (write_d & match6_A) | (write_d & match6_B & is_uncompressed) | (write_d & alloc6 & (is_uncompressed | ~can_pack_B_6));
    assign we6_B = (write_d & match6_B) | (write_d & match6_A & (is_uncompressed | uncomp_out_6)) | (write_d & alloc6 & (is_uncompressed | can_pack_B_6));
    assign we7_A = (write_d & match7_A) | (write_d & match7_B & is_uncompressed) | (write_d & alloc7 & (is_uncompressed | ~can_pack_B_7));
    assign we7_B = (write_d & match7_B) | (write_d & match7_A & (is_uncompressed | uncomp_out_7)) | (write_d & alloc7 & (is_uncompressed | can_pack_B_7));
    assign we8_A = (write_d & match8_A) | (write_d & match8_B & is_uncompressed) | (write_d & alloc8 & (is_uncompressed | ~can_pack_B_8));
    assign we8_B = (write_d & match8_B) | (write_d & match8_A & (is_uncompressed | uncomp_out_8)) | (write_d & alloc8 & (is_uncompressed | can_pack_B_8));

    assign write_data_A = {compress_type_in_d, compress_marks_in_d, data_in_d[118:0]};
    assign write_data_B = is_uncompressed ? data_in_d[255:119] : {compress_type_in_d, compress_marks_in_d, data_in_d[118:0]};

    // -------------------------------------------------------------------------
    // 5. Victim Detection & Safe Atomic Eviction Pipeline Stage
    // -------------------------------------------------------------------------
    wire victim_dirty_A =
        (replace_way_r == 3'd0) ? (valid_out_A1 & dirty_out_A1) :
        (replace_way_r == 3'd1) ? (valid_out_A2 & dirty_out_A2) :
        (replace_way_r == 3'd2) ? (valid_out_A3 & dirty_out_A3) :
        (replace_way_r == 3'd3) ? (valid_out_A4 & dirty_out_A4) :
        (replace_way_r == 3'd4) ? (valid_out_A5 & dirty_out_A5) :
        (replace_way_r == 3'd5) ? (valid_out_A6 & dirty_out_A6) :
        (replace_way_r == 3'd6) ? (valid_out_A7 & dirty_out_A7) :
                                  (valid_out_A8 & dirty_out_A8);

    wire victim_dirty_B =
        (replace_way_r == 3'd0) ? (valid_out_B1 & dirty_out_B1) :
        (replace_way_r == 3'd1) ? (valid_out_B2 & dirty_out_B2) :
        (replace_way_r == 3'd2) ? (valid_out_B3 & dirty_out_B3) :
        (replace_way_r == 3'd3) ? (valid_out_B4 & dirty_out_B4) :
        (replace_way_r == 3'd4) ? (valid_out_B5 & dirty_out_B5) :
        (replace_way_r == 3'd5) ? (valid_out_B6 & dirty_out_B6) :
        (replace_way_r == 3'd6) ? (valid_out_B7 & dirty_out_B7) :
                                  (valid_out_B8 & dirty_out_B8);

    wire victim_is_uncompressed =
        (replace_way_r == 3'd0) ? uncomp_out_1 :
        (replace_way_r == 3'd1) ? uncomp_out_2 :
        (replace_way_r == 3'd2) ? uncomp_out_3 :
        (replace_way_r == 3'd3) ? uncomp_out_4 :
        (replace_way_r == 3'd4) ? uncomp_out_5 :
        (replace_way_r == 3'd5) ? uncomp_out_6 :
        (replace_way_r == 3'd6) ? uncomp_out_7 : uncomp_out_8;

    wire [23:0] victim_tag_A =
        (replace_way_r == 3'd0) ? tag_out_A1 :
        (replace_way_r == 3'd1) ? tag_out_A2 :
        (replace_way_r == 3'd2) ? tag_out_A3 :
        (replace_way_r == 3'd3) ? tag_out_A4 :
        (replace_way_r == 3'd4) ? tag_out_A5 :
        (replace_way_r == 3'd5) ? tag_out_A6 :
        (replace_way_r == 3'd6) ? tag_out_A7 : tag_out_A8;

    // Eviction condition: Read miss where selected replacement victim holds dirty data
    wire victim_is_dirty = victim_is_uncompressed ? (victim_dirty_A | victim_dirty_B) : victim_dirty_A;
    wire victim_evict_needed = read_req_d & cache_miss & victim_is_dirty;

    wire [136:0] victim_raw_A =
        (replace_way_r == 3'd0) ? rmem1_A_out :
        (replace_way_r == 3'd1) ? rmem2_A_out :
        (replace_way_r == 3'd2) ? rmem3_A_out :
        (replace_way_r == 3'd3) ? rmem4_A_out :
        (replace_way_r == 3'd4) ? rmem5_A_out :
        (replace_way_r == 3'd5) ? rmem6_A_out :
        (replace_way_r == 3'd6) ? rmem7_A_out : rmem8_A_out;

    wire [136:0] victim_raw_B =
        (replace_way_r == 3'd0) ? rmem1_B_out :
        (replace_way_r == 3'd1) ? rmem2_B_out :
        (replace_way_r == 3'd2) ? rmem3_B_out :
        (replace_way_r == 3'd3) ? rmem4_B_out :
        (replace_way_r == 3'd4) ? rmem5_B_out :
        (replace_way_r == 3'd5) ? rmem6_B_out :
        (replace_way_r == 3'd6) ? rmem7_B_out : rmem8_B_out;

    // Retimed Pipeline Registers for Eviction Critical Path Balancing
    reg [136:0] victim_raw_A_r;
    reg [136:0] victim_raw_B_r;
    reg         victim_is_uncompressed_r;
    reg         evict_valid_c2;
    reg [31:0]  evict_address_c2;

    reg         evict_valid_c3;
    reg [31:0]  evict_address_c3;

    always @(posedge clk) begin
        if (!reset) begin
            victim_raw_A_r           <= 137'b0;
            victim_raw_B_r           <= 137'b0;
            victim_is_uncompressed_r <= 1'b0;
            evict_valid_c2           <= 1'b0;
            evict_address_c2         <= 32'b0;
            evict_valid_c3           <= 1'b0;
            evict_address_c3         <= 32'b0;
        end else begin
            // Stage 2: Register raw multiplexed data from embedded arrays
            victim_raw_A_r           <= victim_raw_A;
            victim_raw_B_r           <= victim_raw_B;
            victim_is_uncompressed_r <= victim_is_uncompressed;
            evict_valid_c2           <= victim_evict_needed;
            evict_address_c2         <= {victim_tag_A, index_d, 2'b00};

            // Stage 3: Retimed validation alignment
            evict_valid_c3           <= evict_valid_c2;
            evict_address_c3         <= evict_address_c2;
        end
    end

    // Decompressor operating on registered victim payload (breaks combinational loop)
    wire [255:0] victim_decompressed_A;
    l2_bdi_decompressor victim_dec_A (
        .compressed_data  ({137'b0, victim_raw_A_r[118:0]}),
        .compress_type    (victim_raw_A_r[136:134]),
        .compress_marks   (victim_raw_A_r[133:119]),
        .decompressed_data(victim_decompressed_A)
    );

    wire [255:0] victim_full_data = victim_is_uncompressed_r ?
        {victim_raw_B_r[136:0], victim_raw_A_r[118:0]} : victim_decompressed_A;

    // -------------------------------------------------------------------------
    // 6. Sequential Commitment: Tags, Status, Dirty-Bits, and PLRU Updates
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!reset) begin
            valid_A_tree1 <= 64'b0; valid_B_tree1 <= 64'b0; uncompressed_tree1 <= 64'b0;
            valid_A_tree2 <= 64'b0; valid_B_tree2 <= 64'b0; uncompressed_tree2 <= 64'b0;
            valid_A_tree3 <= 64'b0; valid_B_tree3 <= 64'b0; uncompressed_tree3 <= 64'b0;
            valid_A_tree4 <= 64'b0; valid_B_tree4 <= 64'b0; uncompressed_tree4 <= 64'b0;
            valid_A_tree5 <= 64'b0; valid_B_tree5 <= 64'b0; uncompressed_tree5 <= 64'b0;
            valid_A_tree6 <= 64'b0; valid_B_tree6 <= 64'b0; uncompressed_tree6 <= 64'b0;
            valid_A_tree7 <= 64'b0; valid_B_tree7 <= 64'b0; uncompressed_tree7 <= 64'b0;
            valid_A_tree8 <= 64'b0; valid_B_tree8 <= 64'b0; uncompressed_tree8 <= 64'b0;

            dirty_A_tree1 <= 64'b0; dirty_B_tree1 <= 64'b0;
            dirty_A_tree2 <= 64'b0; dirty_B_tree2 <= 64'b0;
            dirty_A_tree3 <= 64'b0; dirty_B_tree3 <= 64'b0;
            dirty_A_tree4 <= 64'b0; dirty_B_tree4 <= 64'b0;
            dirty_A_tree5 <= 64'b0; dirty_B_tree5 <= 64'b0;
            dirty_A_tree6 <= 64'b0; dirty_B_tree6 <= 64'b0;
            dirty_A_tree7 <= 64'b0; dirty_B_tree7 <= 64'b0;
            dirty_A_tree8 <= 64'b0; dirty_B_tree8 <= 64'b0;

            evict_valid   <= 1'b0;
            evict_address <= 32'b0;
            evict_data    <= 256'b0;
        end else begin
            // Eviction acknowledge handshake
            if (evict_ack) begin
                evict_valid <= 1'b0;
            end else if (evict_valid_c3) begin
                evict_valid   <= 1'b1;
                evict_address <= evict_address_c3;
                evict_data    <= victim_full_data;
            end

            // PLRU Tree Updates upon hit or write
            if (write_d || cache_hit) begin
                case (access_way)
                    3'd0: begin plru_tree[index_d][0] <= 1'b1; plru_tree[index_d][1] <= 1'b1; plru_tree[index_d][3] <= 1'b1; end
                    3'd1: begin plru_tree[index_d][0] <= 1'b1; plru_tree[index_d][1] <= 1'b1; plru_tree[index_d][3] <= 1'b0; end
                    3'd2: begin plru_tree[index_d][0] <= 1'b1; plru_tree[index_d][1] <= 1'b0; plru_tree[index_d][4] <= 1'b1; end
                    3'd3: begin plru_tree[index_d][0] <= 1'b1; plru_tree[index_d][1] <= 1'b0; plru_tree[index_d][4] <= 1'b0; end
                    3'd4: begin plru_tree[index_d][0] <= 1'b0; plru_tree[index_d][2] <= 1'b1; plru_tree[index_d][5] <= 1'b1; end
                    3'd5: begin plru_tree[index_d][0] <= 1'b0; plru_tree[index_d][2] <= 1'b1; plru_tree[index_d][5] <= 1'b0; end
                    3'd6: begin plru_tree[index_d][0] <= 1'b0; plru_tree[index_d][2] <= 1'b0; plru_tree[index_d][6] <= 1'b1; end
                    3'd7: begin plru_tree[index_d][0] <= 1'b0; plru_tree[index_d][2] <= 1'b0; plru_tree[index_d][6] <= 1'b0; end
                endcase
            end

            // Way 1 Update
            if (we1_A) begin
                TAG_A_MEM1[index_d] <= tag_d;
                valid_A_tree1[index_d] <= 1'b1;
                uncompressed_tree1[index_d] <= is_uncompressed;
                dirty_A_tree1[index_d] <= ~is_refill_d;
            end
            if (we1_B) begin
                if ((alloc1 & is_compressed & can_pack_B_1) || (write_d & match1_B)) TAG_B_MEM1[index_d] <= tag_d;
                dirty_B_tree1[index_d] <= ~is_refill_d;
            end
            if (we1_B && ((write_d & match1_B) || (alloc1 & is_compressed & can_pack_B_1) || (is_uncompressed & write_d)))
                valid_B_tree1[index_d] <= 1'b1;
            else if ((we1_A && alloc1) || (we1_B && (is_uncompressed || (write_d & match1_A & uncomp_out_1 & is_compressed)))) begin
                valid_B_tree1[index_d] <= 1'b0;
                dirty_B_tree1[index_d] <= 1'b0;
            end

            // Way 2 Update
            if (we2_A) begin
                TAG_A_MEM2[index_d] <= tag_d;
                valid_A_tree2[index_d] <= 1'b1;
                uncompressed_tree2[index_d] <= is_uncompressed;
                dirty_A_tree2[index_d] <= ~is_refill_d;
            end
            if (we2_B) begin
                if ((alloc2 & is_compressed & can_pack_B_2) || (write_d & match2_B)) TAG_B_MEM2[index_d] <= tag_d;
                dirty_B_tree2[index_d] <= ~is_refill_d;
            end
            if (we2_B && ((write_d & match2_B) || (alloc2 & is_compressed & can_pack_B_2) || (is_uncompressed & write_d)))
                valid_B_tree2[index_d] <= 1'b1;
            else if ((we2_A && alloc2) || (we2_B && (is_uncompressed || (write_d & match2_A & uncomp_out_2 & is_compressed)))) begin
                valid_B_tree2[index_d] <= 1'b0;
                dirty_B_tree2[index_d] <= 1'b0;
            end

            // Way 3 Update
            if (we3_A) begin
                TAG_A_MEM3[index_d] <= tag_d;
                valid_A_tree3[index_d] <= 1'b1;
                uncompressed_tree3[index_d] <= is_uncompressed;
                dirty_A_tree3[index_d] <= ~is_refill_d;
            end
            if (we3_B) begin
                if ((alloc3 & is_compressed & can_pack_B_3) || (write_d & match3_B)) TAG_B_MEM3[index_d] <= tag_d;
                dirty_B_tree3[index_d] <= ~is_refill_d;
            end
            if (we3_B && ((write_d & match3_B) || (alloc3 & is_compressed & can_pack_B_3) || (is_uncompressed & write_d)))
                valid_B_tree3[index_d] <= 1'b1;
            else if ((we3_A && alloc3) || (we3_B && (is_uncompressed || (write_d & match3_A & uncomp_out_3 & is_compressed)))) begin
                valid_B_tree3[index_d] <= 1'b0;
                dirty_B_tree3[index_d] <= 1'b0;
            end

            // Way 4 Update
            if (we4_A) begin
                TAG_A_MEM4[index_d] <= tag_d;
                valid_A_tree4[index_d] <= 1'b1;
                uncompressed_tree4[index_d] <= is_uncompressed;
                dirty_A_tree4[index_d] <= ~is_refill_d;
            end
            if (we4_B) begin
                if ((alloc4 & is_compressed & can_pack_B_4) || (write_d & match4_B)) TAG_B_MEM4[index_d] <= tag_d;
                dirty_B_tree4[index_d] <= ~is_refill_d;
            end
            if (we4_B && ((write_d & match4_B) || (alloc4 & is_compressed & can_pack_B_4) || (is_uncompressed & write_d)))
                valid_B_tree4[index_d] <= 1'b1;
            else if ((we4_A && alloc4) || (we4_B && (is_uncompressed || (write_d & match4_A & uncomp_out_4 & is_compressed)))) begin
                valid_B_tree4[index_d] <= 1'b0;
                dirty_B_tree4[index_d] <= 1'b0;
            end

            // Way 5 Update
            if (we5_A) begin
                TAG_A_MEM5[index_d] <= tag_d;
                valid_A_tree5[index_d] <= 1'b1;
                uncompressed_tree5[index_d] <= is_uncompressed;
                dirty_A_tree5[index_d] <= ~is_refill_d;
            end
            if (we5_B) begin
                if ((alloc5 & is_compressed & can_pack_B_5) || (write_d & match5_B)) TAG_B_MEM5[index_d] <= tag_d;
                dirty_B_tree5[index_d] <= ~is_refill_d;
            end
            if (we5_B && ((write_d & match5_B) || (alloc5 & is_compressed & can_pack_B_5) || (is_uncompressed & write_d)))
                valid_B_tree5[index_d] <= 1'b1;
            else if ((we5_A && alloc5) || (we5_B && (is_uncompressed || (write_d & match5_A & uncomp_out_5 & is_compressed)))) begin
                valid_B_tree5[index_d] <= 1'b0;
                dirty_B_tree5[index_d] <= 1'b0;
            end

            // Way 6 Update
            if (we6_A) begin
                TAG_A_MEM6[index_d] <= tag_d;
                valid_A_tree6[index_d] <= 1'b1;
                uncompressed_tree6[index_d] <= is_uncompressed;
                dirty_A_tree6[index_d] <= ~is_refill_d;
            end
            if (we6_B) begin
                if ((alloc6 & is_compressed & can_pack_B_6) || (write_d & match6_B)) TAG_B_MEM6[index_d] <= tag_d;
                dirty_B_tree6[index_d] <= ~is_refill_d;
            end
            if (we6_B && ((write_d & match6_B) || (alloc6 & is_compressed & can_pack_B_6) || (is_uncompressed & write_d)))
                valid_B_tree6[index_d] <= 1'b1;
            else if ((we6_A && alloc6) || (we6_B && (is_uncompressed || (write_d & match6_A & uncomp_out_6 & is_compressed)))) begin
                valid_B_tree6[index_d] <= 1'b0;
                dirty_B_tree6[index_d] <= 1'b0;
            end

            // Way 7 Update
            if (we7_A) begin
                TAG_A_MEM7[index_d] <= tag_d;
                valid_A_tree7[index_d] <= 1'b1;
                uncompressed_tree7[index_d] <= is_uncompressed;
                dirty_A_tree7[index_d] <= ~is_refill_d;
            end
            if (we7_B) begin
                if ((alloc7 & is_compressed & can_pack_B_7) || (write_d & match7_B)) TAG_B_MEM7[index_d] <= tag_d;
                dirty_B_tree7[index_d] <= ~is_refill_d;
            end
            if (we7_B && ((write_d & match7_B) || (alloc7 & is_compressed & can_pack_B_7) || (is_uncompressed & write_d)))
                valid_B_tree7[index_d] <= 1'b1;
            else if ((we7_A && alloc7) || (we7_B && (is_uncompressed || (write_d & match7_A & uncomp_out_7 & is_compressed)))) begin
                valid_B_tree7[index_d] <= 1'b0;
                dirty_B_tree7[index_d] <= 1'b0;
            end

            // Way 8 Update
            if (we8_A) begin
                TAG_A_MEM8[index_d] <= tag_d;
                valid_A_tree8[index_d] <= 1'b1;
                uncompressed_tree8[index_d] <= is_uncompressed;
                dirty_A_tree8[index_d] <= ~is_refill_d;
            end
            if (we8_B) begin
                if ((alloc8 & is_compressed & can_pack_B_8) || (write_d & match8_B)) TAG_B_MEM8[index_d] <= tag_d;
                dirty_B_tree8[index_d] <= ~is_refill_d;
            end
            if (we8_B && ((write_d & match8_B) || (alloc8 & is_compressed & can_pack_B_8) || (is_uncompressed & write_d)))
                valid_B_tree8[index_d] <= 1'b1;
            else if ((we8_A && alloc8) || (we8_B && (is_uncompressed || (write_d & match8_A & uncomp_out_8 & is_compressed)))) begin
                valid_B_tree8[index_d] <= 1'b0;
                dirty_B_tree8[index_d] <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // 7. Way-Halted Data Read & Embedded RAM Block Instantiations
    // -------------------------------------------------------------------------
    wire rden_victim_1 = victim_evict_needed & (replace_way_r == 3'd0);
    wire rden_victim_2 = victim_evict_needed & (replace_way_r == 3'd1);
    wire rden_victim_3 = victim_evict_needed & (replace_way_r == 3'd2);
    wire rden_victim_4 = victim_evict_needed & (replace_way_r == 3'd3);
    wire rden_victim_5 = victim_evict_needed & (replace_way_r == 3'd4);
    wire rden_victim_6 = victim_evict_needed & (replace_way_r == 3'd5);
    wire rden_victim_7 = victim_evict_needed & (replace_way_r == 3'd6);
    wire rden_victim_8 = victim_evict_needed & (replace_way_r == 3'd7);

    wire read_lookup = ~write_d & cache_hit;
    wire read1_A = (read_lookup & match1_A) | rden_victim_1;
    wire read1_B = (read_lookup & (match1_B | (match1_A & uncomp_out_1))) | rden_victim_1;
    wire read2_A = (read_lookup & match2_A) | rden_victim_2;
    wire read2_B = (read_lookup & (match2_B | (match2_A & uncomp_out_2))) | rden_victim_2;
    wire read3_A = (read_lookup & match3_A) | rden_victim_3;
    wire read3_B = (read_lookup & (match3_B | (match3_A & uncomp_out_3))) | rden_victim_3;
    wire read4_A = (read_lookup & match4_A) | rden_victim_4;
    wire read4_B = (read_lookup & (match4_B | (match4_A & uncomp_out_4))) | rden_victim_4;
    wire read5_A = (read_lookup & match5_A) | rden_victim_5;
    wire read5_B = (read_lookup & (match5_B | (match5_A & uncomp_out_5))) | rden_victim_5;
    wire read6_A = (read_lookup & match6_A) | rden_victim_6;
    wire read6_B = (read_lookup & (match6_B | (match6_A & uncomp_out_6))) | rden_victim_6;
    wire read7_A = (read_lookup & match7_A) | rden_victim_7;
    wire read7_B = (read_lookup & (match7_B | (match7_A & uncomp_out_7))) | rden_victim_7;
    wire read8_A = (read_lookup & match8_A) | rden_victim_8;
    wire read8_B = (read_lookup & (match8_B | (match8_A & uncomp_out_8))) | rden_victim_8;

    l2_ram_block data_A1 (.clk(clk), .rden(read1_A), .raddr(index_d), .wren(we1_A), .waddr(index_d), .din(write_data_A), .dout(rmem1_A_out));
    l2_ram_block data_B1 (.clk(clk), .rden(read1_B), .raddr(index_d), .wren(we1_B), .waddr(index_d), .din(write_data_B), .dout(rmem1_B_out));
    l2_ram_block data_A2 (.clk(clk), .rden(read2_A), .raddr(index_d), .wren(we2_A), .waddr(index_d), .din(write_data_A), .dout(rmem2_A_out));
    l2_ram_block data_B2 (.clk(clk), .rden(read2_B), .raddr(index_d), .wren(we2_B), .waddr(index_d), .din(write_data_B), .dout(rmem2_B_out));
    l2_ram_block data_A3 (.clk(clk), .rden(read3_A), .raddr(index_d), .wren(we3_A), .waddr(index_d), .din(write_data_A), .dout(rmem3_A_out));
    l2_ram_block data_B3 (.clk(clk), .rden(read3_B), .raddr(index_d), .wren(we3_B), .waddr(index_d), .din(write_data_B), .dout(rmem3_B_out));
    l2_ram_block data_A4 (.clk(clk), .rden(read4_A), .raddr(index_d), .wren(we4_A), .waddr(index_d), .din(write_data_A), .dout(rmem4_A_out));
    l2_ram_block data_B4 (.clk(clk), .rden(read4_B), .raddr(index_d), .wren(we4_B), .waddr(index_d), .din(write_data_B), .dout(rmem4_B_out));
    l2_ram_block data_A5 (.clk(clk), .rden(read5_A), .raddr(index_d), .wren(we5_A), .waddr(index_d), .din(write_data_A), .dout(rmem5_A_out));
    l2_ram_block data_B5 (.clk(clk), .rden(read5_B), .raddr(index_d), .wren(we5_B), .waddr(index_d), .din(write_data_B), .dout(rmem5_B_out));
    l2_ram_block data_A6 (.clk(clk), .rden(read6_A), .raddr(index_d), .wren(we6_A), .waddr(index_d), .din(write_data_A), .dout(rmem6_A_out));
    l2_ram_block data_B6 (.clk(clk), .rden(read6_B), .raddr(index_d), .wren(we6_B), .waddr(index_d), .din(write_data_B), .dout(rmem6_B_out));
    l2_ram_block data_A7 (.clk(clk), .rden(read7_A), .raddr(index_d), .wren(we7_A), .waddr(index_d), .din(write_data_A), .dout(rmem7_A_out));
    l2_ram_block data_B7 (.clk(clk), .rden(read7_B), .raddr(index_d), .wren(we7_B), .waddr(index_d), .din(write_data_B), .dout(rmem7_B_out));
    l2_ram_block data_A8 (.clk(clk), .rden(read8_A), .raddr(index_d), .wren(we8_A), .waddr(index_d), .din(write_data_A), .dout(rmem8_A_out));
    l2_ram_block data_B8 (.clk(clk), .rden(read8_B), .raddr(index_d), .wren(we8_B), .waddr(index_d), .din(write_data_B), .dout(rmem8_B_out));

    always @(posedge clk) begin
        if (!reset) begin
            match1_A_r <= 1'b0; match1_B_r <= 1'b0; match2_A_r <= 1'b0; match2_B_r <= 1'b0;
            match3_A_r <= 1'b0; match3_B_r <= 1'b0; match4_A_r <= 1'b0; match4_B_r <= 1'b0;
            match5_A_r <= 1'b0; match5_B_r <= 1'b0; match6_A_r <= 1'b0; match6_B_r <= 1'b0;
            match7_A_r <= 1'b0; match7_B_r <= 1'b0; match8_A_r <= 1'b0; match8_B_r <= 1'b0;
            uncomp_out_1_r <= 1'b0; uncomp_out_2_r <= 1'b0; uncomp_out_3_r <= 1'b0; uncomp_out_4_r <= 1'b0;
            uncomp_out_5_r <= 1'b0; uncomp_out_6_r <= 1'b0; uncomp_out_7_r <= 1'b0; uncomp_out_8_r <= 1'b0;
            hit_r  <= 1'b0;
            miss_r <= 1'b0;
        end else begin
            hit_r  <= cache_hit;
            miss_r <= cache_miss;

            match1_A_r <= read_lookup & match1_A; match1_B_r <= read_lookup & match1_B;
            match2_A_r <= read_lookup & match2_A; match2_B_r <= read_lookup & match2_B;
            match3_A_r <= read_lookup & match3_A; match3_B_r <= read_lookup & match3_B;
            match4_A_r <= read_lookup & match4_A; match4_B_r <= read_lookup & match4_B;
            match5_A_r <= read_lookup & match5_A; match5_B_r <= read_lookup & match5_B;
            match6_A_r <= read_lookup & match6_A; match6_B_r <= read_lookup & match6_B;
            match7_A_r <= read_lookup & match7_A; match7_B_r <= read_lookup & match7_B;
            match8_A_r <= read_lookup & match8_A; match8_B_r <= read_lookup & match8_B;

            uncomp_out_1_r <= uncomp_out_1; uncomp_out_2_r <= uncomp_out_2; uncomp_out_3_r <= uncomp_out_3; uncomp_out_4_r <= uncomp_out_4;
            uncomp_out_5_r <= uncomp_out_5; uncomp_out_6_r <= uncomp_out_6; uncomp_out_7_r <= uncomp_out_7; uncomp_out_8_r <= uncomp_out_8;
        end
    end

    // -------------------------------------------------------------------------
    // 8. Read Hit Multiplexer
    // -------------------------------------------------------------------------
    wire [136:0] selected_A_data =
        match1_A_r ? rmem1_A_out : match2_A_r ? rmem2_A_out :
        match3_A_r ? rmem3_A_out : match4_A_r ? rmem4_A_out :
        match5_A_r ? rmem5_A_out : match6_A_r ? rmem6_A_out :
        match7_A_r ? rmem7_A_out : match8_A_r ? rmem8_A_out : 137'b0;

    wire [136:0] raw_B_mux =
        (match1_B_r | (match1_A_r & uncomp_out_1_r)) ? rmem1_B_out :
        (match2_B_r | (match2_A_r & uncomp_out_2_r)) ? rmem2_B_out :
        (match3_B_r | (match3_A_r & uncomp_out_3_r)) ? rmem3_B_out :
        (match4_B_r | (match4_A_r & uncomp_out_4_r)) ? rmem4_B_out :
        (match5_B_r | (match5_A_r & uncomp_out_5_r)) ? rmem5_B_out :
        (match6_B_r | (match6_A_r & uncomp_out_6_r)) ? rmem6_B_out :
        (match7_B_r | (match7_A_r & uncomp_out_7_r)) ? rmem7_B_out :
        (match8_B_r | (match8_A_r & uncomp_out_8_r)) ? rmem8_B_out : 137'b0;

    wire hit_uncompressed_r = (match1_A_r & uncomp_out_1_r) | (match2_A_r & uncomp_out_2_r) |
                              (match3_A_r & uncomp_out_3_r) | (match4_A_r & uncomp_out_4_r) |
                              (match5_A_r & uncomp_out_5_r) | (match6_A_r & uncomp_out_6_r) |
                              (match7_A_r & uncomp_out_7_r) | (match8_A_r & uncomp_out_8_r);

    wire hit_compressed_A_r = (match1_A_r & ~uncomp_out_1_r) | (match2_A_r & ~uncomp_out_2_r) |
                              (match3_A_r & ~uncomp_out_3_r) | (match4_A_r & ~uncomp_out_4_r) |
                              (match5_A_r & ~uncomp_out_5_r) | (match6_A_r & ~uncomp_out_6_r) |
                              (match7_A_r & ~uncomp_out_7_r) | (match8_A_r & ~uncomp_out_8_r);

    wire hit_compressed_B_r = match1_B_r | match2_B_r | match3_B_r | match4_B_r |
                              match5_B_r | match6_B_r | match7_B_r | match8_B_r;

    assign compress_type_out  = (hit_uncompressed_r | hit_compressed_A_r) ? selected_A_data[136:134] :
                                hit_compressed_B_r ? raw_B_mux[136:134] : 3'b0;

    assign compress_marks_out = (hit_uncompressed_r | hit_compressed_A_r) ? selected_A_data[133:119] :
                                hit_compressed_B_r ? raw_B_mux[133:119] : 15'b0;

    assign out                = hit_uncompressed_r ? {raw_B_mux[136:0], selected_A_data[118:0]} :
                                hit_compressed_A_r ? {137'b0, selected_A_data[118:0]} :
                                hit_compressed_B_r ? {137'b0, raw_B_mux[118:0]} : 256'b0;

endmodule


