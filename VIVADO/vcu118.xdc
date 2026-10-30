## ==============================================================================
## Physical & Timing Constraints for AMD/Xilinx Virtex UltraScale+ VCU118
## Target Part: xcvu9p-flga2104-2L-e (Board: xilinx.com:vcu118:part0:2.4)
## ==============================================================================

## 125 MHz Differential System Clock (Bank 64, SLR1 -> 8.000 ns period)
## MMCME4_BASE inside soc_clk_rst_gen automatically derives the 10.000 MHz sys_clk_o
create_clock -period 8.000 -name sys_clk_pin -waveform {0.000 4.000} -add [get_ports clk_p_i]

set_property PACKAGE_PIN AY24 [get_ports clk_p_i]
set_property IOSTANDARD  LVDS [get_ports clk_p_i]
set_property PACKAGE_PIN AY23 [get_ports clk_n_i]
set_property IOSTANDARD  LVDS [get_ports clk_n_i]

## Reset Pushbutton (SW5 CPU_RESET: Active-High when pressed, inverted in soc_clk_rst_gen)
set_property PACKAGE_PIN L19      [get_ports rstn_i]
set_property IOSTANDARD  LVCMOS12 [get_ports rstn_i]

## USB-UART Bridge (Silicon Labs CP2105GM U34, Bank 64, SLR1)
## FPGA TX (BB21, net USB_UART_RX) -> CP2105 RXD
set_property PACKAGE_PIN BB21     [get_ports uart0_txd_o]
set_property IOSTANDARD  LVCMOS18 [get_ports uart0_txd_o]
## FPGA RX (AW25, net USB_UART_TX) <- CP2105 TXD
set_property PACKAGE_PIN AW25     [get_ports uart0_rxd_i]
set_property IOSTANDARD  LVCMOS18 [get_ports uart0_rxd_i]

## User GPIO LEDs (DS6..DS13, Bank 67, SLR1)
set_property PACKAGE_PIN AT32     [get_ports {gpio_o[0]}]
set_property IOSTANDARD  LVCMOS12 [get_ports {gpio_o[0]}]
set_property PACKAGE_PIN AV34     [get_ports {gpio_o[1]}]
set_property IOSTANDARD  LVCMOS12 [get_ports {gpio_o[1]}]
set_property PACKAGE_PIN AY30     [get_ports {gpio_o[2]}]
set_property IOSTANDARD  LVCMOS12 [get_ports {gpio_o[2]}]
set_property PACKAGE_PIN BB32     [get_ports {gpio_o[3]}]
set_property IOSTANDARD  LVCMOS12 [get_ports {gpio_o[3]}]
set_property PACKAGE_PIN BF32     [get_ports {gpio_o[4]}]
set_property IOSTANDARD  LVCMOS12 [get_ports {gpio_o[4]}]
set_property PACKAGE_PIN AU37     [get_ports {gpio_o[5]}]
set_property IOSTANDARD  LVCMOS12 [get_ports {gpio_o[5]}]
set_property PACKAGE_PIN AV36     [get_ports {gpio_o[6]}]
set_property IOSTANDARD  LVCMOS12 [get_ports {gpio_o[6]}]
set_property PACKAGE_PIN BA37     [get_ports {gpio_o[7]}]
set_property IOSTANDARD  LVCMOS12 [get_ports {gpio_o[7]}]

## Pmod Header J52 (PMOD0, Female Right-Angle: 8-bit Bidirectional eFPGA Fabric I/O, Bank 67, SLR1)
set_property PACKAGE_PIN AY14     [get_ports {ja[0]}]
set_property IOSTANDARD  LVCMOS18 [get_ports {ja[0]}]
set_property PACKAGE_PIN AY15     [get_ports {ja[1]}]
set_property IOSTANDARD  LVCMOS18 [get_ports {ja[1]}]
set_property PACKAGE_PIN AW15     [get_ports {ja[2]}]
set_property IOSTANDARD  LVCMOS18 [get_ports {ja[2]}]
set_property PACKAGE_PIN AV15     [get_ports {ja[3]}]
set_property IOSTANDARD  LVCMOS18 [get_ports {ja[3]}]
set_property PACKAGE_PIN AV16     [get_ports {ja[4]}]
set_property IOSTANDARD  LVCMOS18 [get_ports {ja[4]}]
set_property PACKAGE_PIN AU16     [get_ports {ja[5]}]
set_property IOSTANDARD  LVCMOS18 [get_ports {ja[5]}]
set_property PACKAGE_PIN AT15     [get_ports {ja[6]}]
set_property IOSTANDARD  LVCMOS18 [get_ports {ja[6]}]
set_property PACKAGE_PIN AT16     [get_ports {ja[7]}]
set_property IOSTANDARD  LVCMOS18 [get_ports {ja[7]}]

## Pmod Header J53 (PMOD1, Male Vertical: eFPGA BitBang Config s_clk on jb[0], s_data on jb[1], Bank 47)
## Note: Internal pull-downs omitted to avoid fighting onboard U42 pass-gate level translator
set_property PACKAGE_PIN N28      [get_ports {jb[0]}]
set_property IOSTANDARD  LVCMOS12 [get_ports {jb[0]}]
set_property PACKAGE_PIN M30      [get_ports {jb[1]}]
set_property IOSTANDARD  LVCMOS12 [get_ports {jb[1]}]
set_property PACKAGE_PIN N30      [get_ports {jb[2]}]
set_property IOSTANDARD  LVCMOS12 [get_ports {jb[2]}]
set_property PACKAGE_PIN P30      [get_ports {jb[3]}]
set_property IOSTANDARD  LVCMOS12 [get_ports {jb[3]}]
set_property PACKAGE_PIN P29      [get_ports {jb[4]}]
set_property IOSTANDARD  LVCMOS12 [get_ports {jb[4]}]
set_property PACKAGE_PIN L31      [get_ports {jb[5]}]
set_property IOSTANDARD  LVCMOS12 [get_ports {jb[5]}]
set_property PACKAGE_PIN M31      [get_ports {jb[6]}]
set_property IOSTANDARD  LVCMOS12 [get_ports {jb[6]}]
set_property PACKAGE_PIN R29      [get_ports {jb[7]}]
set_property IOSTANDARD  LVCMOS12 [get_ports {jb[7]}]

## Single-Chiplet (SLR1) Floorplan Constraint
## Keeps all SoC, CPU, Crossbar, NPU, and eFPGA soft-fabric logic inside SLR1 (matching Bank 64/67 I/Os)
## without restricting top-level I/O buffers (IBUF/OBUF) from binding to their package pins.
create_pblock pblock_single_slr
resize_pblock [get_pblocks pblock_single_slr] -add {SLR1}
add_cells_to_pblock [get_pblocks pblock_single_slr] [get_cells -quiet [list \
    u_crocoscale_soc/cpu_complex_inst \
    u_crocoscale_soc/axi_crossbar_inst \
    u_crocoscale_soc/ext_mem_inst \
    u_crocoscale_soc/manager_bridge \
    u_crocoscale_soc/efpga_subsystem_top_inst \
]]
add_cells_to_pblock [get_pblocks pblock_single_slr] [get_cells -quiet u_crocoscale_soc/gen_ctrl_bridges*]

## UltraScale+ Bitstream & Configuration Settings
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

