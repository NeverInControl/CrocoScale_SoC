# CrocoScale IP Package: `soc`

* **Source Repository**: [CrocoScale SoC](https://github.com/NeverInControl/CrocoScale_SoC)
* **Commit**: `a6a149c`
* **Format**: `sv`
* **RTL Modules**: 220 files

## Package Layout

* `soc_global.f`: Flat, standalone filelist (all paths relative to package root).
* `RTL/`: Synthesizable module sources.

## Simulation Quickstart

```bash
# Compile standalone RTL using Icarus Verilog:
iverilog -g2012 -f soc_global.f -o sim.vvp
```
