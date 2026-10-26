# Pipelined Compressed L2 Cache with Reconfigurable Control for FPGA

[![Hardware Licence](https://img.shields.io/badge/Licence-CERN--OHL--W--2.0-blue.svg)](LICENSE)
[![Target FPGA](https://img.shields.io/badge/FPGA-Intel_Cyclone_IV_GX-0071C5.svg)](https://www.intel.com)
[![Board Target](https://img.shields.io/badge/Platform-Terasic_DE2i--150-red.svg)](https://www.terasic.com.tw)
[![Timing Closure](https://img.shields.io/badge/Timing_Closure-50.00_MHz_MET_(+3.218ns)-brightgreen.svg)]()
[![HDL Standard](https://img.shields.io/badge/HDL-Verilog_IEEE_1364--2001-orange.svg)]()

A synthesizable Level-2 (L2) cache architecture with Base-Delta-Immediate (BDI) compression, Store-to-Load Forwarding (STLF), and runtime reconfigurable way-masking power control. Synthesized, placed, routed, and timing-closed on an Intel Cyclone IV GX FPGA (`EP4CGX150DF31C7`) on the Terasic DE2i-150 Development Platform.

Developed at the Department of Computer Engineering, Faculty of Engineering, University of Tripoli.

---

## Academic Poster

The complete graduation defense poster is available in [`poster/EngPoster.pdf`](poster/EngPoster.pdf).

<p align="center">
  <img src="poster/exports/03_Poster_Facebook_Feed_Standard_2048px.jpg" alt="Academic Graduation Poster" width="90%">
</p>

---

## Architectural Features

* **4-Stage Pipelined BDI Compressor:** Evaluates parallel delta extractions across 8 compression states per Pekhimenko et al. (Base8-Delta1, Base8-Delta2, Base8-Delta4, Base4-Delta1, Base4-Delta2, Base2-Delta1, Zero, Repeated-Values).
* **Single-Cycle Combinational Decompressor:** Executes parallel signed additions in one clock cycle, maintaining a deterministic 5-cycle read hit latency ($T_{\text{hit}} = 5\text{ cycles}$).
* **Dual Sub-Block Packing (Slot A / Slot B):** Cohabitats two compressed 128-bit blocks into a single 288-bit physical cache line, doubling logical cache capacity without additional physical SRAM cells.
* **Store-to-Load Forwarding (STLF):** Detects Read-After-Write (RAW) pipeline hazards across compressor stages and forwards write data directly to the output, eliminating 100% of pipeline hazard stalls (0 stalls vs 20 stalls in the baseline cache).
* **Adaptive Power Governor:** Dynamically scales set associativity (8-way, 4-way, 2-way, 1-way) via CSR and epoch counters, cutting dynamic bitline switching energy by up to 87.5% under low memory pressure.
* **Fair Baseline Comparison:** Includes an uncompressed 8-way Tree-PLRU conventional cache (`rtl/conventional_cache/l2_conventional_cache_top.v`) under identical 16 KB SRAM budget for head-to-head architectural validation.

---

## Silicon-Verified Implementation Results

Synthesized with Intel Quartus Prime Standard Edition 22.1std and verified with Mentor Graphics / Intel ModelSim 2020.1 on Cyclone IV GX (`EP4CGX150DF31C7`, Speed Grade C7):

| Metric | Conventional Baseline | Proposed BDI L2 Cache | Delta ($\Delta$) | Architectural Rationale |
| :--- | :---: | :---: | :---: | :--- |
| **Top Entity** | `l2_conventional_cache_top` | `l2_bdi_cache_top` | -- | Matched 256-bit memory datapath |
| **Logic Elements (LEs)** | 3,554 (2%) | 19,998 (13%) | +16,444 LEs | Parallel delta subtractors, priority encoders, STLF multiplexers |
| **Dedicated Registers** | 1,100 FFs | 8,405 FFs | +7,305 FFs | 4-stage compression pipeline and forwarding retiming |
| **Block RAM Bits** | 142,848 bits | 160,768 bits | +17,920 bits | Dual sub-block tag and cohabitation metadata storage |
| **Fmax (Slow 85°C Corner)** | 68.96 MHz | 59.59 MHz | -9.37 MHz | Critical path through priority selection network |
| **Target Clock Frequency** | **50.00 MHz** | **50.00 MHz** | 0.00 MHz | Standard industrial operating frequency |
| **Worst-Case Setup Slack** | **+5.498 ns (MET)** | **+3.218 ns (MET)** | -2.280 ns | Fully timing closed at Slow 1200mV 85°C |
| **Recorded Cache Hits** | 58 hits | 79 hits | **+36.2%** | Expanded effective capacity via Dual Sub-Block packing |
| **DRAM Capacity Evictions** | 10 evictions | 6 evictions | **-40.0%** | Reduced off-chip memory access penalty |
| **Pipeline RAW Stalls** | 20 stall cycles | 0 stall cycles | **-100% (Zero)** | Complete hazard suppression via STLF unit |
| **Dynamic Energy Control** | Fixed (8-Way) | Dynamic (8/4/2/1-Way) | Up to **-87.5%** | Run-time way-masking power governor |

---

## Repository Structure

```text
.
├── rtl/                               # Synthesizable Verilog HDL IP Core
│   ├── bdi_cache/                     # Proposed BDI Compressed L2 Cache Subsystem
│   │   ├── l2_bdi_cache_top.v         # Master L2 Compressed Cache Top Entity
│   │   ├── l2_bdi_compressor.v        # 4-Stage Pipelined BDI Parallel Compressor
│   │   ├── l2_bdi_decompressor.v      # Single-Cycle Combinational Decompressor
│   │   ├── l2_hazard_interlock_unit.v # STLF RAW Hazard Interlock & Forwarding
│   │   ├── l2_cache_storage_array.v   # 8-Way Dual-Slot Synchronous Cache Array
│   │   ├── l2_adaptive_power_governor.v # Dynamic Set-Associativity Governor
│   │   ├── l2_csr_control_bank.v      # MMIO Software Control Register Bank
│   │   ├── l2_pipeline_input_stage.v  # Retimed Request Synchronizer Stage
│   │   └── l2_ram_block.v             # Embedded Dual-Port Block RAM Wrapper
│   ├── conventional_cache/            # Baseline Reference Cache
│   │   └── l2_conventional_cache_top.v# 16 KB Conventional Uncompressed 8-Way Cache
│   └── board_demo/                    # Physical FPGA Demonstration Wrapper
│       └── l2_bdi_cache_board_demo.v  # DE2i-150 Physical Pin & ISSP Interface
├── tb/                                # Verification Testbenches
│   ├── bdi_cache/                     # Proposed BDI Cache Testbenches
│   │   └── tb_l2_bdi_cache_top.v      # 17-Scenario Exhaustive Core Testbench
│   ├── comparative/                   # Head-to-Head Comparative Stress Benchmark
│   │   └── tb_l2_comparative_stress_benchmark.v # Unbiased Benchmark vs Baseline
│   └── paper_artifacts/               # Publication Waveform Capture
│       └── tb_paper_journal_artifacts.v # Academic Figures 9 & 10 Testbench
├── sim/                               # Simulation Scripts (ModelSim / QuestaSim)
│   ├── run_sim.do                     # Automated Compilation & Regression Suite
│   ├── run_simulations.bat            # Windows Command-Line Batch Runner
│   ├── RUN_WAVEFORM_L2_TOP.bat        # Interactive GUI Launcher
│   ├── wave_l2_bdi_cache_top.do       # Full Hierarchical Waveform Configuration
│   ├── wave_comparative_benchmark.do  # Comparative Analysis Waveform
│   ├── wave_paper_read_stlf.do        # STLF Hazard Bypass Waveform
│   └── wave_paper_write_compression.do# Pipelined Write Compression Waveform
├── synth/                             # FPGA Synthesis & Implementation (Quartus Prime)
│   ├── bdi_cache/                     # Proposed BDI Cache Synthesis Project
│   │   ├── l2_bdi_cache_top.qpf       # Quartus Project File
│   │   ├── l2_bdi_cache_top.qsf       # Settings & Constraints
│   │   ├── l2_bdi_cache_top.sdc       # Timing Constraints (50.00 MHz Clocks)
│   │   ├── virtual_pins_bdi.tcl       # Virtual Pins TCL Script
│   │   ├── TIMING_CLOSURE_100MHz_ANALYSIS.txt # 100MHz vs 50MHz Timing Report
│   │   ├── l2_bdi_cache_top_rtl_viewer.pdf # Gate-Level Netlist Schematic
│   │   └── l2_bdi_cache_top_rtl_viewer.png
│   ├── conventional_cache/            # Baseline Conventional Cache Project
│   │   ├── l2_conventional_cache_top.qpf
│   │   ├── l2_conventional_cache_top.qsf
│   │   ├── l2_conventional_cache_top.sdc
│   │   └── virtual_pins_conv.tcl
│   └── board_demo/                    # Physical Hardware Board Demo Project
│       ├── l2_bdi_cache_board_demo.qpf
│       ├── l2_bdi_cache_board_demo.qsf
│       ├── assign_board_demo_pins.tcl # DE2i-150 Physical Pin Constraints (106 Pins)
│       └── issp_scripts/              # Altera ISSP JTAG Automation Scripts
├── docs/                              # Technical Engineering Specifications
│   ├── MASTER_ARCHITECTURE_SPECIFICATION.md # Full Microarchitecture Reference Manual
│   ├── PHYSICAL_SYNTHESIS_AND_TIMING_REPORT.md # Static Timing & Corner Analysis Report
│   ├── COMPARATIVE_CACHE_AUDIT.md     # In-Depth Baseline vs. BDI Engineering Audit
│   ├── SOC_INTEGRATION_ROADMAP.md     # Multi-Core Interconnect & RISC-V Roadmap
│   └── DE2i-150_FPGA_System_manual.pdf# Terasic Hardware Reference Manual
├── poster/                            # Academic Graduation Poster & Deliverables
│   ├── EngPoster.pdf                  # Master 2.0m x 1.5m Print-Ready Vector PDF
│   ├── RTL.pdf                        # Synthesized Gate-Level RTL Schematic
│   ├── exports/                       # High-Resolution Publication Renders
│   └── latex_source/                  # Original XeLaTeX / TikZ Poster Code
├── future_work/                       # Multi-Core SoC Hierarchy Models
├── CITATION.cff                       # Machine-Readable Citation Metadata
├── LICENSE                            # CERN Open Hardware Licence v2 - Weakly Reciprocal
├── run_modelsim.bat                   # Quick Root Shortcut for ModelSim Simulation
└── README.md                          # Repository Documentation
```

---

## Simulation & Reproduction

### Prerequisites
* Mentor Graphics ModelSim / QuestaSim (FPGA Edition 2020.1 or compatible).
* Intel Quartus Prime Standard Edition 22.1std.

### Running Testbenches in ModelSim GUI
1. Open ModelSim and set the working directory to `sim`:
   ```tcl
   cd sim
   ```
2. Execute the automated regression test script:
   ```tcl
   do run_sim.do
   ```
3. To view the Store-to-Load Forwarding (STLF) wave analysis:
   ```tcl
   do wave_paper_read_stlf.do
   ```

### Command-Line Execution (Windows)
Run the automated batch script directly:
```cmd
cd sim
run_simulations.bat
```
Or execute `run_modelsim.bat` from the repository root.

---

## Authors & Academic Citation

* **Lead Researcher & Hardware Architect:** Eng. Mohammed Adel Gweaa (`m.ghawia@uot.edu.ly`)
* **Academic Supervisor:** Dr. Mohamed Muftah Eljhani
* **Institution:** Department of Computer Engineering, Faculty of Engineering, University of Tripoli, Tripoli, Libya.

To cite this repository in academic publications:

```bibtex
@misc{gweaa2026compressedcache,
  author       = {Mohammed Adel Gweaa and Mohamed Muftah Eljhani},
  title        = {A Pipelined Compressed Cache Architecture with Runtime Reconfigurable Control for FPGA Platforms},
  year         = {2026},
  howpublished = {\url{https://github.com/mohammed-gweaa/compressed-cache-fpga}},
  institution  = {University of Tripoli, Faculty of Engineering}
}
```

---

## Licence

This hardware architecture and associated verification sources are released under the **CERN Open Hardware Licence Version 2 - Weakly Reciprocal ([CERN-OHL-W-2.0](LICENSE))**.
