# CrocoScale IP Package: `efpga_subsystem`

* **Source Repository**: [CrocoScale SoC](https://github.com/NeverInControl/CrocoScale_SoC)
* **Commit**: `f9219cf`
* **Format**: `sv`
* **RTL Modules**: 35 files in `efpga_subsystem_global.f`

## Package Layout

* `efpga_subsystem_global.f`: Flat, standalone filelist (all paths relative to package root).
* `RTL/`: Synthesizable module sources (including `RTL/AXI_LIB/`).
* `MACROS/`: Foundry hard macro wrappers, blackbox models, and cell collaterals.
* `TEST/`: Verification testbenches (5 files) and golden vectors (70 `.mem` files).

## Simulation / Synthesis Quickstart

```bash
# Standalone compilation (AXI_LIB included in package):
iverilog -g2012 -f efpga_subsystem_global.f -o sim.vvp
```
