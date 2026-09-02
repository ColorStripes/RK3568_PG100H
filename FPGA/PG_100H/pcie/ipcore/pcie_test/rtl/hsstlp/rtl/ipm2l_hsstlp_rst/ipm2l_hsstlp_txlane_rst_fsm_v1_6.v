///////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2019 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROPRIETARY TO PANGO MICROSYSTEMS, INC.
// IT SHALL NOT BE REPRODUCED OR DISCLOSED IN WHOLE OR IN PART OR USED BY
// PARTIES WITHOUT WRITTEN AUTHORIZATION FROM THE OWNER.
//
///////////////////////////////////////////////////////////////////////////////
//
// Library:
// Filename:
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
module  ipm2l_hsstlp_txlane_rst_fsm_v1_6#(
    parameter LANE_BONDING                = 1  , //enable bonding : 2 or 4 , disable bonding : 1
    parameter FREE_CLOCK_FREQ             = 100, //unit is MHz, free clock  freq from GUI
    parameter P_LX_TX_CKDIV               = 0  ,  //initial params
    parameter PCS_TX_CLK_EXPLL_USE_CH     =  "FALSE"     
)(
    // Reset and Clock
    input  wire                   clk                   ,
    input  wire                   rst_n                 ,
    // HSST Reset Control Signal
    input  wire                   i_tx_rate_chng     ,
    input  wire   [2:0]           i_txckdiv             ,
    input  wire                   i_pll_lock_tx         ,
    input  wire                   i_txlane_rst_n       ,
        //not support
    //input  wire                   P_CA_ALIGN_TX         ,
    output reg                    P_TX_LANE_PD_CLKPATH  ,
    output reg                    P_TX_LANE_PD_DRIVER   ,
    output reg                    P_TX_LANE_PD_PISO     ,
    output reg    [2:0]           P_TX_RATE             ,
    output reg                    P_TX_PMA_RST          , 
    output reg                    P_PCS_TX_RST          ,
    output reg                    o_txlane_done         ,
    output reg                    lane_sync             ,
    output reg                    rate_change_on        ,
    output reg                    o_txckdiv_done       
);

localparam         CNTR_WIDTH                        = 9;
//TX Lane Power Up
localparam integer TX_PMA_RST_CNTR_VALUE             = 2*(0.5*FREE_CLOCK_FREQ);//add 50 percent margin 
localparam integer TX_LANE_PD_PISO_CNTR_POS_VALUE    = 2*(1*FREE_CLOCK_FREQ);//add 50 percent margin   
localparam integer TX_LANE_PD_DRIVER_CNTR_POS_VALUE  = 2*(1.5*FREE_CLOCK_FREQ);//add 50 percent margin  
localparam integer TX_PCS_RST_CNTR_VALUE             = 2*(0.5*FREE_CLOCK_FREQ);//add 50 percent margin  
localparam integer TX_RST_DONE_DLY_CNTR_VALUE        = 32;//add for txlane_done is active but fabric clock is none by wenbin at @2019.9.26
//TX LANE SYNC
localparam integer TX_LANE_SYNC_CNTR_F_VALUE         = 2*(0.1*FREE_CLOCK_FREQ);//add 50 percent margin
//TX Lane Rate Change
localparam integer TX_RATE_CHANGE_ON_CNTR_F_VALUE    = 2*(0.1*FREE_CLOCK_FREQ);//add 50 percent margin      
localparam integer TX_RATE_CHANGE_SYNC_CNTR_R_VALUE  = 2*(0.3*FREE_CLOCK_FREQ);//add 50 percent margin      
localparam integer TX_RATE_CNTR_VALUE                = 2*(0.35*FREE_CLOCK_FREQ);//add 50 percent margin     
localparam integer TX_RATE_CHANGE_SYNC_CNTR_F_VALUE  = 2*(0.4*FREE_CLOCK_FREQ);//add 50 percent margin     
localparam integer TX_RATE_CHANGE_PMA_CNTR_F_VALUE   = 2*(0.45*FREE_CLOCK_FREQ);//add 50 percent margin    
localparam integer TX_RATE_CHANGE_ON_CNTR_R_VALUE    = 2*(0.65*FREE_CLOCK_FREQ);//add 50 percent margin  

