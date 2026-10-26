# Engineering Contribution Guidelines & Hardware Architecture Standards

Thank you for your interest in contributing to the **Pipelined Compressed L2 Cache with Reconfigurable Control for FPGA**.

To preserve the scientific integrity, zero-defect verification status, and physical timing closure of the synthesizable Verilog core, all contributors must adhere to the following hardware engineering rules.

---

## 1. Strict Three-Track Code Isolation

This repository enforces strict segregation across three independent tracks:

1. **Track 1: Proposed BDI Core (`rtl/bdi_cache/` & `synth/bdi_cache/`)**
   * Must remain pristine.
   * **Never** add board-specific I/O, push-button debouncers, 7-segment display decoders, or JTAG probes to this track.
   * Must retain exactly 29 standard top-level ports.
   * Must synthesize with Virtual Pins (`virtual_pins_bdi.tcl`) and meet 50.00 MHz timing closure ($+3.218\text{ ns}$ minimum setup slack at Slow 85°C corner).

2. **Track 2: Baseline Conventional Cache (`rtl/conventional_cache/` & `synth/conventional_cache/`)**
   * Operates as the scientific control group under identical 16 KB SRAM budget.
   * Do not alter the conventional datapath or latency equations without supervisor approval.

3. **Track 3: Physical Board Demo (`rtl/board_demo/` & `synth/board_demo/`)**
   * Any hardware-specific features, LED outputs, or Altera ISSP JTAG IP cores must reside strictly in `rtl/board_demo/`.
   * Must maintain independent submodule copies so modifications never alter Track 1.

---

## 2. Verilog HDL Coding Conventions

* **Standard:** IEEE 1364-2001 Verilog.
* **Synchronous Resets:** Use active-low synchronous reset (`negedge rst_n`) or active-high synchronous reset as established in existing modules. Avoid mixing reset polarities.
* **Explicit Port Widths:** Every port and internal wire/register must declare explicit bit-widths (e.g., `[31:0]`, `[127:0]`, `[287:0]`).
* **Non-Blocking vs. Blocking Assignments:**
  * Sequential logic (`always @(posedge clk)`): Strictly use non-blocking assignments (`<=`).
  * Combinational logic (`always @(*)`): Strictly use blocking assignments (`=`).
* **No Inferred Latches:** Ensure all `case` statements have a default branch and all `if-else` chains are fully specified.

---

## 3. Verification & Timing Closure Checklist

Before submitting a Pull Request, verify the following steps:

- [ ] **ModelSim Verification:** Run `sim/run_simulations.bat` or `do run_sim.do`. All 18 regression tests must pass with zero errors and zero hazard stalls (`18 PASSED, 0 FAILED`).
- [ ] **Deterministic Read Latency:** Confirm $T_{\text{hit}} = 5\text{ cycles}$ is preserved without bubble insertion.
- [ ] **Timing Closure:** Run full synthesis in Intel Quartus Prime 22.1std (`quartus_sh --flow compile l2_bdi_cache_top`). TimeQuest must report positive worst-case setup slack ($\ge +3.0\text{ ns}$) at 50.00 MHz on Cyclone IV GX `EP4CGX150DF31C7`.
- [ ] **Clean Git Working Tree:** Do not commit temporary build directories (`db/`, `incremental_db/`, `output_files/`, `work/`, `*.wlf`, `*.vcd`).

---

## 4. Submitting a Pull Request

1. Fork the repository and create a feature branch (`git checkout -b feature/architectural-enhancement`).
2. Commit changes using Conventional Commits format (`feat:`, `fix:`, `docs:`, `refactor:`, `perf:`).
3. Ensure the pull request template is filled out completely.
