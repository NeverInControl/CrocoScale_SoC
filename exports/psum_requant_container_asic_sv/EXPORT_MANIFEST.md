# CrocoScale IP Package: `psum_requant_container` (`asic`)

* **Source Repository**: [CrocoScale SoC](https://github.com/NeverInControl/CrocoScale_SoC)
* **Commit**: `e261e76`
* **Target Flow**: `asic` (`FILE_LISTS/asic/psum_requant_container_asic.f`)
* **Format**: `sv`
* **RTL Modules**: 4 files in `psum_requant_container_global.f`

## Package Layout

* `psum_requant_container_global.f`: Flat, standalone filelist (all paths relative to package root).
* `RTL/`: Synthesizable module sources.
* `MACROS/`: Foundry hard macro wrappers, blackbox models, and cell collaterals.

## Simulation / Synthesis Quickstart

```bash
# Pass external AXI library via -y <path/to/axi_lib>:
iverilog -g2012 -y <path/to/axi_lib> -f psum_requant_container_global.f -o sim.vvp
```
