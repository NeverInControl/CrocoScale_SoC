# Vivado Compilation Speedup & Interactive Debugging

Synthesizing a complete heterogeneous SoC with soft-eFPGA fabric can take anywhere from 15 minutes to well over an hour per iteration. This guide details practical techniques to slash turnaround times using intermediate checkpoints, runtime-optimized synthesis directives, and Out-Of-Context (OOC) compilation.

---

## 1. Checkpoint-Based Interactive Debugging (`.dcp`)

Rebuilding an entire SoC from scratch (Synthesis -> Opt -> Place -> Route) can take from 15 minutes to over an hour per attempt. **Do not re-synthesize from scratch when iterating on implementation.**

1. `opt_design` outputs a gate-level checkpoint at `<project>.runs/impl_1/<top>_opt.dcp`.
2. Load that checkpoint directly into an interactive Vivado session:
   ```tcl
   open_checkpoint path/to/crocoscale_soc_opt.dcp
   ```
3. Source the hook and execute placement directly:
   ```tcl
   source path/to/disable_drc.tcl
   set_case_analysis 0 [get_pins -hierarchical -filter {NAME =~ *fabric_inst*ConfigMem* && REF_PIN_NAME == Q}]
   place_design
   ```
4. Save intermediate progress:
   ```tcl
   write_checkpoint -force post_place.dcp
   ```
5. Run routing directly from memory:
   ```tcl
   route_design
   write_checkpoint -force post_route.dcp
   write_bitstream -force output.bit
   ```

---

## 2. Tool Run Strategies (`Flow_RuntimeOptimized`)

Soft-eFPGA fabrics contain massive arrays of logic elements that do not benefit from hyper-aggressive physical synthesis, because wire delays are determined dynamically at runtime by bitstream downloads rather than static tool placement.

### Implementation Strategy:
Set the implementation run to prioritize turnaround time over fine-grained timing closure:
```tcl
set_property STRATEGY Flow_RuntimeOptimized [get_runs impl_1]
```

### Placer Directives:
To prevent the placer from spending hours trying to resolve fake timing paths through switch matrices:
```tcl
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Quick [get_runs impl_1]
```

---

## 3. Out-Of-Context (OOC) Synthesis for Large Fabrics

When compiling fabrics larger than 100 tiles, top-level flat synthesis consumes excessive host RAM and redundantly re-synthesizes identical tile logic.

### Principle:
A FABulous fabric consists of repeated, identical tile blocks (`LUT4AB`, `RAM_IO`, `DSP`, `NPU_ACT_ROW`). Synthesizing these submodules Out-Of-Context isolates them:
1. Each tile type is synthesized once into an isolated `.dcp` netlist.
2. Top-level synthesis treats each tile as a black-box instantiating the cached netlist.
3. Submodule synthesis runs in parallel across multiple CPU jobs.

### Configuring OOC in Vivado:
To set a subsystem or tile block to synthesize Out-Of-Context:
```tcl
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} [get_runs <submodule>_synth_1]
```
