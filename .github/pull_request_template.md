## Architectural Change Summary

Please provide a concise description of the modification and its hardware rationale:
- **Target Track:** [ ] Track 1 (Proposed BDI Core) / [ ] Track 2 (Baseline) / [ ] Track 3 (Board Demo)
- **Impacted Submodules:** (e.g., `l2_bdi_compressor.v`, `l2_hazard_interlock_unit.v`)

---

## Hardware Verification & Timing Checklist

Before requesting review, ensure all checks pass:

- [ ] **ModelSim Functional Test:** Ran `sim/run_simulations.bat` $\to$ All 18 unit/benchmark tests PASSED with 0 errors.
- [ ] **Hazard Suppression:** Confirmed 0 RAW hazard stalls under STLF test cases.
- [ ] **Read Hit Latency:** Confirmed $T_{\text{hit}} = 5\text{ cycles}$ exactly.
- [ ] **Timing Closure:** Quartus Prime 22.1std TimeQuest reports positive Slack ($> +3.0\text{ ns}$) at 50.00 MHz on Cyclone IV GX (`EP4CGX150DF31C7`).
- [ ] **Pristine Core Isolation:** Verified that no board-specific logic or debug taps were added to Track 1.
