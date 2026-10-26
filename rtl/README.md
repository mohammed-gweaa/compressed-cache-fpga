# RTL Architecture & Source Code Directory Guide

This directory contains the synthesizable Verilog HDL (IEEE 1364-2001) implementation of the **Pipelined Compressed L2 Cache Subsystem**, organized into **three strictly isolated architectural tracks**.

---

## Directory Overview & Architectural Tracks

To ensure academic rigor, reproducibility, and prevent debug instrumentation from polluting core research IP, the RTL code is divided into three completely independent directories:

```text
rtl/
├── bdi_cache/                # Track 1: Proposed Pipelined BDI L2 Cache IP Core (Pristine Academic Baseline)
├── conventional_cache/       # Track 2: Conventional Uncompressed L2 Cache (Scientific Baseline Reference)
└── board_demo/               # Track 3: Physical FPGA Board Demonstration (Hardware Wrapper & Isolated Submodules)
```

---

## Detailed Track Descriptions & Architectural Comparison

### 1. Track 1: Proposed BDI Compressed L2 Cache (`rtl/bdi_cache/`)
* **Role:** The primary scientific innovation and subject of the graduation thesis and research paper.
* **Top-Level Module:** `l2_bdi_cache_top.v`
* **Interface Specification:** **29 Pristine Ports** (standard memory controller and CPU request bus; no board-specific or debug signals).
* **Synthesis Strategy:** Synthesized using **Quartus Virtual Pins** (`synth/bdi_cache/`) to accurately benchmark intrinsic logic gate consumption and critical-path timing without FPGA package I/O pad bottlenecks.
* **Submodules (9 files):**
  1. `l2_bdi_cache_top.v`: Master integration entity orchestrating pipeline stages, tag array, compressor, decompressor, STLF interlock, and CSRs.
  2. `l2_bdi_compressor.v`: 4-stage pipelined Base-Delta-Immediate (BDI) compressor evaluating 8 parallel compression patterns (Base8-Delta1, Base8-Delta2, Base8-Delta4, Base4-Delta1, Base4-Delta2, Base2-Delta1, Zero, Repeated-Values).
  3. `l2_bdi_decompressor.v`: Single-cycle combinational decompressor maintaining a deterministic 5-cycle read hit latency ($T_{\text{hit}} = 5\text{ cycles}$).
  4. `l2_hazard_interlock_unit.v`: Store-to-Load Forwarding (STLF) unit detecting RAW hazards across compressor stages and forwarding write data directly to the output.
  5. `l2_cache_storage_array.v`: 8-way dual sub-block synchronous cache array implementing dual slot cohabitation (Slot A / Slot B).
  6. `l2_adaptive_power_governor.v`: Dynamic set-associativity governor (8-way, 4-way, 2-way, 1-way) via epoch counters and miss-rate thresholds.
  7. `l2_csr_control_bank.v`: Memory-mapped Control & Status Register bank for software observability and mode control.
  8. `l2_pipeline_input_stage.v`: Retimed input request synchronizer and latching stage.
  9. `l2_ram_block.v`: Dual-port embedded Block RAM instantiation wrapper targeting Cyclone IV M9K memory blocks.

---

### 2. Track 2: Baseline Conventional L2 Cache (`rtl/conventional_cache/`)
* **Role:** Scientific baseline control for fair head-to-head empirical validation.
* **Top-Level Module:** `l2_conventional_cache_top.v`
* **Architecture:** 16 KB, 8-way set-associative uncompressed cache with Tree-PLRU replacement policy and matched 256-bit memory bus interface.
* **Synthesis Strategy:** Synthesized using **Quartus Virtual Pins** (`synth/conventional_cache/`) under identical timing constraints (50.00 MHz) and FPGA technology libraries.
* **Empirical Comparison:**
  * **Recorded Cache Hits:** 58 hits (Baseline) vs **79 hits** (BDI Cache) $\rightarrow$ **+36.2% capacity gain**.
  * **Off-Chip DRAM Evictions:** 10 evictions (Baseline) vs **6 evictions** (BDI Cache) $\rightarrow$ **-40.0% bandwidth reduction**.
  * **Pipeline RAW Stalls:** 20 stall cycles (Baseline) vs **0 stall cycles** (BDI Cache) $\rightarrow$ **-100% hazard elimination via STLF**.

