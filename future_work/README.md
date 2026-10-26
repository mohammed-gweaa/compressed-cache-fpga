# Multi-Core SoC Memory Hierarchy & Future Work Extensions

This directory houses future architectural models, multi-level memory subsystem components, and System-on-Chip (SoC) integration wrappers that build upon the core **Pipelined Compressed L2 Cache** IP.

---

## Architecture Overview

The multi-level memory hierarchy models a full processing cluster featuring:
* **CPU Core Interface:** Standard 32-bit Wishbone pipelined bus interface (`cpu_d_cyc`, `cpu_d_stb`, `cpu_d_we`, `cpu_d_adr`, `cpu_d_dat_w`, `cpu_d_dat_r`, `cpu_d_ack`, `cpu_d_stall`).
* **L1 Data Cache (`l1_dcache_core.v`):** 4-way set-associative 8 KB data cache with single-cycle hit latency, managing line fills and dirty writebacks.
* **L1-L2 Bus Arbiter (`l1_l2_bus_arbiter.v`):** Round-robin and priority arbitration resolving concurrent access between instruction (L1-I) and data (L1-D) streams.
* **Advanced L2 Cache Controller (`l2_cache_controller.v`):** Non-blocking transaction controller managing Miss Status Holding Registers (MSHRs), write-allocate buffers, and DRAM line fill transactions.
* **Hardware Prefetcher (`l2_hardware_prefetcher.v`):** Stream and stride prefetch engine tracking sequential access patterns to pre-load lines into the BDI cache ahead of execution.
* **Master SoC Top Entity (`soc_cache_subsystem.v`):** Structural netlist integrating the full hierarchical datapath from CPU load/store pipeline down to main memory (DRAM).

---

## Directory Organization

```text
future_work/
├── rtl/
│   ├── l1_dcache_core.v          # 4-Way 8 KB L1 Data Cache Core
│   ├── l1_l2_bus_arbiter.v       # Dual-Master Round-Robin Bus Arbiter
│   ├── l2_cache_controller.v     # Non-Blocking L2 Transaction Controller (MSHR)
│   ├── l2_hardware_prefetcher.v  # Sequential Stride Hardware Prefetcher
│   └── soc_cache_subsystem.v     # Full Hierarchy Top-Level Integration Wrapper
├── sim/
│   └── wave_soc_hierarchy.do     # ModelSim Complete Memory Hierarchy Waveform Macro
├── synth/
│   ├── soc_cache_subsystem.qpf   # Intel Quartus Prime Project File
│   ├── soc_cache_subsystem.qsf   # Quartus Settings & Module Assignments
│   ├── soc_cache_subsystem.sdc   # Synopsys Design Constraints (50 MHz Clock)
│   └── virtual_pins_soc.tcl      # Virtual Pin Constraints Script
└── tb/
    ├── tb_l2_cache_controller.v  # Dedicated Controller & MSHR Unit Testbench
    ├── tb_soc_cache_random_fuzz.v# High-Entropy Random Memory Stress & Fuzzing
    └── tb_soc_cache_subsystem.v  # End-to-End Hierarchical Integration Testbench
```

---

## Simulation & Verification

To inspect the full hierarchical transactions (CPU $\to$ L1 $\to$ Arbiter $\to$ BDI L2 $\to$ DRAM) in ModelSim:

```tcl
# In ModelSim Transcript Console:
cd future_work/sim
do wave_soc_hierarchy.do
run 50 us
```

This compiles all hierarchical modules, loads the testbench, and displays cycle-by-cycle interactions across all cache levels.

---

## FPGA Synthesis

The entire subsystem is synthesizable for Intel Cyclone IV GX (`EP4CGX150DF31C7`):
* Open `future_work/synth/soc_cache_subsystem.qpf` in **Intel Quartus Prime**.
* Run **Processing $\to$ Start Compilation** (`Ctrl + L`).
* Timing constraints and virtual pin assignments are pre-configured to measure total multi-level silicon utilization.
