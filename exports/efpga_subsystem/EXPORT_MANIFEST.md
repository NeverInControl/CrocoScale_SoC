# CrocoScale IP Package: `efpga_subsystem`

* **Source Repository**: [CrocoScale SoC](https://github.com/NeverInControl/CrocoScale_SoC)
* **Commit**: `43bb750`
* **Format**: `v`
* **RTL Modules**: 109 files

## Package Layout

* `efpga_subsystem_global.f`: Flat, standalone filelist (all paths relative to package root).
* `RTL/`: Synthesizable module sources.

## Simulation Quickstart

```bash
# Compile standalone RTL using Icarus Verilog:
iverilog -g2012 -f efpga_subsystem_global.f -o sim.vvp
```