//TX Lane FSM Status
localparam TX_LANE_IDLE   = 3'd0;
localparam TX_LANE_PMA    = 3'd1;
localparam TX_LANE_SYNC   = 3'd2;
localparam TX_LANE_PCS    = 3'd3;
localparam TX_DONE        = 3'd4;
localparam TX_CKDIV_ONLY  = 3'd5;
localparam TX_LANE_RST    = 3'd6;
//****************************************************************************//
//                      Internal Signal                                       //
//****************************************************************************//
reg     [CNTR_WIDTH-1 : 0] cntr             ;
reg     [2            : 0] txlane_rst_fsm   ;
reg     [2            : 0] next_state       ;
reg     [1            : 0] i_tx_rate_chng_ff    ;
reg                       i_tx_rate_chng_posedge   ;
reg     [2            : 0] i_txckdiv_ff         ;
reg     [2            : 0] txckdiv              ;
//wire                       clk_align_rx     ;   //clk_aligner
wire                       expll_lock_tx    ;

//****************************************************************************//
//                      Sequential and Logic                                  //
//****************************************************************************//
assign expll_lock_tx = (PCS_TX_CLK_EXPLL_USE_CH  ==  "FALSE") ? 1'b1 : i_pll_lock_tx ;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        i_tx_rate_chng_ff     <= 2'b0;
    else 
        i_tx_rate_chng_ff     <= {i_tx_rate_chng_ff[0],i_tx_rate_chng};
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        i_tx_rate_chng_posedge     <= 1'b0;
    else if (txlane_rst_fsm == TX_CKDIV_ONLY)
        i_tx_rate_chng_posedge     <= 1'b0;
    else if (i_tx_rate_chng_ff[0] & (!i_tx_rate_chng_ff[1]))
        i_tx_rate_chng_posedge     <= 1'b1;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        i_txckdiv_ff     <= 3'b000;
    else 
        i_txckdiv_ff     <= i_txckdiv;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        txckdiv                  <= 3'b000;
    else if (!i_tx_rate_chng_posedge && i_tx_rate_chng_ff[0] && (!i_tx_rate_chng_ff[1]) && txlane_rst_fsm != TX_CKDIV_ONLY)
        txckdiv                  <= i_txckdiv_ff;
    else ;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        txlane_rst_fsm     <=   TX_LANE_IDLE   ;
    end
    else begin
        txlane_rst_fsm     <=   next_state ;
    end
end

always@(*) begin
    case(txlane_rst_fsm)
        TX_LANE_IDLE    :
            next_state      = TX_LANE_PMA     ;
        TX_LANE_PMA     :
        begin
            if(cntr == TX_LANE_PD_DRIVER_CNTR_POS_VALUE)
            begin
                if(LANE_BONDING != 1)
                    next_state    =    TX_LANE_SYNC    ;
                else if (expll_lock_tx)
                    next_state    =    TX_LANE_PCS     ;
                else
                    next_state    =    TX_LANE_PMA     ;
            end
            else
                next_state    =    TX_LANE_PMA     ;
        end
        TX_LANE_SYNC    :
        begin
            if(!i_txlane_rst_n)                
                next_state    =    TX_LANE_RST     ;
            else if(expll_lock_tx && (cntr == TX_LANE_SYNC_CNTR_F_VALUE))
                next_state    =    TX_LANE_PCS     ;
            else
                next_state    =    TX_LANE_SYNC    ;
        end
        TX_LANE_PCS     :
        begin
            if (!i_txlane_rst_n)
                next_state    =    TX_LANE_RST     ;      
            else if(cntr == (TX_PCS_RST_CNTR_VALUE + TX_RST_DONE_DLY_CNTR_VALUE))   
                next_state    =    TX_DONE     ;
            else
                next_state    =    TX_LANE_PCS     ;
        end
        TX_DONE    :
        begin
            if(!i_txlane_rst_n)                         
                next_state    =    TX_LANE_RST      ;
            else if(i_tx_rate_chng_posedge)
                next_state    =    TX_CKDIV_ONLY     ;
            else
                next_state    =    TX_DONE     ;
        end
        TX_CKDIV_ONLY    :
        begin
            if(!i_txlane_rst_n)                        
                next_state    =    TX_LANE_RST      ;
            else if(cntr == TX_RATE_CHANGE_ON_CNTR_R_VALUE)
                next_state    =    TX_LANE_PCS     ;
            else
                next_state    =    TX_CKDIV_ONLY     ;
        end
        TX_LANE_RST     :
        begin
            if(!i_txlane_rst_n)
                next_state    =    TX_LANE_RST      ;
            else if(cntr == TX_LANE_PD_DRIVER_CNTR_POS_VALUE) begin
                if(LANE_BONDING != 1)
                    next_state  =   TX_LANE_SYNC    ;
                else if(expll_lock_tx)
                    next_state  =   TX_LANE_PCS     ;
                else
                    next_state  =   TX_LANE_RST     ; 
            end
            else 
                next_state   =   TX_LANE_RST        ;
        end
        default    :
        begin
            next_state    =    TX_LANE_IDLE     ;
        end
    endcase
