// Number Conversion from signed-magnitude to two's complement
module SM2TC
	#(parameter width = 11)
	(input [width-1:0] SM,
	 output [width-1:0] TC
	);

	wire [width-2:0] Magnitude;														// Magnitude
	assign Magnitude = ~(SM[width-2:0]) + 'b1; 		// Flip bits and add 1
 	assign TC =
		SM[width-1] ?																							// If SM is negative
		(Magnitude == 0 ?																			//   And is negative zero
			'd0 :																												//     Convert it to "positive" zero          
			{1'b1, Magnitude}																		//     Else prepend negative sign
		) :         
		SM;                     																			// Else TC = SM since number is positive
endmodule // SM2TC