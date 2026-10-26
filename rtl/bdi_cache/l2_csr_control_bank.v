`timescale 1ns / 1ps
// =============================================================================
// Module Name: l2_csr_control_bank
// Project:     High-Performance BDI Compressed L2 Cache Subsystem for SoC
// Author:      Mohammed Gweaa
// Standard:    IEEE 1364-2001 (Verilog HDL)
//
// Description:
//   Control and Status Register (CSR) Bank for OS-Directed L2 Cache Governance.
//   Provides a 32-bit memory-mapped register interface allowing operating
//   systems, hypervisors, AI runtimes, or firmware to dynamically configure
//   L2 cache parameters, throttle associativity, toggle hardware prefetching,
//   enable non-blocking MSHR Hit-Under-Miss mode, and monitor telemetry.
//
// Register Map:
//   0xFFFF_0000 : CACHE_CFG_REG   [1:0] R/W  Associativity mode (00=1W, 01=2W, 10=4W, 11=8W)
//                                 [2]   R/W  Hardware Data Prefetcher Enable (1=En, 0=Dis)
//                                 [3]   R/W  Non-Blocking MSHR Hit-Under-Miss Enable (1=En, 0=Dis)
//                                 [4]   R/W  Workload Profile Mode (0=General, 1=AI/Streaming)
//   0xFFFF_0004 : CACHE_CTRL_REG  [0]   R/W  Bit 0: Software Override Enable
//                                 [1]   W    Bit 1: Flush Request Pulse
//   0xFFFF_0008 : CACHE_STAT_REG  [15:8] R   Hit Counter (Read-to-clear)
//                                 [7:0]  R   Miss Counter (Read-to-clear)
// =============================================================================

module l2_csr_control_bank (
    input  wire        clk,
    input  wire        reset,

    // CPU CSR Bus Interface
    input  wire [31:0] cpu_address,
    input  wire [31:0] cpu_write_data,
    input  wire        cpu_write_en,
    output wire [31:0] cpu_read_data,

    // Hardware Telemetry Inputs
    input  wire        cache_hit,
    input  wire        cache_miss,

    // Cache Configuration Outputs
    output wire [1:0]  sel_out,
    output wire        override_en_out,
    output wire        flush_req,
    output wire        prefetch_en_out,
    output wire        mshr_en_out,
    output wire        workload_mode_out
);

    localparam ADDR_CFG    = 32'hFFFF_0000;
    localparam ADDR_CTRL   = 32'hFFFF_0004;
    localparam ADDR_STAT   = 32'hFFFF_0008;

    reg [4:0] cfg_reg;
    reg       ctrl_override_reg;
    reg       ctrl_flush_reg;

    reg [7:0] hit_counter;
    reg [7:0] miss_counter;

    // Output assignments
    assign sel_out           = cfg_reg[1:0];
    assign prefetch_en_out   = cfg_reg[2];
    assign mshr_en_out       = cfg_reg[3];
    assign workload_mode_out = cfg_reg[4];
    assign override_en_out   = ctrl_override_reg;
    assign flush_req         = ctrl_flush_reg;

    // Write Logic
    always @(posedge clk) begin
        if (!reset) begin
            // Default: 8-Way (2'b11), Prefetcher Enabled (1'b1), MSHR Enabled (1'b1), General (1'b0)
            cfg_reg           <= 5'b01111;
            ctrl_override_reg <= 1'b0;  // Default: Hardware autonomous epoch control
            ctrl_flush_reg    <= 1'b0;
        end else begin
            ctrl_flush_reg    <= 1'b0;  // Self-clearing pulse

            if (cpu_write_en) begin
                case (cpu_address)
                    ADDR_CFG:  cfg_reg           <= cpu_write_data[4:0];
                    ADDR_CTRL: begin
                        ctrl_override_reg <= cpu_write_data[0];
                        ctrl_flush_reg    <= cpu_write_data[1];
                    end
                    default: ;
                endcase
            end
        end
    end

    // Telemetry Saturating Counters
    always @(posedge clk) begin
        if (!reset) begin
            hit_counter  <= 8'd0;
            miss_counter <= 8'd0;
        end else begin
            if (cache_hit  && (hit_counter  != 8'hFF)) hit_counter  <= hit_counter  + 1'b1;
            if (cache_miss && (miss_counter != 8'hFF)) miss_counter <= miss_counter + 1'b1;

            // Read-to-clear on status register access
            if (!cpu_write_en && (cpu_address == ADDR_STAT)) begin
                hit_counter  <= 8'd0;
                miss_counter <= 8'd0;
            end
        end
    end

    // Read Multiplexer
    reg [31:0] read_data_mux;
    always @(*) begin
        case (cpu_address)
            ADDR_CFG:  read_data_mux = {27'd0, cfg_reg};
            ADDR_CTRL: read_data_mux = {30'd0, ctrl_flush_reg, ctrl_override_reg};
            ADDR_STAT: read_data_mux = {16'd0, hit_counter, miss_counter};
            default:   read_data_mux = 32'd0;
        endcase
    end

    assign cpu_read_data = read_data_mux;

endmodule
