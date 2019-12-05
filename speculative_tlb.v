
// -----------------------------------------------------------------------------
// SPECULATIVE TRANSLATION LOOKASIDE BUFFER
// TAKES INPUT VIRTUAL ADDRESSES AND TRANSLATES TO SYSTEM PHYSICAL ADDRESSES
// ON TLB MISS, EITHER 8B PAGE TABLE OR 32B PAGE TABLE REFERENCED FOR
// TRANSLATION
//
// Author: Calvin Jarrod Smith
// -----------------------------------------------------------------------------
module SPECLATIVE_TLB
	#(parameter TLB_ENTRIES = 4)
	(
	// ---------------------------------------------------------------------------
	// PORTS TO EXTERNAL MODULES, TESTBENCH---------------------------------------
	input SPEC_TLB_RQST,						// REQUEST A SPECULATIVE TRANSLATION
	input TRANS_RQST,								// REQUEST A TRANSLATION
	input[8:0] VIRT_ADDR_LOOKUP,    // 9-BIT VIRTUAL ADDRESS INPUT TO TRANSLATE
	output reg SPEC_HIT,						// SET TO 1 IF SPEC HIT OCCURS, 0 IF SPEC 
                                  // MISS OCCURS
	output reg TLB_HIT,             // SET TO 1 IF TLB HIT OCCURS, 0 IF TLB
                                  // MISS OCCURS
	output reg[8:0] PHY_ADDR_TRANS, // OUTPUT PHYSICAL ADDRESS TRANSLATION
	output reg DONE_TRANS,          // SET TO 1 WHEN TRANSLATION IS FINISHED
	
	input clk,

	// ON TLB MISSES, THESE PORTS USED TO GET ADDRESS TRANSLATIONS
	// IN PAGE TABLES-------------------------------------------------------------
	// FOR CONVENTIONAL TLB USE 8-BYTE PAGE TABLE
	output reg PAGE_8B_RQST,
	output reg[5:0] PAGE_8B_LOOKUP,
	input[11:0] PAGE_8B_RECV,
	input PAGE_8B_COMPLETE,

	// FOR SPECULATIVE TLB USE 32-BYTE PAGE TABLE	
	output reg PAGE_32B_RQST,
	output reg[3:0] PAGE_32B_LOOKUP,
	input[7:0] PAGE_32B_RECV,
	input PAGE_32B_COMPLETE
	// ---------------------------------------------------------------------------

);

reg [12:0] TLB_TABLE[0:TLB_ENTRIES-1]; // TLB TRANSLATION TABLE WITH 4 ENTRIES
reg [1:0] indx, insertIndx, numEntries;
reg [12:0] currentTLBentry;
reg [2:0] state, nextState;

initial begin
	DONE_TRANS = 0;
	SPEC_HIT = 0;
	TLB_HIT = 0;
	PHY_ADDR_TRANS = 9'bZ;
	PAGE_8B_RQST = 0;
	PAGE_8B_LOOKUP = 6'bZ;
	PAGE_32B_RQST = 0;
	PAGE_32B_LOOKUP = 4'bZ;
	indx = 0;
	insertIndx = 0;
	numEntries = 0;
	state = 3'b0;
	nextState = 3'b0;
end
	
// BLOCK USED TO SYNCHRONIZE STATE CHANGE WITH CLOCK
always @ (posedge clk) begin
	//$display ("TLB state: %b, next state: %b",state,nextState);
	//$display ("TLB Index: %b",indx);
	state = nextState;
	if (numEntries < TLB_ENTRIES) begin
		insertIndx = numEntries;
	end
	case (state)
		3'b000: if (TRANS_RQST && ~SPEC_TLB_RQST) nextState = 3'b100;
			else if (TRANS_RQST && SPEC_TLB_RQST) nextState = 3'b001;
			else nextState = 3'b000;
		3'b001: indx = indx + 1;
		3'b011: if (VIRT_ADDR_LOOKUP[8:3] != currentTLBentry[11:6]) indx = indx + 1;
	endcase
end

always @ (PAGE_32B_COMPLETE,PAGE_8B_COMPLETE) begin
	if (numEntries < TLB_ENTRIES) numEntries = numEntries + 1;
end

// LOGIC AT SPECIFIC STATES
always @ * begin
	case (state)
		3'b000: begin
			DONE_TRANS = 0;
			SPEC_HIT = 0;
			TLB_HIT = 0;
			PHY_ADDR_TRANS = 8'bZ;
		end
		3'b001: begin
			currentTLBentry = TLB_TABLE[indx];
			if (VIRT_ADDR_LOOKUP[8:5] == currentTLBentry[11:8]) begin
				PHY_ADDR_TRANS = {currentTLBentry[5:2],VIRT_ADDR_LOOKUP[4:0]};
				DONE_TRANS = 1;
				SPEC_HIT = 1;
				TLB_HIT = 1;
				nextState = 3'b000;
			end else if (indx >= TLB_ENTRIES || indx >= numEntries) nextState = 3'b010;
			else nextState = 3'b001;
		end
		3'b010: begin
			// its not getting to here for some reason
			//$display ("Got to state 010!");
			PAGE_32B_LOOKUP = VIRT_ADDR_LOOKUP[8:5];
			PAGE_32B_RQST = 1;
			nextState = 3'b011;
			//if (PAGE_32B_COMPLETE) begin
			//	PHY_ADDR_TRANS = {PAGE_32B_RECV[3:0],VIRT_ADDR_LOOKUP[4:0]};
			//	TLB_TABLE[insertIndx] = {1'b1,PAGE_32B_RECV[7:4],2'b0,PAGE_32B_RECV[3:0],2'b0};
			//	nextState = 3'b000;
			//	DONE_TRANS = 1;
			//	PAGE_32B_RQST = 0;
			//	PAGE_32B_LOOKUP = 4'bZ;
			//end
		end
		3'b011: begin
			PAGE_32B_RQST = 0;
			if (PAGE_32B_COMPLETE) begin
				PHY_ADDR_TRANS = {PAGE_32B_RECV[3:0],VIRT_ADDR_LOOKUP[4:0]};
				TLB_TABLE[insertIndx] = {1'b1,PAGE_32B_RECV[7:4],2'b0,PAGE_32B_RECV[3:0],2'b0};
				nextState = 3'b000;
				DONE_TRANS = 1;
				PAGE_32B_RQST = 0;
				PAGE_32B_LOOKUP = 4'bZ;
			end
		end
		3'b100: begin
			currentTLBentry = TLB_TABLE[indx];
			if (VIRT_ADDR_LOOKUP[8:3] == currentTLBentry[11:6]) begin
				PHY_ADDR_TRANS = {currentTLBentry[5:0],VIRT_ADDR_LOOKUP[2:0]};
				DONE_TRANS = 1;
				TLB_HIT = 1;
				nextState = 3'b000;
			end	else if (indx >= TLB_ENTRIES) nextState = 3'b100;
			else nextState = 3'b011;
		end
		3'b100: begin
			PAGE_8B_LOOKUP = VIRT_ADDR_LOOKUP[8:3];
			PAGE_8B_RQST = 1;
			if (PAGE_8B_COMPLETE) begin
				PHY_ADDR_TRANS = {PAGE_8B_RECV[5:0],VIRT_ADDR_LOOKUP[2:0]};
				TLB_TABLE[insertIndx] = {1'b0,PAGE_8B_RECV};
				nextState = 3'b000;
				DONE_TRANS = 1;
				PAGE_8B_RQST = 0;
				PAGE_8B_LOOKUP = 6'bZ;
			end
		end
	endcase
end

endmodule
