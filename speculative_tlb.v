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
	input SPEC_TLB_RQST,				// REQUEST A SPECULATIVE TRANSLATION
	input TRANS_RQST,					// REQUEST A TRANSLATION
	input[8:0] VIRT_ADDR_LOOKUP,   	// 9-BIT VIRTUAL ADDRESS INPUT TO TRANSLATE
	output reg SPEC_HIT,				// SET TO 1 IF SPEC HIT OCCURS, 0 IF SPEC 
												// MISS OCCURS
	output reg TLB_HIT,            	// SET TO 1 IF TLB HIT OCCURS, 0 IF TLB
												// MISS OCCURS
	output reg[8:0] PHY_ADDR_TRANS,	// OUTPUT PHYSICAL ADDRESS TRANSLATION
	output reg DONE_TRANS,         	// SET TO 1 WHEN TRANSLATION IS FINISHED
	
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

reg [16:0] TLB_TABLE[0:TLB_ENTRIES-1]; // TLB TRANSLATION TABLE WITH 4 ENTRIES
reg [2:0] indx, insertIndx, nextInsertIndx, numEntries;
reg [16:0] currentTLBentry;
reg [3:0] state, nextState;
reg [3:0] currentLowestFreq;
reg [7:0] rqstd_32B_trans;
reg [11:0] rqstd_8B_trans;
reg [1:0] rqstd_trans;

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
	nextInsertIndx = 0;
	numEntries = 0;
	state = 4'b0;
	nextState = 3'b0;
	currentLowestFreq = 0;
end
	