end

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n) 
    begin
        cntr                   <= {CNTR_WIDTH{1'b0}};
        P_TX_LANE_PD_CLKPATH   <= 1'b1;
        P_TX_PMA_RST           <= 1'b1; 
        P_TX_LANE_PD_PISO      <= 1'b1;
        P_TX_LANE_PD_DRIVER    <= 1'b1;
        lane_sync              <= 1'b0;   
        rate_change_on         <= 1'b1;
        P_TX_RATE              <= P_LX_TX_CKDIV;
        P_PCS_TX_RST           <= 1'b1;
        o_txlane_done          <= 1'b0; 
        o_txckdiv_done         <= 1'b0; 
    end
    else
    begin
        case(txlane_rst_fsm)
            TX_LANE_IDLE    :
            begin
                cntr                   <= {CNTR_WIDTH{1'b0}};
                P_TX_LANE_PD_CLKPATH   <= 1'b1;
                P_TX_PMA_RST           <= 1'b1; 
                P_TX_LANE_PD_PISO      <= 1'b1;
                P_TX_LANE_PD_DRIVER    <= 1'b1;
                lane_sync              <= 1'b0;
                rate_change_on         <= 1'b1;
                P_TX_RATE              <= P_LX_TX_CKDIV;
                P_PCS_TX_RST           <= 1'b1;
                o_txlane_done          <= 1'b0; 
                o_txckdiv_done         <= 1'b0;
            end
            TX_LANE_PMA    :
            begin
                if(cntr == TX_LANE_PD_DRIVER_CNTR_POS_VALUE)    
                begin
                    if((LANE_BONDING != 1) || expll_lock_tx)     
                        cntr                   <= {CNTR_WIDTH{1'b0}};
                    else
                        cntr                   <= TX_LANE_PD_DRIVER_CNTR_POS_VALUE;
                    P_TX_LANE_PD_DRIVER    <= 1'b0;
                end
                else
                begin
                    if(cntr == TX_LANE_PD_PISO_CNTR_POS_VALUE)   
                        P_TX_LANE_PD_PISO   <= 1'b0 ;
                    else if (cntr == TX_PMA_RST_CNTR_VALUE)     
                        P_TX_PMA_RST    <= 1'b0 ;
                    P_TX_LANE_PD_CLKPATH    <= 1'b0 ;
                    cntr                    <= cntr + {{CNTR_WIDTH-1{1'b0}},{1'b1}};
                end
            end
            TX_LANE_SYNC    :
            begin
                if(!i_txlane_rst_n)                     
                begin
                    cntr                   <= {CNTR_WIDTH{1'b0}};
                    lane_sync              <= 1'b0;
                end
                else if(cntr == TX_LANE_SYNC_CNTR_F_VALUE)
                begin
                    if(expll_lock_tx)
                        cntr                   <= {CNTR_WIDTH{1'b0}};
                    else
                        cntr                   <= TX_LANE_SYNC_CNTR_F_VALUE;
                    lane_sync                  <= 1'b0 ;
                end
                else
                begin
                    lane_sync    <= 1'b1 ;
                    cntr         <= cntr + {{CNTR_WIDTH-1{1'b0}},{1'b1}};
                end
            end
            TX_LANE_PCS    :
            begin
                if(!i_txlane_rst_n)     
                    cntr         <= {CNTR_WIDTH{1'b0}};
                else if(cntr == (TX_PCS_RST_CNTR_VALUE + TX_RST_DONE_DLY_CNTR_VALUE))    
                    cntr         <= {CNTR_WIDTH{1'b0}};
                else
                begin
                    if(cntr == TX_PCS_RST_CNTR_VALUE)
                        P_PCS_TX_RST    <= 1'b0 ;
                    cntr         <= cntr + {{CNTR_WIDTH-1{1'b0}},{1'b1}};
                end
            end
            TX_DONE    :
            begin
                o_txlane_done    <= 1'b1 ;
                cntr                <= {CNTR_WIDTH{1'b0}};
            end
            TX_CKDIV_ONLY    :
            begin
                if(!i_txlane_rst_n)        
                begin
                    cntr                <= {CNTR_WIDTH{1'b0}};
                    rate_change_on      <= 1'b1 ;
                    lane_sync           <= 1'b0 ;                    
                end
                else if(cntr == TX_RATE_CHANGE_ON_CNTR_R_VALUE)
                begin
                    cntr                <= {CNTR_WIDTH{1'b0}};
                    o_txckdiv_done      <= 1'b1 ;
                    rate_change_on      <= 1'b1 ;
                end
                else
                begin
                    if(cntr == TX_RATE_CHANGE_PMA_CNTR_F_VALUE)
                        P_TX_PMA_RST    <= 1'b0 ;
                    else if (cntr == TX_RATE_CHANGE_SYNC_CNTR_F_VALUE)
                        lane_sync       <= 1'b0 ;
                    else if (cntr == TX_RATE_CNTR_VALUE)
                        P_TX_RATE       <= txckdiv ;
                    else if (cntr == TX_RATE_CHANGE_SYNC_CNTR_R_VALUE)
                    begin
                        P_TX_PMA_RST    <= 1'b1 ;
                        lane_sync       <= 1'b1 ;
                    end
                    else if (cntr == TX_RATE_CHANGE_ON_CNTR_F_VALUE)
                        rate_change_on  <= 1'b0 ;
                    cntr                <= cntr + {{CNTR_WIDTH-1{1'b0}},{1'b1}};
                    o_txckdiv_done      <= 1'b0 ;
                    o_txlane_done       <= 1'b0 ;
                    P_PCS_TX_RST        <= 1'b1 ;
                end
            end
            TX_LANE_RST    :      
            begin
                if(!i_txlane_rst_n) 
                    cntr <= {{CNTR_WIDTH-1{1'b0}},{1'b0}};
                else if(cntr < TX_LANE_PD_DRIVER_CNTR_POS_VALUE) 
                    cntr <= cntr + {{CNTR_WIDTH-1{1'b0}},{1'b1}};
                else
                    cntr <= {{CNTR_WIDTH-1{1'b0}},{1'b0}};
                
                if(!i_txlane_rst_n) 
                    P_TX_PMA_RST         <= 1'b1;
                else if(cntr == TX_PMA_RST_CNTR_VALUE) 
                    P_TX_PMA_RST         <= 1'b0;

                if(!i_txlane_rst_n)
                    P_TX_LANE_PD_PISO    <= 1'b1;
                else if(cntr == TX_LANE_PD_PISO_CNTR_POS_VALUE)
                    P_TX_LANE_PD_PISO    <= 1'b0;

                if(!i_txlane_rst_n)
                    P_TX_LANE_PD_DRIVER  <= 1'b1;
                else if(cntr == TX_LANE_PD_DRIVER_CNTR_POS_VALUE) 
                    P_TX_LANE_PD_DRIVER  <= 1'b0;

                o_txckdiv_done          <= 1'b0 ;
                o_txlane_done           <= 1'b0 ;
                P_PCS_TX_RST            <= 1'b1 ;
            end
            default    :
            begin
                cntr                   <= {CNTR_WIDTH{1'b0}};
                P_TX_LANE_PD_CLKPATH   <= 1'b1;
                P_TX_PMA_RST           <= 1'b1; 
                P_TX_LANE_PD_PISO      <= 1'b1;
                P_TX_LANE_PD_DRIVER    <= 1'b1;
                lane_sync              <= 1'b0;
                rate_change_on         <= 1'b1;
                P_TX_RATE              <= P_LX_TX_CKDIV;
                P_PCS_TX_RST           <= 1'b1;
                o_txlane_done          <= 1'b0; 
                o_txckdiv_done         <= 1'b0;
            end
        endcase
    end
end

endmodule
