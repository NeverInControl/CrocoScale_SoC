# CrocoScale IP Package: `efpga_subsystem` (`simulation`)

* **Source Repository**: [CrocoScale SoC](https://github.com/NeverInControl/CrocoScale_SoC)
* **Commit**: `6c71879`
* **Target Flow**: `simulation` (`FILE_LISTS/efpga_subsystem.f`)
* **Format**: `v`
* **RTL Modules**: 170 files in `efpga_subsystem_global.f`

## Package Layout

* `efpga_subsystem_global.f`: Flat, standalone filelist (all paths relative to package root).
* `RTL/`: Synthesizable module sources.
* `TEST/`: Verification testbenches (5 files) and golden vectors (70 `.mem` files).
* `HAL/`: C hardware abstraction layer drivers (2 files).

## Simulation / Synthesis Quickstart

```bash
# Pass external AXI library via -y <path/to/axi_lib>:
iverilog -g2012 -y <path/to/axi_lib> -f efpga_subsystem_global.f -o sim.vvp
```
