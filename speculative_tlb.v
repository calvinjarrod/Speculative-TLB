// -----------------------------------------------------------------------------
// SPECULATIVE TRANSLATION LOOKASIDE BUFFER
// TAKES INPUT VIRTUAL ADDRESSES AND TRANSLATES TO SYSTEM PHYSICAL ADDRESSES
// ON TLB MISS, EITHER 8B PAGE TABLE OR 32B PAGE TABLE REFERENCED FOR
// TRANSLATION
//
// Author: Calvin Jarrod Smith
// -----------------------------------------------------------------------------
module SPECLATIVE_TLB
	#(parameter TLB_ENTRIES = 8)
	(
	// ---------------------------------------------------------------------------
	// PORTS TO EXTERNAL MODULES, TESTBENCH---------------------------------------
	input SPEC_TLB_RQST,						// REQUEST A SPECULATIVE TRANSLATION
	input TRANS_RQST,								// REQUEST A TRANSLATION
	input[7:0] VIRT_ADDR_LOOKUP,    // VIRTUAL ADDRESS INPUT TO TRANSLATE
	output reg SPEC_HIT,						// SET TO 1 IF SPEC HIT OCCURS, 0 IF SPEC 
                                  // MISS OCCURS
	output reg TLB_HIT,             // SET TO 1 IF TLB HIT OCCURS, 0 IF TLB
                                  // MISS OCCURS
	output reg[7:0] PHY_ADDR_TRANS, // OUTPUT PHYSICAL ADDRESS TRANSLATION
	output reg DONE_TRANS,          // SET TO 1 WHEN TRANSLATION IS FINISHED
	
	input clk,

	// ON TLB MISSES, THESE PORTS USED TO GET ADDRESS TRANSLATIONS
	// IN PAGE TABLES-------------------------------------------------------------
	// FOR CONVENTIONAL TLB USE 8-BYTE PAGE TABLE
	output reg PAGE_8B_RQST,
	output reg[4:0] PAGE_8B_LOOKUP,
	input[9:0] PAGE_8B_RECV,
	input PAGE_8B_COMPLETE,

	// FOR SPECULATIVE TLB USE 32-BYTE PAGE TABLE	
	output reg PAGE_32B_RQST,
	output reg[2:0] PAGE_32B_LOOKUP,
	input[5:0] PAGE_32B_RECV,
	input PAGE_32B_COMPLETE
	// ---------------------------------------------------------------------------

);

reg [10:0] TLB_TABLE[0:7]; // TLB TRANSLATION TABLE WITH 8 ENTRIES
reg [2:0] indx, insertIndx, numEntries;
reg [10:0] currentTLBentry;
reg [2:0] state, nextState;

initial begin
	DONE_TRANS = 0;
	SPEC_HIT = 0;
	TLB_HIT = 0;
	PHY_ADDR_TRANS = 8'bZ;
	PAGE_8B_RQST = 0;
	PAGE_8B_LOOKUP = 5'bZ;
	PAGE_32B_RQST = 0;
	PAGE_32B_LOOKUP = 10'bZ;
	indx = 0;
	insertIndx = 0;
	numEntries = 0;
	state = 3'b0;
	nextState = 3'b0;
end
	
//PAGE_TABLE_8B  PT8_Lookup(.LOOKUP_RQST(PAGE_8B_RQST),.LOOKUP_ADDR(PAGE_8B_LOOKUP),
//	.LOOKUP_COMPLETE(PAGE_8B_COMPLETE),.LOOKUP_RETURN(PAGE_8B_RECV));
//PAGE_TABLE_32B  PT32_Lookup(.LOOKUP_RQST(PAGE_32B_RQST),.LOOKUP_ADDR(PAGE_32B_LOOKUP),
//	.LOOKUP_COMPLETE(PAGE_32B_COMPLETE),.LOOKUP_RETURN(PAGE_32B_RECV));

// KEEP TRACK OF WHERE NEXT TO PLACE A NEW TLB ENTRY
always @ (posedge clk) begin
	if (numEntries < TLB_ENTRIES) begin
		insertIndx = numEntries;
	end else begin
	// IMPLEMENT REPLACEMENT ALROGITHM
	// IMPLEMENT REPLACEMENT ALROGITHM
	// IMPLEMENT REPLACEMENT ALROGITHM
	// IMPLEMENT REPLACEMENT ALROGITHM
	// IMPLEMENT REPLACEMENT ALROGITHM
	end
end

