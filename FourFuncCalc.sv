module FourFuncCalc
  #(parameter W = 11)             // Default bit width
  (
    input Clock,
    input Clear,                   // C button
    input Equals,                  // = button: displays result so far
    input Add,                     // + button
    input Subtract,                // - button
    input Multiply,                // x button (times)
    input Divide,                  // / button (division quotient)
    input [W-1:0] Number,          // Must be entered in signed-magnitude on SW[W-1:0]
    output signed [W-1:0] Result,  // Calculation result in two's complement
    output Overflow,               // Indicates result can't be represented in W bits 
    output [4:0] state,
    output [W-1:0] debug
  );
  localparam WW = 2 * W;           // Double width for Booth multiplier
  localparam BoothIter = $clog2(W);// Width of Booth Counter

  
//****************************************************************************************************
// Datapath Components
//****************************************************************************************************


//----------------------------------------------------------------------------------------------------
// Registers
//----------------------------------------------------------------------------------------------------
	
  reg signed [W-1:0] A;			// Accumulator
  wire CLR_A, LD_A;			// CLR_A: A <= 0; LD_A: A <= Q
  
  reg signed [W-1:0] N_TC;
  wire CLR_NTC, LD_NTC;
  
  reg signed [W-1:0] N_SM;
  wire CLR_NSM, LD_NSM;
  
  reg signed [WW+1:0] PM;
  wire M_LD, P_LD, PM_ASR;
  
  reg [BoothIter-1:0] MCTR;
  wire MCTR_DN, RST_MCTR;
  
  reg [W-1:0] D;
  wire LD_D, CLR_D;
  
  reg [W-2:0] QCounter;
  wire QC_UP, CLR_QC;
  

  
