
/////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2014 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROPRIETARY TO PANGO MICROSYSTEMS, INC.
// IT SHALL NOT BE REPRODUCED OR DISCLOSED IN WHOLE OR IN PART OR USED BY
// PARTIES WITHOUT WRITTEN AUTHORIZATION FROM THE OWNER.
//
//////////////////////////////////////////////////////////////////////////////
//
// Library:
// Filename:TB mul_tb.v
//////////////////////////////////////////////////////////////////////////////


`timescale 1ns/1ps
module mul_tb();

localparam  T_CLK_PERIOD       = 10     ;       //clock a half perid
localparam  T_RST_TIME         = 200    ;       //reset time
localparam  T_SIM_TIME         = 100000 ;       //simulation time


localparam ASIZE = 25 ; //@IPC int 2,82

localparam BSIZE = 9 ; //@IPC int 2,82

localparam A_SIGNED = 1 ; //@IPC enum 0,1

localparam B_SIGNED = 1 ; //@IPC enum 0,1

localparam ASYNC_RST = 0 ; //@IPC enum FALSE,TRUE

localparam OPTIMAL_TIMING = 0 ; //@IPC enum 0,1

localparam INREG_EN = 0 ; //@IPC enum 0,1

localparam PIPEREG_EN_1 = 1 ; //@IPC enum 0,1

localparam PIPEREG_EN_2 = 0 ; //@IPC enum 0,1

localparam PIPEREG_EN_3 = 0 ; //@IPC enum 0,1

localparam OUTREG_EN = 0 ; //@IPC enum 0,1

//tmp variable for ipc purpose

localparam PIPE_STATUS = 1 ; //@IPC enum 0,1,2,3,4,5

localparam ASYNC_RST_BOOL = 0 ; //@IPC bool

localparam OPTIMAL_TIMING_BOOL = 0 ; //@IPC bool

localparam ADVANCED_BOOL       = 0 ; //@IPC bool

//end of tmp variable
localparam  PSIZE        =   ASIZE + BSIZE           ;


localparam ASIZE_SIGNED  = (A_SIGNED == 1) ? ASIZE : (ASIZE + 1);

localparam BSIZE_SIGNED  = (B_SIGNED == 1) ? BSIZE : (BSIZE + 1);

localparam MAX_DATA_SIZE = (ASIZE_SIGNED >= BSIZE_SIGNED) ? ASIZE_SIGNED : BSIZE_SIGNED;

localparam MIN_DATA_SIZE = (ASIZE_SIGNED <  BSIZE_SIGNED) ? ASIZE_SIGNED : BSIZE_SIGNED;


// variable declaration
reg                 clk         ;
reg                 rst         ;
reg                 ce          ;
reg  [ASIZE-1:0]    a           ;
reg  [BSIZE-1:0]    b           ;
wire [PSIZE-1:0]    p           ;

wire [154:0]        a_ext       ;
wire [154:0]        b_ext       ;
wire [308:0]        p_ext       ;

reg  [PSIZE-1:0]    p_ext_ff1   ;
reg  [PSIZE-1:0]    p_ext_ff2   ;
reg  [PSIZE-1:0]    p_ext_ff3   ;
reg  [PSIZE-1:0]    p_ext_ff4   ;
reg  [PSIZE-1:0]    p_ext_ff5   ;

wire [PSIZE-1:0]    p_mult      ;
wire [PSIZE-1:0]    p_check     ;

reg      pass;
integer  result_fid;

always #T_CLK_PERIOD clk = ~clk;


always@(negedge clk or posedge rst)
begin
    if(rst)
        ce <= 1'b1;
    else
        ce <= $random;
end


initial
begin
    clk = 1'b1;
    rst = 1'b1;
    #T_RST_TIME
    rst = 1'b0;
end

initial begin
    a    = {ASIZE{1'b0}};
    b    = {BSIZE{1'b0}};
end

GTP_GRS   GRS_INST( .GRS_N(1'b1) );

always@(posedge clk)
begin

    a <= {$random,$random,$random};
    b <= {$random,$random,$random};

end

initial begin
    $display("Simulation Starts ...\n");
    result_fid = $fopen ("sim_results.log","a");
    #T_SIM_TIME;
    $display("Simulation is done.\n");
    if (pass == 1)
        $display("Simulation Success!\n");
    else
        $display("Simulation Failed!\n");
    $finish;
end


assign a_ext = {{(155-ASIZE){a[ASIZE-1]&&A_SIGNED}},a[ASIZE-1:0]};
assign b_ext = {{(155-BSIZE){b[BSIZE-1]&&B_SIGNED}},b[BSIZE-1:0]};

assign p_ext = a_ext * b_ext;

always@(posedge clk or posedge rst)
begin
    if (rst)
    begin

        p_ext_ff1 <= {PSIZE{1'b0}};
        p_ext_ff2 <= {PSIZE{1'b0}};
        p_ext_ff3 <= {PSIZE{1'b0}};
        p_ext_ff4 <= {PSIZE{1'b0}};
        p_ext_ff5 <= {PSIZE{1'b0}};

    end
    else if(ce)
    begin

        p_ext_ff1 <= p_ext[PSIZE-1:0];
        p_ext_ff2 <= p_ext_ff1;
        p_ext_ff3 <= p_ext_ff2;
        p_ext_ff4 <= p_ext_ff3;
        p_ext_ff5 <= p_ext_ff4;

    end
end
assign p_mult = (PIPE_STATUS == 0 ) ? p_ext[PSIZE-1:0] :
                (PIPE_STATUS == 1 ) ? p_ext_ff1 :
                (PIPE_STATUS == 2 ) ? p_ext_ff2 :
                (PIPE_STATUS == 3 ) ? p_ext_ff3 :
                (PIPE_STATUS == 4 ) ? p_ext_ff4 : p_ext_ff5 ;

assign p_check = p_mult;

always @(posedge clk or posedge rst)
begin
    if(rst)
        pass <= 1'b1;
    else if ( p_check !== p)
    begin
        $display("mult error! mult data = %h, product = %h",p_check,p);
        $fdisplay(result_fid, "err_chk=1");
        pass <= 1'b0;
    end
end

//***************************************************************** DUT  INST ********************************************************************************
mul  U_mul
    (
	.ce     (ce),
	.rst    (rst),
	.clk    (clk),
	.a      (a),
	.b      (b),
	.p      (p)
    );
endmodule
