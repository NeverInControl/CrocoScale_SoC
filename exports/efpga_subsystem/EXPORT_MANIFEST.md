# CrocoScale IP Package: `efpga_subsystem`

* **Source Repository**: [CrocoScale SoC](https://github.com/NeverInControl/CrocoScale_SoC)
* **Commit**: `44c90f3`
* **Format**: `v`
* **RTL Modules**: 109 files

## Package Layout

* `efpga_subsystem_global.f`: Flat, standalone filelist (all paths relative to package root).
* `RTL/`: Synthesizable module sources.
* `TEST/`: Verification testbenches (1 files) and vectors (0 `.mem` files).
* `HAL/`: C hardware abstraction layer drivers (2 files).

## Simulation Quickstart

```bash
# Compile standalone RTL using Icarus Verilog:
iverilog -g2012 -f efpga_subsystem_global.f -o sim.vvp
```
