`timescale 1ns / 1ps
// =============================================================================
// Module Name: l2_bdi_cache_board_demo
// Target:      Terasic DE2i-150 FPGA Board (Intel Cyclone IV GX EP4CGX150DF31C7)
// Project:     Hardware Live Demo & In-System Signal Probe (ISSP) Testbed
// Author:      Mohammed Gweaa
// Standard:    IEEE 1364-2001 (Verilog HDL)
//
// =============================================================================
// CRITICAL ARCHITECTURAL NOTICE & ACADEMIC SEPARATION MANDATE:
// =============================================================================
// 1. This module is an EXCLUSIVE interactive physical hardware showcase and
//    diagnostic testbed developed solely for OUR BDI Compressed L2 Cache design.
// 2. NO SCIENTIFIC BENCHMARK METRICS, SPEEDUP NUMBERS, OR COMPARATIVE EVALUATION
//    RESULTS IN THE RESEARCH PUBLICATION ARE DERIVED FROM THIS BOARD DEMO.
// 3. All rigorous, published academic results (latency, throughput, AMAT, hit rates,
//    and power dissipation) are strictly measured from deterministic Cycle-Accurate
//    ModelSim/Questa simulations and post-fit Quartus Prime Static Timing and
//    PowerPlay gate-level analyses under unbiased, equalized workloads.
// 4. This board testbed serves exclusively to prove functional deployment,
//    physical pin connectivity, and live real-time operability on physical silicon.
// =============================================================================

module l2_bdi_cache_board_demo (
    // 50 MHz Master Board Oscillator
    input  wire        CLOCK_50,

    // Active-Low Pushbuttons (Debounced)
    // KEY[0]: Request Pulse Trigger
    // KEY[1]: Execution Mode Toggle (Burst / Single-Step)
    // KEY[2]: Manual Eviction Ack
    // KEY[3]: Master Board Reset (Active Low)
    input  wire [3:0]  KEY,

    // Board Slide Switches
    // SW[0]:    0 = Read, 1 = Write
    // SW[1]:    0 = Normal Cache Access, 1 = DRAM Line Refill
    // SW[3:2]:  Address Preset (00=0x000, 01=0x020, 10=0x800, 11=0x1000)
    // SW[4]:    Address Source (0 = SW Presets, 1 = ISSP Injected Address)
    // SW[5]:    Data Source (0 = Pre-programmed Patterns, 1 = ISSP Injected Data)
    // SW[7:6]:  Data Pattern Type:
    //             00 = All-Zeros Line (Zero Base + Delta)
    //             01 = Arithmetic Delta Integers (B8_D2 Compressible)
    //             10 = Repeated Constant 0xDEADBEEF (B8_D1 Compressible)
    //             11 = High-Entropy Pseudo-Random (DCB Bypass Incompressible)
    // SW[10:8]: HEX Display Word Selector (0..7 selects 32-bit slice of 256-bit line)
    // SW[11]:   HEX Mode (0 = Display Data Out Word, 1 = Display Address)
    // SW[12]:   CSR Associativity Override Enable
    // SW[13]:   CSR Associativity Selection (0 = 4-Way, 1 = 8-Way)
    // SW[17]:   Emergency Manual Reset (Active Low)
    input  wire [17:0] SW,

    // 7-Segment Displays (HEX0 to HEX7: 8 Digits = 32 Bits Display)
    output wire [6:0]  HEX0,
    output wire [6:0]  HEX1,
    output wire [6:0]  HEX2,
    output wire [6:0]  HEX3,
    output wire [6:0]  HEX4,
    output wire [6:0]  HEX5,
    output wire [6:0]  HEX6,
    output wire [6:0]  HEX7,

    // Status Green LEDs
    // LEDG[0]: Cache Hit
    // LEDG[1]: Cache Miss
    // LEDG[2]: Cache Response Valid
    // LEDG[3]: Dynamic Compression Bypass (DCB) Active
    // LEDG[4]: Eviction Valid (Dirty line push to DRAM)
    // LEDG[5]: Hazard Stall / Forwarding Active
    // LEDG[7:6]: Current Associativity Selection (01=4-Way, 11=8-Way)
    // LEDG[8]: Pipeline Active / Busy
    output wire [8:0]  LEDG,

    // Telemetry Red LEDs
    // LEDR[7:0]:   Access Counter (dbg_access_count[7:0])
    // LEDR[15:8]:  Miss Counter   (dbg_miss_count[7:0])
    // LEDR[16]:    Single-Step Mode Active Indicator
    // LEDR[17]:    DRAM Eviction Auto-Acknowledge Indicator
    output wire [17:0] LEDR
);

    wire clk = CLOCK_50;

    // -------------------------------------------------------------------------
    // 1. Reset Synthesis & Synchronization
    // -------------------------------------------------------------------------
    wire hw_reset_n = KEY[3] & SW[17];
    reg [2:0] reset_sync;
    always @(posedge clk or negedge hw_reset_n) begin
        if (!hw_reset_n)
            reset_sync <= 3'b000;
        else
            reset_sync <= {reset_sync[1:0], 1'b1};
    end
    wire sys_reset = ~reset_sync[2];

    // -------------------------------------------------------------------------
    // 2. Altera In-System Sources and Probes (ISSP) Core
    // -------------------------------------------------------------------------
    wire [356:0] issp_source;
    wire [315:0] issp_probe;

`ifdef QUARTUS_SYNTH
    altsource_probe #(
        .sld_auto_instance_index ("YES"),
        .sld_instance_index      (0),
        .instance_id             ("BDIL2"),
        .probe_width             (316),
        .source_width            (357),
        .source_initial_value    ("0"),
        .enable_metastability    ("NO")
    ) u_issp (
        .source (issp_source),
        .probe  (issp_probe)
    );
