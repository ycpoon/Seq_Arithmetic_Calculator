// Clocking
// Clock Divider by Powers of 2 (Table of frequencies and periods at EOF)
module Clock_Div
	#(parameter SIZE = 36)	// divides by 2^i for i = 0 to i = 36
	(
		input CLK_in,
		output [SIZE:0] CLKS_out
	);
	
	reg [SIZE:1] Counter;
	initial Counter = 'd0;
	
	always @(posedge CLK_in)
		Counter <= Counter + 1;

	assign CLKS_out = {Counter, CLK_in};
endmodule // Clock_Div

/* Clock fequency and period
   at various taps of CLKS_OUT

	              Frequency		   Period
______________________________________
CLOCK_50[0]     50.00	MHz	  20.00	ns
CLKS_out[1]     25.00	MHz     40.00	ns
CLKS_out[2]	    12.50	MHz     80.00	ns
CLKS_out[3]      6.25	MHz    160.00	ns
CLKS_out[4]      3.13	MHz    320.00	ns
CLKS_out[5]	     1.56	MHz	 640.00	ns
CLKS_out[6]	   781.25	KHz	   1.28	us
CLKS_out[7]	   390.63	KHz	   2.56	us
CLKS_out[8]	   195.31	KHz	   5.12	us
CLKS_out[9]	    97.66	KHz	  10.24	us
CLKS_out[10]    48.83	KHz	  20.48	us
CLKS_out[11]	  24.41	KHz	   40.96	us
CLKS_out[12]	  12.21	KHz	   81.92	us
CLKS_out[13]	   6.10	KHz	  163.84	us
CLKS_out[14]	   3.05	KHz	  327.68	us
CLKS_out[15]	   1.53	KHz	  655.36	us
CLKS_out[16]   762.94	Hz	     	 1.31	ms
CLKS_out[17]	 381.47	Hz	       2.62	ms
CLKS_out[18]	 190.73	Hz	       5.24	ms
CLKS_out[19]	  95.37	Hz	      10.49	ms
CLKS_out[20]	  47.68	Hz	      20.97	ms
CLKS_out[21]	  23.84	Hz       41.94	ms
CLKS_out[22]	  11.92	Hz	      83.89	ms
CLKS_out[23]	   5.96	Hz	     167.77	ms
CLKS_out[24]	   2.98	Hz	     335.54	ms
CLKS_out[25]	   1.49	Hz      671.09	ms
CLKS_out[26]   745.06	milliHz	 1.34	sec
CLKS_out[27]	 372.53	milliHz	 2.68	sec
CLKS_out[28]	 186.26	milliHz	 5.37	sec
CLKS_out[29]	  93.13	milliHz	10.74	sec
CLKS_out[30]	  46.57	milliHz	21.47	sec
CLKS_out[31]	  23.28	milliHz	42.95	sec
CLKS_out[32]	  11.64	milliHz	 1.43	min
CLKS_out[33]	  5.82	milliHz	 2.86	min
CLKS_out[34]	  2.91	milliHz	 5.73	min
CLKS_out[35]	  1.46	milliHz	11.45	min
CLKS_out[36]	  0.73  milliHz	22.91	min
*/