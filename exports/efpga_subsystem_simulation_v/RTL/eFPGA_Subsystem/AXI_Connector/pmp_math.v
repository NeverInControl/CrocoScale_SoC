module pmp_math (
	g_en_i,
	base_i,
	limit_i,
	awaddr_i,
	awlen_i,
	awsize_i,
	awprot_i,
	awvalid_i,
	araddr_i,
	arlen_i,
	arsize_i,
	arprot_i,
	arvalid_i,
	violation_r_o,
	violation_w_o
);
	parameter signed [31:0] NUM_PMP_REGIONS = 2;
	parameter [0:0] PAGE_GRANULARITY = 1'b1;
	parameter signed [31:0] ADDR_WIDTH = 32;
	input wire g_en_i;
	input wire [(NUM_PMP_REGIONS * 32) - 1:0] base_i;
	input wire [(NUM_PMP_REGIONS * 32) - 1:0] limit_i;
	input wire [31:0] awaddr_i;
	input wire [7:0] awlen_i;
	input wire [2:0] awsize_i;
	input wire [2:0] awprot_i;
	input wire awvalid_i;
	input wire [31:0] araddr_i;
	input wire [7:0] arlen_i;
	input wire [2:0] arsize_i;
	input wire [2:0] arprot_i;
	input wire arvalid_i;
	output wire violation_r_o;
	output wire violation_w_o;
	localparam signed [31:0] ADDR_SHIFT = (PAGE_GRANULARITY ? 12 : 2);
	localparam signed [31:0] COMP_WIDTH = ADDR_WIDTH - ADDR_SHIFT;
	wire aw_is_priv = awprot_i[0];
	wire aw_is_sec = ~awprot_i[1];
	wire ar_is_priv = arprot_i[0];
	wire ar_is_sec = ~arprot_i[1];
	wire [NUM_PMP_REGIONS - 1:0] aw_region_ok;
	wire [NUM_PMP_REGIONS - 1:0] ar_region_ok;
	wire aw_allowed;
	wire ar_allowed;
	function automatic [10:0] sv2v_cast_11;
		input reg [10:0] inp;
		sv2v_cast_11 = inp;
	endfunction
	generate
		if (PAGE_GRANULARITY == 1) begin : gen_fast_4k_page_math
			wire [COMP_WIDTH - 1:0] aw_pfn = awaddr_i[ADDR_WIDTH - 1:12];
			wire [COMP_WIDTH - 1:0] ar_pfn = araddr_i[ADDR_WIDTH - 1:12];
			genvar _gv_r_1;
			for (_gv_r_1 = 0; _gv_r_1 < NUM_PMP_REGIONS; _gv_r_1 = _gv_r_1 + 1) begin : pmp_checks_4k
				localparam r = _gv_r_1;
				wire read_en = base_i[r * 32];
				wire write_en = base_i[(r * 32) + 1];
				wire req_priv = limit_i[r * 32];
				wire req_sec = limit_i[(r * 32) + 1];
				wire [COMP_WIDTH - 1:0] base_pfn = base_i[(r * 32) + ((ADDR_WIDTH - 1) >= 12 ? ADDR_WIDTH - 1 : ((ADDR_WIDTH - 1) + ((ADDR_WIDTH - 1) >= 12 ? ADDR_WIDTH - 12 : 14 - ADDR_WIDTH)) - 1)-:((ADDR_WIDTH - 1) >= 12 ? ADDR_WIDTH - 12 : 14 - ADDR_WIDTH)];
				wire [COMP_WIDTH - 1:0] limit_pfn = limit_i[(r * 32) + ((ADDR_WIDTH - 1) >= 12 ? ADDR_WIDTH - 1 : ((ADDR_WIDTH - 1) + ((ADDR_WIDTH - 1) >= 12 ? ADDR_WIDTH - 12 : 14 - ADDR_WIDTH)) - 1)-:((ADDR_WIDTH - 1) >= 12 ? ADDR_WIDTH - 12 : 14 - ADDR_WIDTH)];
				wire aw_in_bounds = (aw_pfn >= base_pfn) && (aw_pfn < limit_pfn);
				wire ar_in_bounds = (ar_pfn >= base_pfn) && (ar_pfn < limit_pfn);
				wire aw_sec_ok = (!req_priv || aw_is_priv) && (!req_sec || aw_is_sec);
				wire ar_sec_ok = (!req_priv || ar_is_priv) && (!req_sec || ar_is_sec);
				assign aw_region_ok[r] = (write_en && aw_in_bounds) && aw_sec_ok;
				assign ar_region_ok[r] = (read_en && ar_in_bounds) && ar_sec_ok;
			end
			assign aw_allowed = |aw_region_ok;
			assign ar_allowed = |ar_region_ok;
		end
		else begin : gen_exact_word_math
			wire [10:0] aw_burst_bytes = sv2v_cast_11((sv2v_cast_11(awlen_i) + 11'd1) << awsize_i[1:0]);
			wire [10:0] ar_burst_bytes = sv2v_cast_11((sv2v_cast_11(arlen_i) + 11'd1) << arsize_i[1:0]);
			localparam signed [31:0] CALC_W = ADDR_WIDTH + 1;
			function automatic [CALC_W - 1:0] sv2v_cast_C12C6;
				input reg [CALC_W - 1:0] inp;
				sv2v_cast_C12C6 = inp;
			endfunction
			function automatic signed [CALC_W - 1:0] sv2v_cast_C12C6_signed;
				input reg signed [CALC_W - 1:0] inp;
				sv2v_cast_C12C6_signed = inp;
			endfunction
			wire [ADDR_WIDTH:0] aw_end_addr_full = ({1'b0, awaddr_i[ADDR_WIDTH - 1:0]} + sv2v_cast_C12C6(aw_burst_bytes)) - sv2v_cast_C12C6_signed(1);
			wire [ADDR_WIDTH:0] ar_end_addr_full = ({1'b0, araddr_i[ADDR_WIDTH - 1:0]} + sv2v_cast_C12C6(ar_burst_bytes)) - sv2v_cast_C12C6_signed(1);
			wire aw_4g_wrap = aw_end_addr_full[ADDR_WIDTH];
			wire ar_4g_wrap = ar_end_addr_full[ADDR_WIDTH];
			wire [COMP_WIDTH - 1:0] aw_start = awaddr_i[ADDR_WIDTH - 1:2];
			wire [COMP_WIDTH - 1:0] aw_end = aw_end_addr_full[ADDR_WIDTH - 1:2];
			wire [COMP_WIDTH - 1:0] ar_start = araddr_i[ADDR_WIDTH - 1:2];
			wire [COMP_WIDTH - 1:0] ar_end = ar_end_addr_full[ADDR_WIDTH - 1:2];
			genvar _gv_r_2;
			for (_gv_r_2 = 0; _gv_r_2 < NUM_PMP_REGIONS; _gv_r_2 = _gv_r_2 + 1) begin : pmp_checks_word
				localparam r = _gv_r_2;
				wire read_en = base_i[r * 32];
				wire write_en = base_i[(r * 32) + 1];
				wire req_priv = limit_i[r * 32];
				wire req_sec = limit_i[(r * 32) + 1];
				wire [COMP_WIDTH - 1:0] base_val = base_i[(r * 32) + ((ADDR_WIDTH - 1) >= 2 ? ADDR_WIDTH - 1 : ((ADDR_WIDTH - 1) + ((ADDR_WIDTH - 1) >= 2 ? ADDR_WIDTH - 2 : 4 - ADDR_WIDTH)) - 1)-:((ADDR_WIDTH - 1) >= 2 ? ADDR_WIDTH - 2 : 4 - ADDR_WIDTH)];
				wire [COMP_WIDTH - 1:0] limit_val = limit_i[(r * 32) + ((ADDR_WIDTH - 1) >= 2 ? ADDR_WIDTH - 1 : ((ADDR_WIDTH - 1) + ((ADDR_WIDTH - 1) >= 2 ? ADDR_WIDTH - 2 : 4 - ADDR_WIDTH)) - 1)-:((ADDR_WIDTH - 1) >= 2 ? ADDR_WIDTH - 2 : 4 - ADDR_WIDTH)];
				wire aw_in_bounds = (aw_start >= base_val) && (aw_end < limit_val);
				wire ar_in_bounds = (ar_start >= base_val) && (ar_end < limit_val);
				wire aw_sec_ok = (!req_priv || aw_is_priv) && (!req_sec || aw_is_sec);
				wire ar_sec_ok = (!req_priv || ar_is_priv) && (!req_sec || ar_is_sec);
				assign aw_region_ok[r] = (write_en && aw_in_bounds) && aw_sec_ok;
				assign ar_region_ok[r] = (read_en && ar_in_bounds) && ar_sec_ok;
			end
			assign aw_allowed = |aw_region_ok & ~aw_4g_wrap;
			assign ar_allowed = |ar_region_ok & ~ar_4g_wrap;
		end
	endgenerate
	assign violation_w_o = g_en_i & (awvalid_i & ~aw_allowed);
	assign violation_r_o = g_en_i & (arvalid_i & ~ar_allowed);
endmodule
