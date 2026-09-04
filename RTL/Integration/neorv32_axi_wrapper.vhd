-- ================================================================================ --
-- neorv32_axi_wrapper.vhd
-- Wraps the custom NeoRV32 and XBUS-to-AXI4 bridge into a static shell for GHDL.
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;

-- Explicitly reference your library where neorv32_top lives
library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_axi_wrapper is
  port (
    -- Global Control
    clk_i         : in  std_ulogic;
    rstn_i        : in  std_ulogic; -- Active-Low
    
    -- IO
    gpio_o        : out std_ulogic_vector(31 downto 0);
    uart0_txd_o   : out std_ulogic;
    uart0_rxd_i   : in  std_ulogic;

    -- AXI4-Full Master Interface (No IDs - handled in SV)
    m_axi_awaddr  : out std_logic_vector(31 downto 0);
    m_axi_awlen   : out std_logic_vector(7 downto 0);
    m_axi_awsize  : out std_logic_vector(2 downto 0);
    m_axi_awburst : out std_logic_vector(1 downto 0);
    m_axi_awcache : out std_logic_vector(3 downto 0);
    m_axi_awprot  : out std_logic_vector(2 downto 0);
    m_axi_awvalid : out std_logic;
    m_axi_awready : in  std_logic;
    
    m_axi_wdata   : out std_logic_vector(31 downto 0);
    m_axi_wstrb   : out std_logic_vector(3 downto 0);
    m_axi_wlast   : out std_logic;
    m_axi_wvalid  : out std_logic;
    m_axi_wready  : in  std_logic;
    
    m_axi_bresp   : in  std_logic_vector(1 downto 0);
    m_axi_bvalid  : in  std_logic;
    m_axi_bready  : out std_logic;
    
    m_axi_araddr  : out std_logic_vector(31 downto 0);
    m_axi_arlen   : out std_logic_vector(7 downto 0);
    m_axi_arsize  : out std_logic_vector(2 downto 0);
    m_axi_arburst : out std_logic_vector(1 downto 0);
    m_axi_arcache : out std_logic_vector(3 downto 0);
    m_axi_arprot  : out std_logic_vector(2 downto 0);
    m_axi_arvalid : out std_logic;
    m_axi_arready : in  std_logic;
    
    m_axi_rdata   : in  std_logic_vector(31 downto 0);
    m_axi_rresp   : in  std_logic_vector(1 downto 0);
    m_axi_rlast   : in  std_logic;
    m_axi_rvalid  : in  std_logic;
    m_axi_rready  : out std_logic
  );
end entity;

architecture rtl of neorv32_axi_wrapper is

  -- Internal XBUS signals
  signal xbus_adr     : std_ulogic_vector(31 downto 0);
  signal xbus_dat_c2b : std_ulogic_vector(31 downto 0);
  signal xbus_dat_b2c : std_ulogic_vector(31 downto 0);
  signal xbus_cti     : std_ulogic_vector(2 downto 0);
  signal xbus_tag     : std_ulogic_vector(2 downto 0);
  signal xbus_sel     : std_ulogic_vector(3 downto 0);
  signal xbus_we      : std_ulogic;
  signal xbus_stb     : std_ulogic;
  signal xbus_cyc     : std_ulogic;
  signal xbus_ack     : std_ulogic;
  signal xbus_err     : std_ulogic;

begin

  -- -------------------------------------------------------------------------------------------
  -- NeoRV32 CPU Instantiation
  -- Using your exact parameters. Unmapped inputs will use the default := 'L' from your entity.
  -- -------------------------------------------------------------------------------------------
  neorv32_inst: entity neorv32.neorv32_top
  generic map (
    CLOCK_FREQUENCY  => 10_000_000, 
    BOOT_MODE_SELECT => 0,
    RISCV_ISA_C      => true,
    RISCV_ISA_M      => true,
    RISCV_ISA_Zicntr => true,
    IMEM_EN          => false,
    DMEM_EN          => false,
    XBUS_EN          => true,
    XBUS_TIMEOUT     => 255,
    IO_GPIO_NUM      => 8,
    IO_CLINT_EN      => true,
    IO_UART0_EN      => true
  )
  port map (
    clk_i       => clk_i,
    rstn_i      => rstn_i,
    
    gpio_o      => gpio_o,
    uart0_txd_o => uart0_txd_o,
    uart0_rxd_i => uart0_rxd_i,
    
    xbus_cyc_o  => xbus_cyc,
    xbus_stb_o  => xbus_stb,
    xbus_we_o   => xbus_we,
    xbus_sel_o  => xbus_sel,
    xbus_adr_o  => xbus_adr,
    xbus_dat_o  => xbus_dat_c2b,
    xbus_cti_o  => xbus_cti,
    xbus_tag_o  => xbus_tag,
    xbus_dat_i  => xbus_dat_b2c,
    xbus_ack_i  => xbus_ack,
    xbus_err_i  => xbus_err
  );

  -- -------------------------------------------------------------------------------------------
  -- XBUS to AXI4-Full Bridge
  -- -------------------------------------------------------------------------------------------
  axi_bridge_inst: entity work.xbus2axi4_bridge
  generic map (
    BURST_EN  => true,
    BURST_LEN => 4
  )
  port map (
    clk           => clk_i,
    resetn        => rstn_i,
    
    xbus_adr_i    => xbus_adr,
    xbus_dat_i    => xbus_dat_c2b,
    xbus_cti_i    => xbus_cti,      -- Wired directly to CPU
    xbus_tag_i    => xbus_tag,      -- Wired directly to CPU
    xbus_we_i     => xbus_we,
    xbus_sel_i    => xbus_sel,
    xbus_stb_i    => xbus_stb,
    xbus_ack_o    => xbus_ack,
    xbus_err_o    => xbus_err,
    xbus_dat_o    => xbus_dat_b2c,
    
    m_axi_awaddr  => m_axi_awaddr,
    m_axi_awlen   => m_axi_awlen,
    m_axi_awsize  => m_axi_awsize,
    m_axi_awburst => m_axi_awburst,
    m_axi_awcache => m_axi_awcache,
    m_axi_awprot  => m_axi_awprot,
    m_axi_awvalid => m_axi_awvalid,
    m_axi_awready => m_axi_awready,
    
    m_axi_wdata   => m_axi_wdata,
    m_axi_wstrb   => m_axi_wstrb,
    m_axi_wlast   => m_axi_wlast,
    m_axi_wvalid  => m_axi_wvalid,
    m_axi_wready  => m_axi_wready,
    
    m_axi_araddr  => m_axi_araddr,
    m_axi_arlen   => m_axi_arlen,
    m_axi_arsize  => m_axi_arsize,
    m_axi_arburst => m_axi_arburst,
    m_axi_arcache => m_axi_arcache,
    m_axi_arprot  => m_axi_arprot,
    m_axi_arvalid => m_axi_arvalid,
    m_axi_arready => m_axi_arready,
    
    m_axi_rdata   => m_axi_rdata,
    m_axi_rresp   => m_axi_rresp,
    m_axi_rlast   => m_axi_rlast,
    m_axi_rvalid  => m_axi_rvalid,
    m_axi_rready  => m_axi_rready,
    
    m_axi_bresp   => m_axi_bresp,
    m_axi_bvalid  => m_axi_bvalid,
    m_axi_bready  => m_axi_bready
  );

end architecture;