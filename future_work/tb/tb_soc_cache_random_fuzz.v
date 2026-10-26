`timescale 1ns / 1ps
// =============================================================================
// Testbench Name: tb_soc_cache_random_fuzz
// Project:        High-Performance BDI Compressed L2 Cache Subsystem for SoC
// Author:         Mohammed Gweaa
// Standard:       IEEE 1364-2001 (Verilog HDL)
//
// Description:
//   Pseudo-Random Fuzzing and High-Stress Testbench for the complete multi-level
//   cache hierarchy (soc_cache_subsystem).
//   Executes 250+ randomized CPU Wishbone load and store transactions across
//   overlapping memory locations, with varying byte enables, verifying bit-exact
//   correctness against an independent Golden Reference Model.
// =============================================================================

module tb_soc_cache_random_fuzz;

    reg clk;
    reg reset;

    // CPU LSU Port
    reg  [31:0] cpu_d_adr_i;
    reg  [31:0] cpu_d_dat_i;
    reg  [3:0]  cpu_d_sel_i;
    reg         cpu_d_we_i;
    reg         cpu_d_cyc_i;
    reg         cpu_d_stb_i;
    wire [31:0] cpu_d_dat_o;
    wire        cpu_d_ack_o;
    wire        cpu_d_stall_o;

    // CPU Instruction Refill Port (Tied off for data fuzzing)
    reg         l1i_req_valid;
    reg  [31:0] l1i_req_addr;
    wire [255:0] l1i_resp_rdata;
    wire        l1i_resp_valid;
    wire        l1i_ready;

    // DRAM Interface
    wire        mem_req_o;
    wire        mem_we_o;
    wire [31:0] mem_addr_o;
    wire [255:0] mem_wdata_o;
    reg  [255:0] mem_rdata_i;
    reg          mem_ready_i;

    // CSR Interface
    reg  [31:0] csr_address;
    reg  [31:0] csr_wdata;
    reg         csr_we;
    wire [31:0] csr_rdata;

    // Diagnostics
    wire [31:0] dbg_l1d_hits;
    wire [31:0] dbg_l1d_misses;
    wire [31:0] dbg_l2_hits;
    wire [31:0] dbg_l2_misses;
    wire [1:0]  dbg_l2_associativity;

    // Device Under Test (DUT)
    soc_cache_subsystem uut (
        .clk                 (clk),
        .reset               (reset),
        .cpu_d_adr_i         (cpu_d_adr_i),
        .cpu_d_dat_i         (cpu_d_dat_i),
        .cpu_d_sel_i         (cpu_d_sel_i),
        .cpu_d_we_i          (cpu_d_we_i),
        .cpu_d_cyc_i         (cpu_d_cyc_i),
        .cpu_d_stb_i         (cpu_d_stb_i),
        .cpu_d_dat_o         (cpu_d_dat_o),
        .cpu_d_ack_o         (cpu_d_ack_o),
        .cpu_d_stall_o       (cpu_d_stall_o),
        .l1i_req_valid       (l1i_req_valid),
        .l1i_req_addr        (l1i_req_addr),
        .l1i_resp_rdata      (l1i_resp_rdata),
        .l1i_resp_valid      (l1i_resp_valid),
        .l1i_ready           (l1i_ready),
        .mem_req_o           (mem_req_o),
        .mem_we_o            (mem_we_o),
        .mem_addr_o          (mem_addr_o),
        .mem_wdata_o         (mem_wdata_o),
        .mem_rdata_i         (mem_rdata_i),
        .mem_ready_i         (mem_ready_i),
        .csr_address         (csr_address),
        .csr_wdata           (csr_wdata),
        .csr_we              (csr_we),
        .csr_rdata           (csr_rdata),
        .dbg_l1d_hits        (dbg_l1d_hits),
        .dbg_l1d_misses      (dbg_l1d_misses),
        .dbg_l2_hits         (dbg_l2_hits),
        .dbg_l2_misses       (dbg_l2_misses),
        .dbg_l2_associativity(dbg_l2_associativity)
    );

    // 50 MHz System Clock
    always #10 clk = ~clk;

    // Simulated DRAM Memory
    reg [255:0] dram_memory [0:2047];
    integer init_i;

    always @(posedge clk) begin
        if (!reset) begin
            mem_ready_i <= 1'b0;
            mem_rdata_i <= 256'd0;
        end else if (mem_req_o && !mem_ready_i) begin
            mem_ready_i <= 1'b1;
            if (mem_we_o) begin
                dram_memory[mem_addr_o[15:5]] <= mem_wdata_o;
            end else begin
                mem_rdata_i <= dram_memory[mem_addr_o[15:5]];
            end
        end else begin
            mem_ready_i <= 1'b0;
        end
    end

    // Golden Reference Model (Byte-Addressable Memory)
    reg [7:0] golden_memory [0:65535];

    // CPU Wishbone Tasks
    task cpu_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  sel;
        begin
            @(posedge clk);
            while (cpu_d_stall_o) @(posedge clk);
            cpu_d_adr_i = addr;
            cpu_d_dat_i = data;
            cpu_d_sel_i = sel;
            cpu_d_we_i  = 1'b1;
            cpu_d_cyc_i = 1'b1;
            cpu_d_stb_i = 1'b1;

            @(posedge clk);
            while (!cpu_d_ack_o) @(posedge clk);
            cpu_d_cyc_i = 1'b0;
            cpu_d_stb_i = 1'b0;
            cpu_d_we_i  = 1'b0;

            // Update Golden Model
            if (sel[0]) golden_memory[addr + 0] = data[7:0];
            if (sel[1]) golden_memory[addr + 1] = data[15:8];
            if (sel[2]) golden_memory[addr + 2] = data[23:16];
            if (sel[3]) golden_memory[addr + 3] = data[31:24];
        end
    endtask

    task cpu_read;
        input  [31:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            while (cpu_d_stall_o) @(posedge clk);
            cpu_d_adr_i = addr;
            cpu_d_sel_i = 4'b1111;
            cpu_d_we_i  = 1'b0;
            cpu_d_cyc_i = 1'b1;
            cpu_d_stb_i = 1'b1;

            @(posedge clk);
            while (!cpu_d_ack_o) @(posedge clk);
            data = cpu_d_dat_o;
            cpu_d_cyc_i = 1'b0;
            cpu_d_stb_i = 1'b0;
        end
    endtask

    integer op_idx;
    integer fuzz_pass_count;
    integer fuzz_fail_count;
    reg [31:0] rand_addr;
    reg [31:0] rand_data;
    reg [3:0]  rand_sel;
    reg [31:0] read_result;
    reg [31:0] golden_expected;

    initial begin
        clk = 0;
        reset = 0;
        cpu_d_adr_i = 0;
        cpu_d_dat_i = 0;
        cpu_d_sel_i = 0;
        cpu_d_we_i  = 0;
        cpu_d_cyc_i = 0;
        cpu_d_stb_i = 0;
        l1i_req_valid = 0;
        l1i_req_addr  = 0;
        csr_address = 0;
        csr_wdata   = 0;
        csr_we      = 0;
        mem_ready_i = 0;
        mem_rdata_i = 0;
        fuzz_pass_count = 0;
        fuzz_fail_count = 0;

        // Initialize DRAM and Golden Model with deterministic pattern
        for (init_i = 0; init_i < 2048; init_i = init_i + 1) begin
            dram_memory[init_i] = {8{32'h0000_0000 + init_i}};
        end
        for (init_i = 0; init_i < 65536; init_i = init_i + 4) begin
            golden_memory[init_i + 0] = ((init_i / 32) & 8'hFF);
            golden_memory[init_i + 1] = 8'h00;
            golden_memory[init_i + 2] = 8'h00;
            golden_memory[init_i + 3] = 8'h00;
        end

        $display("==================================================================");
        $display("[SoC Fuzzing Testbench] Starting 250 High-Stress Randomized Operations...");
        $display("==================================================================");

        #100;
        reset = 1;
        #40;

        // Run 250 randomized stress operations
        for (op_idx = 1; op_idx <= 250; op_idx = op_idx + 1) begin
            // Generate random word-aligned address within 8KB range (stressing set 0 to 63)
            rand_addr = ($random % 8192) & 32'hFFFF_FFFC;
            if (rand_addr[31]) rand_addr = ~rand_addr & 32'h0000_1FFC;

            // Periodically interleave L1-I instruction refill requests to stress arbiter
            if ((op_idx % 15) == 0) begin
                @(posedge clk);
                l1i_req_valid = 1'b1;
                l1i_req_addr  = 32'h0000_1000 + (op_idx * 32);
                @(posedge clk);
                while (!l1i_resp_valid && !l1i_ready) @(posedge clk);
                l1i_req_valid = 1'b0;
            end

            if (($random % 2) == 0) begin
                // Write Operation
                rand_data = $random;
                rand_sel  = ($random % 15) + 1; // Non-zero byte mask
                cpu_write(rand_addr, rand_data, rand_sel);
            end else begin
                // Read Operation & Verification
                cpu_read(rand_addr, read_result);
                golden_expected = {golden_memory[rand_addr + 3], golden_memory[rand_addr + 2],
                                   golden_memory[rand_addr + 1], golden_memory[rand_addr + 0]};

                if (read_result === golden_expected) begin
                    fuzz_pass_count = fuzz_pass_count + 1;
                end else begin
                    $display("[MISMATCH] Op %0d at Addr 0x%08X: Got 0x%08X, Expected 0x%08X",
                             op_idx, rand_addr, read_result, golden_expected);
                    fuzz_fail_count = fuzz_fail_count + 1;
                end
            end
        end

        #100;
        $display("==================================================================");
        $display("[SoC Fuzzing Testbench] Completed: %0d Verified, %0d Mismatches",
                 fuzz_pass_count, fuzz_fail_count);
        $display("L1-D Hits: %0d, L1-D Misses: %0d", dbg_l1d_hits, dbg_l1d_misses);
        $display("L2 Hits:   %0d, L2 Misses:   %0d", dbg_l2_hits, dbg_l2_misses);
        $display("==================================================================");

        if (fuzz_fail_count == 0)
            $display(">>> ALL SOC RANDOM FUZZING TESTS PASSED <<<");
        else
            $display(">>> FUZZING TESTS ENCOUNTERED MISMATCHES <<<");

        $finish;
    end

endmodule
