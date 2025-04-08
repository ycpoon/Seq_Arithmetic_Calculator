`timescale 1ns/1ns
module Binary_to_7SEG_TestBench;
	parameter W = 11;
	reg signed [W-1:0] TC;				// W-bit two's complement number
	wire [6:0] TCSign;						// 7-segment for sign
	wire [6:0] TCD2, TCD1, TCD0;	// 7-segment for magnitude digits
	wire TCTooLarge;							// TC too large

	reg [W-1:0] SM;								// W-bit signed-magnitude number
	wire [6:0] SMSign;						// 7-segment for sign
	wire [6:0] SMD2, SMD1, SMD0;	// 7-segment for magnitude digits
	wire SMTooLarge;							// SM too large


	Binary_to_7SEG #(.W(W)) TCDisplay(TC, 1, TCSign, TCD2, TCD1, TCD0, TCTooLarge);
	Binary_to_7SEG #(.W(W)) SMDisplay(SM, 0, SMSign, SMD2, SMD1, SMD0, SMTooLarge);
	
	initial
	begin
		TC = 'd725; SM = 'd725;
		#1;
//
		TC = - 'd3;  SM = 'b10000000011;
		#1;
		TC = 'd1000; SM = 'd1000;
		#TC;
//
	end
endmodule