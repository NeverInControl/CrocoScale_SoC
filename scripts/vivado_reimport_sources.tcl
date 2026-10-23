# ==============================================================================
# CrocoScale SoC -- Vivado Clean In-Place Source Reimport & OOC Setup Script
# ==============================================================================
# Usage in Vivado Tcl Console:
#   source <path_to_repo>/scripts/vivado_reimport_sources.tcl
# ==============================================================================

set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file dirname $script_dir]

puts "=================================================================="
puts ">>> Starting CrocoScale SoC Clean Source Reimport & OOC Setup <<<"
puts "=================================================================="

# ------------------------------------------------------------------------------
# 1. Clean existing simulation sources from sim_1 (Preserves files on disk!)
# ------------------------------------------------------------------------------
puts "==> Step 1: Clearing current simulation sources from sim_1..."
set old_sim_files [get_files -quiet -of_objects [get_filesets sim_1]]
if {[llength $old_sim_files] > 0} {
    remove_files -fileset sim_1 $old_sim_files
    puts "    Removed [llength $old_sim_files] old simulation files from sim_1."
}

# ------------------------------------------------------------------------------
# 2. Clean existing design sources from sources_1 (Preserves files on disk!)
# ------------------------------------------------------------------------------
puts "==> Step 2: Clearing current design sources from sources_1..."
set old_src_files [get_files -quiet -of_objects [get_filesets sources_1]]
if {[llength $old_src_files] > 0} {
    remove_files $old_src_files
    puts "    Removed [llength $old_src_files] old design source references from sources_1."
}

# ------------------------------------------------------------------------------
# 3. Add Verilog & SystemVerilog sources from FILE_LISTS/vivado/soc_vivado.f
#    (Recursively resolves nested -f filelists directly in Tcl; zero ifdefs!)
# ------------------------------------------------------------------------------
puts "==> Step 3: Adding curated Vivado Verilog/SystemVerilog sources in-place..."

proc resolve_filelist {flist_path repo_root visited_var} {
    upvar 1 $visited_var visited
    set norm_flist [file normalize $flist_path]
    if {[lsearch -exact $visited $norm_flist] != -1 || ![file exists $norm_flist]} {
        return [list]
    }
    lappend visited $norm_flist
    set flist_dir [file dirname $norm_flist]
    set result [list]

    set fp [open $norm_flist r]
    while {[gets $fp line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string match "#*" $line] || [string match "//*" $line]} {
            continue
        }
        if {[regexp {^-[fc]\s+(\S+)} $line -> sub_rel]} {
            set cand1 [file normalize "$flist_dir/$sub_rel"]
            set cand2 [file normalize "$repo_root/FILE_LISTS/$sub_rel"]
            set cand3 [file normalize "$repo_root/$sub_rel"]
            if {[file exists $cand1]} {
                set sub_files [resolve_filelist $cand1 $repo_root visited]
            } elseif {[file exists $cand2]} {
                set sub_files [resolve_filelist $cand2 $repo_root visited]
            } else {
                set sub_files [resolve_filelist $cand3 $repo_root visited]
            }
            foreach sf $sub_files {
                if {[lsearch -exact $result $sf] == -1} {
                    lappend result $sf
                }
            }
        } else {
            set abs_path [file normalize "$repo_root/$line"]
            if {[file exists $abs_path]} {
                if {[lsearch -exact $result $abs_path] == -1} {
                    lappend result $abs_path
                }
            } else {
                puts "    WARNING: File not found on disk: $abs_path"
            }
        }
    }
    close $fp
    return $result
}

set visited_flists [list]
set v_files [resolve_filelist "$repo_root/FILE_LISTS/vivado/soc_vivado.f" $repo_root visited_flists]

if {[llength $v_files] > 0} {
    add_files -norecurse $v_files
    puts "    Added [llength $v_files] curated Verilog/SystemVerilog files from FILE_LISTS/vivado/soc_vivado.f."
}