// BLOCK USED TO SYNCHRONIZE STATE CHANGE WITH CLOCK
always @ (posedge clk) begin
	//$display("Index: %d, Insert Indx : %d, Num of entries: %d",indx,insertIndx,numEntries);
	//$display("State %d, Next State: %d",state,nextState);
	case (nextState) 
		4'b0100: begin
			insertIndx = 0;
			currentLowestFreq = TLB_TABLE[0][16:13];
		end
		4'b1000: begin
			insertIndx = 0;
			currentLowestFreq = TLB_TABLE[0][16:13];
		end
	endcase
	state = nextState;
	case (state)
		4'b0000: begin
			indx = 0;
			if (TRANS_RQST && ~SPEC_TLB_RQST) nextState = 4'b0101;
			else if (TRANS_RQST && SPEC_TLB_RQST) nextState = 4'b0001;
			else if (rqstd_trans == 2'b11) nextState = 4'b0001;
			else if (rqstd_trans == 2'b10) nextState = 4'b0101;
			else nextState = 4'b0000;
		end
		// 32B LOOKUP @ posedge clk
		4'b0001: begin	
			if (VIRT_ADDR_LOOKUP[8:5] != currentTLBentry[11:8] && indx <= TLB_ENTRIES) indx = indx + 1;
			rqstd_trans = 2'b00;
		end
		4'b0010: begin
			indx = 0;
			if (numEntries < TLB_ENTRIES) insertIndx = numEntries;
		end
		4'b0011: begin
			if (PAGE_32B_COMPLETE) begin
				indx = 0;
				if	(numEntries == TLB_ENTRIES) nextState = 4'b0100;
			end
		end
		4'b0100: begin
			if (indx < TLB_ENTRIES) begin
				indx = indx + 1;
			end
			if (currentTLBentry[16:13] <= currentLowestFreq) begin 
				insertIndx = nextInsertIndx;
			end
		end
		// 8B LOOKUP @ posedge clk
		4'b0101: begin	
			if (VIRT_ADDR_LOOKUP[8:3] != currentTLBentry[11:6] && indx <= TLB_ENTRIES) indx = indx + 1;
			rqstd_trans = 2'b00;
		end
		4'b0110: begin
			indx = 0;
			if (numEntries < TLB_ENTRIES) insertIndx = numEntries;
		end
		4'b0111: begin
			if (PAGE_8B_COMPLETE) begin
				indx = 0;
				if (numEntries == TLB_ENTRIES) nextState = 4'b1000;
			end
		end
		4'b1000: begin
			if (indx < TLB_ENTRIES) begin
				indx = indx + 1;
			end
			if (currentTLBentry[16:13] <= currentLowestFreq) begin 
				insertIndx = nextInsertIndx;
			end
		end
	endcase
end

// CATCH TRANSLATION REQUEST IN CASE TLB IS BUSY EVICTING AN OLD ENTRY
always @ (posedge TRANS_RQST, posedge SPEC_TLB_RQST) begin
	rqstd_trans = {TRANS_RQST,SPEC_TLB_RQST};
end

// SAVE TRANSLATION REQUESTS FROM PAGE TABLES IN REGS IN CASE TLB
// NEEDS TO EVICT AN OLD ENTRY AND UPDATES THE insertIndx
always @ (posedge PAGE_32B_COMPLETE, posedge PAGE_8B_COMPLETE) begin
	if (numEntries <= TLB_ENTRIES) insertIndx = numEntries;
	if (PAGE_32B_COMPLETE) rqstd_32B_trans = PAGE_32B_RECV;
	else if (PAGE_8B_COMPLETE) rqstd_8B_trans = PAGE_8B_RECV;
end

// LOGIC AT SPECIFIC STATES
always @ * begin
	case (state)
		4'b0000: begin
			DONE_TRANS = 0;
			SPEC_HIT = 0;
			TLB_HIT = 0;
			PHY_ADDR_TRANS = 9'bZ;
		end
		// 32B ENTRY LOOKUP
		// 32B LOOKUP REQUESTED
		// SEARCH TLB FOR TRANSLATION
		4'b0001: begin
			currentTLBentry = TLB_TABLE[indx];
			// if entry is in TLB
			if (VIRT_ADDR_LOOKUP[8:5] == currentTLBentry[11:8]) begin
				PHY_ADDR_TRANS = {currentTLBentry[5:2],VIRT_ADDR_LOOKUP[4:0]};
				if (TLB_TABLE[indx][16:13] < 4'b1111) begin
					// increase frequency count of entry
					TLB_TABLE[indx] = {TLB_TABLE[indx][16:13]+1,TLB_TABLE[indx][12:0]};
				end
				DONE_TRANS = 1;
				SPEC_HIT = 1;
				TLB_HIT = 1;
				nextState = 4'b0000;
			end else if (indx >= TLB_ENTRIES || indx >= numEntries) nextState = 3'b010;
			else nextState = 4'b0001;
		end
		// ENTRY NOT IN TLB, TRIGGER 32B PAGE TABLE TO LOOK UP TRANSLATION
		4'b0010: begin
			PAGE_32B_LOOKUP = VIRT_ADDR_LOOKUP[8:5];
			PAGE_32B_RQST = 1;
			nextState = 4'b0011;
		end
		// WAIT FOR 32B PAGE TABLE TO FINISH LOOKING UP TRANSLATION
		// INSERT IN TLB IF TLB NOT FULL
		4'b0011: begin
			PAGE_32B_RQST = 0;
			if (PAGE_32B_COMPLETE) begin
				PHY_ADDR_TRANS = {PAGE_32B_RECV[3:0],VIRT_ADDR_LOOKUP[4:0]};			
				DONE_TRANS = 1;
				PAGE_32B_RQST = 0;
				PAGE_32B_LOOKUP = 4'bZ;
				if (numEntries < TLB_ENTRIES) begin
					TLB_TABLE[insertIndx] = {4'b0,1'b1,PAGE_32B_RECV[7:4],2'b0,PAGE_32B_RECV[3:0],2'b0};
					numEntries = numEntries + 1;
					insertIndx = numEntries;
					nextState = 4'b0000;
				end
			end
		end
		// TLB IS FULL, EVICT THE ENTRY THAT'S THE LEAST FREQUENTLY USED USING BITS [16:13] OF 
		// TLB ENTRIES
		4'b0100: begin
			PHY_ADDR_TRANS = 9'bZ;
			currentTLBentry = TLB_TABLE[indx];
			//$display("Current lowest freq: %d",currentLowestFreq);
			//$display("Current TLB entry: %b",currentTLBentry);
			DONE_TRANS = 0;
			if (indx < TLB_ENTRIES) begin
				if (currentTLBentry[16:13] < currentLowestFreq) begin
					currentLowestFreq = currentTLBentry[16:13];
					nextInsertIndx = indx;
					nextState = 4'b0100;
				end
			end 
			if (indx >= TLB_ENTRIES) begin
				TLB_TABLE[insertIndx] = {4'b0,1'b1,rqstd_32B_trans[7:4],2'b0,rqstd_32B_trans[3:0],2'b0};
				nextState = 4'b0000;
			end
		end
		// 8B ENTRY LOOKUP
		// 8B LOOKUP REQUESTED
		// SEARCH TLB FOR TRANSLATION
		4'b0101: begin
			currentTLBentry = TLB_TABLE[indx];
			// if entry is in TLB
			if (VIRT_ADDR_LOOKUP[8:3] == currentTLBentry[11:6]) begin
				PHY_ADDR_TRANS = {currentTLBentry[5:0],VIRT_ADDR_LOOKUP[2:0]};
				if (TLB_TABLE[indx][16:13] < 4'b1111) begin
					// increase frequency count of entry
					TLB_TABLE[indx] = {TLB_TABLE[indx][16:13]+1,TLB_TABLE[indx][12:0]};
				end
				DONE_TRANS = 1;
				TLB_HIT = 1;
				nextState = 4'b0000;
			end else if (indx >= TLB_ENTRIES || indx >= numEntries) nextState = 4'b0110;
			else nextState = 4'b0101;
		end
		// ENTRY NOT IN TLB, TRIGGER 8B PAGE TABLE TO LOOK UP TRANSLATION		
		4'b0110: begin
			PAGE_8B_LOOKUP = VIRT_ADDR_LOOKUP[8:3];
			PAGE_8B_RQST = 1;
			nextState = 4'b0111;
		end
		// WAIT FOR 8B PAGE TABLE TO FINISH LOOKING UP TRANSLATION
		// INSERT IN TLB IF TLB NOT FULL
		4'b0111: begin
			PAGE_8B_RQST = 0;
			if (PAGE_8B_COMPLETE) begin
				PHY_ADDR_TRANS = {PAGE_8B_RECV[5:0],VIRT_ADDR_LOOKUP[2:0]};			
				DONE_TRANS = 1;
				PAGE_8B_RQST = 0;
				PAGE_8B_LOOKUP = 6'bZ;
				if (numEntries < TLB_ENTRIES) begin
					TLB_TABLE[insertIndx] = {4'b0,1'b0,PAGE_8B_RECV[11:0]};
					numEntries = numEntries + 1;
					insertIndx = numEntries;
					nextState = 4'b0000;
				end
			end
		end
		// TLB IS FULL, EVICT THE ENTRY THAT'S THE LEAST FREQUENTLY USED USING BITS [16:13] OF 
		// TLB ENTRIES
		4'b1000: begin
			PHY_ADDR_TRANS = 9'bZ;
			currentTLBentry = TLB_TABLE[indx];
			//$display("Current lowest freq: %d",currentLowestFreq);
			//$display("Current TLB entry: %b",currentTLBentry);
			DONE_TRANS = 0;
			if (indx < TLB_ENTRIES) begin
				if (currentTLBentry[16:13] < currentLowestFreq) begin
					currentLowestFreq = currentTLBentry[16:13];
					nextInsertIndx = indx;
					nextState = 4'b1000;
				end
			end 
			if (indx >= TLB_ENTRIES) begin
				TLB_TABLE[insertIndx] = {4'b0,1'b1,rqstd_8B_trans[11:0]};
				nextState = 4'b0000;
			end
		end
	endcase
end
endmodule