// Statement block for system testbenches running on the real FABulous fabric
// (FILE_LISTS/tb/*_fabric.f, -d FABRIC_SIM). Loads +bitstream_hex=<file> (from
// SOFT_LOGIC/Taskfile.yml) through efpga_manager CONFIG_DATA, like firmware does.
// Needs the tb's cpu_axi_write_word(), MGR_BASE_ADDR, clk and rst_n.
begin : load_fabric_bitstream
    localparam int MAX_BITBYTES = 40960; // must match MAX_BITBYTES in SOFT_LOGIC/Taskfile.yml
    string      hex_file;
    logic [7:0] bs [MAX_BITBYTES];
    if (!$value$plusargs("bitstream_hex=%s", hex_file))
        $fatal(1, "FABRIC_SIM: no +bitstream_hex=<file> given");
    $readmemh(hex_file, bs);
    $display("--- [INIT] Loading fabric bitstream %s via eFPGA Manager CONFIG_DATA ---", hex_file);
    // The manager byte-swaps CPU words into big-endian fabric frames.
    for (int n = 0; n < MAX_BITBYTES; n += 4)
        cpu_axi_write_word(MGR_BASE_ADDR + 32'h0000_0008, {bs[n+3], bs[n+2], bs[n+1], bs[n]});
    $display("  -> [OK] Bitstream loaded (%0d words).", MAX_BITBYTES / 4);
    // The tb released rst_n before the soft logic existed, so its flops never saw a
    // reset. Pulse rst_n again (it also drives the slot soft-reset); configuration
    // survives, only the ConfigFSM resets. Not force/release on the slot-reset port:
    // xsim keeps the forced 0 there, as {4{rst_n}} is not re-evaluated on release.
    rst_n = 1'b0;
    repeat (10) @(negedge clk);
    rst_n = 1'b1;
    repeat (10) @(negedge clk);
end