# ------------------------------------------------------------------------------
# 4. Add NEORV32 CPU complex VHDL sources and set library to 'neorv32'
# ------------------------------------------------------------------------------
puts "==> Step 4: Adding NEORV32 VHDL sources..."
set vhdl_core [glob -nocomplain "$repo_root/RTL/CPU/core/*.vhd"]
set vhdl_boot [list \
    [file normalize "$repo_root/RTL/CPU/bootloader/neorv32_bootrom_image.vhd"] \
]
set vhdl_neorv32 [concat $vhdl_core $vhdl_boot]

if {[llength $vhdl_neorv32] > 0} {
    add_files -norecurse $vhdl_neorv32
    set_property library neorv32 [get_files $vhdl_neorv32]
    puts "    Added [llength $vhdl_neorv32] NEORV32 VHDL files with library 'neorv32'."
}

# Add NEORV32 AXI wrapper and XBUS-to-AXI4 bridge
# Both must reside in the default work library (xil_defaultlib) so 'entity work.xbus2axi4_bridge' resolves
set vhdl_bridge  [file normalize "$repo_root/RTL/CPU/system_integration/xbus2axi4_bridge.vhd"]
set vhdl_wrapper [file normalize "$repo_root/RTL/Integration/neorv32_axi_wrapper.vhd"]
set vhdl_integ   [list $vhdl_bridge $vhdl_wrapper]

if {[llength $vhdl_integ] > 0} {
    add_files -norecurse $vhdl_integ
    set_property library xil_defaultlib [get_files $vhdl_integ]
    puts "    Added NEORV32 AXI wrapper and xbus2axi4_bridge in library 'xil_defaultlib'."
}

# ------------------------------------------------------------------------------
# 5. Add Simulation Sources (Soft-Logic Controllers, Boundary Harness & TBs) to sim_1
# ------------------------------------------------------------------------------
puts "==> Step 5: Adding Soft-Logic controllers, boundary harness, and testbenches to sim_1..."
set sim_only_files [concat \
    [glob -nocomplain "$repo_root/SOFT_LOGIC/minimal/*.sv"] \
    [glob -nocomplain "$repo_root/SOFT_LOGIC/full/*.sv"] \
    [glob -nocomplain "$repo_root/SOFT_LOGIC/flex/*.sv"] \
    [glob -nocomplain "$repo_root/TEST/NPU/TestBenches/*.sv"] \
    [list \
        [file normalize "$repo_root/TEST/SoftLogic/common/efpga_boundary_harness.sv"] \
        [file normalize "$repo_root/TEST/SoftLogic/minimal/system/tb_npu_minimal_functional.sv"] \
        [file normalize "$repo_root/TEST/SoftLogic/minimal/system/tb_npu_minimal_benchmark.sv"] \
        [file normalize "$repo_root/TEST/SoftLogic/full/modules/tb_npu_full_sequencer.sv"] \
        [file normalize "$repo_root/TEST/SoftLogic/full/system/tb_npu_full_sys_functional.sv"] \
        [file normalize "$repo_root/TEST/SoftLogic/full/system/tb_npu_full_sys_3x3_benchmark.sv"] \
        [file normalize "$repo_root/TEST/SoftLogic/flex/system/tb_npu_flex_3x3_functional.sv"] \
        [file normalize "$repo_root/TEST/SoftLogic/flex/system/tb_npu_flex_3x3_crossbar_stress.sv"] \
        [file normalize "$repo_root/TEST/SoftLogic/flex/system/tb_npu_flex_3x3_benchmark.sv"] \
        [file normalize "$repo_root/TEST/eFPGA_Subsystem/TestBenches/tb_efpga_manager.sv"] \
    ] \
]
foreach sf $sim_only_files {
    if {[file exists $sf]} {
        add_files -fileset sim_1 -norecurse $sf
    }
}
puts "    Added Soft-Logic controllers, boundary harness, and all testbenches to sim_1."

# ------------------------------------------------------------------------------
# 7. Configure Top Module (Zero compiler defines required; 100% filelist-driven)
# ------------------------------------------------------------------------------
puts "==> Step 7: Configuring top module (100% filelist-driven architecture)..."
set_property verilog_define {} [get_filesets sources_1]
set_property verilog_define {} [get_filesets sim_1]
set_property top crocoscale_soc [get_filesets sources_1]
update_compile_order -fileset sources_1

