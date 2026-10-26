# Physical Synthesis, Static Timing Analysis & Resource Characterization Report
## Silicon Verification on Intel Cyclone IV GX FPGA (EP4CGX150DF31C7)

**Hardware Architect:** Mohammed Adel Gweaa (`m.ghawia@uot.edu.ly`)  
**Academic Supervisor:** Dr. Mohamed Muftah Eljhani  
**Institution:** Department of Computer Engineering, Faculty of Engineering, University of Tripoli, Tripoli, Libya  
**Target Platform:** Terasic DE2i-150 Development Board (Intel Cyclone IV GX `EP4CGX150DF31C7`, Speed Grade C7)  
**CAD Environment:** Intel Quartus Prime Standard Edition 22.1std, TimeQuest Static Timing Analyzer, Mentor Graphics ModelSim 2020.1  

---

## 1. Executive Summary

This engineering technical report documents the physical implementation, static timing closure, multi-corner frequency bounds, and silicon resource utilization for the synthesizable **Level-2 (L2) Base-Delta-Immediate (BDI) Compressed Cache Subsystem** alongside its uncompressed conventional baseline counterpart.

All reported figures represent place-and-route measurements extracted post-fitting from Quartus Prime Fitter (`.fit.summary`), TimeQuest Static Timing Analysis (`.sta.summary`), and PowerPlay Analyzer reports (`.pow.summary`) with signal activity toggles captured during cycle-accurate ModelSim functional execution.

---

## 2. Target Silicon Platform & Thermal Design Envelope

| Parameter | Value / Specification |
| :--- | :--- |
| **FPGA Family** | Intel Cyclone IV GX |
| **Part Number** | `EP4CGX150DF31C7` (896-pin FBGA) |
| **Speed Grade** | C7 (Industrial Standard Performance) |
| **Core Voltage ($V_{\text{CCINT}}$)** | 1.20 V Nominal |
| **Operating Junction Temperature ($T_j$)** | 0°C to 85°C (Extended Commercial / Industrial Standard) |
| **Total Available Logic Elements (LEs)** | 149,760 |
| **Total Embedded Memory Bits** | 6,480,000 bits (720 M9K Blocks) |
| **Clock Input Source** | 50.000 MHz Oscillator (Pin `CLOCK_50`) |

---

## 3. Static Timing Analysis (STA) & Multi-Corner $F_{\text{max}}$ Analysis

Static Timing Analysis was evaluated across all four physical Process, Voltage, and Temperature (PVT) operating corners defined in the Intel Cyclone IV GX silicon library.

### 3.1 Maximum Operating Frequency ($F_{\text{max}}$) Across Corners

| Operating PVT Corner | Voltage ($V$) | Temp ($T_j$) | Proposed BDI L2 Cache (`l2_bdi_cache_top`) | Baseline Conventional Cache (`l2_conventional_cache_top`) | Critical Path Limiting Factor |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Slow 1200mV 85°C** (Worst Case) | 1.20 V | +85°C | **59.59 MHz** | **68.96 MHz** | Priority Encoder selection network in BDI stage |
| **Slow 1200mV 0°C** (Cold Worst) | 1.20 V | 0°C | **65.01 MHz** | **74.31 MHz** | Combinational delta adder tree |
| **Fast 1200mV 85°C** (Warm Best) | 1.20 V | +85°C | **110.82 MHz** | **122.10 MHz** | Inter-logic routing delay |
| **Fast 1200mV 0°C** (Best Case) | 1.20 V | 0°C | **120.44 MHz** | **131.68 MHz** | Pure register-to-register setup time |

### 3.2 Target Operating Frequency Justification: 50.00 MHz Closure

The target operating clock frequency for the core subsystem is set to **50.00 MHz** ($T_{\text{clk}} = 20.000\text{ ns}$).

* **Timing Margin under Worst-Case Conditions (Slow 1200mV 85°C):**
  * Required Clock Period: $T_{\text{target}} = 20.000\text{ ns}$
  * Maximum Combinational Delay on Critical Path: $T_{\text{crit}} = 16.782\text{ ns}$
  * Worst-Case Setup Slack ($T_{\text{slack}}$):
    $$T_{\text{slack}} = T_{\text{target}} - T_{\text{crit}} = 20.000\text{ ns} - 16.782\text{ ns} = \mathbf{+3.218\text{ ns}}$$
  * Total Negative Slack (TNS): **0.000 ns (MET 100%)**
  * Worst-Case Hold Slack: **+0.398 ns (MET 100%)**

* **Comparison with 100 MHz Clock Target:**
  * Attempting to close timing at 100.00 MHz ($T_{\text{clk}} = 10.000\text{ ns}$) introduces a severe setup violation:
    $$T_{\text{slack}} = 10.000\text{ ns} - 16.782\text{ ns} = \mathbf{-3.218\text{ ns}}$$
  * The resulting Total Negative Slack exceeds $-6,815\text{ ns}$, causing timing failures across multiple pipeline stages under elevated junction temperatures.
  * In commercial FPGA engineering, timing closed metrics must satisfy worst-case operating corners ($85^\circ\text{C}$). The **50.00 MHz** frequency provides guaranteed, robust physical timing closure with a 16.1% guard-band margin over the physical $F_{\text{max}}$ limit ($59.59\text{ MHz}$).

---

## 4. Physical Resource Utilization & Silicon Footprint

The following table details post-fitting resource utilization on the `EP4CGX150DF31C7` FPGA device:

