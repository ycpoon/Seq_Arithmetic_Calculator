// Number Conversion from two's complement to signed-magnitude
module TC2SM
	#(parameter width = 11)
	(
		input [width-1:0] TC, 
		output [width-1:0] SM,
		output Overflow
	);

	wire [width-1:0] Magnitude;
	assign Magnitude =
		TC[width-1] ?																											// If TC is negative
			~(TC[width-1:0]) + 1'b1 : 																	//   Flip bits and add 1
         TC; 																															//   Else SM is positive and SM = TC
				 
	assign SM = {TC[width-1], Magnitude[width-2:0]};		// Prepend sign
  assign Overflow = TC[width-1] & ~TC[width-2:0];		// Most negative TC number
																																						// Alternatively, Overflow = Magnitude[width-1]
endmodule // TC2SM