---

### 3. Track 3: Physical FPGA Board Demonstration (`rtl/board_demo/`)
* **Role:** Live hardware demonstrator for deployment on the Terasic DE2i-150 / DE2-115 development board.
* **Top-Level Module:** `l2_bdi_cache_board_demo.v`
* **Interface Specification:** **106 Physical FPGA Pins** directly mapped to hardware peripherals (push-buttons, slide switches, 7-segment hex displays, LEDs, 50 MHz oscillator).
* **Strict Code Isolation Mandate:**
  * To guarantee zero side-effects on the pristine research core, `rtl/board_demo/` maintains **its own standalone, localized copies** of all 9 RTL submodules.
  * The synthesis project `synth/board_demo/l2_bdi_cache_board_demo.qsf` references **exclusively** files within `rtl/board_demo/`.
  * Diagnostic taps (e.g., `dbg_compress_type`, `dbg_fwd_valid`) and Altera In-System Sources and Probes (ISSP) JTAG IP cores exist **only** within this directory.
* **Hardware Demonstration Features:**
  * Clock divider generating a human-observable 1 Hz / 5 Hz step clock or single-step manual clock via debounced push-button.
  * Input request generator mapping slide switches to address and data fields.
  * 8-digit 7-segment display showing real-time cache metrics (Hit Count, Miss Count, RAW Stalls, Power State).
  * Red/Green LEDs displaying compression types (Zero, Base8, Base4, Base2, Uncompressed) and STLF forwarding events.
  * Altera ISSP JTAG interface enabling live automated stimulus injection and telemetry via Python / Tcl scripts.

---

## Architectural Comparison Matrix

| Feature / Metric | Track 1: `bdi_cache` | Track 2: `conventional_cache` | Track 3: `board_demo` |
| :--- | :---: | :---: | :---: |
| **Directory** | `rtl/bdi_cache/` | `rtl/conventional_cache/` | `rtl/board_demo/` |
| **Primary Module** | `l2_bdi_cache_top.v` | `l2_conventional_cache_top.v` | `l2_bdi_cache_board_demo.v` |
| **Interface Width** | 29 core signals | 29 core signals | 106 physical board pins + JTAG |
| **Compression Logic** | 4-Stage BDI Pipeline | None (Uncompressed) | 4-Stage BDI Pipeline |
| **Hazard Interlock** | STLF (0 RAW Stalls) | Stall Interlock (20 Stalls) | STLF + Hardware LED Probes |
| **Power Scaling** | Dynamic (8/4/2/1-Way) | Static (8-Way) | Dynamic (Switches + ISSP) |
| **Synthesis Target** | Virtual Pins (FPGA Fabric) | Virtual Pins (FPGA Fabric) | Physical Pins (DE2i-150 Package) |
| **Logic Elements (LEs)**| 19,998 (13%) | 3,554 (2%) | 19,034 (13%) |
| **Dedicated FFs** | 8,405 | 1,100 | 8,112 |
| **Memory Bits** | 160,768 | 142,848 | 160,768 |
| **Worst-Case Slack (50 MHz)**| **+3.218 ns (MET)** | **+5.498 ns (MET)** | **+2.914 ns (MET)** |
| **Code Dependencies** | Standalone | Standalone | Standalone (Zero sharing with Track 1) |
| **Verification Scope** | Comprehensive Simulation | Baseline Comparative | Physical FPGA & JTAG ISSP |

---

## Strict Isolation Verification

To verify that the three tracks remain completely isolated and that no accidental cross-folder includes or modifications exist:

```bash
# ModelSim simulation compiles strictly from rtl/bdi_cache/ and rtl/conventional_cache/:
cd sim && run_simulations.bat

# Board demo Quartus project compiles strictly from rtl/board_demo/:
cd synth/board_demo && quartus_map l2_bdi_cache_board_demo
```
