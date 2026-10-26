# Simulation & Waveform Verification Guide

This directory contains the simulation scripts, batch automation, and waveform viewing configurations for Mentor Graphics / Intel ModelSim and QuestaSim.

---

## Directory Contents

```text
sim/
├── l2_cache.mpf                   # ModelSim Project File for Proposed BDI Cache Suite
├── l2_cache_conventional.mpf     # ModelSim Project File for Conventional Baseline Cache
├── run_sim.do                     # Automated compilation and regression test script (BDI Core)
├── run_sim_conventional.do        # Standalone regression test script (Conventional Baseline)
├── run_simulations.bat            # Windows batch script to run simulation in console mode
├── RUN_WAVEFORM_L2_TOP.bat        # Interactive batch launcher to start ModelSim GUI with waveforms
├── wave_l2_bdi_cache_top.do       # Hierarchical signal configuration for core testbench
├── wave_comparative_benchmark.do  # Waveform setup for side-by-side comparative benchmark
├── wave_paper_read_stlf.do        # STLF RAW hazard bypass waveform configuration (Figure 9)
├── wave_paper_write_compression.do# 4-stage pipelined compression waveform configuration (Figure 10)
└── README.md                      # This guide
```

---

## Simulation Execution Options

### 1. Automated Console Batch Mode (Fastest)
From Windows Command Prompt or PowerShell:
```cmd
cd sim
run_simulations.bat
```
* Compiles all RTL modules from `../rtl/bdi_cache/` and `../rtl/conventional_cache/`.
* Compiles all testbenches from `../tb/`.
* Sequentially executes all 3 test suites:
  1. `tb_l2_bdi_cache_top` (17 unit test scenarios - all passed).
  2. `tb_paper_journal_artifacts` (Journal timing waveform capture).
  3. `tb_l2_comparative_stress_benchmark` (Comparative benchmark vs baseline).
* Returns exit status and prints pass/fail summary.

### 2. Interactive GUI Mode with Waveforms
To open ModelSim in graphic mode with pre-configured waveform windows:
```cmd
cd sim
RUN_WAVEFORM_L2_TOP.bat
```

### 3. ModelSim GUI Command Line (Tcl Console)
Inside ModelSim:
```tcl
cd <path_to_repo>/sim
do run_sim.do
```
To view specific waveform analyses:
```tcl
# For Store-to-Load Forwarding (STLF):
do wave_paper_read_stlf.do

# For 4-Stage Pipelined Compression:
do wave_paper_write_compression.do

# For Comparative Benchmark:
do wave_comparative_benchmark.do
```

---

## Verification Assertions & Results

* **Functional Score:** 18/18 Unit & Integration Tests Passed (0 Failures, 0 Stalls).
* **Deterministic Read Latency:** Verified at exactly 5 clock cycles ($T_{\text{hit}} = 5$).
* **RAW Forwarding Bypass:** Verified at 0 stall cycles under back-to-back hazard conditions.
* **Comparative Stress Test:** Confirmed +36.2% hit rate gain and -40% DRAM capacity evictions over conventional baseline.
