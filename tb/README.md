# Verification Testbenches & Simulation Guide

This directory contains the cycle-accurate verification testbenches for the **Level-2 Compressed Cache Subsystem**, written in IEEE 1364-2001 Verilog HDL.

---

## Directory Structure

```text
tb/
├── bdi_cache/                # Suite 1: Proposed BDI Core Functional & Hazard Testbench
│   └── tb_l2_bdi_cache_top.v # 17-Scenario Exhaustive Core Testbench
├── comparative/              # Suite 2: Head-to-Head Comparative Stress Benchmark
│   └── tb_l2_comparative_stress_benchmark.v # BDI Cache vs. Baseline Benchmark
└── paper_artifacts/          # Suite 3: Publication Waveform Capture
    └── tb_paper_journal_artifacts.v # Generates Figures 9 & 10 for Academic Publications
```

---

## 1. Suite 1: Proposed BDI Core Verification (`tb/bdi_cache/`)

### Testbench: `tb_l2_bdi_cache_top.v`
* **Target Entity:** `l2_bdi_cache_top` (Track 1 IP Core)
* **Coverage Scope:** 17 comprehensive test scenarios verifying every pipeline stage, compression mode, and hazard scenario:
  1. **Reset & Initialization:** Verification of tag array zeroing and default CSR power states.
  2. **Uncompressed Line Allocation:** Verifies fallback to uncompressed mode when compression threshold is not met.
  3. **Zero Compression:** Verifies 0-bit compression for all-zero cache lines.
  4. **Base8-Delta1 / Delta2 / Delta4:** Parallel delta extraction using 8-byte bases and 1/2/4-byte deltas.
  5. **Base4-Delta1 / Delta2:** Parallel delta extraction using 4-byte bases.
  6. **Base2-Delta1:** Parallel delta extraction using 2-byte bases.
  7. **Dual Sub-Block Cohabitation (Slot A / Slot B):** Verifies that two compressed lines share the same 288-bit physical cache line.
  8. **Deterministic 5-Cycle Read Hit Latency:** Verifies that decompressor outputs data in exactly 5 clock cycles ($T_{\text{hit}} = 5$).
  9. **Store-to-Load Forwarding (STLF):** Injects consecutive Write-then-Read operations to the exact same address, verifying zero-cycle stall forwarding ($0\text{ stalls}$).
  10. **Replacement & Eviction:** Validates Tree-PLRU eviction and writeback behavior under full cache sets.
  11. **Adaptive Power Governor:** Dynamically changes associativity masks (8-way $\rightarrow$ 4-way $\rightarrow$ 2-way $\rightarrow$ 1-way) and checks dynamic power savings.
  12. **CSR Control:** Tests MMIO reads and writes to system registers.
  13. **High-Stress Burst Traffic:** Stresses the pipeline with continuous alternating read/write bursts.

---

## 2. Suite 2: Comparative Stress Benchmark (`tb/comparative/`)

### Testbench: `tb_l2_comparative_stress_benchmark.v`
* **Target Entities:** Instantiates both `l2_bdi_cache_top` (Proposed) and `l2_conventional_cache_top` (Baseline) side-by-side in lockstep.
* **Stimulus:** Drives both architectures with the exact same pseudo-random, high-contention memory access trace (identical address sequences, hit/miss patterns, and write data).
* **Observed Metrics:**
  * **Hit Count:** 79 hits (BDI) vs 58 hits (Baseline) $\rightarrow$ **+36.2% capacity expansion**.
  * **Capacity Evictions:** 6 evictions (BDI) vs 10 evictions (Baseline) $\rightarrow$ **-40.0% DRAM access penalty reduction**.
  * **RAW Hazard Stalls:** 0 cycles (BDI via STLF) vs 20 cycles (Baseline) $\rightarrow$ **100% elimination of hazard stalls**.

---

## 3. Suite 3: Publication Waveform Generation (`tb/paper_artifacts/`)

### Testbench: `tb_paper_journal_artifacts.v`
* **Target Entity:** `l2_bdi_cache_top`
* **Objective:** Generates publication-grade, cycle-accurate `.vcd` and `.wlf` waveforms matching the exact timing diagrams in the research paper:
  * **Figure 9:** Store-to-Load Forwarding (STLF) bypass timing diagram illustrating write data forwarded directly to read output while compression is still underway.
  * **Figure 10:** 4-stage pipelined write compression timeline illustrating parallel delta computation across Stages 1 through 4.

---

## Running Testbenches via ModelSim

All testbenches are automated through `sim/run_sim.do`:

```bash
cd sim
vsim -c -do run_sim.do
```

Or on Windows:
```cmd
cd sim
run_simulations.bat
```
