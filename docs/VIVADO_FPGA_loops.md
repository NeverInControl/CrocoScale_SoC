# Managing Logic Loops in FABulous eFPGA under Vivado 2025.2

Unconfigured soft-eFPGA fabrics contain bidirectional routing multiplexers that form circular feedback loops across physical LUTs. This guide provides the mandatory constraints, DRC bypass hooks, and safety procedures required to place, route, and emulate FABulous on Xilinx Vivado.

---

## 1. Mandatory Timing & Routing Constraints (`efpga_loops.xdc`)

Create a new constraint file named `efpga_loops.xdc` and add the following constraints:

```tcl
# Allow combinational feedback loops on unconfigured soft-fabric wires
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets -hierarchical -filter {NAME =~ *BEG*}]

# Treat configuration latch outputs as static 0 so STA sees feed-forward paths
set_case_analysis 0 [get_pins -hierarchical -filter {NAME =~ *fabric_inst*ConfigMem* && REF_PIN_NAME == Q}]
```

### Technical Purpose:
* **`ALLOW_COMBINATORIAL_LOOPS true`**: Unprogrammed soft-eFPGA switch matrices form cyclic graphs across physical LUTs. FABulous standardizes routing output nets with `*BEG*` (e.g., `N1BEG`, `E2BEG`, `J2MID_BEG`). Applying this property stops Vivado's physical placement and routing legality checks from treating these wires as fatal layout errors.
* **`set_case_analysis 0`**: Static Timing Analysis (STA) cannot compute path delays through an unconfigured cyclic mesh. Locking the latch `Q` outputs to constant `0` forces all multiplexer select pins to `0`, collapsing switch matrices into static, single-path feed-forward trees for timing calculations. Without this, STA deadlocks or exhausts host memory computing infinite loop delays.

---

## 2. Placer Precondition Hook Script (`disable_drc.tcl`)

Before global placement begins, Vivado's `place_design` command executes an internal precondition DRC check (`report_drc -ruledeck placer_checks`). 

Checks inside this ruledeck (specifically `LCCH-1` for circular latch loops and `AVAL-*`) run recursive Depth-First Searches across the transparent configuration latches and multiplexers. This exhausts the default 1 MB Windows thread stack, causing Vivado to crash silently with a 0-byte dump (`0xC00000FD`).

Save the following script as `disable_drc.tcl` in your project directory:

```tcl
# Disable the entire placer_checks ruledeck to prevent recursive stack overflows
catch { set_property IS_ENABLED false [get_drc_checks -quiet -ruledeck placer_checks] }

# Direct overrides for default ruledeck checks if invoked outside placer_checks
catch { set_property IS_ENABLED false [get_drc_checks -quiet LUTLP-1] }
catch { set_property IS_ENABLED false [get_drc_checks -quiet LUTLP-2] }
catch { set_property IS_ENABLED false [get_drc_checks -quiet LCCH-1] }

# Instruct the C++ placer engine to bypass the precondition DRC evaluation phase
catch { set_param place.disableDrcCheck 1 }
```

### Attach Hook to Implementation:
Attach the hook script to the `PLACE_DESIGN.PRE` step so it executes automatically prior to placement:

```tcl
set_property STEPS.PLACE_DESIGN.TCL.PRE [file normalize "path/to/disable_drc.tcl"] [get_runs impl_1]
```
*(Alternatively in the GUI: **Settings** -> **Implementation** -> **place_design Options** -> set **tcl.pre** to point to `disable_drc.tcl`).*

---

## 3. Disable Redundant Post-Opt DRC Reports

Vivado automatically registers post-optimization DRC reporting (`impl_1_opt_report_drc_0`). Running a full DRC report on an unprogrammed soft-fabric causes secondary crashes:

```tcl
set_property IS_ENABLED false [get_report_configs -of_objects [get_runs impl_1] impl_1_opt_report_drc_0]
```

---

## 4. Critical Warnings, Blind Spots & Tool Risks

> [!CAUTION]
> **READ CAREFULLY BEFORE DEPLOYING THIS FLOW.**
> This configuration bypasses core safety mechanisms of Vivado's physical design engine. It creates critical blind spots where legitimate hardware errors will no longer be flagged.

### Placer Precondition DRC is Completely Blind
* **What was disabled**: The entire `placer_checks` ruledeck and the C++ placer precondition scan.
* **The Failure Mode**: Legitimate design bugs outside the eFPGA—including circular latch loops in custom controllers, unbuffered clock loads, conflicting I/O standards, or illegal cascade paths—**will no longer be detected prior to placement**.
* **Consequence**: An unintentional combinational loop or latch bug in your CPU, AXI crossbar, or peripheral logic will silently pass the precondition stage, only to manifest as corrupt hardware, routing failure, or runtime hang.

---

### Static Timing Analysis (STA) on the Fabric is a Fiction
* **What was disabled**: Dynamic timing paths through all fabric switch matrices.
* **The Failure Mode**: `set_case_analysis 0` forces Vivado to evaluate only the static `A0` input of every multiplexer. Vivado **does not and cannot analyze timing on any actual user bitstream loaded at runtime**.
* **Consequence**: The Vivado timing summary (`WNS`, `TNS`) only reflects default unconfigured state. If your user bitstream introduces a long combinational path across the fabric that fails setup/hold timing, Vivado will still report `Timing Met (WNS > 0)`. You must guarantee fabric timing externally by running the soft-fabric clock at a safely divided frequency (e.g. 10 MHz or lower).

---

### Wildcard Combinational Loop Leakage (`*BEG*`)
* **What was configured**: `ALLOW_COMBINATORIAL_LOOPS true` using wildcard `*BEG*`.
* **The Failure Mode**: If any signal or bus net outside the eFPGA contains `BEG` in its hierarchical name (e.g., `axi_burst_begin`), Vivado will quietly permit combinational loops on that net.
* **Consequence**: Real, catastrophic combinational logic loops in non-fabric RTL will not trigger `LUTLP-1` errors and will be silently routed into hardware.

---

## 5. Never Port These Constraints to ASIC Tapeout Flows

Do **not** copy `efpga_loops.xdc` or `disable_drc.tcl` into ASIC backend toolchains (OpenLane, Cadence Innovus, Synopsys ICC2).

ASIC tools use different SDC case analysis propagation rules. Disabling timing checks or setting case analysis incorrectly in an ASIC flow can result in silicon tapeout failure by masking real timing violations on critical reset and clock paths.
