module AddSub
	#(parameter W = 16)			// Default width
	(
		input [W-1:0] A, B,				// W-bit unsigned inputs
		input c0,											// Carry-in
		output [W-1:0] S,					// W-bit unsigned output
		output ovf										// Overflow signal
	);
	
	wire [W:0] c;									// Carry signals
	assign c[0] = c0;

// Instantiate and "chain" W full adders 
	genvar i;
	generate
		for (i = 0; i < W; i = i + 1)
			begin: RCAddSub
				FullAdder FA(A[i], B[i] ^ c[0], c[i], S[i], c[i+1]);
			end
	endgenerate

// Overflow
		assign ovf = c[W-1] ^ c[W];
endmodule // AddSub