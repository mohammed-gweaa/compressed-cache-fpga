# Future Work and System-on-Chip (SoC) Architectural Integration Roadmap

**Author:** Mohammed Gweaa  
**Affiliation:** Department of Computer Engineering, University of Tripoli  
**Primary Target Silicon:** Intel Cyclone IV GX EP4CGX150DF31C7 & TSMC 28nm ASIC  
**Current Scope:** Standalone Production-Grade Level-2 (L2) Compressed Cache Subsystem  
**Future Scope:** Multi-Core RISC-V SoC Memory Hierarchy Deployment  

---

## 1. Architectural Scope Boundary Definition

To maintain rigorous engineering focus and deliver an industrially complete, silicon-ready intellectual property (IP) block, the primary scope of this project is strictly defined as the **Level-2 (L2) Base-Delta-Immediate Compressed Cache Subsystem** (`l2_bdi_cache_top`).

All external interface blocks, bus arbiters, Level-1 caches, CPU Wishbone interconnects, and external DRAM controllers developed and verified during this research constitute the **Future System Integration Roadmap**. These preparatory modules are fully documented herein to facilitate the transition from an isolated L2 IP into a complete multicore System-on-Chip.

```
+=============================================================================+
|                      SOC ARCHITECTURAL SCOPE SEPARATION                     |
+=============================================================================+
|                                                                             |
|  [FUTURE WORK: SYSTEM INTEGRATION ROADMAP]                                  |
|  ┌───────────────────┐               ┌───────────────────┐                  |
|  │ RISC-V Core LSU   │               │ RISC-V Core IFU   │                  |
|  └─────────┬─────────┘               └─────────┬─────────┘                  |
|            │ Wishbone B4 (32-bit)              │ Burst Refill (256-bit)     |
|            ▼                                   ▼                            |
|  ┌───────────────────┐               ┌───────────────────┐                  |
|  │ L1-D Data Cache   │               │ L1-I Inst Cache   │                  |
|  │ (l1_dcache_core)  │               │ (Inst Refill)     │                  |
|  └─────────┬─────────┘               └─────────┬─────────┘                  |
|            │ 256-bit Line                      │ 256-bit Line               |
|            └─────────────────┬─────────────────┘                            |
|                              ▼                                              |
|                 ┌──────────────────────────┐                                |
|                 │ Upstream Bus Arbiter     │                                |
|                 │ (l1_l2_bus_arbiter)      │                                |
|                 └────────────┬─────────────┘                                |
|                              │ 256-bit Request / Grant                      |
| =============================╪============================================= |
|                              ▼                                              |
|  [CURRENT PRIMARY SCOPE: STANDALONE L2 CACHE IP SUBSYSTEM]                  |
|  ┌───────────────────────────────────────────────────────────────────────┐  |
|  │ Level-2 Bus Adapter & Memory Manager (l2_cache_controller)            │  |
|  │ ┌───────────────────────────────────────────────────────────────────┐ │  |
|  │ │ Core L2 Compressed Storage Array (l2_bdi_cache_top)               │ │  |
|  │ │ ├── Store-to-Load Forwarding RAW Bypass (STLF)                    │ │  |
|  │ │ ├── 4-Stage Balanced Retimed Compressor (l2_bdi_compressor)       │ │  |
|  │ │ ├── Single-Cycle Combinational Decompressor (l2_bdi_decompressor) │ │  |
|  │ │ ├── Dual Sub-Block Synchronous M9K Array (l2_cache_storage_array) │ │  |
|  │ │ ├── Dynamic Epoch Associativity Governor (l2_adaptive_power_gov)  │ │  |
|  │ │ └── Memory-Mapped OS CSR Telemetry Bank (l2_csr_control_bank)     │ │  |
|  │ └───────────────────────────────────────────────────────────────────┘ │  |
|  └───────────────────────────┬───────────────────────────────────────────┘  |
| =============================╪============================================= |
|                              │ 256-bit DRAM Burst Burst Interface           |
|                              ▼                                              |
|  [FUTURE WORK: EXTERNAL MEMORY SUBSYSTEM]                                   |
|  ┌───────────────────────────────────────────────────────────────────────┐  |
|  │ High-Bandwidth DDR3 / DDR4 External DRAM Memory Controller            │  |
|  └───────────────────────────────────────────────────────────────────────┘  |
+=============================================================================+
```

---

## 2. Preparatory System Modules Completed for Future Integration

The following modules have been designed, coded, and functionally verified in ModelSim to serve as the turnkey foundation for future SoC integration:

### 2.1 Level-1 Data Cache (`l1_dcache_core.v`)
* **Function:** 4-way set-associative 4 KB Level-1 Data Cache interfacing directly with the CPU Load-Store Unit via Wishbone B4.
* **Architectural Features:**
  - **Single-Cycle Hit Latency:** Synchronous tag comparison and data multiplexing delivers 32-bit load data in 1 clock cycle.
  - **Byte-Granular Stores:** 4-bit byte-enable decoding (`cpu_d_sel_i`) allows byte (`SB`), half-word (`SH`), and word (`SW`) writes without stalling.
  - **Write-Back Policy:** Eliminates off-core bus traffic on hits by marking modified words in a set dirty register.
  - **Line-Granular Eviction:** When a dirty line is replaced, L1 evicts the complete 256-bit line to L2, completely solving the sub-word Read-Modify-Write problem at the L2 boundary.

### 2.2 Upstream Multi-Port Arbiter (`l1_l2_bus_arbiter.v`)
* **Function:** High-throughput bus arbiter mediating between L1 Instruction refills and L1 Data write-backs/refills.
* **Architectural Features:**
  - **Instruction Priority Scheduling:** Prioritizes L1-I transactions to prevent instruction starvation and pipeline stalling.
  - **Atomic Transaction Locking:** Locks the bus grant until the 256-bit transfer completes, preventing interleaved packet corruption.
  - **Demultiplexed Return Paths:** Directs L2 responses strictly to the requesting master.

### 2.3 Top-Level SoC Integration Wrapper (`soc_cache_subsystem.v`)
* **Function:** Top-level structural integration binding CPU Wishbone, L1-D, L1-I, Arbiter, L2, CSR bank, and external DRAM ports into a unified silicon-proven hierarchy.
* **Verification Status:** Verified with 100% data coherency across 250+ randomized load/store stress transactions in [`tb_soc_cache_random_fuzz.v`](../future_work/tb/tb_soc_cache_random_fuzz.v).

---

## 3. Future Research & Development Vectors

### 3.1 Multi-Core Coherency Extension (Directory-Based MESI/MOESI)
* **Objective:** Expand the standalone L2 cache to serve as a shared last-level cache (LLC) across 2 to 4 RISC-V cores.
* **Implementation Plan:**
  - Introduce duplicate tag directories or Bloom filters to snoop L1 invalidations.
  - Implement Dual Dirty-Bit sub-block invalidation broadcasts to prevent false sharing when two cores access different 128-bit halves of the same physical way.

### 3.2 Hardware Compressed DRAM Link (AXI5 / CHI Interface)
* **Objective:** Extend compression across the off-chip memory bus.
* **Implementation Plan:**
  - Instead of decompressing dirty lines upon eviction to DRAM, transmit the 128-bit compressed sub-block directly across an AXI5-Burst bus.
  - Halves off-chip pin toggling and reduces DRAM bus power by up to $50\%$.

### 3.3 Dynamic Entropy-Aware Profile Reconfiguration
* **Objective:** Allow software or machine-learning governors to dynamically swap compression profiles based on workload phase detection (e.g., integer database processing vs. floating-point AI inference).