// BLOCK USED TO SYNCHRONIZE STATE CHANGE WITH CLOCK
always @ (posedge clk) begin
	state = nextState;
	case (state)
		3'b001: begin
			currentTLBentry = TLB_TABLE[indx];
			if (VIRT_ADDR_LOOKUP[7:5] == currentTLBentry[9:7]) begin
				PHY_ADDR_TRANS = {currentTLBentry[4:2],VIRT_ADDR_LOOKUP[4:0]};
				DONE_TRANS = 1;
				SPEC_HIT = 1;
				TLB_HIT = 1;
			end
		end
	endcase
end

// BLOCK TO HANDLE NEXT STATES
always @ * begin
	case (state) 
		3'b001:	if (VIRT_ADDR_LOOKUP[7:5] == currentTLBentry[9:7]) nextState = 3'b000;
						else if (indx >= TLB_ENTRIES) nextState = 3'b010;
						else nextState = 3'b001;
		3'b011:	if (VIRT_ADDR_LOOKUP[7:3] == currentTLBentry[9:5]) nextState = 3'b000;
						else if (indx >= TLB_ENTRIES) nextState = 3'b100;
						else nextState = 3'b011;
		3'b000:	if (TRANS_RQST && ~SPEC_TLB_RQST) nextState = 3'b011;
						else if (TRANS_RQST && SPEC_TLB_RQST) nextState = 3'b001;
						else nextState = 3'b000;
		3'b010: if (PAGE_32B_COMPLETE) nextState = 3'b000;
	endcase
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
			//currentTLBentry = TLB_TABLE[indx];
			//if (VIRT_ADDR_LOOKUP[7:5] == currentTLBentry[9:7]) begin
			///	PHY_ADDR_TRANS = {currentTLBentry[4:2],VIRT_ADDR_LOOKUP[4:0]};
			//	DONE_TRANS = 1;
			//	SPEC_HIT = 1;
			//	TLB_HIT = 1;
			//end
		end
		3'b010: begin
			PAGE_32B_LOOKUP = VIRT_ADDR_LOOKUP[7:5];
			PAGE_32B_RQST = 1;
			if (PAGE_32B_COMPLETE) begin
				PHY_ADDR_TRANS = {PAGE_32B_RECV[2:0],VIRT_ADDR_LOOKUP[4:0]};
				TLB_TABLE[insertIndx] = {1'b1,PAGE_32B_RECV[5:3],2'b0,PAGE_32B_RECV[2:0],2'b0};
				if (numEntries < TLB_ENTRIES) numEntries = numEntries + 1;
				DONE_TRANS = 1;
				PAGE_32B_RQST = 0;
				PAGE_32B_LOOKUP = 3'bZ;
			end
		end
		3'b011: begin
			currentTLBentry = TLB_TABLE[indx];
			if (VIRT_ADDR_LOOKUP[7:3] == currentTLBentry[9:5]) begin
				PHY_ADDR_TRANS = {currentTLBentry[4:0],VIRT_ADDR_LOOKUP[2:0]};
				DONE_TRANS = 1;
				TLB_HIT = 1;
			end
		end
		3'b100: begin
			PAGE_8B_LOOKUP = VIRT_ADDR_LOOKUP[7:3];
			PAGE_8B_RQST = 1;
			if (PAGE_8B_COMPLETE) begin
				PHY_ADDR_TRANS = {PAGE_8B_RECV[4:0],VIRT_ADDR_LOOKUP[2:0]};
				TLB_TABLE[insertIndx] = {1'b0,PAGE_8B_RECV};
				if (numEntries < TLB_ENTRIES) numEntries = numEntries + 1;
				DONE_TRANS = 1;
				PAGE_8B_RQST = 0;
				PAGE_8B_LOOKUP = 5'bZ;
			end
		end
	endcase
end

endmodule
// -----------------------------------------------------------------------------
// 8 BYTE PAGE TABLE
// USED FOR NON-SPECULATIVE PAGE TRANSLATIONS
// WHEN ENTRY IS NOT PRESENT IN TLB
// -----------------------------------------------------------------------------
module PAGE_TABLE_8B
	#(parameter [4:0]PT_8B_ENTRIES = 32)
	(
	// USED BY TLB TO REQUEST LOOKUP
	input LOOKUP_RQST, 
	input [4:0] LOOKUP_ADDR, 
	output reg LOOKUP_COMPLETE,
	output reg [9:0] LOOKUP_RETURN,
	// USED BY TESTBENCH TO LOAD WITH TRANSLATIONS
	input PT_INSERT_RQST,
	input [4:0] PT_INSERT_INDX,
	input [9:0] PT_INSERT_ENTRY,
	
	input clk
);
reg [9:0] PT_8B[0:31];
reg [4:0] indx;
reg [9:0] currentPTentry;
reg [2:0] state, nextState;
	
initial begin
	LOOKUP_COMPLETE = 0;
	LOOKUP_RETURN = 10'bZ;
	indx = 0;
	state = 0;
	nextState = 0;
end

// BLOCK TO HANDLE STATE CHANGES	
always @ * begin
	case (state) 
		2'b01:	nextState = {LOOKUP_RQST,PT_INSERT_RQST};
		2'b10: 	if (LOOKUP_ADDR == currentPTentry[9:5]) nextState = 2'b00;
						else nextState = 2'b10;
		2'b00:	nextState = {LOOKUP_RQST,PT_INSERT_RQST};
	endcase
	$display ("Current State: %b",state);
end

// CHANGE CURRENT STATE BASED ON CLOCK
always @ (posedge clk) begin
	state = nextState;
	case (state)
		2'b00: indx = 0;
		2'b10: if (LOOKUP_ADDR != currentPTentry[5:3]) indx = indx + 1;
	endcase
end

always @ * begin
	case (state)
		2'b01: begin 
			PT_8B[PT_INSERT_INDX] = PT_INSERT_ENTRY;
		end
		2'b10: begin
			currentPTentry = PT_8B[indx];
			$display ("Current indx: %b",indx);
			if (LOOKUP_ADDR == currentPTentry[9:5]) begin
				LOOKUP_RETURN = currentPTentry;
				LOOKUP_COMPLETE = 1;			
			end
		end
		2'b00: begin
			LOOKUP_COMPLETE <= 0;
			LOOKUP_RETURN <= 10'bZ;
		end
	endcase
end 					
endmodule
// -----------------------------------------------------------------------------
// 32 BYTE PAGE TABLE
// USED FOR SPECULATIVE PAGE TRANSLATIONS
// WHEN ENTRY IS NOT PRESENT IN TLB
// -----------------------------------------------------------------------------
module PAGE_TABLE_32B
	#(parameter [4:0]PT_32B_ENTRIES = 16)
	(
	// USED BY TLB TO REQUEST LOOKUP
	input LOOKUP_RQST, 
	input [2:0] LOOKUP_ADDR, 
	output reg LOOKUP_COMPLETE,
	output reg [5:0] LOOKUP_RETURN,
	// USED BY TESTBENCH TO LOAD WITH TRANSLATIONS
	input PT_INSERT_RQST,
	input [3:0] PT_INSERT_INDX,
	input [5:0] PT_INSERT_ENTRY,
	
	input clk
);
reg [5:0] PT_32B[0:15];
reg [3:0] indx;
reg [5:0] currentPTentry;
reg [2:0] state, nextState;
	
initial begin
	LOOKUP_COMPLETE = 0;
	LOOKUP_RETURN = 6'bZ;
	indx = 0;
	state = 0;
	nextState = 0;
end

// BLOCK TO HANDLE STATE CHANGES	
always @ * begin
	case (state) 
		2'b01: 	nextState = {LOOKUP_RQST,PT_INSERT_RQST};
		2'b10: 	if (LOOKUP_ADDR == currentPTentry[5:3]) nextState = 2'b00;
						else nextState = 2'b10;
		2'b00:	nextState = {LOOKUP_RQST,PT_INSERT_RQST};
	endcase
	$display ("Current State: %b",state);
end

// CHANGE CURRENT STATE BASED ON CLOCK
always @ (posedge clk) begin
	state = nextState;
	case (state)
		2'b00: indx = 0;
		2'b10: if (LOOKUP_ADDR != currentPTentry[5:3]) indx = indx + 1;
	endcase
end

always @ * begin
	case (state)
		2'b01: begin 
			PT_32B[PT_INSERT_INDX] = PT_INSERT_ENTRY;
		end
		2'b10: begin
			currentPTentry = PT_32B[indx];
			$display ("Current indx: %b",indx);
			if (LOOKUP_ADDR == currentPTentry[5:3]) begin
				LOOKUP_RETURN = currentPTentry;
				LOOKUP_COMPLETE = 1;			
			end
		end
		2'b00: begin
			LOOKUP_COMPLETE <= 0;
			LOOKUP_RETURN <= 6'bZ;
		end
	endcase
end 		
endmodule
