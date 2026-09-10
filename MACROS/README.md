# Subsystem Macros

This directory contains ASIC hard macro models, simulation blackboxes, and behavioral collaterals for the eFPGA Subsystem and associated SoC components.

## Directory Structure

* **`FABulous/`**: Hard macro interface wrapper and simulation models for the reconfigurable eFPGA fabric core.
* **`NPU_core/`**: Hard macro model for the systolic array compute core, including the systolic matrix engine, accumulation registers, and requantizer pipeline.
* **`SRAM/`**: ASIC SRAM macro models and memory wrappers replacing generic behavioral arrays.

## Preprocessor Directive

When targeting ASIC synthesis or netlist simulation with hard macros instantiated, define the macro directive:

```verilog
`define ASIC_MACROS
```

This directive switches instantiation from synthesizable RTL descriptions to the dedicated ASIC macro cells across the eFPGA Subsystem wrappers.
