`timescale 1ns / 1ps
// =============================================================================
// Module Name: l2_bdi_cache_board_demo
// Target:      Terasic DE2i-150 FPGA Board (Intel Cyclone IV GX EP4CGX150DF31C7)
// Project:     Hardware Live Demo & In-System Signal Probe (ISSP) Testbed
// Author:      Mohammed Adel Gweaa | University of Tripoli
// Standard:    IEEE 1364-2001 (Verilog HDL)
//
// =============================================================================
// CRITICAL ARCHITECTURAL NOTICE & ACADEMIC SEPARATION MANDATE:
// =============================================================================
// 1. This module is an EXCLUSIVE interactive physical hardware showcase and
//    diagnostic testbed developed solely for the Proposed BDI Compressed L2 Cache.
// 2. NO SCIENTIFIC BENCHMARK METRICS OR SPEEDUP NUMBERS IN THE RESEARCH PUBLICATION
//    ARE DERIVED FROM THIS BOARD DEMO.
// 3. All published academic results (79 Hits vs 58 Hits, -40% DRAM Evictions,
//    0 RAW Stalls) are strictly measured from cycle-accurate ModelSim simulations
//    and Quartus Prime Static Timing Analysis (50.00 MHz, +3.218ns Slack).
// 4. This board testbed serves exclusively to prove functional deployment,
//    physical pin connectivity, and live real-time operability on physical silicon.
// =============================================================================

module l2_bdi_cache_board_demo (
    // 50 MHz Master Board Oscillator
    input  wire        CLOCK_50,

    // Active-Low Pushbuttons (Debounced)
    // KEY[0]: Request Pulse Trigger (or RAW Hazard Burst when SW[14]=1)
    // KEY[1]: Execution Mode Toggle (Burst / Single-Step)
    // KEY[2]: Manual Eviction Ack
    // KEY[3]: Master Board Reset (Active Low)
    input  wire [3:0]  KEY,

    // Board Slide Switches (SW[17:0] - All 18 Fully Utilized)
    // SW[0]:    0 = Read Access, 1 = Write Access
    // SW[1]:    0 = Core Access, 1 = DRAM Line Refill
    // SW[3:2]:  Target Address Preset (00=0x000, 01=0x020, 10=0x800, 11=0x1000)
    // SW[4]:    Address Source (0 = Switch Presets, 1 = ISSP Injected Address)
    // SW[5]:    Data Source (0 = Switch Presets, 1 = ISSP Injected Data)
    // {SW[15], SW[7:6]}: 8 BDI Compression Pattern Presets:
    //             000 = All-Zeros Line (Profile: Base Zero, 8:1 compression)
    //             001 = Arithmetic Delta 1 (Profile: Base8-Delta1)
    //             010 = Arithmetic Delta 2 (Profile: Base8-Delta2)
    //             011 = Repeated Constant 0xDEADBEEF (Profile: SameWord, 8:1)
    //             100 = Word Delta 1 (Profile: Base4-Delta1)
    //             101 = Word Delta 2 (Profile: Base4-Delta2)
    //             110 = Low-Delta Sparse Vector (Profile: Base2-Delta1)
    //             111 = High-Entropy Pseudorandom (Triggers DCB Bypass!)
    // SW[10:8]: HEX Display Word Selector (0..7 selects 32-bit slice of 256-bit line)
    // SW[11]:   HEX Mode (0 = Display Data Out Word, 1 = Display Diagnostic/Address)
    // SW[12]:   CSR Associativity Override Enable
    // SW[13]:   CSR Associativity Selection (0 = 4-Way Low Power, 1 = 8-Way Maximum Performance)
    // SW[14]:   RAW Pipeline Hazard / STLF Test Injection Mode Enable
    // SW[15]:   High-Bit for 8-Pattern BDI Compression Selector
    // SW[16]:   Dual Sub-Block Packing Slot Selector (0 = Slot A, 1 = Slot B offset +0x10)
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

    // Status Green LEDs (LEDG[8:0])
    // LEDG[0]: Cache Hit (Latched)
    // LEDG[1]: Cache Miss (Latched)
    // LEDG[2]: Cache Response Valid (Latched)
    // LEDG[3]: Dynamic Compression Bypass (DCB) Active (Latched)
    // LEDG[4]: Eviction Valid (Dirty line push to DRAM)
    // LEDG[5]: Store-to-Load Forwarding (STLF) Active (Latched RAW Bypass Pulse)
    // LEDG[7:6]: Current Associativity Selection (00=1-Way, 01=2-Way, 10=4-Way, 11=8-Way)
    // LEDG[8]: Heartbeat / System Activity (Slow 2Hz Oscillator Pulse)
    output wire [8:0]  LEDG,

    // Telemetry Red LEDs (LEDR[17:0] - All 18 Fully Utilized)
    // LEDR[2:0]:   Active BDI Compression Profile ID (0=Uncomp, 1..6=BDI Profiles, 7=Zero/SameWord)
    // LEDR[3]:     Dual Sub-Block Slot B Indicator (Cohabitation Active)
    // LEDR[4]:     RAW Pipeline Hazard Interlock Event Active
    // LEDR[5]:     Single-Step Mode Active Indicator
    // LEDR[6]:     Dynamic Compression Bypass (DCB) Active Latched
    // LEDR[7]:     Write Operation Active
    // LEDR[8]:     DRAM Line Refill Active
    // LEDR[9]:     Eviction in Progress Active
    // LEDR[10]:    Store-to-Load Forwarding (STLF) Bypass Latched Active
    // LEDR[11]:    Cache Hit Latched
    // LEDR[14:12]: Access Activity Counter [2:0] (core_dbg_access[2:0])
    // LEDR[17:15]: Miss Telemetry Counter [2:0]   (core_dbg_miss[2:0])
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
    // 2. Altera In-System Sources and Probes (ISSP) Core (BDIL2)
    // -------------------------------------------------------------------------
    wire [356:0] issp_source;
    wire [319:0] issp_probe;

`ifdef QUARTUS_SYNTH
    altsource_probe #(
        .sld_auto_instance_index ("YES"),
        .sld_instance_index      (0),
        .instance_id             ("BDIL2"),
        .probe_width             (320),
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

    // -------------------------------------------------------------------------
    // 4. RAW Hazard Injection State Machine (Live STLF Demonstration)
    // -------------------------------------------------------------------------
    // When SW[14]=1, a single press of KEY[0] initiates an automated 2-cycle burst:
    // Cycle 1: WRITE pattern to address
    // Cycle 2: READ from the EXACT same address (Pipeline RAW Hazard)
    // STLF Unit will immediately forward write data with ZERO stalls!
    reg [1:0] raw_fsm;
    reg       raw_write_pulse;
    reg       raw_read_pulse;

    always @(posedge clk) begin
        if (sys_reset) begin
            raw_fsm         <= 2'b00;
            raw_write_pulse <= 1'b0;
            raw_read_pulse  <= 1'b0;
        end else begin
            raw_write_pulse <= 1'b0;
            raw_read_pulse  <= 1'b0;
            case (raw_fsm)
                2'b00: begin
                    if (SW[14] && req_pulse_reg) begin
                        raw_write_pulse <= 1'b1;
                        raw_fsm         <= 2'b01;
                    end
                end
                2'b01: begin
                    raw_read_pulse <= 1'b1;
                    raw_fsm        <= 2'b00;
                end
                default: raw_fsm <= 2'b00;
            endcase
        end
    end

    wire trigger_request = SW[14] ? (raw_write_pulse | raw_read_pulse) : (req_pulse_reg | issp_pulse);
    wire active_write_cmd = SW[14] ? raw_write_pulse : (SW[0] | issp_write);

    // -------------------------------------------------------------------------
    // 5. Stimulus Multiplexing: Presets vs ISSP
    // -------------------------------------------------------------------------
    // Address Presets with SW[16] Dual Sub-Block Slot B Cohabitation Offset
    wire [4:0] slot_b_offset = SW[16] ? 5'd16 : 5'd0; // Slot B offset = +16 bytes
    reg [31:0] sw_preset_addr;
    always @(*) begin
        case (SW[3:2])
            2'b00: sw_preset_addr = 32'h0000_0000 + slot_b_offset;
            2'b01: sw_preset_addr = 32'h0000_0020 + slot_b_offset;
            2'b10: sw_preset_addr = 32'h0000_0800 + slot_b_offset;
            2'b11: sw_preset_addr = 32'h0000_1000 + slot_b_offset;
        endcase
    end

    // Full 8-Pattern BDI Compression Presets via {SW[15], SW[7:6]}
    reg [255:0] sw_preset_data;
    always @(*) begin
        case ({SW[15], SW[7:6]})
            3'b000: sw_preset_data = 256'h0; // Base Zero (All Zeros)
            3'b001: sw_preset_data = {32'h0000_0007, 32'h0000_0006, 32'h0000_0005, 32'h0000_0004,
                                     32'h0000_0003, 32'h0000_0002, 32'h0000_0001, 32'h0000_0000}; // B8-D1
            3'b010: sw_preset_data = {32'h0000_000E, 32'h0000_000C, 32'h0000_000A, 32'h0000_0008,
                                     32'h0000_0006, 32'h0000_0004, 32'h0000_0002, 32'h0000_0000}; // B8-D2
            3'b011: sw_preset_data = {8{32'hDEAD_BEEF}}; // Repeated Constant (SameWord)
            3'b100: sw_preset_data = {32'h1000_0003, 32'h1000_0002, 32'h1000_0001, 32'h1000_0000,
                                     32'h2000_0003, 32'h2000_0002, 32'h2000_0001, 32'h2000_0000}; // B4-D1
            3'b101: sw_preset_data = {32'h1000_0006, 32'h1000_0004, 32'h1000_0002, 32'h1000_0000,
                                     32'h2000_0006, 32'h2000_0004, 32'h2000_0002, 32'h2000_0000}; // B4-D2
            3'b110: sw_preset_data = {32'h0000_0001, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000,
                                     32'h0000_0000, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000}; // B2-D1 Sparse
            3'b111: sw_preset_data = {32'hA7F3_91C2, 32'h4E18_B5D0, 32'hF09A_2341, 32'h81C3_D4E5,
                                     32'h5B6A_7C8D, 32'h1E2F_3A4B, 32'h9C8B_7A6F, 32'h3412_7856}; // Random (DCB Bypass)
        endcase
    end

    wire [31:0]  muxed_address = SW[4] ? issp_address : sw_preset_addr;
    wire [255:0] muxed_data    = SW[5] ? issp_data_in : sw_preset_data;
    wire         muxed_write   = active_write_cmd;
    wire         muxed_refill  = SW[1] | issp_is_refill;

    // -------------------------------------------------------------------------
    // 6. CSR Override Handling
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
            // Manual switch override of associativity (0=4-Way, 1=8-Way)
            csr_addr_reg  <= 32'h0000_0000;
            csr_wdata_reg <= SW[13] ? 32'h0000_0003 : 32'h0000_0002;
            csr_we_reg    <= 1'b1;
        end else begin
            csr_we_reg    <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // 7. Proposed Core BDI L2 Cache Top Instantiation
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
    wire [2:0]   core_dbg_compress_type;
    wire         core_dbg_fwd_valid;

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
        .workload_mode    (),
        .dbg_compress_type(core_dbg_compress_type),
        .dbg_fwd_valid    (core_dbg_fwd_valid)
    );

    // -------------------------------------------------------------------------
    // 8. Output Status Latches & Live STLF Detection
    // -------------------------------------------------------------------------
    reg        latched_hit;
    reg        latched_miss;
    reg        latched_valid;
    reg        latched_dcb;
    reg        latched_stlf_fwd;
    reg        latched_hazard_event;
    reg [2:0]  latched_comp_type;
    reg [255:0] latched_data_out;

    // Pulse stretcher for human visibility of STLF and Evictions
    reg [21:0] stlf_stretch_cnt;
    always @(posedge clk) begin
        if (sys_reset) begin
            stlf_stretch_cnt <= 22'd0;
            latched_stlf_fwd <= 1'b0;
        end else if (core_dbg_fwd_valid) begin
            stlf_stretch_cnt <= 22'd3_000_000; // ~60 ms visible flash
            latched_stlf_fwd <= 1'b1;
        end else if (stlf_stretch_cnt != 22'd0) begin
            stlf_stretch_cnt <= stlf_stretch_cnt - 1'b1;
            latched_stlf_fwd <= 1'b1;
        end else begin
            latched_stlf_fwd <= 1'b0;
        end
    end

    // RAW Hazard event latching
    always @(posedge clk) begin
        if (sys_reset) begin
            latched_hazard_event <= 1'b0;
        end else if (SW[14] && raw_fsm == 2'b01) begin
            latched_hazard_event <= 1'b1;
        end else if (core_dbg_hazard != 32'd0) begin
            latched_hazard_event <= 1'b1;
        end else if (trigger_request && !SW[14]) begin
            latched_hazard_event <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (sys_reset) begin
            latched_hit       <= 1'b0;
            latched_miss      <= 1'b0;
            latched_valid     <= 1'b0;
            latched_dcb       <= 1'b0;
            latched_comp_type <= 3'd0;
            latched_data_out  <= 256'b0;
        end else begin
            // Update compression profile immediately on write commands or preset selection
            if (active_write_cmd && trigger_request) begin
                latched_comp_type <= core_dbg_compress_type;
                latched_dcb       <= core_dcb_bypass;
            end
            if (core_resp_valid) begin
                latched_hit       <= core_hit;
                latched_miss      <= core_miss;
                latched_valid     <= 1'b1;
                latched_dcb       <= core_dcb_bypass;
                latched_comp_type <= core_dbg_compress_type;
                latched_data_out  <= core_data_out;
            end
        end
    end

    // -------------------------------------------------------------------------
    // 9. Heartbeat Clock Oscillator (Slow ~2 Hz Flash on LEDG[8])
    // -------------------------------------------------------------------------
    reg [24:0] heartbeat_cnt;
    always @(posedge clk) begin
        if (sys_reset)
            heartbeat_cnt <= 25'd0;
        else
            heartbeat_cnt <= heartbeat_cnt + 1'b1;
    end
    wire clk_heartbeat = heartbeat_cnt[24];

    // -------------------------------------------------------------------------
    // 10. Pack ISSP Probes for Host JTAG Readback (320 bits)
    // -------------------------------------------------------------------------
    assign issp_probe[255:0]    = core_data_out;
    assign issp_probe[256]      = core_hit;
    assign issp_probe[257]      = core_miss;
    assign issp_probe[258]      = core_resp_valid;
    assign issp_probe[259]      = core_dbg_fwd_valid; // STLF Bypass Active
    assign issp_probe[260]      = core_dcb_bypass;
    assign issp_probe[261]      = core_evict_valid;
    assign issp_probe[293:262]  = core_evict_address;
    assign issp_probe[303:294]  = core_dbg_access;
    assign issp_probe[313:304]  = core_dbg_miss;
    assign issp_probe[315:314]  = core_dbg_sel;
    assign issp_probe[318:316]  = core_dbg_compress_type;
    assign issp_probe[319]      = latched_stlf_fwd;

    // -------------------------------------------------------------------------
    // 11. 7-Segment Display Subsystem (HEX0 to HEX7)
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

    // SW[11]: Display Data Word vs Request Address / Diagnostic Counters
    reg [31:0] diagnostic_display_mux;
    always @(*) begin
        case (SW[10:8])
            3'b000: diagnostic_display_mux = muxed_address;
            3'b001: diagnostic_display_mux = core_evict_address;
            3'b010: diagnostic_display_mux = core_csr_rdata;
            3'b011: diagnostic_display_mux = {6'b0, core_dbg_access, 6'b0, core_dbg_miss};
            3'b100: diagnostic_display_mux = {8'hBD, 1'b0, latched_comp_type, 4'b0, latched_dcb, SW[16], latched_stlf_fwd, latched_hit, 4'hA, 2'b0, core_dbg_sel};
            3'b101: diagnostic_display_mux = {core_dbg_hazard[15:0], 10'b0, raw_fsm, SW[14], latched_stlf_fwd, latched_valid, latched_hit};
            default: diagnostic_display_mux = muxed_address;
        endcase
    end

    wire [31:0] final_display_32 = SW[11] ? diagnostic_display_mux : display_word_mux;

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
    // 12. Status & Telemetry LED Assignments
    // -------------------------------------------------------------------------
    // Green LEDs
    assign LEDG[0] = latched_hit;
    assign LEDG[1] = latched_miss;
    assign LEDG[2] = latched_valid;
    assign LEDG[3] = latched_dcb;
    assign LEDG[4] = core_evict_valid;
    assign LEDG[5] = latched_stlf_fwd; // STLF RAW Hazard Forwarding Active
    assign LEDG[7:6] = core_dbg_sel;   // Associativity: 00=1-Way, 01=2-Way, 10=4-Way, 11=8-Way
    assign LEDG[8] = clk_heartbeat;    // Master Clock Heartbeat

    // Red LEDs (LEDR[17:0] - All 18 Fully Utilized)
    assign LEDR[2:0]   = latched_comp_type;  // Active BDI Compression Profile (0..7)
    assign LEDR[3]     = SW[16];             // Cohabitation Slot B Selected (+16B offset)
    assign LEDR[4]     = latched_hazard_event | SW[14] | (core_dbg_hazard != 32'd0); // RAW Pipeline Hazard
    assign LEDR[5]     = single_step_mode;   // Single-Step Mode Indicator (KEY[1])
    assign LEDR[6]     = latched_dcb;        // Dynamic Compression Bypass (DCB) Active
    assign LEDR[7]     = muxed_write;        // Write Operation Active
    assign LEDR[8]     = muxed_refill;       // DRAM Line Refill Active
    assign LEDR[9]     = core_evict_valid;   // Eviction in Progress
    assign LEDR[10]    = latched_stlf_fwd;   // STLF Forwarding Latched
    assign LEDR[11]    = latched_hit;        // Cache Hit Latched
    assign LEDR[14:12] = core_dbg_access[2:0]; // Telemetry: Access count [2:0]
    assign LEDR[17:15] = core_dbg_miss[2:0];   // Telemetry: Miss count [2:0]

endmodule
