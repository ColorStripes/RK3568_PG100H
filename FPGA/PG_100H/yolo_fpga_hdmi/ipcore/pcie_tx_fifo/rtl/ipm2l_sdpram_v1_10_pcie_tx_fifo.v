

////////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2019 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROPRIETARY TO PANGO MICROSYSTEMS, INC.
// IT SHALL NOT BE REPRODUCED OR DISCLOSED IN WHOLE OR IN PART OR USED BY
// PARTIES WITHOUT WRITTEN AUTHORIZATION FROM THE OWNER.
//
////////////////////////////////////////////////////////////////////////////////
//
// Library:
// Filename:ipm2l_sdpram.v
////////////////////////////////////////////////////////////////////////////////

module ipm2l_sdpram_v1_10_pcie_tx_fifo  #(
    parameter   c_CAS_MODE              = "18K"             ,   // "18K", "36K", "64K"
    parameter   c_WR_ADDR_WIDTH         = 10                ,
    parameter   c_WR_DATA_WIDTH         = 32                ,
    parameter   c_RD_ADDR_WIDTH         = 10                ,
    parameter   c_RD_DATA_WIDTH         = 32                ,
    parameter   c_WR_ADDR_STROBE_EN     = 0                 ,
    parameter   c_WR_CLK_EN             = 0                 ,
    parameter   c_OUTPUT_REG            = 0                 ,
    parameter   c_RD_OCE_EN             = 0                 ,
    parameter   c_FAB_REG               = 0                 ,
    parameter   c_RD_ADDR_STROBE_EN     = 0                 ,
    parameter   c_RD_CLK_EN             = 0                 ,
    parameter   c_RESET_TYPE            = "ASYNC"           ,
    parameter   c_RD_CLK_OR_POL_INV     = 0                 ,
    parameter   c_POWER_OPT             = 0                 ,
    parameter   c_INIT_FILE             = "NONE"            ,
    parameter   c_INIT_FORMAT           = "BIN"             ,
    parameter   c_WR_BYTE_EN            = 0                 ,
    parameter   c_BE_WIDTH              = 8
) (
    input   wire    [c_WR_ADDR_WIDTH-1 : 0]     wr_addr         ,
    input   wire    [c_WR_DATA_WIDTH-1 : 0]     wr_data         ,
    input   wire                                wr_en           ,
    input   wire                                wr_clk          ,
    input   wire                                wr_clk_en       ,
    input   wire                                wr_rst          ,
    input   wire    [c_BE_WIDTH-1 : 0]          wr_byte_en      ,
    input   wire                                wr_addr_strobe  ,

    input   wire    [c_RD_ADDR_WIDTH-1 : 0]     rd_addr         ,
    output  wire    [c_RD_DATA_WIDTH-1 : 0]     rd_data         ,
    input   wire                                rd_clk          ,
    input   wire                                rd_clk_en       ,
    input   wire                                rd_rst          ,
    input   wire                                rd_oce          ,
    input   wire                                rd_addr_strobe
);

