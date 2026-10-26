`timescale 1 ps / 1 ps

module tb_l2_conventional_cache_power;

    // 50.0 MHz Clock (20,000 ps period -> 10,000 ps half period)
    localparam CLK_PERIOD = 20000;
    localparam CLK_HALF   = 10000;
    localparam NUM_SETS   = 8;
    localparam NUM_WAYS   = 8;

    reg clk;
    reg reset;

    // Primary Core Interface
    reg         request_valid;
    reg  [31:0] address;
    reg         write;
    reg         is_refill;
    reg  [255:0] data_in;

    // MMIO CSR
    reg  [31:0] cpu_mmio_address;
    reg  [31:0] cpu_mmio_wdata;
    reg         cpu_mmio_wen;
    wire [31:0] cpu_mmio_rdata;

    // Responses
    wire [255:0] data_out;
    wire         hit;
    wire         miss;
    wire         response_valid;
    wire         hazard_stall;
    wire         dcb_bypass_active;

    // Eviction
    wire         evict_valid;
    wire [31:0]  evict_address;
    wire [255:0] evict_data;
    reg          evict_ack;

    // Telemetry Probes
    wire [9:0]  dbg_access_count;
    wire [9:0]  dbg_miss_count;
    wire [1:0]  dbg_current_sel;
    wire        dbg_epoch_done;
    wire [31:0] dbg_hazard_count;

    // Instantiate Post-Fit Netlist
    l2_conventional_cache_top uut (
        .clk(clk),
        .reset(reset),
        .request_valid(request_valid),
        .address(address),
        .write(write),
        .is_refill(is_refill),
        .data_in(data_in),
        .cpu_mmio_address(cpu_mmio_address),
        .cpu_mmio_wdata(cpu_mmio_wdata),
        .cpu_mmio_wen(cpu_mmio_wen),
        .cpu_mmio_rdata(cpu_mmio_rdata),
        .data_out(data_out),
        .hit(hit),
        .miss(miss),
        .response_valid(response_valid),
        .hazard_stall(hazard_stall),
        .dcb_bypass_active(dcb_bypass_active),
        .evict_valid(evict_valid),
        .evict_address(evict_address),
        .evict_data(evict_data),
        .evict_ack(evict_ack),
        .dbg_access_count(dbg_access_count),
        .dbg_miss_count(dbg_miss_count),
        .dbg_current_sel(dbg_current_sel),
        .dbg_epoch_done(dbg_epoch_done),
        .dbg_hazard_count(dbg_hazard_count)
    );

    // Clock generator
    initial begin
        clk = 1'b0;
        forever #CLK_HALF clk = ~clk;
    end

    // Auto-respond to evictions
    always @(posedge clk) begin
        if (evict_valid) begin
            evict_ack <= 1'b1;
        end else begin
            evict_ack <= 1'b0;
        end
    end

    // Test pattern generator
    function [255:0] gen_test_data;
        input integer s_idx;
        input integer w_idx;
        input integer p_sel;
        begin
            case (p_sel % 4)
                0: gen_test_data = {8{32'h1000_0000 + (s_idx << 8) + w_idx}};
                1: gen_test_data = {4{64'hA55A_5AA5_F00F_0FF0 ^ {s_idx[15:0], w_idx[15:0], 32'h1234_5678}}};
                2: gen_test_data = {8{32'hDEAD_BEEF ^ {s_idx[7:0], w_idx[7:0], 16'hAAAA}}};
                default: gen_test_data = {64'hCAFE_BABE_DEAD_BEEF, 64'h0123_4567_89AB_CDEF, 64'hFEDC_BA98_7654_3210, 64'hA5A5_5A5A_3C3C_C3C3};
            endcase
        end
    endfunction

    // Cache Address Helper: [Tag: 31:11] [Set: 10:5] [Offset: 4:0]
    function [31:0] make_addr;
        input [20:0] tag;
        input [5:0]  set;
        begin
            make_addr = {tag, set, 5'b00000};
        end
    endfunction

    task do_write;
        input [31:0] a;
        input [255:0] d;
        begin
            @(posedge clk);
            #100;
            address       = a;
            data_in       = d;
            write         = 1'b1;
            request_valid = 1'b1;
            is_refill     = 1'b0;
            @(posedge clk);
            #100;
            request_valid = 1'b0;
            write         = 1'b0;
            data_in       = 256'd0;
            repeat (4) @(posedge clk);
            #100;
        end
    endtask

    task do_read;
        input [31:0] a;
        begin
            @(posedge clk);
            #100;
            address       = a;
            write         = 1'b0;
            request_valid = 1'b1;
            is_refill     = 1'b0;
            @(posedge clk);
            #100;
            request_valid = 1'b0;
            repeat (3) @(posedge clk);
            #100;
        end
    endtask

    integer s_i, w_i, r_i;
    reg [31:0] cur_addr;
    reg [255:0] cur_data;

    initial begin
        $display("==================================================================");
        $display("  STARTING HIGH-CONFIDENCE GATE-LEVEL POWER SIM: CONVENTIONAL L2 ");
        $display("  Target Netlist: l2_conventional_cache_top.vo (Cyclone IV GX)    ");
        $display("==================================================================");

        reset            = 1'b0; // Assert reset
        request_valid    = 1'b0;
        address          = 32'd0;
        write            = 1'b0;
        is_refill        = 1'b0;
        data_in          = 256'd0;
        cpu_mmio_address = 32'd0;
        cpu_mmio_wdata   = 32'd0;
        cpu_mmio_wen     = 1'b0;
        evict_ack        = 1'b0;

        repeat (20) @(posedge clk);
        #100 reset = 1'b1; // De-assert reset
        repeat (10) @(posedge clk);

        // VCD dumping for Quartus Power Analyzer High Confidence
        $dumpfile("l2_conventional_cache_power.vcd");
        $dumpvars(0, uut);

        $display("[PHASE 1] Populating Baseline Cache across %0d Sets and %0d Ways...", NUM_SETS, NUM_WAYS);
        for (s_i = 0; s_i < NUM_SETS; s_i = s_i + 1) begin
            for (w_i = 0; w_i < NUM_WAYS; w_i = w_i + 1) begin
                cur_addr = make_addr(21'h001000 + (w_i * 21'h000100), s_i[5:0]);
                cur_data = gen_test_data(s_i, w_i, s_i + w_i);
                do_write(cur_addr, cur_data);
            end
        end

        repeat (10) @(posedge clk);

        $display("[PHASE 2] High-Activity Cache Hit Burst (Exhaustive Sweep)...");
        for (s_i = 0; s_i < NUM_SETS; s_i = s_i + 1) begin
            for (w_i = 0; w_i < NUM_WAYS; w_i = w_i + 1) begin
                cur_addr = make_addr(21'h001000 + (w_i * 21'h000100), s_i[5:0]);
                do_read(cur_addr);
            end
        end

        repeat (10) @(posedge clk);

        $display("[PHASE 3] Immediate Store-to-Load RAW Hazard Collisions (Stall Events)...");
        for (s_i = 0; s_i < NUM_SETS; s_i = s_i + 1) begin
            cur_addr = make_addr(21'h005000, s_i[5:0]);
            cur_data = gen_test_data(s_i, 1, 2);
            @(posedge clk);
            #100;
            address       = cur_addr;
            data_in       = cur_data;
            write         = 1'b1;
            request_valid = 1'b1;
            @(posedge clk);
            #100;
            write         = 1'b0;
            request_valid = 1'b1;
            @(posedge clk);
            #100;
            request_valid = 1'b0;
            repeat (6) @(posedge clk);
        end

        repeat (10) @(posedge clk);

        $display("[PHASE 4] Capacity Over-Subscription and Evictions...");
        for (s_i = 0; s_i < NUM_SETS; s_i = s_i + 1) begin
            for (w_i = 0; w_i < 4; w_i = w_i + 1) begin
                cur_addr = make_addr(21'h009000 + (w_i * 21'h000200), s_i[5:0]);
                cur_data = gen_test_data(s_i, w_i, 3);
                do_write(cur_addr, cur_data);
            end
        end

        repeat (20) @(posedge clk);

        $display("==================================================================");
        $display("  HIGH-CONFIDENCE SIMULATION FOR BASELINE CACHE FINISHED!         ");
        $display("  VCD Generated: l2_conventional_cache_power.vcd                  ");
        $display("==================================================================");

        $dumpflush;
        $finish;
    end

endmodule