# ------------------------------------------------------------------------------
# 8. Configure Dynamic Simulation MEM_DIR (Zero .mem copies in project)
# ------------------------------------------------------------------------------
puts "==> Step 8: Configuring portable simulation MEM_DIR plusarg..."
set golden_dir [file normalize "$repo_root/TEST/GoldenReference"]
set_property -dict [list xsim.simulate.xsim.more_options "-testplusarg MEM_DIR=$golden_dir"] [get_filesets sim_1]

# ------------------------------------------------------------------------------
# 9. Attach DRC Crash Prevention Hook (disable_drc.tcl)
# ------------------------------------------------------------------------------
puts "==> Step 9: Attaching DRC loop & stack overflow crash prevention hook..."
set proj_dir [get_property DIRECTORY [current_project]]
set drc_hook [file normalize "$proj_dir/disable_drc.tcl"]
if {![file exists $drc_hook]} {
    set drc_hook [file normalize "$repo_root/scripts/disable_drc.tcl"]
}

if {[file exists $drc_hook]} {
    set_property STEPS.OPT_DESIGN.TCL.PRE   $drc_hook [get_runs impl_1]
    set_property STEPS.PLACE_DESIGN.TCL.PRE $drc_hook [get_runs impl_1]
    set_property STEPS.ROUTE_DESIGN.TCL.PRE $drc_hook [get_runs impl_1]
    puts "    Attached disable_drc.tcl to OPT_DESIGN, PLACE_DESIGN, and ROUTE_DESIGN on impl_1."
} else {
    puts "    WARNING: disable_drc.tcl not found at $drc_hook!"
}

# Disable crash-prone post-opt DRC report on soft-fabric loops
catch { set_property IS_ENABLED false [get_report_configs -quiet -of_objects [get_runs impl_1] impl_1_opt_report_drc_0] }

# ------------------------------------------------------------------------------
# 10. Configure Out-Of-Context (OOC) for CPU Complex and Active FABulous Tiles
# ------------------------------------------------------------------------------
puts "==> Step 10: Configuring Out-Of-Context (OOC) modules to prevent loop overload..."

# Active modules requiring OOC isolation:
# - CPU Complex: neorv32_axi_wrapper
# - 11 Active Fabric Tiles (Note: LUT4AB was replaced by FLUT51PSDM):
set ooc_modules [list \
    neorv32_axi_wrapper \
    FLUT51PSDM \
    AXIL_S_IO_W \
    AXI_M_IO_W \
    EXT_PMOD \
    NPU_ACCUM_N \
    NPU_ACCUM_S \
    NPU_CTRL_CFG \
    NPU_SLICE \
    N_term_RAM_IO \
    SOC_DEBUG_IO \
    S_term_RAM_IO \
]

foreach mod $ooc_modules {
    if {[get_filesets -quiet $mod] eq ""} {
        if {[catch {create_fileset -blockset -define_from $mod $mod} err]} {
            puts "    \[INFO\] OOC blockset for '$mod': $err"
        } else {
            puts "    \[OK\] Configured OOC blockset for: $mod"
        }
    } else {
        puts "    \[OK\] OOC blockset '$mod' already exists."
    }
}

# Ensure xbus2axi4_bridge is present inside the neorv32_axi_wrapper OOC blockset
if {[get_filesets -quiet neorv32_axi_wrapper] ne ""} {
    set cur_block_files [get_files -quiet -of_objects [get_filesets neorv32_axi_wrapper]]
    if {[lsearch -exact $cur_block_files $vhdl_bridge] == -1} {
        add_files -fileset neorv32_axi_wrapper -norecurse $vhdl_bridge
        set_property library xil_defaultlib [get_files -of_objects [get_filesets neorv32_axi_wrapper] $vhdl_bridge]
        puts "    \[OK\] Added xbus2axi4_bridge to OOC blockset 'neorv32_axi_wrapper'."
    }
}

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "=================================================================="
puts ">>> Setup Complete! Curated sources linked with OOC & DRC hooks. <<<"
puts "=================================================================="

