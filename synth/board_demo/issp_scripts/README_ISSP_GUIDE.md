# In-System Sources and Probes (ISSP) JTAG Automation Guide
**Target Platform:** Terasic DE2i-150 FPGA Board (Intel Cyclone IV GX `EP4CGX150DF31C7`)  
**Core Module:** `l2_bdi_cache_board_demo` (ISSP Instance Identifier: `"BDIL2"`)  
**Clock Domain:** 50.00 MHz on-board oscillator (`CLOCK_50`)

---

## 1. Overview
The **BDI L2 Cache Hardware Testbed** integrates an on-chip Intel Altera **In-System Sources and Probes (ISSP)** megafunction (`altsource_probe`). This enables real-time, non-intrusive stimulus injection and full-spectrum hardware telemetry readback across the USB-Blaster II JTAG bus without altering cache timing or inserting intrusive debug logic.

---

## 2. Signal Bus Architecture

### Source Bus (Host -> FPGA, Width: 357 Bits)
| Bit Range | Signal Name | Description |
|:---|:---|:---|
| `[255:0]` | `issp_data_in` | 256-bit write cache line payload (8 × 32-bit words) |
| `[287:256]` | `issp_address` | 32-bit physical byte memory address |
| `[288]` | `issp_write` | Write enable (`1` = Write, `0` = Read) |
| `[289]` | `issp_is_refill` | Line refill origin (`1` = DRAM refill, `0` = CPU core access) |
| `[290]` | `issp_req_toggle`| Request toggle bit (Toggles state to trigger 1-cycle edge pulse) |
| `[291]` | `issp_soft_reset_n` | Soft reset (`0` = Assert synchronous reset, `1` = Normal operation) |
| `[323:292]` | `issp_csr_addr` | 32-bit Memory-Mapped CSR address |
| `[355:324]` | `issp_csr_wdata` | 32-bit CSR write data word |
| `[356]` | `issp_csr_we` | CSR write enable strobe |

### Probe Bus (FPGA -> Host, Width: 320 Bits)
| Bit Range | Signal Name | Description |
|:---|:---|:---|
| `[255:0]` | `core_data_out` | 256-bit read data line from cache (or forwarded via STLF) |
| `[256]` | `core_hit` | Cache read hit flag |
| `[257]` | `core_miss` | Cache read miss flag |
| `[258]` | `core_resp_valid` | Response valid flag (5-cycle deterministic latency) |
| `[259]` | `core_dbg_fwd_valid` | **Store-to-Load Forwarding (STLF)** real-time zero-stall bypass active |
| `[260]` | `core_dcb_bypass` | **Dynamic Compression Bypass (DCB)** triggered by incompressible data |
| `[261]` | `core_evict_valid` | Cache line eviction in progress (dirty victim pushed to DRAM) |
| `[293:262]` | `core_evict_address` | 32-bit physical address of evicted victim line |
| `[303:294]` | `core_dbg_access` | 10-bit hardware access counter (`0..1023`) |
| `[313:304]` | `core_dbg_miss` | 10-bit hardware miss counter (`0..1023`) |
| `[315:314]` | `core_dbg_sel` | Current associativity mode (`00`=1-way, `01`=2-way, `10`=4-way, `11`=8-way) |
| `[318:316]` | `core_dbg_compress_type` | Detected BDI compression profile ID (`0..7`) |
| `[319]` | `latched_stlf_fwd` | Latched STLF forwarding event indicator |

---

## 3. Automation Scripts

### 1. `issp_signal_map.tcl`
Shared Tcl library providing:
- Hex-to-binary and binary-to-hex converters.
- 320-bit probe bitfield unpacker (`bdi_unpack_probes`).
- Academic compression profile name decoder (`bdi_decode_profile`).
- Beautiful ANSI ASCII hardware dashboard generator (`bdi_format_dashboard`).

### 2. `issp_read_telemetry.tcl`
Connects to the DE2i-150 board via USB-Blaster, samples the 320-bit probe bus, and renders the complete engineering dashboard:
```bash
quartus_stp -t issp_read_telemetry.tcl
```

### 3. `issp_inject_test_vector.tcl`
Provides an interactive stimulus injection console with high-level Tcl commands:
- `bdi_write <addr_hex> <data_hex_64chars> [is_refill]`
- `bdi_read <addr_hex>`
- `bdi_test_raw_stlf <addr_hex> <data_hex_64chars>`: Live RAW pipeline hazard & zero-stall STLF bypass test.
- `bdi_set_associativity <4_or_8>`: Dynamic runtime associativity power throttling via CSR.

### 4. `issp_automated_validation.tcl`
Full 7-step hardware regression suite running on physical silicon over JTAG:
```bash
quartus_stp -t issp_automated_validation.tcl
```
Executes:
1. Cold Read Miss check.
2. B8-D1 Compressed Refill.
3. Compressed Read Hit & Decompression Integrity.
4. Dual Sub-Block Slot B Cohabitation (+16B).
5. Live STLF RAW Hazard bypass.
6. DCB Dynamic Bypass on pseudorandom high-entropy block.
7. Runtime Associativity Scaling (8-Way -> 4-Way).

---

## 4. Running via Quartus Prime GUI
1. Open Quartus Prime Standard Edition.
2. Select **Tools** -> **In-System Sources and Probes Editor**.
3. In the JTAG hardware dropdown, select **USB-Blaster**.
4. The instance **`BDIL2`** will automatically appear with:
   - Probe Width: **320 bits**
   - Source Width: **357 bits**
5. You can view real-time binary waveforms or load the automation scripts via the Tcl Console!
