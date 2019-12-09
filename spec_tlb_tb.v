`default_nettype wire
`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// SPEC TLB TESTBENCH
// THIS TEST BENCH GENERATES A RANDOM VIRTUAL ADDRESS WITH THE MSB OF 0
// THE SPEC TLB AND ASSOCIATED PAGE TABLES WILL THEN TRANSLATE THE VIRTUAL 
// ADDRESS INTO A SYSTEM PHYSICAL ADDRESS. THE SYSTEM PHYSICAL ADDRESS IS THE
// SAME AS THE VIRTUAL ADDRESS EXCEPT WITH THE MSB SET TO 1 TO MAKE VISUAL
// TRANSLATION EASY.
// 
// TO CHANGE FROM A SPECULATIVE TLB WITH 32-BYTE PAGE ADDRESSES TO A 
// NON-SPECULATIVE TLB WITH 8-BYTE PAGE ADDRESSES, CHANGE SPEC_BIT PARAMETER
// TO 0.
//
// Author: Calvin Jarrod Smith
// -----------------------------------------------------------------------------
module spec_tlb_tb#(parameter [6:0] NUM_ADDRS = 64, parameter SPEC_SET = 0)();

// TB TO TLB PORTS
reg TRANS_RQST;
reg SPEC_TLB_RQST;
reg[8:0] VIRT_ADDR_LOOKUP;
wire SPEC_HIT;
wire TLB_HIT;
wire[8:0] PHY_ADDR_TRANS;
wire DONE_TRANS;
reg clk;

// 8B TO TLB INTERCONNECTS
wire LOOKUP_RQST_8B;
wire [5:0] LOOKUP_ADDR_8B;
wire LOOKUP_COMPLETE_8B;
wire [11:0] LOOKUP_RETURN_8B;

// 32B TO TLB INTERCONNECTS
wire LOOKUP_RQST_32B;
wire [3:0] LOOKUP_ADDR_32B;
wire LOOKUP_COMPLETE_32B;
wire [7:0] LOOKUP_RETURN_32B;

SPECLATIVE_TLB SPEC_TLB(
	.SPEC_TLB_RQST(SPEC_TLB_RQST),
	.TRANS_RQST(TRANS_RQST),
	.VIRT_ADDR_LOOKUP(VIRT_ADDR_LOOKUP),
	.SPEC_HIT(SPEC_HIT),
	.TLB_HIT(TLB_HIT),
	.PHY_ADDR_TRANS(PHY_ADDR_TRANS),
	.DONE_TRANS(DONE_TRANS),
	.clk(clk),
	.PAGE_8B_RQST(LOOKUP_RQST_8B),
	.PAGE_8B_LOOKUP(LOOKUP_ADDR_8B),
	.PAGE_8B_RECV(LOOKUP_RETURN_8B),
	.PAGE_8B_COMPLETE(LOOKUP_COMPLETE_8B), 
	.PAGE_32B_RQST(LOOKUP_RQST_32B),
	.PAGE_32B_LOOKUP(LOOKUP_ADDR_32B),
	.PAGE_32B_RECV(LOOKUP_RETURN_32B),
	.PAGE_32B_COMPLETE(LOOKUP_COMPLETE_32B)
);

PAGE_TABLE_32B PT_32B (
	.LOOKUP_RQST(LOOKUP_RQST_32B),
	.LOOKUP_ADDR(LOOKUP_ADDR_32B),
	.LOOKUP_COMPLETE(LOOKUP_COMPLETE_32B),
	.LOOKUP_RETURN(LOOKUP_RETURN_32B),
	.clk(clk)
);

PAGE_TABLE_8B PT_8B (
	.LOOKUP_RQST(LOOKUP_RQST_8B),
	.LOOKUP_ADDR(LOOKUP_ADDR_8B),
	.LOOKUP_COMPLETE(LOOKUP_COMPLETE_8B),
	.LOOKUP_RETURN(LOOKUP_RETURN_8B),
	.clk(clk)
);

// STATE 0 IS REQUEST NEW ADDRESS FROM TLB
// STATE 1 IS WAIT FOR NEW ADDRESS FROM TLB
reg [1:0] state, nextState;
reg [8:0] completed_addr;
//reg [8:0] ADDRS_TO_TRANSLATE[0:NUM_ADDRS-1];
reg [6:0] indx;
reg [8:0] randomAddr;
reg [5:0] TLB_HITS;

initial begin
	$display ("Virtual Addr\t Physical Addr\t  TLB Hit");
	randomAddr = {1'b0,{$random}%256};
	state = 0;
	nextState = 0;
	SPEC_TLB_RQST = 0;
	TRANS_RQST = 0;
	VIRT_ADDR_LOOKUP = 9'bZ;
	clk = 0;
	indx = 0;
	TLB_HITS = 0;
	repeat (10000) begin
		#1 clk <= ~clk;
	end
end

always @ (posedge TLB_HIT) begin
	TLB_HITS = TLB_HITS + 6'b000001;
end

always @ * begin
	randomAddr = {1'b0,{$random}%256};
	case (state) 
		2'b00: nextState = 2'b01;
		2'b01: if (indx < NUM_ADDRS) begin
			VIRT_ADDR_LOOKUP = randomAddr;
			SPEC_TLB_RQST = SPEC_SET;
			TRANS_RQST = 1;
			nextState = 2'b10;
		end else nextState = 2'b11;
		2'b10: if (DONE_TRANS) begin
			nextState = 2'b01;
			end else begin
				SPEC_TLB_RQST = 0;
				TRANS_RQST = 0;
				nextState = 2'b10;
			end
		2'b11: begin
			$display("---------------------------------------------------------------------------");
			$display("---------------------------------------------------------------------------");
			$display("Number of lookups: %d. Number of TLB hits: %d.",indx,TLB_HITS);
			$display("Total time to lookup %d entries is %d ns",indx,$time);
			$display("---------------------------------------------------------------------------");
			$display("---------------------------------------------------------------------------");
			$stop;
		end
	endcase
end

always @ (posedge clk) begin
	state = nextState;
end

always @ (posedge DONE_TRANS) begin
	if (indx < NUM_ADDRS) indx = indx + 1;
	completed_addr = PHY_ADDR_TRANS;
	$display("%b\t\t%b\t\t%b",VIRT_ADDR_LOOKUP,completed_addr,TLB_HIT);
end
endmodule