`else
    assign issp_source = 357'b0;
`endif

    // Unpack ISSP Source Signals
    wire [255:0] issp_data_in        = issp_source[255:0];
    wire [31:0]  issp_address        = issp_source[287:256];
    wire         issp_write          = issp_source[288];
    wire         issp_is_refill      = issp_source[289];
    wire         issp_req_toggle     = issp_source[290];
    wire         issp_soft_reset_n   = issp_source[291];
    wire [31:0]  issp_csr_addr       = issp_source[323:292];
    wire [31:0]  issp_csr_wdata      = issp_source[355:324];
    wire         issp_csr_we         = issp_source[356];

    // Synchronize ISSP Request Toggle to Clock Domain
    reg issp_toggle_meta, issp_toggle_sync, issp_toggle_d;
    always @(posedge clk) begin
        if (sys_reset) begin
            issp_toggle_meta <= 1'b0;
            issp_toggle_sync <= 1'b0;
            issp_toggle_d    <= 1'b0;
        end else begin
            issp_toggle_meta <= issp_req_toggle;
            issp_toggle_sync <= issp_toggle_meta;
            issp_toggle_d    <= issp_toggle_sync;
        end
    end
    wire issp_pulse = issp_toggle_sync ^ issp_toggle_d;

    // -------------------------------------------------------------------------
    // 3. Pushbutton Debouncing & Execution Mode Control
    // -------------------------------------------------------------------------
    reg [19:0] db_cnt_req, db_cnt_mode;
    reg key0_sync, key0_prev, req_pulse_reg;
    reg key1_sync, key1_prev;
    reg single_step_mode;

    always @(posedge clk) begin
        if (sys_reset) begin
            db_cnt_req       <= 20'd0;
            db_cnt_mode      <= 20'd0;
            key0_sync        <= 1'b1;
            key0_prev        <= 1'b1;
            key1_sync        <= 1'b1;
            key1_prev        <= 1'b1;
            req_pulse_reg    <= 1'b0;
            single_step_mode <= 1'b0;
        end else begin
            // KEY[0] Request Debounce
            if (KEY[0] == key0_sync) begin
                db_cnt_req <= 20'd0;
            end else begin
                db_cnt_req <= db_cnt_req + 1'b1;
                if (&db_cnt_req) begin
                    key0_sync <= KEY[0];
                    db_cnt_req <= 20'd0;
                end
            end
            key0_prev <= key0_sync;
            req_pulse_reg <= (~key0_sync & key0_prev); // Falling edge (button press)

            // KEY[1] Mode Debounce
            if (KEY[1] == key1_sync) begin
                db_cnt_mode <= 20'd0;
            end else begin
                db_cnt_mode <= db_cnt_mode + 1'b1;
                if (&db_cnt_mode) begin
                    key1_sync <= KEY[1];
                    db_cnt_mode <= 20'd0;
                end
            end
            key1_prev <= key1_sync;
            if (~key1_sync & key1_prev) begin
                single_step_mode <= ~single_step_mode;
            end
        end
    end

    wire trigger_request = req_pulse_reg | issp_pulse;

    // -------------------------------------------------------------------------
    // 4. Stimulus Multiplexing: Board Switches vs ISSP
    // -------------------------------------------------------------------------
    // Address Presets
    reg [31:0] sw_preset_addr;
    always @(*) begin
        case (SW[3:2])
            2'b00: sw_preset_addr = 32'h0000_0000;
            2'b01: sw_preset_addr = 32'h0000_0020;
            2'b10: sw_preset_addr = 32'h0000_0800;
            2'b11: sw_preset_addr = 32'h0000_1000;
        endcase
    end

    // Data Pattern Presets
    reg [255:0] sw_preset_data;
    always @(*) begin
        case (SW[7:6])
            2'b00: sw_preset_data = 256'h0; // All Zeros (Base+Delta Zero)
            2'b01: sw_preset_data = {32'h0000_0007, 32'h0000_0006, 32'h0000_0005, 32'h0000_0004,
                                     32'h0000_0003, 32'h0000_0002, 32'h0000_0001, 32'h0000_0000}; // Arithmetic Delta
            2'b10: sw_preset_data = {8{32'hDEAD_BEEF}}; // Repeated Constant
            2'b11: sw_preset_data = {32'hA7F3_91C2, 32'h4E18_B5D0, 32'hF09A_2341, 32'h81C3_D4E5,
                                     32'h5B6A_7C8D, 32'h1E2F_3A4B, 32'h9C8B_7A6F, 32'h3412_7856}; // Random / Incompressible
        endcase
    end

    wire [31:0]  muxed_address = SW[4] ? issp_address : sw_preset_addr;
    wire [255:0] muxed_data    = SW[5] ? issp_data_in : sw_preset_data;
    wire         muxed_write   = SW[0] | issp_write;
    wire         muxed_refill  = SW[1] | issp_is_refill;

    // -------------------------------------------------------------------------
    // 5. CSR Override Handling
    // -------------------------------------------------------------------------
    reg  [31:0] csr_addr_reg;
    reg  [31:0] csr_wdata_reg;
    reg         csr_we_reg;

    always @(posedge clk) begin
        if (sys_reset) begin
            csr_addr_reg  <= 32'h0;
            csr_wdata_reg <= 32'h0;
            csr_we_reg    <= 1'b0;
        end else if (issp_csr_we) begin
            csr_addr_reg  <= issp_csr_addr;
            csr_wdata_reg <= issp_csr_wdata;
            csr_we_reg    <= 1'b1;
        end else if (SW[12]) begin
            // Manual switch override of associativity
            csr_addr_reg  <= 32'h0000_0000;
            csr_wdata_reg <= SW[13] ? 32'h0000_0003 : 32'h0000_0001;
            csr_we_reg    <= 1'b1;
        end else begin
            csr_we_reg    <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // 6. Core BDI L2 Cache Top Instantiation
    // -------------------------------------------------------------------------
    wire [255:0] core_data_out;
    wire         core_hit;
    wire         core_miss;
    wire         core_resp_valid;
    wire         core_hazard_stall;
    wire         core_dcb_bypass;
    wire         core_evict_valid;
    wire [31:0]  core_evict_address;
    wire [255:0] core_evict_data;
    wire [9:0]   core_dbg_access;
    wire [9:0]   core_dbg_miss;
    wire [1:0]   core_dbg_sel;
    wire         core_dbg_epoch;
    wire [31:0]  core_dbg_hazard;
    wire [31:0]  core_csr_rdata;

    // Automatic Eviction Acknowledge Generator (Simulates DRAM Line Drain)
    reg [1:0] evict_ack_cnt;
    always @(posedge clk) begin
        if (sys_reset) begin
            evict_ack_cnt <= 2'b00;
        end else if (core_evict_valid) begin
            evict_ack_cnt <= evict_ack_cnt + 1'b1;
        end else begin
            evict_ack_cnt <= 2'b00;
        end
    end
    wire auto_evict_ack = (evict_ack_cnt == 2'b10) | (~KEY[2]);

    l2_bdi_cache_top u_bdi_cache_core (
        .clk              (clk),
        .reset            (sys_reset | ~issp_soft_reset_n),
        .request_valid    (trigger_request),
        .address          (muxed_address),
        .write            (muxed_write),
        .is_refill        (muxed_refill),
        .data_in          (muxed_data),
        .cpu_mmio_address (csr_addr_reg),
        .cpu_mmio_wdata   (csr_wdata_reg),
        .cpu_mmio_wen     (csr_we_reg),
        .cpu_mmio_rdata   (core_csr_rdata),
        .data_out         (core_data_out),
        .hit              (core_hit),
        .miss             (core_miss),
        .response_valid   (core_resp_valid),
        .hazard_stall     (core_hazard_stall),
        .dcb_bypass_active(core_dcb_bypass),
        .evict_valid      (core_evict_valid),
        .evict_address    (core_evict_address),
        .evict_data       (core_evict_data),
        .evict_ack        (auto_evict_ack),
        .dbg_access_count (core_dbg_access),
        .dbg_miss_count   (core_dbg_miss),
        .dbg_current_sel  (core_dbg_sel),
        .dbg_epoch_done   (core_dbg_epoch),
        .dbg_hazard_count (core_dbg_hazard),
        .prefetch_en      (),
        .mshr_en          (),
        .workload_mode    ()
    );

    // -------------------------------------------------------------------------
    // 7. Pack ISSP Probes for Host JTAG Readback
    // -------------------------------------------------------------------------
    assign issp_probe[255:0]    = core_data_out;
    assign issp_probe[256]      = core_hit;
    assign issp_probe[257]      = core_miss;
    assign issp_probe[258]      = core_resp_valid;
    assign issp_probe[259]      = core_hazard_stall;
    assign issp_probe[260]      = core_dcb_bypass;
    assign issp_probe[261]      = core_evict_valid;
    assign issp_probe[293:262]  = core_evict_address;
    assign issp_probe[303:294]  = core_dbg_access;
    assign issp_probe[313:304]  = core_dbg_miss;
    assign issp_probe[315:314]  = core_dbg_sel;

    // -------------------------------------------------------------------------
    // 8. Output Status Latches for Human-Visible Board Observation
    // -------------------------------------------------------------------------
    reg        latched_hit;
    reg        latched_miss;
    reg        latched_valid;
    reg        latched_dcb;
    reg [255:0] latched_data_out;

    always @(posedge clk) begin
        if (sys_reset) begin
            latched_hit      <= 1'b0;
            latched_miss     <= 1'b0;
            latched_valid    <= 1'b0;
            latched_dcb      <= 1'b0;
            latched_data_out <= 256'b0;
        end else if (core_resp_valid) begin
            latched_hit      <= core_hit;
            latched_miss     <= core_miss;
            latched_valid    <= 1'b1;
            latched_dcb      <= core_dcb_bypass;
            latched_data_out <= core_data_out;
        end
    end

    // -------------------------------------------------------------------------
    // 9. 7-Segment Display Subsystem (HEX0 to HEX7)
    // -------------------------------------------------------------------------
    // Select which 32-bit word of the 256-bit line to display
    reg [31:0] display_word_mux;
    always @(*) begin
        case (SW[10:8])
            3'b000: display_word_mux = latched_data_out[31:0];
            3'b001: display_word_mux = latched_data_out[63:32];
            3'b010: display_word_mux = latched_data_out[95:64];
            3'b011: display_word_mux = latched_data_out[127:96];
            3'b100: display_word_mux = latched_data_out[159:128];
            3'b101: display_word_mux = latched_data_out[191:160];
            3'b110: display_word_mux = latched_data_out[223:192];
            3'b111: display_word_mux = latched_data_out[255:224];
        endcase
    end

    // SW[11]: Display Data Word vs Request Address
    wire [31:0] final_display_32 = SW[11] ? muxed_address : display_word_mux;

    function [6:0] hex_to_7seg;
        input [3:0] nibble;
        begin
            case (nibble)
                4'h0: hex_to_7seg = 7'b1000000; // 0
                4'h1: hex_to_7seg = 7'b1111001; // 1
                4'h2: hex_to_7seg = 7'b0100100; // 2
                4'h3: hex_to_7seg = 7'b0110000; // 3
                4'h4: hex_to_7seg = 7'b0011001; // 4
                4'h5: hex_to_7seg = 7'b0010010; // 5
                4'h6: hex_to_7seg = 7'b0000010; // 6
                4'h7: hex_to_7seg = 7'b1111000; // 7
                4'h8: hex_to_7seg = 7'b0000000; // 8
                4'h9: hex_to_7seg = 7'b0010000; // 9
                4'hA: hex_to_7seg = 7'b0001000; // A
                4'hB: hex_to_7seg = 7'b0000011; // b
                4'hC: hex_to_7seg = 7'b1000110; // C
                4'hD: hex_to_7seg = 7'b0100001; // d
                4'hE: hex_to_7seg = 7'b0000110; // E
                4'hF: hex_to_7seg = 7'b0001110; // F
                default: hex_to_7seg = 7'b1111111;
            endcase
        end
    endfunction

    assign HEX0 = hex_to_7seg(final_display_32[3:0]);
    assign HEX1 = hex_to_7seg(final_display_32[7:4]);
    assign HEX2 = hex_to_7seg(final_display_32[11:8]);
    assign HEX3 = hex_to_7seg(final_display_32[15:12]);
    assign HEX4 = hex_to_7seg(final_display_32[19:16]);
    assign HEX5 = hex_to_7seg(final_display_32[23:20]);
    assign HEX6 = hex_to_7seg(final_display_32[27:24]);
    assign HEX7 = hex_to_7seg(final_display_32[31:28]);

    // -------------------------------------------------------------------------
    // 10. Status LED Assignments
    // -------------------------------------------------------------------------
    assign LEDG[0] = latched_hit;
    assign LEDG[1] = latched_miss;
    assign LEDG[2] = latched_valid;
    assign LEDG[3] = latched_dcb;
    assign LEDG[4] = core_evict_valid;
    assign LEDG[5] = core_hazard_stall;
    assign LEDG[7:6] = core_dbg_sel;
    assign LEDG[8] = trigger_request | core_evict_valid;

    assign LEDR[7:0]   = core_dbg_access[7:0];
    assign LEDR[15:8]  = core_dbg_miss[7:0];
    assign LEDR[16]    = single_step_mode;
    assign LEDR[17]    = auto_evict_ack;

endmodule
