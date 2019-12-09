// -----------------------------------------------------------------------------
// 8 BYTE PAGE TABLE
// USED FOR NON-SPECULATIVE PAGE TRANSLATIONS
// WHEN ENTRY IS NOT PRESENT IN TLB
//
// Author: Calvin Jarrod Smith
// -----------------------------------------------------------------------------
module PAGE_TABLE_8B
	#(parameter [5:0]PT_8B_ENTRIES = 32)
	(
	// USED BY TLB TO REQUEST LOOKUP
	input LOOKUP_RQST, 
	input [5:0] LOOKUP_ADDR, 
	output reg LOOKUP_COMPLETE,
	output reg [11:0] LOOKUP_RETURN,
	
	input clk
);
reg [11:0] PT_8B[0:PT_8B_ENTRIES-1];
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

// CHANGE CURRENT STATE BASED ON CLOCK
always @ (posedge clk) begin
	state = nextState;
	case (state)
		2'b01: if (LOOKUP_ADDR != currentPTentry[11:6]) indx = indx + 1;
		2'b10: indx = 0;
	endcase
end

always @ * begin
	case (state)
		2'b00: begin
			nextState = {1'b0,LOOKUP_RQST};
		end
		2'b01: begin
			currentPTentry = PT_8B[indx];
			//$display ("Current indx: %b",indx);
			if (LOOKUP_ADDR == currentPTentry[11:6]) begin
				LOOKUP_RETURN = currentPTentry;
				LOOKUP_COMPLETE = 1;			
				nextState = 2'b10;
			end //else nextState = 2'b01;
		end
		// WAIT ONE CYCLE AFTER TRANSMITTING TRANSLATION
		2'b10: begin
			LOOKUP_COMPLETE = 1'b0;
			LOOKUP_RETURN = 12'bZ;
			nextState = 2'b00;
		end
	endcase
end 

endmodule