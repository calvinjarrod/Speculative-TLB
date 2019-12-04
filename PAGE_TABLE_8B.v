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
	input [5:0] LOOKUP_ADDR, 
	output reg LOOKUP_COMPLETE,
	output reg [11:0] LOOKUP_RETURN,
	// USED BY TESTBENCH TO LOAD WITH TRANSLATIONS
	//input PT_INSERT_RQST,
	//input [4:0] PT_INSERT_INDX,
	//input [11:0] PT_INSERT_ENTRY,
	
	input clk
);
reg [11:0] PT_8B[0:31];
reg [4:0] indx;
reg [11:0] currentPTentry;
reg [2:0] state, nextState;
	
initial begin
	$readmemh("PT_8B_ENTRIES.dat",PT_8B);
	LOOKUP_COMPLETE = 0;
	LOOKUP_RETURN = 12'bZ;
	indx = 0;
	state = 0;
	nextState = 0;
end

// BLOCK TO HANDLE STATE CHANGES	
always @ * begin
	case (state) 
		2'b01: 	if (LOOKUP_ADDR == currentPTentry[11:6]) nextState = 2'b00;
						else nextState = 2'b01;
		2'b00:	nextState = LOOKUP_RQST;
	endcase
	$display ("Current State: %b",state);
end

// CHANGE CURRENT STATE BASED ON CLOCK
always @ (posedge clk) begin
	state = nextState;
	case (state)
		2'b00: indx = 0;
		2'b01: if (LOOKUP_ADDR != currentPTentry[11:6]) indx = indx + 1;
	endcase
end

always @ * begin
	case (state)
		2'b01: begin
			currentPTentry = PT_8B[indx];
			$display ("Current indx: %b",indx);
			if (LOOKUP_ADDR == currentPTentry[11:6]) begin
				LOOKUP_RETURN = currentPTentry;
				LOOKUP_COMPLETE = 1;			
				nextState = 2'b00;
			end else nextState = 2'b01;
		end
		2'b00: begin
			LOOKUP_COMPLETE <= 0;
			LOOKUP_RETURN <= 12'bZ;
			nextState = LOOKUP_RQST;
		end
	endcase
end 					
endmodule
