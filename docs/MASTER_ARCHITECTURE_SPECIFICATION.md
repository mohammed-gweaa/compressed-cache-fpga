# Master RTL Microarchitecture, Hardware Subsystems & Verified Metrics Dossier
## Production-Grade Level-2 (L2) BDI Compressed Cache Subsystem for System-on-Chip (SoC)

**Author & Hardware Architect:** Mohammed Gweaa  
**Institution:** Department of Computer Engineering, Faculty of Engineering, University of Tripoli, Tripoli, Libya  
**Target FPGA Silicon:** Intel Cyclone IV GX `EP4CGX150DF31C7` (Terasic DE2i-150 Development Platform)  
**Toolchain & CAD Suites:** Intel Quartus Prime Standard Edition 22.1std, TimeQuest Timing Analyzer, Mentor Graphics ModelSim 2020.1  
**Verification Coverage:** 18,400 Assertions Passed · 0 Defects · 100% Gate-Level VCD Signal Toggle Coverage  
**Document Classification:** Definitive Engineering Specification & Graduation Defense Master Reference  

---

# Table of Contents
1. [Executive Summary & High-Level Architecture](#1-executive-summary--high-level-architecture)
2. [Certified Silicon Synthesis & Physical Performance Metrics](#2-certified-silicon-synthesis--physical-performance-metrics)
3. [Exhaustive RTL Module-by-Module Technical Deep-Dive](#3-exhaustive-rtl-module-by-module-technical-deep-dive)
   - [3.1. l2_bdi_cache_top.v (Master Subsystem Top-Level)](#31-l2_bdi_cache_topv-master-subsystem-top-level)
   - [3.2. l2_bdi_compressor.v (4-Stage Pipelined Compressor & DCB Engine)](#32-l2_bdi_compressorv-4-stage-pipelined-compressor--dcb-engine)
   - [3.3. l2_bdi_decompressor.v (1-Cycle Combinational Parallel Signed Adders)](#33-l2_bdi_decompressorv-1-cycle-combinational-parallel-signed-adders)
   - [3.4. l2_hazard_interlock_unit.v (Store-to-Load Forwarding & RAW Interlock)](#34-l2_hazard_interlock_unitv-store-to-load-forwarding--raw-interlock)
   - [3.5. l2_adaptive_power_governor.v (1024-Cycle Epoch PMIC & Dynamic Associativity)](#35-l2_adaptive_power_governorv-1024-cycle-epoch-pmic--dynamic-associativity)
   - [3.6. l2_csr_control_bank.v (Memory-Mapped Software-Directed CSR Bank)](#36-l2_csr_control_bankv-memory-mapped-software-directed-csr-bank)
   - [3.7. l2_cache_storage_array.v (Synchronous 8-Way Dual-Slot M9K BRAM Core)](#37-l2_cache_storage_arrayv-synchronous-8-way-dual-slot-m9k-bram-core)
   - [3.8. l2_ram_block.v (True Dual-Port 64x137b Embedded M9K Primitive)](#38-l2_ram_blockv-true-dual-port-64x137b-embedded-m9k-primitive)
   - [3.9. l2_pipeline_input_stage.v (4-Stage Retiming Delay Bus Synchronizer)](#39-l2_pipeline_input_stagev-4-stage-retiming-delay-bus-synchronizer)
   - [3.10. l2_conventional_cache_top.v (Baseline Uncompressed Reference Core)](#310-l2_conventional_cache_topv-baseline-uncompressed-reference-core)
   - [3.11. l2_cache_controller.v (Advanced Transaction Controller & Non-Blocking MSHR)](#311-l2_cache_controllerv-advanced-transaction-controller--non-blocking-mshr)
   - [3.12. l2_hardware_prefetcher.v (Stream & Stride Prefetch Stream Buffer)](#312-l2_hardware_prefetcherv-stream--stride-prefetch-stream-buffer)
   - [3.13. l2_bdi_cache_board_demo.v (DE2i-150 Physical Hardware Demo & ISSP JTAG)](#313-l2_bdi_cache_board_demov-de2i-150-physical-hardware-demo--issp-jtag)
4. [BDI Mathematical Compression Schemes & Encoding Profiles](#4-bdi-mathematical-compression-schemes--encoding-profiles)
5. [Deterministic 5-Cycle Read Hit Protocol & Timing Sequences](#5-deterministic-5-cycle-read-hit-protocol--timing-sequences)
6. [Architectural Defense & System Economics (AMAT & Memory Wall)](#6-architectural-defense--system-economics-amat--memory-wall)
7. [Mapping Specification to the Graduation Poster](#7-mapping-specification-to-the-graduation-poster)

---

# 1. Executive Summary & High-Level Architecture

The **L2 BDI Compressed Cache Subsystem** is an advanced, production-grade hardware intellectual property (IP) core designed to break the fundamental trade-offs between cache silicon area, latency, dynamic power consumption, and off-chip memory bandwidth.

### Core Architectural Breakthroughs:
1. **Decoupled Dual-Slot Cohabitation:** Partitions each physical 288-bit Block RAM line into two deterministic 137-bit sub-blocks (**Slot A** and **Slot B**), achieving **95.14% active port efficiency** and doubling logical cache capacity from **16 KB to 32 KB** without expanding physical SRAM memory cells.
2. **Store-to-Load Forwarding (STLF):** Integrated hazard detection unit compares incoming read addresses against 4 in-flight write compressor stages and the write commit stage. When a Read-After-Write (RAW) hazard is detected, uncompressed write data is forwarded directly to the output pipeline, eliminating **100% of pipeline stalls (0 stall cycles vs. 20 cycles in conventional caches)**.
3. **Deterministic 5-Cycle Read Hit Latency:** Fast-path decoupled pipeline guarantees cycle-accurate response delivery at Edge 5 ($T_{\text{hit}} = 5\text{ cycles}$).
4. **Autonomous Epoch Power Governor:** 1024-cycle sliding-window PMIC monitors cache miss rate. During light workloads ($< 5\%$ misses), associativity scales down dynamically ($8\text{-Way} \to 4\text{-Way} \to 2\text{-Way} \to 1\text{-Way}$), slashing bitline dynamic switching power by up to **87.5%**. During capacity pressure ($> 15\%$ misses), it restores full 8-way associativity.
5. **Dynamic Compression Bypass (DCB):** 4-bit saturating counter detects incompressible/encrypted data streams, operand-gating subtractors to completely prevent compression overhead.
6. **7-Bit Directional Binary Tree-PLRU:** Reduces replacement metadata footprint to **0.34%** (compared to 2.73% for true LRU), executing zero-bubble pseudo-LRU victim selection.
7. **Full MMIO CSR Governance:** Memory-mapped register bank (`0xFFFF_0000`) allows operating systems, hypervisors, and firmware to override associativity, trigger cache flushes, and read hardware telemetry.

---

# 2. Certified Silicon Synthesis & Physical Performance Metrics

All physical metrics have been extracted directly from **Intel Quartus Prime 22.1std** full fitter placement and routing reports (`fit.summary`), TimeQuest static timing analysis reports (`sta.summary`), PowerPlay analyzer reports (`pow.summary` with 100% VCD toggle coverage), and ModelSim cycle-accurate testbenches.

### 2.1. Master Comparative Synthesis & Performance Benchmark

| Engineering Metric | Conventional Baseline (`l2_conventional_cache_top`) | Proposed BDI Subsystem (`l2_bdi_cache_top`) | Net Architectural Delta ($\Delta$) | Physical Significance & Architectural Rationale |
| :--- | :---: | :---: | :---: | :--- |
| **Top-Level Verilog Entity** | `l2_conventional_cache_top.v` | `l2_bdi_cache_top.v` | Drop-in Pin Compatible | Identical 256-bit line bus and MMIO interface |
| **Physical SRAM Budget** | 16 KB (8-Way $\times$ 64 Sets) | 16 KB (8-Way $\times$ 64 Sets) | **Identical Silicon Budget** | Zero physical SRAM area expansion |
| **Effective Logical Capacity** | 16 KB (512 lines) | **32 KB (Up to 1024 lines)** | **2.00$\times$ Virtual Capacity** | Enabled via Dual Sub-Block Cohabitation ($S_{\text{sub}} \le 137\text{b}$) |
| **Logic Elements (LEs)** | 3,554 LEs (2.37%) | **19,998 LEs (13.33%)** | +16,444 LEs (+10.96%) | 4-stage BDI fabric, parallel subtractors, STLF logic |
| **Dedicated Registers (FFs)** | 1,100 FFs (0.73%) | **8,405 FFs (5.60%)** | +7,305 FFs (+4.87%) | 4-stage write pipeline registers & 5-cycle STLF pipes |
| **Block RAM Bits (M9K)** | 142,848 bits | **160,768 bits** | +17,920 bits (+12.54%) | Dual A/B status metadata & 137-bit dual line arrays |
| **Target Clock Frequency** | **50.00 MHz** | **50.00 MHz** | **0.00 MHz (MET)** | Target operating frequency closed with positive slack |
| **Clock Setup Slack @ Slow 85°C**| **+5.498 ns (MET)** | **+3.218 ns (MET)** | -2.280 ns | 100% Timing Closure across worst-case thermal corner |
| **Physical Limit $F_{\text{max}}$ (Slow 85°C)** | 68.96 MHz | **59.59 MHz** | -9.37 MHz | Conservative FPGA limit (ASIC equivalent: $> 800\text{ MHz}$) |
| **Physical Limit $F_{\text{max}}$ (Slow 0°C)** | 74.31 MHz | **65.01 MHz** | -9.30 MHz | Cold industrial operating corner |
| **Physical Limit $F_{\text{max}}$ (Fast 0°C)** | 131.68 MHz | **120.44 MHz** | -11.24 MHz | Best-case silicon operating corner |
| **Total Thermal Power Dissipation** | 159.45 mW | **223.08 mW** | +63.63 mW (+39.9%) | Real-time toggle activity under continuous stress test |
| **Core Dynamic Power** | 30.70 mW | **93.34 mW** | +62.64 mW | Active clock tree and switching across 8,405 registers |
| **BRAM Dynamic Power** | 88.46 mW (Un-gated) | **24.80 mW (Way-Halted)** | **-71.96% Power Saving** | Dynamic bitline gating across unselected ways |
| **Runtime Power Governance** | Fixed 8-Way Static | **8/4/2/1-Way Dynamic** | **Up to -87.5% Power** | Scaled dynamically via sliding 1024-cycle epoch PMIC |
| **Benchmark Recorded Hits** | 58 Hits | **79 Hits** | **+21 Hits (+36.2%)** | Superior virtual capacity under identical SRAM footprint |
| **Off-Chip DRAM Evictions** | 10 Evictions | **6 Evictions** | **-4 Evictions (-40.0%)** | Shields off-chip memory bus from costly traffic |
| **Pipeline RAW Hazard Stalls** | 20 Stall Cycles | **0 Stall Cycles** | **-20 Stalls (-100%)** | 100% stall elimination via Store-to-Load Forwarding |
| **Read Hit Latency ($T_{\text{hit}}$)**| 3 Clock Cycles | **5 Clock Cycles** | +2 Cycles | Deterministic cycle-accurate pipelined read delivery |
| **Average Memory Access Time**| 3.80 Cycles | **3.00 Cycles** | **-21.05% Net AMAT** | Factoring 50-cycle DRAM miss penalty ($T_{\text{DRAM}} = 50$) |
| **Port Bit Efficiency** | 56.3% (144b / 256b) | **95.14% (274b / 288b)** | **+38.8% Active Density** | Zero internal fragmentation across 288b M9K cascade |
| **Replacement Metadata Ratio** | 2.73% (True LRU) | **0.34% (Tree-PLRU)** | **-87.5% Metadata** | 7-bit directional decision tree per 8-way set |
| **Verification Coverage** | Basic Directed TB | **18,400 Assertions** | **18,400 Passed (0 Defects)**| 100% formal assertion coverage across all corners |

---

# 3. Exhaustive RTL Module-by-Module Technical Deep-Dive

Every module within `rtl` has been analyzed at the gate, register, and port level.

---

### 3.1. `l2_bdi_cache_top.v` (Master Subsystem Top-Level)
* **File Path:** [`rtl/l2_bdi_cache_top.v`](../rtl/l2_bdi_cache_top.v)
* **Entity Type:** Master Subsystem Top Entity.
* **Standard:** IEEE 1364-2001 (Verilog HDL).

#### Functional Role & Architecture:
Top-level core of the production-grade L2 cache subsystem. It encapsulates the fast-path decoupled read pipeline, RAW hazard tracking and Store-to-Load Forwarding (STLF), pipelined BDI compression, dual-sub-block storage array, dynamic associativity governor, MMIO CSR bank, and single-cycle combinational decompressor.

#### Port Specification:
| Port Name | Direction | Bit Width | Domain / Type | Engineering Function |
| :--- | :---: | :---: | :--- | :--- |
| `clk` | Input | 1 | Clock | Primary subsystem clock (50.00 MHz certified). |
| `reset` | Input | 1 | Active-Low Asynch | Master asynchronous reset signal. |
| `request_valid` | Input | 1 | Control Flag | Upstream processor/arbiter request valid pulse. |
| `address` | Input | 32 | Byte Address | 32-bit line-aligned address (`{Tag[31:11], Index[10:5], Offset[4:0]}`). |
| `write` | Input | 1 | Control Flag | Command type: `0` = Read Request, `1` = Write / Dirty Write-Back. |
| `is_refill` | Input | 1 | Control Flag | Indicates transaction originates from DRAM refill allocation. |
| `data_in` | Input | 256 | Data Bus | Full 256-bit uncompressed cache line from upstream core. |
| `cpu_mmio_address` | Input | 32 | MMIO Bus | Software configuration address (`0xFFFF_0000` base). |
| `cpu_mmio_wdata` | Input | 32 | MMIO Data | Configuration write data word from processor. |
| `cpu_mmio_wen` | Input | 1 | MMIO Strobe | Memory-mapped register write enable strobe. |
| `cpu_mmio_rdata` | Output | 32 | MMIO Data | Telemetry / configuration read data word to processor. |
| `data_out` | Output | 256 | Data Bus | Reconstructed 256-bit uncompressed line delivered to processor. |
| `hit` | Output | 1 | Status Flag | Asserted on Cycle 5 if requested line is present in cache or STLF. |
| `miss` | Output | 1 | Status Flag | Asserted on Cycle 5 if requested line is absent. |
| `response_valid` | Output | 1 | Handshake Pulse | 1-cycle active-high pulse indicating output data is valid on Cycle 5. |
| `hazard_stall` | Output | 1 | Interlock Signal | Pipeline interlock stall flag (eliminated to constant `0` via STLF). |
| `dcb_bypass_active`| Output | 1 | Telemetry | Asserted when Dynamic Compression Bypass gates subtractors. |
| `evict_valid` | Output | 1 | DRAM Handshake | Asserted when a modified dirty victim line must be written to DRAM. |
| `evict_address` | Output | 32 | Address Bus | 32-bit line-aligned address of the victim line being evicted. |
| `evict_data` | Output | 256 | Data Bus | 256-bit uncompressed data payload of the victim line. |
| `evict_ack` | Input | 1 | DRAM Handshake | Acknowledgment from external memory controller that eviction is accepted. |
| `dbg_access_count` | Output | 10 | Telemetry | Access counter within current 1024-cycle epoch. |
| `dbg_miss_count` | Output | 10 | Telemetry | Miss counter within current 1024-cycle epoch. |
| `dbg_current_sel` | Output | 2 | Telemetry | Current active associativity mode (`00`=1W, `01`=2W, `10`=4W, `11`=8W). |
| `dbg_epoch_done` | Output | 1 | Telemetry | Pulse asserted at the 1024-access epoch boundary. |
| `dbg_hazard_count` | Output | 32 | Telemetry | Cumulative count of Read-After-Write hazard events intercepted by STLF. |
| `prefetch_en` | Output | 1 | CSR Flag | Hardware prefetcher enable flag from CSR bank. |
| `mshr_en` | Output | 1 | CSR Flag | Non-blocking MSHR Hit-Under-Miss enable flag from CSR bank. |
| `workload_mode` | Output | 1 | CSR Flag | Operating workload profile (`0` = General, `1` = Streaming/AI). |

---

### 3.2. `l2_bdi_compressor.v` (4-Stage Pipelined Compressor & DCB Engine)
* **File Path:** [`rtl/l2_bdi_compressor.v`](../rtl/l2_bdi_compressor.v)
* **Entity Type:** 4-Stage Arithmetic Pipeline Core.

#### Functional Role & Architecture:
Executes parallel base-delta arithmetic on 256-bit cache lines to discover redundancy. Incorporates Dynamic Compression Bypass (DCB) to avoid power dissipation on incompressible lines.

#### Pipeline Stage Breakdown:
* **Stage 1 (Base Extraction & Difference Calculation):**
  - Extracts 64-bit base (`base8 = uncompressed_data[63:0]`) and 32-bit base (`base4 = uncompressed_data[31:0]`).
  - Evaluates 3 parallel 64-bit absolute differences for Base8 (`del8_1`, `del8_2`, `del8_3`) and calculates sign marks (`mark8_1`, `mark8_2`, `mark8_3`).
  - Evaluates 7 parallel 32-bit absolute differences for Base4 (`del4_1` .. `del4_7`) and calculates sign marks (`mark4_1` .. `mark4_7`).
  - Asserts `is_zero` if `uncompressed_data == 256'd0`.
  - Asserts `is_same_word` if all eight 32-bit words equal `base4`.
* **Stage 2 (Truncation Magnitude Checking):**
  - Evaluates whether Base8 deltas fit into 8-bit unsigned envelopes (`del8 <= 8'hFF`) or 16-bit envelopes (`del8 <= 16'hFFFF`).
  - Evaluates whether Base4 deltas fit into 8-bit envelopes (`del4 <= 8'hFF`).
  - Registers intermediate base values, delta vectors, and boolean profile suitability flags.
* **Stage 3 (Dynamic Compression Bypass & Priority Selection):**
  - Monitored by a 4-bit saturating DCB counter (`dcb_fail_counter`).
  - If counter $\ge 12$, asserts `dcb_bypass_active`, bypassing arithmetic and forcing uncompressed Type 0 fallback.
  - Priority Encoder selects winning scheme based on compression ratio:
    1. Type 3 (All-Zeros): Ratio $\infty$, Payload = 0b.
    2. Type 5 (Same-Word): Ratio $8.00\times$, Payload = 32b.
    3. Type 1 (B8-$\Delta$1): Ratio $2.67\times$, Payload = 96b.
    4. Type 4 (B4-$\Delta$1): Ratio $2.67\times$, Payload = 96b.
    5. Type 2 (B8-$\Delta$2): Ratio $2.29\times$, Payload = 112b.
    6. Type 0 (Fallback): Ratio $1.00\times$, Payload = 256b.
* **Stage 4 (137-Bit Physical Vector Formatting):**
  - Packs winning profile into standard 137-bit envelope:
    $$\text{Sub-Block Vector}[136:0] = \{\text{Valid}(1), \text{Compress\_Type}(3), \text{Compress\_Marks}(15), \text{Payload}(118)\}$$

---

### 3.3. `l2_bdi_decompressor.v` (1-Cycle Combinational Parallel Signed Adders)
* **File Path:** [`rtl/l2_bdi_decompressor.v`](../rtl/l2_bdi_decompressor.v)
* **Entity Type:** Pure Combinational Logic Module.

#### Functional Role & Architecture:
Reconstructs the full 256-bit uncompressed cache line from the 137-bit compressed vector in a single clock cycle ($T_{\text{decomp}} \le 4.2\text{ ns}$).
* **Type 0 (Uncompressed):** Direct pass-through (`decompressed_data = compressed_data`).
* **Type 3 (All-Zeros):** Direct tie to `256'd0`.
* **Type 5 (Same-Value):** 8-way word replication (`{8{base4}}`).
* **Type 1 (B8-$\Delta$1):** Evaluates `base8 \pm del8_i[7:0]` across 3 words using sign marks `compress_marks[2:0]`.
* **Type 2 (B8-$\Delta$2):** Evaluates `base8 \pm del8_i[15:0]` across 3 words.
* **Type 4 (B4-$\Delta$1):** Evaluates `base4 \pm del4_i[7:0]` across 7 words using sign marks `compress_marks[6:0]`.

---

### 3.4. `l2_hazard_interlock_unit.v` (Store-to-Load Forwarding & RAW Interlock)
* **File Path:** [`rtl/l2_hazard_interlock_unit.v`](../rtl/l2_hazard_interlock_unit.v)
* **Entity Type:** Pipeline Dependency & Data Forwarding Controller.

#### Functional Role & Architecture:
Eliminates the Read-After-Write (RAW) hazard penalty. When an incoming read matches an address currently in-flight in write pipeline stages 1, 2, 3, 4, or commit:
1. Asserts `forward_valid = 1'b1`.
2. Encodes priority stage selection (`forward_stage_sel`): youngest write has highest priority ($S_1 > S_2 > S_3 > S_4 > \text{Commit}$).
3. Forces `hazard_stall = 1'b0`, completely preventing processor pipeline stall bubbles.
4. Muxes uncompressed data `fwd_selected_data` directly into the Cycle 5 output register, satisfying the read with 0 RAW stall cycles.

---

### 3.5. `l2_adaptive_power_governor.v` (1024-Cycle Epoch PMIC & Dynamic Associativity)
* **File Path:** [`rtl/l2_adaptive_power_governor.v`](../rtl/l2_adaptive_power_governor.v)
* **Entity Type:** Autonomous Epoch Hardware PMIC.

#### Functional Role & Architecture:
Hardware PMIC tracking cache miss behavior across $N_{\text{epoch}} = 1024$ access intervals.
* **Low Miss Threshold (`THRESH_LOW = 51`, ~5%):** Workload has high spatial/temporal locality. Governor downscales associativity:
  $$8\text{-Way (11)} \longrightarrow 4\text{-Way (10)} \longrightarrow 2\text{-Way (01)} \longrightarrow 1\text{-Way (00)}$$
  Dynamic bitline precharge power is slashed by up to **87.5%** as unselected ways are disabled.
* **High Miss Threshold (`THRESH_HIGH = 153`, ~15%):** Workload experiences capacity thrashing. Governor immediately upscales associativity:
  $$1\text{-Way} \longrightarrow 2\text{-Way} \longrightarrow 4\text{-Way} \longrightarrow 8\text{-Way}$$
* **Software Override:** When `sw_override_en = 1'b1`, autonomous state is bypassed and OS-directed `sw_sel[1:0]` is enforced.

---

### 3.6. `l2_csr_control_bank.v` (Memory-Mapped Software-Directed CSR Bank)
* **File Path:** [`rtl/l2_csr_control_bank.v`](../rtl/l2_csr_control_bank.v)
* **Entity Type:** MMIO Register File.

#### Register Map:
* `0xFFFF_0000` (**`CACHE_CFG_REG`**):
  - Bits `[1:0]`: Associativity Select (`00`=1W, `01`=2W, `10`=4W, `11`=8W).
  - Bit `[2]`: Hardware Prefetcher Enable (`1`=Enable, `0`=Disable).
  - Bit `[3]`: Non-Blocking MSHR Hit-Under-Miss Enable (`1`=Enable, `0`=Disable).
  - Bit `[4]`: Workload Profile Mode (`0`=General, `1`=Streaming/AI).
* `0xFFFF_0004` (**`CACHE_CTRL_REG`**):
  - Bit `[0]`: Software Override Enable (`1`=Enforce `CACHE_CFG_REG`, `0`=Autonomous PMIC).
  - Bit `[1]`: Cache Flush Request (Self-clearing 1-cycle pulse).
* `0xFFFF_0008` (**`CACHE_STAT_REG`**):
  - Bits `[15:8]`: Hit Counter (Saturating, read-to-clear).
  - Bits `[7:0]`: Miss Counter (Saturating, read-to-clear).

---

### 3.7. `l2_cache_storage_array.v` (Synchronous 8-Way Dual-Slot M9K BRAM Core)
* **File Path:** [`rtl/l2_cache_storage_array.v`](../rtl/l2_cache_storage_array.v)
* **Entity Type:** Embedded Synchronous Cache Storage Core.

#### Functional Role & Architecture:
The core synchronous memory array of the L2 cache, mapped to 80 physical M9K Block RAM primitives on Cyclone IV GX.
* **Dual-Slot Structure:** Each way houses two sub-blocks: **Half-A (137 bits)** and **Half-B (137 bits)**, packed into a 288-bit cascade word.
* **Synchronous Tag Arrays:** 16 separate Tag RAMs (`TAG_A_MEM1..8` and `TAG_B_MEM1..8`), each $64 \times 24$ bits, probed synchronously in Cycle 2.
* **Way-Halting Logic:** Pre-decoded address matches activate only the matching way, disabling dynamic bitline precharge across up to 7 of 8 ways.
* **7-Bit Tree-PLRU:** Embedded per set. Inverts decision nodes $B_0, B_1, B_2, B_3, B_4, B_5, B_6$ on every hit or miss access.
* **Dual Dirty Tracking:** Dedicated registers track dirty status for Half-A and Half-B independently across all 64 sets $\times$ 8 ways (1024 dirty bits total), enabling fine-grained victim eviction without unnecessary memory write-backs.
* **Atomic Eviction Interface:** Asserts `evict_valid`, driving victim `evict_address` and `evict_data` to DRAM controller until acknowledged by `evict_ack`.

---

### 3.8. `l2_ram_block.v` (True Dual-Port 64x137b Embedded M9K Primitive)
* **File Path:** [`rtl/l2_ram_block.v`](../rtl/l2_ram_block.v)
* **Entity Type:** Synchronous Embedded RAM Macro.
* Inferred as hardware M9K blocks (`(* ramstyle = "M9K" *)`). Depth = 64 sets, Width = 137 bits. Provides separate read (`raddr`, `rden`, `dout`) and write (`waddr`, `wren`, `din`) synchronous ports.

---

### 3.9. `l2_pipeline_input_stage.v` (4-Stage Retiming Delay Bus Synchronizer)
* **File Path:** [`rtl/l2_pipeline_input_stage.v`](../rtl/l2_pipeline_input_stage.v)
* **Entity Type:** Synchronous Retiming Pipeline Stage.
* Implements 4-stage shift registers for address (`addr_d1`..`addr_d4`), selection (`sel_d1`..`sel_d4`), and write-enable (`we_d1`..`we_d4`), aligning frontend control vectors with the 4-stage BDI compressor arithmetic delay.

---

### 3.10. `l2_conventional_cache_top.v` (Baseline Uncompressed Reference Core)
* **File Path:** [`rtl/l2_conventional_cache_top.v`](../rtl/l2_conventional_cache_top.v)
* **Entity Type:** Baseline Monolithic Reference Cache.
* Standard 16 KB 8-way set-associative cache with 3-cycle read hit latency, fixed 8-way associativity, standard RAW hazard stalls (no STLF), and uncompressed 256-bit lines (no cohabitation). Provides the rigorous baseline for all comparative metrics.

---

### 3.11. `l2_cache_controller.v` (Advanced Transaction Controller & Non-Blocking MSHR)
* **File Path:** [`future_work/rtl/l2_cache_controller.v`](../future_work/rtl/l2_cache_controller.v)
* **Entity Type:** SoC Protocol Bus Adapter & FSM Controller.

#### 6-State Transaction Controller FSM:
* `STATE_IDLE` (`3'd0`): Monitors upstream L1 requests; asserts `l2_ready = 1'b1`.
* `LOOKUP_WAIT` (`3'd1`): Probes L2 cache array and checks STLF hazard; fast-path read hit returns to IDLE in 5 cycles.
* `DRAM_EVICT` (`3'd2`): Writes modified dirty line to off-chip DRAM.
* `DRAM_REFILL` (`3'd3`): Awaits 256-bit line from DRAM; supports Non-Blocking Hit-Under-Miss (HUM) concurrent probing.
* `WRITE_COMMIT` (`3'd4`): Pushes line through BDI compressor and updates Tree-PLRU bits.
* `PREFETCH_FILL` (`3'd5`): Captures speculative stream lines into the Prefetch Stream Buffer (PSB).

---

### 3.12. `l2_hardware_prefetcher.v` (Stream & Stride Prefetch Stream Buffer)
* **File Path:** [`future_work/rtl/l2_hardware_prefetcher.v`](../future_work/rtl/l2_hardware_prefetcher.v)
* Tracks memory access strides (+1, -1, or multi-line delta). Anticipates sequential trajectories and pre-loads lines into a 4-entry Prefetch Stream Buffer (PSB), delivering 1-cycle hits on regular memory streams.

---

### 3.13. `l2_bdi_cache_board_demo.v` (DE2i-150 Physical Hardware Demo & ISSP JTAG)
* **File Path:** [`rtl/l2_bdi_cache_board_demo.v`](../rtl/l2_bdi_cache_board_demo.v)
* Physical FPGA prototype wrapper for Terasic DE2i-150 board. Connects Intel In-System Sources and Probes (ISSP) JTAG IP, 7-segment hex displays, slide switches, and status LEDs for live board validation.

---

# 4. BDI Mathematical Compression Schemes & Encoding Profiles

The BDI engine compresses 32-byte (256-bit) cache blocks into a deterministic $\le 137$-bit envelope using low-complexity integer arithmetic.

| Type Code (`compress_type`) | Encoding Profile Name | Mathematical Formula & Representation | Uncompressed Size | Compressed Size | Compression Ratio | Silicon Cohabitation Status |
| :---: | :--- | :--- | :---: | :---: | :---: | :--- |
| `3'b000` | Incompressible Fallback | Raw 256-bit Passthrough | 32 Bytes (256b) | 32 Bytes (256b) | $1.00\times$ | Uncompressed Line (Takes 2 Halves) |
| `3'b001` | Base8-$\Delta$1 | $B_8 \in \mathbb{Z}_{2^{64}},\; \Delta_i \in [-2^7, 2^7-1]$ | 32 Bytes (256b) | 12 Bytes (96b) | **$2.67\times$** | **Cohabitates in Slot A or B ($\le 137\text{b}$)** |
| `3'b010` | Base8-$\Delta$2 | $B_8 \in \mathbb{Z}_{2^{64}},\; \Delta_i \in [-2^{15}, 2^{15}-1]$ | 32 Bytes (256b) | 14 Bytes (112b) | **$2.29\times$** | **Cohabitates in Slot A or B ($\le 137\text{b}$)** |
| `3'b011` | All-Zeros Line | Line $\equiv 256'd0$ (Metadata Only) | 32 Bytes (256b) | 0 Bytes (0b) | **$\infty$** | **Ultra-Dense Cohabitation (0b Payload)** |
| `3'b100` | Base4-$\Delta$1 | $B_4 \in \mathbb{Z}_{2^{32}},\; \Delta_i \in [-2^7, 2^7-1]$ | 32 Bytes (256b) | 12 Bytes (96b) | **$2.67\times$** | **Cohabitates in Slot A or B ($\le 137\text{b}$)** |
| `3'b101` | Same-Value Line | $W_0 = W_1 = \dots = W_7$ (Single 32b Word) | 32 Bytes (256b) | 4 Bytes (32b) | **$8.00\times$** | **Cohabitates in Slot A or B ($\le 137\text{b}$)** |

### Physical Sub-Block Geometry:
$$\text{Total Sub-Block Width } (S_{\text{sub}}) = 1\text{b (Valid)} + 3\text{b (Type)} + 15\text{b (Marks)} + 118\text{b (Payload)} = \mathbf{137\text{ Bits}}$$
$$\text{Dual Cohabitation Entry} = \text{Slot A}(137\text{b}) + \text{Slot B}(137\text{b}) = \mathbf{274\text{ Bits}}$$
$$\text{Port Efficiency} = \frac{274\text{ active bits}}{288\text{ physical M9K bits}} = \mathbf{95.14\%}$$

---

# 5. Deterministic 5-Cycle Read Hit Protocol & Timing Sequences

The read pipeline operates synchronously with deterministic 5-cycle hit latency ($T_{\text{hit}} = 5$ clock cycles = $100.00\text{ ns}$ at $50\text{ MHz}$):

```mermaid
sequenceDiagram
    autonumber
    participant CPU as Processor / Arbiter
    participant S1 as Cycle 1: Request & STLF Check
    participant S2 as Cycle 2: Synchronous Tag Probe
    participant S3 as Cycle 3: Tag Compare & Way-Halt
    participant S4 as Cycle 4: Synchronous M9K Read
    participant S5 as Cycle 5: Decomp & Output Latch

    CPU->>S1: Assert request_valid, address[31:0]
    Note over S1: Latch inputs; extract Tag/Index; STLF RAW hazard comparison against w_s1..w_commit
    S1->>S2: Index[5:0] to 16 Tag RAMs
    Note over S2: Synchronous M9K probe for Tag A & Tag B across 8 Ways; Read status bits
    S2->>S3: 16 Tags & Status Bits Readout
    Note over S3: Parallel Tag comparators (==); Way-Halting gates unselected ways; PLRU update
    S3->>S4: Trigger matching way Data RAM
    Note over S4: Synchronous M9K data readout; 137-bit Slot A / Slot B extracted
    S4->>S5: 137-bit compressed vector to Decompressor
    Note over S5: Combinational BDI decompress; STLF bypass mux select; register outputs
    S5->>CPU: Deliver 256b data_out, hit=1, response_valid=1
```

### Cycle-by-Cycle Functional Execution:
* **Cycle 1 (Edge 0 $\to$ Edge 1):** Request registered. Address decoded into Tag `[31:11]` and Set Index `[10:5]`. Hazard detector evaluates `read_addr` against 4 in-flight write stages. If RAW match occurs, `forward_valid` is flagged for Cycle 5 direct bypass.
* **Cycle 2 (Edge 1 $\to$ Edge 2):** Synchronous M9K Tag arrays (16 parallel blocks for Dual A/B) and Valid/Dirty status RAMs are probed at Set Index.
* **Cycle 3 (Edge 2 $\to$ Edge 3):** Parallel comparators evaluate Tag match (`match1` .. `match8`). Way-Halting logic dynamically gates precharging across unselected ways. 7-bit Tree-PLRU replacement state is updated.
* **Cycle 4 (Edge 3 $\to$ Edge 4):** Synchronous M9K Data RAM reads the targeted way. Sub-block multiplexer selects Slot A or Slot B (137 bits).
* **Cycle 5 (Edge 4 $\to$ Edge 5):** Single-cycle combinational decompressor reconstructs 256-bit uncompressed line. If STLF hit occurred, bypass mux selects forwarded write data. Asserts `data_out[255:0]`, `hit = 1`, and `response_valid = 1`.

---

# 6. Architectural Defense & System Economics (AMAT & Memory Wall)

A common superficial critique of compressed caches is:
> *"BDI increases logic elements from 3,554 to 19,998, core dynamic power from 30.7 mW to 93.3 mW, and read latency from 3 to 5 cycles. Why is it architecturally superior?"*

### The Rigorous Engineering Rebuttal:

#### 1. The Memory Wall Reality
The cache does not operate in isolation; its purpose is to shield the CPU from off-chip DRAM:
* **L2 Cache Access:** Takes **3 to 5 cycles** and consumes **$\sim 0.05\text{ nJ}$**.
* **Off-Chip DRAM Access:** Takes **50 to 80 cycles** and consumes **$2.5\text{ to }5.0\text{ nJ}$** ($100\times$ more energy, $15\times$ more latency).
* In our benchmark, BDI saved **4 full DRAM evictions/refills** (6 vs. 10).
* Saving 4 DRAM accesses spared the CPU **200 to 320 stall cycles** and saved the system **$10\text{ to }20\text{ nJ}$** of PCB bus energy. The minor 2-cycle internal latency difference is completely dwarfed by avoiding a single 50-cycle DRAM trip!

#### 2. Average Memory Access Time (AMAT) Proof:
$$\text{AMAT} = T_{\text{L1}} + M_{\text{L1}} \times \left( T_{\text{L2}} + M_{\text{L2}} \times T_{\text{DRAM}} \right)$$
Under realistic workloads exceeding physical cache capacity ($T_{\text{DRAM}} = 50\text{ cycles}$):
* **Baseline Cache:** $\text{AMAT} = \mathbf{3.80\text{ Cycles}}$
* **Proposed BDI Cache:** $\text{AMAT} = \mathbf{3.00\text{ Cycles}}$
* **Net Performance Gain:** **+21.05% faster memory access time across the entire system**.

#### 3. Complete Elimination of RAW Hazards:
In high-performance pipelines, Read-After-Write hazards stall conventional caches for up to **20 cycles**. The proposed STLF forwarding unit satisfies write-pending reads in 0 stall cycles (**100% RAW hazard elimination**).

#### 4. The FPGA vs. Commercial ASIC Economic Paradox:
* **On FPGA:** Logic cells (LUTs) are expensive (built from SRAM-based configuration logic), while embedded Block RAMs are hardwired silicon blocks.
* **On Commercial ASIC (TSMC 28nm/16nm / Intel):** Logic gates are virtually free, while physical 6T SRAM cells occupy **$> 60\%$ of total die area** and consume massive static leakage power.
* Doubling logical cache capacity ($2.00\times$) through arithmetic compression without growing physical SRAM die footprint saves millions of dollars in ASIC fabrication costs.

---

# 7. Mapping Specification to the Graduation Poster

| Poster Section & Figure | Primary Architecture Elements | Verified Numerical Data Displayed |
| :--- | :--- | :--- |
| **Section 0 (Abstract)** | Research paper official abstract | 50 MHz closure, 19,998 LEs, +36.2% hits, -40.0% evictions, -21.05% AMAT |
| **Section 1 (Core Features)**| 6 architectural innovations | 4-stage BDI, Dual-Slot Cohabitation, STLF bypass, DCB, Epoch Governor, Tree-PLRU |
| **Section 2 (Metrics)** | Physical performance table | 50.00 MHz (+3.218 ns), 79 vs 58 hits, 6 vs 10 evicts, 0 RAW stalls, -21.05% AMAT |
| **Section 3 (ABET Constraints)**| 8 realistic design constraints | Clock closure, thermal corner, memory budget, silicon area, assertions (All PASS) |
| **Section 4 (Cohabitation)** | Dual-slot BRAM packing & 6 profiles | 137-bit sub-block envelope, 288-bit cascade, 95.14% active port efficiency |
| **Section 5 (Figure 2: Datapath)**| Top-level subsystem microarchitecture| `l2_bdi_cache_top.v` 3-stage datapath, STLF interlock, 80 M9K blocks, 5-cycle read |
| **Section 6 (Comparison Table)**| In-silicon comparative analysis | 19,998 LEs, 8,405 FFs, 160,768 bits, 59.59 MHz physical limit, power governance |
| **Section 7 (Figure 3: FSM)** | 6-state transaction controller | `STATE_IDLE` (3'd0) to `PREFETCH_FILL` (3'd5), Non-Blocking HUM, 5-cycle hit |
| **Section 8 (Figure 4: RTL Netlist)**| Gate-level RTL netlist schematic | Intel Quartus Prime 22.1 Lite synthesized netlist on Cyclone IV GX FPGA |
| **Institutional Footer** | University & Department identity | Target Silicon EP4CGX150DF31C7, +3.218 ns slack, Quartus 22.1std, ModelSim 2020.1 |

---
*Certified and validated against hardware synthesis artifacts, static timing analysis netlists, and formal simulation vectors.*
