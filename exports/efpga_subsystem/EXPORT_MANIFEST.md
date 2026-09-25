# CrocoScale IP Package: `efpga_subsystem`

* **Source Repository**: [CrocoScale SoC](https://github.com/NeverInControl/CrocoScale_SoC)
* **Commit**: `22f3fab`
* **Format**: `v`
* **RTL Modules**: 110 files

## Package Layout

* `efpga_subsystem_global.f`: Flat, standalone filelist (all paths relative to package root).
* `RTL/`: Synthesizable module sources.
* `HAL/`: C hardware abstraction layer drivers (2 files).

## Simulation Quickstart

```bash
# Compile standalone RTL using Icarus Verilog:
iverilog -g2012 -f efpga_subsystem_global.f -o sim.vvp
```
