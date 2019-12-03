`timescale 1ns/10ps
// -----------------------------------------------------------------------------
// SPECULATIVE TRANSLATION LOOKASIDE BUFFER
// TAKES INPUT VIRTUAL ADDRESSES AND TRANSLATES TO SYSTEM PHYSICAL ADDRESSES
// ON TLB MISS, EITHER 8B PAGE TABLE OR 32B PAGE TABLE REFERENCED FOR
// TRANSLATION
// -----------------------------------------------------------------------------
module SPECLATIVE_TLB
	#(parameter TLB_ENTRIES = 8)
	(
	// PORTS TO EXTERNAL MODULES, TESTBENCH
	input SPEC_TLB_RQST,						// REQUEST A SPECULATIVE TRANSLATION
	input TRANS_RQST,								// REQUEST A TRANSLATION
	input[7:0] VIRT_ADDR_LOOKUP,    // VIRTUAL ADDRESS INPUT TO TRANSLATE
	output reg SPEC_HIT,						// SET TO 1 IF SPEC HIT OCCURS, 0 IF SPEC 
                                  // MISS OCCURS
	output reg TLB_HIT,             // SET TO 1 IF TLB HIT OCCURS, 0 IF TLB 
                                  // MISS OCCURS
	output reg[7:0] PHY_ADDR_TRANS, // OUTPUT PHYSICAL ADDRESS TRANSLATION
	output reg DONE_TRANS,          // SET TO 1 WHEN TRANSLATION IS FINISHED
	
	input clk
);

// ON TLB MISSES, THESE PORTS USED TO GET ADDRESS TRANSLATIONS
// IN PAGE TABLES---------------------------------------------------------------
// FOR CONVENTIONAL TLB USE 8-BYTE PAGE TABLE
reg PAGE_8B_RQST;
reg[4:0] PAGE_8B_LOOKUP;
reg[9:0] PAGE_8B_RECV;

// FOR SPECULATIVE TLB USE 32-BYTE PAGE TABLE	
reg PAGE_32B_RQST;
reg[2:0] PAGE_32B_LOOKUP;
reg[5:0] PAGE_32B_INPUT;
// -----------------------------------------------------------------------------

initial begin
	assign DONE_TRANS = 0;
	assign SPEC_HIT = 0;
	assign TLB_HIT = 0;
	assign PHY_ADDR_TRANS = 8'bZ;
	assign PAGE_8B_RQST = 0;
	assign PAGE_8B_LOOKUP = 5'bZ;
	assign PAGE_32B_RQST = 0;
	assign PAGE_32B_LOOKUP = 10'bZ;
end
	
reg [10:0] TLB_TABLE[0:7]; // TLB TRANSLATION TABLE WITH 8 ENTRIES
reg [2:0] indx;
reg [10:0] currentTLBentry;

PAGE_TABLE_8B  PT8_Lookup(PAGE_8B_RQST,PAGE_8B_LOOKUP,PAGE_8B_RECV);
PAGE_TABLE_32B PT32_Lookup(PAGE_32B_RQST,PAGE_32B_LOOKUP,PAGE_32B_RECV);

always @ (posedge clk) begin
	if (TRANS_RQST) begin
		if (~SPEC_TLB_RQST) begin    // USE CONVENTIONAL TLB
			currentTLBentry <= TLB_TABLE[0];
			indx = 0;
			while (currentTLBentry[9:5] != VIRT_ADDR_LOOKUP[7:3] || indx == TLB_ENTRIES-1) begin
				indx = indx+1;
				currentTLBentry = TLB_TABLE[indx];
			end
			if (indx == 7) begin
				//PAGE_8B_LOOKUP
			end 
				
	
			PHY_ADDR_TRANS <= VIRT_ADDR_LOOKUP;
			DONE_TRANS <= 1;	
		end else if (SPEC_TLB_RQST) begin	// USE SPECULATIVE TLB
		end
	end
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
	input reg[4:0] LOOKUP_ADDR, 
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
		2'b01: 	nextState = 2'b0;
		2'b10: 	if (LOOKUP_ADDR == currentPTentry[9:5]) nextState = 2'b00;
						else nextState = 2'b10;
		2'b00:	nextState = 2'b00;
	endcase
	$display ("Current State: %b",state);
end

// CHANGE CURRENT STATE BASED ON CLOCK
always @ (posedge clk) begin
	state = nextState;
	if (state != 2'b10) begin
		state = {LOOKUP_RQST,PT_INSERT_RQST};
	end else if (state == 2'b10 && LOOKUP_COMPLETE == 0) begin
		indx = indx + 1;
		if (indx >= PT_8B_ENTRIES) indx = 0;		
	end else if (state == 2'b10 && LOOKUP_COMPLETE == 1) begin
		LOOKUP_COMPLETE = 0;
		LOOKUP_RETURN = 10'bZ;
		state = {LOOKUP_RQST,PT_INSERT_RQST};
	end
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
			indx = 0;
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
	input reg[2:0] LOOKUP_ADDR, 
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
		2'b01: 	nextState = 2'b0;
		2'b10: 	if (LOOKUP_ADDR == currentPTentry[5:3]) nextState = 2'b00;
						else nextState = 2'b10;
		2'b00:	nextState = 2'b00;
	endcase
	$display ("Current State: %b",state);
end

// CHANGE CURRENT STATE BASED ON CLOCK
always @ (posedge clk) begin
	state = nextState;
	if (state != 2'b10) begin
		state = {LOOKUP_RQST,PT_INSERT_RQST};
	end else if (state == 2'b10 && LOOKUP_COMPLETE == 0) begin
		indx = indx + 1;
		if (indx >= PT_32B_ENTRIES) indx = 0;		
	end else if (state == 2'b10 && LOOKUP_COMPLETE == 1) begin
		LOOKUP_COMPLETE = 0;
		LOOKUP_RETURN = 6'bZ;
		state = {LOOKUP_RQST,PT_INSERT_RQST};
	end
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
			indx = 0;
		end
	endcase
end 		
endmodule