localparam RST_VAL_EN = 0 ; // @IPC bool

    localparam  c_WR_BYTE_WIDTH = c_WR_BYTE_EN ? (c_WR_DATA_WIDTH/(c_BE_WIDTH==0 ? 1 : c_BE_WIDTH)) : ( (c_WR_DATA_WIDTH%9 ==0) ? 9 : (c_WR_DATA_WIDTH%8 ==0) ? 8 : 9 );
    localparam  ADDR_STROBE_EN  = (c_WR_ADDR_STROBE_EN == 1) || (c_RD_ADDR_STROBE_EN == 1);
    //c_WR_DATA_WIDTH == 2^N
    //WIDTH_RATIO = 1
    //L_DATA_WIDTH is the parameter value of DATA_WIDTH_A and DATA_WIDTH_B in a instance DRM ,define witch type DRM to instance in noraml mode
    localparam  DATA_WIDTH_WIDE = c_WR_DATA_WIDTH >= c_RD_DATA_WIDTH ? c_WR_DATA_WIDTH :c_RD_DATA_WIDTH ; //wider DATA_WIDTH between c_WR_DATA_WIDTH and c_RD_DATA_WIDTH
    localparam  ADDR_WIDTH_WIDE = c_WR_DATA_WIDTH >= c_RD_DATA_WIDTH ? c_WR_ADDR_WIDTH :c_RD_ADDR_WIDTH ; //ADDR WIDTH correspond to DATA_WIDTH_WIDE

    localparam  DATA_WIDTH_NARROW = c_WR_DATA_WIDTH >= c_RD_DATA_WIDTH ? c_RD_DATA_WIDTH :c_WR_DATA_WIDTH ;
    localparam  ADDR_WIDTH_NARROW = c_WR_DATA_WIDTH >= c_RD_DATA_WIDTH ? c_RD_ADDR_WIDTH :c_WR_ADDR_WIDTH ;

    localparam  DATA_WIDTH_W2N = c_WR_DATA_WIDTH >= c_RD_DATA_WIDTH ? 1 : 0 ;

    localparam  N_DATA_1_WIDTH = ADDR_WIDTH_WIDE <= 9  ? ( (DATA_WIDTH_WIDE%9 == 0) ? ((ADDR_STROBE_EN == 1) ? 36 : 72) :
                                                           (DATA_WIDTH_WIDE%8 == 0) ? ((ADDR_STROBE_EN == 1) ? 32 : 64) :
                                                                                      ((ADDR_STROBE_EN == 1) ? 36 : 72) ) :
                                 ADDR_WIDTH_WIDE == 10 ? ( (DATA_WIDTH_WIDE%9 == 0) ? 36 :
                                                           (DATA_WIDTH_WIDE%8 == 0) ? 32 :
                                                                                      36 ) :
                                 ADDR_WIDTH_WIDE == 11 ? ( (DATA_WIDTH_WIDE%9 == 0) ? 18 :
                                                           (DATA_WIDTH_WIDE%8 == 0) ? 16 :
                                                                                      18 ) :
                                 ADDR_WIDTH_WIDE == 12 ? ( (DATA_WIDTH_WIDE%9 == 0) ? 9  :
                                                           (DATA_WIDTH_WIDE%8 == 0) ? 8  :
                                                                                      9  ) :
                                 ADDR_WIDTH_WIDE == 13 ? 4 :
                                 ADDR_WIDTH_WIDE == 14 ? 2 :
                                                         1 ;

    localparam  L_DATA_1_WIDTH = DATA_WIDTH_WIDE == 1    ? 1  :
                                 DATA_WIDTH_WIDE == 2    ? 2  :
                                 DATA_WIDTH_WIDE <= 4    ? 4  :
                                 DATA_WIDTH_WIDE <= 9    ? ( (DATA_WIDTH_WIDE%9 == 0) ? 9  : (DATA_WIDTH_WIDE%8 == 0) ? 8  : 9  ) :
                                 DATA_WIDTH_WIDE <= 18   ? ( (DATA_WIDTH_WIDE%9 == 0) ? 18 : (DATA_WIDTH_WIDE%8 == 0) ? 16 : 18 ) :
                                 DATA_WIDTH_WIDE <= 36   ? ( (DATA_WIDTH_WIDE%9 == 0) ? 36 : (DATA_WIDTH_WIDE%8 == 0) ? 32 : 36 ) :
                                                           ( (DATA_WIDTH_WIDE%9 == 0) ? ( (ADDR_STROBE_EN == 1) ? 36 : 72 ) :
                                                             (DATA_WIDTH_WIDE%8 == 0) ? ( (ADDR_STROBE_EN == 1) ? 32 : 64 ) :
                                                                                        ( (ADDR_STROBE_EN == 1) ? 36 : 72 ) ) ;
    //WIDTH_RATIO = 2
    localparam  N_DATA_WIDTH_2_WIDE = DATA_WIDTH_WIDE%9 == 0 ? ( ADDR_WIDTH_WIDE <= 9  ? ( (ADDR_STROBE_EN == 1) ? 36 : 72 ) :
                                                                 ADDR_WIDTH_WIDE == 10 ? 36 :
                                                                                         18 ) :
                                       ADDR_WIDTH_WIDE <= 9  ? ( (ADDR_STROBE_EN == 1) ? 32 : 64 ) :
                                       ADDR_WIDTH_WIDE == 10 ? 32 :
                                       ADDR_WIDTH_WIDE == 11 ? 16 :
                                       ADDR_WIDTH_WIDE == 12 ? 8  :
                                       ADDR_WIDTH_WIDE == 13 ? 4  :
                                                               2  ;

    localparam  L_DATA_WIDTH_2_WIDE = DATA_WIDTH_WIDE%9 == 0  ? ( DATA_WIDTH_WIDE <= 18 ? 18 :
                                                                  DATA_WIDTH_WIDE <= 36 ? 36 :
                                                                                          ( (ADDR_STROBE_EN == 1) ? 36 : 72 ) ) :
                                        DATA_WIDTH_WIDE == 2  ? 2  :
                                        DATA_WIDTH_WIDE == 4  ? 4  :
                                        DATA_WIDTH_WIDE == 8  ? 8  :
                                        DATA_WIDTH_WIDE == 16 ? 16 :
                                        DATA_WIDTH_WIDE == 32 ? 32 :
                                                                ( (ADDR_STROBE_EN == 1) ? 32 : 64 );
    //WIDTH_RATIO == 4
    localparam  N_DATA_WIDTH_4_WIDE = DATA_WIDTH_WIDE%9 == 0  ? ( ADDR_WIDTH_WIDE <= 9  ? ( (ADDR_STROBE_EN == 1) ? 36 : 72 ) :
                                                                                          36 ) :
                                        ADDR_WIDTH_WIDE <= 9  ? ( (ADDR_STROBE_EN == 1) ? 32 : 64 ) :
                                        ADDR_WIDTH_WIDE == 10 ? 32 :
                                        ADDR_WIDTH_WIDE == 11 ? 16 :
                                        ADDR_WIDTH_WIDE == 12 ? 8  :
                                                                4  ;

    localparam  L_DATA_WIDTH_4_WIDE =  DATA_WIDTH_WIDE%9 == 0 ? ( DATA_WIDTH_WIDE <= 36 ? 36 :
                                                                                          ( (ADDR_STROBE_EN == 1) ? 36 : 72 ) ) :
                                        DATA_WIDTH_WIDE == 4  ? 4  :
                                        DATA_WIDTH_WIDE == 8  ? 8  :
                                        DATA_WIDTH_WIDE == 16 ? 16 :
                                        DATA_WIDTH_WIDE == 32 ? 32 :
                                                                ( (ADDR_STROBE_EN == 1) ? 32 : 64 ) ;

    //WIDTH_RATIO == 8
    localparam  N_DATA_WIDTH_8_WIDE   = DATA_WIDTH_WIDE%9 == 0  ? ( (ADDR_STROBE_EN == 1) ? 36 : 72 ) :
                                          ADDR_WIDTH_WIDE <= 9  ? ( (ADDR_STROBE_EN == 1) ? 32 : 64 ) :
                                          ADDR_WIDTH_WIDE == 10 ? 32 :
                                          ADDR_WIDTH_WIDE == 11 ? 16 :
                                                                  8  ;

    localparam  L_DATA_WIDTH_8_WIDE   = DATA_WIDTH_WIDE%9 == 0 ? ( (ADDR_STROBE_EN == 1) ? 36 : 72 ) :
                                         DATA_WIDTH_WIDE == 8  ? 8  :
                                         DATA_WIDTH_WIDE == 16 ? 16 :
                                         DATA_WIDTH_WIDE == 32 ? 32 :
                                                                 ( (ADDR_STROBE_EN == 1) ? 32 : 64 ) ;

    //WIDTH_RATIO == 16
    localparam  N_DATA_WIDTH_16_WIDE  = ADDR_WIDTH_WIDE <= 9  ? ( (ADDR_STROBE_EN == 1) ? 32 : 64 ) :
                                        ADDR_WIDTH_WIDE == 10 ? 32 :
                                                                16 ;

    localparam  L_DATA_WIDTH_16_WIDE  = DATA_WIDTH_WIDE == 16 ? 16 :
                                        DATA_WIDTH_WIDE == 32 ? 32 :
                                                                ( (ADDR_STROBE_EN == 1) ? 32 : 64 ) ;

    //WIDTH_RATIO == 32
    localparam  N_DATA_WIDTH_32_WIDE  = ADDR_WIDTH_WIDE <= 9  ? ( (ADDR_STROBE_EN == 1) ? 32 : 64 ) :
                                                                32 ;

    localparam  L_DATA_WIDTH_32_WIDE  = DATA_WIDTH_WIDE == 32 ? 32 :
                                                                ( (ADDR_STROBE_EN == 1) ? 32 : 64 ) ;

    //WIDTH_RATIO == 64
    localparam  N_DATA_WIDTH_64_WIDE  = (ADDR_STROBE_EN == 1) ? 32 : 64 ;
    localparam  L_DATA_WIDTH_64_WIDE  = (ADDR_STROBE_EN == 1) ? 32 : 64 ;

    //********************************************************************************************************************************************************************
    //BYTE ENABLE parameter
    //byte_enable==1 && WIDTH_RATIO = 1
    localparam  N_BYTE_DATA_1_WIDTH = (c_WR_BYTE_WIDTH == 8) ? ( (ADDR_WIDTH_WIDE <= 9 ) ? ((ADDR_STROBE_EN == 1) ? 32 : 64) :
                                                                 (ADDR_WIDTH_WIDE == 10) ? 32 :
                                                                                           16 ) :
                                                               ( (ADDR_WIDTH_WIDE <= 9 ) ? ((ADDR_STROBE_EN == 1) ? 36 : 72) :
                                                                 (ADDR_WIDTH_WIDE == 10) ? 36 :
                                                                                           18 );
    localparam  L_BYTE_DATA_1_WIDTH = (c_WR_BYTE_WIDTH == 8) ? ( (DATA_WIDTH_WIDE <= 16) ? 16 :
                                                                 (DATA_WIDTH_WIDE <= 32) ? 32 :
                                                                                           ((ADDR_STROBE_EN == 1) ? 32 : 64) ) :
                                                               ( (DATA_WIDTH_WIDE <= 18) ? 18 :
                                                                 (DATA_WIDTH_WIDE <= 36) ? 36 :
                                                                                           ((ADDR_STROBE_EN == 1) ? 36 : 72) );

    //byte_enable==1 && WIDTH_RATIO = 2
    localparam  N_BYTE_DATA_WIDTH_2_WIDE = (c_WR_BYTE_WIDTH == 8) ? ( (ADDR_WIDTH_WIDE <= 9 ) ? ((ADDR_STROBE_EN == 1) ? 32 : 64) :
                                                                      (ADDR_WIDTH_WIDE == 10) ? 32 :
                                                                                                16 ) :
                                                                    ( (ADDR_WIDTH_WIDE <= 9 ) ? ((ADDR_STROBE_EN == 1) ? 36 : 72) :
                                                                      (ADDR_WIDTH_WIDE == 10) ? 36 :
                                                                                                18 );
    localparam  L_BYTE_DATA_WIDTH_2_WIDE = (c_WR_BYTE_WIDTH == 8) ? ( (DATA_WIDTH_WIDE == 16) ? 16 :
                                                                      (DATA_WIDTH_WIDE == 32) ? 32 :
                                                                                                ((ADDR_STROBE_EN == 1) ? 32 : 64) ) :
                                                                    ( (DATA_WIDTH_WIDE == 18) ? 18 :
                                                                      (DATA_WIDTH_WIDE == 36) ? 36 :
                                                                                                ((ADDR_STROBE_EN == 1) ? 36 : 72) );

    //byte_enable==1 && WIDTH_RATIO = 4
    localparam  N_BYTE_DATA_WIDTH_4_WIDE = (c_WR_BYTE_WIDTH == 8) ? ( (ADDR_WIDTH_WIDE <= 9 ) ? ((ADDR_STROBE_EN == 1) ? 32 : 64) :
                                                                                                32 ) :
                                                                    ( (ADDR_WIDTH_WIDE <= 9 ) ? ((ADDR_STROBE_EN == 1) ? 36 : 72) :
                                                                                                36 );
    localparam  L_BYTE_DATA_WIDTH_4_WIDE = (c_WR_BYTE_WIDTH == 8) ? ( (DATA_WIDTH_WIDE == 32) ? 32 :
                                                                                                ((ADDR_STROBE_EN == 1) ? 32 : 64) ) :
                                                                    ( (DATA_WIDTH_WIDE == 36) ? 36 :
                                                                                                ((ADDR_STROBE_EN == 1) ? 36 : 72) );

    //byte_enable==1 && WIDTH_RATIO = 8
    localparam  N_BYTE_DATA_WIDTH_8_WIDE = (c_WR_BYTE_WIDTH == 8) ? ( (ADDR_STROBE_EN == 1) ? 32 : 64 ) :
                                                                    ( (ADDR_STROBE_EN == 1) ? 36 : 72 ) ;
    localparam  L_BYTE_DATA_WIDTH_8_WIDE = (c_WR_BYTE_WIDTH == 8) ? ( (ADDR_STROBE_EN == 1) ? 32 : 64 ) :
                                                                    ( (ADDR_STROBE_EN == 1) ? 36 : 72 );
    //********************************************************************************************************************************************************************
    localparam  WIDTH_RATIO  =  (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH) ? (c_WR_DATA_WIDTH/c_RD_DATA_WIDTH) : (c_RD_DATA_WIDTH/c_WR_DATA_WIDTH);

    localparam  N_DRM_DATA_WIDTH_A  = WIDTH_RATIO == 1  ? N_DATA_1_WIDTH :
                                      WIDTH_RATIO == 2  ? (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? N_DATA_WIDTH_2_WIDE  : (N_DATA_WIDTH_2_WIDE/2)):
                                      WIDTH_RATIO == 4  ? (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? N_DATA_WIDTH_4_WIDE  : (N_DATA_WIDTH_4_WIDE/4)):
                                      WIDTH_RATIO == 8  ? (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? N_DATA_WIDTH_8_WIDE  : (N_DATA_WIDTH_8_WIDE/8)):
                                      WIDTH_RATIO == 16 ? (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? N_DATA_WIDTH_16_WIDE : (N_DATA_WIDTH_16_WIDE/16)):
                                      WIDTH_RATIO == 32 ? (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? N_DATA_WIDTH_32_WIDE : (N_DATA_WIDTH_32_WIDE/32)):
                                                          (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? N_DATA_WIDTH_64_WIDE : (N_DATA_WIDTH_64_WIDE/64));

    localparam  L_DRM_DATA_WIDTH_A  = WIDTH_RATIO == 1  ? L_DATA_1_WIDTH :
                                      WIDTH_RATIO == 2  ? (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? L_DATA_WIDTH_2_WIDE  : (L_DATA_WIDTH_2_WIDE/2)):
                                      WIDTH_RATIO == 4  ? (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? L_DATA_WIDTH_4_WIDE  : (L_DATA_WIDTH_4_WIDE/4)):
                                      WIDTH_RATIO == 8  ? (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? L_DATA_WIDTH_8_WIDE  : (L_DATA_WIDTH_8_WIDE/8)):
                                      WIDTH_RATIO == 16 ? (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? L_DATA_WIDTH_16_WIDE : (L_DATA_WIDTH_16_WIDE/16)):
                                      WIDTH_RATIO == 32 ? (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? L_DATA_WIDTH_32_WIDE : (L_DATA_WIDTH_32_WIDE/32)):
                                                          (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? L_DATA_WIDTH_64_WIDE : (L_DATA_WIDTH_64_WIDE/64));

    localparam  N_DRM_DATA_WIDTH_B  = WIDTH_RATIO == 1  ? N_DATA_1_WIDTH :
                                      WIDTH_RATIO == 2  ? (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? N_DATA_WIDTH_2_WIDE  : (N_DATA_WIDTH_2_WIDE/2)):
                                      WIDTH_RATIO == 4  ? (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? N_DATA_WIDTH_4_WIDE  : (N_DATA_WIDTH_4_WIDE/4)):
                                      WIDTH_RATIO == 8  ? (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? N_DATA_WIDTH_8_WIDE  : (N_DATA_WIDTH_8_WIDE/8)):
                                      WIDTH_RATIO == 16 ? (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? N_DATA_WIDTH_16_WIDE : (N_DATA_WIDTH_16_WIDE/16)):
                                      WIDTH_RATIO == 32 ? (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? N_DATA_WIDTH_32_WIDE : (N_DATA_WIDTH_32_WIDE/32)):
                                                          (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? N_DATA_WIDTH_64_WIDE : (N_DATA_WIDTH_64_WIDE/64));

    localparam  L_DRM_DATA_WIDTH_B  = WIDTH_RATIO == 1  ? L_DATA_1_WIDTH :
                                      WIDTH_RATIO == 2  ? (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? L_DATA_WIDTH_2_WIDE  : (L_DATA_WIDTH_2_WIDE/2)):
                                      WIDTH_RATIO == 4  ? (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? L_DATA_WIDTH_4_WIDE  : (L_DATA_WIDTH_4_WIDE/4)):
                                      WIDTH_RATIO == 8  ? (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? L_DATA_WIDTH_8_WIDE  : (L_DATA_WIDTH_8_WIDE/8)):
                                      WIDTH_RATIO == 16 ? (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? L_DATA_WIDTH_16_WIDE : (L_DATA_WIDTH_16_WIDE/16)):
                                      WIDTH_RATIO == 32 ? (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? L_DATA_WIDTH_32_WIDE : (L_DATA_WIDTH_32_WIDE/32)):
                                                          (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? L_DATA_WIDTH_64_WIDE : (L_DATA_WIDTH_64_WIDE/64));

    //byte_enable  DRM DATA WIDTH
    localparam  N_BYTE_DATA_WIDTH_A = WIDTH_RATIO == 1  ? N_BYTE_DATA_1_WIDTH :
                                      WIDTH_RATIO == 2  ? (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? N_BYTE_DATA_WIDTH_2_WIDE  : (N_BYTE_DATA_WIDTH_2_WIDE/2)) :
                                      WIDTH_RATIO == 4  ? (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? N_BYTE_DATA_WIDTH_4_WIDE  : (N_BYTE_DATA_WIDTH_4_WIDE/4)) :
                                                          (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? N_BYTE_DATA_WIDTH_8_WIDE  : (N_BYTE_DATA_WIDTH_8_WIDE/8)) ;

    localparam  N_BYTE_DATA_WIDTH_B = WIDTH_RATIO == 1  ? N_BYTE_DATA_1_WIDTH :
                                      WIDTH_RATIO == 2  ? (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? N_BYTE_DATA_WIDTH_2_WIDE  : (N_BYTE_DATA_WIDTH_2_WIDE/2)) :
                                      WIDTH_RATIO == 4  ? (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? N_BYTE_DATA_WIDTH_4_WIDE  : (N_BYTE_DATA_WIDTH_4_WIDE/4)) :
                                                          (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? N_BYTE_DATA_WIDTH_8_WIDE  : (N_BYTE_DATA_WIDTH_8_WIDE/8)) ;

    localparam  L_BYTE_DATA_WIDTH_A = WIDTH_RATIO == 1  ? L_BYTE_DATA_1_WIDTH :
                                      WIDTH_RATIO == 2  ? (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? L_BYTE_DATA_WIDTH_2_WIDE  : (L_BYTE_DATA_WIDTH_2_WIDE/2)) :
                                      WIDTH_RATIO == 4  ? (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? L_BYTE_DATA_WIDTH_4_WIDE  : (L_BYTE_DATA_WIDTH_4_WIDE/4)) :
                                                          (c_WR_DATA_WIDTH > c_RD_DATA_WIDTH ? L_BYTE_DATA_WIDTH_8_WIDE  : (L_BYTE_DATA_WIDTH_8_WIDE/8)) ;

    localparam  L_BYTE_DATA_WIDTH_B = WIDTH_RATIO == 1  ? L_BYTE_DATA_1_WIDTH :
                                      WIDTH_RATIO == 2  ? (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? L_BYTE_DATA_WIDTH_2_WIDE  : (L_BYTE_DATA_WIDTH_2_WIDE/2)) :
                                      WIDTH_RATIO == 4  ? (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? L_BYTE_DATA_WIDTH_4_WIDE  : (L_BYTE_DATA_WIDTH_4_WIDE/4)) :
                                                          (c_RD_DATA_WIDTH > c_WR_DATA_WIDTH ? L_BYTE_DATA_WIDTH_8_WIDE  : (L_BYTE_DATA_WIDTH_8_WIDE/8)) ;

    //*****************************************************************************************************************************************
    //DRM_DATA_WIDTH_A is the  port A parameter  of DRM
    localparam  DRM_DATA_WIDTH_A = (c_POWER_OPT == 1) ? (c_WR_BYTE_EN ==1 ? L_BYTE_DATA_WIDTH_A : L_DRM_DATA_WIDTH_A):
                                                        (c_WR_BYTE_EN ==1 ? N_BYTE_DATA_WIDTH_A : N_DRM_DATA_WIDTH_A);
    //DRM_DATA_WIDTH_A is the  port B parameter  of DRM
    localparam  DRM_DATA_WIDTH_B = (c_POWER_OPT == 1) ? (c_WR_BYTE_EN ==1 ? L_BYTE_DATA_WIDTH_B : L_DRM_DATA_WIDTH_B):
                                                        (c_WR_BYTE_EN ==1 ? N_BYTE_DATA_WIDTH_B : N_DRM_DATA_WIDTH_B);

    //DATA_LOOP_NUM difine how many loop to cascade the c_WR_DATA_WIDTH
    localparam  DATA_LOOP_NUM = (c_WR_DATA_WIDTH%DRM_DATA_WIDTH_A == 0) ? (c_WR_DATA_WIDTH/DRM_DATA_WIDTH_A):(c_WR_DATA_WIDTH/DRM_DATA_WIDTH_A + 1);

    localparam  Q_DRM_DATA_WIDTH_B    = (DRM_DATA_WIDTH_B == 72) ? 36 : ((DRM_DATA_WIDTH_B == 64) ? 32 : DRM_DATA_WIDTH_B);
    localparam  Q_DRM_DATA_WIDTH_B_H  = (DRM_DATA_WIDTH_B == 72 || DRM_DATA_WIDTH_B == 64) ? Q_DRM_DATA_WIDTH_B/2 : Q_DRM_DATA_WIDTH_B;

    localparam  Q_DRM_DATA_WIDTH_A    = (DRM_DATA_WIDTH_B == 64 || DRM_DATA_WIDTH_B == 72) ? Q_DRM_DATA_WIDTH_B :
                                       ((DRM_DATA_WIDTH_A == 72) ? 36 : ((DRM_DATA_WIDTH_A == 64) ? 32 : DRM_DATA_WIDTH_A));
    localparam  Q_DRM_DATA_WIDTH_A_H  = (DRM_DATA_WIDTH_B == 64 || DRM_DATA_WIDTH_B == 72) ? Q_DRM_DATA_WIDTH_B/2 :
                                        (DRM_DATA_WIDTH_A == 72 || DRM_DATA_WIDTH_A == 64) ? Q_DRM_DATA_WIDTH_A/2 : Q_DRM_DATA_WIDTH_A;


    localparam  D_DRM_DATA_WIDTH_A    = (DRM_DATA_WIDTH_A == 72) ? 36 : ((DRM_DATA_WIDTH_A == 64) ? 32 : DRM_DATA_WIDTH_A);
