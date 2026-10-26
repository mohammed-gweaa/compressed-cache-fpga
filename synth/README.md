# FPGA Synthesis & Static Timing Analysis (STA) Guide

This directory contains the complete Intel Quartus Prime synthesis, placement, routing, and timing closure configurations for the **Level-2 Compressed Cache Subsystem**, divided into **three independent synthesis projects**.

---

## Synthesis Projects Overview

```text
synth/
├── bdi_cache/                # Track 1: Proposed BDI L2 Cache IP Core Synthesis (Virtual Pins)
├── conventional_cache/       # Track 2: Baseline Conventional Cache Synthesis (Virtual Pins)
└── board_demo/               # Track 3: Physical FPGA Board Demonstration Synthesis (106 Physical Pins)
```

---

## 1. Track 1: Proposed BDI L2 Cache Core (`synth/bdi_cache/`)

### Objective
Measures the intrinsic silicon resource footprint, register retiming, and maximum clock frequency ($F_{\text{max}}$) of the core research architecture without package pin-count limitations.

### Key Files
* `l2_bdi_cache_top.qpf` / `l2_bdi_cache_top.qsf`: Master Quartus Prime project files.
* `l2_bdi_cache_top.sdc`: Synopsys Design Constraints specifying a 50.00 MHz system clock ($T_{\text{clk}} = 20.000\text{ ns}$).
* `virtual_pins_bdi.tcl`: Tcl script declaring all 29 top-level ports as **Virtual Pins** (`VIRTUAL_PIN ON`).
* `TIMING_CLOSURE_100MHz_ANALYSIS.txt`: Comprehensive timing report documenting why 50 MHz was chosen over 100 MHz due to the BDI priority encoder carry chain.
* `l2_bdi_cache_top_rtl_viewer.pdf` / `.png`: Synthesized netlist schematics.

### Implementation Results (Cyclone IV GX `EP4CGX150DF31C7`)
* **Logic Elements (LEs):** 19,998 / 149,760 (13%)
* **Dedicated Logic Registers:** 8,405
* **Total Embedded RAM Bits:** 160,768 bits (Dual Sub-Block array)
* **Worst-Case Timing Slack (Slow 85°C):** **+3.218 ns (MET)**
* **Maximum Operating Frequency ($F_{\text{max}}$):** **59.59 MHz** (Industrial 50 MHz target closed with margin)

---

## 2. Track 2: Conventional Baseline Cache (`synth/conventional_cache/`)

### Objective
Provides an unbiased, silicon-verified reference point of an uncompressed 8-way Tree-PLRU 16 KB cache under identical manufacturing process parameters.

### Key Files
* `l2_conventional_cache_top.qpf` / `l2_conventional_cache_top.qsf`: Quartus project configuration.
* `l2_conventional_cache_top.sdc`: 50.00 MHz clock constraints.
* `virtual_pins_conv.tcl`: Virtual pin assignments for standard baseline ports.

### Implementation Results (Cyclone IV GX `EP4CGX150DF31C7`)
* **Logic Elements (LEs):** 3,554 / 149,760 (2%)
* **Dedicated Logic Registers:** 1,100
* **Total Embedded RAM Bits:** 142,848 bits
* **Worst-Case Timing Slack (Slow 85°C):** **+5.498 ns (MET)**
* **Maximum Operating Frequency ($F_{\text{max}}$):** **68.96 MHz**

---

## 3. Track 3: Physical Board Demonstration (`synth/board_demo/`)

### Objective
Implements a self-contained, fully routable physical bitstream for live interactive demonstration and JTAG In-System verification on the Terasic DE2i-150 / DE2-115 development board.

### Key Files
* `l2_bdi_cache_board_demo.qpf` / `l2_bdi_cache_board_demo.qsf`: Dedicated project compiling strictly from `../../rtl/board_demo/`.
* `l2_bdi_cache_board_demo.sdc`: 50.00 MHz oscillator constraints (`CLOCK_50`).
* `assign_board_demo_pins.tcl`: Complete physical pin assignments mapping **106 board pins** (switches, buttons, 7-segment hex displays, LEDs, clocks).
* `issp_scripts/`: Automated JTAG In-System Sources and Probes (ISSP) testing environment.

### Differences Between Virtual Pins (Tracks 1 & 2) vs Physical Pins (Track 3)

| Parameter | Virtual Pins (`bdi_cache` & `conv_cache`) | Physical Pins (`board_demo`) |
| :--- | :--- | :--- |
| **Purpose** | Academic IP benchmarking & silicon area characterization | Live hardware demonstration & board deployment |
| **I/O Routing** | Absorbed inside FPGA fabric (no physical I/O pads) | Routed to physical BGA package pins (106 pins) |
| **I/O Buffer Delay** | Excluded from STA (measures pure core logic path) | Included with 3.3V LVTTL I/O buffer delays |
| **Bitstream (`.sof`)**| Not generated (fabric-only netlist) | **Generated** for direct USB-Blaster programming |
| **Debug Visibility**| Via ModelSim cycle-accurate testbenches | Via physical LEDs, 7-seg displays & Altera ISSP JTAG |

---

## How to Synthesize via Command Line

### 1. Synthesize Track 1 (Proposed BDI Cache Core)
```bash
cd synth/bdi_cache
quartus_map l2_bdi_cache_top
quartus_fit l2_bdi_cache_top
quartus_sta l2_bdi_cache_top
```

### 2. Synthesize Track 2 (Baseline Conventional Cache)
```bash
cd synth/conventional_cache
quartus_map l2_conventional_cache_top
quartus_fit l2_conventional_cache_top
quartus_sta l2_conventional_cache_top
```

### 3. Synthesize Track 3 & Generate Programming Bitstream (`.sof`)
```bash
cd synth/board_demo
quartus_map l2_bdi_cache_board_demo
quartus_fit l2_bdi_cache_board_demo
quartus_asm l2_bdi_cache_board_demo
quartus_sta l2_bdi_cache_board_demo
```
