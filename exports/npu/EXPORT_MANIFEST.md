# CrocoScale IP Package: `npu`

* **Source Repository**: [CrocoScale SoC](https://github.com/NeverInControl/CrocoScale_SoC)
* **Commit**: `22f3fab`
* **Format**: `v`
* **RTL Modules**: 9 files

## Package Layout

* `npu_global.f`: Flat, standalone filelist (all paths relative to package root).
* `RTL/`: Synthesizable module sources.
* `TEST/`: Verification testbenches (4 files) and vectors (50 `.mem` files).

## Simulation Quickstart

```bash
# Compile standalone RTL using Icarus Verilog:
iverilog -g2012 -f npu_global.f -o sim.vvp
```