//----------------------------------------------------------------------------------------------------
// Number Converters
// Instantiate the three number converters following the example of SM2TC1
//----------------------------------------------------------------------------------------------------

  wire signed [W-1:0] NumberTC;	// Two's complement of Number
  SM2TC #(.width(W)) SM2TC1(Number, NumberTC);
  
  wire [W-1:0] D_SM;
  wire dummy;
  TC2SM #(.width(W)) TC2SM1(A, D_SM, dummy);
  
  wire QSgn;
  assign QSgn = A[W-1] ^ Number[W-1];
  
  wire [W-1:0] QC;
  assign QC = {QSgn, QCounter};
  
  wire [W-1:0] Q_TC;
  SM2TC #(.width(W)) SM2TC2(QC, Q_TC);
  
  wire [W-1:0] ABS_N_SM;
  assign ABS_N_SM = {1'b0, N_SM[W-2:0]};
  
  wire [W-1:0] ABS_D_SM;
  assign ABS_D_SM = {1'b0, D_SM[W-2:0]};


//----------------------------------------------------------------------------------------------------
// MUXes
//----------------------------------------------------------------------------------------------------
  

  wire signed [W-1:0] Y1, Y2, Y3, Y4, Y5, Y6, Y7, R; 
  
  wire SEL_D;
  assign Y3 = SEL_D ? D : A;
  
  wire SEL_P;
  assign Y1 = SEL_P ? PM[WW:W+1] : Y3;
  
  assign Y2 = SEL_D ? ABS_N_SM : N_TC;
  
  wire SEL_A;
  assign Y7 = SEL_A ? ABS_D_SM : R;
  
  wire SEL_M;
  assign Y4 = SEL_M ? PM[W:1] : R;
  
  wire SEL_Q;
  assign Y5 = SEL_Q ? Q_TC : Y4;
  
  wire SEL_N;
  assign Y6 = SEL_N ? Y2 : Y5;
  
  
//----------------------------------------------------------------------------------------------------
// Adder/Subtractor 
//----------------------------------------------------------------------------------------------------

	wire c0;					// 0: Add, 1: Subtract
	wire ovf;					// Overflow
	AddSub #(.W(W)) AddSub1(Y1, Y2, c0, R, ovf);

  
//----------------------------------------------------------------------------------------------------
// Multiplication Wires
//----------------------------------------------------------------------------------------------------

  wire Movf;
  wire [W:0] ALLONES = ~0;
  assign Movf = (PM[WW:W] !== 'd0) &&  (PM[WW:W] !== ALLONES);
  
  wire PSgn;
  assign PSgn = R[W-1] ^ ovf;
  

//****************************************************************************************************
/* Datapath Controller */
//****************************************************************************************************


//----------------------------------------------------------------------------------------------------
// Controller State and State Labels
//----------------------------------------------------------------------------------------------------

  reg [4:0] X, X_Next;

  localparam XInit		= 5'd0;	// Power-on state (A == 0)
  localparam XClear		= 5'd1;		// Pick numeric assignments
  localparam XLoadN		= 5'd2;
  localparam XLoadA		= 5'd3;
  localparam XResult	= 5'd4;
  localparam XOvf		= 5'd5;
  localparam XAdd		= 5'd6;
  localparam XALoadN	= 5'd7;
  localparam XDoAdd		= 5'd8;
  localparam XSub		= 5'd9;
  localparam XSLoadN	= 5'd10;
  localparam XDoSub		= 5'd11;
  localparam XMul		= 5'd12;
  localparam XMLoad		= 5'd13;
  localparam XMCheck	= 5'd14;
  localparam XMAdd		= 5'd15;
  localparam XMSub		= 5'd16;
  localparam XMNext		= 5'd17;
  localparam XMMore		= 5'd18;
  localparam XDiv		= 5'd19;
  localparam XDLoad		= 5'd20;
  localparam XDCheck	= 5'd21;
  localparam XDSub		= 5'd22;
  localparam XDMore		= 5'd23;
	

//----------------------------------------------------------------------------------------------------
// Controller State Transitions
//----------------------------------------------------------------------------------------------------

	always @*
	case (X)
		XInit:
          if (Clear)
              X_Next <= XInit;
          else if (Equals)
              X_Next <= XLoadN;
          else if (Add)
              X_Next <= XAdd;
          else if (Subtract)
              X_Next <= XSub;
          else if (Multiply)
              X_Next <= XMul;
          else if (Divide)
              X_Next <= XDiv;
          else
              X_Next <= XInit;
      
      XClear:
        X_Next <= XInit;
      
      XLoadN:
        X_Next <= XLoadA;
      
      XLoadA:
        X_Next <= XResult;
      
      XResult:
        if(Add)
          	X_Next <= XAdd;
        else if (Subtract)
            X_Next <= XSub;
        else if (Multiply)
            X_Next <= XMul;
        else if (Divide)
            X_Next <= XDiv;
        else
            X_Next <= XResult;
      
      XOvf:
        if(Clear)
          	X_Next <= XClear;
      	else 
          	X_Next <= XOvf;
      
      XAdd:
        if (Equals)
            X_Next <= XALoadN;
        else if (Add)
            X_Next <= XAdd;
        else if (Subtract)
            X_Next <= XSub;
        else if (Multiply)
            X_Next <= XMul;
        else if (Divide)
            X_Next <= XDiv;
        else
            X_Next <= XAdd;
      
      XALoadN:
        X_Next <= XDoAdd;
      
      XDoAdd:
        if(ovf)
          	X_Next <= XOvf;
      	else
          	X_Next <= XResult;
      
      XSub:
        if (Equals)
            X_Next <= XSLoadN;
        else if (Add)
            X_Next <= XAdd;
        else if (Subtract)
            X_Next <= XSub;
        else if (Multiply)
            X_Next <= XMul;
        else if (Divide)
            X_Next <= XDiv;
        else
            X_Next <= XSub;
      
      XSLoadN:
        X_Next <= XDoSub;
      
      XDoSub:
        if(ovf)
          	X_Next <= XOvf;
      	else
          	X_Next <= XResult;
      
      XMul:
        if (Equals)
            X_Next <= XMLoad;
        else if (Add)
            X_Next <= XAdd;
        else if (Subtract)
            X_Next <= XSub;
        else if (Multiply)
            X_Next <= XMul;
        else if (Divide)
            X_Next <= XDiv;
        else
            X_Next <= XMul;
      
      XMLoad:
        X_Next <= XMCheck;
      
      XMCheck:
        if(~PM[1] && PM[0])
          	X_Next <=  XMAdd;
      	else if (PM[1] && ~ PM[0])
        	X_Next <= XMSub;
      	else
          	X_Next <= XMNext;
      
      XMAdd:
        X_Next <= XMNext;
      
      XMSub:
        X_Next <= XMNext;
      
      XMNext:
        X_Next <= XMMore;
      
      XMMore:
        if(MCTR == 'd0)
          if(Movf)
            X_Next <= XOvf;
      	  else
            X_Next <= XResult;
      	else
          X_Next <= XMCheck;
      
      XDiv:
        if (Equals)
            X_Next <= XDLoad;
        else if (Add)
            X_Next <= XAdd;
        else if (Subtract)
            X_Next <= XSub;
        else if (Multiply)
            X_Next <= XMul;
        else if (Divide)
            X_Next <= XDiv;
        else
            X_Next <= XDiv;
      
      XDLoad:
        X_Next <= XDCheck;
      
      XDCheck:
        if(D < ABS_N_SM)
          X_Next <= XDMore;
      	else
          X_Next <= XDSub;
      
      XDSub:
        X_Next <= XDMore;
      
      XDMore:
        if(D < ABS_N_SM)
          X_Next <= XResult;
      	else
          X_Next <= XDSub;
        
	endcase
  
  
//----------------------------------------------------------------------------------------------------
// Initial state on power-on
//----------------------------------------------------------------------------------------------------

  initial begin
    X <= XClear;
    A <= 'd0;
    N_TC <= 'd0;
    N_SM <= 'd0;
    MCTR <= W;		//BoothIter'dW;
    PM <= 'd0;      			//WW+1'd0;
    D <= 'd0;
    QCounter <= 'd0;
  end


//----------------------------------------------------------------------------------------------------
// Controller Commands to Datapath
//----------------------------------------------------------------------------------------------------
	
  assign CLR_A = (X == XClear);
  assign LD_A = (X == XLoadA) || (X == XDoAdd) || (X == XDoSub) || ((X == XMMore) && (X_Next != XMCheck)) || ((X == XDMore) && (X_Next != XDSub));
  
  assign CLR_NTC = (X == XClear);
  assign LD_NTC = (X == XLoadN) || (X == XALoadN) || (X == XSLoadN) || (X == XMLoad);
  
  assign CLR_NSM = (X == XClear);
  assign LD_NSM = (X == XDLoad);
  
  assign M_LD = (X == XMLoad);
  assign P_LD = (X == XMAdd) || (X == XMSub);
  assign PM_ASR = (X == XMNext);
  
  assign MCTR_DN = (X == XMNext);
  assign RST_MCTR = (X == XClear) || (X == XMLoad);
  
  assign CLR_D = (X == XClear);
  assign LD_D = (X == XDLoad) || (X == XDSub);
  
  assign QC_UP = (X == XDSub);
  assign CLR_QC = (X == XClear) || (X == XDLoad);
  
  
  // Mux
  
  assign SEL_D = (X == XDSub);
  
  assign SEL_P = (X == XMAdd) || (X == XMSub);
  
  assign SEL_A = (X == XDLoad);
  
  assign SEL_M = (X == XMMore);
  
  assign SEL_Q = (X == XDMore);
  
  assign SEL_N = (X == XLoadA);
  
  
  //c0
  
  assign c0 = (X == XDoSub) || (X == XMSub) || (X == XDSub);
  

//----------------------------------------------------------------------------------------------------  
// Controller State Update
//----------------------------------------------------------------------------------------------------

	always @(posedge Clock)
		if (Clear)
			X <= XClear;
		else
			X <= X_Next;

      
//----------------------------------------------------------------------------------------------------
// Datapath State Update
//----------------------------------------------------------------------------------------------------
	
  
  wire signed [W:0] ZERO;
  assign ZERO = 'd0;
  
  always @(posedge Clock)
  begin
    if(Clear) begin
      A <= 'd0;
      N_TC <= 'd0;
      N_SM <= 'd0;
      MCTR <= W;	
      PM <= 'd0;      			
      D <= 'd0;
      QCounter <= 'd0;
    end else begin
      A <= LD_A ? Y6 : A;
      N_TC <= LD_NTC ? NumberTC : N_TC;
      N_SM <= LD_NSM ? Number : N_SM;
      PM <= (M_LD ? $signed({ZERO, A, 1'b0}) : (P_LD ? $signed({PSgn, R, PM[W:0]}) : (PM_ASR ? PM >>> 1 : PM)));
      MCTR <= RST_MCTR ? W : (MCTR_DN ? MCTR - 1'b1 : MCTR);
      D <= LD_D ? Y7 : D;
      QCounter <= CLR_QC ? 'd0 : (QC_UP ? QCounter + 1'b1 : QCounter);
  end
  end

 
//---------------------------------------------------------------------------------------------------- 
// Calculator Outputs
//----------------------------------------------------------------------------------------------------
  
  assign Result = A;
  assign Overflow = (X == XOvf);
  assign state = X;
  assign debug = PM[WW:W+1];

endmodule // FourFuncCalc