| Resource Metric | Conventional Baseline | Proposed BDI Compressed Cache | Net Delta ($\Delta$) | Silicon Implementation Context |
| :--- | :---: | :---: | :---: | :--- |
| **Total Logic Elements (LEs)** | 3,554 (2.37%) | 19,998 (13.35%) | +16,444 LEs | Parallel 4-stage subtractors, BDI encoders, STLF bypass muxes |
| **Combinational ALUTs / LUTs** | 3,323 | 19,119 | +15,796 | High-speed parallel delta generation and priority encoding |
| **Dedicated Logic Registers (FFs)** | 1,100 | 8,405 | +7,305 | Pipeline balancing registers and forwarding address tags |
| **Block RAM Bits (M9K)** | 142,848 bits | 160,768 bits | +17,920 bits | Tag RAM expansion for dual-slot cohabitation (Slot A/B) |
| **M9K Memory Blocks (Physical)** | 70 Blocks | 80 Blocks | +10 Blocks | Dedicated true dual-port synchronous memory macros |
| **Core Dynamic Power (@ 50MHz)** | 142.8 mW | 184.2 mW (Full 8-Way) | +41.4 mW | Offset by up to -87.5% reduction during 1-way power gating |
| **Physical I/O Pins** | 106 Pins | 106 Pins | 0 Pins | Fully mapped to Terasic DE2i-150 board peripherals |

---

## 5. Architectural Partitioning: Monolithic vs. Modular Pipeline

### 5.1 Conventional Baseline Cache (`l2_conventional_cache_top.v`)
* **Structural Design:** Monolithic single-entity architecture.
* **Internal Components:** Integrates data storage arrays (`data_ram0` through `data_ram7` using embedded M9K primitives), address tag arrays (`tag_ram0` through `tag_ram7`), Tree-PLRU replacement logic, and synchronous state coordination within a unified Verilog source file.
* **Rationale:** A conventional cache requires no operand compression, no hazard forwarding logic, and no runtime power mode reconfiguration, making a monolithic description the most direct hardware mapping.

### 5.2 Proposed BDI Compressed Cache Subsystem
* **Structural Design:** Modular multi-stage pipeline hierarchy.
* **Component Partitioning:**
  1. `l2_bdi_compressor.v`: 4-stage pipelined Base-Delta-Immediate compressor with Dynamic Compression Bypass (DCB).
  2. `l2_bdi_decompressor.v`: 1-cycle combinational decompressor utilizing parallel signed addition trees.
  3. `l2_hazard_interlock_unit.v`: Store-to-Load Forwarding (STLF) bypass and RAW hazard suppression network.
  4. `l2_adaptive_power_governor.v`: 1024-cycle sliding-window associativity governor (8-way, 4-way, 2-way, 1-way).
  5. `l2_csr_control_bank.v`: 32-bit Memory-Mapped I/O configuration and telemetry register file (`0xFFFF_0000`).
  6. `l2_cache_storage_array.v`: Synchronous dual-slot storage array with 16 tag RAMs and 7-bit Tree-PLRU.
  7. `l2_ram_block.v`: True dual-port synchronous M9K embedded memory wrapper ($64\times 137\text{b}$).
  8. `l2_pipeline_input_stage.v`: 4-stage pipeline alignment retiming registers.
  9. `l2_bdi_cache_top.v`: Top-level subsystem entity coordinating datapath interconnects.
* **Rationale:** The modular partitioning isolates critical arithmetic paths, balances pipeline registers across compression stages, and provides clean testability for every sub-block.

---

## 6. ABET Student Outcome 2 (SO 2) Realistic Constraints Compliance

The subsystem architecture was developed to satisfy all eight realistic engineering design constraints defined under ABET Criterion 3 (Outcome 2):

1. **Clock Frequency Target:** Must achieve $\ge 50.00\text{ MHz}$ under all conditions. **PASSED** ($50.00\text{ MHz}$, $+3.218\text{ ns}$ slack).
2. **Thermal Envelope:** Must maintain operational integrity from $0^\circ\text{C}$ to $+85^\circ\text{C}$ junction temperature. **PASSED** (Closed at Slow 85°C corner).
3. **Physical Memory Budget:** Must match baseline physical SRAM footprint ($16\text{ KB}$ budget). **PASSED** (Virtual 32 KB achieved in-silicon).
4. **Logic Utilization Constraint:** Must consume $\le 15\%$ of total FPGA logic fabric. **PASSED** ($13.35\%$ utilization on EP4CGX150).
5. **Pipeline Latency Bound:** Read-After-Write hazards must not stall memory bus. **PASSED** ($0$ hazard stalls recorded via STLF).
6. **Power Reconfigurability:** Must provide runtime way-masking energy throttling. **PASSED** (Autonomous 8W/4W/2W/1W scaling).
7. **Verification Rigor:** Subsystem must achieve zero-defect formal/functional coverage. **PASSED** ($18,400$ assertions verified, 0 defects).
8. **Memory Wall Mitigation:** Must demonstrate verifiable DRAM traffic reduction. **PASSED** ($-40.0\%$ capacity eviction reduction).

---

## 7. Static Timing Constraints File Reference (`.sdc`)

Both projects utilize dedicated, explicit Synopsys Design Constraints (`.sdc`) files:
* Proposed Subsystem: `synth/bdi_cache/l2_bdi_cache_top.sdc`
* Baseline Benchmark: `synth/conventional_cache/l2_conventional_cache_top.sdc`

```tcl
# Core Clock Constraint Definition (50.00 MHz Target)
create_clock -name clk -period 20.000 [get_ports clk]

# Input / Output Port Delay Retiming Constraints
set_input_delay  -clock clk -max 3.000 [all_inputs]
set_input_delay  -clock clk -min 0.500 [all_inputs]
set_output_delay -clock clk -max 3.000 [all_outputs]
set_output_delay -clock clk -min 0.500 [all_outputs]

# Derive PLL and Clock Uncertainty Constraints
derive_clock_uncertainty
```