//    localparam  D_DRM_DATA_WIDTH_A_H  = (DRM_DATA_WIDTH_A == 72 || DRM_DATA_WIDTH_A == 64) ? D_DRM_DATA_WIDTH_A/2 : D_DRM_DATA_WIDTH_A;

    localparam  D_DRM_DATA_WIDTH_B  = (DRM_DATA_WIDTH_A == 64 || DRM_DATA_WIDTH_A== 72) ? D_DRM_DATA_WIDTH_A :
                                     ((DRM_DATA_WIDTH_B == 72) ? 36 : ((DRM_DATA_WIDTH_B == 64) ? 32 : DRM_DATA_WIDTH_B));
//    localparam  D_DRM_DATA_WIDTH_B_H  = (DRM_DATA_WIDTH_A == 64 || DRM_DATA_WIDTH_A == 72) ? D_DRM_DATA_WIDTH_A/2 :
//                                        (DRM_DATA_WIDTH_B == 72 || DRM_DATA_WIDTH_B == 64) ? D_DRM_DATA_WIDTH_B/2 : D_DRM_DATA_WIDTH_B;

    //DRM_ADDR_WIDTH is the ADDR_WIDTH of INSTANCE DRM primitives
    localparam  DRM_ADDR_WIDTH_A = DRM_DATA_WIDTH_A == 1  ? 15:
                                   DRM_DATA_WIDTH_A == 2  ? 14:
                                   DRM_DATA_WIDTH_A == 4  ? 13:
                                   DRM_DATA_WIDTH_A == 8  ? 12:
                                   DRM_DATA_WIDTH_A == 9  ? 12:
                                   DRM_DATA_WIDTH_A == 16 ? 11:
                                   DRM_DATA_WIDTH_A == 18 ? 11:
                                   DRM_DATA_WIDTH_A == 32 ? 10:
                                   DRM_DATA_WIDTH_A == 36 ? 10:
                                                             9;

    localparam  DRM_ADDR_WIDTH_B = DRM_DATA_WIDTH_B == 1  ? 15:
                                   DRM_DATA_WIDTH_B == 2  ? 14:
                                   DRM_DATA_WIDTH_B == 4  ? 13:
                                   DRM_DATA_WIDTH_B == 8  ? 12:
                                   DRM_DATA_WIDTH_B == 9  ? 12:
                                   DRM_DATA_WIDTH_B == 16 ? 11:
                                   DRM_DATA_WIDTH_B == 18 ? 11:
                                   DRM_DATA_WIDTH_B == 32 ? 10:
                                   DRM_DATA_WIDTH_B == 36 ? 10:
                                                             9;

    localparam  ADDR_WIDTH_A  = c_WR_ADDR_WIDTH > DRM_ADDR_WIDTH_A ? c_WR_ADDR_WIDTH : DRM_ADDR_WIDTH_A;
    //CS_ADDR_WIDTH_A is the CS address width to choose the DRM18K CS_ADDR_WIDTH_A=  [ extra-addres + cs[2]+csp[1]+cs[0] ]
    localparam  CS_ADDR_WIDTH_A  = ADDR_WIDTH_A - DRM_ADDR_WIDTH_A;

    localparam  ADDR_WIDTH_B  = c_RD_ADDR_WIDTH > DRM_ADDR_WIDTH_B ? c_RD_ADDR_WIDTH : DRM_ADDR_WIDTH_B;
    localparam  CS_ADDR_WIDTH_B  = ADDR_WIDTH_B - DRM_ADDR_WIDTH_B;
    //ADDR_LOOP_NUM_A difine how many loops to cascade the c_WR_ADDR_WIDTH
    localparam  ADDR_LOOP_NUM_A  = 2**CS_ADDR_WIDTH_A;
    localparam  ADDR_LOOP_NUM_B  = 2**CS_ADDR_WIDTH_B;

    //CAS_DATA_WIDTH_A is the cascaded  data width
    localparam  CAS_DATA_WIDTH_A   =  DRM_DATA_WIDTH_A*DATA_LOOP_NUM   ;
    localparam  CAS_DATA_WIDTH_B   =  DRM_DATA_WIDTH_B*DATA_LOOP_NUM   ;

    localparam  Q_CAS_DATA_WIDTH_A =  Q_DRM_DATA_WIDTH_A*DATA_LOOP_NUM ;
    localparam  Q_CAS_DATA_WIDTH_B =  Q_DRM_DATA_WIDTH_B*DATA_LOOP_NUM ;

    localparam  D_CAS_DATA_WIDTH_A =  D_DRM_DATA_WIDTH_A*DATA_LOOP_NUM ;
    localparam  D_CAS_DATA_WIDTH_B =  D_DRM_DATA_WIDTH_B*DATA_LOOP_NUM ;

    localparam  WR_BYTE_WIDTH_A = c_WR_BYTE_EN == 1 ? c_WR_BYTE_WIDTH : ( (DRM_DATA_WIDTH_A >=8 || DRM_DATA_WIDTH_A >=9 ) ? ((c_WR_DATA_WIDTH%9 == 0) ? 9 : 8 ) : 1 );
    localparam  WR_BYTE_WIDTH_B = c_WR_BYTE_EN == 1 ? c_WR_BYTE_WIDTH : ( (DRM_DATA_WIDTH_B >=8 || DRM_DATA_WIDTH_B >=9 ) ? ((c_RD_DATA_WIDTH%9 == 0) ? 9 : 8 ) : 1 );

    //MASK_NUM the mask base value
    localparam  MASK_NUM_A  = ( DRM_DATA_WIDTH_A == 72 || DRM_DATA_WIDTH_A == 64 ) ? (ADDR_LOOP_NUM_A > 4 ? 2 : 4 ) : ( ADDR_LOOP_NUM_A > 8 ) ? (( DRM_DATA_WIDTH_A == 72 || DRM_DATA_WIDTH_A == 64 ) ? 2 : 4) : 8;
    localparam  MASK_NUM_B  = ( DRM_DATA_WIDTH_B == 72 || DRM_DATA_WIDTH_B == 64 ) ? (ADDR_LOOP_NUM_B > 4 ? 2 : 4 ) : ( ADDR_LOOP_NUM_B > 8 ) ? (( DRM_DATA_WIDTH_B == 72 || DRM_DATA_WIDTH_B == 64 ) ? 2 : 4) : 8;

    //parameter  check
    initial begin
       if( (2**c_WR_ADDR_WIDTH*c_WR_DATA_WIDTH) != (2**c_RD_ADDR_WIDTH*c_RD_DATA_WIDTH) ) begin
          $display("IPSpecCheck: 04030129 ipm2l_flex_sdpram parameter setting error !!!: 2**c_WR_ADDR_WIDTH*c_WR_DATA_WIDTH must be equal to  2**c_RD_ADDR_WIDTH*c_RD_DATA_WIDTH or 2**c_WR_ADDR_WIDTH*9 must be equal to  2**c_RD_ADDR_WIDTH*9")/* PANGO PAP_ERROR */;
          $finish;
       end
       else if( c_WR_ADDR_WIDTH>20 || c_WR_ADDR_WIDTH<9 ) begin
          $display("IPSpecCheck: 04030130 ipm2l_flex_sdpram parameter setting error !!!: c_WR_ADDR_WIDTH must between 9-20 when DRM Resource is 36K")/* PANGO PAP_WARNING */;
