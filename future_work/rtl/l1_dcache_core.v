`timescale 1ns / 1ps
// =============================================================================
// Module Name: l1_dcache_core
// Project:     High-Performance BDI Compressed L2 Cache IP for SoC
// Author:      Mohammed Gweaa
// Standard:    IEEE 1364-2001 (Verilog HDL)
//
// Description:
//   Ultra-Fast Level-1 Data Cache (L1-D) Core.
//   Directly interfaces with the CPU Load-Store Unit (LSU) via Wishbone B4.
//   Connects to L2 Cache via a 256-bit cache-line burst interface.
//
// Architectural Characteristics:
//   - Physical Capacity: 4 KB (64 sets x 2 ways x 32 bytes / 256 bits).
//   - Hit Latency: 1 Clock Cycle (Pure single-cycle synchronous SRAM).
//   - Granularity: 32-bit words with 4-bit byte enables (wb_sel_i).
//   - Write Policy: Write-Back with Write-Allocate.
//   - Eviction: Pushes full 256-bit dirty lines to L2 in background.
// =============================================================================

module l1_dcache_core (
    input  wire        clk,
    input  wire        reset,

    // ── CPU Bus Interface (Wishbone B4 Slave from RISC-V LSU) ────────────
    input  wire [31:0] cpu_adr_i,
    input  wire [31:0] cpu_dat_i,
    input  wire [3:0]  cpu_sel_i,
    input  wire        cpu_we_i,
    input  wire        cpu_cyc_i,
    input  wire        cpu_stb_i,
    output reg  [31:0] cpu_dat_o,
    output reg         cpu_ack_o,
    output wire        cpu_stall_o,

    // ── L2 Cache Interface (Master Port to L1-to-L2 Arbiter) ─────────────
    output reg         l2_req_valid,
    output reg  [31:0] l2_req_addr,
    output reg         l2_req_write,
    output reg  [255:0] l2_req_wdata,
    input  wire [255:0] l2_resp_rdata,
    input  wire        l2_resp_valid,
    input  wire        l2_ready,

    // ── Diagnostics ──────────────────────────────────────────────────────
    output reg  [31:0] dbg_l1_hits,
    output reg  [31:0] dbg_l1_misses
);

    wire cpu_transfer_req = cpu_cyc_i && cpu_stb_i;

    // Address partitioning: [31:11] Tag (21 bits), [10:5] Index (6 bits -> 64 sets), [4:2] Word (3 bits), [1:0] Byte
    wire [5:0]  set_idx = cpu_adr_i[10:5];
    wire [20:0] tag_in  = cpu_adr_i[31:11];
    wire [2:0]  word_idx= cpu_adr_i[4:2];

    // L1 Storage Arrays (64 sets x 2 ways)
    reg [255:0] data_w0 [0:63];
    reg [255:0] data_w1 [0:63];
    reg [20:0]  tag_w0  [0:63];
    reg [20:0]  tag_w1  [0:63];
    reg [63:0]  valid_w0;
    reg [63:0]  valid_w1;
    reg [63:0]  dirty_w0;
    reg [63:0]  dirty_w1;
    reg [63:0]  lru_bit; // 0 = Way 0 is LRU, 1 = Way 1 is LRU

    integer init_idx;
    initial begin
        valid_w0 = 64'd0; valid_w1 = 64'd0;
        dirty_w0 = 64'd0; dirty_w1 = 64'd0;
        lru_bit  = 64'd0;
        for (init_idx = 0; init_idx < 64; init_idx = init_idx + 1) begin
            data_w0[init_idx] = 256'd0; data_w1[init_idx] = 256'd0;
            tag_w0[init_idx]  = 21'd0;  tag_w1[init_idx]  = 21'd0;
        end
    end

    // Word Extraction and Byte Merge Functions
    function [31:0] extract_word;
        input [255:0] line;
        input [2:0]   idx;
        begin
            case (idx)
                3'd0: extract_word = line[31:0];
                3'd1: extract_word = line[63:32];
                3'd2: extract_word = line[95:64];
                3'd3: extract_word = line[127:96];
                3'd4: extract_word = line[159:128];
                3'd5: extract_word = line[191:160];
                3'd6: extract_word = line[223:192];
                3'd7: extract_word = line[255:224];
            endcase
        end
    endfunction

    function [255:0] merge_word;
        input [255:0] line;
        input [31:0]  wdata;
        input [3:0]   sel;
        input [2:0]   idx;
        reg   [31:0]  orig_w;
        reg   [31:0]  new_w;
        begin
            orig_w = extract_word(line, idx);
            new_w[7:0]   = sel[0] ? wdata[7:0]   : orig_w[7:0];
            new_w[15:8]  = sel[1] ? wdata[15:8]  : orig_w[15:8];
            new_w[23:16] = sel[2] ? wdata[23:16] : orig_w[23:16];
            new_w[31:24] = sel[3] ? wdata[31:24] : orig_w[31:24];

            merge_word = line;
            case (idx)
                3'd0: merge_word[31:0]   = new_w;
                3'd1: merge_word[63:32]  = new_w;
                3'd2: merge_word[95:64]  = new_w;
                3'd3: merge_word[127:96] = new_w;
                3'd4: merge_word[159:128]= new_w;
                3'd5: merge_word[191:160]= new_w;
                3'd6: merge_word[223:192]= new_w;
                3'd7: merge_word[255:224]= new_w;
            endcase
        end
    endfunction

    // Hit Detection
    wire hit_w0 = valid_w0[set_idx] && (tag_w0[set_idx] == tag_in);
    wire hit_w1 = valid_w1[set_idx] && (tag_w1[set_idx] == tag_in);
    wire l1_hit = hit_w0 || hit_w1;

    // FSM States
    localparam S_IDLE        = 3'd0;
    localparam S_EVICT_REQ   = 3'd1;
    localparam S_EVICT_WAIT  = 3'd2;
    localparam S_REFILL_REQ  = 3'd3;
    localparam S_REFILL_WAIT = 3'd4;
    localparam S_ACK_CPU     = 3'd5;

    reg [2:0]   state;
    reg [31:0]  latched_adr;
    reg [31:0]  latched_dat;
    reg [3:0]   latched_sel;
    reg         latched_we;
    reg [20:0]  latched_victim_tag;
    reg [255:0] latched_victim_data;
    reg         latched_repl_way;

    wire repl_way = lru_bit[set_idx]; // 0 -> replace way 0, 1 -> replace way 1
    wire victim_dirty = repl_way ? (valid_w1[set_idx] && dirty_w1[set_idx]) :
                                   (valid_w0[set_idx] && dirty_w0[set_idx]);
    wire [20:0] victim_tag = repl_way ? tag_w1[set_idx] : tag_w0[set_idx];
    wire [255:0] victim_data = repl_way ? data_w1[set_idx] : data_w0[set_idx];

    assign cpu_stall_o = (state != S_IDLE);

    always @(posedge clk) begin
        if (!reset) begin
            state               <= S_IDLE;
            cpu_ack_o           <= 1'b0;
            cpu_dat_o           <= 32'd0;
            l2_req_valid        <= 1'b0;
            l2_req_addr         <= 32'd0;
            l2_req_write        <= 1'b0;
            l2_req_wdata        <= 256'd0;
            latched_adr         <= 32'd0;
            latched_dat         <= 32'd0;
            latched_sel         <= 4'd0;
            latched_we          <= 1'b0;
            latched_victim_tag  <= 21'd0;
            latched_victim_data <= 256'd0;
            latched_repl_way    <= 1'b0;
            dbg_l1_hits         <= 32'd0;
            dbg_l1_misses       <= 32'd0;
        end else begin
            cpu_ack_o <= 1'b0;

            case (state)
                S_IDLE: begin
                    l2_req_valid <= 1'b0;
                    if (cpu_transfer_req) begin
                        latched_adr <= cpu_adr_i;
                        latched_dat <= cpu_dat_i;
                        latched_sel <= cpu_sel_i;
                        latched_we  <= cpu_we_i;

                        if (l1_hit) begin
                            // ── FAST 1-CYCLE L1 HIT!
                            dbg_l1_hits <= dbg_l1_hits + 1'b1;
                            cpu_ack_o   <= 1'b1;

                            if (!cpu_we_i) begin
                                // Read Hit: return 32-bit word in 1 cycle
                                cpu_dat_o <= extract_word(hit_w0 ? data_w0[set_idx] : data_w1[set_idx], word_idx);
                            end else begin
                                // Write Hit: update word with byte enables in 1 cycle, set dirty
                                if (hit_w0) begin
                                    data_w0[set_idx]  <= merge_word(data_w0[set_idx], cpu_dat_i, cpu_sel_i, word_idx);
                                    dirty_w0[set_idx] <= 1'b1;
                                end else begin
                                    data_w1[set_idx]  <= merge_word(data_w1[set_idx], cpu_dat_i, cpu_sel_i, word_idx);
                                    dirty_w1[set_idx] <= 1'b1;
                                end
                            end

                            // Update LRU
                            lru_bit[set_idx] <= hit_w0 ? 1'b1 : 1'b0;

                        end else begin
                            // ── L1 MISS: Must service from L2
                            dbg_l1_misses    <= dbg_l1_misses + 1'b1;
                            latched_repl_way <= repl_way;

                            if (victim_dirty) begin
                                // Evict dirty line to L2 first (Write-Back)
                                latched_victim_tag  <= victim_tag;
                                latched_victim_data <= victim_data;
                                l2_req_valid        <= 1'b1;
                                l2_req_addr         <= {victim_tag, set_idx, 5'b00000};
                                l2_req_write        <= 1'b1;
                                l2_req_wdata        <= victim_data;
                                state               <= S_EVICT_REQ;
                            end else begin
                                // Clean miss: Request line refill from L2 directly
                                l2_req_valid <= 1'b1;
                                l2_req_addr  <= {cpu_adr_i[31:5], 5'b00000};
                                l2_req_write <= 1'b0;
                                state        <= S_REFILL_REQ;
                            end
                        end
                    end
                end

                S_EVICT_REQ: begin
                    l2_req_valid <= 1'b1;
                    l2_req_write <= 1'b1;
                    l2_req_addr  <= {latched_victim_tag, latched_adr[10:5], 5'b00000};
                    l2_req_wdata <= latched_victim_data;

                    if (l2_ready) begin
                        // L2 accepted dirty eviction request
                        l2_req_valid <= 1'b0;
                        state        <= S_EVICT_WAIT;
                    end
                end

                S_EVICT_WAIT: begin
                    l2_req_valid <= 1'b0;
                    if (l2_ready) begin
                        // L2 write commit is complete, issue line refill
                        l2_req_valid <= 1'b1;
                        l2_req_addr  <= {latched_adr[31:5], 5'b00000};
                        l2_req_write <= 1'b0;
                        state        <= S_REFILL_REQ;
                    end
                end

                S_REFILL_REQ: begin
                    l2_req_valid <= 1'b1;
                    l2_req_addr  <= {latched_adr[31:5], 5'b00000};
                    l2_req_write <= 1'b0;

                    if (l2_ready) begin
                        // L2 accepted refill request
                        l2_req_valid <= 1'b0;
                        state        <= S_REFILL_WAIT;
                    end
                end

                S_REFILL_WAIT: begin
                    l2_req_valid <= 1'b0;

                    if (l2_resp_valid) begin
                        // 256-bit line arrived from L2!
                        if (!latched_we) begin
                            // Read Miss Refill
                            if (latched_repl_way == 1'b0) begin
                                data_w0[latched_adr[10:5]]  <= l2_resp_rdata;
                                tag_w0[latched_adr[10:5]]   <= latched_adr[31:11];
                                valid_w0[latched_adr[10:5]] <= 1'b1;
                                dirty_w0[latched_adr[10:5]] <= 1'b0;
                            end else begin
                                data_w1[latched_adr[10:5]]  <= l2_resp_rdata;
                                tag_w1[latched_adr[10:5]]   <= latched_adr[31:11];
                                valid_w1[latched_adr[10:5]] <= 1'b1;
                                dirty_w1[latched_adr[10:5]] <= 1'b0;
                            end
                            cpu_dat_o <= extract_word(l2_resp_rdata, latched_adr[4:2]);
                        end else begin
                            // Write Miss Refill (Write-Allocate)
                            if (latched_repl_way == 1'b0) begin
                                data_w0[latched_adr[10:5]]  <= merge_word(l2_resp_rdata, latched_dat, latched_sel, latched_adr[4:2]);
                                tag_w0[latched_adr[10:5]]   <= latched_adr[31:11];
                                valid_w0[latched_adr[10:5]] <= 1'b1;
                                dirty_w0[latched_adr[10:5]] <= 1'b1; // Marked dirty
                            end else begin
                                data_w1[latched_adr[10:5]]  <= merge_word(l2_resp_rdata, latched_dat, latched_sel, latched_adr[4:2]);
                                tag_w1[latched_adr[10:5]]   <= latched_adr[31:11];
                                valid_w1[latched_adr[10:5]] <= 1'b1;
                                dirty_w1[latched_adr[10:5]] <= 1'b1; // Marked dirty
                            end
                        end

                        lru_bit[latched_adr[10:5]] <= ~latched_repl_way;
                        cpu_ack_o <= 1'b1;
                        state     <= S_ACK_CPU;
                    end
                end

                S_ACK_CPU: begin
                    cpu_ack_o <= 1'b1;
                    if (!cpu_stb_i) begin
                        cpu_ack_o <= 1'b0;
                        state     <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
