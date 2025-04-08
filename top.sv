module SeqCalculator
	(
		input CLOCK_50,
		input [17:0] SW,							// SW[17]: Operation Control, SW[10:0]: signed-magnitude Number
		input [3:0] KEY,							// Operations (along with SW[17])
		output [6:0] HEX7, HEX6, HEX5, HEX4,// Number 
		output [6:0] HEX3, HEX2, HEX1, HEX0,// Result
		output [8:0] LEDG							// Overflow
	);
  
  wire [36:0] Clck_Array;
  wire clock;
  
  Clock_Div C1 (CLOCK_50, Clck_Array);
  
  assign clock = Clck_Array[0];  // 50 MHz Clock
  
  parameter W = 11;
  
  wire [W-1:0] result;
  
  FourFuncCalc #(
    .W(W)
  ) F1 (
    .Clock(clock),
    .Clear(SW[17] && ~KEY[0]),
    .Equals(SW[17] && ~KEY[3]),
    .Add(~SW[17] && ~KEY[3]),
    .Subtract(~SW[17] && ~KEY[2]),
    .Multiply(~SW[17] && ~KEY[1]),
    .Divide(~SW[17] && ~KEY[0]),
    .Number(SW[10:0]),
    .Result(result),
    .Overflow(LEDG[8])
  );
  
  // HEX Display for Number
  Binary_to_7SEG #(
    .W(W)
  ) B1 (
    .N(SW[10:0]),
    .Encoding(1'b0),
    .Sign(HEX7),
    .D2(HEX6),
    .D1(HEX5),
    .D0(HEX4)
  );
  
  // HEX Display for Output
  Binary_to_7SEG #(
    .W(W)
  ) B2 (
    .N(result),
    .Encoding(1'b0),
    .Sign(HEX3),
    .D2(HEX2),
    .D1(HEX1),
    .D0(HEX0)
  );
    
endmodule // SeqCalculator