//          $finish;
       end
       else if( c_WR_DATA_WIDTH>1152 || c_WR_DATA_WIDTH<1 ) begin
          $display("IPSpecCheck: 04030131 ipm2l_flex_sdpram parameter setting error !!!: c_WR_DATA_WIDTH must between 1-1152")/* PANGO PAP_WARNING */;
//         $finish;
       end
       else if( c_RD_ADDR_WIDTH>20 || c_RD_ADDR_WIDTH<9 ) begin
          $display("IPSpecCheck: 04030132 ipm2l_flex_sdpram parameter setting error !!!: c_RD_ADDR_WIDTH must between 9-20 when DRM Resource is 36K")/* PANGO PAP_WARNING */;
//          $finish;
       end
       else if( c_RD_DATA_WIDTH>1152 || c_RD_DATA_WIDTH<1 ) begin
          $display("IPSpecCheck: 04030133 ipm2l_flex_sdpram parameter setting error !!!: c_RD_DATA_WIDTH must between 1-1152")/* PANGO PAP_WARNING */;
//          $finish;
       end
//       else if( (2**c_WR_ADDR_WIDTH)*c_WR_DATA_WIDTH > 1152*1024 ) begin
//          $display("IPSpecCheck: 04030134 ipm2l_flex_sdpram parameter setting error !!!: ipmc_flex_ram must less than  1152k")/* PANGO PAP_ERROR */;
//          $finish;
//       end
       else if ( (c_WR_ADDR_STROBE_EN!=0 && c_WR_ADDR_STROBE_EN!=1) || (c_RD_ADDR_STROBE_EN!=0 && c_RD_ADDR_STROBE_EN!=1) ) begin
          $display("IPSpecCheck: 04030135 ipm2l_flex_sdpram parameter setting error !!!: c_WR_ADDR_STROBE_EN or c_RD_ADDR_STROBE_EN must be 0 or 1")/* PANGO PAP_ERROR */;
          $finish;
       end
       else if ( (c_WR_CLK_EN!=0 && c_WR_CLK_EN!=1) || (c_RD_CLK_EN!=0 && c_RD_CLK_EN!=1) ) begin
          $display("IPSpecCheck: 04030136 ipm2l_flex_sdpram parameter setting error !!!: c_WR_CLK_EN or c_RD_CLK_EN must be 0 or 1")/* PANGO PAP_ERROR */;
          $finish;
       end
       else if ( c_RD_OCE_EN!=0 && c_RD_OCE_EN!=1 ) begin
          $display("IPSpecCheck: 04030137 ipm2l_flex_sdpram parameter setting error !!!: c_RD_OCE_EN must be 0 or 1")/* PANGO PAP_ERROR */;
          $finish;
       end
       else if( c_OUTPUT_REG!=1 && c_OUTPUT_REG!=0 ) begin
          $display("IPSpecCheck: 04030138 ipm2l_flex_sdpram parameter setting error !!!: c_OUTPUT_REG must be 0 or 1")/* PANGO PAP_ERROR */;
          $finish;
       end
       else if ( c_FAB_REG!=1 && c_FAB_REG!=0  ) begin
           $display("IPSpecCheck: 04030178 ipm2l_flex_sdpram parameter setting error !!!: c_FAB_REG must be 0 or 1")/* PANGO PAP_ERROR */;
           $finish;
       end
       else if(c_RD_CLK_OR_POL_INV!=1 && c_RD_CLK_OR_POL_INV!=0 ) begin
          $display("IPSpecCheck: 04030139 ipm2l_flex_sdpram parameter setting error !!!: c_RD_CLK_OR_POL_INV must be 0 or 1")/* PANGO PAP_ERROR */;
          $finish;
       end
       else if( c_RD_OCE_EN==1 && (c_OUTPUT_REG==0 && c_FAB_REG==0) ) begin
           $display("IPSpecCheck: 04030140 ipm2l_flex_sdpram parameter setting error !!!: c_OUTPUT_REG and c_FAB_REG could not be 0 at same time when c_RD_OCE_EN is 1")/* PANGO PAP_ERROR */;
           $finish;
       end
       else if( c_RD_CLK_OR_POL_INV==1 && (c_OUTPUT_REG==0 && c_FAB_REG==0) ) begin
           $display("IPSpecCheck: 04030141 ipm2l_flex_sdpram parameter setting error !!!: c_OUTPUT_REG and c_FAB_REG could not be 0 at same time when c_RD_CLK_OR_POL_INV is 1")/* PANGO PAP_ERROR */;
           $finish;
       end
       else if(c_RESET_TYPE!="ASYNC" && c_RESET_TYPE!="SYNC" ) begin
          $display("IPSpecCheck: 04030142 ipm2l_flex_sdpram parameter setting error !!!: c_RESET_TYPE must be ASYNC or SYNC")/* PANGO PAP_ERROR */;
          $finish;
       end
       else if(c_POWER_OPT!=1 && c_POWER_OPT!=0 ) begin
          $display("IPSpecCheck: 04030143 ipm2l_flex_sdpram parameter setting error !!!: c_POWER_OPT must be 0 or 1")/* PANGO PAP_ERROR */;
          $finish;
       end
       else if ( WIDTH_RATIO > 1 && c_INIT_FILE!="NONE" ) begin
          $display("IPSpecCheck: 04030144 ipm2l_flex_sdpram parameter setting error !!!: No RAM Initial when Mixed Data Width")/* PANGO PAP_ERROR */;
          $finish;
       end
       else if(c_WR_BYTE_EN!=0 && c_WR_BYTE_EN!=1 ) begin
          $display("IPSpecCheck: 04030145 ipm2l_flex_sdpram parameter setting error !!!: c_WR_BYTE_EN must be 0 or 1")/* PANGO PAP_ERROR */;
          $finish;
       end
       else if(c_INIT_FORMAT!="BIN" && c_INIT_FORMAT!="HEX") begin
             $display("IPSpecCheck: 04030148 ipm2l_flex_sdpram parameter setting error !!!: c_INIT_FORMAT must be bin or hex ")/* PANGO PAP_ERROR */;
             $finish;
       end
       else if(WIDTH_RATIO > 64 && c_WR_BYTE_EN == 0 && ADDR_STROBE_EN == 0) begin
             $display("IPSpecCheck: 04030149 ipm2l_flex_sdpram parameter setting error !!!: Data Width Ratio is 1~64 when both disable Byte Write and Address Strobe and DRM Resource is 36K")/* PANGO PAP_ERROR */;
             $finish;
       end
       else if(WIDTH_RATIO > 32 && c_WR_BYTE_EN == 0 && ADDR_STROBE_EN == 1) begin
             $display("IPSpecCheck: 04030150 ipm2l_flex_sdpram parameter setting error !!!: Data Width Ratio is 1~32 when disable Byte Write and enable Address Strobe and DRM Resource is 36K")/* PANGO PAP_ERROR */;
             $finish;
       end
       else if(WIDTH_RATIO > 8 && c_WR_BYTE_EN == 1 && ADDR_STROBE_EN == 0) begin
             $display("IPSpecCheck: 04030151: ipm2l_flex_sdpram parameter setting error !!!: Data Width Ratio is 1~8 when enable Byte Write and disable Address Strobe and DRM Resource is 36K")/* PANGO PAP_ERROR */;
             $finish;
       end
       else if(WIDTH_RATIO > 4 && c_WR_BYTE_EN == 1 && ADDR_STROBE_EN == 1) begin
             $display("IPSpecCheck: 04030152: ipm2l_flex_sdpram parameter setting error !!!: Data Width Ratio is 1~4 when both enable Byte Write and Address Strobe and DRM Resource is 36K")/* PANGO PAP_ERROR */;
             $finish;
       end
       else if(c_WR_BYTE_EN ==1) begin
          if(c_WR_BYTE_WIDTH !=8 && c_WR_BYTE_WIDTH!=9 ) begin
             $display("IPSpecCheck: 04030146 ipm2l_flex_sdpram parameter setting error !!!: c_WR_BYTE_WIDTH must be 8 or 9")/* PANGO PAP_ERROR */;
             $finish;
          end
          if( (c_WR_DATA_WIDTH%8)!=0 && (c_WR_DATA_WIDTH%9)!=0 ) begin
             $display("IPSpecCheck: 04030147 ipm2l_flex_sdpram parameter setting error !!!: c_WR_DATA_WIDTH must be 8*N or 9*N")/* PANGO PAP_ERROR */;
             $finish;
          end
       end
       else if ( ADDR_STROBE_EN == 1 && ( DRM_DATA_WIDTH_A > 36 || DRM_DATA_WIDTH_B > 36 ) ) begin
           $display("IPSpecCheck: 04030155 ipm2l_flex_sdpram parameter setting error !!!: Address Strobe dose not work when DRM36K mode is 512x72|64")/* PANGO PAP_ERROR */;
           $finish;
       end
       else if( c_WR_DATA_WIDTH != c_RD_DATA_WIDTH ) begin
          if( c_WR_DATA_WIDTH%9 == 0 || c_RD_DATA_WIDTH%9 == 0 ) begin
             if( ((c_WR_DATA_WIDTH/9)&(c_WR_DATA_WIDTH/9-1))!=0 || ((c_RD_DATA_WIDTH/9)&(c_RD_DATA_WIDTH/9-1))!=0 ) begin
                $display("IPSpecCheck: 04030156 ipm2l_flex_sdpram parameter setting error !!!: c_WR_DATA_WIDTH and c_RD_DATA_WIDTH must be 2^N or 9*2^N ")/* PANGO PAP_ERROR */;
                $finish;
             end
             else if( (WIDTH_RATIO > 8) && (ADDR_STROBE_EN == 0) ) begin
                $display("IPSpecCheck: 01030157 ipm2l_flex_dpram parameter setting error !!!: Data Width Ratio is 1~8 when c_WR_DATA_WIDTH and c_RD_DATA_WIDTH is 9*2^N and DRM Resource is 36K and disable Address Strobe")/* PANGO PAP_ERROR */;
                $finish;
             end
             else if( (WIDTH_RATIO > 4) && (ADDR_STROBE_EN == 1) ) begin
                $display("IPSpecCheck: 01030158 ipm2l_flex_dpram parameter setting error !!!: Data Width Ratio is 1~4 when c_WR_DATA_WIDTH and c_RD_DATA_WIDTH is 9*2^N and DRM Resource is 36K and enable Address Strobe")/* PANGO PAP_ERROR */;
                $finish;
             end
          end
          else begin
             if ( (c_WR_DATA_WIDTH&(c_WR_DATA_WIDTH-1))!=0 || (c_RD_DATA_WIDTH&(c_RD_DATA_WIDTH-1))!=0 ) begin
                $display("IPSpecCheck: 04030156 ipm2l_flex_sdpram parameter setting error !!!: c_WR_DATA_WIDTH and c_RD_DATA_WIDTH must be 2^N or 9*2^N ")/* PANGO PAP_ERROR */;
                $finish;
             end
          end
       end
    end

    //main code
    //***********************************************************************************************************************************************
    //inner variables
    //port A operation
    wire  [CAS_DATA_WIDTH_A-1:0]                    wr_data_bus       ;
    reg   [CAS_DATA_WIDTH_A-1:0]                    wr_data_mix_bus   ;
    reg   [D_CAS_DATA_WIDTH_A-1:0]                  da_data_bus       ; //the data bus of data_cascaded instance DRM
    wire  [Q_CAS_DATA_WIDTH_A*ADDR_LOOP_NUM_A-1:0]  qa_data_bus       ; //the total data width of instance DRM
    wire  [ADDR_WIDTH_A-1:0]                        wr_addr_bus       ;
    reg   [DATA_LOOP_NUM*16-1:0]                    drm_wr_addr_bus   ; //write address to all instance DRM
    reg                                             wr_cs_bit0        ; //write cs[0]  to all instance DRM
    reg   [ADDR_LOOP_NUM_A-1:0]                     wr_cs_bit1_bus    ; //write cs[1]  to all instance DRM
    reg   [ADDR_LOOP_NUM_A-1:0]                     wr_cs_bit2_bus    ; //write cs[2] bus  to every data_cascaded DRM-block
    reg   [DATA_LOOP_NUM-1:0 ]                      wr_en_bus         ;

    //port B operation
    wire  [CAS_DATA_WIDTH_B*ADDR_LOOP_NUM_B-1:0]    rd_data_bus       ;
    reg   [D_CAS_DATA_WIDTH_B-1:0]                  db_data_bus       ; //the data bus of data_cascaded instance DRM
    wire  [Q_CAS_DATA_WIDTH_B*ADDR_LOOP_NUM_B-1:0]  qb_data_bus       ; //the total data width of instance DRM
    wire  [ADDR_WIDTH_B-1:0]                        rd_addr_bus       ;
    wire  [3:0]                                     rd_addr_bsel_bus  ;
    reg   [15:0]                                    drm_rd_addr       ; //read address to all instance DRM
    reg                                             rd_cs_bit0        ; //read cs[0]  to all instance DRM
    reg   [ADDR_LOOP_NUM_B-1:0]                     rd_cs_bit1_bus    ; //read cs[1]  to all instance DRM
    reg   [ADDR_LOOP_NUM_B-1:0]                     rd_cs_bit2_bus    ; //raad cs[2]  bus  to every data_cascaded DRM-block

    reg   [CAS_DATA_WIDTH_B-1:0]                    rd_mix_data       ; //mix data form rd_data_bus
    reg   [CAS_DATA_WIDTH_B-1:0]                    rd_full_data      ;

    //byte enable
    wire  [8*DATA_LOOP_NUM-1 : 0]      wr_byte_en_bus_p  ;
    reg   [8*DATA_LOOP_NUM-1 : 0]      wr_byte_en_bus    ;
    wire  [8*DATA_LOOP_NUM-1 : 0]      wr_byte_en_bus_m  ;

    wire  [DATA_LOOP_NUM*ADDR_LOOP_NUM_A-1:0]       cas_caout        ;
    wire  [DATA_LOOP_NUM*ADDR_LOOP_NUM_A-1:0]       cas_cbout        ;

    //write data mux
    assign  wr_data_bus[CAS_DATA_WIDTH_A-1:0] = {{(CAS_DATA_WIDTH_A - c_WR_DATA_WIDTH){1'b0}},wr_data[c_WR_DATA_WIDTH-1:0]};
    assign  wr_addr_bus[ADDR_WIDTH_A-1:0] = {{(ADDR_WIDTH_A - c_WR_ADDR_WIDTH){1'b0}},wr_addr[c_WR_ADDR_WIDTH-1:0]};

    //generate drm_wr_addr_bus connect to the instance DRM directly ,based on DRM_DATA_WIDTH_A
    integer gen_wa;
    generate
    always @(*) begin
        for( gen_wa=0;gen_wa < DATA_LOOP_NUM;gen_wa = gen_wa + 1 ) begin
//            if (DRM_DATA_WIDTH_B == 64 || DRM_DATA_WIDTH_B == 72) begin
//                case (DRM_DATA_WIDTH_A)
//                    1      : drm_wr_addr_bus[gen_wa*16 +: 16] = {1'b1,wr_addr_bus[5],wr_addr_bus[(ADDR_WIDTH_A-CS_ADDR_WIDTH_A-1):6],wr_addr_bus[4:0]};
//                    2      : drm_wr_addr_bus[gen_wa*16 +: 16] = {1'b1,wr_addr_bus[4],wr_addr_bus[(ADDR_WIDTH_A-CS_ADDR_WIDTH_A-1):5],wr_addr_bus[3:0],1'b0};
//                    4      : drm_wr_addr_bus[gen_wa*16 +: 16] = {1'b1,wr_addr_bus[3],wr_addr_bus[(ADDR_WIDTH_A-CS_ADDR_WIDTH_A-1):4],wr_addr_bus[2:0],2'b00};
//                    8,9    : drm_wr_addr_bus[gen_wa*16 +: 16] = {1'b1,wr_addr_bus[2],wr_addr_bus[(ADDR_WIDTH_A-CS_ADDR_WIDTH_A-1):3],wr_addr_bus[1:0],3'b000};
//                    16,18  : drm_wr_addr_bus[gen_wa*16 +: 16] = {1'b1,wr_addr_bus[1],wr_addr_bus[(ADDR_WIDTH_A-CS_ADDR_WIDTH_A-1):2],wr_addr_bus[0],4'b0000};
//                    32,36  : drm_wr_addr_bus[gen_wa*16 +: 16] = {1'b1,wr_addr_bus[0],wr_addr_bus[(ADDR_WIDTH_A-CS_ADDR_WIDTH_A-1):1], 5'b00000};
//                    64,72  : drm_wr_addr_bus[gen_wa*16 +: 16] = {1'b1,wr_addr_bus[(ADDR_WIDTH_A-CS_ADDR_WIDTH_A-1):0], 6'b000000};
//                    default: drm_wr_addr_bus[gen_wa*16 +: 16] = 16'b0;
//                endcase
//            end
//            else begin
                case (DRM_DATA_WIDTH_A)
                    1      : drm_wr_addr_bus[gen_wa*16 +: 16] = {1'b1,wr_addr_bus[(ADDR_WIDTH_A-CS_ADDR_WIDTH_A-1):0]};
                    2      : drm_wr_addr_bus[gen_wa*16 +: 16] = {1'b1,wr_addr_bus[(ADDR_WIDTH_A-CS_ADDR_WIDTH_A-1):0],1'b0};
                    4      : drm_wr_addr_bus[gen_wa*16 +: 16] = {1'b1,wr_addr_bus[(ADDR_WIDTH_A-CS_ADDR_WIDTH_A-1):0],2'b00};
                    8,9    : drm_wr_addr_bus[gen_wa*16 +: 16] = {1'b1,wr_addr_bus[(ADDR_WIDTH_A-CS_ADDR_WIDTH_A-1):0],3'b000};
                    16,18  : drm_wr_addr_bus[gen_wa*16 +: 16] = {1'b1,wr_addr_bus[(ADDR_WIDTH_A-CS_ADDR_WIDTH_A-1):0],4'b0000};
                    32,36  : drm_wr_addr_bus[gen_wa*16 +: 16] = {1'b1,wr_addr_bus[(ADDR_WIDTH_A-CS_ADDR_WIDTH_A-1):0],5'b00000};
                    64,72  : drm_wr_addr_bus[gen_wa*16 +: 16] = {1'b1,wr_addr_bus[(ADDR_WIDTH_A-CS_ADDR_WIDTH_A-1):0],6'b000000};
                    default: drm_wr_addr_bus[gen_wa*16 +: 16] = 16'b0;
                endcase
//            end
        end
    end
    endgenerate
    //*****************************************************************************************************************************************************
    //generate CSA bus
    localparam CS_ADDR_A_3_LSB = (CS_ADDR_WIDTH_A >= 3) ? (ADDR_WIDTH_A-CS_ADDR_WIDTH_A+1) : (ADDR_WIDTH_A-2);  //avoid reveral index of wr_addr_bus

    localparam CS_ADDR_A_4_LSB = (CS_ADDR_WIDTH_A >= 4) ? ((ADDR_WIDTH_A-CS_ADDR_WIDTH_A+2)) : (ADDR_WIDTH_A-2); //avoid reveral index of wr_addr_bus

    integer  gen_csa;
    generate
    always@(*) begin
        for(gen_csa=0;gen_csa<ADDR_LOOP_NUM_A;gen_csa=gen_csa+1) begin
            if(DRM_DATA_WIDTH_A == 72 || DRM_DATA_WIDTH_A == 64) begin
                if(CS_ADDR_WIDTH_A == 0) begin
                   wr_cs_bit0 = 0;
                   wr_cs_bit1_bus[gen_csa] = 0;
                   wr_cs_bit2_bus[gen_csa] = 0;
                end
                else if(CS_ADDR_WIDTH_A == 1) begin
                   wr_cs_bit0 = wr_addr_bus[ADDR_WIDTH_A-CS_ADDR_WIDTH_A];
                   wr_cs_bit1_bus[gen_csa] = 0;
                   wr_cs_bit2_bus[gen_csa] = 0;
                end
                else if(CS_ADDR_WIDTH_A == 2) begin
                   wr_cs_bit0 = wr_addr_bus[ADDR_WIDTH_A-2];
                   wr_cs_bit1_bus[gen_csa] = wr_addr_bus[ADDR_WIDTH_A-1];
                   wr_cs_bit2_bus[gen_csa] = 0;
                end
                else if(CS_ADDR_WIDTH_A >= 3 ) begin
                   wr_cs_bit0 = wr_addr_bus[ADDR_WIDTH_A-CS_ADDR_WIDTH_A];
                   wr_cs_bit1_bus[gen_csa] = (wr_addr_bus[(ADDR_WIDTH_A-1):CS_ADDR_A_3_LSB] == (gen_csa/2) ) ? 0 : 1;
                   wr_cs_bit2_bus[gen_csa] = 0;
                end
            end
            else begin
                if(CS_ADDR_WIDTH_A == 0) begin
                   wr_cs_bit0 = 0;
                   wr_cs_bit1_bus[gen_csa] = 0;
                   wr_cs_bit2_bus[gen_csa] = 0;
                end
                else if(CS_ADDR_WIDTH_A == 1) begin
                   wr_cs_bit0 = wr_addr_bus[ADDR_WIDTH_A-CS_ADDR_WIDTH_A];
                   wr_cs_bit1_bus[gen_csa] = 0;
                   wr_cs_bit2_bus[gen_csa] = 0;
                end
                else if(CS_ADDR_WIDTH_A == 2) begin
                   wr_cs_bit0 = wr_addr_bus[ADDR_WIDTH_A-2];
                   wr_cs_bit1_bus[gen_csa] = wr_addr_bus[ADDR_WIDTH_A-1];
                   wr_cs_bit2_bus[gen_csa] = 0;
                end
                else if(CS_ADDR_WIDTH_A == 3) begin
                   wr_cs_bit0 = wr_addr_bus[ADDR_WIDTH_A-CS_ADDR_WIDTH_A];
                   wr_cs_bit1_bus[gen_csa] = wr_addr_bus[ADDR_WIDTH_A-2];
                   wr_cs_bit2_bus[gen_csa] = wr_addr_bus[ADDR_WIDTH_A-1];
                end
                else if(CS_ADDR_WIDTH_A >= 4) begin
                   wr_cs_bit0 = wr_addr_bus[ADDR_WIDTH_A-CS_ADDR_WIDTH_A];
                   wr_cs_bit1_bus[gen_csa] = wr_addr_bus[ADDR_WIDTH_A-CS_ADDR_WIDTH_A+1];
                   wr_cs_bit2_bus[gen_csa] = ( wr_addr_bus[(ADDR_WIDTH_A-1):CS_ADDR_A_4_LSB] == (gen_csa/4) ) ? 0 : 1;
                end
            end
        end
    end
    endgenerate

    //****************************************************************************************************************************************************
    //generate wr_data_mix_bus  and wr_byte_en_mix_bus
    assign wr_byte_en_bus_p = (c_WR_BYTE_EN == 0) ? {{8*DATA_LOOP_NUM}{1'b1}} : {{(8*DATA_LOOP_NUM-c_BE_WIDTH){1'b0}},wr_byte_en[c_BE_WIDTH-1:0]};
    localparam DATA_DUTY_RATIO = (DRM_DATA_WIDTH_A < c_WR_DATA_WIDTH) ? 1 : (DRM_DATA_WIDTH_A / c_WR_DATA_WIDTH);
    genvar  gen_i_wd,gen_j_wd;
    generate
        if( c_WR_DATA_WIDTH > c_RD_DATA_WIDTH && DATA_LOOP_NUM > 1 ) begin
            for (gen_i_wd=0;gen_i_wd < DATA_LOOP_NUM;gen_i_wd =gen_i_wd+1)
                for(gen_j_wd=0;gen_j_wd<WIDTH_RATIO;gen_j_wd=gen_j_wd+1 )
                    always@(*)
                        wr_data_mix_bus[gen_i_wd*DRM_DATA_WIDTH_A+gen_j_wd*DRM_DATA_WIDTH_B +:DRM_DATA_WIDTH_B] = wr_data_bus[(gen_i_wd + gen_j_wd*DATA_LOOP_NUM)*DRM_DATA_WIDTH_B +:DRM_DATA_WIDTH_B];
        end
        else if(c_WR_DATA_WIDTH > c_RD_DATA_WIDTH && DATA_LOOP_NUM == 1 && c_WR_DATA_WIDTH < DRM_DATA_WIDTH_A )
            for( gen_j_wd=0;gen_j_wd<WIDTH_RATIO;gen_j_wd=gen_j_wd+1 )
                always@(*)
                    wr_data_mix_bus[gen_j_wd*DRM_DATA_WIDTH_B +:DRM_DATA_WIDTH_B] =  {{(DRM_DATA_WIDTH_B-c_RD_DATA_WIDTH){1'b0}},wr_data_bus[gen_j_wd*c_RD_DATA_WIDTH +:c_RD_DATA_WIDTH]};
        else begin
            always@(*)
                wr_data_mix_bus = wr_data_bus;
        end

         //generate wr_en_bus
        for (gen_i_wd=0;gen_i_wd < DATA_LOOP_NUM;gen_i_wd =gen_i_wd+1) begin:wr_en_bus_loop
            if(DRM_DATA_WIDTH_A <= 9 && c_WR_BYTE_EN == 1 ) begin:single_byte_wr_en_bus
                always@(*)
                    wr_en_bus[gen_i_wd] = wr_en & wr_byte_en[gen_i_wd];
            end
            else begin:no_single_byte_wr_en_bus
                always@(*)
                    wr_en_bus[gen_i_wd] = wr_en;
            end
        end

        //generate wr_byte_en_bus
        if( c_WR_DATA_WIDTH > c_RD_DATA_WIDTH && DATA_LOOP_NUM > 1 && c_WR_BYTE_EN == 1) begin
            for (gen_i_wd=0;gen_i_wd < DATA_LOOP_NUM;gen_i_wd =gen_i_wd+1)
                for( gen_j_wd=0;gen_j_wd<WIDTH_RATIO;gen_j_wd=gen_j_wd+1 )
                    always@(*)
                        wr_byte_en_bus[gen_i_wd*(DRM_DATA_WIDTH_A/WR_BYTE_WIDTH_A)+gen_j_wd*(DRM_DATA_WIDTH_B/WR_BYTE_WIDTH_B) +:(DRM_DATA_WIDTH_B/WR_BYTE_WIDTH_B)] = wr_byte_en_bus_p[(gen_i_wd + gen_j_wd*DATA_LOOP_NUM)*(DRM_DATA_WIDTH_B/WR_BYTE_WIDTH_B) +:(DRM_DATA_WIDTH_B/WR_BYTE_WIDTH_B)];
        end
        else if( c_WR_DATA_WIDTH > c_RD_DATA_WIDTH  && DATA_LOOP_NUM == 1  && c_WR_BYTE_EN == 1 && DRM_DATA_WIDTH_A > c_WR_DATA_WIDTH) begin
            for(gen_i_wd=0;gen_i_wd < WIDTH_RATIO;gen_i_wd =gen_i_wd+1)
                always@(*) begin
                    wr_byte_en_bus[gen_i_wd*c_BE_WIDTH*DATA_DUTY_RATIO/WIDTH_RATIO +:c_BE_WIDTH*DATA_DUTY_RATIO/WIDTH_RATIO] = {{((DRM_DATA_WIDTH_A/(c_WR_BYTE_WIDTH*WIDTH_RATIO))-c_BE_WIDTH/WIDTH_RATIO){1'b1}},wr_byte_en_bus_p[gen_i_wd*c_BE_WIDTH/WIDTH_RATIO +:c_BE_WIDTH/WIDTH_RATIO]};
                end
            if(8*DATA_LOOP_NUM > c_BE_WIDTH*DATA_DUTY_RATIO)
              always@(*) begin
                wr_byte_en_bus[8*DATA_LOOP_NUM-1 : c_BE_WIDTH*DATA_DUTY_RATIO] = {(8*DATA_LOOP_NUM - c_BE_WIDTH*DATA_DUTY_RATIO){1'b0}};
              end
        end
        else
            always@(*)
            wr_byte_en_bus = wr_byte_en_bus_p;

    endgenerate

    assign  rd_addr_bus[ADDR_WIDTH_B-1:0] = {{(ADDR_WIDTH_B-c_RD_ADDR_WIDTH){1'b0}},rd_addr[c_RD_ADDR_WIDTH-1:0]};
    always@(*) begin
        drm_rd_addr = 16'b0;
//        if (DRM_DATA_WIDTH_A == 64 || DRM_DATA_WIDTH_A == 72) begin
//            case(DRM_DATA_WIDTH_B)  //synthesis parallel_case
//                1      : drm_rd_addr = {1'b1,rd_addr_bus[5],rd_addr_bus[(ADDR_WIDTH_B-CS_ADDR_WIDTH_B-1):6],rd_addr_bus[4:0]};
//                2      : drm_rd_addr = {1'b1,rd_addr_bus[4],rd_addr_bus[(ADDR_WIDTH_B-CS_ADDR_WIDTH_B-1):5],rd_addr_bus[3:0],1'b0};
//                4      : drm_rd_addr = {1'b1,rd_addr_bus[3],rd_addr_bus[(ADDR_WIDTH_B-CS_ADDR_WIDTH_B-1):4],rd_addr_bus[2:0],2'b00};
//                8,9    : drm_rd_addr = {1'b1,rd_addr_bus[2],rd_addr_bus[(ADDR_WIDTH_B-CS_ADDR_WIDTH_B-1):3],rd_addr_bus[1:0],3'b000};
//                16,18  : drm_rd_addr = {1'b1,rd_addr_bus[1],rd_addr_bus[(ADDR_WIDTH_B-CS_ADDR_WIDTH_B-1):2],rd_addr_bus[0],4'b0000};
//                32,36  : drm_rd_addr = {1'b1,rd_addr_bus[0],rd_addr_bus[(ADDR_WIDTH_B-CS_ADDR_WIDTH_B-1):1],5'b00000};
//                64,72  : drm_rd_addr = {1'b1,rd_addr_bus[(ADDR_WIDTH_B-CS_ADDR_WIDTH_B-1):0],6'b000000};
//                default: drm_rd_addr = 16'b0;
//            endcase
//        end
//        else begin
            case(DRM_DATA_WIDTH_B)  //synthesis parallel_case
                1      : drm_rd_addr = {1'b1,rd_addr_bus[(ADDR_WIDTH_B-CS_ADDR_WIDTH_B-1):0]};
                2      : drm_rd_addr = {1'b1,rd_addr_bus[(ADDR_WIDTH_B-CS_ADDR_WIDTH_B-1):0],1'b0};
                4      : drm_rd_addr = {1'b1,rd_addr_bus[(ADDR_WIDTH_B-CS_ADDR_WIDTH_B-1):0],2'b00};
                8,9    : drm_rd_addr = {1'b1,rd_addr_bus[(ADDR_WIDTH_B-CS_ADDR_WIDTH_B-1):0],3'b000};
                16,18  : drm_rd_addr = {1'b1,rd_addr_bus[(ADDR_WIDTH_B-CS_ADDR_WIDTH_B-1):0],4'b0000};
                32,36  : drm_rd_addr = {1'b1,rd_addr_bus[(ADDR_WIDTH_B-CS_ADDR_WIDTH_B-1):0],5'b00000};
                64,72  : drm_rd_addr = {1'b1,rd_addr_bus[(ADDR_WIDTH_B-CS_ADDR_WIDTH_B-1):0],6'b000000};
                default: drm_rd_addr = 16'b0;
            endcase
//        end
    end

    //*************************************************************************************************************************************************************
    //generate CSB bus
    localparam  CS_ADDR_B_3_LSB = (CS_ADDR_WIDTH_B >= 3) ? (ADDR_WIDTH_B-CS_ADDR_WIDTH_B+1) : (ADDR_WIDTH_B-2);  //avoid reveral index of wr_addr_bus
    localparam  CS_ADDR_B_4_LSB = (CS_ADDR_WIDTH_B >= 4) ? ((ADDR_WIDTH_B-CS_ADDR_WIDTH_B+2)) : (ADDR_WIDTH_B-2); //avoid reveral index of wr_addr_bus

    integer gen_csb;
    generate
    always@(*) begin
        for(gen_csb=0;gen_csb<ADDR_LOOP_NUM_B;gen_csb=gen_csb+1) begin
            if(DRM_DATA_WIDTH_B == 72 || DRM_DATA_WIDTH_B == 64) begin
                if (CS_ADDR_WIDTH_B == 0) begin
                    rd_cs_bit0 = 0;
                    rd_cs_bit1_bus[gen_csb] = 0;
                    rd_cs_bit2_bus[gen_csb] = 0;
                end
                else if(CS_ADDR_WIDTH_B == 1) begin
                    rd_cs_bit0 = rd_addr_bus[ADDR_WIDTH_B-CS_ADDR_WIDTH_B];
                    rd_cs_bit1_bus[gen_csb] = 0;
                    rd_cs_bit2_bus[gen_csb] = 0;
                end
                else if(CS_ADDR_WIDTH_B == 2) begin
                    rd_cs_bit0 = rd_addr_bus[ADDR_WIDTH_B-CS_ADDR_WIDTH_B];
                    rd_cs_bit1_bus[gen_csb] = rd_addr_bus[ADDR_WIDTH_B-1];
                    rd_cs_bit2_bus[gen_csb] = 0;
                end
                else if(CS_ADDR_WIDTH_B >= 3) begin
                    rd_cs_bit0 = rd_addr_bus[ADDR_WIDTH_B-CS_ADDR_WIDTH_B];
                    rd_cs_bit1_bus[gen_csb] = (rd_addr_bus[(ADDR_WIDTH_B-1):CS_ADDR_B_3_LSB] == (gen_csb/2) ) ? 0: 1;
                    rd_cs_bit2_bus[gen_csb] = 0;
                end
            end
            else begin
                if(CS_ADDR_WIDTH_B == 0) begin
                    rd_cs_bit0 = 0;
                    rd_cs_bit1_bus[gen_csb] = 0;
                    rd_cs_bit2_bus[gen_csb] = 0;
                end
                else if(CS_ADDR_WIDTH_B ==1 ) begin
                    rd_cs_bit0 = rd_addr_bus[ADDR_WIDTH_B-CS_ADDR_WIDTH_B];
                    rd_cs_bit1_bus[gen_csb] = 0;
                    rd_cs_bit2_bus[gen_csb] = 0;
                end
                else if(CS_ADDR_WIDTH_B == 2) begin
                    rd_cs_bit0 = rd_addr_bus[ADDR_WIDTH_B-2];
                    rd_cs_bit1_bus[gen_csb] = rd_addr_bus[ADDR_WIDTH_B-1];
                    rd_cs_bit2_bus[gen_csb] = 0;
                end
                else if(CS_ADDR_WIDTH_B == 3) begin
                    rd_cs_bit0 = rd_addr_bus[ADDR_WIDTH_B-3];
                    rd_cs_bit1_bus[gen_csb] = rd_addr_bus[ADDR_WIDTH_B-2];
                    rd_cs_bit2_bus[gen_csb] = rd_addr_bus[ADDR_WIDTH_B-1];
                end
                else if(CS_ADDR_WIDTH_B >= 4) begin
                    rd_cs_bit0 = rd_addr_bus[ADDR_WIDTH_B-CS_ADDR_WIDTH_B];
                    rd_cs_bit1_bus[gen_csb] = rd_addr_bus[ADDR_WIDTH_B - CS_ADDR_WIDTH_B + 1];
                    rd_cs_bit2_bus[gen_csb] = (rd_addr_bus[(ADDR_WIDTH_B - 1):CS_ADDR_B_4_LSB] == (gen_csb/4) ) ? 0 : 1;
                end
            end
        end
    end
    endgenerate

    integer  drm_d_i;
    generate
    always@(*) begin
        for (drm_d_i = 0; drm_d_i <DATA_LOOP_NUM; drm_d_i = drm_d_i+1) begin
            db_data_bus[drm_d_i*D_DRM_DATA_WIDTH_B +:D_DRM_DATA_WIDTH_B] = 'b0;
            da_data_bus[drm_d_i*D_DRM_DATA_WIDTH_A +:D_DRM_DATA_WIDTH_A] = 'b0;
            if(DRM_DATA_WIDTH_A == 72 || DRM_DATA_WIDTH_A == 64)          //DRM data_in = {DB,DA}
                {db_data_bus[(drm_d_i*D_DRM_DATA_WIDTH_B) +:D_DRM_DATA_WIDTH_B], da_data_bus[(drm_d_i*D_DRM_DATA_WIDTH_A) +:D_DRM_DATA_WIDTH_A]} = wr_data_mix_bus[drm_d_i*DRM_DATA_WIDTH_A +: DRM_DATA_WIDTH_A];
            else begin                                                    //DRM data_in = DA
                da_data_bus[drm_d_i*D_DRM_DATA_WIDTH_A +:D_DRM_DATA_WIDTH_A] = wr_data_mix_bus[drm_d_i*DRM_DATA_WIDTH_A +:DRM_DATA_WIDTH_A];
                db_data_bus[drm_d_i*D_DRM_DATA_WIDTH_B +:D_DRM_DATA_WIDTH_B] = 'b0;
            end
        end
    end
    endgenerate

    wire [36*DATA_LOOP_NUM*ADDR_LOOP_NUM_A-1:0]  QA_bus;
    wire [36*DATA_LOOP_NUM*ADDR_LOOP_NUM_B-1:0]  QB_bus;
    wire [36*DATA_LOOP_NUM-1:0]                  DA_bus;
    wire [36*DATA_LOOP_NUM-1:0]                  DB_bus;

    //***********************************************************************************************************************************************************
    //INSTANCE DRM
    //generate DRMs: ADDR_LOOP to cascade request address  and  DATA LOOP to cascade request data
    genvar gen_i,gen_j;
    generate
        for(gen_j=0;gen_j<ADDR_LOOP_NUM_A;gen_j=gen_j+1) begin:ADDR_LOOP
            for(gen_i=0;gen_i<DATA_LOOP_NUM;gen_i=gen_i+1) begin:DATA_LOOP
                localparam CSA_MASK_SEL = ((DRM_DATA_WIDTH_A == 72 || DRM_DATA_WIDTH_A == 64) ? (gen_j%MASK_NUM_A & 3'b011) : (gen_j%MASK_NUM_A));
                localparam CSB_MASK_SEL = gen_j%MASK_NUM_B;
                localparam RAM_MODE_SEL = (((DRM_DATA_WIDTH_A == 36 || DRM_DATA_WIDTH_A == 32) || (DRM_DATA_WIDTH_B == 36 || DRM_DATA_WIDTH_B == 32)) && (ADDR_STROBE_EN == 1)) ? "TRUE_DUAL_PORT" : "SIMPLE_DUAL_PORT";

                //data route
                if (D_DRM_DATA_WIDTH_A == 32)begin
                    assign  {DA_bus[gen_i*36+27 +:8], DA_bus[gen_i*36+18 +:8], DA_bus[gen_i*36+9 +:8], DA_bus[gen_i*36 +:8]} = da_data_bus[gen_i*D_DRM_DATA_WIDTH_A +:D_DRM_DATA_WIDTH_A];
                end
                else if (D_DRM_DATA_WIDTH_A == 16)begin
                    assign  {DA_bus[gen_i*36+9 +:8], DA_bus[gen_i*36 +:8]} = da_data_bus[gen_i*D_DRM_DATA_WIDTH_A +:D_DRM_DATA_WIDTH_A];
                end
                else begin
                    assign  DA_bus[gen_i*36 +:D_DRM_DATA_WIDTH_A] = da_data_bus[gen_i*D_DRM_DATA_WIDTH_A +:D_DRM_DATA_WIDTH_A];
                end

                if (D_DRM_DATA_WIDTH_B == 32)begin
                    assign  {DB_bus[gen_i*36+27 +:8], DB_bus[gen_i*36+18 +:8], DB_bus[gen_i*36+9 +:8], DB_bus[gen_i*36 +:8]} = db_data_bus[gen_i*D_DRM_DATA_WIDTH_B +:D_DRM_DATA_WIDTH_B];
                end
                else if (D_DRM_DATA_WIDTH_B == 16)begin
                    assign  {DB_bus[gen_i*36+9 +:8], DB_bus[gen_i*36 +:8]} = db_data_bus[gen_i*D_DRM_DATA_WIDTH_B +:D_DRM_DATA_WIDTH_B];
                end
                else begin
                    assign  DB_bus[gen_i*36 +:D_DRM_DATA_WIDTH_B] = db_data_bus[gen_i*D_DRM_DATA_WIDTH_B +:D_DRM_DATA_WIDTH_B];
                end

                if (Q_DRM_DATA_WIDTH_A == 32)begin
                    assign  qa_data_bus[gen_i*Q_DRM_DATA_WIDTH_A+gen_j*Q_CAS_DATA_WIDTH_A +:Q_DRM_DATA_WIDTH_A] = {QA_bus[(gen_i*36+gen_j*36*DATA_LOOP_NUM+27) +:8], QA_bus[(gen_i*36+gen_j*36*DATA_LOOP_NUM+18) +:8], QA_bus[(gen_i*36+gen_j*36*DATA_LOOP_NUM+9) +:8], QA_bus[(gen_i*36+gen_j*36*DATA_LOOP_NUM) +:8]};
                end
                else if (Q_DRM_DATA_WIDTH_A == 16) begin
                    assign  qa_data_bus[gen_i*Q_DRM_DATA_WIDTH_A+gen_j*Q_CAS_DATA_WIDTH_A +:Q_DRM_DATA_WIDTH_A] = {QA_bus[(gen_i*36+gen_j*36*DATA_LOOP_NUM+9) +:8], QA_bus[(gen_i*36+gen_j*36*DATA_LOOP_NUM) +:8]};
                end
                else begin
                    assign  qa_data_bus[gen_i*Q_DRM_DATA_WIDTH_A+gen_j*Q_CAS_DATA_WIDTH_A +:Q_DRM_DATA_WIDTH_A] = QA_bus[(gen_i*36+gen_j*36*DATA_LOOP_NUM) +:Q_DRM_DATA_WIDTH_A];
                end

                if (Q_DRM_DATA_WIDTH_B == 32)begin
                    assign  qb_data_bus[gen_i*Q_DRM_DATA_WIDTH_B+gen_j*Q_CAS_DATA_WIDTH_B +:Q_DRM_DATA_WIDTH_B] = {QB_bus[(gen_i*36+gen_j*36*DATA_LOOP_NUM+27) +:8], QB_bus[(gen_i*36+gen_j*36*DATA_LOOP_NUM+18) +:8],QB_bus[(gen_i*36+gen_j*36*DATA_LOOP_NUM+9) +:8], QB_bus[(gen_i*36+gen_j*36*DATA_LOOP_NUM) +:8]};
                end
                else if (Q_DRM_DATA_WIDTH_B == 16)begin
                    assign  qb_data_bus[gen_i*Q_DRM_DATA_WIDTH_B+gen_j*Q_CAS_DATA_WIDTH_B +:Q_DRM_DATA_WIDTH_B] = {QB_bus[(gen_i*36+gen_j*36*DATA_LOOP_NUM+9) +:8], QB_bus[(gen_i*36+gen_j*36*DATA_LOOP_NUM) +:8]};
                end
                else begin
                    assign  qb_data_bus[gen_i*Q_DRM_DATA_WIDTH_B+gen_j*Q_CAS_DATA_WIDTH_B +:Q_DRM_DATA_WIDTH_B] = QB_bus[(gen_i*36+gen_j*36*DATA_LOOP_NUM) +:Q_DRM_DATA_WIDTH_B];
                end

                case(DRM_DATA_WIDTH_A)
                   1      : assign wr_byte_en_bus_m[gen_i*8 +: 8]  =  wr_byte_en_bus;
                   2      : assign wr_byte_en_bus_m[gen_i*8 +: 8]  =  wr_byte_en_bus;
                   4      : assign wr_byte_en_bus_m[gen_i*8 +: 8]  =  wr_byte_en_bus;
                   8,9    : assign wr_byte_en_bus_m[gen_i*8 +: 8]  =  8'hff;
                   16,18  : assign wr_byte_en_bus_m[gen_i*8 +: 8]  =  (c_WR_BYTE_EN == 1) ? {6'b00_0000, wr_byte_en_bus[gen_i*2 +:2]} : wr_byte_en_bus;
                   32,36  : assign wr_byte_en_bus_m[gen_i*8 +: 8]  =  (c_WR_BYTE_EN == 1) ? {4'b0000,    wr_byte_en_bus[gen_i*4 +:4]} : wr_byte_en_bus;
                   64,72  : assign wr_byte_en_bus_m[gen_i*8 +: 8]  =  (c_WR_BYTE_EN == 1) ? {            wr_byte_en_bus[gen_i*8 +:8]} : wr_byte_en_bus;
                   default: assign wr_byte_en_bus_m[gen_i*8 +: 8]  =  8'b0;
                endcase

            GTP_DRM36K_E1 # (
                .GRS_EN                   ( "FALSE"                  ),
                .CSA_MASK                 ( CSA_MASK_SEL             ),
                .CSB_MASK                 ( CSB_MASK_SEL             ),
                .DATA_WIDTH_A             ( DRM_DATA_WIDTH_A         ),
                .DATA_WIDTH_B             ( DRM_DATA_WIDTH_B         ),
                .WRITE_MODE_A             ( "NORMAL_WRITE"           ),
                .WRITE_MODE_B             ( "NORMAL_WRITE"           ),
                .DOA_REG                  ( c_OUTPUT_REG             ),
                .DOB_REG                  ( c_OUTPUT_REG             ),
                .DOA_REG_CLKINV           ( c_RD_CLK_OR_POL_INV      ),
                .DOB_REG_CLKINV           ( c_RD_CLK_OR_POL_INV      ),

                .RST_TYPE                 ( c_RESET_TYPE             ),
                .RAM_MODE                 ( RAM_MODE_SEL             ),
                .INIT_FILE                ( c_INIT_FILE              ),
                .RAM_CASCADE              ( "NONE"                   ),
                .ECC_WRITE_EN             ( "FALSE"                  ),
                .ECC_READ_EN              ( "FALSE"                  ),
                .BLOCK_X                  ( gen_i                    ),
                .BLOCK_Y                  ( gen_j                    ),
                .RAM_ADDR_WIDTH           ( ADDR_WIDTH_A             ),
                .RAM_DATA_WIDTH           ( CAS_DATA_WIDTH_A         ),
                .INIT_FORMAT              ( c_INIT_FORMAT            )
            ) U_GTP_DRM36K_E1 (
                .DOA                      ( QA_bus[(gen_i*36+gen_j*36*DATA_LOOP_NUM) +:36]  ),
                .ADDRA                    ( drm_wr_addr_bus[gen_i*16 +:16]                  ),
                .ADDRA_HOLD               ( wr_addr_strobe                                  ),
                .BWEA                     ( wr_byte_en_bus_m[gen_i*8 +:8]                   ),
                .DIA                      ( DA_bus[gen_i*36 +:36]                           ),
                .CSA                      ( {wr_cs_bit2_bus[gen_j],wr_cs_bit1_bus[gen_j],wr_cs_bit0}      ),
                .WEA                      ( wr_en_bus[gen_i]                                ),
                .CLKA                     ( wr_clk                                          ),
                .CEA                      ( wr_clk_en                                       ),
                .ORCEA                    ( rd_oce                                          ),
                .RSTA                     ( wr_rst                                          ),
                .CINA                     (                                                 ),
                .COUTA                    (                                                 ),

                .DOB                      ( QB_bus[(gen_i*36+gen_j*36*DATA_LOOP_NUM) +:36]  ),
                .ADDRB                    ( drm_rd_addr[15:0]                               ),
                .ADDRB_HOLD               ( rd_addr_strobe                                  ),
                .BWEB                     ( {4'b0000}                                       ),
                .DIB                      ( DB_bus[gen_i*36 +:36]                           ),
                .CSB                      ( {rd_cs_bit2_bus[gen_j],rd_cs_bit1_bus[gen_j],rd_cs_bit0}      ),
                .WEB                      ( 1'b0                                            ),
                .CLKB                     ( rd_clk                                          ),
                .CEB                      ( rd_clk_en                                       ),
                .ORCEB                    ( rd_oce                                          ),
                .RSTB                     ( rd_rst                                          ),
                .CINB                     (                                                 ),
                .COUTB                    (                                                 ),

                .INJECT_SBITERR           (                                                 ),
                .INJECT_DBITERR           (                                                 ),
                .ECC_SBITERR              (                                                 ),
                .ECC_DBITERR              (                                                 ),
                .ECC_RDADDR               (                                                 ),
                .ECC_PARITY               (                                                 )
            );


                if(DRM_DATA_WIDTH_B == 72 || DRM_DATA_WIDTH_B == 64) begin
                    assign rd_data_bus[gen_i*DRM_DATA_WIDTH_B+gen_j*CAS_DATA_WIDTH_B +:DRM_DATA_WIDTH_B] = {qb_data_bus[(gen_i*Q_DRM_DATA_WIDTH_B+gen_j*Q_CAS_DATA_WIDTH_B) +:Q_DRM_DATA_WIDTH_B],qa_data_bus[(gen_i*Q_DRM_DATA_WIDTH_A+gen_j*Q_CAS_DATA_WIDTH_A) +:Q_DRM_DATA_WIDTH_A]};
                end
                else begin
                    assign rd_data_bus[gen_i*DRM_DATA_WIDTH_B+gen_j*CAS_DATA_WIDTH_B +:DRM_DATA_WIDTH_B] =  qb_data_bus[gen_i*Q_DRM_DATA_WIDTH_B+gen_j*Q_CAS_DATA_WIDTH_B +:Q_DRM_DATA_WIDTH_B];
                end
            end
        end
    endgenerate

    localparam   RD_ADDR_SEL_LSB = (CS_ADDR_WIDTH_B > 0) ? (ADDR_WIDTH_B - CS_ADDR_WIDTH_B) : (ADDR_WIDTH_B - 1);

    //cs read addr register  to match read data
    wire [CS_ADDR_WIDTH_B-1:0]   addr_bus_rd_sel;
    reg  [CS_ADDR_WIDTH_B-1:0]   addr_bus_rd_ce;
    reg  [CS_ADDR_WIDTH_B-1:0]   addr_bus_rd_ce_ff;
    wire [CS_ADDR_WIDTH_B-1:0]   addr_bus_rd_ce_mux;
    reg  [CS_ADDR_WIDTH_B-1:0]   addr_bus_rd_oce;
    reg  [CS_ADDR_WIDTH_B-1:0]   addr_bus_rd_invt;

    reg     wr_en_ff;

    //CE
    always @(posedge rd_clk)
    begin
        if (~rd_addr_strobe & rd_clk_en)
            addr_bus_rd_ce <= rd_addr_bus[ADDR_WIDTH_B-1:RD_ADDR_SEL_LSB];
    end

    //OCE
    always @(posedge rd_clk)
    begin
        if (rd_oce)
            addr_bus_rd_oce <= addr_bus_rd_ce;
    end

    //INVT
    always @(negedge rd_clk)
    begin
        if (rd_oce)
            addr_bus_rd_invt <= addr_bus_rd_ce;
    end

    assign  addr_bus_rd_sel = (c_RD_CLK_OR_POL_INV == 1) ? addr_bus_rd_invt : (c_OUTPUT_REG == 1) ? addr_bus_rd_oce : addr_bus_rd_ce;

    //select read data
    integer cs_rd;
    generate
    always@(*) begin
        rd_mix_data = 'b0;
        if(ADDR_LOOP_NUM_B >1 ) begin
            for(cs_rd=0;cs_rd<ADDR_LOOP_NUM_B;cs_rd=cs_rd+1) begin
                if(addr_bus_rd_sel== cs_rd)
                    rd_mix_data = rd_data_bus[cs_rd*CAS_DATA_WIDTH_B +:CAS_DATA_WIDTH_B];
            end
        end
        else begin
            rd_mix_data = rd_data_bus;
        end
    end
    endgenerate

    integer  gen_i_rd,gen_j_rd;
    generate
    always@(*) begin
        if( c_RD_DATA_WIDTH > c_WR_DATA_WIDTH && DATA_LOOP_NUM > 1 ) begin   //read mix data
            for (gen_i_rd=0;gen_i_rd < WIDTH_RATIO;gen_i_rd = gen_i_rd + 1)
                for(gen_j_rd=0;gen_j_rd < DATA_LOOP_NUM ;gen_j_rd = gen_j_rd+1)
                    rd_full_data[gen_i_rd*(CAS_DATA_WIDTH_B/WIDTH_RATIO)+gen_j_rd*DRM_DATA_WIDTH_A +:DRM_DATA_WIDTH_A] = rd_mix_data[(gen_i_rd + gen_j_rd*WIDTH_RATIO)*DRM_DATA_WIDTH_A +:DRM_DATA_WIDTH_A];
        end
        else if(c_RD_DATA_WIDTH > c_WR_DATA_WIDTH && DATA_LOOP_NUM == 1 && DRM_DATA_WIDTH_B > c_RD_DATA_WIDTH) begin
            for (gen_i_rd=0;gen_i_rd < WIDTH_RATIO;gen_i_rd = gen_i_rd + 1)
                    rd_full_data[gen_i_rd*c_WR_DATA_WIDTH +:c_WR_DATA_WIDTH] = rd_mix_data[gen_i_rd*DRM_DATA_WIDTH_A +:c_WR_DATA_WIDTH];
        end
        else begin    //read nomix data
            rd_full_data = rd_mix_data;
        end
    end
    endgenerate

    assign  rd_data = rd_full_data[c_RD_DATA_WIDTH-1:0];

endmodule
