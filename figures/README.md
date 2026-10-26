# Academic Publication Figures & Waveform Artifacts

This directory contains high-resolution vector PDF figures documenting the microarchitecture, protocol flowcharts, silicon validation, and cycle-accurate waveform captures of the **Pipelined Compressed L2 Cache with Reconfigurable Control for FPGA**.

---

## Directory Catalog

| Figure Filename | Architectural Description | Reference Section in Dissertation / Paper |
| :--- | :--- | :--- |
| `fig_system_architecture.pdf` | Master L2 cache top-level system block diagram with 256-bit memory datapath, showing compressor, decompressor, STLF interlock, storage array, and power governor. | Section 1 / Chapter 3 (System Architecture) |
| `fig_bdi_pipeline.pdf` | 4-stage pipelined Base-Delta-Immediate (BDI) compression engine showing stage-by-stage delta extraction, parallel subtractors, and DCB counter. | Section 3.2 (Pipelined Compression Engine) |
| `fig_bdi_profiles_barchart.pdf` | Frequency distribution bar chart of the 8 compression profiles (Base8-$\Delta$1/2/4, Base4-$\Delta$1/2, Base2-$\Delta$1, Zero, Rep-Val). | Section 4 (BDI Encoding Profiles) |
| `fig_dual_subblock_layout.pdf` | Bit-level layout of the 288-bit physical cache line partitioned into Slot A (137 bits), Slot B (137 bits), and status/cohabitation metadata (14 bits). | Section 3.7 (Dual-Slot Cohabitation Array) |
| `fig_stlf_datapath.pdf` | Store-to-Load Forwarding (STLF) comparator logic and bypass multiplexers resolving Read-After-Write (RAW) pipeline hazards in 0 stall cycles. | Section 3.4 (Hazard Interlock Unit) |
| `fig_tree_plru.pdf` | 7-bit directional binary Tree-PLRU replacement decision tree showing victim selection and state-update traversal. | Section 3.7 (Cache Replacement Policy) |
| `fig_cache_controller_fsm.pdf` | Algorithmic State Machine (ASM) flowchart of the L2 transaction controller handling hits, misses, evictions, and writebacks. | Section 3.11 / Future Work (Cache Controller) |
| `fig_read_write_protocol_flowchart.pdf` | Cycle-accurate request servicing flowchart for pipelined read hits ($T_{\text{hit}} = 5\text{ cycles}$) and pipelined write compression. | Section 5 (Timing Sequences & Protocols) |
| `fig_comparative_results.pdf` | Comparative benchmark results (+36.2% cache hits, -40% DRAM capacity evictions, 0 pipeline stalls) vs. conventional baseline. | Section 2 (Comparative Silicon Benchmark) |
| `fig_de2i150_board_validation.pdf` | Hardware lab setup photograph and pinout validation on the Terasic DE2i-150 development board (`EP4CGX150DF31C7`). | Section 3.13 (Physical Hardware Demonstration) |
| `fig_read_stlf_waveform.pdf` | Cycle-accurate ModelSim waveform showing back-to-back RAW hazard bypass with deterministic 5-cycle read latency. | Figure 9 (Publication Artifact) |
| `fig_write_compression_waveform.pdf` | Cycle-accurate ModelSim waveform capturing 4-stage pipelined write compression with delta selection and RAM write enable. | Figure 10 (Publication Artifact) |

---

## Formats & Reproducibility

* **Vector PDF Files:** Compiled in high-resolution vector PDF format to ensure zero quality degradation when scaled for large posters (up to 2.0m x 1.5m) and IEEE/ACM journal publications.
* **In-Browser Web Renders (`figures/renders/`):** Each vector PDF has an equivalent high-resolution PNG render (180 DPI) optimized for web preview in GitHub markdown documentation and mobile devices without requiring PDF downloads.
* **Waveform Captures:** (`fig_read_stlf_waveform.pdf` and `fig_write_compression_waveform.pdf`) are captured directly from cycle-accurate simulation runs using `tb/paper_artifacts/tb_paper_journal_artifacts.v`.

