// =============================================================================
// File: TEST/SoftLogic/common/load_fabric_bitstream.svh
// Description:
//   Shared, soft-logic agnostic bitstream loader task for system testbenches.
//   Streams a generated FABulous bitstream (.hex, overridden via +bitstream_hex=
//   or defaulting to default_hex_file) through the efpga_manager CONFIG_DATA
//   register (0x1000_0008), then pulses rst_n to reset the newly configured
//   fabric flip-flops.
// =============================================================================

task automatic cpu_load_fabric_bitstream(input string default_hex_file);
    localparam int MAX_BITBYTES = 39316; // Must match MAX_BITBYTES in scripts/generate_bitstream.py
    string      hex_file;
    logic [7:0] bs [0:MAX_BITBYTES-1];

    if (!$value$plusargs("bitstream_hex=%s", hex_file)) begin
        hex_file = default_hex_file;
    end
    $readmemh(hex_file, bs);
    $display("--- [INIT] Loading fabric bitstream '%s' via eFPGA Manager CONFIG_DATA ---", hex_file);
    // efpga_manager byte-swaps little-endian CPU words into big-endian fabric frames
    for (int n = 0; n < MAX_BITBYTES; n += 4) begin
        cpu_axi_write_word(MGR_BASE_ADDR + 32'h0000_0008, {bs[n+3], bs[n+2], bs[n+1], bs[n]});
    end
    $display("  -> [OK] Bitstream loaded (%0d words).", MAX_BITBYTES / 4);
    // Pulse rst_n so newly configured soft-logic flip-flops see a clean reset;
    // fabric configuration latches survive resetn (only ConfigFSM resets).
    rst_n = 1'b0;
    repeat (10) @(negedge clk);
    rst_n = 1'b1;
    repeat (10) @(negedge clk);
endtask
