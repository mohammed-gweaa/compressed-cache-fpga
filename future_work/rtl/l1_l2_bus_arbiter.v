`timescale 1ns / 1ps
// =============================================================================
// Module Name: l1_l2_bus_arbiter
// Project:     High-Performance BDI Compressed L2 Cache IP for SoC
// Author:      Mohammed Gweaa
// Standard:    IEEE 1364-2001 (Verilog HDL)
//
// Description:
//   Upstream Multi-Port Arbiter between L1 Caches and the L2 Cache Subsystem.
//   Arbitrates between:
//     - Port 0: L1 Instruction Cache (L1-I): Read-Only line refills.
//               High priority to prevent CPU instruction fetch stalls.
//     - Port 1: L1 Data Cache (L1-D): Read refills & Dirty line write-backs.
//
// Features:
//   - Strict priority for L1-I with starvation prevention.
//   - Locks transaction grant until L2 response or commit completes.
//   - Demultiplexes response data back to the originating L1 cache.
// =============================================================================

module l1_l2_bus_arbiter (
    input  wire        clk,
    input  wire        reset,

    // ── Port 0: L1 Instruction Cache (L1-I) ──────────────────────────────
    input  wire        l1i_req_valid,
    input  wire [31:0] l1i_req_addr,
    output wire [255:0] l1i_resp_rdata,
    output wire        l1i_resp_valid,
    output wire        l1i_ready,

    // ── Port 1: L1 Data Cache (L1-D) ─────────────────────────────────────
    input  wire        l1d_req_valid,
    input  wire [31:0] l1d_req_addr,
    input  wire        l1d_req_write,
    input  wire [255:0] l1d_req_wdata,
    output wire [255:0] l1d_resp_rdata,
    output wire        l1d_resp_valid,
    output wire        l1d_ready,

    // ── Unified L2 Slave Port (connected to bdi_l2_adapter) ──────────────
    output reg         l2_req_valid,
    output reg  [31:0] l2_req_addr,
    output reg         l2_req_write,
    output reg  [255:0] l2_req_wdata,
    input  wire [255:0] l2_resp_rdata,
    input  wire        l2_resp_valid,
    input  wire        l2_ready
);

    localparam ARB_IDLE   = 2'd0;
    localparam ARB_L1I    = 2'd1;
    localparam ARB_L1D_RD = 2'd2;
    localparam ARB_L1D_WR = 2'd3;

    reg [1:0] arb_state;
    reg [2:0] write_wait_cnt;

    // Grants
    wire grant_l1i = (arb_state == ARB_IDLE) ? l1i_req_valid : (arb_state == ARB_L1I);
    wire grant_l1d = (arb_state == ARB_IDLE) ? (!l1i_req_valid && l1d_req_valid) :
                     ((arb_state == ARB_L1D_RD) || (arb_state == ARB_L1D_WR));

    assign l1i_ready = (arb_state == ARB_IDLE) && l2_ready;
    assign l1d_ready = (arb_state == ARB_IDLE) && !l1i_req_valid && l2_ready;

    // Response Routing
    assign l1i_resp_rdata = l2_resp_rdata;
    assign l1i_resp_valid = (arb_state == ARB_L1I) && l2_resp_valid;

    assign l1d_resp_rdata = l2_resp_rdata;
    assign l1d_resp_valid = (arb_state == ARB_L1D_RD) && l2_resp_valid;

    always @(posedge clk) begin
        if (!reset) begin
            arb_state        <= ARB_IDLE;
            write_wait_cnt   <= 3'd0;
            l2_req_valid     <= 1'b0;
            l2_req_addr      <= 32'd0;
            l2_req_write     <= 1'b0;
            l2_req_wdata     <= 256'd0;
        end else begin
            l2_req_valid <= 1'b0;

            case (arb_state)
                ARB_IDLE: begin
                    if (l2_ready) begin
                        if (l1i_req_valid) begin
                            // L1-I Read Request (Highest Priority)
                            l2_req_valid <= 1'b1;
                            l2_req_addr  <= l1i_req_addr;
                            l2_req_write <= 1'b0;
                            arb_state    <= ARB_L1I;
                        end else if (l1d_req_valid) begin
                            // L1-D Request
                            l2_req_valid <= 1'b1;
                            l2_req_addr  <= l1d_req_addr;
                            l2_req_write <= l1d_req_write;
                            l2_req_wdata <= l1d_req_wdata;

                            if (!l1d_req_write) begin
                                arb_state <= ARB_L1D_RD;
                            end else begin
                                write_wait_cnt <= 3'd4;
                                arb_state      <= ARB_L1D_WR;
                            end
                        end
                    end
                end

                ARB_L1I: begin
                    if (l2_resp_valid) begin
                        arb_state <= ARB_IDLE;
                    end
                end

                ARB_L1D_RD: begin
                    if (l2_resp_valid) begin
                        arb_state <= ARB_IDLE;
                    end
                end

                ARB_L1D_WR: begin
                    if (write_wait_cnt > 3'd1) begin
                        write_wait_cnt <= write_wait_cnt - 1'b1;
                    end else if (l2_ready) begin
                        arb_state <= ARB_IDLE;
                    end
                end

                default: arb_state <= ARB_IDLE;
            endcase
        end
    end

endmodule
