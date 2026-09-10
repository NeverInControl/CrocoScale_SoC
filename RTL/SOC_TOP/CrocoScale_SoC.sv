`timescale 1ns / 1ps

module crocoscale_soc #(
    parameter int NUM_SLOTS        = 1,          // Dynamically scales Crossbar, Bridges, and eFPGA
    parameter int MEM_SIZE         = 128*1024,   
    parameter logic [31:0] HW_VERSION = 32'hFAB00001,
    parameter int AXI_ID_WIDTH     = 8
)(
    input  logic       clk_i,        
    input  logic       rstn_i,      // Raw async button
    output logic [7:0] gpio_o,      
    output logic       uart0_txd_o,
    input  logic       uart0_rxd_i  
);

    // ===========================================================================
    // Global Control & Clock Generation
    // ===========================================================================
    logic [31:0] con_gpio_out;
    assign gpio_o = con_gpio_out[7:0];
    
`ifdef VIVADO
    // Emulation clock divider (100 MHz to 10 MHz) and global clock buffer for Digilent Nexys Video
    logic [2:0] clk_div = 0;
    logic       clk_10mhz_unbuf = 0;
    logic       clk_10mhz;

    always_ff @(posedge clk_i) begin
        if (clk_div == 3'd4) begin
            clk_div         <= 0;
            clk_10mhz_unbuf <= ~clk_10mhz_unbuf;
        end else begin
            clk_div         <= clk_div + 1;
        end
    end

    BUFG clk_bufg (
        .I(clk_10mhz_unbuf),
        .O(clk_10mhz)
    );
`else
    // ASIC and Simulation: clk_i directly drives the internal system clock
    wire clk_10mhz = clk_i;
`endif

    // ===========================================================================
    // 2. Global Reset Synchronizer (Async Assert, Sync De-assert)
    // ===========================================================================
`ifdef VIVADO
    (* ASYNC_REG = "TRUE" *) logic rst_sync_0, rst_sync_1;
`else
    logic rst_sync_0, rst_sync_1;
`endif
    
    always_ff @(posedge clk_10mhz or negedge rstn_i) begin
        if (!rstn_i) begin
            rst_sync_0 <= 1'b0;
            rst_sync_1 <= 1'b0;
        end else begin
            rst_sync_0 <= 1'b1;
            rst_sync_1 <= rst_sync_0;
        end
    end

    logic sys_rstn; // Safe Active-Low 
    logic sys_rst;  // Safe Active-High 
    
    assign sys_rstn = rst_sync_1;
    assign sys_rst  = ~sys_rstn;

    // ===========================================================================
    // AXI Crossbar Sizing & Routing Map
    // ===========================================================================
    localparam int S_COUNT = 1 + NUM_SLOTS; // S0: CPU | S1..N: Fabric DMA
    localparam int M_COUNT = 2 + NUM_SLOTS; // M0: RAM | M1: Manager | M2..N: Fabric Control
    
    // Crossbar requires ID widening to route responses back to concurrent masters
    localparam int M_ID_WIDTH = AXI_ID_WIDTH + $clog2(S_COUNT); 

    function automatic logic [M_COUNT*32-1:0] get_m_base_addrs();
        logic [M_COUNT*32-1:0] map;
        map[0*32 +: 32] = 32'h00000000; // M0: RAM
        map[1*32 +: 32] = 32'h10000000; // M1: Global Manager
        for (int i = 0; i < NUM_SLOTS; i++) begin
            map[(2+i)*32 +: 32] = 32'h20000000 + (i * 32'h01000000); // M2+: Slot Controls (16MB spaced)
        end
        return map;
    endfunction

    function automatic logic [M_COUNT*32-1:0] get_m_addr_widths();
        logic [M_COUNT*32-1:0] map;
        map[0*32 +: 32] = $clog2(MEM_SIZE); // M0: RAM
        map[1*32 +: 32] = 32'd16;           // M1: Global Manager (64KB)
        for (int i = 0; i < NUM_SLOTS; i++) begin
            map[(2+i)*32 +: 32] = 32'd16;   // M2+: Slot Controls (64KB each)
        end
        return map;
    endfunction

    localparam logic [M_COUNT*32-1:0] CROSSBAR_BASE_ADDRS  = get_m_base_addrs();
    localparam logic [M_COUNT*32-1:0] CROSSBAR_ADDR_WIDTHS = get_m_addr_widths();

    // Crossbar Slave Interconnect Signals
    logic [S_COUNT*AXI_ID_WIDTH-1:0] s_axi_awid;
    logic [S_COUNT*32-1:0]           s_axi_awaddr;
    logic [S_COUNT*8-1:0]            s_axi_awlen;
    logic [S_COUNT*3-1:0]            s_axi_awsize;
    logic [S_COUNT*2-1:0]            s_axi_awburst;
    logic [S_COUNT-1:0]              s_axi_awlock;
    logic [S_COUNT*4-1:0]            s_axi_awcache;
    logic [S_COUNT*3-1:0]            s_axi_awprot;
    logic [S_COUNT-1:0]              s_axi_awvalid;
    logic [S_COUNT-1:0]              s_axi_awready;
    logic [S_COUNT*32-1:0]           s_axi_wdata;
    logic [S_COUNT*4-1:0]            s_axi_wstrb;
    logic [S_COUNT-1:0]              s_axi_wlast;
    logic [S_COUNT-1:0]              s_axi_wvalid;
    logic [S_COUNT-1:0]              s_axi_wready;
    logic [S_COUNT*AXI_ID_WIDTH-1:0] s_axi_bid;
    logic [S_COUNT*2-1:0]            s_axi_bresp;
    logic [S_COUNT-1:0]              s_axi_bvalid;
    logic [S_COUNT-1:0]              s_axi_bready;
    logic [S_COUNT*AXI_ID_WIDTH-1:0] s_axi_arid;
    logic [S_COUNT*32-1:0]           s_axi_araddr;
    logic [S_COUNT*8-1:0]            s_axi_arlen;
    logic [S_COUNT*3-1:0]            s_axi_arsize;
    logic [S_COUNT*2-1:0]            s_axi_arburst;
    logic [S_COUNT-1:0]              s_axi_arlock;
    logic [S_COUNT*4-1:0]            s_axi_arcache;
    logic [S_COUNT*3-1:0]            s_axi_arprot;
    logic [S_COUNT-1:0]              s_axi_arvalid;
    logic [S_COUNT-1:0]              s_axi_arready;
    logic [S_COUNT*AXI_ID_WIDTH-1:0] s_axi_rid;
    logic [S_COUNT*32-1:0]           s_axi_rdata;
    logic [S_COUNT*2-1:0]            s_axi_rresp;
    logic [S_COUNT-1:0]              s_axi_rlast;
    logic [S_COUNT-1:0]              s_axi_rvalid;
    logic [S_COUNT-1:0]              s_axi_rready;

    // Crossbar Master Interconnect Signals
    logic [M_COUNT*M_ID_WIDTH-1:0]   m_axi_awid;
    logic [M_COUNT*32-1:0]           m_axi_awaddr;
    logic [M_COUNT*8-1:0]            m_axi_awlen;
    logic [M_COUNT*3-1:0]            m_axi_awsize;
    logic [M_COUNT*2-1:0]            m_axi_awburst;
    logic [M_COUNT-1:0]              m_axi_awlock;
    logic [M_COUNT*4-1:0]            m_axi_awcache;
    logic [M_COUNT*3-1:0]            m_axi_awprot;
    logic [M_COUNT*4-1:0]            m_axi_awqos;
    logic [M_COUNT*4-1:0]            m_axi_awregion;
    logic [M_COUNT-1:0]              m_axi_awvalid;
    logic [M_COUNT-1:0]              m_axi_awready;
    logic [M_COUNT*32-1:0]           m_axi_wdata;
    logic [M_COUNT*4-1:0]            m_axi_wstrb;
    logic [M_COUNT-1:0]              m_axi_wlast;
    logic [M_COUNT-1:0]              m_axi_wvalid;
    logic [M_COUNT-1:0]              m_axi_wready;
    logic [M_COUNT*M_ID_WIDTH-1:0]   m_axi_bid;
    logic [M_COUNT*2-1:0]            m_axi_bresp;
    logic [M_COUNT-1:0]              m_axi_bvalid;
    logic [M_COUNT-1:0]              m_axi_bready;
    logic [M_COUNT*M_ID_WIDTH-1:0]   m_axi_arid;
    logic [M_COUNT*32-1:0]           m_axi_araddr;
    logic [M_COUNT*8-1:0]            m_axi_arlen;
    logic [M_COUNT*3-1:0]            m_axi_arsize;
    logic [M_COUNT*2-1:0]            m_axi_arburst;
    logic [M_COUNT-1:0]              m_axi_arlock;
    logic [M_COUNT*4-1:0]            m_axi_arcache;
    logic [M_COUNT*3-1:0]            m_axi_arprot;
    logic [M_COUNT*4-1:0]            m_axi_arqos;
    logic [M_COUNT*4-1:0]            m_axi_arregion;
    logic [M_COUNT-1:0]              m_axi_arvalid;
    logic [M_COUNT-1:0]              m_axi_arready;
    logic [M_COUNT*M_ID_WIDTH-1:0]   m_axi_rid;
    logic [M_COUNT*32-1:0]           m_axi_rdata;
    logic [M_COUNT*2-1:0]            m_axi_rresp;
    logic [M_COUNT-1:0]              m_axi_rlast;
    logic [M_COUNT-1:0]              m_axi_rvalid;
    logic [M_COUNT-1:0]              m_axi_rready;

    // ===========================================================================
    // Master 0: NeoRV32 CPU Complex (VHDL Blackbox via GHDL)
    // ===========================================================================
    neorv32_axi_wrapper cpu_complex_inst (
        .clk_i         (clk_10mhz),
        .rstn_i        (sys_rstn),
        .gpio_o        (con_gpio_out),
        .uart0_txd_o   (uart0_txd_o),
        .uart0_rxd_i   (uart0_rxd_i),

        .m_axi_awaddr  (s_axi_awaddr[0*32 +: 32]), 
        .m_axi_awlen   (s_axi_awlen[0*8 +: 8]),
        .m_axi_awsize  (s_axi_awsize[0*3 +: 3]),   
        .m_axi_awburst (s_axi_awburst[0*2 +: 2]),
        .m_axi_awcache (s_axi_awcache[0*4 +: 4]),
        .m_axi_awprot  (s_axi_awprot[0*3 +: 3]),   
        .m_axi_awvalid (s_axi_awvalid[0]),
        .m_axi_awready (s_axi_awready[0]),         
        .m_axi_wdata   (s_axi_wdata[0*32 +: 32]),
        .m_axi_wstrb   (s_axi_wstrb[0*4 +: 4]),    
        .m_axi_wlast   (s_axi_wlast[0]),
        .m_axi_wvalid  (s_axi_wvalid[0]),          
        .m_axi_wready  (s_axi_wready[0]),
        .m_axi_bresp   (s_axi_bresp[0*2 +: 2]),    
        .m_axi_bvalid  (s_axi_bvalid[0]),
        .m_axi_bready  (s_axi_bready[0]),          
        .m_axi_araddr  (s_axi_araddr[0*32 +: 32]),
        .m_axi_arlen   (s_axi_arlen[0*8 +: 8]),    
        .m_axi_arsize  (s_axi_arsize[0*3 +: 3]),
        .m_axi_arburst (s_axi_arburst[0*2 +: 2]),  
        .m_axi_arcache (s_axi_arcache[0*4 +: 4]),
        .m_axi_arprot  (s_axi_arprot[0*3 +: 3]),
        .m_axi_arvalid (s_axi_arvalid[0]),         
        .m_axi_arready (s_axi_arready[0]),
        .m_axi_rdata   (s_axi_rdata[0*32 +: 32]),  
        .m_axi_rresp   (s_axi_rresp[0*2 +: 2]),
        .m_axi_rlast   (s_axi_rlast[0]),           
        .m_axi_rvalid  (s_axi_rvalid[0]),
        .m_axi_rready  (s_axi_rready[0])
    );
    
    assign s_axi_awid[0*AXI_ID_WIDTH +: AXI_ID_WIDTH] = {AXI_ID_WIDTH{1'b0}};
    assign s_axi_arid[0*AXI_ID_WIDTH +: AXI_ID_WIDTH] = {AXI_ID_WIDTH{1'b0}};
    assign s_axi_awlock[0] = 1'b0;
    assign s_axi_arlock[0] = 1'b0;

    // ===========================================================================
    // Full Non-Blocking AXI4 Crossbar Interconnect
    // ===========================================================================
    axi_crossbar #(
        .S_COUNT      (S_COUNT),
        .M_COUNT      (M_COUNT),
        .DATA_WIDTH   (32),
        .ADDR_WIDTH   (32),
        .STRB_WIDTH   (4),
        .S_ID_WIDTH   (AXI_ID_WIDTH), 
        .M_ID_WIDTH   (M_ID_WIDTH),
        .M_BASE_ADDR  (CROSSBAR_BASE_ADDRS),
        .M_ADDR_WIDTH (CROSSBAR_ADDR_WIDTHS),
        .S_AW_REG_TYPE({S_COUNT{2'd1}}),
        .S_W_REG_TYPE ({S_COUNT{2'd2}}),
        .S_B_REG_TYPE ({S_COUNT{2'd1}}),
        .S_AR_REG_TYPE({S_COUNT{2'd1}}),
        .S_R_REG_TYPE ({S_COUNT{2'd2}}),
        .M_AW_REG_TYPE({M_COUNT{2'd1}}),
        .M_W_REG_TYPE ({M_COUNT{2'd2}}),
        .M_B_REG_TYPE ({M_COUNT{2'd1}}),
        .M_AR_REG_TYPE({M_COUNT{2'd1}}),
        .M_R_REG_TYPE ({M_COUNT{2'd2}})
    ) axi_crossbar_inst (
        .clk            (clk_10mhz),    
        .rst            (sys_rst), 
        
        .s_axi_awid     (s_axi_awid),    .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awlen    (s_axi_awlen),   .s_axi_awsize   (s_axi_awsize),
        .s_axi_awburst  (s_axi_awburst), .s_axi_awlock   (s_axi_awlock),
        .s_axi_awcache  (s_axi_awcache), .s_axi_awprot   (s_axi_awprot),
        .s_axi_awqos    ('0),            .s_axi_awuser   ('0),
        .s_axi_awvalid  (s_axi_awvalid), .s_axi_awready  (s_axi_awready),
        .s_axi_wdata    (s_axi_wdata),   .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wlast    (s_axi_wlast),   .s_axi_wuser    ('0),
        .s_axi_wvalid   (s_axi_wvalid),  .s_axi_wready   (s_axi_wready),
        .s_axi_bid      (s_axi_bid),     .s_axi_bresp    (s_axi_bresp),
        .s_axi_buser    (),              .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready), 
        .s_axi_arid     (s_axi_arid),    .s_axi_araddr   (s_axi_araddr),
        .s_axi_arlen    (s_axi_arlen),   .s_axi_arsize   (s_axi_arsize),
        .s_axi_arburst  (s_axi_arburst), .s_axi_arlock   (s_axi_arlock),
        .s_axi_arcache  (s_axi_arcache), .s_axi_arprot   (s_axi_arprot),
        .s_axi_arqos    ('0),            .s_axi_aruser   ('0),
        .s_axi_arvalid  (s_axi_arvalid), .s_axi_arready  (s_axi_arready),
        .s_axi_rid      (s_axi_rid),     .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),   .s_axi_rlast    (s_axi_rlast),
        .s_axi_ruser    (),              .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),
        
        .m_axi_awid     (m_axi_awid),    .m_axi_awaddr   (m_axi_awaddr),
        .m_axi_awlen    (m_axi_awlen),   .m_axi_awsize   (m_axi_awsize),
        .m_axi_awburst  (m_axi_awburst), .m_axi_awlock   (m_axi_awlock),
        .m_axi_awcache  (m_axi_awcache), .m_axi_awprot   (m_axi_awprot),
        .m_axi_awqos    (m_axi_awqos),   .m_axi_awregion (m_axi_awregion),
        .m_axi_awuser   (),
        .m_axi_awvalid  (m_axi_awvalid), .m_axi_awready  (m_axi_awready),
        .m_axi_wdata    (m_axi_wdata),   .m_axi_wstrb    (m_axi_wstrb),
        .m_axi_wlast    (m_axi_wlast),   .m_axi_wuser    (),
        .m_axi_wvalid   (m_axi_wvalid),  .m_axi_wready   (m_axi_wready), 
        .m_axi_bid      (m_axi_bid),     .m_axi_bresp    (m_axi_bresp),  
        .m_axi_buser    ('0),            .m_axi_bvalid   (m_axi_bvalid),
        .m_axi_bready   (m_axi_bready), 
        .m_axi_arid     (m_axi_arid),    .m_axi_araddr   (m_axi_araddr),
        .m_axi_arlen    (m_axi_arlen),   .m_axi_arsize   (m_axi_arsize), 
        .m_axi_arburst  (m_axi_arburst), .m_axi_arlock   (m_axi_arlock), 
        .m_axi_arcache  (m_axi_arcache), .m_axi_arprot   (m_axi_arprot), 
        .m_axi_arqos    (m_axi_arqos),   .m_axi_arregion (m_axi_arregion),
        .m_axi_aruser   (),
        .m_axi_arvalid  (m_axi_arvalid), .m_axi_arready  (m_axi_arready),
        .m_axi_rid      (m_axi_rid),     .m_axi_rdata    (m_axi_rdata),  
        .m_axi_rresp    (m_axi_rresp),   .m_axi_rlast    (m_axi_rlast),  
        .m_axi_ruser    ('0),            .m_axi_rvalid   (m_axi_rvalid),
        .m_axi_rready   (m_axi_rready)
    );

    // ===========================================================================
    // Slave 0: System RAM
    // ===========================================================================
    axi_ram #(
        .DATA_WIDTH (32), .ADDR_WIDTH ($clog2(MEM_SIZE)), .ID_WIDTH (M_ID_WIDTH) 
    ) ext_mem_inst (
        .clk            (clk_10mhz),                                .rst            (sys_rst), 
        .s_axi_awid     (m_axi_awid[0*M_ID_WIDTH +: M_ID_WIDTH]),   .s_axi_awaddr   (m_axi_awaddr[0*32 +: $clog2(MEM_SIZE)]), 
        .s_axi_awlen    (m_axi_awlen[0*8 +: 8]),                    .s_axi_awsize   (m_axi_awsize[0*3 +: 3]),
        .s_axi_awburst  (m_axi_awburst[0*2 +: 2]),                  .s_axi_awlock   (m_axi_awlock[0]),
        .s_axi_awcache  (m_axi_awcache[0*4 +: 4]),                  .s_axi_awprot   (m_axi_awprot[0*3 +: 3]),
        .s_axi_awvalid  (m_axi_awvalid[0]),                         .s_axi_awready  (m_axi_awready[0]),
        .s_axi_wdata    (m_axi_wdata[0*32 +: 32]),                  .s_axi_wstrb    (m_axi_wstrb[0*4 +: 4]),
        .s_axi_wlast    (m_axi_wlast[0]),                           .s_axi_wvalid   (m_axi_wvalid[0]),
        .s_axi_wready   (m_axi_wready[0]),                          .s_axi_bid      (m_axi_bid[0*M_ID_WIDTH +: M_ID_WIDTH]),
        .s_axi_bresp    (m_axi_bresp[0*2 +: 2]),                    .s_axi_bvalid   (m_axi_bvalid[0]),
        .s_axi_bready   (m_axi_bready[0]),                          .s_axi_arid     (m_axi_arid[0*M_ID_WIDTH +: M_ID_WIDTH]),
        .s_axi_araddr   (m_axi_araddr[0*32 +: $clog2(MEM_SIZE)]),   .s_axi_arlen    (m_axi_arlen[0*8 +: 8]),
        .s_axi_arsize   (m_axi_arsize[0*3 +: 3]),                   .s_axi_arburst  (m_axi_arburst[0*2 +: 2]),
        .s_axi_arlock   (m_axi_arlock[0]),                          .s_axi_arcache  (m_axi_arcache[0*4 +: 4]),
        .s_axi_arprot   (m_axi_arprot[0*3 +: 3]),                   .s_axi_arvalid  (m_axi_arvalid[0]),
        .s_axi_arready  (m_axi_arready[0]),                         .s_axi_rid      (m_axi_rid[0*M_ID_WIDTH +: M_ID_WIDTH]),
        .s_axi_rdata    (m_axi_rdata[0*32 +: 32]),                  .s_axi_rresp    (m_axi_rresp[0*2 +: 2]),
        .s_axi_rlast    (m_axi_rlast[0]),                           .s_axi_rvalid   (m_axi_rvalid[0]),
        .s_axi_rready   (m_axi_rready[0])
    );

    // ===========================================================================
    // Master-to-AXI-Lite Adapters (Manager M1 & Slot Control M2..N)
    // ===========================================================================
    logic [31:0]               axil_mgr_awaddr, axil_mgr_wdata, axil_mgr_araddr, axil_mgr_rdata;
    logic [3:0]                axil_mgr_wstrb; 
    logic [2:0]                axil_mgr_awprot, axil_mgr_arprot; 
    logic [1:0]                axil_mgr_bresp, axil_mgr_rresp;
    logic                      axil_mgr_awvalid, axil_mgr_awready, axil_mgr_wvalid, axil_mgr_wready, axil_mgr_bvalid, axil_mgr_bready;
    logic                      axil_mgr_arvalid, axil_mgr_arready, axil_mgr_rvalid, axil_mgr_rready;

    logic [NUM_SLOTS*32-1:0]   axil_ctrl_s_awaddr, axil_ctrl_s_wdata, axil_ctrl_s_araddr, axil_ctrl_s_rdata;
    logic [NUM_SLOTS*4-1:0]    axil_ctrl_s_wstrb; 
    logic [NUM_SLOTS*3-1:0]    axil_ctrl_s_awprot, axil_ctrl_s_arprot; 
    logic [NUM_SLOTS*2-1:0]    axil_ctrl_s_bresp, axil_ctrl_s_rresp;
    logic [NUM_SLOTS-1:0]      axil_ctrl_s_awvalid, axil_ctrl_s_awready, axil_ctrl_s_wvalid, axil_ctrl_s_wready, axil_ctrl_s_bvalid, axil_ctrl_s_bready;
    logic [NUM_SLOTS-1:0]      axil_ctrl_s_arvalid, axil_ctrl_s_arready, axil_ctrl_s_rvalid, axil_ctrl_s_rready;

    // Manager Bridge -> M1
    axi_axil_adapter #(.ADDR_WIDTH(32), .AXI_DATA_WIDTH(32), .AXIL_DATA_WIDTH(32), .AXI_ID_WIDTH(M_ID_WIDTH))
    manager_bridge (
        .clk(clk_10mhz), .rst(sys_rst), 
        .s_axi_awid(m_axi_awid[1*M_ID_WIDTH +: M_ID_WIDTH]), .s_axi_awaddr(m_axi_awaddr[1*32 +: 32]), .s_axi_awlen(m_axi_awlen[1*8 +: 8]), .s_axi_awsize(m_axi_awsize[1*3 +: 3]), .s_axi_awburst(m_axi_awburst[1*2 +: 2]), .s_axi_awlock(m_axi_awlock[1]), .s_axi_awcache(m_axi_awcache[1*4 +: 4]), .s_axi_awprot(m_axi_awprot[1*3 +: 3]), .s_axi_awvalid(m_axi_awvalid[1]), .s_axi_awready(m_axi_awready[1]), .s_axi_wdata(m_axi_wdata[1*32 +: 32]), .s_axi_wstrb(m_axi_wstrb[1*4 +: 4]), .s_axi_wlast(m_axi_wlast[1]), .s_axi_wvalid(m_axi_wvalid[1]), .s_axi_wready(m_axi_wready[1]), .s_axi_bid(m_axi_bid[1*M_ID_WIDTH +: M_ID_WIDTH]), .s_axi_bresp(m_axi_bresp[1*2 +: 2]), .s_axi_bvalid(m_axi_bvalid[1]), .s_axi_bready(m_axi_bready[1]), .s_axi_arid(m_axi_arid[1*M_ID_WIDTH +: M_ID_WIDTH]), .s_axi_araddr(m_axi_araddr[1*32 +: 32]), .s_axi_arlen(m_axi_arlen[1*8 +: 8]), .s_axi_arsize(m_axi_arsize[1*3 +: 3]), .s_axi_arburst(m_axi_arburst[1*2 +: 2]), .s_axi_arlock(m_axi_arlock[1]), .s_axi_arcache(m_axi_arcache[1*4 +: 4]), .s_axi_arprot(m_axi_arprot[1*3 +: 3]), .s_axi_arvalid(m_axi_arvalid[1]), .s_axi_arready(m_axi_arready[1]), .s_axi_rid(m_axi_rid[1*M_ID_WIDTH +: M_ID_WIDTH]), .s_axi_rdata(m_axi_rdata[1*32 +: 32]), .s_axi_rresp(m_axi_rresp[1*2 +: 2]), .s_axi_rlast(m_axi_rlast[1]), .s_axi_rvalid(m_axi_rvalid[1]), .s_axi_rready(m_axi_rready[1]),
        .m_axil_awaddr(axil_mgr_awaddr), .m_axil_awprot(axil_mgr_awprot), .m_axil_awvalid(axil_mgr_awvalid), .m_axil_awready(axil_mgr_awready), .m_axil_wdata(axil_mgr_wdata), .m_axil_wstrb(axil_mgr_wstrb), .m_axil_wvalid(axil_mgr_wvalid), .m_axil_wready(axil_mgr_wready), .m_axil_bresp(axil_mgr_bresp), .m_axil_bvalid(axil_mgr_bvalid), .m_axil_bready(axil_mgr_bready), .m_axil_araddr(axil_mgr_araddr), .m_axil_arprot(axil_mgr_arprot), .m_axil_arvalid(axil_mgr_arvalid), .m_axil_arready(axil_mgr_arready), .m_axil_rdata(axil_mgr_rdata), .m_axil_rresp(axil_mgr_rresp), .m_axil_rvalid(axil_mgr_rvalid), .m_axil_rready(axil_mgr_rready)
    );

    // Slot Control Adapters -> M2..MN
    genvar i;
    generate
        for (i = 0; i < NUM_SLOTS; i++) begin : gen_ctrl_bridges
            axi_axil_adapter #(.ADDR_WIDTH(32), .AXI_DATA_WIDTH(32), .AXIL_DATA_WIDTH(32), .AXI_ID_WIDTH(M_ID_WIDTH))
            ctrl_bridge (
                .clk(clk_10mhz), .rst(sys_rst), 
                .s_axi_awid(m_axi_awid[(2+i)*M_ID_WIDTH +: M_ID_WIDTH]), .s_axi_awaddr(m_axi_awaddr[(2+i)*32 +: 32]), .s_axi_awlen(m_axi_awlen[(2+i)*8 +: 8]), .s_axi_awsize(m_axi_awsize[(2+i)*3 +: 3]), .s_axi_awburst(m_axi_awburst[(2+i)*2 +: 2]), .s_axi_awlock(m_axi_awlock[2+i]), .s_axi_awcache(m_axi_awcache[(2+i)*4 +: 4]), .s_axi_awprot(m_axi_awprot[(2+i)*3 +: 3]), .s_axi_awvalid(m_axi_awvalid[2+i]), .s_axi_awready(m_axi_awready[2+i]), .s_axi_wdata(m_axi_wdata[(2+i)*32 +: 32]), .s_axi_wstrb(m_axi_wstrb[(2+i)*4 +: 4]), .s_axi_wlast(m_axi_wlast[2+i]), .s_axi_wvalid(m_axi_wvalid[2+i]), .s_axi_wready(m_axi_wready[2+i]), .s_axi_bid(m_axi_bid[(2+i)*M_ID_WIDTH +: M_ID_WIDTH]), .s_axi_bresp(m_axi_bresp[(2+i)*2 +: 2]), .s_axi_bvalid(m_axi_bvalid[2+i]), .s_axi_bready(m_axi_bready[2+i]), .s_axi_arid(m_axi_arid[(2+i)*M_ID_WIDTH +: M_ID_WIDTH]), .s_axi_araddr(m_axi_araddr[(2+i)*32 +: 32]), .s_axi_arlen(m_axi_arlen[(2+i)*8 +: 8]), .s_axi_arsize(m_axi_arsize[(2+i)*3 +: 3]), .s_axi_arburst(m_axi_arburst[(2+i)*2 +: 2]), .s_axi_arlock(m_axi_arlock[2+i]), .s_axi_arcache(m_axi_arcache[(2+i)*4 +: 4]), .s_axi_arprot(m_axi_arprot[(2+i)*3 +: 3]), .s_axi_arvalid(m_axi_arvalid[2+i]), .s_axi_arready(m_axi_arready[2+i]), .s_axi_rid(m_axi_rid[(2+i)*M_ID_WIDTH +: M_ID_WIDTH]), .s_axi_rdata(m_axi_rdata[(2+i)*32 +: 32]), .s_axi_rresp(m_axi_rresp[(2+i)*2 +: 2]), .s_axi_rlast(m_axi_rlast[2+i]), .s_axi_rvalid(m_axi_rvalid[2+i]), .s_axi_rready(m_axi_rready[2+i]),
                .m_axil_awaddr(axil_ctrl_s_awaddr[i*32 +: 32]), .m_axil_awprot(axil_ctrl_s_awprot[i*3 +: 3]), .m_axil_awvalid(axil_ctrl_s_awvalid[i]), .m_axil_awready(axil_ctrl_s_awready[i]), .m_axil_wdata(axil_ctrl_s_wdata[i*32 +: 32]), .m_axil_wstrb(axil_ctrl_s_wstrb[i*4 +: 4]), .m_axil_wvalid(axil_ctrl_s_wvalid[i]), .m_axil_wready(axil_ctrl_s_wready[i]), .m_axil_bresp(axil_ctrl_s_bresp[i*2 +: 2]), .m_axil_bvalid(axil_ctrl_s_bvalid[i]), .m_axil_bready(axil_ctrl_s_bready[i]), .m_axil_araddr(axil_ctrl_s_araddr[i*32 +: 32]), .m_axil_arprot(axil_ctrl_s_arprot[i*3 +: 3]), .m_axil_arvalid(axil_ctrl_s_arvalid[i]), .m_axil_arready(axil_ctrl_s_arready[i]), .m_axil_rdata(axil_ctrl_s_rdata[i*32 +: 32]), .m_axil_rresp(axil_ctrl_s_rresp[i*2 +: 2]), .m_axil_rvalid(axil_ctrl_s_rvalid[i]), .m_axil_rready(axil_ctrl_s_rready[i])
            );
        end
    endgenerate

    // ===========================================================================
    // eFPGA Subsystem (Encapsulated Connector & eFPGA Fabric)
    // ===========================================================================
    efpga_subsystem_top #(
        .NUM_SLOTS   (NUM_SLOTS),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
        .HW_VERSION  (HW_VERSION)
    ) efpga_subsystem_top_inst (
        .clk_i              (clk_10mhz),
        .rstn_i             (sys_rstn),
        .rst_i              (sys_rst),

        // Global Management Interface (from Manager Bridge M1)
        .s_axil_mgr_awaddr  (axil_mgr_awaddr),
        .s_axil_mgr_awprot  (axil_mgr_awprot),
        .s_axil_mgr_awvalid (axil_mgr_awvalid),
        .s_axil_mgr_awready (axil_mgr_awready),
        .s_axil_mgr_wdata   (axil_mgr_wdata),
        .s_axil_mgr_wstrb   (axil_mgr_wstrb),
        .s_axil_mgr_wvalid  (axil_mgr_wvalid),
        .s_axil_mgr_wready  (axil_mgr_wready),
        .s_axil_mgr_bresp   (axil_mgr_bresp),
        .s_axil_mgr_bvalid  (axil_mgr_bvalid),
        .s_axil_mgr_bready  (axil_mgr_bready),
        .s_axil_mgr_araddr  (axil_mgr_araddr),
        .s_axil_mgr_arprot  (axil_mgr_arprot),
        .s_axil_mgr_arvalid (axil_mgr_arvalid),
        .s_axil_mgr_arready (axil_mgr_arready),
        .s_axil_mgr_rdata   (axil_mgr_rdata),
        .s_axil_mgr_rresp   (axil_mgr_rresp),
        .s_axil_mgr_rvalid  (axil_mgr_rvalid),
        .s_axil_mgr_rready  (axil_mgr_rready),

        // Slot Control Interface (from Slot Bridges M2..N)
        .s_axil_ctrl_awaddr (axil_ctrl_s_awaddr),
        .s_axil_ctrl_awprot (axil_ctrl_s_awprot),
        .s_axil_ctrl_awvalid(axil_ctrl_s_awvalid),
        .s_axil_ctrl_awready(axil_ctrl_s_awready),
        .s_axil_ctrl_wdata  (axil_ctrl_s_wdata),
        .s_axil_ctrl_wstrb  (axil_ctrl_s_wstrb),
        .s_axil_ctrl_wvalid (axil_ctrl_s_wvalid),
        .s_axil_ctrl_wready (axil_ctrl_s_wready),
        .s_axil_ctrl_bresp  (axil_ctrl_s_bresp),
        .s_axil_ctrl_bvalid (axil_ctrl_s_bvalid),
        .s_axil_ctrl_bready (axil_ctrl_s_bready),
        .s_axil_ctrl_araddr (axil_ctrl_s_araddr),
        .s_axil_ctrl_arprot (axil_ctrl_s_arprot),
        .s_axil_ctrl_arvalid(axil_ctrl_s_arvalid),
        .s_axil_ctrl_arready(axil_ctrl_s_arready),
        .s_axil_ctrl_rdata  (axil_ctrl_s_rdata),
        .s_axil_ctrl_rresp  (axil_ctrl_s_rresp),
        .s_axil_ctrl_rvalid (axil_ctrl_s_rvalid),
        .s_axil_ctrl_rready (axil_ctrl_s_rready),

        // DMA Initiator Interface (driving Crossbar Slaves S1..N)
        .m_axi_dma_awid     (s_axi_awid[1*AXI_ID_WIDTH +: NUM_SLOTS*AXI_ID_WIDTH]),
        .m_axi_dma_awaddr   (s_axi_awaddr[1*32 +: NUM_SLOTS*32]),
        .m_axi_dma_awlen    (s_axi_awlen[1*8 +: NUM_SLOTS*8]),
        .m_axi_dma_awsize   (s_axi_awsize[1*3 +: NUM_SLOTS*3]),
        .m_axi_dma_awburst  (s_axi_awburst[1*2 +: NUM_SLOTS*2]),
        .m_axi_dma_awlock   (s_axi_awlock[1 +: NUM_SLOTS]),
        .m_axi_dma_awcache  (s_axi_awcache[1*4 +: NUM_SLOTS*4]),
        .m_axi_dma_awprot   (s_axi_awprot[1*3 +: NUM_SLOTS*3]),
        .m_axi_dma_awvalid  (s_axi_awvalid[1 +: NUM_SLOTS]),
        .m_axi_dma_awready  (s_axi_awready[1 +: NUM_SLOTS]),
        .m_axi_dma_wdata    (s_axi_wdata[1*32 +: NUM_SLOTS*32]),
        .m_axi_dma_wstrb    (s_axi_wstrb[1*4 +: NUM_SLOTS*4]),
        .m_axi_dma_wlast    (s_axi_wlast[1 +: NUM_SLOTS]),
        .m_axi_dma_wvalid   (s_axi_wvalid[1 +: NUM_SLOTS]),
        .m_axi_dma_wready   (s_axi_wready[1 +: NUM_SLOTS]),
        .m_axi_dma_bid      (s_axi_bid[1*AXI_ID_WIDTH +: NUM_SLOTS*AXI_ID_WIDTH]),
        .m_axi_dma_bresp    (s_axi_bresp[1*2 +: NUM_SLOTS*2]),
        .m_axi_dma_bvalid   (s_axi_bvalid[1 +: NUM_SLOTS]),
        .m_axi_dma_bready   (s_axi_bready[1 +: NUM_SLOTS]),
        .m_axi_dma_arid     (s_axi_arid[1*AXI_ID_WIDTH +: NUM_SLOTS*AXI_ID_WIDTH]),
        .m_axi_dma_araddr   (s_axi_araddr[1*32 +: NUM_SLOTS*32]),
        .m_axi_dma_arlen    (s_axi_arlen[1*8 +: NUM_SLOTS*8]),
        .m_axi_dma_arsize   (s_axi_arsize[1*3 +: NUM_SLOTS*3]),
        .m_axi_dma_arburst  (s_axi_arburst[1*2 +: NUM_SLOTS*2]),
        .m_axi_dma_arlock   (s_axi_arlock[1 +: NUM_SLOTS]),
        .m_axi_dma_arcache  (s_axi_arcache[1*4 +: NUM_SLOTS*4]),
        .m_axi_dma_arprot   (s_axi_arprot[1*3 +: NUM_SLOTS*3]),
        .m_axi_dma_arvalid  (s_axi_arvalid[1 +: NUM_SLOTS]),
        .m_axi_dma_arready  (s_axi_arready[1 +: NUM_SLOTS]),
        .m_axi_dma_rid      (s_axi_rid[1*AXI_ID_WIDTH +: NUM_SLOTS*AXI_ID_WIDTH]),
        .m_axi_dma_rdata    (s_axi_rdata[1*32 +: NUM_SLOTS*32]),
        .m_axi_dma_rresp    (s_axi_rresp[1*2 +: NUM_SLOTS*2]),
        .m_axi_dma_rlast    (s_axi_rlast[1 +: NUM_SLOTS]),
        .m_axi_dma_rvalid   (s_axi_rvalid[1 +: NUM_SLOTS]),
        .m_axi_dma_rready   (s_axi_rready[1 +: NUM_SLOTS])
    );

endmodule