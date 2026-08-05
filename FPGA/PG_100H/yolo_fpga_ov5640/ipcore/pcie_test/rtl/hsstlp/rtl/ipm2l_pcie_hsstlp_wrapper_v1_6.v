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
`timescale 1ns/100fs

module ipm2l_hsstlp_wrapper_v1_6#(
    //--------Global Parameter--------//
    parameter               PLL0_EN                             = "FALSE"     ,//TRUE, FALSE; for PLL0 enable
    parameter               PLL1_EN                             = "FALSE"     ,//TRUE, FALSE; for PLL1 enable
    parameter               CH0_EN                              = "DISABLE"   ,//"Fullduplex","TX_only","RX_only","DISABLE"
    parameter               CH1_EN                              = "DISABLE"   ,//"Fullduplex","TX_only","RX_only","DISABLE"
    parameter               CH2_EN                              = "DISABLE"   ,//"Fullduplex","TX_only","RX_only","DISABLE"
    parameter               CH3_EN                              = "DISABLE"   ,//"Fullduplex","TX_only","RX_only","DISABLE"
    parameter               CHANNEL0_EN                         = "FALSE"     ,//TRUE, FALSE; for Channel0 enable
    parameter               CHANNEL1_EN                         = "FALSE"     ,//TRUE, FALSE; for Channel1 enable
    parameter               CHANNEL2_EN                         = "FALSE"     ,//TRUE, FALSE; for Channel2 enable
    parameter               CHANNEL3_EN                         = "FALSE"     ,//TRUE, FALSE; for Channel3 enable
    parameter               TX_CHANNEL0_PLL                     = 0           ,//0: select PLL0 1: select PLL1
    parameter               TX_CHANNEL1_PLL                     = 0           ,//0: select PLL0 1: select PLL1
    parameter               TX_CHANNEL2_PLL                     = 0           ,//0: select PLL0 1: select PLL1
    parameter               TX_CHANNEL3_PLL                     = 0           ,//0: select PLL0 1: select PLL1
    parameter               RX_CHANNEL0_PLL                     = 0           ,//0: select PLL0 1: select PLL1
    parameter               RX_CHANNEL1_PLL                     = 0           ,//0: select PLL0 1: select PLL1
    parameter               RX_CHANNEL2_PLL                     = 0           ,//0: select PLL0 1: select PLL1
    parameter               RX_CHANNEL3_PLL                     = 0           ,//0: select PLL0 1: select PLL1
    parameter               CH0_MULT_LANE_MODE                  = 1           , //Lane0 --> 1: Singel Lane 2:Two Lane 4:Four Lane
    parameter               CH1_MULT_LANE_MODE                  = 1           , //Lane1 --> 1: Singel Lane 2:Two Lane 4:Four Lane
    parameter               CH2_MULT_LANE_MODE                  = 1           , //Lane2 --> 1: Singel Lane 2:Two Lane 4:Four Lane
    parameter               CH3_MULT_LANE_MODE                  = 1           , //Lane3 --> 1: Singel Lane 2:Two Lane 4:Four Lane
    parameter               PLL0_TXPCLK_PLL_SEL                 = 0           ,//0: PLL0 clock from channel 0 
    parameter               PLL1_TXPCLK_PLL_SEL                 = 0           ,//0: PLL1 clock from channel 0 
    //--------PLL0 parameter--------//
    parameter    integer    PMA_PLL0_TX_SYNCK_PD = 0                          ,//0:txsync_cp powerup 1:txysnc_cp powerdown                                                  
    parameter               PMA_PLL0_REG_REFCLK_TERM_IMP_CTRL = "TRUE"        ,//refclk termination impedance selection register,don't support simulation                   
                                                                                                                                                                            
    parameter    integer    PMA_PLL0_REG_BG_TRIM = 2                          ,//v2i config, don't support simulation                                                       
    parameter    integer    PMA_PLL0_REG_IBUP_A1 = 262143                     ,//v2i config, don't support simulation                                                       
    parameter    integer    PMA_PLL0_REG_IBUP_A2 = 3072                       ,//v2i config, don't support simulation                                                       
    parameter    integer    PMA_PLL0_REG_IBUP_PD = 0                          ,//v2i config, don't support simulation                                                       
    parameter               PMA_PLL0_REG_V2I_BIAS_SEL = "FALSE"               ,//v2i config, don't support simulation                                                       
    parameter               PMA_PLL0_REG_V2I_EN = "TRUE"                      ,//v2i config, don't support simulation                                                       
    parameter    integer    PMA_PLL0_REG_V2I_TB_SEL = 0                       ,//v2i config, don't support simulation                                                       
    parameter               PMA_PLL0_REG_V2I_RCALTEST_PD = "FALSE"            ,//v2i config, don't support simulation                                                       
    parameter    integer    PMA_PLL0_REG_RES_CAL_TEST = 0                     ,//v2i config, don't support simulation                                                       
    parameter    integer    PMA_PLL0_RES_CAL_DIV = 0                          ,//v2i config, don't support simulation                                                       
    parameter               PMA_PLL0_RES_CAL_CLK_SEL = "FALSE"                ,//v2i config, don't support simulation                                                       
                                                                                                                                                                           
    parameter               PMA_PLL0_REG_PLL_PFDDELAY_EN = "TRUE"             ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL0_REG_PFDDELAYSEL = 1                      ,//default:1
    parameter    integer    PMA_PLL0_REG_PLL_VCTRL_SET = 0                    ,//default:0                                                                                  
    parameter               PMA_PLL0_REG_READY_OR_LOCK = "FALSE"              ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL0_REG_PLL_CP = 31                          ,//Min current :1, Max current:1023, Default: 31                                              
    parameter    integer    PMA_PLL0_REG_PLL_REFDIV = 16                      ,//Pll reference clock divider M, default: 16                                                 
    parameter               PMA_PLL0_REG_PLL_LOCKDET_EN = "FALSE"             ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL0_REG_PLL_READY = "FALSE"                  ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL0_REG_PLL_READY_OW = "FALSE"               ,//TRUE, FALSEt                                                                               
    parameter    integer    PMA_PLL0_REG_PLL_FBDIV = 36                       ,//Pll feedback divider N2 is Pll_fbdiv<5> :Pll_fbdiv<5>=1 ---> N2=5,Pll_fbdiv<5>=0 ---> N2=4,
                                                                               //Pll feedback divider N1 is Pll_fbdiv<4:0> :1,2,3,4,5,6,8,10                                
    parameter    integer    PMA_PLL0_REG_LPF_RES = 1                          ,//LPF resistor control,Default: 1                                                            
    parameter               PMA_PLL0_REG_JTAG_OE = "FALSE"                    ,//Pll jtag oe                                                                                
    parameter    integer    PMA_PLL0_REG_JTAG_VHYSTSEL = 0                    ,//Pll jtag threshod voltage selection,default (0)                                            
    parameter               PMA_PLL0_REG_PLL_LOCKDET_EN_OW = "FALSE"          ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL0_REG_PLL_LOCKDET_FBCT = 7                 ,//0: 2^9,1: 2^10,2: 2^11,3: 2^12,4: 2^13,5: 2^14,6: 2^15,7: 2^16-1 (default)                 
    parameter    integer    PMA_PLL0_REG_PLL_LOCKDET_ITER = 3                 ,//0: 1,1: 2,2: 4,3: 8(default),4: 16,5: 32,6: 64,7:127                                       
    parameter               PMA_PLL0_REG_PLL_LOCKDET_MODE = "FALSE"           ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL0_REG_PLL_LOCKDET_LOCKCT = 4               ,///0: 2,1: 4,2: 8,3: 16,4: 32 (default),5: 64,6: 128,7: 256                                  
    parameter    integer    PMA_PLL0_REG_PLL_LOCKDET_REFCT = 7                ,//0: 2^9,1: 2^10,2: 2^11,3: 2^12,4: 2^13,5: 2^14,6: 2^15,7: 2^16-1 (default )                
    parameter               PMA_PLL0_REG_PLL_LOCKDET_RESET_N = "TRUE"         ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL0_REG_PLL_LOCKDET_RESET_N_OW = "FALSE"     ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL0_REG_PLL_LOCKED = "FALSE"                 ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL0_REG_PLL_LOCKED_OW = "FALSE"              ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL0_REG_PLL_LOCKED_STICKY_CLEAR = "FALSE"    ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL0_REG_PLL_UNLOCKED = "FALSE"               ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL0_REG_PLL_UNLOCKDET_ITER = 2               ,//00: 63, 01: 127, 10: 255 (default),11: 1023                                                
    parameter               PMA_PLL0_REG_PLL_UNLOCKED_OW = "FALSE"            ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL0_REG_PLL_UNLOCKED_STICKY_CLEAR = "FALSE"  ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL0_REG_I_CTRL_MAX = 63                      ,//0 to 63, Default :6b'111111                                                                
    parameter               PMA_PLL0_REG_REFCLK_TEST_EN = "FALSE"             ,//TRUE, FALSE; for refclk port test                                                          
    parameter               PMA_PLL0_REG_RESCAL_EN = "FALSE"                  ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL0_REG_I_CTRL_MIN = 0                       ,//0 to 63                                                                                    
    parameter               PMA_PLL0_REG_RESCAL_DONE_OW = "FALSE"             ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL0_REG_RESCAL_DONE_VAL = "FALSE"            ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL0_REG_RESCAL_I_CODE = 46                   ,//0 to 63                                                                                    
    parameter               PMA_PLL0_REG_RESCAL_I_CODE_OW = "FALSE"           ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL0_REG_RESCAL_I_CODE_PMA = "FALSE"          ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL0_REG_RESCAL_I_CODE_VAL = 46               ,//0 to 63                                                                                    
    parameter               PMA_PLL0_REG_RESCAL_INT_R_SMALL_OW = "FALSE"      ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL0_REG_RESCAL_INT_R_SMALL_VAL = "FALSE"     ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL0_REG_RESCAL_ITER_VALID_SEL = 0            ,//0,1,2,3                                                                                    
    parameter               PMA_PLL0_REG_RESCAL_RESET_N_OW = "FALSE"          ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL0_REG_RESCAL_RST_N_VAL = "FALSE"           ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL0_REG_RESCAL_WAIT_SEL = "TRUE"             ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL0_REFCLK2LANE_PD_L = "FALSE"               ,//TRUE, FALSE; for pll_refclk_lane_l power down control                                      
    parameter               PMA_PLL0_REFCLK2LANE_PD_R = "FALSE"               ,//TRUE, FALSE; for pll_refclk_lane_r power down control                                      
    parameter               PMA_PLL0_REG_LOCKDET_REPEAT = "FALSE"             ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL0_REG_NOFBCLK_STICKY_CLEAR = "FALSE"       ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL0_REG_NOREFCLK_STICKY_CLEAR = "FALSE"      ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL0_REG_TEST_SEL = 15                        ,//0 to 20; for test                                                                          
    parameter               PMA_PLL0_REG_TEST_V_EN = "FALSE"                  ,//TRUE, FALSE;for test                                                                       
    parameter               PMA_PLL0_REG_TEST_SIG_HALF_EN = "FALSE"           ,//TRUE, FALSE;for test                                                                       
    parameter               PMA_PLL0_REG_REFCLK_PAD_SEL = "FALSE"             ,//TRUE, FALSE;for reference clock selection                                                  
    parameter               PMA_PLL0_PARM_PLL_POWERUP = "OFF"                 ,//ON, OFF                                                                                    
    //--------PLL1 parameter--------//
    parameter    integer    PMA_PLL1_TX_SYNCK_PD = 0                          ,//0:txsync_cp powerup 1:txysnc_cp powerdown                                                  
    parameter               PMA_PLL1_REG_REFCLK_TERM_IMP_CTRL = "TRUE"        ,//refclk termination impedance selection register,don't support simulation                   
                                                                                                                                                                            
    parameter    integer    PMA_PLL1_REG_BG_TRIM = 2                          ,//v2i config, don't support simulation                                                       
    parameter    integer    PMA_PLL1_REG_IBUP_A1 = 262143                     ,//v2i config, don't support simulation                                                       
    parameter    integer    PMA_PLL1_REG_IBUP_A2 = 3072                       ,//v2i config, don't support simulation                                                       
    parameter    integer    PMA_PLL1_REG_IBUP_PD = 0                          ,//v2i config, don't support simulation                                                       
    parameter               PMA_PLL1_REG_V2I_BIAS_SEL = "FALSE"               ,//v2i config, don't support simulation                                                       
    parameter               PMA_PLL1_REG_V2I_EN = "TRUE"                      ,//v2i config, don't support simulation                                                       
    parameter    integer    PMA_PLL1_REG_V2I_TB_SEL = 0                       ,//v2i config, don't support simulation                                                       
    parameter               PMA_PLL1_REG_V2I_RCALTEST_PD = "FALSE"            ,//v2i config, don't support simulation                                                       
    parameter    integer    PMA_PLL1_REG_RES_CAL_TEST = 0                     ,//v2i config, don't support simulation                                                       
    parameter    integer    PMA_PLL1_RES_CAL_DIV = 0                          ,//v2i config, don't support simulation                                                       
    parameter               PMA_PLL1_RES_CAL_CLK_SEL = "FALSE"                ,//v2i config, don't support simulation                                                       
                                                                                                                                                                           
    parameter               PMA_PLL1_REG_PLL_PFDDELAY_EN = "TRUE"             ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL1_REG_PFDDELAYSEL = 1                      ,//default:1
    parameter    integer    PMA_PLL1_REG_PLL_VCTRL_SET = 0                    ,//default:0                                                                                  
    parameter               PMA_PLL1_REG_READY_OR_LOCK = "FALSE"              ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL1_REG_PLL_CP = 31                          ,//Min current :1, Max current:1023, Default: 31                                              
    parameter    integer    PMA_PLL1_REG_PLL_REFDIV = 16                      ,//Pll reference clock divider M, default: 16                                                 
    parameter               PMA_PLL1_REG_PLL_LOCKDET_EN = "FALSE"             ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL1_REG_PLL_READY = "FALSE"                  ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL1_REG_PLL_READY_OW = "FALSE"               ,//TRUE, FALSEt                                                                               
    parameter    integer    PMA_PLL1_REG_PLL_FBDIV = 36                       ,//Pll feedback divider N2 is Pll_fbdiv<5> :Pll_fbdiv<5>=1 ---> N2=5,Pll_fbdiv<5>=0 ---> N2=4,
                                                                               //Pll feedback divider N1 is Pll_fbdiv<4:0> :1,2,3,4,5,6,8,10                                
    parameter    integer    PMA_PLL1_REG_LPF_RES = 1                          ,//LPF resistor control,Default: 1                                                            
    parameter               PMA_PLL1_REG_JTAG_OE = "FALSE"                    ,//Pll jtag oe                                                                                
    parameter    integer    PMA_PLL1_REG_JTAG_VHYSTSEL = 0                    ,//Pll jtag threshod voltage selection,default (0)                                            
    parameter               PMA_PLL1_REG_PLL_LOCKDET_EN_OW = "FALSE"          ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL1_REG_PLL_LOCKDET_FBCT = 7                 ,//0: 2^9,1: 2^10,2: 2^11,3: 2^12,4: 2^13,5: 2^14,6: 2^15,7: 2^16-1 (default)                 
    parameter    integer    PMA_PLL1_REG_PLL_LOCKDET_ITER = 3                 ,//0: 1,1: 2,2: 4,3: 8(default),4: 16,5: 32,6: 64,7:127                                       
    parameter               PMA_PLL1_REG_PLL_LOCKDET_MODE = "FALSE"           ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL1_REG_PLL_LOCKDET_LOCKCT = 4               ,///0: 2,1: 4,2: 8,3: 16,4: 32 (default),5: 64,6: 128,7: 256                                  
    parameter    integer    PMA_PLL1_REG_PLL_LOCKDET_REFCT = 7                ,//0: 2^9,1: 2^10,2: 2^11,3: 2^12,4: 2^13,5: 2^14,6: 2^15,7: 2^16-1 (default )                
    parameter               PMA_PLL1_REG_PLL_LOCKDET_RESET_N = "TRUE"         ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL1_REG_PLL_LOCKDET_RESET_N_OW = "FALSE"     ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL1_REG_PLL_LOCKED = "FALSE"                 ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL1_REG_PLL_LOCKED_OW = "FALSE"              ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL1_REG_PLL_LOCKED_STICKY_CLEAR = "FALSE"    ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL1_REG_PLL_UNLOCKED = "FALSE"               ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL1_REG_PLL_UNLOCKDET_ITER = 2               ,//00: 63, 01: 127, 10: 255 (default),11: 1023                                                
    parameter               PMA_PLL1_REG_PLL_UNLOCKED_OW = "FALSE"            ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL1_REG_PLL_UNLOCKED_STICKY_CLEAR = "FALSE"  ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL1_REG_I_CTRL_MAX = 63                      ,//0 to 63, Default :6b'111111                                                                
    parameter               PMA_PLL1_REG_REFCLK_TEST_EN = "FALSE"             ,//TRUE, FALSE; for refclk port test                                                          
    parameter               PMA_PLL1_REG_RESCAL_EN = "FALSE"                  ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL1_REG_I_CTRL_MIN = 0                       ,//0 to 63                                                                                    
    parameter               PMA_PLL1_REG_RESCAL_DONE_OW = "FALSE"             ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL1_REG_RESCAL_DONE_VAL = "FALSE"            ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL1_REG_RESCAL_I_CODE = 46                   ,//0 to 63                                                                                    
    parameter               PMA_PLL1_REG_RESCAL_I_CODE_OW = "FALSE"           ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL1_REG_RESCAL_I_CODE_PMA = "FALSE"          ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL1_REG_RESCAL_I_CODE_VAL = 46               ,//0 to 63                                                                                    
    parameter               PMA_PLL1_REG_RESCAL_INT_R_SMALL_OW = "FALSE"      ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL1_REG_RESCAL_INT_R_SMALL_VAL = "FALSE"     ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL1_REG_RESCAL_ITER_VALID_SEL = 0            ,//0,1,2,3                                                                                    
    parameter               PMA_PLL1_REG_RESCAL_RESET_N_OW = "FALSE"          ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL1_REG_RESCAL_RST_N_VAL = "FALSE"           ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL1_REG_RESCAL_WAIT_SEL = "TRUE"             ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL1_REFCLK2LANE_PD_L = "FALSE"               ,//TRUE, FALSE; for pll_refclk_lane_l power down control                                      
    parameter               PMA_PLL1_REFCLK2LANE_PD_R = "FALSE"               ,//TRUE, FALSE; for pll_refclk_lane_r power down control                                      
    parameter               PMA_PLL1_REG_LOCKDET_REPEAT = "FALSE"             ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL1_REG_NOFBCLK_STICKY_CLEAR = "FALSE"       ,//TRUE, FALSE                                                                                
    parameter               PMA_PLL1_REG_NOREFCLK_STICKY_CLEAR = "FALSE"      ,//TRUE, FALSE                                                                                
    parameter    integer    PMA_PLL1_REG_TEST_SEL = 15                        ,//0 to 20; for test                                                                          
    parameter               PMA_PLL1_REG_TEST_V_EN = "FALSE"                  ,//TRUE, FALSE;for test                                                                       
    parameter               PMA_PLL1_REG_TEST_SIG_HALF_EN = "FALSE"           ,//TRUE, FALSE;for test                                                                       
    parameter               PMA_PLL1_REG_REFCLK_PAD_SEL = "FALSE"             ,//TRUE, FALSE;for reference clock selection                                                  
    parameter               PMA_PLL1_PARM_PLL_POWERUP = "OFF"                 ,//ON, OFF                                                                                    
    //--------CHANNEL0 parameter--------//
    parameter    integer    CH0_MUX_BIAS = 2                                      ,//0 to 7; don't support simulation                                             
    parameter    integer    CH0_PD_CLK = 0                                        ,//0 to 1                                                                       
    parameter    integer    CH0_REG_SYNC = 0                                      ,//0 to 1                                                                       
    parameter    integer    CH0_REG_SYNC_OW = 0                                   ,//0 to 1                                                                       
    parameter    integer    CH0_PLL_LOCK_OW = 0                                   ,//0 to 1                                                                       
    parameter    integer    CH0_PLL_LOCK_OW_EN = 0                                ,//0 to 1                                                                       
    //pcs
    parameter    integer    PCS_CH0_SLAVE = 0                                     ,//Altered in 2019.12.05, should be configured by user, software only checks corresponding connection of clock
    parameter               PCS_CH0_BYPASS_WORD_ALIGN = "FALSE"                   ,//TRUE, FALSE; for bypass word alignment                                       
    parameter               PCS_CH0_BYPASS_DENC = "FALSE"                         ,//TRUE, FALSE; for bypass 8b/10b decoder                                       
    parameter               PCS_CH0_BYPASS_BONDING = "FALSE"                      ,//TRUE, FALSE; for bypass channel bonding                                      
    parameter               PCS_CH0_BYPASS_CTC = "FALSE"                          ,//TRUE, FALSE; for bypass ctc                                                  
    parameter               PCS_CH0_BYPASS_GEAR = "FALSE"                         ,//TRUE, FALSE; for bypass Rx Gear                                              
    parameter               PCS_CH0_BYPASS_BRIDGE = "FALSE"                       ,//TRUE, FALSE; for bypass Rx Bridge unit                                       
    parameter               PCS_CH0_BYPASS_BRIDGE_FIFO = "FALSE"                  ,//TRUE, FALSE; for bypass Rx Bridge FIFO                                       
    parameter               PCS_CH0_DATA_MODE = "X8"                              ,//"X8","X10","X16","X20"                                                       
    parameter               PCS_CH0_RX_POLARITY_INV = "DELAY"                     ,//"DELAY","BIT_POLARITY_INVERION","BIT_REVERSAL","BOTH"                        
    parameter               PCS_CH0_ALIGN_MODE = "1GB"                            ,//1GB, 10GB, RAPIDIO, OUTSIDE                                                  
    parameter               PCS_CH0_SAMP_16B = "X20"                              ,//"X20",X16                                                                    
    parameter               PCS_CH0_FARLP_PWR_REDUCTION = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PCS_CH0_COMMA_REG0 = 0                                ,//0 to 1023                                                                    
    parameter    integer    PCS_CH0_COMMA_MASK = 0                                ,//0 to 1023                                                                    
    parameter               PCS_CH0_CEB_MODE = "10GB"                             ,//"10GB" "RAPIDIO" "OUTSIDE"                                                   
    parameter               PCS_CH0_CTC_MODE = "1SKIP"                            ,//1SKIP, 2SKIP, PCIE_2BYTE, 4SKIP                                              
    parameter    integer    PCS_CH0_A_REG = 0                                     ,//0 to 255                                                                     
    parameter               PCS_CH0_GE_AUTO_EN = "FALSE"                          ,//TRUE, FALSE;                                                                 
    parameter    integer    PCS_CH0_SKIP_REG0 = 0                                 ,//0 to 1023                                                                    
    parameter    integer    PCS_CH0_SKIP_REG1 = 0                                 ,//0 to 1023                                                                    
    parameter    integer    PCS_CH0_SKIP_REG2 = 0                                 ,//0 to 1023                                                                    
    parameter    integer    PCS_CH0_SKIP_REG3 = 0                                 ,//0 to 1023                                                                    
    parameter               PCS_CH0_DEC_DUAL = "FALSE"                            ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_SPLIT = "FALSE"                               ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_FIFOFLAG_CTC = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_COMMA_DET_MODE = "COMMA_PATTERN"              ,//"RX_CLK_SLIP" "COMMA_PATTERN"                                                
    parameter               PCS_CH0_ERRDETECT_SILENCE = "TRUE"                    ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_PMA_RCLK_POLINV = "PMA_RCLK"                  ,//"PMA_RCLK" "REVERSE_OF_PMA_RCLK"                                             
    parameter               PCS_CH0_PCS_RCLK_SEL = "PMA_RCLK"                     ,//"PMA_RCLK" "PMA_TCLK" "RCLK"                                                 
    parameter               PCS_CH0_CB_RCLK_SEL = "PMA_RCLK"                      ,//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK"                                             
    parameter               PCS_CH0_AFTER_CTC_RCLK_SEL = "PMA_RCLK"               ,//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK" "RCLK2"                                     
    parameter               PCS_CH0_RCLK_POLINV = "RCLK"                          ,//"RCLK" "REVERSE_OF_RCLK"                                                     
    parameter               PCS_CH0_BRIDGE_RCLK_SEL = "PMA_RCLK"                  ,//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK" "RCLK"                                      
    parameter               PCS_CH0_PCS_RCLK_EN = "FALSE"                         ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_CB_RCLK_EN = "FALSE"                          ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_AFTER_CTC_RCLK_EN = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_AFTER_CTC_RCLK_EN_GB = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_PCS_RX_RSTN = "TRUE"                          ,//TRUE, FALSE; for PCS Receiver Reset                                          
    parameter               PCS_CH0_PCIE_SLAVE = "MASTER"                         ,//"MASTER","SLAVE"                                                             
    parameter               PCS_CH0_RX_64B66B_67B = "NORMAL"                      ,//"NORMAL" "64B_66B" "64B_67B"                                                 
    parameter               PCS_CH0_RX_BRIDGE_CLK_POLINV = "RX_BRIDGE_CLK"        ,//"RX_BRIDGE_CLK" "REVERSE_OF_RX_BRIDGE_CLK"                                   
    parameter               PCS_CH0_PCS_CB_RSTN = "TRUE"                          ,//TRUE, FALSE; for PCS CB Reset                                                
    parameter               PCS_CH0_TX_BRIDGE_GEAR_SEL = "FALSE"                  ,//TRUE: tx gear priority, FALSE:tx bridge unit priority                        
    parameter               PCS_CH0_TX_BYPASS_BRIDGE_UINT = "FALSE"               ,//TRUE, FALSE; for bypass                                                      
    parameter               PCS_CH0_TX_BYPASS_BRIDGE_FIFO = "FALSE"               ,//TRUE, FALSE; for bypass Tx Bridge FIFO                                       
    parameter               PCS_CH0_TX_BYPASS_GEAR = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_TX_BYPASS_ENC = "FALSE"                       ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_TX_BYPASS_BIT_SLIP = "TRUE"                   ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_TX_GEAR_SPLIT = "TRUE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_TX_DRIVE_REG_MODE = "NO_CHANGE"               ,//"NO_CHANGE" "EN_POLARIY_REV" "EN_BIT_REV" "EN_BOTH"                          
    parameter    integer    PCS_CH0_TX_BIT_SLIP_CYCLES = 0                        ,//o to 31                                                                      
    parameter               PCS_CH0_INT_TX_MASK_0 = "FALSE"                       ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_INT_TX_MASK_1 = "FALSE"                       ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_INT_TX_MASK_2 = "FALSE"                       ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_INT_TX_CLR_0 = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_INT_TX_CLR_1 = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_INT_TX_CLR_2 = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_TX_PMA_TCLK_POLINV = "PMA_TCLK"               ,//"PMA_TCLK" "REVERSE_OF_PMA_TCLK"                                             
    parameter               PCS_CH0_TX_PCS_CLK_EN_SEL = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_TX_BRIDGE_TCLK_SEL = "TCLK"                   ,//"PCS_TCLK" "TCLK"                                                            
    parameter               PCS_CH0_TX_TCLK_POLINV = "TCLK"                       ,//"TCLK" "REVERSE_OF_TCLK"                                                     
    parameter               PCS_CH0_PCS_TCLK_SEL= "PMA_TCLK"                      ,//"PMA_TCLK" "TCLK"                                                            
    parameter               PCS_CH0_TX_PCS_TX_RSTN = "TRUE"                       ,//TRUE, FALSE; for PCS Transmitter Reset                                       
    parameter               PCS_CH0_TX_SLAVE = "MASTER"                           ,//"MASTER" "SLAVE"                                                             
    parameter               PCS_CH0_TX_GEAR_CLK_EN_SEL = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH0_DATA_WIDTH_MODE = "X20"                       ,//"X8" "X10" "X16" "X20"                                                       
    parameter               PCS_CH0_TX_64B66B_67B = "NORMAL"                      ,//"NORMAL" "64B_66B" "64B_67B"                                                 
    parameter               PCS_CH0_GEAR_TCLK_SEL = "PMA_TCLK"                    ,//"PMA_TCLK" "TCLK2"                                                           
    parameter               PCS_CH0_TX_TCLK2FABRIC_SEL = "TRUE"                   ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_TX_OUTZZ = "FALSE"                            ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_ENC_DUAL = "FALSE"                            ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_TX_BITSLIP_DATA_MODE = "X10"                  ,//"X10" "X20"                                                                  
    parameter               PCS_CH0_TX_BRIDGE_CLK_POLINV = "TX_BRIDGE_CLK"        ,//"TX_BRIDGE_CLK" "REVERSE_OF_TX_BRIDGE_CLK"                                   
    parameter    integer    PCS_CH0_COMMA_REG1 = 0                                ,//0 to 1023                                                                    
    parameter    integer    PCS_CH0_RAPID_IMAX = 0                                ,//0 to 7                                                                       
    parameter    integer    PCS_CH0_RAPID_VMIN_1 = 0                              ,//0 to 255                                                                     
    parameter    integer    PCS_CH0_RAPID_VMIN_2 = 0                              ,//0 to 255                                                                     
    parameter               PCS_CH0_RX_PRBS_MODE = "DISABLE"                      ,//DISABLE PRBS_7 PRBS_15 PRBS_23 PRBS_31                                       
    parameter               PCS_CH0_RX_ERRCNT_CLR = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_PRBS_ERR_LPBK = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_TX_PRBS_MODE = "DISABLE"                      ,//DISABLE PRBS_7 PRBS_15 PRBS_23 PRBS_31 LONG_1 LONG_0 20UI D10_2 PCIE         
    parameter               PCS_CH0_TX_INSERT_ER = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_ENABLE_PRBS_GEN = "FALSE"                     ,//TRUE, FALSE                                                                  
    parameter    integer    PCS_CH0_DEFAULT_RADDR = 6                             ,//0 to 15                                                                      
    parameter    integer    PCS_CH0_MASTER_CHECK_OFFSET = 0                       ,//0 to 15                                                                      
    parameter    integer    PCS_CH0_DELAY_SET = 0                                 ,//0 to 15                                                                      
    parameter               PCS_CH0_SEACH_OFFSET = "20BIT"                        ,//"20BIT" 30BIT" "40BIT" "50BIT" "60BIT" "70BIT" "80BIT"                       
    parameter    integer    PCS_CH0_CEB_RAPIDLS_MMAX = 0                          ,//0 to 7                                                                       
    parameter    integer    PCS_CH0_CTC_AFULL = 20                                ,//0 to 31                                                                      
    parameter    integer    PCS_CH0_CTC_AEMPTY = 12                               ,//0 to 31                                                                      
    parameter    integer    PCS_CH0_CTC_CONTI_SKP_SET = 0                         ,//0 to 1                                                                       
    parameter               PCS_CH0_FAR_LOOP = "FALSE"                            ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_NEAR_LOOP = "FALSE"                           ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_PMA_TX2RX_PLOOP_EN = "FALSE"                  ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_PMA_TX2RX_SLOOP_EN = "FALSE"                  ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_PMA_RX2TX_PLOOP_EN = "FALSE"                  ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_INT_RX_MASK_0 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_INT_RX_MASK_1 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_INT_RX_MASK_2 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_INT_RX_MASK_3 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_INT_RX_MASK_4 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_INT_RX_MASK_5 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_INT_RX_MASK_6 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_INT_RX_MASK_7 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_INT_RX_CLR_0 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_INT_RX_CLR_1 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_INT_RX_CLR_2 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_INT_RX_CLR_3 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_INT_RX_CLR_4 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_INT_RX_CLR_5 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_INT_RX_CLR_6 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_INT_RX_CLR_7 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_CA_RSTN_RX = "FALSE"                          ,//TRUE, FALSE; for Rx CLK Aligner Reset                                        
    parameter               PCS_CH0_CA_DYN_DLY_EN_RX = "FALSE"                    ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_CA_DYN_DLY_SEL_RX = "FALSE"                   ,//TRUE, FALSE                                                                  
    parameter    integer    PCS_CH0_CA_RX = 0                                     ,//0 to 255                                                                     
    parameter               PCS_CH0_CA_RSTN_TX = "FALSE"                          ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_CA_DYN_DLY_EN_TX = "FALSE"                    ,//TRUE, FALSE                                                                  
    parameter               PCS_CH0_CA_DYN_DLY_SEL_TX = "FALSE"                   ,//TRUE, FALSE                                                                  
    parameter    integer    PCS_CH0_CA_TX = 0                                     ,//0 to 255                                                                     
    parameter               PCS_CH0_RXPRBS_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH0_WDALIGN_PWR_REDUCTION = "NORMAL"              ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH0_RXDEC_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH0_RXCB_PWR_REDUCTION = "NORMAL"                 ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH0_RXCTC_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH0_RXGEAR_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH0_RXBRG_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH0_RXTEST_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH0_TXBRG_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH0_TXGEAR_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH0_TXENC_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH0_TXBSLP_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH0_TXPRBS_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    //pma_rx                                                                                                                                                 
    parameter               PMA_CH0_REG_RX_PD = "ON"                              ,//ON, OFF;                                                                     
    parameter               PMA_CH0_REG_RX_PD_EN = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PMA_CH0_REG_RX_RESERVED_2 = "FALSE"                   ,//TRUE, FALSE                                                                  
    parameter               PMA_CH0_REG_RX_RESERVED_3 = "FALSE"                   ,//TRUE, FALSE                                                                  
    parameter               PMA_CH0_REG_RX_DATAPATH_PD = "ON"                     ,//ON, OFF;                                                                     
    parameter               PMA_CH0_REG_RX_DATAPATH_PD_EN = "FALSE"               ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_SIGDET_PD = "ON"                       ,//ON, OFF;                                                                     
    parameter               PMA_CH0_REG_RX_SIGDET_PD_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_DCC_RST_N = "TRUE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_DCC_RST_N_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_CDR_RST_N = "TRUE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_CDR_RST_N_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_SIGDET_RST_N = "TRUE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_SIGDET_RST_N_EN = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RXPCLK_SLIP = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RXPCLK_SLIP_OW = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_PCLKSWITCH_RST_N = "TRUE"              ,//TRUE, FALSE; for TX PMA Reset                                                
    parameter               PMA_CH0_REG_RX_PCLKSWITCH_RST_N_EN = "FALSE"          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_PCLKSWITCH = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_PCLKSWITCH_EN = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_HIGHZ = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_HIGHZ_EN = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_SIGDET_CLK_WINDOW = "FALSE"            ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_SIGDET_CLK_WINDOW_OW = "FALSE"         ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_PD_BIAS_RX = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_PD_BIAS_RX_OW = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_RESET_N = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_RESET_N_OW = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_RESERVED_29_28 = 0                     ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_RX_BUSWIDTH = "20BIT"                     ,//"8BIT" "10BIT" "16BIT" "20BIT"                                               
    parameter               PMA_CH0_REG_RX_BUSWIDTH_EN = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_RATE = "DIV1"                          ,//"DIV4" "DIV2" "DIV1" "MUL2"                                                  
    parameter               PMA_CH0_REG_RX_RESERVED_36 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_RATE_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_RES_TRIM = 46                          ,//0 to 63                                                                      
    parameter               PMA_CH0_REG_RX_RESERVED_44 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_RESERVED_45 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_SIGDET_STATUS_EN = "FALSE"             ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_RESERVED_48_47 = 0                     ,//0 to 3                                                                       
    parameter    integer    PMA_CH0_REG_RX_ICTRL_SIGDET = 5                       ,//0 to 15                                                                      
    parameter    integer    PMA_CH0_REG_CDR_READY_THD = 2734                      ,//0 to 4095                                                                    
    parameter               PMA_CH0_REG_RX_RESERVED_65 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_PCLK_EDGE_SEL = "POS_EDGE"             ,//"POS_EDGE" "NEG_EDGE"                                                        
    parameter    integer    PMA_CH0_REG_RX_PIBUF_IC = 1                           ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_RX_RESERVED_69 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_DCC_IC_RX = 1                          ,//0 to 3                                                                       
    parameter    integer    PMA_CH0_REG_CDR_READY_CHECK_CTRL = 0                  ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_RX_ICTRL_TRX = "100PCT"                   ,//"87_5PCT" "100PCT" "112_5PCT" "125PCT"                                       
    parameter    integer    PMA_CH0_REG_RX_RESERVED_77_76 = 0                     ,//0 to 3                                                                       
    parameter    integer    PMA_CH0_REG_RX_RESERVED_79_78 = 1                     ,//0 to 3                                                                       
    parameter    integer    PMA_CH0_REG_RX_RESERVED_81_80 = 1                     ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_RX_ICTRL_PIBUF = "100PCT"                 ,//"87_5PCT" "100PCT" "112_5PCT" "125PCT"                                       
    parameter               PMA_CH0_REG_RX_ICTRL_PI = "100PCT"                    ,//"87_5PCT" "100PCT" "112_5PCT" "125PCT"                                       
    parameter               PMA_CH0_REG_RX_ICTRL_DCC = "100PCT"                   ,//"87_5PCT" "100PCT" "112_5PCT" "125PCT"                                       
    parameter    integer    PMA_CH0_REG_RX_RESERVED_89_88 = 1                     ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_TX_RATE = "DIV1"                          ,//"DIV4" "DIV2" "DIV1" "MUL2"                                                  
    parameter               PMA_CH0_REG_RX_RESERVED_92 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RATE_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_TX2RX_PLPBK_RST_N = "TRUE"             ,//TRUE, FALSE; for tx2rx pma parallel loop back Reset                          
    parameter               PMA_CH0_REG_RX_TX2RX_PLPBK_RST_N_EN = "FALSE"         ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_TX2RX_PLPBK_EN = "FALSE"               ,//TRUE, FALSE; for tx2rx pma parallel loop back enable                         
    parameter               PMA_CH0_REG_TXCLK_SEL = "PLL"                         ,//"PLL" "RXCLK"                                                                
    parameter               PMA_CH0_REG_RX_DATA_POLARITY = "NORMAL"               ,//"NORMAL" "REVERSE"                                                           
    parameter               PMA_CH0_REG_RX_ERR_INSERT = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_UDP_CHK_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_PRBS_SEL = "PRBS7"                        ,//"PRBS7" "PRBS15" "PRBS23" "PRBS31"                                           
    parameter               PMA_CH0_REG_PRBS_CHK_EN = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_PRBS_CHK_WIDTH_SEL = "20BIT"              ,//"8BIT" "10BIT" "16BIT" "20BIT"                                               
    parameter               PMA_CH0_REG_BIST_CHK_PAT_SEL = "PRBS"                 ,//"PRBS" "CONSTANT"                                                            
    parameter               PMA_CH0_REG_LOAD_ERR_CNT = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CHK_COUNTER_EN = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_CDR_PROP_GAIN = 7                         ,//0 to 7                                                                       
    parameter    integer    PMA_CH0_REG_CDR_PROP_TURBO_GAIN = 5                   ,//0 to 7                                                                       
    parameter    integer    PMA_CH0_REG_CDR_INT_GAIN = 4                          ,//0 to 7                                                                       
    parameter    integer    PMA_CH0_REG_CDR_INT_TURBO_GAIN = 5                    ,//0 to 7                                                                       
    parameter    integer    PMA_CH0_REG_CDR_INT_SAT_MAX = 768                     ,//0 to 1023                                                                    
    parameter    integer    PMA_CH0_REG_CDR_INT_SAT_MIN = 255                     ,//0 to 1023                                                                    
    parameter               PMA_CH0_REG_CDR_INT_RST = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_INT_RST_OW = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_PROP_RST = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_PROP_RST_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_LOCK_RST = "FALSE"                    ,//TRUE, FALSE; for CDR LOCK Counter Reset                                      
    parameter               PMA_CH0_REG_CDR_LOCK_RST_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_CDR_RX_PI_FORCE_SEL = 0                   ,//0,1                                                                          
    parameter    integer    PMA_CH0_REG_CDR_RX_PI_FORCE_D = 0                     ,//0 to 255                                                                     
    parameter               PMA_CH0_REG_CDR_LOCK_TIMER = "1_2U"                   ,//"0_8U" "1_2U" "1_6U" "2_4U" 3_2U" "4_8U" "12_8U" "25_6U"                     
    parameter    integer    PMA_CH0_REG_CDR_TURBO_MODE_TIMER = 1                  ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_CDR_LOCK_VAL = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_LOCK_OW = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_INT_SAT_DET_EN = "TRUE"               ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_SAT_AUTO_DIS = "TRUE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_GAIN_AUTO = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_TURBO_GAIN_AUTO = "FALSE"             ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_RESERVED_171_167 = 0                   ,//0 to 31                                                                      
    parameter    integer    PMA_CH0_REG_RX_RESERVED_175_172 = 0                   ,//0 to 31                                                                      
    parameter               PMA_CH0_REG_CDR_SAT_DET_STATUS_EN = "FALSE"           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_SAT_DET_STATUS_RESET_EN = "FALSE"     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_PI_CTRL_RST = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_PI_CTRL_RST_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_SAT_DET_RST = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_SAT_DET_RST_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_SAT_DET_STICKY_RST = "FALSE"          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_SAT_DET_STICKY_RST_OW = "FALSE"       ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_SIGDET_STATUS_DIS = "FALSE"           ,//TRUE, FALSE; for sigdet_status is 0 to reset cdr                             
    parameter    integer    PMA_CH0_REG_CDR_SAT_DET_TIMER = 2                     ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_CDR_SAT_DET_STATUS_VAL = "FALSE"          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_SAT_DET_STATUS_OW = "FALSE"           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_CDR_TURBO_MODE_EN = "TRUE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_RESERVED_190 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_RESERVED_193_191 = 0                   ,//0 to 7                                                                       
    parameter               PMA_CH0_REG_CDR_STATUS_FIFO_EN = "TRUE"               ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_PMA_TEST_SEL = 0                          ,//0,1                                                                          
    parameter    integer    PMA_CH0_REG_OOB_COMWAKE_GAP_MIN = 3                   ,//0 to 63                                                                      
    parameter    integer    PMA_CH0_REG_OOB_COMWAKE_GAP_MAX = 11                  ,//0 to 63                                                                      
    parameter    integer    PMA_CH0_REG_OOB_COMINIT_GAP_MIN = 15                  ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_REG_OOB_COMINIT_GAP_MAX = 35                  ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_REG_RX_RESERVED_227_226 = 1                   ,//0 to 3                                                                       
    parameter    integer    PMA_CH0_REG_COMWAKE_STATUS_CLEAR = 0                  ,//0,1                                                                          
    parameter    integer    PMA_CH0_REG_COMINIT_STATUS_CLEAR = 0                  ,//0,1                                                                          
    parameter               PMA_CH0_REG_RX_SYNC_RST_N_EN = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_SYNC_RST_N = "TRUE"                    ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_RESERVED_233_232 = 0                   ,//0 to 3                                                                       
    parameter    integer    PMA_CH0_REG_RX_RESERVED_235_234 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_RX_SATA_COMINIT_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_SATA_COMINIT = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_SATA_COMWAKE_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_SATA_COMWAKE = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_RESERVED_241_240 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_RX_DCC_DISABLE = "FALSE"                  ,//TRUE, FALSE; for rx dcc disable control                                      
    parameter               PMA_CH0_REG_RX_RESERVED_243 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_SLIP_SEL_EN = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_SLIP_SEL = 0                           ,//0 to 15                                                                      
    parameter               PMA_CH0_REG_RX_SLIP_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_SIGDET_STATUS_SEL = 5                  ,//0 to 7                                                                       
    parameter               PMA_CH0_REG_RX_SIGDET_FSM_RST_N = "TRUE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_RESERVED_254 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_SIGDET_STATUS = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_SIGDET_VTH = "72MV"                    ,//"45MV" "54MV" "63MV" "72MV"                       
    parameter    integer    PMA_CH0_REG_RX_SIGDET_GRM = 0                         ,//0,1,2,3                                                                      
    parameter               PMA_CH0_REG_RX_SIGDET_PULSE_EXT = "FALSE"             ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_SIGDET_CH2_SEL = 0                     ,//0,1                                                                          
    parameter    integer    PMA_CH0_REG_RX_SIGDET_CH2_CHK_WINDOW = 3              ,//0 to 31                                                                      
    parameter               PMA_CH0_REG_RX_SIGDET_CHK_WINDOW_EN = "TRUE"          ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_SIGDET_NOSIG_COUNT_SETTING = 4         ,//0 to 7                                                                       
    parameter               PMA_CH0_REG_SLIP_FIFO_INV_EN = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_SLIP_FIFO_INV = "POS_EDGE"                ,//"POS_EDGE" "NEG_EDGE"                                                        
    parameter    integer    PMA_CH0_REG_RX_SIGDET_OOB_DET_COUNT_VAL = 0           ,//0 to 31                                                                      
    parameter    integer    PMA_CH0_REG_RX_SIGDET_4OOB_DET_SEL = 7                ,//0 to 7                                                                       
    parameter    integer    PMA_CH0_REG_RX_RESERVED_285_283 = 0                   ,//0 to 7                                                                       
    parameter               PMA_CH0_REG_RX_RESERVED_286 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_SIGDET_IC_I = 10                       ,//0 to 15                                                                      
    parameter               PMA_CH0_REG_RX_OOB_DETECTOR_RESET_N_OW = "FALSE"      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_OOB_DETECTOR_RESET_N = "FALSE"         ,//TRUE, FALSE;for rx oob detector Reset                                        
    parameter               PMA_CH0_REG_RX_OOB_DETECTOR_PD_OW = "FALSE"           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_OOB_DETECTOR_PD = "ON"                 ,//TRUE, FALSE;for rx oob detector powerdown                                    
    parameter               PMA_CH0_REG_RX_LS_MODE_EN = "FALSE"                   ,//TRUE, FALSE;for Enable Low-speed mode                                        
    parameter               PMA_CH0_REG_ANA_RX_EQ1_R_SET_FB_O_SEL = "TRUE"        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_ANA_RX_EQ2_R_SET_FB_O_SEL = "TRUE"        ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_EQ1_R_SET_TOP = 0                      ,//0 to 3                                                                       
    parameter    integer    PMA_CH0_REG_RX_EQ1_R_SET_FB = 15                      ,//0 to 15                                                                      
    parameter    integer    PMA_CH0_REG_RX_EQ1_C_SET_FB = 0                       ,//0 to 15                                                                      
    parameter               PMA_CH0_REG_RX_EQ1_OFF = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_EQ2_R_SET_TOP = 0                      ,//0 to 3                                                                       
    parameter    integer    PMA_CH0_REG_RX_EQ2_R_SET_FB = 0                       ,//0 to 15                                                                      
    parameter    integer    PMA_CH0_REG_RX_EQ2_C_SET_FB = 0                       ,//0 to 15                                                                      
    parameter               PMA_CH0_REG_RX_EQ2_OFF = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_EQ_DAC = 0                                ,//0 to 63                                                                      
    parameter    integer    PMA_CH0_REG_RX_ICTRL_EQ = 2                           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_EQ_DC_CALIB_EN = "TRUE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_EQ_DC_CALIB_SEL = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_RESERVED_337_330 = 0                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_REG_RX_RESERVED_345_338 = 0                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_REG_RX_RESERVED_353_346 = 0                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_REG_RX_RESERVED_361_354 = 0                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_CTLE_CTRL_REG_I = 0                           ,//0 to 15                                                                      
    parameter               PMA_CH0_CTLE_REG_FORCE_SEL_I = "FALSE"                ,//TRUE, FALSE;for ctrl self-adaption adjust                                    
    parameter               PMA_CH0_CTLE_REG_HOLD_I = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_CTLE_REG_INIT_DAC_I = 0                       ,//0 to 15                                                                      
    parameter               PMA_CH0_CTLE_REG_POLARITY_I = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_CTLE_REG_SHIFTER_GAIN_I = 1                   ,//0 to 7                                                                       
    parameter    integer    PMA_CH0_CTLE_REG_THRESHOLD_I = 3072                   ,//0 to 4095                                                                    
    parameter               PMA_CH0_REG_RX_RES_TRIM_EN = "TRUE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_RESERVED_393_389 = 0                   ,//0 to 31                                                                      
    parameter               PMA_CH0_CFG_RX_LANE_POWERUP = "ON"                    ,//ON, OFF;for RX_LANE Power-up                                                 
    parameter               PMA_CH0_CFG_RX_PMA_RSTN = "TRUE"                      ,//TRUE, FALSE;for RX_PMA Reset                                                 
    parameter               PMA_CH0_INT_PMA_RX_MASK_0 = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_INT_PMA_RX_CLR_0 = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_CFG_CTLE_ADP_RSTN = "TRUE"                    ,//TRUE, FALSE;for ctrl Reset                                                   
    //pma_tx                                                                                                                                                 
    parameter               PMA_CH0_REG_TX_PD = "ON"                              ,//ON, OFF;for transmitter power down                                           
    parameter               PMA_CH0_REG_TX_PD_OW = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_MAIN_PRE_Z = "FALSE"                   ,//TRUE, FALSE;Enable EI for PCIE mode                                          
    parameter               PMA_CH0_REG_TX_MAIN_PRE_Z_OW = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_TX_BEACON_TIMER_SEL = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_TX_RXDET_REQ_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RXDET_REQ = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_BEACON_EN_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_BEACON_EN = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_EI_EN_OW = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_EI_EN = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_BIT_CONV = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_TX_RES_CAL = 48                           ,//0 to 63                                                                      
    parameter               PMA_CH0_REG_TX_RESERVED_19 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_TX_RESERVED_25_20 = 32                    ,//0 to 63                                                                      
    parameter    integer    PMA_CH0_REG_TX_RESERVED_33_26 = 0                     ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_REG_TX_RESERVED_41_34 = 0                     ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_REG_TX_RESERVED_49_42 = 0                     ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_REG_TX_RESERVED_57_50 = 0                     ,//0 to 255                                                                     
    parameter               PMA_CH0_REG_TX_SYNC_OW = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_SYNC = "FALSE"                         ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_PD_POST = "OFF"                        ,//ON, OFF;                                                                     
    parameter               PMA_CH0_REG_TX_PD_POST_OW = "TRUE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RESET_N_OW = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RESET_N = "TRUE"                       ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RESERVED_64 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RESERVED_65 = "TRUE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_BUSWIDTH_OW = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_BUSWIDTH = "20BIT"                     ,//"8BIT" "10BIT" "16BIT" "20BIT"                                               
    parameter               PMA_CH0_REG_PLL_READY_OW = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_PLL_READY = "TRUE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RESERVED_72 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RESERVED_73 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RESERVED_74 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_EI_PCLK_DELAY_SEL = 0                     ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_TX_RESERVED_77 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_TX_RESERVED_83_78 = 0                     ,//0 to 63                                                                      
    parameter    integer    PMA_CH0_REG_TX_RESERVED_89_84 = 0                     ,//0 to 63                                                                      
    parameter    integer    PMA_CH0_REG_TX_RESERVED_95_90 = 0                     ,//0 to 63                                                                      
    parameter    integer    PMA_CH0_REG_TX_RESERVED_101_96 = 0                    ,//0 to 63                                                                      
    parameter    integer    PMA_CH0_REG_TX_RESERVED_107_102 = 0                   ,//0 to 63                                                                      
    parameter    integer    PMA_CH0_REG_TX_RESERVED_113_108 = 0                   ,//0 to 63                                                                      
    parameter    integer    PMA_CH0_REG_TX_AMP_DAC0 = 25                          ,//0 to 63                                                                      
    parameter    integer    PMA_CH0_REG_TX_AMP_DAC1 = 19                          ,//0 to 63                                                                      
    parameter    integer    PMA_CH0_REG_TX_AMP_DAC2 = 14                          ,//0 to 63                                                                      
    parameter    integer    PMA_CH0_REG_TX_AMP_DAC3 = 9                           ,//0 to 63                                                                      
    parameter    integer    PMA_CH0_REG_TX_RESERVED_143_138 = 5                   ,//0 to 63                                                                      
    parameter    integer    PMA_CH0_REG_TX_MARGIN = 0                             ,//0 to 7                                                                       
    parameter               PMA_CH0_REG_TX_MARGIN_OW = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_TX_RESERVED_149_148 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_TX_RESERVED_150 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_SWING = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_SWING_OW = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RESERVED_153 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RXDET_THRESHOLD = "84MV"               ,//"28MV" "56MV" "84MV" "112MV"                                                 
    parameter    integer    PMA_CH0_REG_TX_RESERVED_157_156 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_TX_BEACON_OSC_CTRL = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_TX_RESERVED_160_159 = 0                   ,//0 to 3                                                                       
    parameter    integer    PMA_CH0_REG_TX_RESERVED_162_161 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_TX_TX2RX_SLPBACK_EN = "FALSE"             ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_PCLK_EDGE_SEL = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RXDET_STATUS_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RXDET_STATUS = "TRUE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_PRBS_GEN_EN = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_PRBS_GEN_WIDTH_SEL = "20BIT"           ,//"8BIT" "10BIT" "16BIT" "20BIT"                                               
    parameter               PMA_CH0_REG_TX_PRBS_SEL = "PRBS7"                     ,//"PRBS7" "PRBS15" "PRBS23" "PRBS31"                                           
    parameter    integer    PMA_CH0_REG_TX_UDP_DATA_7_TO_0 = 5                    ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_REG_TX_UDP_DATA_15_TO_8 = 235                 ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_REG_TX_UDP_DATA_19_TO_16 = 3                  ,//0 to 15                                                                      
    parameter               PMA_CH0_REG_TX_RESERVED_192 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_TX_FIFO_WP_CTRL = 4                       ,//0 to 7                                                                       
    parameter               PMA_CH0_REG_TX_FIFO_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_TX_DATA_MUX_SEL = 0                       ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_TX_ERR_INSERT = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_TX_RESERVED_203_200 = 0                   ,//0 to15                                                                       
    parameter               PMA_CH0_REG_TX_RESERVED_204 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_SATA_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_TX_RESERVED_207_206 = 0                   ,//0 to3                                                                        
    parameter               PMA_CH0_REG_RATE_CHANGE_TXPCLK_ON_OW = "FALSE"        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RATE_CHANGE_TXPCLK_ON = "TRUE"            ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_TX_CFG_POST1 = 0                          ,//0 to 31                                                                      
    parameter    integer    PMA_CH0_REG_TX_CFG_POST2 = 0                          ,//0 to 31                                                                      
    parameter    integer    PMA_CH0_REG_TX_DEEMP = 0                              ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_TX_DEEMP_OW = "FALSE"                     ,//TRUE, FALSE;for TX DEEMP Control                                             
    parameter    integer    PMA_CH0_REG_TX_RESERVED_224_223 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_TX_RESERVED_225 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_TX_RESERVED_229_226 = 0                   ,//0 to 15                                                                      
    parameter    integer    PMA_CH0_REG_TX_OOB_DELAY_SEL = 0                      ,//0 to 15                                                                      
    parameter               PMA_CH0_REG_TX_POLARITY = "NORMAL"                    ,//"NORMAL" "REVERSE"                                                           
    parameter               PMA_CH0_REG_ANA_TX_JTAG_DATA_O_SEL = "FALSE"          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RESERVED_236 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_LS_MODE_EN = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_JTAG_MODE_EN_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_JTAG_MODE_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_JTAG_MODE_EN_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_JTAG_MODE_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_RX_JTAG_OE = "TRUE"                       ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_ACJTAG_VHYSTSEL = 0                    ,//0 to 7                                                                       
    parameter               PMA_CH0_REG_TX_RES_CAL_EN = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_RX_TERM_MODE_CTRL = 5                     ,//0 to 7; for rx terminatin Control                                            
    parameter    integer    PMA_CH0_REG_TX_RESERVED_251_250 = 0                   ,//0 to 7                                                                       
    parameter               PMA_CH0_REG_PLPBK_TXPCLK_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RESERVED_253 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RESERVED_254 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RESERVED_255 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RESERVED_256 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_RESERVED_257 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_TX_PH_SEL = 1                             ,//0 to 63                                                                      
    parameter    integer    PMA_CH0_REG_TX_CFG_PRE = 0                            ,//0 to 31                                                                      
    parameter    integer    PMA_CH0_REG_TX_CFG_MAIN = 0                           ,//0 to 63                                                                      
    parameter    integer    PMA_CH0_REG_CFG_POST = 0                              ,//0 to 31                                                                      
    parameter               PMA_CH0_REG_PD_MAIN = "TRUE"                          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_PD_PRE = "TRUE"                           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_LS_DATA = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_TX_DCC_BUF_SZ_SEL = 0                     ,//0 to 3                                                                       
    parameter    integer    PMA_CH0_REG_TX_DCC_CAL_CUR_TUNE = 0                   ,//0 to 63                                                                      
    parameter               PMA_CH0_REG_TX_DCC_CAL_EN = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_TX_DCC_CUR_SS = 0                         ,//0 to 3                                                                       
    parameter               PMA_CH0_REG_TX_DCC_FA_CTRL = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_DCC_RI_CTRL = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_ATB_SEL_2_TO_0 = 0                        ,//0 to 7                                                                       
    parameter    integer    PMA_CH0_REG_ATB_SEL_9_TO_3 = 0                        ,//0 to 127                                                                     
    parameter    integer    PMA_CH0_REG_TX_CFG_7_TO_0 = 0                         ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_REG_TX_CFG_15_TO_8 = 0                        ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_REG_TX_CFG_23_TO_16 = 0                       ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_REG_TX_CFG_31_TO_24 = 128                     ,//0 to 255                                                                     
    parameter               PMA_CH0_REG_TX_OOB_EI_EN = "FALSE"                    ,//TRUE, FALSE; Enable OOB EI for SATA mode                                     
    parameter               PMA_CH0_REG_TX_OOB_EI_EN_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_BEACON_EN_DELAYED = "FALSE"            ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_BEACON_EN_DELAYED_OW = "FALSE"         ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH0_REG_TX_JTAG_DATA = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH0_REG_TX_RXDET_TIMER_SEL = 87                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_REG_TX_CFG1_7_0 = 0                           ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_REG_TX_CFG1_15_8 = 0                          ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_REG_TX_CFG1_23_16 = 0                         ,//0 to 255                                                                     
    parameter    integer    PMA_CH0_REG_TX_CFG1_31_24 = 0                         ,//0 to 255                                                                     
    parameter               PMA_CH0_REG_CFG_LANE_POWERUP = "ON"                   ,//ON, OFF; for PMA_LANE powerup                                                
    parameter               PMA_CH0_REG_CFG_TX_LANE_POWERUP_CLKPATH = "TRUE"      ,//TRUE, FALSE; for Pma tx lane clkpath powerup                                 
    parameter               PMA_CH0_REG_CFG_TX_LANE_POWERUP_PISO = "TRUE"         ,//TRUE, FALSE; for Pma tx lane piso powerup                                    
    parameter               PMA_CH0_REG_CFG_TX_LANE_POWERUP_DRIVER = "TRUE"       ,//TRUE, FALSE; for Pma tx lane driver powerup                                  
    //--------CHANNEL1 parameter--------//
    parameter    integer    CH1_MUX_BIAS = 2                                      ,//0 to 7; don't support simulation                                             
    parameter    integer    CH1_PD_CLK = 0                                        ,//0 to 1                                                                       
    parameter    integer    CH1_REG_SYNC = 0                                      ,//0 to 1                                                                       
    parameter    integer    CH1_REG_SYNC_OW = 0                                   ,//0 to 1                                                                       
    parameter    integer    CH1_PLL_LOCK_OW = 0                                   ,//0 to 1                                                                       
    parameter    integer    CH1_PLL_LOCK_OW_EN = 0                                ,//0 to 1                                                                       
    //pcs
    parameter    integer    PCS_CH1_SLAVE = 0                                     ,//Altered in 2019.12.05, should be configured by user, software only checks corresponding connection of clock
    parameter               PCS_CH1_BYPASS_WORD_ALIGN = "FALSE"                   ,//TRUE, FALSE; for bypass word alignment                                       
    parameter               PCS_CH1_BYPASS_DENC = "FALSE"                         ,//TRUE, FALSE; for bypass 8b/10b decoder                                       
    parameter               PCS_CH1_BYPASS_BONDING = "FALSE"                      ,//TRUE, FALSE; for bypass channel bonding                                      
    parameter               PCS_CH1_BYPASS_CTC = "FALSE"                          ,//TRUE, FALSE; for bypass ctc                                                  
    parameter               PCS_CH1_BYPASS_GEAR = "FALSE"                         ,//TRUE, FALSE; for bypass Rx Gear                                              
    parameter               PCS_CH1_BYPASS_BRIDGE = "FALSE"                       ,//TRUE, FALSE; for bypass Rx Bridge unit                                       
    parameter               PCS_CH1_BYPASS_BRIDGE_FIFO = "FALSE"                  ,//TRUE, FALSE; for bypass Rx Bridge FIFO                                       
    parameter               PCS_CH1_DATA_MODE = "X8"                              ,//"X8","X10","X16","X20"                                                       
    parameter               PCS_CH1_RX_POLARITY_INV = "DELAY"                     ,//"DELAY","BIT_POLARITY_INVERION","BIT_REVERSAL","BOTH"                        
    parameter               PCS_CH1_ALIGN_MODE = "1GB"                            ,//1GB, 10GB, RAPIDIO, OUTSIDE                                                  
    parameter               PCS_CH1_SAMP_16B = "X20"                              ,//"X20",X16                                                                    
    parameter               PCS_CH1_FARLP_PWR_REDUCTION = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PCS_CH1_COMMA_REG0 = 0                                ,//0 to 1023                                                                    
    parameter    integer    PCS_CH1_COMMA_MASK = 0                                ,//0 to 1023                                                                    
    parameter               PCS_CH1_CEB_MODE = "10GB"                             ,//"10GB" "RAPIDIO" "OUTSIDE"                                                   
    parameter               PCS_CH1_CTC_MODE = "1SKIP"                            ,//1SKIP, 2SKIP, PCIE_2BYTE, 4SKIP                                              
    parameter    integer    PCS_CH1_A_REG = 0                                     ,//0 to 255                                                                     
    parameter               PCS_CH1_GE_AUTO_EN = "FALSE"                          ,//TRUE, FALSE;                                                                 
    parameter    integer    PCS_CH1_SKIP_REG0 = 0                                 ,//0 to 1023                                                                    
    parameter    integer    PCS_CH1_SKIP_REG1 = 0                                 ,//0 to 1023                                                                    
    parameter    integer    PCS_CH1_SKIP_REG2 = 0                                 ,//0 to 1023                                                                    
    parameter    integer    PCS_CH1_SKIP_REG3 = 0                                 ,//0 to 1023                                                                    
    parameter               PCS_CH1_DEC_DUAL = "FALSE"                            ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_SPLIT = "FALSE"                               ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_FIFOFLAG_CTC = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_COMMA_DET_MODE = "COMMA_PATTERN"              ,//"RX_CLK_SLIP" "COMMA_PATTERN"                                                
    parameter               PCS_CH1_ERRDETECT_SILENCE = "TRUE"                    ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_PMA_RCLK_POLINV = "PMA_RCLK"                  ,//"PMA_RCLK" "REVERSE_OF_PMA_RCLK"                                             
    parameter               PCS_CH1_PCS_RCLK_SEL = "PMA_RCLK"                     ,//"PMA_RCLK" "PMA_TCLK" "RCLK"                                                 
    parameter               PCS_CH1_CB_RCLK_SEL = "PMA_RCLK"                      ,//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK"                                             
    parameter               PCS_CH1_AFTER_CTC_RCLK_SEL = "PMA_RCLK"               ,//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK" "RCLK2"                                     
    parameter               PCS_CH1_RCLK_POLINV = "RCLK"                          ,//"RCLK" "REVERSE_OF_RCLK"                                                     
    parameter               PCS_CH1_BRIDGE_RCLK_SEL = "PMA_RCLK"                  ,//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK" "RCLK"                                      
    parameter               PCS_CH1_PCS_RCLK_EN = "FALSE"                         ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_CB_RCLK_EN = "FALSE"                          ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_AFTER_CTC_RCLK_EN = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_AFTER_CTC_RCLK_EN_GB = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_PCS_RX_RSTN = "TRUE"                          ,//TRUE, FALSE; for PCS Receiver Reset                                          
    parameter               PCS_CH1_PCIE_SLAVE = "MASTER"                         ,//"MASTER","SLAVE"                                                             
    parameter               PCS_CH1_RX_64B66B_67B = "NORMAL"                      ,//"NORMAL" "64B_66B" "64B_67B"                                                 
    parameter               PCS_CH1_RX_BRIDGE_CLK_POLINV = "RX_BRIDGE_CLK"        ,//"RX_BRIDGE_CLK" "REVERSE_OF_RX_BRIDGE_CLK"                                   
    parameter               PCS_CH1_PCS_CB_RSTN = "TRUE"                         ,//TRUE, FALSE; for PCS CB Reset                                                
    parameter               PCS_CH1_TX_BRIDGE_GEAR_SEL = "FALSE"                  ,//TRUE: tx gear priority, FALSE:tx bridge unit priority                        
    parameter               PCS_CH1_TX_BYPASS_BRIDGE_UINT = "FALSE"               ,//TRUE, FALSE; for bypass                                                      
    parameter               PCS_CH1_TX_BYPASS_BRIDGE_FIFO = "FALSE"               ,//TRUE, FALSE; for bypass Tx Bridge FIFO                                       
    parameter               PCS_CH1_TX_BYPASS_GEAR = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_TX_BYPASS_ENC = "FALSE"                       ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_TX_BYPASS_BIT_SLIP = "TRUE"                   ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_TX_GEAR_SPLIT = "TRUE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_TX_DRIVE_REG_MODE = "NO_CHANGE"               ,//"NO_CHANGE" "EN_POLARIY_REV" "EN_BIT_REV" "EN_BOTH"                          
    parameter    integer    PCS_CH1_TX_BIT_SLIP_CYCLES = 0                        ,//o to 31                                                                      
    parameter               PCS_CH1_INT_TX_MASK_0 = "FALSE"                       ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_INT_TX_MASK_1 = "FALSE"                       ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_INT_TX_MASK_2 = "FALSE"                       ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_INT_TX_CLR_0 = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_INT_TX_CLR_1 = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_INT_TX_CLR_2 = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_TX_PMA_TCLK_POLINV = "PMA_TCLK"               ,//"PMA_TCLK" "REVERSE_OF_PMA_TCLK"                                             
    parameter               PCS_CH1_TX_PCS_CLK_EN_SEL = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_TX_BRIDGE_TCLK_SEL = "TCLK"                   ,//"PCS_TCLK" "TCLK"                                                            
    parameter               PCS_CH1_TX_TCLK_POLINV = "TCLK"                       ,//"TCLK" "REVERSE_OF_TCLK"                                                     
    parameter               PCS_CH1_PCS_TCLK_SEL= "PMA_TCLK"                      ,//"PMA_TCLK" "TCLK"                                                            
    parameter               PCS_CH1_TX_PCS_TX_RSTN = "TRUE"                       ,//TRUE, FALSE; for PCS Transmitter Reset                                       
    parameter               PCS_CH1_TX_SLAVE = "MASTER"                           ,//"MASTER" "SLAVE"                                                             
    parameter               PCS_CH1_TX_GEAR_CLK_EN_SEL = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH1_DATA_WIDTH_MODE = "X20"                       ,//"X8" "X10" "X16" "X20"                                                       
    parameter               PCS_CH1_TX_64B66B_67B = "NORMAL"                      ,//"NORMAL" "64B_66B" "64B_67B"                                                 
    parameter               PCS_CH1_GEAR_TCLK_SEL = "PMA_TCLK"                    ,//"PMA_TCLK" "TCLK2"                                                           
    parameter               PCS_CH1_TX_TCLK2FABRIC_SEL = "TRUE"                   ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_TX_OUTZZ = "FALSE"                            ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_ENC_DUAL = "FALSE"                            ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_TX_BITSLIP_DATA_MODE = "X10"                  ,//"X10" "X20"                                                                  
    parameter               PCS_CH1_TX_BRIDGE_CLK_POLINV = "TX_BRIDGE_CLK"        ,//"TX_BRIDGE_CLK" "REVERSE_OF_TX_BRIDGE_CLK"                                   
    parameter    integer    PCS_CH1_COMMA_REG1 = 0                                ,//0 to 1023                                                                    
    parameter    integer    PCS_CH1_RAPID_IMAX = 0                                ,//0 to 7                                                                       
    parameter    integer    PCS_CH1_RAPID_VMIN_1 = 0                              ,//0 to 255                                                                     
    parameter    integer    PCS_CH1_RAPID_VMIN_2 = 0                              ,//0 to 255                                                                     
    parameter               PCS_CH1_RX_PRBS_MODE = "DISABLE"                      ,//DISABLE PRBS_7 PRBS_15 PRBS_23 PRBS_31                                       
    parameter               PCS_CH1_RX_ERRCNT_CLR = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_PRBS_ERR_LPBK = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_TX_PRBS_MODE = "DISABLE"                      ,//DISABLE PRBS_7 PRBS_15 PRBS_23 PRBS_31 LONG_1 LONG_0 20UI D10_2 PCIE         
    parameter               PCS_CH1_TX_INSERT_ER = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_ENABLE_PRBS_GEN = "FALSE"                     ,//TRUE, FALSE                                                                  
    parameter    integer    PCS_CH1_DEFAULT_RADDR = 6                             ,//0 to 15                                                                      
    parameter    integer    PCS_CH1_MASTER_CHECK_OFFSET = 0                       ,//0 to 15                                                                      
    parameter    integer    PCS_CH1_DELAY_SET = 0                                 ,//0 to 15                                                                      
    parameter               PCS_CH1_SEACH_OFFSET = "20BIT"                        ,//"20BIT" 30BIT" "40BIT" "50BIT" "60BIT" "70BIT" "80BIT"                       
    parameter    integer    PCS_CH1_CEB_RAPIDLS_MMAX = 0                          ,//0 to 7                                                                       
    parameter    integer    PCS_CH1_CTC_AFULL = 20                                ,//0 to 31                                                                      
    parameter    integer    PCS_CH1_CTC_AEMPTY = 12                               ,//0 to 31                                                                      
    parameter    integer    PCS_CH1_CTC_CONTI_SKP_SET = 0                         ,//0 to 1                                                                       
    parameter               PCS_CH1_FAR_LOOP = "FALSE"                            ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_NEAR_LOOP = "FALSE"                           ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_PMA_TX2RX_PLOOP_EN = "FALSE"                  ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_PMA_TX2RX_SLOOP_EN = "FALSE"                  ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_PMA_RX2TX_PLOOP_EN = "FALSE"                  ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_INT_RX_MASK_0 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_INT_RX_MASK_1 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_INT_RX_MASK_2 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_INT_RX_MASK_3 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_INT_RX_MASK_4 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_INT_RX_MASK_5 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_INT_RX_MASK_6 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_INT_RX_MASK_7 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_INT_RX_CLR_0 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_INT_RX_CLR_1 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_INT_RX_CLR_2 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_INT_RX_CLR_3 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_INT_RX_CLR_4 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_INT_RX_CLR_5 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_INT_RX_CLR_6 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_INT_RX_CLR_7 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_CA_RSTN_RX = "FALSE"                          ,//TRUE, FALSE; for Rx CLK Aligner Reset                                        
    parameter               PCS_CH1_CA_DYN_DLY_EN_RX = "FALSE"                    ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_CA_DYN_DLY_SEL_RX = "FALSE"                   ,//TRUE, FALSE                                                                  
    parameter    integer    PCS_CH1_CA_RX = 0                                     ,//0 to 255                                                                     
    parameter               PCS_CH1_CA_RSTN_TX = "FALSE"                          ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_CA_DYN_DLY_EN_TX = "FALSE"                    ,//TRUE, FALSE                                                                  
    parameter               PCS_CH1_CA_DYN_DLY_SEL_TX = "FALSE"                   ,//TRUE, FALSE                                                                  
    parameter    integer    PCS_CH1_CA_TX = 0                                     ,//0 to 255                                                                     
    parameter               PCS_CH1_RXPRBS_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH1_WDALIGN_PWR_REDUCTION = "NORMAL"              ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH1_RXDEC_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH1_RXCB_PWR_REDUCTION = "NORMAL"                 ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH1_RXCTC_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH1_RXGEAR_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH1_RXBRG_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH1_RXTEST_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH1_TXBRG_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH1_TXGEAR_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH1_TXENC_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH1_TXBSLP_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH1_TXPRBS_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    //pma_rx                                                                                                                                                 
    parameter               PMA_CH1_REG_RX_PD = "ON"                              ,//ON, OFF;                                                                     
    parameter               PMA_CH1_REG_RX_PD_EN = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PMA_CH1_REG_RX_RESERVED_2 = "FALSE"                   ,//TRUE, FALSE                                                                  
    parameter               PMA_CH1_REG_RX_RESERVED_3 = "FALSE"                   ,//TRUE, FALSE                                                                  
    parameter               PMA_CH1_REG_RX_DATAPATH_PD = "ON"                     ,//ON, OFF;                                                                     
    parameter               PMA_CH1_REG_RX_DATAPATH_PD_EN = "FALSE"               ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_SIGDET_PD = "ON"                       ,//ON, OFF;                                                                     
    parameter               PMA_CH1_REG_RX_SIGDET_PD_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_DCC_RST_N = "TRUE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_DCC_RST_N_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_CDR_RST_N = "TRUE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_CDR_RST_N_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_SIGDET_RST_N = "TRUE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_SIGDET_RST_N_EN = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RXPCLK_SLIP = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RXPCLK_SLIP_OW = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_PCLKSWITCH_RST_N = "TRUE"              ,//TRUE, FALSE; for TX PMA Reset                                                
    parameter               PMA_CH1_REG_RX_PCLKSWITCH_RST_N_EN = "FALSE"          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_PCLKSWITCH = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_PCLKSWITCH_EN = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_HIGHZ = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_HIGHZ_EN = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_SIGDET_CLK_WINDOW = "FALSE"            ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_SIGDET_CLK_WINDOW_OW = "FALSE"         ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_PD_BIAS_RX = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_PD_BIAS_RX_OW = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_RESET_N = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_RESET_N_OW = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_RESERVED_29_28 = 0                     ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_RX_BUSWIDTH = "20BIT"                     ,//"8BIT" "10BIT" "16BIT" "20BIT"                                               
    parameter               PMA_CH1_REG_RX_BUSWIDTH_EN = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_RATE = "DIV1"                          ,//"DIV4" "DIV2" "DIV1" "MUL2"                                                  
    parameter               PMA_CH1_REG_RX_RESERVED_36 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_RATE_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_RES_TRIM = 46                          ,//0 to 63                                                                      
    parameter               PMA_CH1_REG_RX_RESERVED_44 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_RESERVED_45 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_SIGDET_STATUS_EN = "FALSE"             ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_RESERVED_48_47 = 0                     ,//0 to 3                                                                       
    parameter    integer    PMA_CH1_REG_RX_ICTRL_SIGDET = 5                       ,//0 to 15                                                                      
    parameter    integer    PMA_CH1_REG_CDR_READY_THD = 2734                      ,//0 to 4095                                                                    
    parameter               PMA_CH1_REG_RX_RESERVED_65 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_PCLK_EDGE_SEL = "POS_EDGE"             ,//"POS_EDGE" "NEG_EDGE"                                                        
    parameter    integer    PMA_CH1_REG_RX_PIBUF_IC = 1                           ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_RX_RESERVED_69 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_DCC_IC_RX = 1                          ,//0 to 3                                                                       
    parameter    integer    PMA_CH1_REG_CDR_READY_CHECK_CTRL = 0                  ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_RX_ICTRL_TRX = "100PCT"                   ,//"87_5PCT" "100PCT" "112_5PCT" "125PCT"                                       
    parameter    integer    PMA_CH1_REG_RX_RESERVED_77_76 = 0                     ,//0 to 3                                                                       
    parameter    integer    PMA_CH1_REG_RX_RESERVED_79_78 = 1                     ,//0 to 3                                                                       
    parameter    integer    PMA_CH1_REG_RX_RESERVED_81_80 = 1                     ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_RX_ICTRL_PIBUF = "100PCT"                 ,//"87_5PCT" "100PCT" "112_5PCT" "125PCT"                                       
    parameter               PMA_CH1_REG_RX_ICTRL_PI = "100PCT"                    ,//"87_5PCT" "100PCT" "112_5PCT" "125PCT"                                       
    parameter               PMA_CH1_REG_RX_ICTRL_DCC = "100PCT"                   ,//"87_5PCT" "100PCT" "112_5PCT" "125PCT"                                       
    parameter    integer    PMA_CH1_REG_RX_RESERVED_89_88 = 1                     ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_TX_RATE = "DIV1"                          ,//"DIV4" "DIV2" "DIV1" "MUL2"                                                  
    parameter               PMA_CH1_REG_RX_RESERVED_92 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RATE_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_TX2RX_PLPBK_RST_N = "TRUE"             ,//TRUE, FALSE; for tx2rx pma parallel loop back Reset                          
    parameter               PMA_CH1_REG_RX_TX2RX_PLPBK_RST_N_EN = "FALSE"         ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_TX2RX_PLPBK_EN = "FALSE"               ,//TRUE, FALSE; for tx2rx pma parallel loop back enable                         
    parameter               PMA_CH1_REG_TXCLK_SEL = "PLL"                         ,//"PLL" "RXCLK"                                                                
    parameter               PMA_CH1_REG_RX_DATA_POLARITY = "NORMAL"               ,//"NORMAL" "REVERSE"                                                           
    parameter               PMA_CH1_REG_RX_ERR_INSERT = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_UDP_CHK_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_PRBS_SEL = "PRBS7"                        ,//"PRBS7" "PRBS15" "PRBS23" "PRBS31"                                           
    parameter               PMA_CH1_REG_PRBS_CHK_EN = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_PRBS_CHK_WIDTH_SEL = "20BIT"              ,//"8BIT" "10BIT" "16BIT" "20BIT"                                               
    parameter               PMA_CH1_REG_BIST_CHK_PAT_SEL = "PRBS"                 ,//"PRBS" "CONSTANT"                                                            
    parameter               PMA_CH1_REG_LOAD_ERR_CNT = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CHK_COUNTER_EN = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_CDR_PROP_GAIN = 7                         ,//0 to 7                                                                       
    parameter    integer    PMA_CH1_REG_CDR_PROP_TURBO_GAIN = 5                   ,//0 to 7                                                                       
    parameter    integer    PMA_CH1_REG_CDR_INT_GAIN = 4                          ,//0 to 7                                                                       
    parameter    integer    PMA_CH1_REG_CDR_INT_TURBO_GAIN = 5                    ,//0 to 7                                                                       
    parameter    integer    PMA_CH1_REG_CDR_INT_SAT_MAX = 768                     ,//0 to 1023                                                                    
    parameter    integer    PMA_CH1_REG_CDR_INT_SAT_MIN = 255                     ,//0 to 1023                                                                    
    parameter               PMA_CH1_REG_CDR_INT_RST = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_INT_RST_OW = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_PROP_RST = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_PROP_RST_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_LOCK_RST = "FALSE"                    ,//TRUE, FALSE; for CDR LOCK Counter Reset                                      
    parameter               PMA_CH1_REG_CDR_LOCK_RST_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_CDR_RX_PI_FORCE_SEL = 0                   ,//0,1                                                                          
    parameter    integer    PMA_CH1_REG_CDR_RX_PI_FORCE_D = 0                     ,//0 to 255                                                                     
    parameter               PMA_CH1_REG_CDR_LOCK_TIMER = "1_2U"                   ,//"0_8U" "1_2U" "1_6U" "2_4U" 3_2U" "4_8U" "12_8U" "25_6U"                     
    parameter    integer    PMA_CH1_REG_CDR_TURBO_MODE_TIMER = 1                  ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_CDR_LOCK_VAL = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_LOCK_OW = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_INT_SAT_DET_EN = "TRUE"               ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_SAT_AUTO_DIS = "TRUE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_GAIN_AUTO = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_TURBO_GAIN_AUTO = "FALSE"             ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_RESERVED_171_167 = 0                   ,//0 to 31                                                                      
    parameter    integer    PMA_CH1_REG_RX_RESERVED_175_172 = 0                   ,//0 to 31                                                                      
    parameter               PMA_CH1_REG_CDR_SAT_DET_STATUS_EN = "FALSE"           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_SAT_DET_STATUS_RESET_EN = "FALSE"     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_PI_CTRL_RST = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_PI_CTRL_RST_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_SAT_DET_RST = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_SAT_DET_RST_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_SAT_DET_STICKY_RST = "FALSE"          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_SAT_DET_STICKY_RST_OW = "FALSE"       ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_SIGDET_STATUS_DIS = "FALSE"           ,//TRUE, FALSE; for sigdet_status is 0 to reset cdr                             
    parameter    integer    PMA_CH1_REG_CDR_SAT_DET_TIMER = 2                     ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_CDR_SAT_DET_STATUS_VAL = "FALSE"          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_SAT_DET_STATUS_OW = "FALSE"           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_CDR_TURBO_MODE_EN = "TRUE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_RESERVED_190 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_RESERVED_193_191 = 0                   ,//0 to 7                                                                       
    parameter               PMA_CH1_REG_CDR_STATUS_FIFO_EN = "TRUE"               ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_PMA_TEST_SEL = 0                          ,//0,1                                                                          
    parameter    integer    PMA_CH1_REG_OOB_COMWAKE_GAP_MIN = 3                   ,//0 to 63                                                                      
    parameter    integer    PMA_CH1_REG_OOB_COMWAKE_GAP_MAX = 11                  ,//0 to 63                                                                      
    parameter    integer    PMA_CH1_REG_OOB_COMINIT_GAP_MIN = 15                  ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_REG_OOB_COMINIT_GAP_MAX = 35                  ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_REG_RX_RESERVED_227_226 = 1                   ,//0 to 3                                                                       
    parameter    integer    PMA_CH1_REG_COMWAKE_STATUS_CLEAR = 0                  ,//0,1                                                                          
    parameter    integer    PMA_CH1_REG_COMINIT_STATUS_CLEAR = 0                  ,//0,1                                                                          
    parameter               PMA_CH1_REG_RX_SYNC_RST_N_EN = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_SYNC_RST_N = "TRUE"                    ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_RESERVED_233_232 = 0                   ,//0 to 3                                                                       
    parameter    integer    PMA_CH1_REG_RX_RESERVED_235_234 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_RX_SATA_COMINIT_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_SATA_COMINIT = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_SATA_COMWAKE_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_SATA_COMWAKE = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_RESERVED_241_240 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_RX_DCC_DISABLE = "FALSE"                  ,//TRUE, FALSE; for rx dcc disable control                                      
    parameter               PMA_CH1_REG_RX_RESERVED_243 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_SLIP_SEL_EN = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_SLIP_SEL = 0                           ,//0 to 15                                                                      
    parameter               PMA_CH1_REG_RX_SLIP_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_SIGDET_STATUS_SEL = 5                  ,//0 to 7                                                                       
    parameter               PMA_CH1_REG_RX_SIGDET_FSM_RST_N = "TRUE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_RESERVED_254 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_SIGDET_STATUS = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_SIGDET_VTH = "72MV"                    ,//"45MV" "54MV" "63MV" "72MV"                       
    parameter    integer    PMA_CH1_REG_RX_SIGDET_GRM = 0                         ,//0,1,2,3                                                                      
    parameter               PMA_CH1_REG_RX_SIGDET_PULSE_EXT = "FALSE"             ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_SIGDET_CH2_SEL = 0                     ,//0,1                                                                          
    parameter    integer    PMA_CH1_REG_RX_SIGDET_CH2_CHK_WINDOW = 3              ,//0 to 31                                                                      
    parameter               PMA_CH1_REG_RX_SIGDET_CHK_WINDOW_EN = "TRUE"          ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_SIGDET_NOSIG_COUNT_SETTING = 4         ,//0 to 7                                                                       
    parameter               PMA_CH1_REG_SLIP_FIFO_INV_EN = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_SLIP_FIFO_INV = "POS_EDGE"                ,//"POS_EDGE" "NEG_EDGE"                                                        
    parameter    integer    PMA_CH1_REG_RX_SIGDET_OOB_DET_COUNT_VAL = 0           ,//0 to 31                                                                      
    parameter    integer    PMA_CH1_REG_RX_SIGDET_4OOB_DET_SEL = 7                ,//0 to 7                                                                       
    parameter    integer    PMA_CH1_REG_RX_RESERVED_285_283 = 0                   ,//0 to 7                                                                       
    parameter               PMA_CH1_REG_RX_RESERVED_286 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_SIGDET_IC_I = 10                       ,//0 to 15                                                                      
    parameter               PMA_CH1_REG_RX_OOB_DETECTOR_RESET_N_OW = "FALSE"      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_OOB_DETECTOR_RESET_N = "FALSE"         ,//TRUE, FALSE;for rx oob detector Reset                                        
    parameter               PMA_CH1_REG_RX_OOB_DETECTOR_PD_OW = "FALSE"           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_OOB_DETECTOR_PD = "ON"                 ,//TRUE, FALSE;for rx oob detector powerdown                                    
    parameter               PMA_CH1_REG_RX_LS_MODE_EN = "FALSE"                   ,//TRUE, FALSE;for Enable Low-speed mode                                        
    parameter               PMA_CH1_REG_ANA_RX_EQ1_R_SET_FB_O_SEL = "TRUE"        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_ANA_RX_EQ2_R_SET_FB_O_SEL = "TRUE"        ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_EQ1_R_SET_TOP = 0                      ,//0 to 3                                                                       
    parameter    integer    PMA_CH1_REG_RX_EQ1_R_SET_FB = 15                      ,//0 to 15                                                                      
    parameter    integer    PMA_CH1_REG_RX_EQ1_C_SET_FB = 0                       ,//0 to 15                                                                      
    parameter               PMA_CH1_REG_RX_EQ1_OFF = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_EQ2_R_SET_TOP = 0                      ,//0 to 3                                                                       
    parameter    integer    PMA_CH1_REG_RX_EQ2_R_SET_FB = 0                       ,//0 to 15                                                                      
    parameter    integer    PMA_CH1_REG_RX_EQ2_C_SET_FB = 0                       ,//0 to 15                                                                      
    parameter               PMA_CH1_REG_RX_EQ2_OFF = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_EQ_DAC = 0                                ,//0 to 63                                                                      
    parameter    integer    PMA_CH1_REG_RX_ICTRL_EQ = 2                           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_EQ_DC_CALIB_EN = "TRUE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_EQ_DC_CALIB_SEL = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_RESERVED_337_330 = 0                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_REG_RX_RESERVED_345_338 = 0                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_REG_RX_RESERVED_353_346 = 0                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_REG_RX_RESERVED_361_354 = 0                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_CTLE_CTRL_REG_I = 0                           ,//0 to 15                                                                      
    parameter               PMA_CH1_CTLE_REG_FORCE_SEL_I = "FALSE"                ,//TRUE, FALSE;for ctrl self-adaption adjust                                    
    parameter               PMA_CH1_CTLE_REG_HOLD_I = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_CTLE_REG_INIT_DAC_I = 0                       ,//0 to 15                                                                      
    parameter               PMA_CH1_CTLE_REG_POLARITY_I = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_CTLE_REG_SHIFTER_GAIN_I = 1                   ,//0 to 7                                                                       
    parameter    integer    PMA_CH1_CTLE_REG_THRESHOLD_I = 3072                   ,//0 to 4095                                                                    
    parameter               PMA_CH1_REG_RX_RES_TRIM_EN = "TRUE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_RESERVED_393_389 = 0                   ,//0 to 31                                                                      
    parameter               PMA_CH1_CFG_RX_LANE_POWERUP = "ON"                    ,//ON, OFF;for RX_LANE Power-up                                                 
    parameter               PMA_CH1_CFG_RX_PMA_RSTN = "TRUE"                      ,//TRUE, FALSE;for RX_PMA Reset                                                 
    parameter               PMA_CH1_INT_PMA_RX_MASK_0 = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_INT_PMA_RX_CLR_0 = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_CFG_CTLE_ADP_RSTN = "TRUE"                    ,//TRUE, FALSE;for ctrl Reset                                                   
    //pma_tx                                                                                                                                                 
    parameter               PMA_CH1_REG_TX_PD = "ON"                              ,//ON, OFF;for transmitter power down                                           
    parameter               PMA_CH1_REG_TX_PD_OW = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_MAIN_PRE_Z = "FALSE"                   ,//TRUE, FALSE;Enable EI for PCIE mode                                          
    parameter               PMA_CH1_REG_TX_MAIN_PRE_Z_OW = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_TX_BEACON_TIMER_SEL = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_TX_RXDET_REQ_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RXDET_REQ = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_BEACON_EN_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_BEACON_EN = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_EI_EN_OW = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_EI_EN = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_BIT_CONV = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_TX_RES_CAL = 48                           ,//0 to 63                                                                      
    parameter               PMA_CH1_REG_TX_RESERVED_19 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_TX_RESERVED_25_20 = 32                    ,//0 to 63                                                                      
    parameter    integer    PMA_CH1_REG_TX_RESERVED_33_26 = 0                     ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_REG_TX_RESERVED_41_34 = 0                     ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_REG_TX_RESERVED_49_42 = 0                     ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_REG_TX_RESERVED_57_50 = 0                     ,//0 to 255                                                                     
    parameter               PMA_CH1_REG_TX_SYNC_OW = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_SYNC = "FALSE"                         ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_PD_POST = "OFF"                        ,//ON, OFF;                                                                     
    parameter               PMA_CH1_REG_TX_PD_POST_OW = "TRUE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RESET_N_OW = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RESET_N = "TRUE"                       ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RESERVED_64 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RESERVED_65 = "TRUE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_BUSWIDTH_OW = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_BUSWIDTH = "20BIT"                     ,//"8BIT" "10BIT" "16BIT" "20BIT"                                               
    parameter               PMA_CH1_REG_PLL_READY_OW = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_PLL_READY = "TRUE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RESERVED_72 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RESERVED_73 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RESERVED_74 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_EI_PCLK_DELAY_SEL = 0                     ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_TX_RESERVED_77 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_TX_RESERVED_83_78 = 0                     ,//0 to 63                                                                      
    parameter    integer    PMA_CH1_REG_TX_RESERVED_89_84 = 0                     ,//0 to 63                                                                      
    parameter    integer    PMA_CH1_REG_TX_RESERVED_95_90 = 0                     ,//0 to 63                                                                      
    parameter    integer    PMA_CH1_REG_TX_RESERVED_101_96 = 0                    ,//0 to 63                                                                      
    parameter    integer    PMA_CH1_REG_TX_RESERVED_107_102 = 0                   ,//0 to 63                                                                      
    parameter    integer    PMA_CH1_REG_TX_RESERVED_113_108 = 0                   ,//0 to 63                                                                      
    parameter    integer    PMA_CH1_REG_TX_AMP_DAC0 = 25                          ,//0 to 63                                                                      
    parameter    integer    PMA_CH1_REG_TX_AMP_DAC1 = 19                          ,//0 to 63                                                                      
    parameter    integer    PMA_CH1_REG_TX_AMP_DAC2 = 14                          ,//0 to 63                                                                      
    parameter    integer    PMA_CH1_REG_TX_AMP_DAC3 = 9                           ,//0 to 63                                                                      
    parameter    integer    PMA_CH1_REG_TX_RESERVED_143_138 = 5                   ,//0 to 63                                                                      
    parameter    integer    PMA_CH1_REG_TX_MARGIN = 0                             ,//0 to 7                                                                       
    parameter               PMA_CH1_REG_TX_MARGIN_OW = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_TX_RESERVED_149_148 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_TX_RESERVED_150 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_SWING = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_SWING_OW = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RESERVED_153 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RXDET_THRESHOLD = "84MV"               ,//"28MV" "56MV" "84MV" "112MV"                                                 
    parameter    integer    PMA_CH1_REG_TX_RESERVED_157_156 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_TX_BEACON_OSC_CTRL = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_TX_RESERVED_160_159 = 0                   ,//0 to 3                                                                       
    parameter    integer    PMA_CH1_REG_TX_RESERVED_162_161 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_TX_TX2RX_SLPBACK_EN = "FALSE"             ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_PCLK_EDGE_SEL = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RXDET_STATUS_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RXDET_STATUS = "TRUE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_PRBS_GEN_EN = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_PRBS_GEN_WIDTH_SEL = "20BIT"           ,//"8BIT" "10BIT" "16BIT" "20BIT"                                               
    parameter               PMA_CH1_REG_TX_PRBS_SEL = "PRBS7"                     ,//"PRBS7" "PRBS15" "PRBS23" "PRBS31"                                           
    parameter    integer    PMA_CH1_REG_TX_UDP_DATA_7_TO_0 = 5                    ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_REG_TX_UDP_DATA_15_TO_8 = 235                 ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_REG_TX_UDP_DATA_19_TO_16 = 3                  ,//0 to 15                                                                      
    parameter               PMA_CH1_REG_TX_RESERVED_192 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_TX_FIFO_WP_CTRL = 4                       ,//0 to 7                                                                       
    parameter               PMA_CH1_REG_TX_FIFO_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_TX_DATA_MUX_SEL = 0                       ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_TX_ERR_INSERT = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_TX_RESERVED_203_200 = 0                   ,//0 to15                                                                       
    parameter               PMA_CH1_REG_TX_RESERVED_204 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_SATA_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_TX_RESERVED_207_206 = 0                   ,//0 to3                                                                        
    parameter               PMA_CH1_REG_RATE_CHANGE_TXPCLK_ON_OW = "FALSE"        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RATE_CHANGE_TXPCLK_ON = "TRUE"            ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_TX_CFG_POST1 = 0                          ,//0 to 31                                                                      
    parameter    integer    PMA_CH1_REG_TX_CFG_POST2 = 0                          ,//0 to 31                                                                      
    parameter    integer    PMA_CH1_REG_TX_DEEMP = 0                              ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_TX_DEEMP_OW = "FALSE"                     ,//TRUE, FALSE;for TX DEEMP Control                                             
    parameter    integer    PMA_CH1_REG_TX_RESERVED_224_223 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_TX_RESERVED_225 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_TX_RESERVED_229_226 = 0                   ,//0 to 15                                                                      
    parameter    integer    PMA_CH1_REG_TX_OOB_DELAY_SEL = 0                      ,//0 to 15                                                                      
    parameter               PMA_CH1_REG_TX_POLARITY = "NORMAL"                    ,//"NORMAL" "REVERSE"                                                           
    parameter               PMA_CH1_REG_ANA_TX_JTAG_DATA_O_SEL = "FALSE"          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RESERVED_236 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_LS_MODE_EN = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_JTAG_MODE_EN_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_JTAG_MODE_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_JTAG_MODE_EN_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_JTAG_MODE_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_RX_JTAG_OE = "TRUE"                       ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_ACJTAG_VHYSTSEL = 0                    ,//0 to 7                                                                       
    parameter               PMA_CH1_REG_TX_RES_CAL_EN = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_RX_TERM_MODE_CTRL = 5                     ,//0 to 7; for rx terminatin Control                                            
    parameter    integer    PMA_CH1_REG_TX_RESERVED_251_250 = 0                   ,//0 to 7                                                                       
    parameter               PMA_CH1_REG_PLPBK_TXPCLK_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RESERVED_253 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RESERVED_254 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RESERVED_255 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RESERVED_256 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_RESERVED_257 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_TX_PH_SEL = 1                             ,//0 to 63                                                                      
    parameter    integer    PMA_CH1_REG_TX_CFG_PRE = 0                            ,//0 to 31                                                                      
    parameter    integer    PMA_CH1_REG_TX_CFG_MAIN = 0                           ,//0 to 63                                                                      
    parameter    integer    PMA_CH1_REG_CFG_POST = 0                              ,//0 to 31                                                                      
    parameter               PMA_CH1_REG_PD_MAIN = "TRUE"                          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_PD_PRE = "TRUE"                           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_LS_DATA = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_TX_DCC_BUF_SZ_SEL = 0                     ,//0 to 3                                                                       
    parameter    integer    PMA_CH1_REG_TX_DCC_CAL_CUR_TUNE = 0                   ,//0 to 63                                                                      
    parameter               PMA_CH1_REG_TX_DCC_CAL_EN = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_TX_DCC_CUR_SS = 0                         ,//0 to 3                                                                       
    parameter               PMA_CH1_REG_TX_DCC_FA_CTRL = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_DCC_RI_CTRL = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_ATB_SEL_2_TO_0 = 0                        ,//0 to 7                                                                       
    parameter    integer    PMA_CH1_REG_ATB_SEL_9_TO_3 = 0                        ,//0 to 127                                                                     
    parameter    integer    PMA_CH1_REG_TX_CFG_7_TO_0 = 0                         ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_REG_TX_CFG_15_TO_8 = 0                        ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_REG_TX_CFG_23_TO_16 = 0                       ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_REG_TX_CFG_31_TO_24 = 128                     ,//0 to 255                                                                     
    parameter               PMA_CH1_REG_TX_OOB_EI_EN = "FALSE"                    ,//TRUE, FALSE; Enable OOB EI for SATA mode                                     
    parameter               PMA_CH1_REG_TX_OOB_EI_EN_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_BEACON_EN_DELAYED = "FALSE"            ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_BEACON_EN_DELAYED_OW = "FALSE"         ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH1_REG_TX_JTAG_DATA = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH1_REG_TX_RXDET_TIMER_SEL = 87                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_REG_TX_CFG1_7_0 = 0                           ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_REG_TX_CFG1_15_8 = 0                          ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_REG_TX_CFG1_23_16 = 0                         ,//0 to 255                                                                     
    parameter    integer    PMA_CH1_REG_TX_CFG1_31_24 = 0                         ,//0 to 255                                                                     
    parameter               PMA_CH1_REG_CFG_LANE_POWERUP = "ON"                   ,//ON, OFF; for PMA_LANE powerup                                                
    parameter               PMA_CH1_REG_CFG_TX_LANE_POWERUP_CLKPATH = "TRUE"      ,//TRUE, FALSE; for Pma tx lane clkpath powerup                                 
    parameter               PMA_CH1_REG_CFG_TX_LANE_POWERUP_PISO = "TRUE"         ,//TRUE, FALSE; for Pma tx lane piso powerup                                    
    parameter               PMA_CH1_REG_CFG_TX_LANE_POWERUP_DRIVER = "TRUE"       ,//TRUE, FALSE; for Pma tx lane driver powerup                                  
    //--------CHANNEL2 parameter--------//
    parameter    integer    CH2_MUX_BIAS = 2                                      ,//0 to 7; don't support simulation                                             
    parameter    integer    CH2_PD_CLK = 0                                        ,//0 to 1                                                                       
    parameter    integer    CH2_REG_SYNC = 0                                      ,//0 to 1                                                                       
    parameter    integer    CH2_REG_SYNC_OW = 0                                   ,//0 to 1                                                                       
    parameter    integer    CH2_PLL_LOCK_OW = 0                                   ,//0 to 1                                                                       
    parameter    integer    CH2_PLL_LOCK_OW_EN = 0                                ,//0 to 1                                                                       
    //pcs
    parameter    integer    PCS_CH2_SLAVE = 0                                     ,//Altered in 2019.12.05, should be configured by user, software only checks corresponding connection of clock
    parameter               PCS_CH2_BYPASS_WORD_ALIGN = "FALSE"                   ,//TRUE, FALSE; for bypass word alignment                                       
    parameter               PCS_CH2_BYPASS_DENC = "FALSE"                         ,//TRUE, FALSE; for bypass 8b/10b decoder                                       
    parameter               PCS_CH2_BYPASS_BONDING = "FALSE"                      ,//TRUE, FALSE; for bypass channel bonding                                      
    parameter               PCS_CH2_BYPASS_CTC = "FALSE"                          ,//TRUE, FALSE; for bypass ctc                                                  
    parameter               PCS_CH2_BYPASS_GEAR = "FALSE"                         ,//TRUE, FALSE; for bypass Rx Gear                                              
    parameter               PCS_CH2_BYPASS_BRIDGE = "FALSE"                       ,//TRUE, FALSE; for bypass Rx Bridge unit                                       
    parameter               PCS_CH2_BYPASS_BRIDGE_FIFO = "FALSE"                  ,//TRUE, FALSE; for bypass Rx Bridge FIFO                                       
    parameter               PCS_CH2_DATA_MODE = "X8"                              ,//"X8","X10","X16","X20"                                                       
    parameter               PCS_CH2_RX_POLARITY_INV = "DELAY"                     ,//"DELAY","BIT_POLARITY_INVERION","BIT_REVERSAL","BOTH"                        
    parameter               PCS_CH2_ALIGN_MODE = "1GB"                            ,//1GB, 10GB, RAPIDIO, OUTSIDE                                                  
    parameter               PCS_CH2_SAMP_16B = "X20"                              ,//"X20",X16                                                                    
    parameter               PCS_CH2_FARLP_PWR_REDUCTION = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PCS_CH2_COMMA_REG0 = 0                                ,//0 to 1023                                                                    
    parameter    integer    PCS_CH2_COMMA_MASK = 0                                ,//0 to 1023                                                                    
    parameter               PCS_CH2_CEB_MODE = "10GB"                             ,//"10GB" "RAPIDIO" "OUTSIDE"                                                   
    parameter               PCS_CH2_CTC_MODE = "1SKIP"                            ,//1SKIP, 2SKIP, PCIE_2BYTE, 4SKIP                                              
    parameter    integer    PCS_CH2_A_REG = 0                                     ,//0 to 255                                                                     
    parameter               PCS_CH2_GE_AUTO_EN = "FALSE"                          ,//TRUE, FALSE;                                                                 
    parameter    integer    PCS_CH2_SKIP_REG0 = 0                                 ,//0 to 1023                                                                    
    parameter    integer    PCS_CH2_SKIP_REG1 = 0                                 ,//0 to 1023                                                                    
    parameter    integer    PCS_CH2_SKIP_REG2 = 0                                 ,//0 to 1023                                                                    
    parameter    integer    PCS_CH2_SKIP_REG3 = 0                                 ,//0 to 1023                                                                    
    parameter               PCS_CH2_DEC_DUAL = "FALSE"                            ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_SPLIT = "FALSE"                               ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_FIFOFLAG_CTC = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_COMMA_DET_MODE = "COMMA_PATTERN"              ,//"RX_CLK_SLIP" "COMMA_PATTERN"                                                
    parameter               PCS_CH2_ERRDETECT_SILENCE = "TRUE"                    ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_PMA_RCLK_POLINV = "PMA_RCLK"                  ,//"PMA_RCLK" "REVERSE_OF_PMA_RCLK"                                             
    parameter               PCS_CH2_PCS_RCLK_SEL = "PMA_RCLK"                     ,//"PMA_RCLK" "PMA_TCLK" "RCLK"                                                 
    parameter               PCS_CH2_CB_RCLK_SEL = "PMA_RCLK"                      ,//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK"                                             
    parameter               PCS_CH2_AFTER_CTC_RCLK_SEL = "PMA_RCLK"               ,//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK" "RCLK2"                                     
    parameter               PCS_CH2_RCLK_POLINV = "RCLK"                          ,//"RCLK" "REVERSE_OF_RCLK"                                                     
    parameter               PCS_CH2_BRIDGE_RCLK_SEL = "PMA_RCLK"                  ,//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK" "RCLK"                                      
    parameter               PCS_CH2_PCS_RCLK_EN = "FALSE"                         ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_CB_RCLK_EN = "FALSE"                          ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_AFTER_CTC_RCLK_EN = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_AFTER_CTC_RCLK_EN_GB = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_PCS_RX_RSTN = "TRUE"                          ,//TRUE, FALSE; for PCS Receiver Reset                                          
    parameter               PCS_CH2_PCIE_SLAVE = "MASTER"                         ,//"MASTER","SLAVE"                                                             
    parameter               PCS_CH2_RX_64B66B_67B = "NORMAL"                      ,//"NORMAL" "64B_66B" "64B_67B"                                                 
    parameter               PCS_CH2_RX_BRIDGE_CLK_POLINV = "RX_BRIDGE_CLK"        ,//"RX_BRIDGE_CLK" "REVERSE_OF_RX_BRIDGE_CLK"                                   
    parameter               PCS_CH2_PCS_CB_RSTN = "TRUE"                         ,//TRUE, FALSE; for PCS CB Reset                                                
    parameter               PCS_CH2_TX_BRIDGE_GEAR_SEL = "FALSE"                  ,//TRUE: tx gear priority, FALSE:tx bridge unit priority                        
    parameter               PCS_CH2_TX_BYPASS_BRIDGE_UINT = "FALSE"               ,//TRUE, FALSE; for bypass                                                      
    parameter               PCS_CH2_TX_BYPASS_BRIDGE_FIFO = "FALSE"               ,//TRUE, FALSE; for bypass Tx Bridge FIFO                                       
    parameter               PCS_CH2_TX_BYPASS_GEAR = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_TX_BYPASS_ENC = "FALSE"                       ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_TX_BYPASS_BIT_SLIP = "TRUE"                   ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_TX_GEAR_SPLIT = "TRUE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_TX_DRIVE_REG_MODE = "NO_CHANGE"               ,//"NO_CHANGE" "EN_POLARIY_REV" "EN_BIT_REV" "EN_BOTH"                          
    parameter    integer    PCS_CH2_TX_BIT_SLIP_CYCLES = 0                        ,//o to 31                                                                      
    parameter               PCS_CH2_INT_TX_MASK_0 = "FALSE"                       ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_INT_TX_MASK_1 = "FALSE"                       ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_INT_TX_MASK_2 = "FALSE"                       ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_INT_TX_CLR_0 = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_INT_TX_CLR_1 = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_INT_TX_CLR_2 = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_TX_PMA_TCLK_POLINV = "PMA_TCLK"               ,//"PMA_TCLK" "REVERSE_OF_PMA_TCLK"                                             
    parameter               PCS_CH2_TX_PCS_CLK_EN_SEL = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_TX_BRIDGE_TCLK_SEL = "TCLK"                   ,//"PCS_TCLK" "TCLK"                                                            
    parameter               PCS_CH2_TX_TCLK_POLINV = "TCLK"                       ,//"TCLK" "REVERSE_OF_TCLK"                                                     
    parameter               PCS_CH2_PCS_TCLK_SEL= "PMA_TCLK"                      ,//"PMA_TCLK" "TCLK"                                                            
    parameter               PCS_CH2_TX_PCS_TX_RSTN = "TRUE"                       ,//TRUE, FALSE; for PCS Transmitter Reset                                       
    parameter               PCS_CH2_TX_SLAVE = "MASTER"                           ,//"MASTER" "SLAVE"                                                             
    parameter               PCS_CH2_TX_GEAR_CLK_EN_SEL = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH2_DATA_WIDTH_MODE = "X20"                       ,//"X8" "X10" "X16" "X20"                                                       
    parameter               PCS_CH2_TX_64B66B_67B = "NORMAL"                      ,//"NORMAL" "64B_66B" "64B_67B"                                                 
    parameter               PCS_CH2_GEAR_TCLK_SEL = "PMA_TCLK"                    ,//"PMA_TCLK" "TCLK2"                                                           
    parameter               PCS_CH2_TX_TCLK2FABRIC_SEL = "TRUE"                   ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_TX_OUTZZ = "FALSE"                            ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_ENC_DUAL = "FALSE"                            ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_TX_BITSLIP_DATA_MODE = "X10"                  ,//"X10" "X20"                                                                  
    parameter               PCS_CH2_TX_BRIDGE_CLK_POLINV = "TX_BRIDGE_CLK"        ,//"TX_BRIDGE_CLK" "REVERSE_OF_TX_BRIDGE_CLK"                                   
    parameter    integer    PCS_CH2_COMMA_REG1 = 0                                ,//0 to 1023                                                                    
    parameter    integer    PCS_CH2_RAPID_IMAX = 0                                ,//0 to 7                                                                       
    parameter    integer    PCS_CH2_RAPID_VMIN_1 = 0                              ,//0 to 255                                                                     
    parameter    integer    PCS_CH2_RAPID_VMIN_2 = 0                              ,//0 to 255                                                                     
    parameter               PCS_CH2_RX_PRBS_MODE = "DISABLE"                      ,//DISABLE PRBS_7 PRBS_15 PRBS_23 PRBS_31                                       
    parameter               PCS_CH2_RX_ERRCNT_CLR = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_PRBS_ERR_LPBK = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_TX_PRBS_MODE = "DISABLE"                      ,//DISABLE PRBS_7 PRBS_15 PRBS_23 PRBS_31 LONG_1 LONG_0 20UI D10_2 PCIE         
    parameter               PCS_CH2_TX_INSERT_ER = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_ENABLE_PRBS_GEN = "FALSE"                     ,//TRUE, FALSE                                                                  
    parameter    integer    PCS_CH2_DEFAULT_RADDR = 6                             ,//0 to 15                                                                      
    parameter    integer    PCS_CH2_MASTER_CHECK_OFFSET = 0                       ,//0 to 15                                                                      
    parameter    integer    PCS_CH2_DELAY_SET = 0                                 ,//0 to 15                                                                      
    parameter               PCS_CH2_SEACH_OFFSET = "20BIT"                        ,//"20BIT" 30BIT" "40BIT" "50BIT" "60BIT" "70BIT" "80BIT"                       
    parameter    integer    PCS_CH2_CEB_RAPIDLS_MMAX = 0                          ,//0 to 7                                                                       
    parameter    integer    PCS_CH2_CTC_AFULL = 20                                ,//0 to 31                                                                      
    parameter    integer    PCS_CH2_CTC_AEMPTY = 12                               ,//0 to 31                                                                      
    parameter    integer    PCS_CH2_CTC_CONTI_SKP_SET = 0                         ,//0 to 1                                                                       
    parameter               PCS_CH2_FAR_LOOP = "FALSE"                            ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_NEAR_LOOP = "FALSE"                           ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_PMA_TX2RX_PLOOP_EN = "FALSE"                  ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_PMA_TX2RX_SLOOP_EN = "FALSE"                  ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_PMA_RX2TX_PLOOP_EN = "FALSE"                  ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_INT_RX_MASK_0 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_INT_RX_MASK_1 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_INT_RX_MASK_2 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_INT_RX_MASK_3 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_INT_RX_MASK_4 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_INT_RX_MASK_5 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_INT_RX_MASK_6 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_INT_RX_MASK_7 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_INT_RX_CLR_0 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_INT_RX_CLR_1 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_INT_RX_CLR_2 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_INT_RX_CLR_3 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_INT_RX_CLR_4 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_INT_RX_CLR_5 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_INT_RX_CLR_6 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_INT_RX_CLR_7 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_CA_RSTN_RX = "FALSE"                          ,//TRUE, FALSE; for Rx CLK Aligner Reset                                        
    parameter               PCS_CH2_CA_DYN_DLY_EN_RX = "FALSE"                    ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_CA_DYN_DLY_SEL_RX = "FALSE"                   ,//TRUE, FALSE                                                                  
    parameter    integer    PCS_CH2_CA_RX = 0                                     ,//0 to 255                                                                     
    parameter               PCS_CH2_CA_RSTN_TX = "FALSE"                          ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_CA_DYN_DLY_EN_TX = "FALSE"                    ,//TRUE, FALSE                                                                  
    parameter               PCS_CH2_CA_DYN_DLY_SEL_TX = "FALSE"                   ,//TRUE, FALSE                                                                  
    parameter    integer    PCS_CH2_CA_TX = 0                                     ,//0 to 255                                                                     
    parameter               PCS_CH2_RXPRBS_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH2_WDALIGN_PWR_REDUCTION = "NORMAL"              ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH2_RXDEC_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH2_RXCB_PWR_REDUCTION = "NORMAL"                 ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH2_RXCTC_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH2_RXGEAR_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH2_RXBRG_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH2_RXTEST_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH2_TXBRG_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH2_TXGEAR_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH2_TXENC_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH2_TXBSLP_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH2_TXPRBS_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    //pma_rx                                                                                                                                                 
    parameter               PMA_CH2_REG_RX_PD = "ON"                              ,//ON, OFF;                                                                     
    parameter               PMA_CH2_REG_RX_PD_EN = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PMA_CH2_REG_RX_RESERVED_2 = "FALSE"                   ,//TRUE, FALSE                                                                  
    parameter               PMA_CH2_REG_RX_RESERVED_3 = "FALSE"                   ,//TRUE, FALSE                                                                  
    parameter               PMA_CH2_REG_RX_DATAPATH_PD = "ON"                     ,//ON, OFF;                                                                     
    parameter               PMA_CH2_REG_RX_DATAPATH_PD_EN = "FALSE"               ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_SIGDET_PD = "ON"                       ,//ON, OFF;                                                                     
    parameter               PMA_CH2_REG_RX_SIGDET_PD_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_DCC_RST_N = "TRUE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_DCC_RST_N_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_CDR_RST_N = "TRUE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_CDR_RST_N_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_SIGDET_RST_N = "TRUE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_SIGDET_RST_N_EN = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RXPCLK_SLIP = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RXPCLK_SLIP_OW = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_PCLKSWITCH_RST_N = "TRUE"              ,//TRUE, FALSE; for TX PMA Reset                                                
    parameter               PMA_CH2_REG_RX_PCLKSWITCH_RST_N_EN = "FALSE"          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_PCLKSWITCH = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_PCLKSWITCH_EN = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_HIGHZ = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_HIGHZ_EN = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_SIGDET_CLK_WINDOW = "FALSE"            ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_SIGDET_CLK_WINDOW_OW = "FALSE"         ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_PD_BIAS_RX = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_PD_BIAS_RX_OW = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_RESET_N = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_RESET_N_OW = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_RESERVED_29_28 = 0                     ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_RX_BUSWIDTH = "20BIT"                     ,//"8BIT" "10BIT" "16BIT" "20BIT"                                               
    parameter               PMA_CH2_REG_RX_BUSWIDTH_EN = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_RATE = "DIV1"                          ,//"DIV4" "DIV2" "DIV1" "MUL2"                                                  
    parameter               PMA_CH2_REG_RX_RESERVED_36 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_RATE_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_RES_TRIM = 46                          ,//0 to 63                                                                      
    parameter               PMA_CH2_REG_RX_RESERVED_44 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_RESERVED_45 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_SIGDET_STATUS_EN = "FALSE"             ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_RESERVED_48_47 = 0                     ,//0 to 3                                                                       
    parameter    integer    PMA_CH2_REG_RX_ICTRL_SIGDET = 5                       ,//0 to 15                                                                      
    parameter    integer    PMA_CH2_REG_CDR_READY_THD = 2734                      ,//0 to 4095                                                                    
    parameter               PMA_CH2_REG_RX_RESERVED_65 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_PCLK_EDGE_SEL = "POS_EDGE"             ,//"POS_EDGE" "NEG_EDGE"                                                        
    parameter    integer    PMA_CH2_REG_RX_PIBUF_IC = 1                           ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_RX_RESERVED_69 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_DCC_IC_RX = 1                          ,//0 to 3                                                                       
    parameter    integer    PMA_CH2_REG_CDR_READY_CHECK_CTRL = 0                  ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_RX_ICTRL_TRX = "100PCT"                   ,//"87_5PCT" "100PCT" "112_5PCT" "125PCT"                                       
    parameter    integer    PMA_CH2_REG_RX_RESERVED_77_76 = 0                     ,//0 to 3                                                                       
    parameter    integer    PMA_CH2_REG_RX_RESERVED_79_78 = 1                     ,//0 to 3                                                                       
    parameter    integer    PMA_CH2_REG_RX_RESERVED_81_80 = 1                     ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_RX_ICTRL_PIBUF = "100PCT"                 ,//"87_5PCT" "100PCT" "112_5PCT" "125PCT"                                       
    parameter               PMA_CH2_REG_RX_ICTRL_PI = "100PCT"                    ,//"87_5PCT" "100PCT" "112_5PCT" "125PCT"                                       
    parameter               PMA_CH2_REG_RX_ICTRL_DCC = "100PCT"                   ,//"87_5PCT" "100PCT" "112_5PCT" "125PCT"                                       
    parameter    integer    PMA_CH2_REG_RX_RESERVED_89_88 = 1                     ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_TX_RATE = "DIV1"                          ,//"DIV4" "DIV2" "DIV1" "MUL2"                                                  
    parameter               PMA_CH2_REG_RX_RESERVED_92 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RATE_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_TX2RX_PLPBK_RST_N = "TRUE"             ,//TRUE, FALSE; for tx2rx pma parallel loop back Reset                          
    parameter               PMA_CH2_REG_RX_TX2RX_PLPBK_RST_N_EN = "FALSE"         ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_TX2RX_PLPBK_EN = "FALSE"               ,//TRUE, FALSE; for tx2rx pma parallel loop back enable                         
    parameter               PMA_CH2_REG_TXCLK_SEL = "PLL"                         ,//"PLL" "RXCLK"                                                                
    parameter               PMA_CH2_REG_RX_DATA_POLARITY = "NORMAL"               ,//"NORMAL" "REVERSE"                                                           
    parameter               PMA_CH2_REG_RX_ERR_INSERT = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_UDP_CHK_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_PRBS_SEL = "PRBS7"                        ,//"PRBS7" "PRBS15" "PRBS23" "PRBS31"                                           
    parameter               PMA_CH2_REG_PRBS_CHK_EN = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_PRBS_CHK_WIDTH_SEL = "20BIT"              ,//"8BIT" "10BIT" "16BIT" "20BIT"                                               
    parameter               PMA_CH2_REG_BIST_CHK_PAT_SEL = "PRBS"                 ,//"PRBS" "CONSTANT"                                                            
    parameter               PMA_CH2_REG_LOAD_ERR_CNT = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CHK_COUNTER_EN = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_CDR_PROP_GAIN = 7                         ,//0 to 7                                                                       
    parameter    integer    PMA_CH2_REG_CDR_PROP_TURBO_GAIN = 5                   ,//0 to 7                                                                       
    parameter    integer    PMA_CH2_REG_CDR_INT_GAIN = 4                          ,//0 to 7                                                                       
    parameter    integer    PMA_CH2_REG_CDR_INT_TURBO_GAIN = 5                    ,//0 to 7                                                                       
    parameter    integer    PMA_CH2_REG_CDR_INT_SAT_MAX = 768                     ,//0 to 1023                                                                    
    parameter    integer    PMA_CH2_REG_CDR_INT_SAT_MIN = 255                     ,//0 to 1023                                                                    
    parameter               PMA_CH2_REG_CDR_INT_RST = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_INT_RST_OW = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_PROP_RST = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_PROP_RST_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_LOCK_RST = "FALSE"                    ,//TRUE, FALSE; for CDR LOCK Counter Reset                                      
    parameter               PMA_CH2_REG_CDR_LOCK_RST_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_CDR_RX_PI_FORCE_SEL = 0                   ,//0,1                                                                          
    parameter    integer    PMA_CH2_REG_CDR_RX_PI_FORCE_D = 0                     ,//0 to 255                                                                     
    parameter               PMA_CH2_REG_CDR_LOCK_TIMER = "1_2U"                   ,//"0_8U" "1_2U" "1_6U" "2_4U" 3_2U" "4_8U" "12_8U" "25_6U"                     
    parameter    integer    PMA_CH2_REG_CDR_TURBO_MODE_TIMER = 1                  ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_CDR_LOCK_VAL = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_LOCK_OW = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_INT_SAT_DET_EN = "TRUE"               ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_SAT_AUTO_DIS = "TRUE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_GAIN_AUTO = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_TURBO_GAIN_AUTO = "FALSE"             ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_RESERVED_171_167 = 0                   ,//0 to 31                                                                      
    parameter    integer    PMA_CH2_REG_RX_RESERVED_175_172 = 0                   ,//0 to 31                                                                      
    parameter               PMA_CH2_REG_CDR_SAT_DET_STATUS_EN = "FALSE"           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_SAT_DET_STATUS_RESET_EN = "FALSE"     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_PI_CTRL_RST = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_PI_CTRL_RST_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_SAT_DET_RST = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_SAT_DET_RST_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_SAT_DET_STICKY_RST = "FALSE"          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_SAT_DET_STICKY_RST_OW = "FALSE"       ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_SIGDET_STATUS_DIS = "FALSE"           ,//TRUE, FALSE; for sigdet_status is 0 to reset cdr                             
    parameter    integer    PMA_CH2_REG_CDR_SAT_DET_TIMER = 2                     ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_CDR_SAT_DET_STATUS_VAL = "FALSE"          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_SAT_DET_STATUS_OW = "FALSE"           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_CDR_TURBO_MODE_EN = "TRUE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_RESERVED_190 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_RESERVED_193_191 = 0                   ,//0 to 7                                                                       
    parameter               PMA_CH2_REG_CDR_STATUS_FIFO_EN = "TRUE"               ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_PMA_TEST_SEL = 0                          ,//0,1                                                                          
    parameter    integer    PMA_CH2_REG_OOB_COMWAKE_GAP_MIN = 3                   ,//0 to 63                                                                      
    parameter    integer    PMA_CH2_REG_OOB_COMWAKE_GAP_MAX = 11                  ,//0 to 63                                                                      
    parameter    integer    PMA_CH2_REG_OOB_COMINIT_GAP_MIN = 15                  ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_REG_OOB_COMINIT_GAP_MAX = 35                  ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_REG_RX_RESERVED_227_226 = 1                   ,//0 to 3                                                                       
    parameter    integer    PMA_CH2_REG_COMWAKE_STATUS_CLEAR = 0                  ,//0,1                                                                          
    parameter    integer    PMA_CH2_REG_COMINIT_STATUS_CLEAR = 0                  ,//0,1                                                                          
    parameter               PMA_CH2_REG_RX_SYNC_RST_N_EN = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_SYNC_RST_N = "TRUE"                    ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_RESERVED_233_232 = 0                   ,//0 to 3                                                                       
    parameter    integer    PMA_CH2_REG_RX_RESERVED_235_234 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_RX_SATA_COMINIT_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_SATA_COMINIT = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_SATA_COMWAKE_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_SATA_COMWAKE = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_RESERVED_241_240 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_RX_DCC_DISABLE = "FALSE"                  ,//TRUE, FALSE; for rx dcc disable control                                      
    parameter               PMA_CH2_REG_RX_RESERVED_243 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_SLIP_SEL_EN = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_SLIP_SEL = 0                           ,//0 to 15                                                                      
    parameter               PMA_CH2_REG_RX_SLIP_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_SIGDET_STATUS_SEL = 5                  ,//0 to 7                                                                       
    parameter               PMA_CH2_REG_RX_SIGDET_FSM_RST_N = "TRUE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_RESERVED_254 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_SIGDET_STATUS = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_SIGDET_VTH = "72MV"                    ,//"45MV" "54MV" "63MV" "72MV"                       
    parameter    integer    PMA_CH2_REG_RX_SIGDET_GRM = 0                         ,//0,1,2,3                                                                      
    parameter               PMA_CH2_REG_RX_SIGDET_PULSE_EXT = "FALSE"             ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_SIGDET_CH2_SEL = 0                     ,//0,1                                                                          
    parameter    integer    PMA_CH2_REG_RX_SIGDET_CH2_CHK_WINDOW = 3              ,//0 to 31                                                                      
    parameter               PMA_CH2_REG_RX_SIGDET_CHK_WINDOW_EN = "TRUE"          ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_SIGDET_NOSIG_COUNT_SETTING = 4         ,//0 to 7                                                                       
    parameter               PMA_CH2_REG_SLIP_FIFO_INV_EN = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_SLIP_FIFO_INV = "POS_EDGE"                ,//"POS_EDGE" "NEG_EDGE"                                                        
    parameter    integer    PMA_CH2_REG_RX_SIGDET_OOB_DET_COUNT_VAL = 0           ,//0 to 31                                                                      
    parameter    integer    PMA_CH2_REG_RX_SIGDET_4OOB_DET_SEL = 7                ,//0 to 7                                                                       
    parameter    integer    PMA_CH2_REG_RX_RESERVED_285_283 = 0                   ,//0 to 7                                                                       
    parameter               PMA_CH2_REG_RX_RESERVED_286 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_SIGDET_IC_I = 10                       ,//0 to 15                                                                      
    parameter               PMA_CH2_REG_RX_OOB_DETECTOR_RESET_N_OW = "FALSE"      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_OOB_DETECTOR_RESET_N = "FALSE"         ,//TRUE, FALSE;for rx oob detector Reset                                        
    parameter               PMA_CH2_REG_RX_OOB_DETECTOR_PD_OW = "FALSE"           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_OOB_DETECTOR_PD = "ON"                 ,//TRUE, FALSE;for rx oob detector powerdown                                    
    parameter               PMA_CH2_REG_RX_LS_MODE_EN = "FALSE"                   ,//TRUE, FALSE;for Enable Low-speed mode                                        
    parameter               PMA_CH2_REG_ANA_RX_EQ1_R_SET_FB_O_SEL = "TRUE"        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_ANA_RX_EQ2_R_SET_FB_O_SEL = "TRUE"        ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_EQ1_R_SET_TOP = 0                      ,//0 to 3                                                                       
    parameter    integer    PMA_CH2_REG_RX_EQ1_R_SET_FB = 15                      ,//0 to 15                                                                      
    parameter    integer    PMA_CH2_REG_RX_EQ1_C_SET_FB = 0                       ,//0 to 15                                                                      
    parameter               PMA_CH2_REG_RX_EQ1_OFF = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_EQ2_R_SET_TOP = 0                      ,//0 to 3                                                                       
    parameter    integer    PMA_CH2_REG_RX_EQ2_R_SET_FB = 0                       ,//0 to 15                                                                      
    parameter    integer    PMA_CH2_REG_RX_EQ2_C_SET_FB = 0                       ,//0 to 15                                                                      
    parameter               PMA_CH2_REG_RX_EQ2_OFF = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_EQ_DAC = 0                                ,//0 to 63                                                                      
    parameter    integer    PMA_CH2_REG_RX_ICTRL_EQ = 2                           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_EQ_DC_CALIB_EN = "TRUE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_EQ_DC_CALIB_SEL = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_RESERVED_337_330 = 0                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_REG_RX_RESERVED_345_338 = 0                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_REG_RX_RESERVED_353_346 = 0                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_REG_RX_RESERVED_361_354 = 0                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_CTLE_CTRL_REG_I = 0                           ,//0 to 15                                                                      
    parameter               PMA_CH2_CTLE_REG_FORCE_SEL_I = "FALSE"                ,//TRUE, FALSE;for ctrl self-adaption adjust                                    
    parameter               PMA_CH2_CTLE_REG_HOLD_I = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_CTLE_REG_INIT_DAC_I = 0                       ,//0 to 15                                                                      
    parameter               PMA_CH2_CTLE_REG_POLARITY_I = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_CTLE_REG_SHIFTER_GAIN_I = 1                   ,//0 to 7                                                                       
    parameter    integer    PMA_CH2_CTLE_REG_THRESHOLD_I = 3072                   ,//0 to 4095                                                                    
    parameter               PMA_CH2_REG_RX_RES_TRIM_EN = "TRUE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_RESERVED_393_389 = 0                   ,//0 to 31                                                                      
    parameter               PMA_CH2_CFG_RX_LANE_POWERUP = "ON"                    ,//ON, OFF;for RX_LANE Power-up                                                 
    parameter               PMA_CH2_CFG_RX_PMA_RSTN = "TRUE"                      ,//TRUE, FALSE;for RX_PMA Reset                                                 
    parameter               PMA_CH2_INT_PMA_RX_MASK_0 = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_INT_PMA_RX_CLR_0 = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_CFG_CTLE_ADP_RSTN = "TRUE"                    ,//TRUE, FALSE;for ctrl Reset                                                   
    //pma_tx                                                                                                                                                 
    parameter               PMA_CH2_REG_TX_PD = "ON"                              ,//ON, OFF;for transmitter power down                                           
    parameter               PMA_CH2_REG_TX_PD_OW = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_MAIN_PRE_Z = "FALSE"                   ,//TRUE, FALSE;Enable EI for PCIE mode                                          
    parameter               PMA_CH2_REG_TX_MAIN_PRE_Z_OW = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_TX_BEACON_TIMER_SEL = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_TX_RXDET_REQ_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RXDET_REQ = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_BEACON_EN_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_BEACON_EN = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_EI_EN_OW = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_EI_EN = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_BIT_CONV = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_TX_RES_CAL = 48                           ,//0 to 63                                                                      
    parameter               PMA_CH2_REG_TX_RESERVED_19 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_TX_RESERVED_25_20 = 32                    ,//0 to 63                                                                      
    parameter    integer    PMA_CH2_REG_TX_RESERVED_33_26 = 0                     ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_REG_TX_RESERVED_41_34 = 0                     ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_REG_TX_RESERVED_49_42 = 0                     ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_REG_TX_RESERVED_57_50 = 0                     ,//0 to 255                                                                     
    parameter               PMA_CH2_REG_TX_SYNC_OW = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_SYNC = "FALSE"                         ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_PD_POST = "OFF"                        ,//ON, OFF;                                                                     
    parameter               PMA_CH2_REG_TX_PD_POST_OW = "TRUE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RESET_N_OW = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RESET_N = "TRUE"                       ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RESERVED_64 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RESERVED_65 = "TRUE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_BUSWIDTH_OW = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_BUSWIDTH = "20BIT"                     ,//"8BIT" "10BIT" "16BIT" "20BIT"                                               
    parameter               PMA_CH2_REG_PLL_READY_OW = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_PLL_READY = "TRUE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RESERVED_72 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RESERVED_73 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RESERVED_74 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_EI_PCLK_DELAY_SEL = 0                     ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_TX_RESERVED_77 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_TX_RESERVED_83_78 = 0                     ,//0 to 63                                                                      
    parameter    integer    PMA_CH2_REG_TX_RESERVED_89_84 = 0                     ,//0 to 63                                                                      
    parameter    integer    PMA_CH2_REG_TX_RESERVED_95_90 = 0                     ,//0 to 63                                                                      
    parameter    integer    PMA_CH2_REG_TX_RESERVED_101_96 = 0                    ,//0 to 63                                                                      
    parameter    integer    PMA_CH2_REG_TX_RESERVED_107_102 = 0                   ,//0 to 63                                                                      
    parameter    integer    PMA_CH2_REG_TX_RESERVED_113_108 = 0                   ,//0 to 63                                                                      
    parameter    integer    PMA_CH2_REG_TX_AMP_DAC0 = 25                          ,//0 to 63                                                                      
    parameter    integer    PMA_CH2_REG_TX_AMP_DAC1 = 19                          ,//0 to 63                                                                      
    parameter    integer    PMA_CH2_REG_TX_AMP_DAC2 = 14                          ,//0 to 63                                                                      
    parameter    integer    PMA_CH2_REG_TX_AMP_DAC3 = 9                           ,//0 to 63                                                                      
    parameter    integer    PMA_CH2_REG_TX_RESERVED_143_138 = 5                   ,//0 to 63                                                                      
    parameter    integer    PMA_CH2_REG_TX_MARGIN = 0                             ,//0 to 7                                                                       
    parameter               PMA_CH2_REG_TX_MARGIN_OW = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_TX_RESERVED_149_148 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_TX_RESERVED_150 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_SWING = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_SWING_OW = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RESERVED_153 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RXDET_THRESHOLD = "84MV"               ,//"28MV" "56MV" "84MV" "112MV"                                                 
    parameter    integer    PMA_CH2_REG_TX_RESERVED_157_156 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_TX_BEACON_OSC_CTRL = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_TX_RESERVED_160_159 = 0                   ,//0 to 3                                                                       
    parameter    integer    PMA_CH2_REG_TX_RESERVED_162_161 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_TX_TX2RX_SLPBACK_EN = "FALSE"             ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_PCLK_EDGE_SEL = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RXDET_STATUS_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RXDET_STATUS = "TRUE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_PRBS_GEN_EN = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_PRBS_GEN_WIDTH_SEL = "20BIT"           ,//"8BIT" "10BIT" "16BIT" "20BIT"                                               
    parameter               PMA_CH2_REG_TX_PRBS_SEL = "PRBS7"                     ,//"PRBS7" "PRBS15" "PRBS23" "PRBS31"                                           
    parameter    integer    PMA_CH2_REG_TX_UDP_DATA_7_TO_0 = 5                    ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_REG_TX_UDP_DATA_15_TO_8 = 235                 ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_REG_TX_UDP_DATA_19_TO_16 = 3                  ,//0 to 15                                                                      
    parameter               PMA_CH2_REG_TX_RESERVED_192 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_TX_FIFO_WP_CTRL = 4                       ,//0 to 7                                                                       
    parameter               PMA_CH2_REG_TX_FIFO_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_TX_DATA_MUX_SEL = 0                       ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_TX_ERR_INSERT = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_TX_RESERVED_203_200 = 0                   ,//0 to15                                                                       
    parameter               PMA_CH2_REG_TX_RESERVED_204 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_SATA_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_TX_RESERVED_207_206 = 0                   ,//0 to3                                                                        
    parameter               PMA_CH2_REG_RATE_CHANGE_TXPCLK_ON_OW = "FALSE"        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RATE_CHANGE_TXPCLK_ON = "TRUE"            ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_TX_CFG_POST1 = 0                          ,//0 to 31                                                                      
    parameter    integer    PMA_CH2_REG_TX_CFG_POST2 = 0                          ,//0 to 31                                                                      
    parameter    integer    PMA_CH2_REG_TX_DEEMP = 0                              ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_TX_DEEMP_OW = "FALSE"                     ,//TRUE, FALSE;for TX DEEMP Control                                             
    parameter    integer    PMA_CH2_REG_TX_RESERVED_224_223 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_TX_RESERVED_225 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_TX_RESERVED_229_226 = 0                   ,//0 to 15                                                                      
    parameter    integer    PMA_CH2_REG_TX_OOB_DELAY_SEL = 0                      ,//0 to 15                                                                      
    parameter               PMA_CH2_REG_TX_POLARITY = "NORMAL"                    ,//"NORMAL" "REVERSE"                                                           
    parameter               PMA_CH2_REG_ANA_TX_JTAG_DATA_O_SEL = "FALSE"          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RESERVED_236 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_LS_MODE_EN = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_JTAG_MODE_EN_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_JTAG_MODE_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_JTAG_MODE_EN_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_JTAG_MODE_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_RX_JTAG_OE = "TRUE"                       ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_ACJTAG_VHYSTSEL = 0                    ,//0 to 7                                                                       
    parameter               PMA_CH2_REG_TX_RES_CAL_EN = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_RX_TERM_MODE_CTRL = 5                     ,//0 to 7; for rx terminatin Control                                            
    parameter    integer    PMA_CH2_REG_TX_RESERVED_251_250 = 0                   ,//0 to 7                                                                       
    parameter               PMA_CH2_REG_PLPBK_TXPCLK_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RESERVED_253 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RESERVED_254 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RESERVED_255 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RESERVED_256 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_RESERVED_257 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_TX_PH_SEL = 1                             ,//0 to 63                                                                      
    parameter    integer    PMA_CH2_REG_TX_CFG_PRE = 0                            ,//0 to 31                                                                      
    parameter    integer    PMA_CH2_REG_TX_CFG_MAIN = 0                           ,//0 to 63                                                                      
    parameter    integer    PMA_CH2_REG_CFG_POST = 0                              ,//0 to 31                                                                      
    parameter               PMA_CH2_REG_PD_MAIN = "TRUE"                          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_PD_PRE = "TRUE"                           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_LS_DATA = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_TX_DCC_BUF_SZ_SEL = 0                     ,//0 to 3                                                                       
    parameter    integer    PMA_CH2_REG_TX_DCC_CAL_CUR_TUNE = 0                   ,//0 to 63                                                                      
    parameter               PMA_CH2_REG_TX_DCC_CAL_EN = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_TX_DCC_CUR_SS = 0                         ,//0 to 3                                                                       
    parameter               PMA_CH2_REG_TX_DCC_FA_CTRL = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_DCC_RI_CTRL = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_ATB_SEL_2_TO_0 = 0                        ,//0 to 7                                                                       
    parameter    integer    PMA_CH2_REG_ATB_SEL_9_TO_3 = 0                        ,//0 to 127                                                                     
    parameter    integer    PMA_CH2_REG_TX_CFG_7_TO_0 = 0                         ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_REG_TX_CFG_15_TO_8 = 0                        ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_REG_TX_CFG_23_TO_16 = 0                       ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_REG_TX_CFG_31_TO_24 = 128                     ,//0 to 255                                                                     
    parameter               PMA_CH2_REG_TX_OOB_EI_EN = "FALSE"                    ,//TRUE, FALSE; Enable OOB EI for SATA mode                                     
    parameter               PMA_CH2_REG_TX_OOB_EI_EN_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_BEACON_EN_DELAYED = "FALSE"            ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_BEACON_EN_DELAYED_OW = "FALSE"         ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH2_REG_TX_JTAG_DATA = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH2_REG_TX_RXDET_TIMER_SEL = 87                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_REG_TX_CFG1_7_0 = 0                           ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_REG_TX_CFG1_15_8 = 0                          ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_REG_TX_CFG1_23_16 = 0                         ,//0 to 255                                                                     
    parameter    integer    PMA_CH2_REG_TX_CFG1_31_24 = 0                         ,//0 to 255                                                                     
    parameter               PMA_CH2_REG_CFG_LANE_POWERUP = "ON"                   ,//ON, OFF; for PMA_LANE powerup                                                
    parameter               PMA_CH2_REG_CFG_TX_LANE_POWERUP_CLKPATH = "TRUE"      ,//TRUE, FALSE; for Pma tx lane clkpath powerup                                 
    parameter               PMA_CH2_REG_CFG_TX_LANE_POWERUP_PISO = "TRUE"         ,//TRUE, FALSE; for Pma tx lane piso powerup                                    
    parameter               PMA_CH2_REG_CFG_TX_LANE_POWERUP_DRIVER = "TRUE"       ,//TRUE, FALSE; for Pma tx lane driver powerup                                  
    //--------CHANNEL3 parameter--------//
    parameter    integer    CH3_MUX_BIAS = 2                                      ,//0 to 7; don't support simulation                                             
    parameter    integer    CH3_PD_CLK = 0                                        ,//0 to 1                                                                       
    parameter    integer    CH3_REG_SYNC = 0                                      ,//0 to 1                                                                       
    parameter    integer    CH3_REG_SYNC_OW = 0                                   ,//0 to 1                                                                       
    parameter    integer    CH3_PLL_LOCK_OW = 0                                   ,//0 to 1                                                                       
    parameter    integer    CH3_PLL_LOCK_OW_EN = 0                                ,//0 to 1                                                                       
    //pcs
    parameter    integer    PCS_CH3_SLAVE = 0                                     ,//Altered in 2019.12.05, should be configured by user, software only checks corresponding connection of clock
    parameter               PCS_CH3_BYPASS_WORD_ALIGN = "FALSE"                   ,//TRUE, FALSE; for bypass word alignment                                       
    parameter               PCS_CH3_BYPASS_DENC = "FALSE"                         ,//TRUE, FALSE; for bypass 8b/10b decoder                                       
    parameter               PCS_CH3_BYPASS_BONDING = "FALSE"                      ,//TRUE, FALSE; for bypass channel bonding                                      
    parameter               PCS_CH3_BYPASS_CTC = "FALSE"                          ,//TRUE, FALSE; for bypass ctc                                                  
    parameter               PCS_CH3_BYPASS_GEAR = "FALSE"                         ,//TRUE, FALSE; for bypass Rx Gear                                              
    parameter               PCS_CH3_BYPASS_BRIDGE = "FALSE"                       ,//TRUE, FALSE; for bypass Rx Bridge unit                                       
    parameter               PCS_CH3_BYPASS_BRIDGE_FIFO = "FALSE"                  ,//TRUE, FALSE; for bypass Rx Bridge FIFO                                       
    parameter               PCS_CH3_DATA_MODE = "X8"                              ,//"X8","X10","X16","X20"                                                       
    parameter               PCS_CH3_RX_POLARITY_INV = "DELAY"                     ,//"DELAY","BIT_POLARITY_INVERION","BIT_REVERSAL","BOTH"                        
    parameter               PCS_CH3_ALIGN_MODE = "1GB"                            ,//1GB, 10GB, RAPIDIO, OUTSIDE                                                  
    parameter               PCS_CH3_SAMP_16B = "X20"                              ,//"X20",X16                                                                    
    parameter               PCS_CH3_FARLP_PWR_REDUCTION = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PCS_CH3_COMMA_REG0 = 0                                ,//0 to 1023                                                                    
    parameter    integer    PCS_CH3_COMMA_MASK = 0                                ,//0 to 1023                                                                    
    parameter               PCS_CH3_CEB_MODE = "10GB"                             ,//"10GB" "RAPIDIO" "OUTSIDE"                                                   
    parameter               PCS_CH3_CTC_MODE = "1SKIP"                            ,//1SKIP, 2SKIP, PCIE_2BYTE, 4SKIP                                              
    parameter    integer    PCS_CH3_A_REG = 0                                     ,//0 to 255                                                                     
    parameter               PCS_CH3_GE_AUTO_EN = "FALSE"                          ,//TRUE, FALSE;                                                                 
    parameter    integer    PCS_CH3_SKIP_REG0 = 0                                 ,//0 to 1023                                                                    
    parameter    integer    PCS_CH3_SKIP_REG1 = 0                                 ,//0 to 1023                                                                    
    parameter    integer    PCS_CH3_SKIP_REG2 = 0                                 ,//0 to 1023                                                                    
    parameter    integer    PCS_CH3_SKIP_REG3 = 0                                 ,//0 to 1023                                                                    
    parameter               PCS_CH3_DEC_DUAL = "FALSE"                            ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_SPLIT = "FALSE"                               ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_FIFOFLAG_CTC = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_COMMA_DET_MODE = "COMMA_PATTERN"              ,//"RX_CLK_SLIP" "COMMA_PATTERN"                                                
    parameter               PCS_CH3_ERRDETECT_SILENCE = "TRUE"                    ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_PMA_RCLK_POLINV = "PMA_RCLK"                  ,//"PMA_RCLK" "REVERSE_OF_PMA_RCLK"                                             
    parameter               PCS_CH3_PCS_RCLK_SEL = "PMA_RCLK"                     ,//"PMA_RCLK" "PMA_TCLK" "RCLK"                                                 
    parameter               PCS_CH3_CB_RCLK_SEL = "PMA_RCLK"                      ,//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK"                                             
    parameter               PCS_CH3_AFTER_CTC_RCLK_SEL = "PMA_RCLK"               ,//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK" "RCLK2"                                     
    parameter               PCS_CH3_RCLK_POLINV = "RCLK"                          ,//"RCLK" "REVERSE_OF_RCLK"                                                     
    parameter               PCS_CH3_BRIDGE_RCLK_SEL = "PMA_RCLK"                  ,//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK" "RCLK"                                      
    parameter               PCS_CH3_PCS_RCLK_EN = "FALSE"                         ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_CB_RCLK_EN = "FALSE"                          ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_AFTER_CTC_RCLK_EN = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_AFTER_CTC_RCLK_EN_GB = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_PCS_RX_RSTN = "TRUE"                          ,//TRUE, FALSE; for PCS Receiver Reset                                          
    parameter               PCS_CH3_PCIE_SLAVE = "MASTER"                         ,//"MASTER","SLAVE"                                                             
    parameter               PCS_CH3_RX_64B66B_67B = "NORMAL"                      ,//"NORMAL" "64B_66B" "64B_67B"                                                 
    parameter               PCS_CH3_RX_BRIDGE_CLK_POLINV = "RX_BRIDGE_CLK"        ,//"RX_BRIDGE_CLK" "REVERSE_OF_RX_BRIDGE_CLK"                                   
    parameter               PCS_CH3_PCS_CB_RSTN = "TRUE"                         ,//TRUE, FALSE; for PCS CB Reset                                                
    parameter               PCS_CH3_TX_BRIDGE_GEAR_SEL = "FALSE"                  ,//TRUE: tx gear priority, FALSE:tx bridge unit priority                        
    parameter               PCS_CH3_TX_BYPASS_BRIDGE_UINT = "FALSE"               ,//TRUE, FALSE; for bypass                                                      
    parameter               PCS_CH3_TX_BYPASS_BRIDGE_FIFO = "FALSE"               ,//TRUE, FALSE; for bypass Tx Bridge FIFO                                       
    parameter               PCS_CH3_TX_BYPASS_GEAR = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_TX_BYPASS_ENC = "FALSE"                       ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_TX_BYPASS_BIT_SLIP = "TRUE"                   ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_TX_GEAR_SPLIT = "TRUE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_TX_DRIVE_REG_MODE = "NO_CHANGE"               ,//"NO_CHANGE" "EN_POLARIY_REV" "EN_BIT_REV" "EN_BOTH"                          
    parameter    integer    PCS_CH3_TX_BIT_SLIP_CYCLES = 0                        ,//o to 31                                                                      
    parameter               PCS_CH3_INT_TX_MASK_0 = "FALSE"                       ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_INT_TX_MASK_1 = "FALSE"                       ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_INT_TX_MASK_2 = "FALSE"                       ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_INT_TX_CLR_0 = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_INT_TX_CLR_1 = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_INT_TX_CLR_2 = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_TX_PMA_TCLK_POLINV = "PMA_TCLK"               ,//"PMA_TCLK" "REVERSE_OF_PMA_TCLK"                                             
    parameter               PCS_CH3_TX_PCS_CLK_EN_SEL = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_TX_BRIDGE_TCLK_SEL = "TCLK"                   ,//"PCS_TCLK" "TCLK"                                                            
    parameter               PCS_CH3_TX_TCLK_POLINV = "TCLK"                       ,//"TCLK" "REVERSE_OF_TCLK"                                                     
    parameter               PCS_CH3_PCS_TCLK_SEL= "PMA_TCLK"                      ,//"PMA_TCLK" "TCLK"                                                            
    parameter               PCS_CH3_TX_PCS_TX_RSTN = "TRUE"                       ,//TRUE, FALSE; for PCS Transmitter Reset                                       
    parameter               PCS_CH3_TX_SLAVE = "MASTER"                           ,//"MASTER" "SLAVE"                                                             
    parameter               PCS_CH3_TX_GEAR_CLK_EN_SEL = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PCS_CH3_DATA_WIDTH_MODE = "X20"                       ,//"X8" "X10" "X16" "X20"                                                       
    parameter               PCS_CH3_TX_64B66B_67B = "NORMAL"                      ,//"NORMAL" "64B_66B" "64B_67B"                                                 
    parameter               PCS_CH3_GEAR_TCLK_SEL = "PMA_TCLK"                    ,//"PMA_TCLK" "TCLK2"                                                           
    parameter               PCS_CH3_TX_TCLK2FABRIC_SEL = "TRUE"                   ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_TX_OUTZZ = "FALSE"                            ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_ENC_DUAL = "FALSE"                            ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_TX_BITSLIP_DATA_MODE = "X10"                  ,//"X10" "X20"                                                                  
    parameter               PCS_CH3_TX_BRIDGE_CLK_POLINV = "TX_BRIDGE_CLK"        ,//"TX_BRIDGE_CLK" "REVERSE_OF_TX_BRIDGE_CLK"                                   
    parameter    integer    PCS_CH3_COMMA_REG1 = 0                                ,//0 to 1023                                                                    
    parameter    integer    PCS_CH3_RAPID_IMAX = 0                                ,//0 to 7                                                                       
    parameter    integer    PCS_CH3_RAPID_VMIN_1 = 0                              ,//0 to 255                                                                     
    parameter    integer    PCS_CH3_RAPID_VMIN_2 = 0                              ,//0 to 255                                                                     
    parameter               PCS_CH3_RX_PRBS_MODE = "DISABLE"                      ,//DISABLE PRBS_7 PRBS_15 PRBS_23 PRBS_31                                       
    parameter               PCS_CH3_RX_ERRCNT_CLR = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_PRBS_ERR_LPBK = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_TX_PRBS_MODE = "DISABLE"                      ,//DISABLE PRBS_7 PRBS_15 PRBS_23 PRBS_31 LONG_1 LONG_0 20UI D10_2 PCIE         
    parameter               PCS_CH3_TX_INSERT_ER = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_ENABLE_PRBS_GEN = "FALSE"                     ,//TRUE, FALSE                                                                  
    parameter    integer    PCS_CH3_DEFAULT_RADDR = 6                             ,//0 to 15                                                                      
    parameter    integer    PCS_CH3_MASTER_CHECK_OFFSET = 0                       ,//0 to 15                                                                      
    parameter    integer    PCS_CH3_DELAY_SET = 0                                 ,//0 to 15                                                                      
    parameter               PCS_CH3_SEACH_OFFSET = "20BIT"                        ,//"20BIT" 30BIT" "40BIT" "50BIT" "60BIT" "70BIT" "80BIT"                       
    parameter    integer    PCS_CH3_CEB_RAPIDLS_MMAX = 0                          ,//0 to 7                                                                       
    parameter    integer    PCS_CH3_CTC_AFULL = 20                                ,//0 to 31                                                                      
    parameter    integer    PCS_CH3_CTC_AEMPTY = 12                               ,//0 to 31                                                                      
    parameter    integer    PCS_CH3_CTC_CONTI_SKP_SET = 0                         ,//0 to 1                                                                       
    parameter               PCS_CH3_FAR_LOOP = "FALSE"                            ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_NEAR_LOOP = "FALSE"                           ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_PMA_TX2RX_PLOOP_EN = "FALSE"                  ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_PMA_TX2RX_SLOOP_EN = "FALSE"                  ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_PMA_RX2TX_PLOOP_EN = "FALSE"                  ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_INT_RX_MASK_0 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_INT_RX_MASK_1 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_INT_RX_MASK_2 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_INT_RX_MASK_3 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_INT_RX_MASK_4 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_INT_RX_MASK_5 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_INT_RX_MASK_6 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_INT_RX_MASK_7 = "FALSE"                       ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_INT_RX_CLR_0 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_INT_RX_CLR_1 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_INT_RX_CLR_2 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_INT_RX_CLR_3 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_INT_RX_CLR_4 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_INT_RX_CLR_5 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_INT_RX_CLR_6 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_INT_RX_CLR_7 = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_CA_RSTN_RX = "FALSE"                          ,//TRUE, FALSE; for Rx CLK Aligner Reset                                        
    parameter               PCS_CH3_CA_DYN_DLY_EN_RX = "FALSE"                    ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_CA_DYN_DLY_SEL_RX = "FALSE"                   ,//TRUE, FALSE                                                                  
    parameter    integer    PCS_CH3_CA_RX = 0                                     ,//0 to 255                                                                     
    parameter               PCS_CH3_CA_RSTN_TX = "FALSE"                          ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_CA_DYN_DLY_EN_TX = "FALSE"                    ,//TRUE, FALSE                                                                  
    parameter               PCS_CH3_CA_DYN_DLY_SEL_TX = "FALSE"                   ,//TRUE, FALSE                                                                  
    parameter    integer    PCS_CH3_CA_TX = 0                                     ,//0 to 255                                                                     
    parameter               PCS_CH3_RXPRBS_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH3_WDALIGN_PWR_REDUCTION = "NORMAL"              ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH3_RXDEC_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH3_RXCB_PWR_REDUCTION = "NORMAL"                 ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH3_RXCTC_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH3_RXGEAR_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH3_RXBRG_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH3_RXTEST_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH3_TXBRG_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH3_TXGEAR_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH3_TXENC_PWR_REDUCTION = "NORMAL"                ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH3_TXBSLP_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    parameter               PCS_CH3_TXPRBS_PWR_REDUCTION = "NORMAL"               ,//"NORMAL" "POWER_REDUCTION"                                                   
    //pma_rx                                                                                                                                                 
    parameter               PMA_CH3_REG_RX_PD = "ON"                              ,//ON, OFF;                                                                     
    parameter               PMA_CH3_REG_RX_PD_EN = "FALSE"                        ,//TRUE, FALSE                                                                  
    parameter               PMA_CH3_REG_RX_RESERVED_2 = "FALSE"                   ,//TRUE, FALSE                                                                  
    parameter               PMA_CH3_REG_RX_RESERVED_3 = "FALSE"                   ,//TRUE, FALSE                                                                  
    parameter               PMA_CH3_REG_RX_DATAPATH_PD = "ON"                     ,//ON, OFF;                                                                     
    parameter               PMA_CH3_REG_RX_DATAPATH_PD_EN = "FALSE"               ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_SIGDET_PD = "ON"                       ,//ON, OFF;                                                                     
    parameter               PMA_CH3_REG_RX_SIGDET_PD_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_DCC_RST_N = "TRUE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_DCC_RST_N_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_CDR_RST_N = "TRUE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_CDR_RST_N_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_SIGDET_RST_N = "TRUE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_SIGDET_RST_N_EN = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RXPCLK_SLIP = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RXPCLK_SLIP_OW = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_PCLKSWITCH_RST_N = "TRUE"              ,//TRUE, FALSE; for TX PMA Reset                                                
    parameter               PMA_CH3_REG_RX_PCLKSWITCH_RST_N_EN = "FALSE"          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_PCLKSWITCH = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_PCLKSWITCH_EN = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_HIGHZ = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_HIGHZ_EN = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_SIGDET_CLK_WINDOW = "FALSE"            ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_SIGDET_CLK_WINDOW_OW = "FALSE"         ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_PD_BIAS_RX = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_PD_BIAS_RX_OW = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_RESET_N = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_RESET_N_OW = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_RESERVED_29_28 = 0                     ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_RX_BUSWIDTH = "20BIT"                     ,//"8BIT" "10BIT" "16BIT" "20BIT"                                               
    parameter               PMA_CH3_REG_RX_BUSWIDTH_EN = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_RATE = "DIV1"                          ,//"DIV4" "DIV2" "DIV1" "MUL2"                                                  
    parameter               PMA_CH3_REG_RX_RESERVED_36 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_RATE_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_RES_TRIM = 46                          ,//0 to 63                                                                      
    parameter               PMA_CH3_REG_RX_RESERVED_44 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_RESERVED_45 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_SIGDET_STATUS_EN = "FALSE"             ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_RESERVED_48_47 = 0                     ,//0 to 3                                                                       
    parameter    integer    PMA_CH3_REG_RX_ICTRL_SIGDET = 5                       ,//0 to 15                                                                      
    parameter    integer    PMA_CH3_REG_CDR_READY_THD = 2734                      ,//0 to 4095                                                                    
    parameter               PMA_CH3_REG_RX_RESERVED_65 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_PCLK_EDGE_SEL = "POS_EDGE"             ,//"POS_EDGE" "NEG_EDGE"                                                        
    parameter    integer    PMA_CH3_REG_RX_PIBUF_IC = 1                           ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_RX_RESERVED_69 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_DCC_IC_RX = 1                          ,//0 to 3                                                                       
    parameter    integer    PMA_CH3_REG_CDR_READY_CHECK_CTRL = 0                  ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_RX_ICTRL_TRX = "100PCT"                   ,//"87_5PCT" "100PCT" "112_5PCT" "125PCT"                                       
    parameter    integer    PMA_CH3_REG_RX_RESERVED_77_76 = 0                     ,//0 to 3                                                                       
    parameter    integer    PMA_CH3_REG_RX_RESERVED_79_78 = 1                     ,//0 to 3                                                                       
    parameter    integer    PMA_CH3_REG_RX_RESERVED_81_80 = 1                     ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_RX_ICTRL_PIBUF = "100PCT"                 ,//"87_5PCT" "100PCT" "112_5PCT" "125PCT"                                       
    parameter               PMA_CH3_REG_RX_ICTRL_PI = "100PCT"                    ,//"87_5PCT" "100PCT" "112_5PCT" "125PCT"                                       
    parameter               PMA_CH3_REG_RX_ICTRL_DCC = "100PCT"                   ,//"87_5PCT" "100PCT" "112_5PCT" "125PCT"                                       
    parameter    integer    PMA_CH3_REG_RX_RESERVED_89_88 = 1                     ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_TX_RATE = "DIV1"                          ,//"DIV4" "DIV2" "DIV1" "MUL2"                                                  
    parameter               PMA_CH3_REG_RX_RESERVED_92 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RATE_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_TX2RX_PLPBK_RST_N = "TRUE"             ,//TRUE, FALSE; for tx2rx pma parallel loop back Reset                          
    parameter               PMA_CH3_REG_RX_TX2RX_PLPBK_RST_N_EN = "FALSE"         ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_TX2RX_PLPBK_EN = "FALSE"               ,//TRUE, FALSE; for tx2rx pma parallel loop back enable                         
    parameter               PMA_CH3_REG_TXCLK_SEL = "PLL"                         ,//"PLL" "RXCLK"                                                                
    parameter               PMA_CH3_REG_RX_DATA_POLARITY = "NORMAL"               ,//"NORMAL" "REVERSE"                                                           
    parameter               PMA_CH3_REG_RX_ERR_INSERT = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_UDP_CHK_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_PRBS_SEL = "PRBS7"                        ,//"PRBS7" "PRBS15" "PRBS23" "PRBS31"                                           
    parameter               PMA_CH3_REG_PRBS_CHK_EN = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_PRBS_CHK_WIDTH_SEL = "20BIT"              ,//"8BIT" "10BIT" "16BIT" "20BIT"                                               
    parameter               PMA_CH3_REG_BIST_CHK_PAT_SEL = "PRBS"                 ,//"PRBS" "CONSTANT"                                                            
    parameter               PMA_CH3_REG_LOAD_ERR_CNT = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CHK_COUNTER_EN = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_CDR_PROP_GAIN = 7                         ,//0 to 7                                                                       
    parameter    integer    PMA_CH3_REG_CDR_PROP_TURBO_GAIN = 5                   ,//0 to 7                                                                       
    parameter    integer    PMA_CH3_REG_CDR_INT_GAIN = 4                          ,//0 to 7                                                                       
    parameter    integer    PMA_CH3_REG_CDR_INT_TURBO_GAIN = 5                    ,//0 to 7                                                                       
    parameter    integer    PMA_CH3_REG_CDR_INT_SAT_MAX = 768                     ,//0 to 1023                                                                    
    parameter    integer    PMA_CH3_REG_CDR_INT_SAT_MIN = 255                     ,//0 to 1023                                                                    
    parameter               PMA_CH3_REG_CDR_INT_RST = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_INT_RST_OW = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_PROP_RST = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_PROP_RST_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_LOCK_RST = "FALSE"                    ,//TRUE, FALSE; for CDR LOCK Counter Reset                                      
    parameter               PMA_CH3_REG_CDR_LOCK_RST_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_CDR_RX_PI_FORCE_SEL = 0                   ,//0,1                                                                          
    parameter    integer    PMA_CH3_REG_CDR_RX_PI_FORCE_D = 0                     ,//0 to 255                                                                     
    parameter               PMA_CH3_REG_CDR_LOCK_TIMER = "1_2U"                   ,//"0_8U" "1_2U" "1_6U" "2_4U" 3_2U" "4_8U" "12_8U" "25_6U"                     
    parameter    integer    PMA_CH3_REG_CDR_TURBO_MODE_TIMER = 1                  ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_CDR_LOCK_VAL = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_LOCK_OW = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_INT_SAT_DET_EN = "TRUE"               ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_SAT_AUTO_DIS = "TRUE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_GAIN_AUTO = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_TURBO_GAIN_AUTO = "FALSE"             ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_RESERVED_171_167 = 0                   ,//0 to 31                                                                      
    parameter    integer    PMA_CH3_REG_RX_RESERVED_175_172 = 0                   ,//0 to 31                                                                      
    parameter               PMA_CH3_REG_CDR_SAT_DET_STATUS_EN = "FALSE"           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_SAT_DET_STATUS_RESET_EN = "FALSE"     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_PI_CTRL_RST = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_PI_CTRL_RST_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_SAT_DET_RST = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_SAT_DET_RST_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_SAT_DET_STICKY_RST = "FALSE"          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_SAT_DET_STICKY_RST_OW = "FALSE"       ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_SIGDET_STATUS_DIS = "FALSE"           ,//TRUE, FALSE; for sigdet_status is 0 to reset cdr                             
    parameter    integer    PMA_CH3_REG_CDR_SAT_DET_TIMER = 2                     ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_CDR_SAT_DET_STATUS_VAL = "FALSE"          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_SAT_DET_STATUS_OW = "FALSE"           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_CDR_TURBO_MODE_EN = "TRUE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_RESERVED_190 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_RESERVED_193_191 = 0                   ,//0 to 7                                                                       
    parameter               PMA_CH3_REG_CDR_STATUS_FIFO_EN = "TRUE"               ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_PMA_TEST_SEL = 0                          ,//0,1                                                                          
    parameter    integer    PMA_CH3_REG_OOB_COMWAKE_GAP_MIN = 3                   ,//0 to 63                                                                      
    parameter    integer    PMA_CH3_REG_OOB_COMWAKE_GAP_MAX = 11                  ,//0 to 63                                                                      
    parameter    integer    PMA_CH3_REG_OOB_COMINIT_GAP_MIN = 15                  ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_REG_OOB_COMINIT_GAP_MAX = 35                  ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_REG_RX_RESERVED_227_226 = 1                   ,//0 to 3                                                                       
    parameter    integer    PMA_CH3_REG_COMWAKE_STATUS_CLEAR = 0                  ,//0,1                                                                          
    parameter    integer    PMA_CH3_REG_COMINIT_STATUS_CLEAR = 0                  ,//0,1                                                                          
    parameter               PMA_CH3_REG_RX_SYNC_RST_N_EN = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_SYNC_RST_N = "TRUE"                    ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_RESERVED_233_232 = 0                   ,//0 to 3                                                                       
    parameter    integer    PMA_CH3_REG_RX_RESERVED_235_234 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_RX_SATA_COMINIT_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_SATA_COMINIT = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_SATA_COMWAKE_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_SATA_COMWAKE = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_RESERVED_241_240 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_RX_DCC_DISABLE = "FALSE"                  ,//TRUE, FALSE; for rx dcc disable control                                      
    parameter               PMA_CH3_REG_RX_RESERVED_243 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_SLIP_SEL_EN = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_SLIP_SEL = 0                           ,//0 to 15                                                                      
    parameter               PMA_CH3_REG_RX_SLIP_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_SIGDET_STATUS_SEL = 5                  ,//0 to 7                                                                       
    parameter               PMA_CH3_REG_RX_SIGDET_FSM_RST_N = "TRUE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_RESERVED_254 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_SIGDET_STATUS = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_SIGDET_VTH = "72MV"                    ,//"45MV" "54MV" "63MV" "72MV"                       
    parameter    integer    PMA_CH3_REG_RX_SIGDET_GRM = 0                         ,//0,1,2,3                                                                      
    parameter               PMA_CH3_REG_RX_SIGDET_PULSE_EXT = "FALSE"             ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_SIGDET_CH2_SEL = 0                     ,//0,1                                                                          
    parameter    integer    PMA_CH3_REG_RX_SIGDET_CH2_CHK_WINDOW = 3              ,//0 to 31                                                                      
    parameter               PMA_CH3_REG_RX_SIGDET_CHK_WINDOW_EN = "TRUE"          ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_SIGDET_NOSIG_COUNT_SETTING = 4         ,//0 to 7                                                                       
    parameter               PMA_CH3_REG_SLIP_FIFO_INV_EN = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_SLIP_FIFO_INV = "POS_EDGE"                ,//"POS_EDGE" "NEG_EDGE"                                                        
    parameter    integer    PMA_CH3_REG_RX_SIGDET_OOB_DET_COUNT_VAL = 0           ,//0 to 31                                                                      
    parameter    integer    PMA_CH3_REG_RX_SIGDET_4OOB_DET_SEL = 7                ,//0 to 7                                                                       
    parameter    integer    PMA_CH3_REG_RX_RESERVED_285_283 = 0                   ,//0 to 7                                                                       
    parameter               PMA_CH3_REG_RX_RESERVED_286 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_SIGDET_IC_I = 10                       ,//0 to 15                                                                      
    parameter               PMA_CH3_REG_RX_OOB_DETECTOR_RESET_N_OW = "FALSE"      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_OOB_DETECTOR_RESET_N = "FALSE"         ,//TRUE, FALSE;for rx oob detector Reset                                        
    parameter               PMA_CH3_REG_RX_OOB_DETECTOR_PD_OW = "FALSE"           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_OOB_DETECTOR_PD = "ON"                 ,//TRUE, FALSE;for rx oob detector powerdown                                    
    parameter               PMA_CH3_REG_RX_LS_MODE_EN = "FALSE"                   ,//TRUE, FALSE;for Enable Low-speed mode                                        
    parameter               PMA_CH3_REG_ANA_RX_EQ1_R_SET_FB_O_SEL = "TRUE"        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_ANA_RX_EQ2_R_SET_FB_O_SEL = "TRUE"        ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_EQ1_R_SET_TOP = 0                      ,//0 to 3                                                                       
    parameter    integer    PMA_CH3_REG_RX_EQ1_R_SET_FB = 15                      ,//0 to 15                                                                      
    parameter    integer    PMA_CH3_REG_RX_EQ1_C_SET_FB = 0                       ,//0 to 15                                                                      
    parameter               PMA_CH3_REG_RX_EQ1_OFF = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_EQ2_R_SET_TOP = 0                      ,//0 to 3                                                                       
    parameter    integer    PMA_CH3_REG_RX_EQ2_R_SET_FB = 0                       ,//0 to 15                                                                      
    parameter    integer    PMA_CH3_REG_RX_EQ2_C_SET_FB = 0                       ,//0 to 15                                                                      
    parameter               PMA_CH3_REG_RX_EQ2_OFF = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_EQ_DAC = 0                                ,//0 to 63                                                                      
    parameter    integer    PMA_CH3_REG_RX_ICTRL_EQ = 2                           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_EQ_DC_CALIB_EN = "TRUE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_EQ_DC_CALIB_SEL = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_RESERVED_337_330 = 0                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_REG_RX_RESERVED_345_338 = 0                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_REG_RX_RESERVED_353_346 = 0                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_REG_RX_RESERVED_361_354 = 0                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_CTLE_CTRL_REG_I = 0                           ,//0 to 15                                                                      
    parameter               PMA_CH3_CTLE_REG_FORCE_SEL_I = "FALSE"                ,//TRUE, FALSE;for ctrl self-adaption adjust                                    
    parameter               PMA_CH3_CTLE_REG_HOLD_I = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_CTLE_REG_INIT_DAC_I = 0                       ,//0 to 15                                                                      
    parameter               PMA_CH3_CTLE_REG_POLARITY_I = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_CTLE_REG_SHIFTER_GAIN_I = 1                   ,//0 to 7                                                                       
    parameter    integer    PMA_CH3_CTLE_REG_THRESHOLD_I = 3072                   ,//0 to 4095                                                                    
    parameter               PMA_CH3_REG_RX_RES_TRIM_EN = "TRUE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_RESERVED_393_389 = 0                   ,//0 to 31                                                                      
    parameter               PMA_CH3_CFG_RX_LANE_POWERUP = "ON"                    ,//ON, OFF;for RX_LANE Power-up                                                 
    parameter               PMA_CH3_CFG_RX_PMA_RSTN = "TRUE"                      ,//TRUE, FALSE;for RX_PMA Reset                                                 
    parameter               PMA_CH3_INT_PMA_RX_MASK_0 = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_INT_PMA_RX_CLR_0 = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_CFG_CTLE_ADP_RSTN = "TRUE"                    ,//TRUE, FALSE;for ctrl Reset                                                   
    //pma_tx                                                                                                                                                 
    parameter               PMA_CH3_REG_TX_PD = "ON"                              ,//ON, OFF;for transmitter power down                                           
    parameter               PMA_CH3_REG_TX_PD_OW = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_MAIN_PRE_Z = "FALSE"                   ,//TRUE, FALSE;Enable EI for PCIE mode                                          
    parameter               PMA_CH3_REG_TX_MAIN_PRE_Z_OW = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_TX_BEACON_TIMER_SEL = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_TX_RXDET_REQ_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RXDET_REQ = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_BEACON_EN_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_BEACON_EN = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_EI_EN_OW = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_EI_EN = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_BIT_CONV = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_TX_RES_CAL = 48                           ,//0 to 63                                                                      
    parameter               PMA_CH3_REG_TX_RESERVED_19 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_TX_RESERVED_25_20 = 32                    ,//0 to 63                                                                      
    parameter    integer    PMA_CH3_REG_TX_RESERVED_33_26 = 0                     ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_REG_TX_RESERVED_41_34 = 0                     ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_REG_TX_RESERVED_49_42 = 0                     ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_REG_TX_RESERVED_57_50 = 0                     ,//0 to 255                                                                     
    parameter               PMA_CH3_REG_TX_SYNC_OW = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_SYNC = "FALSE"                         ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_PD_POST = "OFF"                        ,//ON, OFF;                                                                     
    parameter               PMA_CH3_REG_TX_PD_POST_OW = "TRUE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RESET_N_OW = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RESET_N = "TRUE"                       ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RESERVED_64 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RESERVED_65 = "TRUE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_BUSWIDTH_OW = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_BUSWIDTH = "20BIT"                     ,//"8BIT" "10BIT" "16BIT" "20BIT"                                               
    parameter               PMA_CH3_REG_PLL_READY_OW = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_PLL_READY = "TRUE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RESERVED_72 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RESERVED_73 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RESERVED_74 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_EI_PCLK_DELAY_SEL = 0                     ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_TX_RESERVED_77 = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_TX_RESERVED_83_78 = 0                     ,//0 to 63                                                                      
    parameter    integer    PMA_CH3_REG_TX_RESERVED_89_84 = 0                     ,//0 to 63                                                                      
    parameter    integer    PMA_CH3_REG_TX_RESERVED_95_90 = 0                     ,//0 to 63                                                                      
    parameter    integer    PMA_CH3_REG_TX_RESERVED_101_96 = 0                    ,//0 to 63                                                                      
    parameter    integer    PMA_CH3_REG_TX_RESERVED_107_102 = 0                   ,//0 to 63                                                                      
    parameter    integer    PMA_CH3_REG_TX_RESERVED_113_108 = 0                   ,//0 to 63                                                                      
    parameter    integer    PMA_CH3_REG_TX_AMP_DAC0 = 25                          ,//0 to 63                                                                      
    parameter    integer    PMA_CH3_REG_TX_AMP_DAC1 = 19                          ,//0 to 63                                                                      
    parameter    integer    PMA_CH3_REG_TX_AMP_DAC2 = 14                          ,//0 to 63                                                                      
    parameter    integer    PMA_CH3_REG_TX_AMP_DAC3 = 9                           ,//0 to 63                                                                      
    parameter    integer    PMA_CH3_REG_TX_RESERVED_143_138 = 5                   ,//0 to 63                                                                      
    parameter    integer    PMA_CH3_REG_TX_MARGIN = 0                             ,//0 to 7                                                                       
    parameter               PMA_CH3_REG_TX_MARGIN_OW = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_TX_RESERVED_149_148 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_TX_RESERVED_150 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_SWING = "FALSE"                        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_SWING_OW = "FALSE"                     ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RESERVED_153 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RXDET_THRESHOLD = "84MV"               ,//"28MV" "56MV" "84MV" "112MV"                                                 
    parameter    integer    PMA_CH3_REG_TX_RESERVED_157_156 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_TX_BEACON_OSC_CTRL = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_TX_RESERVED_160_159 = 0                   ,//0 to 3                                                                       
    parameter    integer    PMA_CH3_REG_TX_RESERVED_162_161 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_TX_TX2RX_SLPBACK_EN = "FALSE"             ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_PCLK_EDGE_SEL = "FALSE"                ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RXDET_STATUS_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RXDET_STATUS = "TRUE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_PRBS_GEN_EN = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_PRBS_GEN_WIDTH_SEL = "20BIT"           ,//"8BIT" "10BIT" "16BIT" "20BIT"                                               
    parameter               PMA_CH3_REG_TX_PRBS_SEL = "PRBS7"                     ,//"PRBS7" "PRBS15" "PRBS23" "PRBS31"                                           
    parameter    integer    PMA_CH3_REG_TX_UDP_DATA_7_TO_0 = 5                    ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_REG_TX_UDP_DATA_15_TO_8 = 235                 ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_REG_TX_UDP_DATA_19_TO_16 = 3                  ,//0 to 15                                                                      
    parameter               PMA_CH3_REG_TX_RESERVED_192 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_TX_FIFO_WP_CTRL = 4                       ,//0 to 7                                                                       
    parameter               PMA_CH3_REG_TX_FIFO_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_TX_DATA_MUX_SEL = 0                       ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_TX_ERR_INSERT = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_TX_RESERVED_203_200 = 0                   ,//0 to15                                                                       
    parameter               PMA_CH3_REG_TX_RESERVED_204 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_SATA_EN = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_TX_RESERVED_207_206 = 0                   ,//0 to3                                                                        
    parameter               PMA_CH3_REG_RATE_CHANGE_TXPCLK_ON_OW = "FALSE"        ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RATE_CHANGE_TXPCLK_ON = "TRUE"            ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_TX_CFG_POST1 = 0                          ,//0 to 31                                                                      
    parameter    integer    PMA_CH3_REG_TX_CFG_POST2 = 0                          ,//0 to 31                                                                      
    parameter    integer    PMA_CH3_REG_TX_DEEMP = 0                              ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_TX_DEEMP_OW = "FALSE"                     ,//TRUE, FALSE;for TX DEEMP Control                                             
    parameter    integer    PMA_CH3_REG_TX_RESERVED_224_223 = 0                   ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_TX_RESERVED_225 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_TX_RESERVED_229_226 = 0                   ,//0 to 15                                                                      
    parameter    integer    PMA_CH3_REG_TX_OOB_DELAY_SEL = 0                      ,//0 to 15                                                                      
    parameter               PMA_CH3_REG_TX_POLARITY = "NORMAL"                    ,//"NORMAL" "REVERSE"                                                           
    parameter               PMA_CH3_REG_ANA_TX_JTAG_DATA_O_SEL = "FALSE"          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RESERVED_236 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_LS_MODE_EN = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_JTAG_MODE_EN_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_JTAG_MODE_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_JTAG_MODE_EN_OW = "FALSE"              ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_JTAG_MODE_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_RX_JTAG_OE = "TRUE"                       ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_ACJTAG_VHYSTSEL = 0                    ,//0 to 7                                                                       
    parameter               PMA_CH3_REG_TX_RES_CAL_EN = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_RX_TERM_MODE_CTRL = 5                     ,//0 to 7; for rx terminatin Control                                            
    parameter    integer    PMA_CH3_REG_TX_RESERVED_251_250 = 0                   ,//0 to 7                                                                       
    parameter               PMA_CH3_REG_PLPBK_TXPCLK_EN = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RESERVED_253 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RESERVED_254 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RESERVED_255 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RESERVED_256 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_RESERVED_257 = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_TX_PH_SEL = 1                             ,//0 to 63                                                                      
    parameter    integer    PMA_CH3_REG_TX_CFG_PRE = 0                            ,//0 to 31                                                                      
    parameter    integer    PMA_CH3_REG_TX_CFG_MAIN = 0                           ,//0 to 63                                                                      
    parameter    integer    PMA_CH3_REG_CFG_POST = 0                              ,//0 to 31                                                                      
    parameter               PMA_CH3_REG_PD_MAIN = "TRUE"                          ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_PD_PRE = "TRUE"                           ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_LS_DATA = "FALSE"                      ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_TX_DCC_BUF_SZ_SEL = 0                     ,//0 to 3                                                                       
    parameter    integer    PMA_CH3_REG_TX_DCC_CAL_CUR_TUNE = 0                   ,//0 to 63                                                                      
    parameter               PMA_CH3_REG_TX_DCC_CAL_EN = "FALSE"                   ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_TX_DCC_CUR_SS = 0                         ,//0 to 3                                                                       
    parameter               PMA_CH3_REG_TX_DCC_FA_CTRL = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_DCC_RI_CTRL = "FALSE"                  ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_ATB_SEL_2_TO_0 = 0                        ,//0 to 7                                                                       
    parameter    integer    PMA_CH3_REG_ATB_SEL_9_TO_3 = 0                        ,//0 to 127                                                                     
    parameter    integer    PMA_CH3_REG_TX_CFG_7_TO_0 = 0                         ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_REG_TX_CFG_15_TO_8 = 0                        ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_REG_TX_CFG_23_TO_16 = 0                       ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_REG_TX_CFG_31_TO_24 = 128                     ,//0 to 255                                                                     
    parameter               PMA_CH3_REG_TX_OOB_EI_EN = "FALSE"                    ,//TRUE, FALSE; Enable OOB EI for SATA mode                                     
    parameter               PMA_CH3_REG_TX_OOB_EI_EN_OW = "FALSE"                 ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_BEACON_EN_DELAYED = "FALSE"            ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_BEACON_EN_DELAYED_OW = "FALSE"         ,//TRUE, FALSE;                                                                 
    parameter               PMA_CH3_REG_TX_JTAG_DATA = "FALSE"                    ,//TRUE, FALSE;                                                                 
    parameter    integer    PMA_CH3_REG_TX_RXDET_TIMER_SEL = 87                   ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_REG_TX_CFG1_7_0 = 0                           ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_REG_TX_CFG1_15_8 = 0                          ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_REG_TX_CFG1_23_16 = 0                         ,//0 to 255                                                                     
    parameter    integer    PMA_CH3_REG_TX_CFG1_31_24 = 0                         ,//0 to 255                                                                     
    parameter               PMA_CH3_REG_CFG_LANE_POWERUP = "ON"                   ,//ON, OFF; for PMA_LANE powerup                                                
    parameter               PMA_CH3_REG_CFG_TX_LANE_POWERUP_CLKPATH = "TRUE"      ,//TRUE, FALSE; for Pma tx lane clkpath powerup                                 
    parameter               PMA_CH3_REG_CFG_TX_LANE_POWERUP_PISO = "TRUE"         ,//TRUE, FALSE; for Pma tx lane piso powerup                                    
    parameter               PMA_CH3_REG_CFG_TX_LANE_POWERUP_DRIVER = "TRUE"        //TRUE, FALSE; for Pma tx lane driver powerup                                  
)(
    //--------fabric Port--------//
    input  wire             p_cfg_clk                                         ,//input               
    input  wire             p_cfg_rst                                         ,//input               
    input  wire             p_cfg_psel                                        ,//input               
    input  wire             p_cfg_enable                                      ,//input               
    input  wire             p_cfg_write                                       ,//input               
    input  wire [15:0]      p_cfg_addr                                        ,//input [15:0]        
    input  wire [7:0]       p_cfg_wdata                                       ,//input [7:0]     
    output wire             p_cfg_ready                                       ,//output              
    output wire [7:0]       p_cfg_rdata                                       ,//output [7:0]        
    output wire             p_cfg_int                                         ,//output     
    //--------PLL0 Port--------//
    output                  P_REFCK2CORE_0                                    ,//output      
    output                  P_PLL_READY_0                                     ,//output      
    input                   P_RESCAL_RST_I_0                                  ,//input              
    input                   P_PLL_REF_CLK_0                                   ,//input       
    input                   P_PLL_RST_0                                       ,//input       
    input                   P_PLLPOWERDOWN_0                                  ,//input       
    input                   P_LANE_SYNC_0                                     ,//input       
    input                   P_RATE_CHANGE_TCLK_ON_0                           ,//input       
    input                   REFCLK_CML_N_0                                    ,//input       
    input                   REFCLK_CML_P_0                                    ,//input       
    //--------PLL1 Port--------//
    output                  P_REFCK2CORE_1                                    ,//output      
    output                  P_PLL_READY_1                                     ,//output      
                                                                                             
    input                   P_RESCAL_RST_I_1                                  ,//input              
    input                   P_PLL_REF_CLK_1                                   ,//input       
    input                   P_PLL_RST_1                                       ,//input       
    input                   P_PLLPOWERDOWN_1                                  ,//input       
    input                   P_LANE_SYNC_1                                     ,//input       
    input                   P_RATE_CHANGE_TCLK_ON_1                           ,//input       
                                                                                             
    input                   REFCLK_CML_N_1                                    ,//input       
    input                   REFCLK_CML_P_1                                    ,//input       
    //--------CHANNEL0 Port--------//
    //PAD
    output                  P_TX_SDN_0                                          ,//output              
    output                  P_TX_SDP_0                                          ,//output              
    //SRB related                     
    output                  P_PCS_RX_MCB_STATUS_0                               ,//output              
    output                  P_PCS_LSM_SYNCED_0                                  ,//output              
    output [46:0]           P_RDATA_0                                           ,//output [46:0]       
    output                  P_RCLK2FABRIC_0                                     ,//output              
    output                  P_TCLK2FABRIC_0                                     ,//output              
    output                  P_RX_SIGDET_STATUS_0                                ,//output              
    output                  P_RX_SATA_COMINIT_0                                 ,//output              
    output                  P_RX_SATA_COMWAKE_0                                 ,//output              
    output                  P_RX_READY_0                                        ,//output              
    output                  P_TX_RXDET_STATUS_0                                 ,//output              
    //PAD                                             
    input                   P_RX_SDN_0                                          ,//input               
    input                   P_RX_SDP_0                                          ,//input               
    //SRB related                              
    input                   P_RX_CLK_FR_CORE_0                                  ,//input               
    input                   P_RCLK2_FR_CORE_0                                   ,//input               
    input                   P_TX_CLK_FR_CORE_0                                  ,//input               
    input                   P_TCLK2_FR_CORE_0                                   ,//input               
    input                   P_PCS_TX_RST_0                                      ,//input               
    input                   P_PCS_RX_RST_0                                      ,//input               
    input                   P_PCS_CB_RST_0                                      ,//input               
    input                   P_RXGEAR_SLIP_0                                     ,//input               
    input [45:0]            P_TDATA_0                                           ,//input [45:0]        
    input                   P_PCS_WORD_ALIGN_EN_0                               ,//input               
    input                   P_RX_POLARITY_INVERT_0                              ,//input               
    input                   P_PCS_MCB_EXT_EN_0                                  ,//input               
    input                   P_PCS_NEAREND_LOOP_0                                ,//input               
    input                   P_PCS_FAREND_LOOP_0                                 ,//input               
    input                   P_PMA_NEAREND_PLOOP_0                               ,//input               
    input                   P_PMA_NEAREND_SLOOP_0                               ,//input               
    input                   P_PMA_FAREND_PLOOP_0                                ,//input               
    input                   P_TX_BEACON_EN_0                                    ,//input               
    input                   P_LANE_PD_0                                         ,//input               
    input                   P_LANE_RST_0                                        ,//input               
    input                   P_RX_LANE_PD_0                                      ,//input               
    input                   P_RX_PMA_RST_0                                      ,//input               
    input [1:0]             P_TX_DEEMP_0                                        ,//input [1:0]         
    input                   P_TX_SWING_0                                        ,//input               
    input                   P_TX_RXDET_REQ_0                                    ,//input               
    input [2:0]             P_TX_RATE_0                                         ,//input [2:0]         
    input [2:0]             P_TX_MARGIN_0                                       ,//input [2:0]         
    input                   P_TX_PMA_RST_0                                      ,//input               
    input                   P_TX_LANE_PD_CLKPATH_0                              ,//input               
    input                   P_TX_LANE_PD_PISO_0                                 ,//input               
    input                   P_TX_LANE_PD_DRIVER_0                               ,//input               
    input [2:0]             P_RX_RATE_0                                         ,//input [2:0]         
    input                   P_RX_HIGHZ_0                                        ,//input               
    //--------CHANNEL1 Port--------//
    //PAD
    output                  P_TX_SDN_1                                          ,//output              
    output                  P_TX_SDP_1                                          ,//output              
    //SRB related                     
    output                  P_PCS_RX_MCB_STATUS_1                               ,//output              
    output                  P_PCS_LSM_SYNCED_1                                  ,//output              
    output [46:0]           P_RDATA_1                                           ,//output [46:0]       
    output                  P_RCLK2FABRIC_1                                     ,//output              
    output                  P_TCLK2FABRIC_1                                     ,//output              
    output                  P_RX_SIGDET_STATUS_1                                ,//output              
    output                  P_RX_SATA_COMINIT_1                                 ,//output              
    output                  P_RX_SATA_COMWAKE_1                                 ,//output              
    output                  P_RX_READY_1                                        ,//output              
    output                  P_TX_RXDET_STATUS_1                                 ,//output              
    //PAD                                             
    input                   P_RX_SDN_1                                          ,//input               
    input                   P_RX_SDP_1                                          ,//input               
    //SRB related                              
    input                   P_RX_CLK_FR_CORE_1                                  ,//input               
    input                   P_RCLK2_FR_CORE_1                                   ,//input               
    input                   P_TX_CLK_FR_CORE_1                                  ,//input               
    input                   P_TCLK2_FR_CORE_1                                   ,//input               
    input                   P_PCS_TX_RST_1                                      ,//input               
    input                   P_PCS_RX_RST_1                                      ,//input               
    input                   P_PCS_CB_RST_1                                      ,//input               
    input                   P_RXGEAR_SLIP_1                                     ,//input               
    input [45:0]            P_TDATA_1                                           ,//input [45:0]        
    input                   P_PCS_WORD_ALIGN_EN_1                               ,//input               
    input                   P_RX_POLARITY_INVERT_1                              ,//input               
    input                   P_PCS_MCB_EXT_EN_1                                  ,//input               
    input                   P_PCS_NEAREND_LOOP_1                                ,//input               
    input                   P_PCS_FAREND_LOOP_1                                 ,//input               
    input                   P_PMA_NEAREND_PLOOP_1                               ,//input               
    input                   P_PMA_NEAREND_SLOOP_1                               ,//input               
    input                   P_PMA_FAREND_PLOOP_1                                ,//input               
    input                   P_TX_BEACON_EN_1                                    ,//input               
    input                   P_LANE_PD_1                                         ,//input               
    input                   P_LANE_RST_1                                        ,//input               
    input                   P_RX_LANE_PD_1                                      ,//input               
    input                   P_RX_PMA_RST_1                                      ,//input               
    input [1:0]             P_TX_DEEMP_1                                        ,//input [1:0]         
    input                   P_TX_SWING_1                                        ,//input               
    input                   P_TX_RXDET_REQ_1                                    ,//input               
    input [2:0]             P_TX_RATE_1                                         ,//input [2:0]         
    input [2:0]             P_TX_MARGIN_1                                       ,//input [2:0]         
    input                   P_TX_PMA_RST_1                                      ,//input               
    input                   P_TX_LANE_PD_CLKPATH_1                              ,//input               
    input                   P_TX_LANE_PD_PISO_1                                 ,//input               
    input                   P_TX_LANE_PD_DRIVER_1                               ,//input               
    input [2:0]             P_RX_RATE_1                                         ,//input [2:0]         
    input                   P_RX_HIGHZ_1                                        ,//input               
    //--------CHANNEL2 Port--------//
    //PAD
    output                  P_TX_SDN_2                                          ,//output              
    output                  P_TX_SDP_2                                          ,//output              
    //SRB related                     
    output                  P_PCS_RX_MCB_STATUS_2                               ,//output              
    output                  P_PCS_LSM_SYNCED_2                                  ,//output              
    output [46:0]           P_RDATA_2                                           ,//output [46:0]       
    output                  P_RCLK2FABRIC_2                                     ,//output              
    output                  P_TCLK2FABRIC_2                                     ,//output              
    output                  P_RX_SIGDET_STATUS_2                                ,//output              
    output                  P_RX_SATA_COMINIT_2                                 ,//output              
    output                  P_RX_SATA_COMWAKE_2                                 ,//output              
    output                  P_RX_READY_2                                        ,//output              
    output                  P_TX_RXDET_STATUS_2                                 ,//output              
    //PAD                                             
    input                   P_RX_SDN_2                                          ,//input               
    input                   P_RX_SDP_2                                          ,//input               
    //SRB related                              
    input                   P_RX_CLK_FR_CORE_2                                  ,//input               
    input                   P_RCLK2_FR_CORE_2                                   ,//input               
    input                   P_TX_CLK_FR_CORE_2                                  ,//input               
    input                   P_TCLK2_FR_CORE_2                                   ,//input               
    input                   P_PCS_TX_RST_2                                      ,//input               
    input                   P_PCS_RX_RST_2                                      ,//input               
    input                   P_PCS_CB_RST_2                                      ,//input               
    input                   P_RXGEAR_SLIP_2                                     ,//input               
    input [45:0]            P_TDATA_2                                           ,//input [45:0]        
    input                   P_PCS_WORD_ALIGN_EN_2                               ,//input               
    input                   P_RX_POLARITY_INVERT_2                              ,//input               
    input                   P_PCS_MCB_EXT_EN_2                                  ,//input               
    input                   P_PCS_NEAREND_LOOP_2                                ,//input               
    input                   P_PCS_FAREND_LOOP_2                                 ,//input               
    input                   P_PMA_NEAREND_PLOOP_2                               ,//input               
    input                   P_PMA_NEAREND_SLOOP_2                               ,//input               
    input                   P_PMA_FAREND_PLOOP_2                                ,//input               
    input                   P_TX_BEACON_EN_2                                    ,//input               
    input                   P_LANE_PD_2                                         ,//input               
    input                   P_LANE_RST_2                                        ,//input               
    input                   P_RX_LANE_PD_2                                      ,//input               
    input                   P_RX_PMA_RST_2                                      ,//input               
    input [1:0]             P_TX_DEEMP_2                                        ,//input [1:0]         
    input                   P_TX_SWING_2                                        ,//input               
    input                   P_TX_RXDET_REQ_2                                    ,//input               
    input [2:0]             P_TX_RATE_2                                         ,//input [2:0]         
    input [2:0]             P_TX_MARGIN_2                                       ,//input [2:0]         
    input                   P_TX_PMA_RST_2                                      ,//input               
    input                   P_TX_LANE_PD_CLKPATH_2                              ,//input               
    input                   P_TX_LANE_PD_PISO_2                                 ,//input               
    input                   P_TX_LANE_PD_DRIVER_2                               ,//input               
    input [2:0]             P_RX_RATE_2                                         ,//input [2:0]         
    input                   P_RX_HIGHZ_2                                        ,//input               
    //--------CHANNEL3 Port--------//
    //PAD
    output                  P_TX_SDN_3                                          ,//output              
    output                  P_TX_SDP_3                                          ,//output              
    //SRB related                     
    output                  P_PCS_RX_MCB_STATUS_3                               ,//output              
    output                  P_PCS_LSM_SYNCED_3                                  ,//output              
    output [46:0]           P_RDATA_3                                           ,//output [46:0]       
    output                  P_RCLK2FABRIC_3                                     ,//output              
    output                  P_TCLK2FABRIC_3                                     ,//output              
    output                  P_RX_SIGDET_STATUS_3                                ,//output              
    output                  P_RX_SATA_COMINIT_3                                 ,//output              
    output                  P_RX_SATA_COMWAKE_3                                 ,//output              
    output                  P_RX_READY_3                                        ,//output              
    output                  P_TX_RXDET_STATUS_3                                 ,//output              
    //PAD                                             
    input                   P_RX_SDN_3                                          ,//input               
    input                   P_RX_SDP_3                                          ,//input               
    //SRB related                              
    input                   P_RX_CLK_FR_CORE_3                                  ,//input               
    input                   P_RCLK2_FR_CORE_3                                   ,//input               
    input                   P_TX_CLK_FR_CORE_3                                  ,//input               
    input                   P_TCLK2_FR_CORE_3                                   ,//input               
    input                   P_PCS_TX_RST_3                                      ,//input               
    input                   P_PCS_RX_RST_3                                      ,//input               
    input                   P_PCS_CB_RST_3                                      ,//input               
    input                   P_RXGEAR_SLIP_3                                     ,//input               
    input [45:0]            P_TDATA_3                                           ,//input [45:0]        
    input                   P_PCS_WORD_ALIGN_EN_3                               ,//input               
    input                   P_RX_POLARITY_INVERT_3                              ,//input               
    input                   P_PCS_MCB_EXT_EN_3                                  ,//input               
    input                   P_PCS_NEAREND_LOOP_3                                ,//input               
    input                   P_PCS_FAREND_LOOP_3                                 ,//input               
    input                   P_PMA_NEAREND_PLOOP_3                               ,//input               
    input                   P_PMA_NEAREND_SLOOP_3                               ,//input               
    input                   P_PMA_FAREND_PLOOP_3                                ,//input               
    input                   P_TX_BEACON_EN_3                                    ,//input               
    input                   P_LANE_PD_3                                         ,//input               
    input                   P_LANE_RST_3                                        ,//input               
    input                   P_RX_LANE_PD_3                                      ,//input               
    input                   P_RX_PMA_RST_3                                      ,//input               
    input [1:0]             P_TX_DEEMP_3                                        ,//input [1:0]         
    input                   P_TX_SWING_3                                        ,//input               
    input                   P_TX_RXDET_REQ_3                                    ,//input               
    input [2:0]             P_TX_RATE_3                                         ,//input [2:0]         
    input [2:0]             P_TX_MARGIN_3                                       ,//input [2:0]         
    input                   P_TX_PMA_RST_3                                      ,//input               
    input                   P_TX_LANE_PD_CLKPATH_3                              ,//input               
    input                   P_TX_LANE_PD_PISO_3                                 ,//input               
    input                   P_TX_LANE_PD_DRIVER_3                               ,//input               
    input [2:0]             P_RX_RATE_3                                         ,//input [2:0]         
    input                   P_RX_HIGHZ_3                                         //input               
);

//wire define
wire  [5:0]            P_RESCAL_I_CODE_I_0      = 6'b101110                ;//input [5:0] 
wire                   P_PLL_LOCKDET_RST_I_0    = 1'b0                     ;//input
wire  [5:0]            P_RESCAL_I_CODE_O_0                                 ;//output [5:0]
wire                   PLL_CLK0_0                                          ;//output      
wire                   PLL_CLK90_0                                         ;//output      
wire                   PLL_CLK180_0                                        ;//output      
wire                   PLL_CLK270_0                                        ;//output      
wire                   SYNC_PLL_0                                          ;//output      
wire                   RATE_CHANGE_PLL_0                                   ;//output      
wire                   PLL_PD_O_0                                          ;//output      
wire                   PLL_RST_O_0                                         ;//output      
wire                   PMA_PLL_READY_O_0                                   ;//output      
wire                   PLL_REFCLK_LANE_L_0                                 ;//output      
wire                   TXPCLK_PLL_SELECTED_0                               ;//input       
wire                   P_CFG_READY_PLL_0                                   ;//output      
wire  [7:0]            P_CFG_RDATA_PLL_0                                   ;//output [7:0]
wire                   P_CFG_INT_PLL_0                                     ;//output      
wire                   P_CFG_RST_PLL_0                                     ;//input       
wire                   P_CFG_CLK_PLL_0                                     ;//input       
wire                   P_CFG_PSEL_PLL_0                                    ;//input       
wire                   P_CFG_ENABLE_PLL_0                                  ;//input       
wire                   P_CFG_WRITE_PLL_0                                   ;//input       
wire  [11:0]           P_CFG_ADDR_PLL_0                                    ;//input [11:0]
wire  [7:0]            P_CFG_WDATA_PLL_0                                   ;//input [7:0] 

wire  [5:0]            P_RESCAL_I_CODE_I_1      = 6'b101110                ;//input [5:0] 
wire                   P_PLL_LOCKDET_RST_I_1    = 1'b0                     ;//input
wire  [5:0]            P_RESCAL_I_CODE_O_1                                 ;//output [5:0]
wire                   PLL_CLK0_1                                          ;//output      
wire                   PLL_CLK90_1                                         ;//output      
wire                   PLL_CLK180_1                                        ;//output      
wire                   PLL_CLK270_1                                        ;//output      
wire                   SYNC_PLL_1                                          ;//output      
wire                   RATE_CHANGE_PLL_1                                   ;//output      
wire                   PLL_PD_O_1                                          ;//output      
wire                   PLL_RST_O_1                                         ;//output      
wire                   PMA_PLL_READY_O_1                                   ;//output      
wire                   PLL_REFCLK_LANE_L_1                                 ;//output      
wire                   TXPCLK_PLL_SELECTED_1                               ;//input       
wire                   P_CFG_READY_PLL_1                                   ;//output      
wire  [7:0]            P_CFG_RDATA_PLL_1                                   ;//output [7:0]
wire                   P_CFG_INT_PLL_1                                     ;//output      
wire                   P_CFG_RST_PLL_1                                     ;//input       
wire                   P_CFG_CLK_PLL_1                                     ;//input       
wire                   P_CFG_PSEL_PLL_1                                    ;//input       
wire                   P_CFG_ENABLE_PLL_1                                  ;//input       
wire                   P_CFG_WRITE_PLL_1                                   ;//input       
wire [11:0]            P_CFG_ADDR_PLL_1                                    ;//input [11:0]
wire [7:0]             P_CFG_WDATA_PLL_1                                   ;//input [7:0] 
    
wire                   TXPCLK_PLL_0                                        ;//output              
wire                   SYNC_0                                              ;//input               
wire                   RATE_CHANGE_0                                       ;//input               
wire                   PLL_LOCK_SEL_0                                      ;//input               
wire                   CLK_TXP_0                                           ;//input               
wire                   CLK_TXN_0                                           ;//input               
wire                   CLK_RX0_0                                           ;//input               
wire                   CLK_RX90_0                                          ;//input               
wire                   CLK_RX180_0                                         ;//input               
wire                   CLK_RX270_0                                         ;//input               
wire                   PLL_PD_I_0                                          ;//input               
wire                   PLL_RESET_I_0                                       ;//input               
wire                   PLL_REFCLK_I_0                                      ;//input               
wire [5:0]             PLL_RES_TRIM_I_0                                    ;//input [5:0]         
wire       	            PMA_RCLK_0                                          ;//output to be done          	    
wire                   MCB_RCLK_0                                          ;//input  to be done            
wire [18:0]            LANE_CIN_BUS_FORWARD_0                              ;//input [18:0]   to be done     
wire                   APATTERN_STATUS_CIN_0                               ;//input          to be done   
wire [18:0]            LANE_COUT_BUS_FORWARD_0                             ;//output [18:0]  to be done     
wire                   APATTERN_STATUS_COUT_0                              ;//output         to be done     
wire                   P_CFG_READY_0                                       ;//output              
wire  [7:0]            P_CFG_RDATA_0                                       ;//output [7:0]        
wire                   P_CFG_INT_0                                         ;//output              
wire                   P_CFG_CLK_0                                         ;//input               
wire                   P_CFG_RST_0                                         ;//input               
wire                   P_CFG_PSEL_0                                        ;//input               
wire                   P_CFG_ENABLE_0                                      ;//input               
wire                   P_CFG_WRITE_0                                       ;//input               
wire [11:0]            P_CFG_ADDR_0                                        ;//input [11:0]        
wire [7:0]             P_CFG_WDATA_0                                       ;//input [7:0]         
wire [19:0]            P_TEST_STATUS_0                                     ;//output [19:0]       
wire                   P_CA_ALIGN_RX_0                                     ;//output              
wire                   P_CA_ALIGN_TX_0                                     ;//output              
wire                   P_CEB_ADETECT_EN_0                            = 1'b1;//input               
wire                   P_CTLE_ADP_RST_0                              = 1'b0;//input               
wire                   P_TX_LS_DATA_0                                = 1'b0;//input               
wire [7:0]             P_CIM_CLK_ALIGNER_RX_0                        = 8'b0;//input [7:0]         
wire [7:0]             P_CIM_CLK_ALIGNER_TX_0                        = 8'b0;//input [7:0]         
wire                   P_CIM_DYN_DLY_SEL_RX_0                        = 1'b0;//input               
wire                   P_CIM_DYN_DLY_SEL_TX_0                        = 1'b0;//input               
wire                   P_CIM_START_ALIGN_RX_0                        = 1'b0;//input               
wire                   P_CIM_START_ALIGN_TX_0                        = 1'b0;//input              
wire                   P_RX_LS_DATA_0                                      ;//output
wire [2:0]             P_TX_BUSWIDTH_0                               = 2'b0;//input [2:0]
wire [2:0]             P_RX_BUSWIDTH_0                               = 2'b0;//input [2:0]

wire                   TXPCLK_PLL_1                                        ;//output              
wire                   SYNC_1                                              ;//input               
wire                   RATE_CHANGE_1                                       ;//input               
wire                   PLL_LOCK_SEL_1                                      ;//input               
wire                   CLK_TXP_1                                           ;//input               
wire                   CLK_TXN_1                                           ;//input               
wire                   CLK_RX0_1                                           ;//input               
wire                   CLK_RX90_1                                          ;//input               
wire                   CLK_RX180_1                                         ;//input               
wire                   CLK_RX270_1                                         ;//input               
wire                   PLL_PD_I_1                                          ;//input               
wire                   PLL_RESET_I_1                                       ;//input               
wire                   PLL_REFCLK_I_1                                      ;//input               
wire [5:0]             PLL_RES_TRIM_I_1                                    ;//input [5:0]         
wire       	            PMA_RCLK_1                                          ;//output to be done          	    
wire                   MCB_RCLK_1                                          ;//input  to be done            
wire [18:0]            LANE_CIN_BUS_FORWARD_1                              ;//input [18:0]   to be done     
wire                   APATTERN_STATUS_CIN_1                               ;//input          to be done   
wire [18:0]            LANE_COUT_BUS_FORWARD_1                             ;//output [18:0]  to be done     
wire                   APATTERN_STATUS_COUT_1                              ;//output         to be done     
wire                   P_CFG_READY_1                                       ;//output              
wire  [7:0]            P_CFG_RDATA_1                                       ;//output [7:0]        
wire                   P_CFG_INT_1                                         ;//output              
wire                   P_CFG_CLK_1                                         ;//input               
wire                   P_CFG_RST_1                                         ;//input               
wire                   P_CFG_PSEL_1                                        ;//input               
wire                   P_CFG_ENABLE_1                                      ;//input               
wire                   P_CFG_WRITE_1                                       ;//input               
wire [11:0]            P_CFG_ADDR_1                                        ;//input [11:0]        
wire [7:0]             P_CFG_WDATA_1                                       ;//input [7:0]         
wire [19:0]            P_TEST_STATUS_1                                     ;//output [19:0]       
wire                   P_CA_ALIGN_RX_1                                     ;//output              
wire                   P_CA_ALIGN_TX_1                                     ;//output              
wire                   P_CEB_ADETECT_EN_1                            = 1'b1;//input               
wire                   P_CTLE_ADP_RST_1                              = 1'b0;//input               
wire                   P_TX_LS_DATA_1                                = 1'b0;//input               
wire [7:0]             P_CIM_CLK_ALIGNER_RX_1                        = 8'b0;//input [7:0]         
wire [7:0]             P_CIM_CLK_ALIGNER_TX_1                        = 8'b0;//input [7:0]         
wire                   P_CIM_DYN_DLY_SEL_RX_1                        = 1'b0;//input               
wire                   P_CIM_DYN_DLY_SEL_TX_1                        = 1'b0;//input               
wire                   P_CIM_START_ALIGN_RX_1                        = 1'b0;//input               
wire                   P_CIM_START_ALIGN_TX_1                        = 1'b0;//input               
wire                   P_RX_LS_DATA_1                                      ;//output
wire [2:0]             P_TX_BUSWIDTH_1                               = 3'b0;//input [2:0]         
wire [2:0]             P_RX_BUSWIDTH_1                               = 3'b0;//input [2:0]         

wire                   TXPCLK_PLL_2                                        ;//output              
wire                   SYNC_2                                              ;//input               
wire                   RATE_CHANGE_2                                       ;//input               
wire                   PLL_LOCK_SEL_2                                      ;//input               
wire                   CLK_TXP_2                                           ;//input               
wire                   CLK_TXN_2                                           ;//input               
wire                   CLK_RX0_2                                           ;//input               
wire                   CLK_RX90_2                                          ;//input               
wire                   CLK_RX180_2                                         ;//input               
wire                   CLK_RX270_2                                         ;//input               
wire                   PLL_PD_I_2                                          ;//input               
wire                   PLL_RESET_I_2                                       ;//input               
wire                   PLL_REFCLK_I_2                                      ;//input               
wire [5:0]             PLL_RES_TRIM_I_2                                    ;//input [5:0]         
wire       	           PMA_RCLK_2                                          ;//output to be done          	    
wire                   MCB_RCLK_2                                          ;//input  to be done            
wire [18:0]            LANE_CIN_BUS_FORWARD_2                              ;//input [18:0]   to be done     
wire                   APATTERN_STATUS_CIN_2                               ;//input          to be done   
wire [18:0]            LANE_COUT_BUS_FORWARD_2                             ;//output [18:0]  to be done     
wire                   APATTERN_STATUS_COUT_2                              ;//output         to be done     
wire                   P_CFG_READY_2                                       ;//output              
wire  [7:0]            P_CFG_RDATA_2                                       ;//output [7:0]        
wire                   P_CFG_INT_2                                         ;//output              
wire                   P_CFG_CLK_2                                         ;//input               
wire                   P_CFG_RST_2                                         ;//input               
wire                   P_CFG_PSEL_2                                        ;//input               
wire                   P_CFG_ENABLE_2                                      ;//input               
wire                   P_CFG_WRITE_2                                       ;//input               
wire [11:0]            P_CFG_ADDR_2                                        ;//input [11:0]        
wire [7:0]             P_CFG_WDATA_2                                       ;//input [7:0]         
wire [19:0]            P_TEST_STATUS_2                                     ;//output [19:0]       
wire                   P_CA_ALIGN_RX_2                                     ;//output              
wire                   P_CA_ALIGN_TX_2                                     ;//output              
wire                   P_CEB_ADETECT_EN_2                            = 1'b1;//input               
wire                   P_CTLE_ADP_RST_2                              = 1'b0;//input               
wire                   P_TX_LS_DATA_2                                = 1'b0;//input               
wire [7:0]             P_CIM_CLK_ALIGNER_RX_2                        = 8'b0;//input [7:0]         
wire [7:0]             P_CIM_CLK_ALIGNER_TX_2                        = 8'b0;//input [7:0]         
wire                   P_CIM_DYN_DLY_SEL_RX_2                        = 1'b0;//input               
wire                   P_CIM_DYN_DLY_SEL_TX_2                        = 1'b0;//input               
wire                   P_CIM_START_ALIGN_RX_2                        = 1'b0;//input               
wire                   P_CIM_START_ALIGN_TX_2                        = 1'b0;//input               
wire                   P_RX_LS_DATA_2                                      ;//output
wire [2:0]             P_TX_BUSWIDTH_2                               = 3'b0;//input [2:0]         
wire [2:0]             P_RX_BUSWIDTH_2                               = 3'b0;//input [2:0]         

wire                   TXPCLK_PLL_3                                        ;//output              
wire                   SYNC_3                                              ;//input               
wire                   RATE_CHANGE_3                                       ;//input               
wire                   PLL_LOCK_SEL_3                                      ;//input               
wire                   CLK_TXP_3                                           ;//input               
wire                   CLK_TXN_3                                           ;//input               
wire                   CLK_RX0_3                                           ;//input               
wire                   CLK_RX90_3                                          ;//input               
wire                   CLK_RX180_3                                         ;//input               
wire                   CLK_RX270_3                                         ;//input               
wire                   PLL_PD_I_3                                          ;//input               
wire                   PLL_RESET_I_3                                       ;//input               
wire                   PLL_REFCLK_I_3                                      ;//input               
wire [5:0]             PLL_RES_TRIM_I_3                                    ;//input [5:0]         
wire       	           PMA_RCLK_3                                          ;//output to be done          	    
wire                   MCB_RCLK_3                                          ;//input  to be done            
wire [18:0]            LANE_CIN_BUS_FORWARD_3                              ;//input [18:0]   to be done     
wire                   APATTERN_STATUS_CIN_3                         = 1'b1;//input          to be done   
wire [18:0]            LANE_COUT_BUS_FORWARD_3                             ;//output [18:0]  to be done     
wire                   APATTERN_STATUS_COUT_3                              ;//output         to be done     
wire                   P_CFG_READY_3                                       ;//output              
wire  [7:0]            P_CFG_RDATA_3                                       ;//output [7:0]        
wire                   P_CFG_INT_3                                         ;//output              
wire                   P_CFG_CLK_3                                         ;//input               
wire                   P_CFG_RST_3                                         ;//input               
wire                   P_CFG_PSEL_3                                        ;//input               
wire                   P_CFG_ENABLE_3                                      ;//input               
wire                   P_CFG_WRITE_3                                       ;//input               
wire [11:0]            P_CFG_ADDR_3                                        ;//input [11:0]        
wire [7:0]             P_CFG_WDATA_3                                       ;//input [7:0]         
wire [19:0]            P_TEST_STATUS_3                                     ;//output [19:0]       
wire                   P_CA_ALIGN_RX_3                                     ;//output              
wire                   P_CA_ALIGN_TX_3                                     ;//output              
wire                   P_CEB_ADETECT_EN_3                            = 1'b1;//input               
wire                   P_CTLE_ADP_RST_3                              = 1'b0;//input               
wire                   P_TX_LS_DATA_3                                = 1'b0;//input               
wire [7:0]             P_CIM_CLK_ALIGNER_RX_3                        = 8'b0;//input [7:0]         
wire [7:0]             P_CIM_CLK_ALIGNER_TX_3                        = 8'b0;//input [7:0]         
wire                   P_CIM_DYN_DLY_SEL_RX_3                        = 1'b0;//input               
wire                   P_CIM_DYN_DLY_SEL_TX_3                        = 1'b0;//input               
wire                   P_CIM_START_ALIGN_RX_3                        = 1'b0;//input               
wire                   P_CIM_START_ALIGN_TX_3                        = 1'b0;//input               
wire                   P_RX_LS_DATA_3                                      ;//output
wire [2:0]             P_TX_BUSWIDTH_3                               = 3'b0;//input [2:0]         
wire [2:0]             P_RX_BUSWIDTH_3                               = 3'b0;//input [2:0]         

//--------Channel Bonding Adapter Logic--------//
//Process MCB_RCLK 
assign MCB_RCLK_0 = PMA_RCLK_0;
assign MCB_RCLK_1 = (CH0_MULT_LANE_MODE==2 || CH0_MULT_LANE_MODE==4 ) ? PMA_RCLK_0 : PMA_RCLK_1;
assign MCB_RCLK_2 = (CH0_MULT_LANE_MODE==4 ) ? PMA_RCLK_0 : PMA_RCLK_2;
assign MCB_RCLK_3 = (CH0_MULT_LANE_MODE==4 ) ? PMA_RCLK_0 :  
                    (CH2_MULT_LANE_MODE==2 ) ? PMA_RCLK_2 : PMA_RCLK_3;

//Process CIN & COUT FOR channel bonding
generate
if(CH0_MULT_LANE_MODE==4) begin: LANE_0123_BONDING
    assign LANE_CIN_BUS_FORWARD_1 = LANE_COUT_BUS_FORWARD_0;//LANE0 >> LANE1
    assign LANE_CIN_BUS_FORWARD_2 = LANE_COUT_BUS_FORWARD_1;//LANE1 >> LANE2
    assign LANE_CIN_BUS_FORWARD_3 = LANE_COUT_BUS_FORWARD_2;//LANE2 >> LANE3
    assign APATTERN_STATUS_CIN_0  = APATTERN_STATUS_COUT_1 ;//LANE1 >> LANE0
    assign APATTERN_STATUS_CIN_1  = APATTERN_STATUS_COUT_2 ;//LANE2 >> LANE1
    assign APATTERN_STATUS_CIN_2  = APATTERN_STATUS_COUT_3 ;//LANE3 >> LANE2
end
else if(CH0_MULT_LANE_MODE==2 && CH2_MULT_LANE_MODE==2) begin:LANE_01_23_BONDING
    assign LANE_CIN_BUS_FORWARD_1 = LANE_COUT_BUS_FORWARD_0;//LANE0 >> LANE1
    assign LANE_CIN_BUS_FORWARD_3 = LANE_COUT_BUS_FORWARD_2;//LANE2 >> LANE3
    assign APATTERN_STATUS_CIN_0  = APATTERN_STATUS_COUT_1 ;//LANE1 >> LANE0
    assign APATTERN_STATUS_CIN_2  = APATTERN_STATUS_COUT_3 ;//LANE3 >> LANE2
end
else if(CH0_MULT_LANE_MODE==2 && CH2_MULT_LANE_MODE==1) begin:LANE_01_BONDING
    assign LANE_CIN_BUS_FORWARD_1 = LANE_COUT_BUS_FORWARD_0;//LANE0 >> LANE1
    assign APATTERN_STATUS_CIN_0  = APATTERN_STATUS_COUT_1 ;//LANE1 >> LANE0
end
else if(CH0_MULT_LANE_MODE==1 && CH2_MULT_LANE_MODE==2) begin:LANE_23_BONDING
    assign LANE_CIN_BUS_FORWARD_3 = LANE_COUT_BUS_FORWARD_2;//LANE2 >> LANE3
    assign APATTERN_STATUS_CIN_2  = APATTERN_STATUS_COUT_3 ;//LANE3 >> LANE2
end
endgenerate

//--------SIM Adapt Logic--------//

//--------TXPLL SELECTED---------//
assign TXPCLK_PLL_SELECTED_0     = PLL0_TXPCLK_PLL_SEL == 0 ? TXPCLK_PLL_0 :
                                   PLL0_TXPCLK_PLL_SEL == 1 ? TXPCLK_PLL_1 :
                                   PLL0_TXPCLK_PLL_SEL == 2 ? TXPCLK_PLL_2 : TXPCLK_PLL_3;
 
assign TXPCLK_PLL_SELECTED_1     = PLL1_TXPCLK_PLL_SEL == 0 ? TXPCLK_PLL_0 :
                                   PLL1_TXPCLK_PLL_SEL == 1 ? TXPCLK_PLL_1 :
                                   PLL1_TXPCLK_PLL_SEL == 2 ? TXPCLK_PLL_2 : TXPCLK_PLL_3;

//--------CHANNEL0 Selected--------//
assign    PLL_RES_TRIM_I_0        = P_RESCAL_I_CODE_O_0;//output [5:0]
assign    SYNC_0                  = (TX_CHANNEL0_PLL==0) ? SYNC_PLL_0          : SYNC_PLL_1          ;//output               
assign    RATE_CHANGE_0           = (TX_CHANNEL0_PLL==0) ? RATE_CHANGE_PLL_0   : RATE_CHANGE_PLL_1   ;//output               
assign    CLK_TXP_0               = (TX_CHANNEL0_PLL==0) ? PLL_CLK0_0          : PLL_CLK0_1          ;//output               
assign    CLK_TXN_0               = (TX_CHANNEL0_PLL==0) ? PLL_CLK180_0        : PLL_CLK180_1        ;//output               
assign    CLK_RX0_0               = (RX_CHANNEL0_PLL==0) ? PLL_CLK0_0          : PLL_CLK0_1          ;//output               
assign    CLK_RX90_0              = (RX_CHANNEL0_PLL==0) ? PLL_CLK90_0         : PLL_CLK90_1         ;//output               
assign    CLK_RX180_0             = (RX_CHANNEL0_PLL==0) ? PLL_CLK180_0        : PLL_CLK180_1        ;//output               
assign    CLK_RX270_0             = (RX_CHANNEL0_PLL==0) ? PLL_CLK270_0        : PLL_CLK270_1        ;//output               
assign    PLL_PD_I_0              = (RX_CHANNEL0_PLL==0) ? PLL_PD_O_0          : PLL_PD_O_1          ;//output               
assign    PLL_RESET_I_0           = (CH0_EN == "TX_only")? ((TX_CHANNEL0_PLL==0) ? PLL_RST_O_0   : PLL_RST_O_1  ) : 
                                                           ((RX_CHANNEL0_PLL==0) ? PLL_RST_O_0   : PLL_RST_O_1  ) ;//output               
assign    PLL_REFCLK_I_0          = (CH0_EN == "TX_only")? ((TX_CHANNEL0_PLL==0) ? PLL_REFCLK_LANE_L_0   : PLL_REFCLK_LANE_L_1  ) : 
                                                           ((RX_CHANNEL0_PLL==0) ? PLL_REFCLK_LANE_L_0   : PLL_REFCLK_LANE_L_1  ) ;//output               
assign    PLL_LOCK_SEL_0          = (CH0_EN == "TX_only")? ((TX_CHANNEL0_PLL==0) ? PMA_PLL_READY_O_0   : PMA_PLL_READY_O_1  ) : 
                                                           ((RX_CHANNEL0_PLL==0) ? PMA_PLL_READY_O_0   : PMA_PLL_READY_O_1  ) ;//output 
//--------CHANNEL1 Selected--------//
assign    PLL_RES_TRIM_I_1        = P_RESCAL_I_CODE_O_0;//output [5:0]
assign    SYNC_1                  = (TX_CHANNEL1_PLL==0) ? SYNC_PLL_0          : SYNC_PLL_1          ;//output               
assign    RATE_CHANGE_1           = (TX_CHANNEL1_PLL==0) ? RATE_CHANGE_PLL_0   : RATE_CHANGE_PLL_1   ;//output               
assign    CLK_TXP_1               = (TX_CHANNEL1_PLL==0) ? PLL_CLK0_0          : PLL_CLK0_1          ;//output               
assign    CLK_TXN_1               = (TX_CHANNEL1_PLL==0) ? PLL_CLK180_0        : PLL_CLK180_1        ;//output               
assign    CLK_RX0_1               = (RX_CHANNEL1_PLL==0) ? PLL_CLK0_0          : PLL_CLK0_1          ;//output               
assign    CLK_RX90_1              = (RX_CHANNEL1_PLL==0) ? PLL_CLK90_0         : PLL_CLK90_1         ;//output               
assign    CLK_RX180_1             = (RX_CHANNEL1_PLL==0) ? PLL_CLK180_0        : PLL_CLK180_1        ;//output               
assign    CLK_RX270_1             = (RX_CHANNEL1_PLL==0) ? PLL_CLK270_0        : PLL_CLK270_1        ;//output               
assign    PLL_PD_I_1              = (RX_CHANNEL1_PLL==0) ? PLL_PD_O_0          : PLL_PD_O_1          ;//output               
assign    PLL_RESET_I_1           = (CH1_EN == "TX_only")? ((TX_CHANNEL1_PLL==0) ? PLL_RST_O_0   : PLL_RST_O_1  ) : 
                                                           ((RX_CHANNEL1_PLL==0) ? PLL_RST_O_0   : PLL_RST_O_1  ) ;//output               
assign    PLL_REFCLK_I_1          = (CH1_EN == "TX_only")? ((TX_CHANNEL1_PLL==0) ? PLL_REFCLK_LANE_L_0   : PLL_REFCLK_LANE_L_1  ) : 
                                                           ((RX_CHANNEL1_PLL==0) ? PLL_REFCLK_LANE_L_0   : PLL_REFCLK_LANE_L_1  ) ;//output               
assign    PLL_LOCK_SEL_1          = (CH1_EN == "TX_only")? ((TX_CHANNEL1_PLL==0) ? PMA_PLL_READY_O_0   : PMA_PLL_READY_O_1  ) : 
                                                           ((RX_CHANNEL1_PLL==0) ? PMA_PLL_READY_O_0   : PMA_PLL_READY_O_1  ) ;//output 
//--------CHANNEL2 Selected--------//
assign    PLL_RES_TRIM_I_2        = P_RESCAL_I_CODE_O_0;//output [5:0]
assign    SYNC_2                  = (TX_CHANNEL2_PLL==0) ? SYNC_PLL_0          : SYNC_PLL_1          ;//output               
assign    RATE_CHANGE_2           = (TX_CHANNEL2_PLL==0) ? RATE_CHANGE_PLL_0   : RATE_CHANGE_PLL_1   ;//output               
assign    CLK_TXP_2               = (TX_CHANNEL2_PLL==0) ? PLL_CLK0_0          : PLL_CLK0_1          ;//output               
assign    CLK_TXN_2               = (TX_CHANNEL2_PLL==0) ? PLL_CLK180_0        : PLL_CLK180_1        ;//output               
assign    CLK_RX0_2               = (RX_CHANNEL2_PLL==0) ? PLL_CLK0_0          : PLL_CLK0_1          ;//output               
assign    CLK_RX90_2              = (RX_CHANNEL2_PLL==0) ? PLL_CLK90_0         : PLL_CLK90_1         ;//output               
assign    CLK_RX180_2             = (RX_CHANNEL2_PLL==0) ? PLL_CLK180_0        : PLL_CLK180_1        ;//output               
assign    CLK_RX270_2             = (RX_CHANNEL2_PLL==0) ? PLL_CLK270_0        : PLL_CLK270_1        ;//output               
assign    PLL_PD_I_2              = (RX_CHANNEL2_PLL==0) ? PLL_PD_O_0          : PLL_PD_O_1          ;//output               
assign    PLL_RESET_I_2           = (CH2_EN == "TX_only")? ((TX_CHANNEL2_PLL==0) ? PLL_RST_O_0   : PLL_RST_O_1  ) : 
                                                           ((RX_CHANNEL2_PLL==0) ? PLL_RST_O_0   : PLL_RST_O_1  ) ;//output               
assign    PLL_REFCLK_I_2          = (CH2_EN == "TX_only")? ((TX_CHANNEL2_PLL==0) ? PLL_REFCLK_LANE_L_0   : PLL_REFCLK_LANE_L_1  ) : 
                                                           ((RX_CHANNEL2_PLL==0) ? PLL_REFCLK_LANE_L_0   : PLL_REFCLK_LANE_L_1  ) ;//output               
assign    PLL_LOCK_SEL_2          = (CH2_EN == "TX_only")? ((TX_CHANNEL2_PLL==0) ? PMA_PLL_READY_O_0   : PMA_PLL_READY_O_1  ) : 
                                                           ((RX_CHANNEL2_PLL==0) ? PMA_PLL_READY_O_0   : PMA_PLL_READY_O_1  ) ;//output
//--------CHANNEL3 Selected--------//
assign    PLL_RES_TRIM_I_3        = P_RESCAL_I_CODE_O_0;//output [5:0]
assign    SYNC_3                  = (TX_CHANNEL3_PLL==0) ? SYNC_PLL_0          : SYNC_PLL_1          ;//output               
assign    RATE_CHANGE_3           = (TX_CHANNEL3_PLL==0) ? RATE_CHANGE_PLL_0   : RATE_CHANGE_PLL_1   ;//output               
assign    CLK_TXP_3               = (TX_CHANNEL3_PLL==0) ? PLL_CLK0_0          : PLL_CLK0_1          ;//output               
assign    CLK_TXN_3               = (TX_CHANNEL3_PLL==0) ? PLL_CLK180_0        : PLL_CLK180_1        ;//output               
assign    CLK_RX0_3               = (RX_CHANNEL3_PLL==0) ? PLL_CLK0_0          : PLL_CLK0_1          ;//output               
assign    CLK_RX90_3              = (RX_CHANNEL3_PLL==0) ? PLL_CLK90_0         : PLL_CLK90_1         ;//output               
assign    CLK_RX180_3             = (RX_CHANNEL3_PLL==0) ? PLL_CLK180_0        : PLL_CLK180_1        ;//output               
assign    CLK_RX270_3             = (RX_CHANNEL3_PLL==0) ? PLL_CLK270_0        : PLL_CLK270_1        ;//output               
assign    PLL_PD_I_3              = (RX_CHANNEL3_PLL==0) ? PLL_PD_O_0          : PLL_PD_O_1          ;//output               
assign    PLL_RESET_I_3           = (CH3_EN == "TX_only")? ((TX_CHANNEL3_PLL==0) ? PLL_RST_O_0   : PLL_RST_O_1  ) : 
                                                           ((RX_CHANNEL3_PLL==0) ? PLL_RST_O_0   : PLL_RST_O_1  ) ;//output               
assign    PLL_REFCLK_I_3          = (CH3_EN == "TX_only")? ((TX_CHANNEL3_PLL==0) ? PLL_REFCLK_LANE_L_0   : PLL_REFCLK_LANE_L_1  ) : 
                                                           ((RX_CHANNEL3_PLL==0) ? PLL_REFCLK_LANE_L_0   : PLL_REFCLK_LANE_L_1  ) ;//output               
assign    PLL_LOCK_SEL_3          = (CH3_EN == "TX_only")? ((TX_CHANNEL3_PLL==0) ? PMA_PLL_READY_O_0   : PMA_PLL_READY_O_1  ) : 
                                                           ((RX_CHANNEL3_PLL==0) ? PMA_PLL_READY_O_0   : PMA_PLL_READY_O_1  ) ;//output  

//--------APB bridge instance--------//
ipm2l_hsstlp_apb_bridge_v1_2#(
    .PLL0_EN                                (PLL0_EN                    ),//TRUE, FALSE; for PLL0 enable
    .PLL1_EN                                (PLL1_EN                    ),//TRUE, FALSE; for PLL1 enable
    .CHANNEL0_EN                            (CHANNEL0_EN                ),//TRUE, FALSE; for Channel0 enable
    .CHANNEL1_EN                            (CHANNEL1_EN                ),//TRUE, FALSE; for Channel1 enable
    .CHANNEL2_EN                            (CHANNEL2_EN                ),//TRUE, FALSE; for Channel2 enable
    .CHANNEL3_EN                            (CHANNEL3_EN                ) //TRUE, FALSE; for Channel3 enable
) U_APB_BRIDGE (
    //--------Fabric Port--------//
    .p_cfg_clk                              (p_cfg_clk                  ),//input               
    .p_cfg_rst                              (p_cfg_rst                  ),//input               
    .p_cfg_psel                             (p_cfg_psel                 ),//input               
    .p_cfg_enable                           (p_cfg_enable               ),//input               
    .p_cfg_write                            (p_cfg_write                ),//input               
    .p_cfg_addr                             (p_cfg_addr                 ),//input [15:0]        
    .p_cfg_wdata                            (p_cfg_wdata                ),//input [7:0]     
    .p_cfg_ready                            (p_cfg_ready                ),//output              
    .p_cfg_rdata                            (p_cfg_rdata                ),//output [7:0]        
    .p_cfg_int                              (p_cfg_int                  ),//output     
    //--------PLL0 Port--------//
    .P_CFG_READY_PLL_0                      (P_CFG_READY_PLL_0          ),//input      
    .P_CFG_RDATA_PLL_0                      (P_CFG_RDATA_PLL_0          ),//input [7:0]
    .P_CFG_INT_PLL_0                        (P_CFG_INT_PLL_0            ),//input   
    .P_CFG_RST_PLL_0                        (P_CFG_RST_PLL_0            ),//output       
    .P_CFG_CLK_PLL_0                        (P_CFG_CLK_PLL_0            ),//output       
    .P_CFG_PSEL_PLL_0                       (P_CFG_PSEL_PLL_0           ),//output       
    .P_CFG_ENABLE_PLL_0                     (P_CFG_ENABLE_PLL_0         ),//output       
    .P_CFG_WRITE_PLL_0                      (P_CFG_WRITE_PLL_0          ),//output       
    .P_CFG_ADDR_PLL_0                       (P_CFG_ADDR_PLL_0           ),//output [11:0]
    .P_CFG_WDATA_PLL_0                      (P_CFG_WDATA_PLL_0          ),//output [7:0] 
    //--------PLL1 Port--------//
    .P_CFG_READY_PLL_1                      (P_CFG_READY_PLL_1          ),//input      
    .P_CFG_RDATA_PLL_1                      (P_CFG_RDATA_PLL_1          ),//input [7:0]
    .P_CFG_INT_PLL_1                        (P_CFG_INT_PLL_1            ),//input   
    .P_CFG_RST_PLL_1                        (P_CFG_RST_PLL_1            ),//output       
    .P_CFG_CLK_PLL_1                        (P_CFG_CLK_PLL_1            ),//output       
    .P_CFG_PSEL_PLL_1                       (P_CFG_PSEL_PLL_1           ),//output       
    .P_CFG_ENABLE_PLL_1                     (P_CFG_ENABLE_PLL_1         ),//output       
    .P_CFG_WRITE_PLL_1                      (P_CFG_WRITE_PLL_1          ),//output       
    .P_CFG_ADDR_PLL_1                       (P_CFG_ADDR_PLL_1           ),//output [11:0]
    .P_CFG_WDATA_PLL_1                      (P_CFG_WDATA_PLL_1          ),//output [7:0] 
    //--------CHANNEL0 Port--------//
    .P_CFG_READY_0                          (P_CFG_READY_0              ),//input                    
    .P_CFG_RDATA_0                          (P_CFG_RDATA_0              ),//input [7:0]              
    .P_CFG_INT_0                            (P_CFG_INT_0                ),//input               
    .P_CFG_CLK_0                            (P_CFG_CLK_0                ),//output                   
    .P_CFG_RST_0                            (P_CFG_RST_0                ),//output                   
    .P_CFG_PSEL_0                           (P_CFG_PSEL_0               ),//output                   
    .P_CFG_ENABLE_0                         (P_CFG_ENABLE_0             ),//output                   
    .P_CFG_WRITE_0                          (P_CFG_WRITE_0              ),//output                   
    .P_CFG_ADDR_0                           (P_CFG_ADDR_0               ),//output [11:0]            
    .P_CFG_WDATA_0                          (P_CFG_WDATA_0              ),//output [7:0]         
    //--------CHANNEL1 Port--------//
    .P_CFG_READY_1                          (P_CFG_READY_1              ),//input                    
    .P_CFG_RDATA_1                          (P_CFG_RDATA_1              ),//input [7:0]              
    .P_CFG_INT_1                            (P_CFG_INT_1                ),//input               
    .P_CFG_CLK_1                            (P_CFG_CLK_1                ),//output                   
    .P_CFG_RST_1                            (P_CFG_RST_1                ),//output                   
    .P_CFG_PSEL_1                           (P_CFG_PSEL_1               ),//output                   
    .P_CFG_ENABLE_1                         (P_CFG_ENABLE_1             ),//output                   
    .P_CFG_WRITE_1                          (P_CFG_WRITE_1              ),//output                   
    .P_CFG_ADDR_1                           (P_CFG_ADDR_1               ),//output [11:0]            
    .P_CFG_WDATA_1                          (P_CFG_WDATA_1              ),//output [7:0]         
    //--------CHANNEL2 Port--------//
    .P_CFG_READY_2                          (P_CFG_READY_2              ),//input                    
    .P_CFG_RDATA_2                          (P_CFG_RDATA_2              ),//input [7:0]              
    .P_CFG_INT_2                            (P_CFG_INT_2                ),//input               
    .P_CFG_CLK_2                            (P_CFG_CLK_2                ),//output                   
    .P_CFG_RST_2                            (P_CFG_RST_2                ),//output                   
    .P_CFG_PSEL_2                           (P_CFG_PSEL_2               ),//output                   
    .P_CFG_ENABLE_2                         (P_CFG_ENABLE_2             ),//output                   
    .P_CFG_WRITE_2                          (P_CFG_WRITE_2              ),//output                   
    .P_CFG_ADDR_2                           (P_CFG_ADDR_2               ),//output [11:0]            
    .P_CFG_WDATA_2                          (P_CFG_WDATA_2              ),//output [7:0]         
    //--------CHANNEL3 Port--------//
    .P_CFG_READY_3                          (P_CFG_READY_3              ),//input                    
    .P_CFG_RDATA_3                          (P_CFG_RDATA_3              ),//input [7:0]              
    .P_CFG_INT_3                            (P_CFG_INT_3                ),//input               
    .P_CFG_CLK_3                            (P_CFG_CLK_3                ),//output                   
    .P_CFG_RST_3                            (P_CFG_RST_3                ),//output                   
    .P_CFG_PSEL_3                           (P_CFG_PSEL_3               ),//output                   
    .P_CFG_ENABLE_3                         (P_CFG_ENABLE_3             ),//output                   
    .P_CFG_WRITE_3                          (P_CFG_WRITE_3              ),//output                   
    .P_CFG_ADDR_3                           (P_CFG_ADDR_3               ),//output [11:0]            
    .P_CFG_WDATA_3                          (P_CFG_WDATA_3              ) //output [7:0]         
);

//--------PLL0 instance--------//
generate
if(PLL0_EN == "TRUE") begin:PLL0_ENABLE
GTP_HSSTLP_PLL#(
    .TX_SYNCK_PD                            (PMA_PLL0_TX_SYNCK_PD                  ),//0:txsync_cp powerup 1:txysnc_cp powerdown
    .PMA_PLL_REG_REFCLK_TERM_IMP_CTRL       (PMA_PLL0_REG_REFCLK_TERM_IMP_CTRL     ),//refclk termination impedance selection register,don't support simulation
                                                                                  
    .PMA_PLL_REG_BG_TRIM                    (PMA_PLL0_REG_BG_TRIM                  ),//v2i config, don't support simulation
    .PMA_PLL_REG_IBUP_A1                    (PMA_PLL0_REG_IBUP_A1                  ),//v2i config, don't support simulation
    .PMA_PLL_REG_IBUP_A2                    (PMA_PLL0_REG_IBUP_A2                  ),//v2i config, don't support simulation
    .PMA_PLL_REG_IBUP_PD                    (PMA_PLL0_REG_IBUP_PD                  ),//v2i config, don't support simulation
    .PMA_PLL_REG_V2I_BIAS_SEL               (PMA_PLL0_REG_V2I_BIAS_SEL             ),//v2i config, don't support simulation
    .PMA_PLL_REG_V2I_EN                     (PMA_PLL0_REG_V2I_EN                   ),//v2i config, don't support simulation
    .PMA_PLL_REG_V2I_TB_SEL                 (PMA_PLL0_REG_V2I_TB_SEL               ),//v2i config, don't support simulation
    .PMA_PLL_REG_V2I_RCALTEST_PD            (PMA_PLL0_REG_V2I_RCALTEST_PD          ),//v2i config, don't support simulation
    .PMA_PLL_REG_RES_CAL_TEST               (PMA_PLL0_REG_RES_CAL_TEST             ),//v2i config, don't support simulation
    .PMA_RES_CAL_DIV                        (PMA_PLL0_RES_CAL_DIV                  ),//v2i config, don't support simulation
    .PMA_RES_CAL_CLK_SEL                    (PMA_PLL0_RES_CAL_CLK_SEL              ),//v2i config, don't support simulation
                                                                                  
    .PMA_PLL_REG_PLL_PFDDELAY_EN            (PMA_PLL0_REG_PLL_PFDDELAY_EN          ),//TRUE, FALSE
    .PMA_PLL_REG_PFDDELAYSEL                (PMA_PLL0_REG_PFDDELAYSEL              ),//default :1                 
    .PMA_PLL_REG_PLL_VCTRL_SET              (PMA_PLL0_REG_PLL_VCTRL_SET            ),//default:0
    .PMA_PLL_REG_READY_OR_LOCK              (PMA_PLL0_REG_READY_OR_LOCK            ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_CP                     (PMA_PLL0_REG_PLL_CP                   ),//Min current :1, Max current:1023, Default: 31
    .PMA_PLL_REG_PLL_REFDIV                 (PMA_PLL0_REG_PLL_REFDIV               ),//Pll reference clock divider M, default: 16 
    .PMA_PLL_REG_PLL_LOCKDET_EN             (PMA_PLL0_REG_PLL_LOCKDET_EN           ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_READY                  (PMA_PLL0_REG_PLL_READY                ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_READY_OW               (PMA_PLL0_REG_PLL_READY_OW             ),//TRUE, FALSEt 
    .PMA_PLL_REG_PLL_FBDIV                  (PMA_PLL0_REG_PLL_FBDIV                ),//Pll feedback divider N2 is Pll_fbdiv<5> :Pll_fbdiv<5>=1 ---> N2=5,Pll_fbdiv<5>=0 ---> N2=4,
                                                                                     //Pll feedback divider N1 is Pll_fbdiv<4:0> :1,2,3,4,5,6,8,10
    .PMA_PLL_REG_LPF_RES                    (PMA_PLL0_REG_LPF_RES                  ),//LPF resistor control,Default: 1
    .PMA_PLL_REG_JTAG_OE                    (PMA_PLL0_REG_JTAG_OE                  ),//Pll jtag oe
    .PMA_PLL_REG_JTAG_VHYSTSEL              (PMA_PLL0_REG_JTAG_VHYSTSEL            ),//Pll jtag threshod voltage selection,default (0)
    .PMA_PLL_REG_PLL_LOCKDET_EN_OW          (PMA_PLL0_REG_PLL_LOCKDET_EN_OW        ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_LOCKDET_FBCT           (PMA_PLL0_REG_PLL_LOCKDET_FBCT         ),//0: 2^9,1: 2^10,2: 2^11,3: 2^12,4: 2^13,5: 2^14,6: 2^15,7: 2^16-1 (default)
    .PMA_PLL_REG_PLL_LOCKDET_ITER           (PMA_PLL0_REG_PLL_LOCKDET_ITER         ),//0: 1,1: 2,2: 4,3: 8(default),4: 16,5: 32,6: 64,7:127
    .PMA_PLL_REG_PLL_LOCKDET_MODE           (PMA_PLL0_REG_PLL_LOCKDET_MODE         ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_LOCKDET_LOCKCT         (PMA_PLL0_REG_PLL_LOCKDET_LOCKCT       ),///0: 2,1: 4,2: 8,3: 16,4: 32 (default),5: 64,6: 128,7: 256
    .PMA_PLL_REG_PLL_LOCKDET_REFCT          (PMA_PLL0_REG_PLL_LOCKDET_REFCT        ),//0: 2^9,1: 2^10,2: 2^11,3: 2^12,4: 2^13,5: 2^14,6: 2^15,7: 2^16-1 (default )
    .PMA_PLL_REG_PLL_LOCKDET_RESET_N        (PMA_PLL0_REG_PLL_LOCKDET_RESET_N      ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_LOCKDET_RESET_N_OW     (PMA_PLL0_REG_PLL_LOCKDET_RESET_N_OW   ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_LOCKED                 (PMA_PLL0_REG_PLL_LOCKED               ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_LOCKED_OW              (PMA_PLL0_REG_PLL_LOCKED_OW            ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_LOCKED_STICKY_CLEAR    (PMA_PLL0_REG_PLL_LOCKED_STICKY_CLEAR  ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_UNLOCKED               (PMA_PLL0_REG_PLL_UNLOCKED             ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_UNLOCKDET_ITER         (PMA_PLL0_REG_PLL_UNLOCKDET_ITER       ),//00: 63, 01: 127, 10: 255 (default),11: 1023
    .PMA_PLL_REG_PLL_UNLOCKED_OW            (PMA_PLL0_REG_PLL_UNLOCKED_OW          ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_UNLOCKED_STICKY_CLEAR  (PMA_PLL0_REG_PLL_UNLOCKED_STICKY_CLEAR),//TRUE, FALSE
    .PMA_PLL_REG_I_CTRL_MAX                 (PMA_PLL0_REG_I_CTRL_MAX               ),//0 to 63, Default :6b'111111
    .PMA_PLL_REG_REFCLK_TEST_EN             (PMA_PLL0_REG_REFCLK_TEST_EN           ),//TRUE, FALSE; for refclk port test 
    .PMA_PLL_REG_RESCAL_EN                  (PMA_PLL0_REG_RESCAL_EN                ),//TRUE, FALSE
    .PMA_PLL_REG_I_CTRL_MIN                 (PMA_PLL0_REG_I_CTRL_MIN               ),//0 to 63
    .PMA_PLL_REG_RESCAL_DONE_OW             (PMA_PLL0_REG_RESCAL_DONE_OW           ),//TRUE, FALSE
    .PMA_PLL_REG_RESCAL_DONE_VAL            (PMA_PLL0_REG_RESCAL_DONE_VAL          ),//TRUE, FALSE
    .PMA_PLL_REG_RESCAL_I_CODE              (PMA_PLL0_REG_RESCAL_I_CODE            ),//0 to 63
    .PMA_PLL_REG_RESCAL_I_CODE_OW           (PMA_PLL0_REG_RESCAL_I_CODE_OW         ),//TRUE, FALSE
    .PMA_PLL_REG_RESCAL_I_CODE_PMA          (PMA_PLL0_REG_RESCAL_I_CODE_PMA        ),//TRUE, FALSE
    .PMA_PLL_REG_RESCAL_I_CODE_VAL          (PMA_PLL0_REG_RESCAL_I_CODE_VAL        ),//0 to 63
    .PMA_PLL_REG_RESCAL_INT_R_SMALL_OW      (PMA_PLL0_REG_RESCAL_INT_R_SMALL_OW    ),//TRUE, FALSE
    .PMA_PLL_REG_RESCAL_INT_R_SMALL_VAL     (PMA_PLL0_REG_RESCAL_INT_R_SMALL_VAL   ),//TRUE, FALSE
    .PMA_PLL_REG_RESCAL_ITER_VALID_SEL      (PMA_PLL0_REG_RESCAL_ITER_VALID_SEL    ),//0,1,2,3
    .PMA_PLL_REG_RESCAL_RESET_N_OW          (PMA_PLL0_REG_RESCAL_RESET_N_OW        ),//TRUE, FALSE
    .PMA_PLL_REG_RESCAL_RST_N_VAL           (PMA_PLL0_REG_RESCAL_RST_N_VAL         ),//TRUE, FALSE
    .PMA_PLL_REG_RESCAL_WAIT_SEL            (PMA_PLL0_REG_RESCAL_WAIT_SEL          ),//TRUE, FALSE
    .PMA_PLL_REFCLK2LANE_PD_L               (PMA_PLL0_REFCLK2LANE_PD_L             ),//TRUE, FALSE; for pll_refclk_lane_l power down control
    .PMA_PLL_REFCLK2LANE_PD_R               (PMA_PLL0_REFCLK2LANE_PD_R             ),//TRUE, FALSE; for pll_refclk_lane_r power down control
    .PMA_PLL_REG_LOCKDET_REPEAT             (PMA_PLL0_REG_LOCKDET_REPEAT           ),//TRUE, FALSE
    .PMA_PLL_REG_NOFBCLK_STICKY_CLEAR       (PMA_PLL0_REG_NOFBCLK_STICKY_CLEAR     ),//TRUE, FALSE
    .PMA_PLL_REG_NOREFCLK_STICKY_CLEAR      (PMA_PLL0_REG_NOREFCLK_STICKY_CLEAR    ),//TRUE, FALSE
    .PMA_PLL_REG_TEST_SEL                   (PMA_PLL0_REG_TEST_SEL                 ),//0 to 20; for test
    .PMA_PLL_REG_TEST_V_EN                  (PMA_PLL0_REG_TEST_V_EN                ),//TRUE, FALSE;for test
    .PMA_PLL_REG_TEST_SIG_HALF_EN           (PMA_PLL0_REG_TEST_SIG_HALF_EN         ),//TRUE, FALSE;for test
    .PMA_PLL_REG_REFCLK_PAD_SEL             (PMA_PLL0_REG_REFCLK_PAD_SEL           ),//TRUE, FALSE;for reference clock selection
    .PARM_PLL_POWERUP                       (PMA_PLL0_PARM_PLL_POWERUP             ) //ON, OFF
) U_GTP_HSSTLP_PLL0 (
    //SRB related
    .P_CFG_READY_PLL                        (P_CFG_READY_PLL_0                      ),//output                  
    .P_CFG_RDATA_PLL                        (P_CFG_RDATA_PLL_0                      ),//output [7:0]            
    .P_CFG_INT_PLL                          (P_CFG_INT_PLL_0                        ),//output                  
    .P_RESCAL_I_CODE_O                      (P_RESCAL_I_CODE_O_0                    ),//output [5:0]            
    .P_REFCK2CORE                           (P_REFCK2CORE_0                         ),//output                  
    .P_PLL_READY                            (P_PLL_READY_0                          ),//output                  
    //CLK                                   
    .PLL_CLK0                               (PLL_CLK0_0                             ),//output                  
    .PLL_CLK90                              (PLL_CLK90_0                            ),//output                  
    .PLL_CLK180                             (PLL_CLK180_0                           ),//output                  
    .PLL_CLK270                             (PLL_CLK270_0                           ),//output                  
    .SYNC_PLL                               (SYNC_PLL_0                             ),//output                  
    .RATE_CHANGE_PLL                        (RATE_CHANGE_PLL_0                      ),//output                  
    .PLL_PD_O                               (PLL_PD_O_0                             ),//output                  
    .PLL_RST_O                              (PLL_RST_O_0                            ),//output                  
    .PMA_PLL_READY_O                        (PMA_PLL_READY_O_0                      ),//output                  
    .PLL_REFCLK_LANE_L                      (PLL_REFCLK_LANE_L_0                    ),//output                  
    //SRB related 
    .P_CFG_RST_PLL                          (P_CFG_RST_PLL_0                        ),//input                   
    .P_CFG_CLK_PLL                          (P_CFG_CLK_PLL_0                        ),//input                   
    .P_CFG_PSEL_PLL                         (P_CFG_PSEL_PLL_0                       ),//input                   
    .P_CFG_ENABLE_PLL                       (P_CFG_ENABLE_PLL_0                     ),//input                   
    .P_CFG_WRITE_PLL                        (P_CFG_WRITE_PLL_0                      ),//input                   
    .P_CFG_ADDR_PLL                         (P_CFG_ADDR_PLL_0                       ),//input [11:0]            
    .P_CFG_WDATA_PLL                        (P_CFG_WDATA_PLL_0                      ),//input [7:0]             
    .P_RESCAL_RST_I                         (P_RESCAL_RST_I_0                       ),//input                   
    .P_RESCAL_I_CODE_I                      (P_RESCAL_I_CODE_I_0                    ),//input [5:0]             
    .P_PLL_LOCKDET_RST_I                    (P_PLL_LOCKDET_RST_I_0                  ),//input                   
    .P_PLL_REF_CLK                          (P_PLL_REF_CLK_0                        ),//input                   
    .P_PLL_RST                              (P_PLL_RST_0                            ),//input                   
    .P_PLLPOWERDOWN                         (P_PLLPOWERDOWN_0                       ),//input                   
    .P_LANE_SYNC                            (P_LANE_SYNC_0                          ),//input                   
    .P_RATE_CHANGE_TCLK_ON                  (P_RATE_CHANGE_TCLK_ON_0                ),//input                   
    //PAD related
    .REFCLK_CML_N                           (REFCLK_CML_N_0                         ),//input                   
    .REFCLK_CML_P                           (REFCLK_CML_P_0                         ),//input                   
    .TXPCLK_PLL_SELECTED                    (TXPCLK_PLL_SELECTED_0                  ) //input                   
);
end
else begin:PLL0_NULL //output default value to be done
    assign    P_CFG_READY_PLL_0                      = 1'b0;//output                  
    assign    P_CFG_RDATA_PLL_0                      = 8'b0;//output [7:0]            
    assign    P_CFG_INT_PLL_0                        = 1'b0;//output                  
    assign    P_RESCAL_I_CODE_O_0                    = 6'b0;//output [5:0]            
    assign    P_REFCK2CORE_0                         = 1'b0;//output                  
    assign    P_PLL_READY_0                          = 1'b0;//output                  
    assign    PLL_CLK0_0                             = 1'b0;//output                  
    assign    PLL_CLK90_0                            = 1'b0;//output                  
    assign    PLL_CLK180_0                           = 1'b0;//output                  
    assign    PLL_CLK270_0                           = 1'b0;//output                  
    assign    SYNC_PLL_0                             = 1'b0;//output                  
    assign    RATE_CHANGE_PLL_0                      = 1'b0;//output                  
    assign    PLL_PD_O_0                             = 1'b0;//output                  
    assign    PLL_RST_O_0                            = 1'b0;//output                  
    assign    PMA_PLL_READY_O_0                      = 1'b0;//output                  
    assign    PLL_REFCLK_LANE_L_0                    = 1'b0;//output                  
end
endgenerate

//--------PLL1 instance--------//
generate
if(PLL1_EN == "TRUE") begin:PLL1_ENABLE
GTP_HSSTLP_PLL#(
    .TX_SYNCK_PD                            (PMA_PLL1_TX_SYNCK_PD                  ),//0:txsync_cp powerup 1:txysnc_cp powerdown
    .PMA_PLL_REG_REFCLK_TERM_IMP_CTRL       (PMA_PLL1_REG_REFCLK_TERM_IMP_CTRL     ),//refclk termination impedance selection register,don't support simulation
                                                                                  
    .PMA_PLL_REG_BG_TRIM                    (PMA_PLL1_REG_BG_TRIM                  ),//v2i config, don't support simulation
    .PMA_PLL_REG_IBUP_A1                    (PMA_PLL1_REG_IBUP_A1                  ),//v2i config, don't support simulation
    .PMA_PLL_REG_IBUP_A2                    (PMA_PLL1_REG_IBUP_A2                  ),//v2i config, don't support simulation
    .PMA_PLL_REG_IBUP_PD                    (PMA_PLL1_REG_IBUP_PD                  ),//v2i config, don't support simulation
    .PMA_PLL_REG_V2I_BIAS_SEL               (PMA_PLL1_REG_V2I_BIAS_SEL             ),//v2i config, don't support simulation
    .PMA_PLL_REG_V2I_EN                     (PMA_PLL1_REG_V2I_EN                   ),//v2i config, don't support simulation
    .PMA_PLL_REG_V2I_TB_SEL                 (PMA_PLL1_REG_V2I_TB_SEL               ),//v2i config, don't support simulation
    .PMA_PLL_REG_V2I_RCALTEST_PD            (PMA_PLL1_REG_V2I_RCALTEST_PD          ),//v2i config, don't support simulation
    .PMA_PLL_REG_RES_CAL_TEST               (PMA_PLL1_REG_RES_CAL_TEST             ),//v2i config, don't support simulation
    .PMA_RES_CAL_DIV                        (PMA_PLL1_RES_CAL_DIV                  ),//v2i config, don't support simulation
    .PMA_RES_CAL_CLK_SEL                    (PMA_PLL1_RES_CAL_CLK_SEL              ),//v2i config, don't support simulation
                                                                                  
    .PMA_PLL_REG_PLL_PFDDELAY_EN            (PMA_PLL1_REG_PLL_PFDDELAY_EN          ),//TRUE, FALSE
    .PMA_PLL_REG_PFDDELAYSEL                (PMA_PLL1_REG_PFDDELAYSEL              ),//default :1                 
    .PMA_PLL_REG_PLL_VCTRL_SET              (PMA_PLL1_REG_PLL_VCTRL_SET            ),//default:0
    .PMA_PLL_REG_READY_OR_LOCK              (PMA_PLL1_REG_READY_OR_LOCK            ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_CP                     (PMA_PLL1_REG_PLL_CP                   ),//Min current :1, Max current:1023, Default: 31
    .PMA_PLL_REG_PLL_REFDIV                 (PMA_PLL1_REG_PLL_REFDIV               ),//Pll reference clock divider M, default: 16 
    .PMA_PLL_REG_PLL_LOCKDET_EN             (PMA_PLL1_REG_PLL_LOCKDET_EN           ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_READY                  (PMA_PLL1_REG_PLL_READY                ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_READY_OW               (PMA_PLL1_REG_PLL_READY_OW             ),//TRUE, FALSEt 
    .PMA_PLL_REG_PLL_FBDIV                  (PMA_PLL1_REG_PLL_FBDIV                ),//Pll feedback divider N2 is Pll_fbdiv<5> :Pll_fbdiv<5>=1 ---> N2=5,Pll_fbdiv<5>=0 ---> N2=4,
                                                                                     //Pll feedback divider N1 is Pll_fbdiv<4:0> :1,2,3,4,5,6,8,10
    .PMA_PLL_REG_LPF_RES                    (PMA_PLL1_REG_LPF_RES                  ),//LPF resistor control,Default: 1
    .PMA_PLL_REG_JTAG_OE                    (PMA_PLL1_REG_JTAG_OE                  ),//Pll jtag oe
    .PMA_PLL_REG_JTAG_VHYSTSEL              (PMA_PLL1_REG_JTAG_VHYSTSEL            ),//Pll jtag threshod voltage selection,default (0)
    .PMA_PLL_REG_PLL_LOCKDET_EN_OW          (PMA_PLL1_REG_PLL_LOCKDET_EN_OW        ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_LOCKDET_FBCT           (PMA_PLL1_REG_PLL_LOCKDET_FBCT         ),//0: 2^9,1: 2^10,2: 2^11,3: 2^12,4: 2^13,5: 2^14,6: 2^15,7: 2^16-1 (default)
    .PMA_PLL_REG_PLL_LOCKDET_ITER           (PMA_PLL1_REG_PLL_LOCKDET_ITER         ),//0: 1,1: 2,2: 4,3: 8(default),4: 16,5: 32,6: 64,7:127
    .PMA_PLL_REG_PLL_LOCKDET_MODE           (PMA_PLL1_REG_PLL_LOCKDET_MODE         ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_LOCKDET_LOCKCT         (PMA_PLL1_REG_PLL_LOCKDET_LOCKCT       ),///0: 2,1: 4,2: 8,3: 16,4: 32 (default),5: 64,6: 128,7: 256
    .PMA_PLL_REG_PLL_LOCKDET_REFCT          (PMA_PLL1_REG_PLL_LOCKDET_REFCT        ),//0: 2^9,1: 2^10,2: 2^11,3: 2^12,4: 2^13,5: 2^14,6: 2^15,7: 2^16-1 (default )
    .PMA_PLL_REG_PLL_LOCKDET_RESET_N        (PMA_PLL1_REG_PLL_LOCKDET_RESET_N      ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_LOCKDET_RESET_N_OW     (PMA_PLL1_REG_PLL_LOCKDET_RESET_N_OW   ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_LOCKED                 (PMA_PLL1_REG_PLL_LOCKED               ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_LOCKED_OW              (PMA_PLL1_REG_PLL_LOCKED_OW            ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_LOCKED_STICKY_CLEAR    (PMA_PLL1_REG_PLL_LOCKED_STICKY_CLEAR  ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_UNLOCKED               (PMA_PLL1_REG_PLL_UNLOCKED             ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_UNLOCKDET_ITER         (PMA_PLL1_REG_PLL_UNLOCKDET_ITER       ),//00: 63, 01: 127, 10: 255 (default),11: 1023
    .PMA_PLL_REG_PLL_UNLOCKED_OW            (PMA_PLL1_REG_PLL_UNLOCKED_OW          ),//TRUE, FALSE
    .PMA_PLL_REG_PLL_UNLOCKED_STICKY_CLEAR  (PMA_PLL1_REG_PLL_UNLOCKED_STICKY_CLEAR),//TRUE, FALSE
    .PMA_PLL_REG_I_CTRL_MAX                 (PMA_PLL1_REG_I_CTRL_MAX               ),//0 to 63, Default :6b'111111
    .PMA_PLL_REG_REFCLK_TEST_EN             (PMA_PLL1_REG_REFCLK_TEST_EN           ),//TRUE, FALSE; for refclk port test 
    .PMA_PLL_REG_RESCAL_EN                  (PMA_PLL1_REG_RESCAL_EN                ),//TRUE, FALSE
    .PMA_PLL_REG_I_CTRL_MIN                 (PMA_PLL1_REG_I_CTRL_MIN               ),//0 to 63
    .PMA_PLL_REG_RESCAL_DONE_OW             (PMA_PLL1_REG_RESCAL_DONE_OW           ),//TRUE, FALSE
    .PMA_PLL_REG_RESCAL_DONE_VAL            (PMA_PLL1_REG_RESCAL_DONE_VAL          ),//TRUE, FALSE
    .PMA_PLL_REG_RESCAL_I_CODE              (PMA_PLL1_REG_RESCAL_I_CODE            ),//0 to 63
    .PMA_PLL_REG_RESCAL_I_CODE_OW           (PMA_PLL1_REG_RESCAL_I_CODE_OW         ),//TRUE, FALSE
    .PMA_PLL_REG_RESCAL_I_CODE_PMA          (PMA_PLL1_REG_RESCAL_I_CODE_PMA        ),//TRUE, FALSE
    .PMA_PLL_REG_RESCAL_I_CODE_VAL          (PMA_PLL1_REG_RESCAL_I_CODE_VAL        ),//0 to 63
    .PMA_PLL_REG_RESCAL_INT_R_SMALL_OW      (PMA_PLL1_REG_RESCAL_INT_R_SMALL_OW    ),//TRUE, FALSE
    .PMA_PLL_REG_RESCAL_INT_R_SMALL_VAL     (PMA_PLL1_REG_RESCAL_INT_R_SMALL_VAL   ),//TRUE, FALSE
    .PMA_PLL_REG_RESCAL_ITER_VALID_SEL      (PMA_PLL1_REG_RESCAL_ITER_VALID_SEL    ),//0,1,2,3
    .PMA_PLL_REG_RESCAL_RESET_N_OW          (PMA_PLL1_REG_RESCAL_RESET_N_OW        ),//TRUE, FALSE
    .PMA_PLL_REG_RESCAL_RST_N_VAL           (PMA_PLL1_REG_RESCAL_RST_N_VAL         ),//TRUE, FALSE
    .PMA_PLL_REG_RESCAL_WAIT_SEL            (PMA_PLL1_REG_RESCAL_WAIT_SEL          ),//TRUE, FALSE
    .PMA_PLL_REFCLK2LANE_PD_L               (PMA_PLL1_REFCLK2LANE_PD_L             ),//TRUE, FALSE; for pll_refclk_lane_l power down control
    .PMA_PLL_REFCLK2LANE_PD_R               (PMA_PLL1_REFCLK2LANE_PD_R             ),//TRUE, FALSE; for pll_refclk_lane_r power down control
    .PMA_PLL_REG_LOCKDET_REPEAT             (PMA_PLL1_REG_LOCKDET_REPEAT           ),//TRUE, FALSE
    .PMA_PLL_REG_NOFBCLK_STICKY_CLEAR       (PMA_PLL1_REG_NOFBCLK_STICKY_CLEAR     ),//TRUE, FALSE
    .PMA_PLL_REG_NOREFCLK_STICKY_CLEAR      (PMA_PLL1_REG_NOREFCLK_STICKY_CLEAR    ),//TRUE, FALSE
    .PMA_PLL_REG_TEST_SEL                   (PMA_PLL1_REG_TEST_SEL                 ),//0 to 20; for test
    .PMA_PLL_REG_TEST_V_EN                  (PMA_PLL1_REG_TEST_V_EN                ),//TRUE, FALSE;for test
    .PMA_PLL_REG_TEST_SIG_HALF_EN           (PMA_PLL1_REG_TEST_SIG_HALF_EN         ),//TRUE, FALSE;for test
    .PMA_PLL_REG_REFCLK_PAD_SEL             (PMA_PLL1_REG_REFCLK_PAD_SEL           ),//TRUE, FALSE;for reference clock selection
    .PARM_PLL_POWERUP                       (PMA_PLL1_PARM_PLL_POWERUP             ) //ON, OFF
) U_GTP_HSSTLP_PLL1 (
    //SRB related
    .P_CFG_READY_PLL                        (P_CFG_READY_PLL_1                      ),//output                  
    .P_CFG_RDATA_PLL                        (P_CFG_RDATA_PLL_1                      ),//output [7:0]            
    .P_CFG_INT_PLL                          (P_CFG_INT_PLL_1                        ),//output                  
    .P_RESCAL_I_CODE_O                      (P_RESCAL_I_CODE_O_1                    ),//output [5:0]            
    .P_REFCK2CORE                           (P_REFCK2CORE_1                         ),//output                  
    .P_PLL_READY                            (P_PLL_READY_1                          ),//output                  
    //CLK                                   
    .PLL_CLK0                               (PLL_CLK0_1                             ),//output                  
    .PLL_CLK90                              (PLL_CLK90_1                            ),//output                  
    .PLL_CLK180                             (PLL_CLK180_1                           ),//output                  
    .PLL_CLK270                             (PLL_CLK270_1                           ),//output                  
    .SYNC_PLL                               (SYNC_PLL_1                             ),//output                  
    .RATE_CHANGE_PLL                        (RATE_CHANGE_PLL_1                      ),//output                  
    .PLL_PD_O                               (PLL_PD_O_1                             ),//output                  
    .PLL_RST_O                              (PLL_RST_O_1                            ),//output                  
    .PMA_PLL_READY_O                        (PMA_PLL_READY_O_1                      ),//output                  
    .PLL_REFCLK_LANE_L                      (PLL_REFCLK_LANE_L_1                    ),//output                  
    //SRB related 
    .P_CFG_RST_PLL                          (P_CFG_RST_PLL_1                        ),//input                   
    .P_CFG_CLK_PLL                          (P_CFG_CLK_PLL_1                        ),//input                   
    .P_CFG_PSEL_PLL                         (P_CFG_PSEL_PLL_1                       ),//input                   
    .P_CFG_ENABLE_PLL                       (P_CFG_ENABLE_PLL_1                     ),//input                   
    .P_CFG_WRITE_PLL                        (P_CFG_WRITE_PLL_1                      ),//input                   
    .P_CFG_ADDR_PLL                         (P_CFG_ADDR_PLL_1                       ),//input [11:0]            
    .P_CFG_WDATA_PLL                        (P_CFG_WDATA_PLL_1                      ),//input [7:0]             
    .P_RESCAL_RST_I                         (P_RESCAL_RST_I_1                       ),//input                   
    .P_RESCAL_I_CODE_I                      (P_RESCAL_I_CODE_I_1                    ),//input [5:0]             
    .P_PLL_LOCKDET_RST_I                    (P_PLL_LOCKDET_RST_I_1                  ),//input                   
    .P_PLL_REF_CLK                          (P_PLL_REF_CLK_1                        ),//input                   
    .P_PLL_RST                              (P_PLL_RST_1                            ),//input                   
    .P_PLLPOWERDOWN                         (P_PLLPOWERDOWN_1                       ),//input                   
    .P_LANE_SYNC                            (P_LANE_SYNC_1                          ),//input                   
    .P_RATE_CHANGE_TCLK_ON                  (P_RATE_CHANGE_TCLK_ON_1                ),//input                   
    //PAD related
    .REFCLK_CML_N                           (REFCLK_CML_N_1                         ),//input                   
    .REFCLK_CML_P                           (REFCLK_CML_P_1                         ),//input                   
    .TXPCLK_PLL_SELECTED                    (TXPCLK_PLL_SELECTED_1                  ) //input                   
);
end
else begin:PLL1_NULL //output default value to be done
    assign    P_CFG_READY_PLL_1                      = 1'b0;//output                  
    assign    P_CFG_RDATA_PLL_1                      = 8'b0;//output [7:0]            
    assign    P_CFG_INT_PLL_1                        = 1'b0;//output                  
    assign    P_RESCAL_I_CODE_O_1                    = 6'b0;//output [5:0]            
    assign    P_REFCK2CORE_1                         = 1'b0;//output                  
    assign    P_PLL_READY_1                          = 1'b0;//output                  
    assign    PLL_CLK0_1                             = 1'b0;//output                  
    assign    PLL_CLK90_1                            = 1'b0;//output                  
    assign    PLL_CLK180_1                           = 1'b0;//output                  
    assign    PLL_CLK270_1                           = 1'b0;//output                  
    assign    SYNC_PLL_1                             = 1'b0;//output                  
    assign    RATE_CHANGE_PLL_1                      = 1'b0;//output                  
    assign    PLL_PD_O_1                             = 1'b0;//output                  
    assign    PLL_RST_O_1                            = 1'b0;//output                  
    assign    PMA_PLL_READY_O_1                      = 1'b0;//output                  
    assign    PLL_REFCLK_LANE_L_1                    = 1'b0;//output                  
end
endgenerate

//--------CHANNEL0 instance--------//
generate
if(CHANNEL0_EN == "TRUE") begin:CHANNEL0_ENABLE
GTP_HSSTLP_LANE#(
    .MUX_BIAS                                    (CH0_MUX_BIAS                                      ),//0 to 7; don't support simulation
    .PD_CLK                                      (CH0_PD_CLK                                        ),//0 to 1
    .REG_SYNC                                    (CH0_REG_SYNC                                      ),//0 to 1
    .REG_SYNC_OW                                 (CH0_REG_SYNC_OW                                   ),//0 to 1
    .PLL_LOCK_OW                                 (CH0_PLL_LOCK_OW                                   ),//0 to 1
    .PLL_LOCK_OW_EN                              (CH0_PLL_LOCK_OW_EN                                ),//0 to 1
    //pcs
    .PCS_SLAVE                                   (PCS_CH0_SLAVE                                     ),
    .PCS_BYPASS_WORD_ALIGN                       (PCS_CH0_BYPASS_WORD_ALIGN                         ),//TRUE, FALSE; for bypass word alignment
    .PCS_BYPASS_DENC                             (PCS_CH0_BYPASS_DENC                               ),//TRUE, FALSE; for bypass 8b/10b decoder
    .PCS_BYPASS_BONDING                          (PCS_CH0_BYPASS_BONDING                            ),//TRUE, FALSE; for bypass channel bonding
    .PCS_BYPASS_CTC                              (PCS_CH0_BYPASS_CTC                                ),//TRUE, FALSE; for bypass ctc
    .PCS_BYPASS_GEAR                             (PCS_CH0_BYPASS_GEAR                               ),//TRUE, FALSE; for bypass Rx Gear
    .PCS_BYPASS_BRIDGE                           (PCS_CH0_BYPASS_BRIDGE                             ),//TRUE, FALSE; for bypass Rx Bridge unit
    .PCS_BYPASS_BRIDGE_FIFO                      (PCS_CH0_BYPASS_BRIDGE_FIFO                        ),//TRUE, FALSE; for bypass Rx Bridge FIFO
    .PCS_DATA_MODE                               (PCS_CH0_DATA_MODE                                 ),//"X8","X10","X16","X20"
    .PCS_RX_POLARITY_INV                         (PCS_CH0_RX_POLARITY_INV                           ),//"DELAY","BIT_POLARITY_INVERION","BIT_REVERSAL","BOTH"
    .PCS_ALIGN_MODE                              (PCS_CH0_ALIGN_MODE                                ),//1GB, 10GB, RAPIDIO, OUTSIDE
    .PCS_SAMP_16B                                (PCS_CH0_SAMP_16B                                  ),//"X20",X16
    .PCS_FARLP_PWR_REDUCTION                     (PCS_CH0_FARLP_PWR_REDUCTION                       ),//TRUE, FALSE;
    .PCS_COMMA_REG0                              (PCS_CH0_COMMA_REG0                                ),//0 to 1023
    .PCS_COMMA_MASK                              (PCS_CH0_COMMA_MASK                                ),//0 to 1023
    .PCS_CEB_MODE                                (PCS_CH0_CEB_MODE                                  ),//"10GB" "RAPIDIO" "OUTSIDE"
    .PCS_CTC_MODE                                (PCS_CH0_CTC_MODE                                  ),//1SKIP, 2SKIP, PCIE_2BYTE, 4SKIP
    .PCS_A_REG                                   (PCS_CH0_A_REG                                     ),//0 to 255
    .PCS_GE_AUTO_EN                              (PCS_CH0_GE_AUTO_EN                                ),//TRUE, FALSE;
    .PCS_SKIP_REG0                               (PCS_CH0_SKIP_REG0                                 ),//0 to 1023
    .PCS_SKIP_REG1                               (PCS_CH0_SKIP_REG1                                 ),//0 to 1023
    .PCS_SKIP_REG2                               (PCS_CH0_SKIP_REG2                                 ),//0 to 1023
    .PCS_SKIP_REG3                               (PCS_CH0_SKIP_REG3                                 ),//0 to 1023
    .PCS_DEC_DUAL                                (PCS_CH0_DEC_DUAL                                  ),//TRUE, FALSE;
    .PCS_SPLIT                                   (PCS_CH0_SPLIT                                     ),//TRUE, FALSE;
    .PCS_FIFOFLAG_CTC                            (PCS_CH0_FIFOFLAG_CTC                              ),//TRUE, FALSE;
    .PCS_COMMA_DET_MODE                          (PCS_CH0_COMMA_DET_MODE                            ),//"RX_CLK_SLIP" "COMMA_PATTERN"
    .PCS_ERRDETECT_SILENCE                       (PCS_CH0_ERRDETECT_SILENCE                         ),//TRUE, FALSE;
    .PCS_PMA_RCLK_POLINV                         (PCS_CH0_PMA_RCLK_POLINV                           ),//"PMA_RCLK" "REVERSE_OF_PMA_RCLK"
    .PCS_PCS_RCLK_SEL                            (PCS_CH0_PCS_RCLK_SEL                              ),//"PMA_RCLK" "PMA_TCLK" "RCLK"
    .PCS_CB_RCLK_SEL                             (PCS_CH0_CB_RCLK_SEL                               ),//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK"
    .PCS_AFTER_CTC_RCLK_SEL                      (PCS_CH0_AFTER_CTC_RCLK_SEL                        ),//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK" "RCLK2"
    .PCS_RCLK_POLINV                             (PCS_CH0_RCLK_POLINV                               ),//"RCLK" "REVERSE_OF_RCLK"
    .PCS_BRIDGE_RCLK_SEL                         (PCS_CH0_BRIDGE_RCLK_SEL                           ),//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK" "RCLK"
    .PCS_PCS_RCLK_EN                             (PCS_CH0_PCS_RCLK_EN                               ),//TRUE, FALSE;
    .PCS_CB_RCLK_EN                              (PCS_CH0_CB_RCLK_EN                                ),//TRUE, FALSE;
    .PCS_AFTER_CTC_RCLK_EN                       (PCS_CH0_AFTER_CTC_RCLK_EN                         ),//TRUE, FALSE;
    .PCS_AFTER_CTC_RCLK_EN_GB                    (PCS_CH0_AFTER_CTC_RCLK_EN_GB                      ),//TRUE, FALSE;
    .PCS_PCS_RX_RSTN                             (PCS_CH0_PCS_RX_RSTN                               ),//TRUE, FALSE; for PCS Receiver Reset
    .PCS_PCIE_SLAVE                              (PCS_CH0_PCIE_SLAVE                                ),//"MASTER","SLAVE"
    .PCS_RX_64B66B_67B                           (PCS_CH0_RX_64B66B_67B                             ),//"NORMAL" "64B_66B" "64B_67B"
    .PCS_RX_BRIDGE_CLK_POLINV                    (PCS_CH0_RX_BRIDGE_CLK_POLINV                      ),//"RX_BRIDGE_CLK" "REVERSE_OF_RX_BRIDGE_CLK"
    .PCS_PCS_CB_RSTN                             (PCS_CH0_PCS_CB_RSTN                               ),//TRUE, FALSE; for PCS CB Reset
    .PCS_TX_BRIDGE_GEAR_SEL                      (PCS_CH0_TX_BRIDGE_GEAR_SEL                        ),//TRUE: tx gear priority, FALSE:tx bridge unit priority
    .PCS_TX_BYPASS_BRIDGE_UINT                   (PCS_CH0_TX_BYPASS_BRIDGE_UINT                     ),//TRUE, FALSE; for bypass 
    .PCS_TX_BYPASS_BRIDGE_FIFO                   (PCS_CH0_TX_BYPASS_BRIDGE_FIFO                     ),//TRUE, FALSE; for bypass Tx Bridge FIFO
    .PCS_TX_BYPASS_GEAR                          (PCS_CH0_TX_BYPASS_GEAR                            ),//TRUE, FALSE;
    .PCS_TX_BYPASS_ENC                           (PCS_CH0_TX_BYPASS_ENC                             ),//TRUE, FALSE;
    .PCS_TX_BYPASS_BIT_SLIP                      (PCS_CH0_TX_BYPASS_BIT_SLIP                        ),//TRUE, FALSE;
    .PCS_TX_GEAR_SPLIT                           (PCS_CH0_TX_GEAR_SPLIT                             ),//TRUE, FALSE;
    .PCS_TX_DRIVE_REG_MODE                       (PCS_CH0_TX_DRIVE_REG_MODE                         ),//"NO_CHANGE" "EN_POLARIY_REV" "EN_BIT_REV" "EN_BOTH"
    .PCS_TX_BIT_SLIP_CYCLES                      (PCS_CH0_TX_BIT_SLIP_CYCLES                        ),//o to 31
    .PCS_INT_TX_MASK_0                           (PCS_CH0_INT_TX_MASK_0                             ),//TRUE, FALSE;
    .PCS_INT_TX_MASK_1                           (PCS_CH0_INT_TX_MASK_1                             ),//TRUE, FALSE;
    .PCS_INT_TX_MASK_2                           (PCS_CH0_INT_TX_MASK_2                             ),//TRUE, FALSE;
    .PCS_INT_TX_CLR_0                            (PCS_CH0_INT_TX_CLR_0                              ),//TRUE, FALSE;
    .PCS_INT_TX_CLR_1                            (PCS_CH0_INT_TX_CLR_1                              ),//TRUE, FALSE;
    .PCS_INT_TX_CLR_2                            (PCS_CH0_INT_TX_CLR_2                              ),//TRUE, FALSE;
    .PCS_TX_PMA_TCLK_POLINV                      (PCS_CH0_TX_PMA_TCLK_POLINV                        ),//"PMA_TCLK" "REVERSE_OF_PMA_TCLK"
    .PCS_TX_PCS_CLK_EN_SEL                       (PCS_CH0_TX_PCS_CLK_EN_SEL                         ),//TRUE, FALSE;
    .PCS_TX_BRIDGE_TCLK_SEL                      (PCS_CH0_TX_BRIDGE_TCLK_SEL                        ),//"PCS_TCLK" "TCLK"
    .PCS_TX_TCLK_POLINV                          (PCS_CH0_TX_TCLK_POLINV                            ),//"TCLK" "REVERSE_OF_TCLK"
    .PCS_PCS_TCLK_SEL                            (PCS_CH0_PCS_TCLK_SEL                              ),//"PMA_TCLK" "TCLK"
    .PCS_TX_PCS_TX_RSTN                          (PCS_CH0_TX_PCS_TX_RSTN                            ),//TRUE, FALSE; for PCS Transmitter Reset
    .PCS_TX_SLAVE                                (PCS_CH0_TX_SLAVE                                  ),//"MASTER" "SLAVE"
    .PCS_TX_GEAR_CLK_EN_SEL                      (PCS_CH0_TX_GEAR_CLK_EN_SEL                        ),//TRUE, FALSE;
    .PCS_DATA_WIDTH_MODE                         (PCS_CH0_DATA_WIDTH_MODE                           ),//"X8" "X10" "X16" "X20"
    .PCS_TX_64B66B_67B                           (PCS_CH0_TX_64B66B_67B                             ),//"NORMAL" "64B_66B" "64B_67B"
    .PCS_GEAR_TCLK_SEL                           (PCS_CH0_GEAR_TCLK_SEL                             ),//"PMA_TCLK" "TCLK2"
    .PCS_TX_TCLK2FABRIC_SEL                      (PCS_CH0_TX_TCLK2FABRIC_SEL                        ),//TRUE, FALSE
    .PCS_TX_OUTZZ                                (PCS_CH0_TX_OUTZZ                                  ),//TRUE, FALSE
    .PCS_ENC_DUAL                                (PCS_CH0_ENC_DUAL                                  ),//TRUE, FALSE
    .PCS_TX_BITSLIP_DATA_MODE                    (PCS_CH0_TX_BITSLIP_DATA_MODE                      ),//"X10" "X20"
    .PCS_TX_BRIDGE_CLK_POLINV                    (PCS_CH0_TX_BRIDGE_CLK_POLINV                      ),//"TX_BRIDGE_CLK" "REVERSE_OF_TX_BRIDGE_CLK"
    .PCS_COMMA_REG1                              (PCS_CH0_COMMA_REG1                                ),//0 to 1023
    .PCS_RAPID_IMAX                              (PCS_CH0_RAPID_IMAX                                ),//0 to 7
    .PCS_RAPID_VMIN_1                            (PCS_CH0_RAPID_VMIN_1                              ),//0 to 255
    .PCS_RAPID_VMIN_2                            (PCS_CH0_RAPID_VMIN_2                              ),//0 to 255
    .PCS_RX_PRBS_MODE                            (PCS_CH0_RX_PRBS_MODE                              ),//DISABLE PRBS_7 PRBS_15 PRBS_23 PRBS_31
    .PCS_RX_ERRCNT_CLR                           (PCS_CH0_RX_ERRCNT_CLR                             ),//TRUE, FALSE
    .PCS_PRBS_ERR_LPBK                           (PCS_CH0_PRBS_ERR_LPBK                             ),//TRUE, FALSE
    .PCS_TX_PRBS_MODE                            (PCS_CH0_TX_PRBS_MODE                              ),//DISABLE PRBS_7 PRBS_15 PRBS_23 PRBS_31 LONG_1 LONG_0 20UI D10_2 PCIE
    .PCS_TX_INSERT_ER                            (PCS_CH0_TX_INSERT_ER                              ),//TRUE, FALSE
    .PCS_ENABLE_PRBS_GEN                         (PCS_CH0_ENABLE_PRBS_GEN                           ),//TRUE, FALSE
    .PCS_DEFAULT_RADDR                           (PCS_CH0_DEFAULT_RADDR                             ),//0 to 15
    .PCS_MASTER_CHECK_OFFSET                     (PCS_CH0_MASTER_CHECK_OFFSET                       ),//0 to 15
    .PCS_DELAY_SET                               (PCS_CH0_DELAY_SET                                 ),//0 to 15
    .PCS_SEACH_OFFSET                            (PCS_CH0_SEACH_OFFSET                              ),//"20BIT" 30BIT" "40BIT" "50BIT" "60BIT" "70BIT" "80BIT"
    .PCS_CEB_RAPIDLS_MMAX                        (PCS_CH0_CEB_RAPIDLS_MMAX                          ),//0 to 7
    .PCS_CTC_AFULL                               (PCS_CH0_CTC_AFULL                                 ),//0 to 31
    .PCS_CTC_AEMPTY                              (PCS_CH0_CTC_AEMPTY                                ),//0 to 31
    .PCS_CTC_CONTI_SKP_SET                       (PCS_CH0_CTC_CONTI_SKP_SET                         ),//0 to 1
    .PCS_FAR_LOOP                                (PCS_CH0_FAR_LOOP                                  ),//TRUE, FALSE
    .PCS_NEAR_LOOP                               (PCS_CH0_NEAR_LOOP                                 ),//TRUE, FALSE
    .PCS_PMA_TX2RX_PLOOP_EN                      (PCS_CH0_PMA_TX2RX_PLOOP_EN                        ),//TRUE, FALSE
    .PCS_PMA_TX2RX_SLOOP_EN                      (PCS_CH0_PMA_TX2RX_SLOOP_EN                        ),//TRUE, FALSE
    .PCS_PMA_RX2TX_PLOOP_EN                      (PCS_CH0_PMA_RX2TX_PLOOP_EN                        ),//TRUE, FALSE
    .PCS_INT_RX_MASK_0                           (PCS_CH0_INT_RX_MASK_0                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_1                           (PCS_CH0_INT_RX_MASK_1                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_2                           (PCS_CH0_INT_RX_MASK_2                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_3                           (PCS_CH0_INT_RX_MASK_3                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_4                           (PCS_CH0_INT_RX_MASK_4                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_5                           (PCS_CH0_INT_RX_MASK_5                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_6                           (PCS_CH0_INT_RX_MASK_6                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_7                           (PCS_CH0_INT_RX_MASK_7                             ),//TRUE, FALSE
    .PCS_INT_RX_CLR_0                            (PCS_CH0_INT_RX_CLR_0                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_1                            (PCS_CH0_INT_RX_CLR_1                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_2                            (PCS_CH0_INT_RX_CLR_2                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_3                            (PCS_CH0_INT_RX_CLR_3                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_4                            (PCS_CH0_INT_RX_CLR_4                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_5                            (PCS_CH0_INT_RX_CLR_5                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_6                            (PCS_CH0_INT_RX_CLR_6                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_7                            (PCS_CH0_INT_RX_CLR_7                              ),//TRUE, FALSE
    .PCS_CA_RSTN_RX                              (PCS_CH0_CA_RSTN_RX                                ),//TRUE, FALSE; for Rx CLK Aligner Reset
    .PCS_CA_DYN_DLY_EN_RX                        (PCS_CH0_CA_DYN_DLY_EN_RX                          ),//TRUE, FALSE
    .PCS_CA_DYN_DLY_SEL_RX                       (PCS_CH0_CA_DYN_DLY_SEL_RX                         ),//TRUE, FALSE
    .PCS_CA_RX                                   (PCS_CH0_CA_RX                                     ),//0 to 255
    .PCS_CA_RSTN_TX                              (PCS_CH0_CA_RSTN_TX                                ),//TRUE, FALSE
    .PCS_CA_DYN_DLY_EN_TX                        (PCS_CH0_CA_DYN_DLY_EN_TX                          ),//TRUE, FALSE
    .PCS_CA_DYN_DLY_SEL_TX                       (PCS_CH0_CA_DYN_DLY_SEL_TX                         ),//TRUE, FALSE
    .PCS_CA_TX                                   (PCS_CH0_CA_TX                                     ),//0 to 255
    .PCS_RXPRBS_PWR_REDUCTION                    (PCS_CH0_RXPRBS_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_WDALIGN_PWR_REDUCTION                   (PCS_CH0_WDALIGN_PWR_REDUCTION                     ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXDEC_PWR_REDUCTION                     (PCS_CH0_RXDEC_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXCB_PWR_REDUCTION                      (PCS_CH0_RXCB_PWR_REDUCTION                        ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXCTC_PWR_REDUCTION                     (PCS_CH0_RXCTC_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXGEAR_PWR_REDUCTION                    (PCS_CH0_RXGEAR_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXBRG_PWR_REDUCTION                     (PCS_CH0_RXBRG_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXTEST_PWR_REDUCTION                    (PCS_CH0_RXTEST_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXBRG_PWR_REDUCTION                     (PCS_CH0_TXBRG_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXGEAR_PWR_REDUCTION                    (PCS_CH0_TXGEAR_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXENC_PWR_REDUCTION                     (PCS_CH0_TXENC_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXBSLP_PWR_REDUCTION                    (PCS_CH0_TXBSLP_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXPRBS_PWR_REDUCTION                    (PCS_CH0_TXPRBS_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    //pma_rx                                                                                      
    .PMA_REG_RX_PD                               (PMA_CH0_REG_RX_PD                                 ),//ON, OFF;
    .PMA_REG_RX_PD_EN                            (PMA_CH0_REG_RX_PD_EN                              ),//TRUE, FALSE
    .PMA_REG_RX_RESERVED_2                       (PMA_CH0_REG_RX_RESERVED_2                         ),//TRUE, FALSE
    .PMA_REG_RX_RESERVED_3                       (PMA_CH0_REG_RX_RESERVED_3                         ),//TRUE, FALSE
    .PMA_REG_RX_DATAPATH_PD                      (PMA_CH0_REG_RX_DATAPATH_PD                        ),//ON, OFF;
    .PMA_REG_RX_DATAPATH_PD_EN                   (PMA_CH0_REG_RX_DATAPATH_PD_EN                     ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_PD                        (PMA_CH0_REG_RX_SIGDET_PD                          ),//ON, OFF;
    .PMA_REG_RX_SIGDET_PD_EN                     (PMA_CH0_REG_RX_SIGDET_PD_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_DCC_RST_N                        (PMA_CH0_REG_RX_DCC_RST_N                          ),//TRUE, FALSE;
    .PMA_REG_RX_DCC_RST_N_EN                     (PMA_CH0_REG_RX_DCC_RST_N_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_CDR_RST_N                        (PMA_CH0_REG_RX_CDR_RST_N                          ),//TRUE, FALSE;
    .PMA_REG_RX_CDR_RST_N_EN                     (PMA_CH0_REG_RX_CDR_RST_N_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_RST_N                     (PMA_CH0_REG_RX_SIGDET_RST_N                       ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_RST_N_EN                  (PMA_CH0_REG_RX_SIGDET_RST_N_EN                    ),//TRUE, FALSE;
    .PMA_REG_RXPCLK_SLIP                         (PMA_CH0_REG_RXPCLK_SLIP                           ),//TRUE, FALSE;
    .PMA_REG_RXPCLK_SLIP_OW                      (PMA_CH0_REG_RXPCLK_SLIP_OW                        ),//TRUE, FALSE;
    .PMA_REG_RX_PCLKSWITCH_RST_N                 (PMA_CH0_REG_RX_PCLKSWITCH_RST_N                   ),//TRUE, FALSE; for TX PMA Reset
    .PMA_REG_RX_PCLKSWITCH_RST_N_EN              (PMA_CH0_REG_RX_PCLKSWITCH_RST_N_EN                ),//TRUE, FALSE;
    .PMA_REG_RX_PCLKSWITCH                       (PMA_CH0_REG_RX_PCLKSWITCH                         ),//TRUE, FALSE;
    .PMA_REG_RX_PCLKSWITCH_EN                    (PMA_CH0_REG_RX_PCLKSWITCH_EN                      ),//TRUE, FALSE;
    .PMA_REG_RX_HIGHZ                            (PMA_CH0_REG_RX_HIGHZ                              ),//TRUE, FALSE;
    .PMA_REG_RX_HIGHZ_EN                         (PMA_CH0_REG_RX_HIGHZ_EN                           ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_CLK_WINDOW                (PMA_CH0_REG_RX_SIGDET_CLK_WINDOW                  ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_CLK_WINDOW_OW             (PMA_CH0_REG_RX_SIGDET_CLK_WINDOW_OW               ),//TRUE, FALSE;
    .PMA_REG_RX_PD_BIAS_RX                       (PMA_CH0_REG_RX_PD_BIAS_RX                         ),//TRUE, FALSE;
    .PMA_REG_RX_PD_BIAS_RX_OW                    (PMA_CH0_REG_RX_PD_BIAS_RX_OW                      ),//TRUE, FALSE;
    .PMA_REG_RX_RESET_N                          (PMA_CH0_REG_RX_RESET_N                            ),//TRUE, FALSE;
    .PMA_REG_RX_RESET_N_OW                       (PMA_CH0_REG_RX_RESET_N_OW                         ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_29_28                   (PMA_CH0_REG_RX_RESERVED_29_28                     ),//0 to 3
    .PMA_REG_RX_BUSWIDTH                         (PMA_CH0_REG_RX_BUSWIDTH                           ),//"8BIT" "10BIT" "16BIT" "20BIT"
    .PMA_REG_RX_BUSWIDTH_EN                      (PMA_CH0_REG_RX_BUSWIDTH_EN                        ),//TRUE, FALSE;
    .PMA_REG_RX_RATE                             (PMA_CH0_REG_RX_RATE                               ),//"DIV4" "DIV2" "DIV1" "MUL2"
    .PMA_REG_RX_RESERVED_36                      (PMA_CH0_REG_RX_RESERVED_36                        ),//TRUE, FALSE;
    .PMA_REG_RX_RATE_EN                          (PMA_CH0_REG_RX_RATE_EN                            ),//TRUE, FALSE;
    .PMA_REG_RX_RES_TRIM                         (PMA_CH0_REG_RX_RES_TRIM                           ),//0 to 63
    .PMA_REG_RX_RESERVED_44                      (PMA_CH0_REG_RX_RESERVED_44                        ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_45                      (PMA_CH0_REG_RX_RESERVED_45                        ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_STATUS_EN                 (PMA_CH0_REG_RX_SIGDET_STATUS_EN                   ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_48_47                   (PMA_CH0_REG_RX_RESERVED_48_47                     ),//0 to 3
    .PMA_REG_RX_ICTRL_SIGDET                     (PMA_CH0_REG_RX_ICTRL_SIGDET                       ),//0 to 15
    .PMA_REG_CDR_READY_THD                       (PMA_CH0_REG_CDR_READY_THD                         ),//0 to 4095
    .PMA_REG_RX_RESERVED_65                      (PMA_CH0_REG_RX_RESERVED_65                        ),//TRUE, FALSE;
    .PMA_REG_RX_PCLK_EDGE_SEL                    (PMA_CH0_REG_RX_PCLK_EDGE_SEL                      ),//"POS_EDGE" "NEG_EDGE"
    .PMA_REG_RX_PIBUF_IC                         (PMA_CH0_REG_RX_PIBUF_IC                           ),//0 to 3
    .PMA_REG_RX_RESERVED_69                      (PMA_CH0_REG_RX_RESERVED_69                        ),//TRUE, FALSE; 
    .PMA_REG_RX_DCC_IC_RX                        (PMA_CH0_REG_RX_DCC_IC_RX                          ),//0 to 3
    .PMA_REG_CDR_READY_CHECK_CTRL                (PMA_CH0_REG_CDR_READY_CHECK_CTRL                  ),//0 to 3
    .PMA_REG_RX_ICTRL_TRX                        (PMA_CH0_REG_RX_ICTRL_TRX                          ),//"87_5PCT" "100PCT" "112_5PCT" "125PCT"
    .PMA_REG_RX_RESERVED_77_76                   (PMA_CH0_REG_RX_RESERVED_77_76                     ),//0 to 3
    .PMA_REG_RX_RESERVED_79_78                   (PMA_CH0_REG_RX_RESERVED_79_78                     ),//0 to 3
    .PMA_REG_RX_RESERVED_81_80                   (PMA_CH0_REG_RX_RESERVED_81_80                     ),//0 to 3
    .PMA_REG_RX_ICTRL_PIBUF                      (PMA_CH0_REG_RX_ICTRL_PIBUF                        ),//"87_5PCT" "100PCT" "112_5PCT" "125PCT"
    .PMA_REG_RX_ICTRL_PI                         (PMA_CH0_REG_RX_ICTRL_PI                           ),//"87_5PCT" "100PCT" "112_5PCT" "125PCT"
    .PMA_REG_RX_ICTRL_DCC                        (PMA_CH0_REG_RX_ICTRL_DCC                          ),//"87_5PCT" "100PCT" "112_5PCT" "125PCT"
    .PMA_REG_RX_RESERVED_89_88                   (PMA_CH0_REG_RX_RESERVED_89_88                     ),//0 to 3
    .PMA_REG_TX_RATE                             (PMA_CH0_REG_TX_RATE                               ),//"DIV4" "DIV2" "DIV1" "MUL2"
    .PMA_REG_RX_RESERVED_92                      (PMA_CH0_REG_RX_RESERVED_92                        ),//TRUE, FALSE; 
    .PMA_REG_TX_RATE_EN                          (PMA_CH0_REG_TX_RATE_EN                            ),//TRUE, FALSE; 
    .PMA_REG_RX_TX2RX_PLPBK_RST_N                (PMA_CH0_REG_RX_TX2RX_PLPBK_RST_N                  ),//TRUE, FALSE; for tx2rx pma parallel loop back Reset
    .PMA_REG_RX_TX2RX_PLPBK_RST_N_EN             (PMA_CH0_REG_RX_TX2RX_PLPBK_RST_N_EN               ),//TRUE, FALSE; 
    .PMA_REG_RX_TX2RX_PLPBK_EN                   (PMA_CH0_REG_RX_TX2RX_PLPBK_EN                     ),//TRUE, FALSE; for tx2rx pma parallel loop back enable
    .PMA_REG_TXCLK_SEL                           (PMA_CH0_REG_TXCLK_SEL                             ),//"PLL" "RXCLK"
    .PMA_REG_RX_DATA_POLARITY                    (PMA_CH0_REG_RX_DATA_POLARITY                      ),//"NORMAL" "REVERSE"
    .PMA_REG_RX_ERR_INSERT                       (PMA_CH0_REG_RX_ERR_INSERT                         ),//TRUE, FALSE;
    .PMA_REG_UDP_CHK_EN                          (PMA_CH0_REG_UDP_CHK_EN                            ),//TRUE, FALSE;
    .PMA_REG_PRBS_SEL                            (PMA_CH0_REG_PRBS_SEL                              ),//"PRBS7" "PRBS15" "PRBS23" "PRBS31"
    .PMA_REG_PRBS_CHK_EN                         (PMA_CH0_REG_PRBS_CHK_EN                           ),//TRUE, FALSE;
    .PMA_REG_PRBS_CHK_WIDTH_SEL                  (PMA_CH0_REG_PRBS_CHK_WIDTH_SEL                    ),//"8BIT" "10BIT" "16BIT" "20BIT"
    .PMA_REG_BIST_CHK_PAT_SEL                    (PMA_CH0_REG_BIST_CHK_PAT_SEL                      ),//"PRBS" "CONSTANT"
    .PMA_REG_LOAD_ERR_CNT                        (PMA_CH0_REG_LOAD_ERR_CNT                          ),//TRUE, FALSE;
    .PMA_REG_CHK_COUNTER_EN                      (PMA_CH0_REG_CHK_COUNTER_EN                        ),//TRUE, FALSE;
    .PMA_REG_CDR_PROP_GAIN                       (PMA_CH0_REG_CDR_PROP_GAIN                         ),//0 to 7
    .PMA_REG_CDR_PROP_TURBO_GAIN                 (PMA_CH0_REG_CDR_PROP_TURBO_GAIN                   ),//0 to 7
    .PMA_REG_CDR_INT_GAIN                        (PMA_CH0_REG_CDR_INT_GAIN                          ),//0 to 7
    .PMA_REG_CDR_INT_TURBO_GAIN                  (PMA_CH0_REG_CDR_INT_TURBO_GAIN                    ),//0 to 7
    .PMA_REG_CDR_INT_SAT_MAX                     (PMA_CH0_REG_CDR_INT_SAT_MAX                       ),//0 to 1023
    .PMA_REG_CDR_INT_SAT_MIN                     (PMA_CH0_REG_CDR_INT_SAT_MIN                       ),//0 to 1023
    .PMA_REG_CDR_INT_RST                         (PMA_CH0_REG_CDR_INT_RST                           ),//TRUE, FALSE;
    .PMA_REG_CDR_INT_RST_OW                      (PMA_CH0_REG_CDR_INT_RST_OW                        ),//TRUE, FALSE;
    .PMA_REG_CDR_PROP_RST                        (PMA_CH0_REG_CDR_PROP_RST                          ),//TRUE, FALSE;
    .PMA_REG_CDR_PROP_RST_OW                     (PMA_CH0_REG_CDR_PROP_RST_OW                       ),//TRUE, FALSE;
    .PMA_REG_CDR_LOCK_RST                        (PMA_CH0_REG_CDR_LOCK_RST                          ),//TRUE, FALSE; for CDR LOCK Counter Reset
    .PMA_REG_CDR_LOCK_RST_OW                     (PMA_CH0_REG_CDR_LOCK_RST_OW                       ),//TRUE, FALSE;
    .PMA_REG_CDR_RX_PI_FORCE_SEL                 (PMA_CH0_REG_CDR_RX_PI_FORCE_SEL                   ),//0,1
    .PMA_REG_CDR_RX_PI_FORCE_D                   (PMA_CH0_REG_CDR_RX_PI_FORCE_D                     ),//0 to 255
    .PMA_REG_CDR_LOCK_TIMER                      (PMA_CH0_REG_CDR_LOCK_TIMER                        ),//"0_8U" "1_2U" "1_6U" "2_4U" 3_2U" "4_8U" "12_8U" "25_6U"
    .PMA_REG_CDR_TURBO_MODE_TIMER                (PMA_CH0_REG_CDR_TURBO_MODE_TIMER                  ),//0 to 3
    .PMA_REG_CDR_LOCK_VAL                        (PMA_CH0_REG_CDR_LOCK_VAL                          ),//TRUE, FALSE;
    .PMA_REG_CDR_LOCK_OW                         (PMA_CH0_REG_CDR_LOCK_OW                           ),//TRUE, FALSE;
    .PMA_REG_CDR_INT_SAT_DET_EN                  (PMA_CH0_REG_CDR_INT_SAT_DET_EN                    ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_AUTO_DIS                    (PMA_CH0_REG_CDR_SAT_AUTO_DIS                      ),//TRUE, FALSE;
    .PMA_REG_CDR_GAIN_AUTO                       (PMA_CH0_REG_CDR_GAIN_AUTO                         ),//TRUE, FALSE;
    .PMA_REG_CDR_TURBO_GAIN_AUTO                 (PMA_CH0_REG_CDR_TURBO_GAIN_AUTO                   ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_171_167                 (PMA_CH0_REG_RX_RESERVED_171_167                   ),//0 to 31
    .PMA_REG_RX_RESERVED_175_172                 (PMA_CH0_REG_RX_RESERVED_175_172                   ),//0 to 31
    .PMA_REG_CDR_SAT_DET_STATUS_EN               (PMA_CH0_REG_CDR_SAT_DET_STATUS_EN                 ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_STATUS_RESET_EN         (PMA_CH0_REG_CDR_SAT_DET_STATUS_RESET_EN           ),//TRUE, FALSE;
    .PMA_REG_CDR_PI_CTRL_RST                     (PMA_CH0_REG_CDR_PI_CTRL_RST                       ),//TRUE, FALSE;
    .PMA_REG_CDR_PI_CTRL_RST_OW                  (PMA_CH0_REG_CDR_PI_CTRL_RST_OW                    ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_RST                     (PMA_CH0_REG_CDR_SAT_DET_RST                       ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_RST_OW                  (PMA_CH0_REG_CDR_SAT_DET_RST_OW                    ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_STICKY_RST              (PMA_CH0_REG_CDR_SAT_DET_STICKY_RST                ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_STICKY_RST_OW           (PMA_CH0_REG_CDR_SAT_DET_STICKY_RST_OW             ),//TRUE, FALSE;
    .PMA_REG_CDR_SIGDET_STATUS_DIS               (PMA_CH0_REG_CDR_SIGDET_STATUS_DIS                 ),//TRUE, FALSE; for sigdet_status is 0 to reset cdr
    .PMA_REG_CDR_SAT_DET_TIMER                   (PMA_CH0_REG_CDR_SAT_DET_TIMER                     ),//0 to 3
    .PMA_REG_CDR_SAT_DET_STATUS_VAL              (PMA_CH0_REG_CDR_SAT_DET_STATUS_VAL                ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_STATUS_OW               (PMA_CH0_REG_CDR_SAT_DET_STATUS_OW                 ),//TRUE, FALSE;
    .PMA_REG_CDR_TURBO_MODE_EN                   (PMA_CH0_REG_CDR_TURBO_MODE_EN                     ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_190                     (PMA_CH0_REG_RX_RESERVED_190                       ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_193_191                 (PMA_CH0_REG_RX_RESERVED_193_191                   ),//0 to 7
    .PMA_REG_CDR_STATUS_FIFO_EN                  (PMA_CH0_REG_CDR_STATUS_FIFO_EN                    ),//TRUE, FALSE;
    .PMA_REG_PMA_TEST_SEL                        (PMA_CH0_REG_PMA_TEST_SEL                          ),//0,1
    .PMA_REG_OOB_COMWAKE_GAP_MIN                 (PMA_CH0_REG_OOB_COMWAKE_GAP_MIN                   ),//0 to 63
    .PMA_REG_OOB_COMWAKE_GAP_MAX                 (PMA_CH0_REG_OOB_COMWAKE_GAP_MAX                   ),//0 to 63
    .PMA_REG_OOB_COMINIT_GAP_MIN                 (PMA_CH0_REG_OOB_COMINIT_GAP_MIN                   ),//0 to 255
    .PMA_REG_OOB_COMINIT_GAP_MAX                 (PMA_CH0_REG_OOB_COMINIT_GAP_MAX                   ),//0 to 255
    .PMA_REG_RX_RESERVED_227_226                 (PMA_CH0_REG_RX_RESERVED_227_226                   ),//0 to 3
    .PMA_REG_COMWAKE_STATUS_CLEAR                (PMA_CH0_REG_COMWAKE_STATUS_CLEAR                  ),//0,1
    .PMA_REG_COMINIT_STATUS_CLEAR                (PMA_CH0_REG_COMINIT_STATUS_CLEAR                  ),//0,1
    .PMA_REG_RX_SYNC_RST_N_EN                    (PMA_CH0_REG_RX_SYNC_RST_N_EN                      ),//TRUE, FALSE;
    .PMA_REG_RX_SYNC_RST_N                       (PMA_CH0_REG_RX_SYNC_RST_N                         ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_233_232                 (PMA_CH0_REG_RX_RESERVED_233_232                   ),//0 to 3
    .PMA_REG_RX_RESERVED_235_234                 (PMA_CH0_REG_RX_RESERVED_235_234                   ),//0 to 3
    .PMA_REG_RX_SATA_COMINIT_OW                  (PMA_CH0_REG_RX_SATA_COMINIT_OW                    ),//TRUE, FALSE;
    .PMA_REG_RX_SATA_COMINIT                     (PMA_CH0_REG_RX_SATA_COMINIT                       ),//TRUE, FALSE;
    .PMA_REG_RX_SATA_COMWAKE_OW                  (PMA_CH0_REG_RX_SATA_COMWAKE_OW                    ),//TRUE, FALSE;
    .PMA_REG_RX_SATA_COMWAKE                     (PMA_CH0_REG_RX_SATA_COMWAKE                       ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_241_240                 (PMA_CH0_REG_RX_RESERVED_241_240                   ),//0 to 3
    .PMA_REG_RX_DCC_DISABLE                      (PMA_CH0_REG_RX_DCC_DISABLE                        ),//TRUE, FALSE; for rx dcc disable control
    .PMA_REG_RX_RESERVED_243                     (PMA_CH0_REG_RX_RESERVED_243                       ),//TRUE, FALSE;
    .PMA_REG_RX_SLIP_SEL_EN                      (PMA_CH0_REG_RX_SLIP_SEL_EN                        ),//TRUE, FALSE;
    .PMA_REG_RX_SLIP_SEL                         (PMA_CH0_REG_RX_SLIP_SEL                           ),//0 to 15
    .PMA_REG_RX_SLIP_EN                          (PMA_CH0_REG_RX_SLIP_EN                            ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_STATUS_SEL                (PMA_CH0_REG_RX_SIGDET_STATUS_SEL                  ),//0 to 7
    .PMA_REG_RX_SIGDET_FSM_RST_N                 (PMA_CH0_REG_RX_SIGDET_FSM_RST_N                   ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_254                     (PMA_CH0_REG_RX_RESERVED_254                       ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_STATUS                    (PMA_CH0_REG_RX_SIGDET_STATUS                      ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_VTH                       (PMA_CH0_REG_RX_SIGDET_VTH                         ),//"45MV" "54MV" "63MV" "72MV"
    .PMA_REG_RX_SIGDET_GRM                       (PMA_CH0_REG_RX_SIGDET_GRM                         ),//0,1,2,3
    .PMA_REG_RX_SIGDET_PULSE_EXT                 (PMA_CH0_REG_RX_SIGDET_PULSE_EXT                   ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_CH2_SEL                   (PMA_CH0_REG_RX_SIGDET_CH2_SEL                     ),//0,1
    .PMA_REG_RX_SIGDET_CH2_CHK_WINDOW            (PMA_CH0_REG_RX_SIGDET_CH2_CHK_WINDOW              ),//0 to 31
    .PMA_REG_RX_SIGDET_CHK_WINDOW_EN             (PMA_CH0_REG_RX_SIGDET_CHK_WINDOW_EN               ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_NOSIG_COUNT_SETTING       (PMA_CH0_REG_RX_SIGDET_NOSIG_COUNT_SETTING         ),//0 to 7
    .PMA_REG_SLIP_FIFO_INV_EN                    (PMA_CH0_REG_SLIP_FIFO_INV_EN                      ),//TRUE, FALSE;
    .PMA_REG_SLIP_FIFO_INV                       (PMA_CH0_REG_SLIP_FIFO_INV                         ),//"POS_EDGE" "NEG_EDGE"
    .PMA_REG_RX_SIGDET_OOB_DET_COUNT_VAL         (PMA_CH0_REG_RX_SIGDET_OOB_DET_COUNT_VAL           ),//0 to 31
    .PMA_REG_RX_SIGDET_4OOB_DET_SEL              (PMA_CH0_REG_RX_SIGDET_4OOB_DET_SEL                ),//0 to 7
    .PMA_REG_RX_RESERVED_285_283                 (PMA_CH0_REG_RX_RESERVED_285_283                   ),//0 to 7
    .PMA_REG_RX_RESERVED_286                     (PMA_CH0_REG_RX_RESERVED_286                       ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_IC_I                      (PMA_CH0_REG_RX_SIGDET_IC_I                        ),//0 to 15
    .PMA_REG_RX_OOB_DETECTOR_RESET_N_OW          (PMA_CH0_REG_RX_OOB_DETECTOR_RESET_N_OW            ),//TRUE, FALSE;
    .PMA_REG_RX_OOB_DETECTOR_RESET_N             (PMA_CH0_REG_RX_OOB_DETECTOR_RESET_N               ),//TRUE, FALSE;for rx oob detector Reset
    .PMA_REG_RX_OOB_DETECTOR_PD_OW               (PMA_CH0_REG_RX_OOB_DETECTOR_PD_OW                 ),//TRUE, FALSE;
    .PMA_REG_RX_OOB_DETECTOR_PD                  (PMA_CH0_REG_RX_OOB_DETECTOR_PD                    ),//TRUE, FALSE;for rx oob detector powerdown
    .PMA_REG_RX_LS_MODE_EN                       (PMA_CH0_REG_RX_LS_MODE_EN                         ),//TRUE, FALSE;for Enable Low-speed mode
    .PMA_REG_ANA_RX_EQ1_R_SET_FB_O_SEL           (PMA_CH0_REG_ANA_RX_EQ1_R_SET_FB_O_SEL             ),//TRUE, FALSE;
    .PMA_REG_ANA_RX_EQ2_R_SET_FB_O_SEL           (PMA_CH0_REG_ANA_RX_EQ2_R_SET_FB_O_SEL             ),//TRUE, FALSE;
    .PMA_REG_RX_EQ1_R_SET_TOP                    (PMA_CH0_REG_RX_EQ1_R_SET_TOP                      ),//0 to 3
    .PMA_REG_RX_EQ1_R_SET_FB                     (PMA_CH0_REG_RX_EQ1_R_SET_FB                       ),//0 to 15
    .PMA_REG_RX_EQ1_C_SET_FB                     (PMA_CH0_REG_RX_EQ1_C_SET_FB                       ),//0 to 15
    .PMA_REG_RX_EQ1_OFF                          (PMA_CH0_REG_RX_EQ1_OFF                            ),//TRUE, FALSE;
    .PMA_REG_RX_EQ2_R_SET_TOP                    (PMA_CH0_REG_RX_EQ2_R_SET_TOP                      ),//0 to 3
    .PMA_REG_RX_EQ2_R_SET_FB                     (PMA_CH0_REG_RX_EQ2_R_SET_FB                       ),//0 to 15
    .PMA_REG_RX_EQ2_C_SET_FB                     (PMA_CH0_REG_RX_EQ2_C_SET_FB                       ),//0 to 15
    .PMA_REG_RX_EQ2_OFF                          (PMA_CH0_REG_RX_EQ2_OFF                            ),//TRUE, FALSE;
    .PMA_REG_EQ_DAC                              (PMA_CH0_REG_EQ_DAC                                ),//0 to 63
    .PMA_REG_RX_ICTRL_EQ                         (PMA_CH0_REG_RX_ICTRL_EQ                           ),//TRUE, FALSE;
    .PMA_REG_EQ_DC_CALIB_EN                      (PMA_CH0_REG_EQ_DC_CALIB_EN                        ),//TRUE, FALSE;
    .PMA_REG_EQ_DC_CALIB_SEL                     (PMA_CH0_REG_EQ_DC_CALIB_SEL                       ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_337_330                 (PMA_CH0_REG_RX_RESERVED_337_330                   ),//0 to 255
    .PMA_REG_RX_RESERVED_345_338                 (PMA_CH0_REG_RX_RESERVED_345_338                   ),//0 to 255
    .PMA_REG_RX_RESERVED_353_346                 (PMA_CH0_REG_RX_RESERVED_353_346                   ),//0 to 255
    .PMA_REG_RX_RESERVED_361_354                 (PMA_CH0_REG_RX_RESERVED_361_354                   ),//0 to 255
    .PMA_CTLE_CTRL_REG_I                         (PMA_CH0_CTLE_CTRL_REG_I                           ),//0 to 15
    .PMA_CTLE_REG_FORCE_SEL_I                    (PMA_CH0_CTLE_REG_FORCE_SEL_I                      ),//TRUE, FALSE;for ctrl self-adaption adjust
    .PMA_CTLE_REG_HOLD_I                         (PMA_CH0_CTLE_REG_HOLD_I                           ),//TRUE, FALSE;
    .PMA_CTLE_REG_INIT_DAC_I                     (PMA_CH0_CTLE_REG_INIT_DAC_I                       ),//0 to 15
    .PMA_CTLE_REG_POLARITY_I                     (PMA_CH0_CTLE_REG_POLARITY_I                       ),//TRUE, FALSE;
    .PMA_CTLE_REG_SHIFTER_GAIN_I                 (PMA_CH0_CTLE_REG_SHIFTER_GAIN_I                   ),//0 to 7
    .PMA_CTLE_REG_THRESHOLD_I                    (PMA_CH0_CTLE_REG_THRESHOLD_I                      ),//0 to 4095
    .PMA_REG_RX_RES_TRIM_EN                      (PMA_CH0_REG_RX_RES_TRIM_EN                        ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_393_389                 (PMA_CH0_REG_RX_RESERVED_393_389                   ),//0 to 31
    .PMA_CFG_RX_LANE_POWERUP                     (PMA_CH0_CFG_RX_LANE_POWERUP                       ),//ON, OFF;for RX_LANE Power-up
    .PMA_CFG_RX_PMA_RSTN                         (PMA_CH0_CFG_RX_PMA_RSTN                           ),//TRUE, FALSE;for RX_PMA Reset
    .PMA_INT_PMA_RX_MASK_0                       (PMA_CH0_INT_PMA_RX_MASK_0                         ),//TRUE, FALSE;
    .PMA_INT_PMA_RX_CLR_0                        (PMA_CH0_INT_PMA_RX_CLR_0                          ),//TRUE, FALSE;
    .PMA_CFG_CTLE_ADP_RSTN                       (PMA_CH0_CFG_CTLE_ADP_RSTN                         ),//TRUE, FALSE;for ctrl Reset
    //pma_tx                                                                                      
    .PMA_REG_TX_PD                               (PMA_CH0_REG_TX_PD                                 ),//ON, OFF;for transmitter power down
    .PMA_REG_TX_PD_OW                            (PMA_CH0_REG_TX_PD_OW                              ),//TRUE, FALSE;
    .PMA_REG_TX_MAIN_PRE_Z                       (PMA_CH0_REG_TX_MAIN_PRE_Z                         ),//TRUE, FALSE;Enable EI for PCIE mode
    .PMA_REG_TX_MAIN_PRE_Z_OW                    (PMA_CH0_REG_TX_MAIN_PRE_Z_OW                      ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_TIMER_SEL                 (PMA_CH0_REG_TX_BEACON_TIMER_SEL                   ),//0 to 3
    .PMA_REG_TX_RXDET_REQ_OW                     (PMA_CH0_REG_TX_RXDET_REQ_OW                       ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_REQ                        (PMA_CH0_REG_TX_RXDET_REQ                          ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_EN_OW                     (PMA_CH0_REG_TX_BEACON_EN_OW                       ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_EN                        (PMA_CH0_REG_TX_BEACON_EN                          ),//TRUE, FALSE;
    .PMA_REG_TX_EI_EN_OW                         (PMA_CH0_REG_TX_EI_EN_OW                           ),//TRUE, FALSE;
    .PMA_REG_TX_EI_EN                            (PMA_CH0_REG_TX_EI_EN                              ),//TRUE, FALSE;
    .PMA_REG_TX_BIT_CONV                         (PMA_CH0_REG_TX_BIT_CONV                           ),//TRUE, FALSE;
    .PMA_REG_TX_RES_CAL                          (PMA_CH0_REG_TX_RES_CAL                            ),//0 to 63
    .PMA_REG_TX_RESERVED_19                      (PMA_CH0_REG_TX_RESERVED_19                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_25_20                   (PMA_CH0_REG_TX_RESERVED_25_20                     ),//0 to 63
    .PMA_REG_TX_RESERVED_33_26                   (PMA_CH0_REG_TX_RESERVED_33_26                     ),//0 to 255
    .PMA_REG_TX_RESERVED_41_34                   (PMA_CH0_REG_TX_RESERVED_41_34                     ),//0 to 255
    .PMA_REG_TX_RESERVED_49_42                   (PMA_CH0_REG_TX_RESERVED_49_42                     ),//0 to 255
    .PMA_REG_TX_RESERVED_57_50                   (PMA_CH0_REG_TX_RESERVED_57_50                     ),//0 to 255
    .PMA_REG_TX_SYNC_OW                          (PMA_CH0_REG_TX_SYNC_OW                            ),//TRUE, FALSE;
    .PMA_REG_TX_SYNC                             (PMA_CH0_REG_TX_SYNC                               ),//TRUE, FALSE;
    .PMA_REG_TX_PD_POST                          (PMA_CH0_REG_TX_PD_POST                            ),//ON, OFF;
    .PMA_REG_TX_PD_POST_OW                       (PMA_CH0_REG_TX_PD_POST_OW                         ),//TRUE, FALSE;
    .PMA_REG_TX_RESET_N_OW                       (PMA_CH0_REG_TX_RESET_N_OW                         ),//TRUE, FALSE;
    .PMA_REG_TX_RESET_N                          (PMA_CH0_REG_TX_RESET_N                            ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_64                      (PMA_CH0_REG_TX_RESERVED_64                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_65                      (PMA_CH0_REG_TX_RESERVED_65                        ),//TRUE, FALSE;
    .PMA_REG_TX_BUSWIDTH_OW                      (PMA_CH0_REG_TX_BUSWIDTH_OW                        ),//TRUE, FALSE;
    .PMA_REG_TX_BUSWIDTH                         (PMA_CH0_REG_TX_BUSWIDTH                           ),//"8BIT" "10BIT" "16BIT" "20BIT"
    .PMA_REG_PLL_READY_OW                        (PMA_CH0_REG_PLL_READY_OW                          ),//TRUE, FALSE;
    .PMA_REG_PLL_READY                           (PMA_CH0_REG_PLL_READY                             ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_72                      (PMA_CH0_REG_TX_RESERVED_72                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_73                      (PMA_CH0_REG_TX_RESERVED_73                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_74                      (PMA_CH0_REG_TX_RESERVED_74                        ),//TRUE, FALSE;
    .PMA_REG_EI_PCLK_DELAY_SEL                   (PMA_CH0_REG_EI_PCLK_DELAY_SEL                     ),//0 to 3
    .PMA_REG_TX_RESERVED_77                      (PMA_CH0_REG_TX_RESERVED_77                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_83_78                   (PMA_CH0_REG_TX_RESERVED_83_78                     ),//0 to 63
    .PMA_REG_TX_RESERVED_89_84                   (PMA_CH0_REG_TX_RESERVED_89_84                     ),//0 to 63
    .PMA_REG_TX_RESERVED_95_90                   (PMA_CH0_REG_TX_RESERVED_95_90                     ),//0 to 63
    .PMA_REG_TX_RESERVED_101_96                  (PMA_CH0_REG_TX_RESERVED_101_96                    ),//0 to 63
    .PMA_REG_TX_RESERVED_107_102                 (PMA_CH0_REG_TX_RESERVED_107_102                   ),//0 to 63
    .PMA_REG_TX_RESERVED_113_108                 (PMA_CH0_REG_TX_RESERVED_113_108                   ),//0 to 63
    .PMA_REG_TX_AMP_DAC0                         (PMA_CH0_REG_TX_AMP_DAC0                           ),//0 to 63
    .PMA_REG_TX_AMP_DAC1                         (PMA_CH0_REG_TX_AMP_DAC1                           ),//0 to 63
    .PMA_REG_TX_AMP_DAC2                         (PMA_CH0_REG_TX_AMP_DAC2                           ),//0 to 63
    .PMA_REG_TX_AMP_DAC3                         (PMA_CH0_REG_TX_AMP_DAC3                           ),//0 to 63
    .PMA_REG_TX_RESERVED_143_138                 (PMA_CH0_REG_TX_RESERVED_143_138                   ),//0 to 63
    .PMA_REG_TX_MARGIN                           (PMA_CH0_REG_TX_MARGIN                             ),//0 to 7
    .PMA_REG_TX_MARGIN_OW                        (PMA_CH0_REG_TX_MARGIN_OW                          ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_149_148                 (PMA_CH0_REG_TX_RESERVED_149_148                   ),//0 to 3
    .PMA_REG_TX_RESERVED_150                     (PMA_CH0_REG_TX_RESERVED_150                       ),//TRUE, FALSE;
    .PMA_REG_TX_SWING                            (PMA_CH0_REG_TX_SWING                              ),//TRUE, FALSE;
    .PMA_REG_TX_SWING_OW                         (PMA_CH0_REG_TX_SWING_OW                           ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_153                     (PMA_CH0_REG_TX_RESERVED_153                       ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_THRESHOLD                  (PMA_CH0_REG_TX_RXDET_THRESHOLD                    ),//"28MV" "56MV" "84MV" "112MV"
    .PMA_REG_TX_RESERVED_157_156                 (PMA_CH0_REG_TX_RESERVED_157_156                   ),//0 to 3
    .PMA_REG_TX_BEACON_OSC_CTRL                  (PMA_CH0_REG_TX_BEACON_OSC_CTRL                    ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_160_159                 (PMA_CH0_REG_TX_RESERVED_160_159                   ),//0 to 3
    .PMA_REG_TX_RESERVED_162_161                 (PMA_CH0_REG_TX_RESERVED_162_161                   ),//0 to 3
    .PMA_REG_TX_TX2RX_SLPBACK_EN                 (PMA_CH0_REG_TX_TX2RX_SLPBACK_EN                   ),//TRUE, FALSE;
    .PMA_REG_TX_PCLK_EDGE_SEL                    (PMA_CH0_REG_TX_PCLK_EDGE_SEL                      ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_STATUS_OW                  (PMA_CH0_REG_TX_RXDET_STATUS_OW                    ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_STATUS                     (PMA_CH0_REG_TX_RXDET_STATUS                       ),//TRUE, FALSE;
    .PMA_REG_TX_PRBS_GEN_EN                      (PMA_CH0_REG_TX_PRBS_GEN_EN                        ),//TRUE, FALSE;
    .PMA_REG_TX_PRBS_GEN_WIDTH_SEL               (PMA_CH0_REG_TX_PRBS_GEN_WIDTH_SEL                 ),//"8BIT" "10BIT" "16BIT" "20BIT"
    .PMA_REG_TX_PRBS_SEL                         (PMA_CH0_REG_TX_PRBS_SEL                           ),//"PRBS7" "PRBS15" "PRBS23" "PRBS31"
    .PMA_REG_TX_UDP_DATA_7_TO_0                  (PMA_CH0_REG_TX_UDP_DATA_7_TO_0                    ),//0 to 255
    .PMA_REG_TX_UDP_DATA_15_TO_8                 (PMA_CH0_REG_TX_UDP_DATA_15_TO_8                   ),//0 to 255
    .PMA_REG_TX_UDP_DATA_19_TO_16                (PMA_CH0_REG_TX_UDP_DATA_19_TO_16                  ),//0 to 15
    .PMA_REG_TX_RESERVED_192                     (PMA_CH0_REG_TX_RESERVED_192                       ),//TRUE, FALSE;
    .PMA_REG_TX_FIFO_WP_CTRL                     (PMA_CH0_REG_TX_FIFO_WP_CTRL                       ),//0 to 7
    .PMA_REG_TX_FIFO_EN                          (PMA_CH0_REG_TX_FIFO_EN                            ),//TRUE, FALSE;
    .PMA_REG_TX_DATA_MUX_SEL                     (PMA_CH0_REG_TX_DATA_MUX_SEL                       ),//0 to 3
    .PMA_REG_TX_ERR_INSERT                       (PMA_CH0_REG_TX_ERR_INSERT                         ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_203_200                 (PMA_CH0_REG_TX_RESERVED_203_200                   ),//0 to15
    .PMA_REG_TX_RESERVED_204                     (PMA_CH0_REG_TX_RESERVED_204                       ),//TRUE, FALSE;
    .PMA_REG_TX_SATA_EN                          (PMA_CH0_REG_TX_SATA_EN                            ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_207_206                 (PMA_CH0_REG_TX_RESERVED_207_206                   ),//0 to3
    .PMA_REG_RATE_CHANGE_TXPCLK_ON_OW            (PMA_CH0_REG_RATE_CHANGE_TXPCLK_ON_OW              ),//TRUE, FALSE;
    .PMA_REG_RATE_CHANGE_TXPCLK_ON               (PMA_CH0_REG_RATE_CHANGE_TXPCLK_ON                 ),//TRUE, FALSE;
    .PMA_REG_TX_CFG_POST1                        (PMA_CH0_REG_TX_CFG_POST1                          ),//0 to 31
    .PMA_REG_TX_CFG_POST2                        (PMA_CH0_REG_TX_CFG_POST2                          ),//0 to 31
    .PMA_REG_TX_DEEMP                            (PMA_CH0_REG_TX_DEEMP                              ),//0 to 3
    .PMA_REG_TX_DEEMP_OW                         (PMA_CH0_REG_TX_DEEMP_OW                           ),//TRUE, FALSE;for TX DEEMP Control
    .PMA_REG_TX_RESERVED_224_223                 (PMA_CH0_REG_TX_RESERVED_224_223                   ),//0 to 3
    .PMA_REG_TX_RESERVED_225                     (PMA_CH0_REG_TX_RESERVED_225                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_229_226                 (PMA_CH0_REG_TX_RESERVED_229_226                   ),//0 to 15
    .PMA_REG_TX_OOB_DELAY_SEL                    (PMA_CH0_REG_TX_OOB_DELAY_SEL                      ),//0 to 15
    .PMA_REG_TX_POLARITY                         (PMA_CH0_REG_TX_POLARITY                           ),//"NORMAL" "REVERSE"
    .PMA_REG_ANA_TX_JTAG_DATA_O_SEL              (PMA_CH0_REG_ANA_TX_JTAG_DATA_O_SEL                ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_236                     (PMA_CH0_REG_TX_RESERVED_236                       ),//TRUE, FALSE;
    .PMA_REG_TX_LS_MODE_EN                       (PMA_CH0_REG_TX_LS_MODE_EN                         ),//TRUE, FALSE;
    .PMA_REG_TX_JTAG_MODE_EN_OW                  (PMA_CH0_REG_TX_JTAG_MODE_EN_OW                    ),//TRUE, FALSE;
    .PMA_REG_TX_JTAG_MODE_EN                     (PMA_CH0_REG_TX_JTAG_MODE_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_JTAG_MODE_EN_OW                  (PMA_CH0_REG_RX_JTAG_MODE_EN_OW                    ),//TRUE, FALSE;
    .PMA_REG_RX_JTAG_MODE_EN                     (PMA_CH0_REG_RX_JTAG_MODE_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_JTAG_OE                          (PMA_CH0_REG_RX_JTAG_OE                            ),//TRUE, FALSE;
    .PMA_REG_RX_ACJTAG_VHYSTSEL                  (PMA_CH0_REG_RX_ACJTAG_VHYSTSEL                    ),//0 to 7
    .PMA_REG_TX_RES_CAL_EN                       (PMA_CH0_REG_TX_RES_CAL_EN                         ),//TRUE, FALSE;
    .PMA_REG_RX_TERM_MODE_CTRL                   (PMA_CH0_REG_RX_TERM_MODE_CTRL                     ),//0 to 7; for rx terminatin Control
    .PMA_REG_TX_RESERVED_251_250                 (PMA_CH0_REG_TX_RESERVED_251_250                   ),//0 to 7
    .PMA_REG_PLPBK_TXPCLK_EN                     (PMA_CH0_REG_PLPBK_TXPCLK_EN                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_253                     (PMA_CH0_REG_TX_RESERVED_253                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_254                     (PMA_CH0_REG_TX_RESERVED_254                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_255                     (PMA_CH0_REG_TX_RESERVED_255                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_256                     (PMA_CH0_REG_TX_RESERVED_256                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_257                     (PMA_CH0_REG_TX_RESERVED_257                       ),//TRUE, FALSE;
    .PMA_REG_TX_PH_SEL                           (PMA_CH0_REG_TX_PH_SEL                             ),//0 to 63
    .PMA_REG_TX_CFG_PRE                          (PMA_CH0_REG_TX_CFG_PRE                            ),//0 to 31
    .PMA_REG_TX_CFG_MAIN                         (PMA_CH0_REG_TX_CFG_MAIN                           ),//0 to 63
    .PMA_REG_CFG_POST                            (PMA_CH0_REG_CFG_POST                              ),//0 to 31
    .PMA_REG_PD_MAIN                             (PMA_CH0_REG_PD_MAIN                               ),//TRUE, FALSE;
    .PMA_REG_PD_PRE                              (PMA_CH0_REG_PD_PRE                                ),//TRUE, FALSE;
    .PMA_REG_TX_LS_DATA                          (PMA_CH0_REG_TX_LS_DATA                            ),//TRUE, FALSE;
    .PMA_REG_TX_DCC_BUF_SZ_SEL                   (PMA_CH0_REG_TX_DCC_BUF_SZ_SEL                     ),//0 to 3
    .PMA_REG_TX_DCC_CAL_CUR_TUNE                 (PMA_CH0_REG_TX_DCC_CAL_CUR_TUNE                   ),//0 to 63
    .PMA_REG_TX_DCC_CAL_EN                       (PMA_CH0_REG_TX_DCC_CAL_EN                         ),//TRUE, FALSE;
    .PMA_REG_TX_DCC_CUR_SS                       (PMA_CH0_REG_TX_DCC_CUR_SS                         ),//0 to 3
    .PMA_REG_TX_DCC_FA_CTRL                      (PMA_CH0_REG_TX_DCC_FA_CTRL                        ),//TRUE, FALSE;
    .PMA_REG_TX_DCC_RI_CTRL                      (PMA_CH0_REG_TX_DCC_RI_CTRL                        ),//TRUE, FALSE;
    .PMA_REG_ATB_SEL_2_TO_0                      (PMA_CH0_REG_ATB_SEL_2_TO_0                        ),//0 to 7
    .PMA_REG_ATB_SEL_9_TO_3                      (PMA_CH0_REG_ATB_SEL_9_TO_3                        ),//0 to 127
    .PMA_REG_TX_CFG_7_TO_0                       (PMA_CH0_REG_TX_CFG_7_TO_0                         ),//0 to 255
    .PMA_REG_TX_CFG_15_TO_8                      (PMA_CH0_REG_TX_CFG_15_TO_8                        ),//0 to 255
    .PMA_REG_TX_CFG_23_TO_16                     (PMA_CH0_REG_TX_CFG_23_TO_16                       ),//0 to 255
    .PMA_REG_TX_CFG_31_TO_24                     (PMA_CH0_REG_TX_CFG_31_TO_24                       ),//0 to 255
    .PMA_REG_TX_OOB_EI_EN                        (PMA_CH0_REG_TX_OOB_EI_EN                          ),//TRUE, FALSE; Enable OOB EI for SATA mode
    .PMA_REG_TX_OOB_EI_EN_OW                     (PMA_CH0_REG_TX_OOB_EI_EN_OW                       ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_EN_DELAYED                (PMA_CH0_REG_TX_BEACON_EN_DELAYED                  ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_EN_DELAYED_OW             (PMA_CH0_REG_TX_BEACON_EN_DELAYED_OW               ),//TRUE, FALSE;
    .PMA_REG_TX_JTAG_DATA                        (PMA_CH0_REG_TX_JTAG_DATA                          ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_TIMER_SEL                  (PMA_CH0_REG_TX_RXDET_TIMER_SEL                    ),//0 to 255
    .PMA_REG_TX_CFG1_7_0                         (PMA_CH0_REG_TX_CFG1_7_0                           ),//0 to 255
    .PMA_REG_TX_CFG1_15_8                        (PMA_CH0_REG_TX_CFG1_15_8                          ),//0 to 255
    .PMA_REG_TX_CFG1_23_16                       (PMA_CH0_REG_TX_CFG1_23_16                         ),//0 to 255
    .PMA_REG_TX_CFG1_31_24                       (PMA_CH0_REG_TX_CFG1_31_24                         ),//0 to 255
    .PMA_REG_CFG_LANE_POWERUP                    (PMA_CH0_REG_CFG_LANE_POWERUP                      ),//ON, OFF; for PMA_LANE powerup
    .PMA_REG_CFG_TX_LANE_POWERUP_CLKPATH         (PMA_CH0_REG_CFG_TX_LANE_POWERUP_CLKPATH           ),//TRUE, FALSE; for Pma tx lane clkpath powerup
    .PMA_REG_CFG_TX_LANE_POWERUP_PISO            (PMA_CH0_REG_CFG_TX_LANE_POWERUP_PISO              ),//TRUE, FALSE; for Pma tx lane piso powerup
    .PMA_REG_CFG_TX_LANE_POWERUP_DRIVER          (PMA_CH0_REG_CFG_TX_LANE_POWERUP_DRIVER            ) //TRUE, FALSE; for Pma tx lane driver powerup
) U_GTP_HSSTLP_LANE0 (
    //PAD
    .P_TX_SDN                               (P_TX_SDN_0            ),//output              
    .P_TX_SDP                               (P_TX_SDP_0            ),//output              
    //SRB related                           
    .P_PCS_RX_MCB_STATUS                    (P_PCS_RX_MCB_STATUS_0 ),//output              
    .P_PCS_LSM_SYNCED                       (P_PCS_LSM_SYNCED_0    ),//output              
    .P_CFG_READY                            (P_CFG_READY_0         ),//output              
    .P_CFG_RDATA                            (P_CFG_RDATA_0         ),//output [7:0]        
    .P_CFG_INT                              (P_CFG_INT_0           ),//output              
    .P_RDATA                                (P_RDATA_0             ),//output [46:0]       
    .P_RCLK2FABRIC                          (P_RCLK2FABRIC_0       ),//output              
    .P_TCLK2FABRIC                          (P_TCLK2FABRIC_0       ),//output              
    .P_RX_SIGDET_STATUS                     (P_RX_SIGDET_STATUS_0  ),//output              
    .P_RX_SATA_COMINIT                      (P_RX_SATA_COMINIT_0   ),//output              
    .P_RX_SATA_COMWAKE                      (P_RX_SATA_COMWAKE_0   ),//output              
    .P_RX_LS_DATA                           (P_RX_LS_DATA_0        ),//output              
    .P_RX_READY                             (P_RX_READY_0          ),//output              
    .P_TEST_STATUS                          (P_TEST_STATUS_0       ),//output [19:0]       
    .P_TX_RXDET_STATUS                      (P_TX_RXDET_STATUS_0   ),//output              
    .P_CA_ALIGN_RX                          (P_CA_ALIGN_RX_0       ),//output              
    .P_CA_ALIGN_TX                          (P_CA_ALIGN_TX_0       ),//output              
    //out                                    
    .PMA_RCLK                               (PMA_RCLK_0            ),//output       	    
    .TXPCLK_PLL                             (TXPCLK_PLL_0          ),//output              
    //cin and cout                           
    .LANE_COUT_BUS_FORWARD                  (LANE_COUT_BUS_FORWARD_0),//output [18:0]       
    .APATTERN_STATUS_COUT                   (APATTERN_STATUS_COUT_0),//output              
    //PAD                                     
    .P_RX_SDN                               (P_RX_SDN_0            ),//input               
    .P_RX_SDP                               (P_RX_SDP_0            ),//input               
    //SRB related                            
    .P_RX_CLK_FR_CORE                       (P_RX_CLK_FR_CORE_0    ),//input               
    .P_RCLK2_FR_CORE                        (P_RCLK2_FR_CORE_0     ),//input               
    .P_TX_CLK_FR_CORE                       (P_TX_CLK_FR_CORE_0    ),//input               
    .P_TCLK2_FR_CORE                        (P_TCLK2_FR_CORE_0     ),//input               
    .P_PCS_TX_RST                           (P_PCS_TX_RST_0        ),//input               
    .P_PCS_RX_RST                           (P_PCS_RX_RST_0        ),//input               
    .P_PCS_CB_RST                           (P_PCS_CB_RST_0        ),//input               
    .P_RXGEAR_SLIP                          (P_RXGEAR_SLIP_0       ),//input               
    .P_CFG_CLK                              (P_CFG_CLK_0           ),//input               
    .P_CFG_RST                              (P_CFG_RST_0           ),//input               
    .P_CFG_PSEL                             (P_CFG_PSEL_0          ),//input               
    .P_CFG_ENABLE                           (P_CFG_ENABLE_0        ),//input               
    .P_CFG_WRITE                            (P_CFG_WRITE_0         ),//input               
    .P_CFG_ADDR                             (P_CFG_ADDR_0          ),//input [11:0]        
    .P_CFG_WDATA                            (P_CFG_WDATA_0         ),//input [7:0]         
    .P_TDATA                                (P_TDATA_0             ),//input [45:0]        
    .P_PCS_WORD_ALIGN_EN                    (P_PCS_WORD_ALIGN_EN_0 ),//input               
    .P_RX_POLARITY_INVERT                   (P_RX_POLARITY_INVERT_0),//input               
    .P_CEB_ADETECT_EN                       (P_CEB_ADETECT_EN_0    ),//input               
    .P_PCS_MCB_EXT_EN                       (P_PCS_MCB_EXT_EN_0    ),//input               
    .P_PCS_NEAREND_LOOP                     (P_PCS_NEAREND_LOOP_0  ),//input               
    .P_PCS_FAREND_LOOP                      (P_PCS_FAREND_LOOP_0   ),//input               
    .P_PMA_NEAREND_PLOOP                    (P_PMA_NEAREND_PLOOP_0 ),//input               
    .P_PMA_NEAREND_SLOOP                    (P_PMA_NEAREND_SLOOP_0 ),//input               
    .P_PMA_FAREND_PLOOP                     (P_PMA_FAREND_PLOOP_0  ),//input               
                                                                 
    .P_LANE_PD                              (P_LANE_PD_0           ),//input               
    .P_LANE_RST                             (P_LANE_RST_0          ),//input               
    .P_RX_LANE_PD                           (P_RX_LANE_PD_0        ),//input               
    .P_RX_PMA_RST                           (P_RX_PMA_RST_0        ),//input               
    .P_CTLE_ADP_RST                         (P_CTLE_ADP_RST_0      ),//input               
    .P_TX_DEEMP                             (P_TX_DEEMP_0          ),//input [1:0]         
    .P_TX_LS_DATA                           (P_TX_LS_DATA_0        ),//input               
    .P_TX_BEACON_EN                         (P_TX_BEACON_EN_0      ),//input               
    .P_TX_SWING                             (P_TX_SWING_0          ),//input               
    .P_TX_RXDET_REQ                         (P_TX_RXDET_REQ_0      ),//input               
    .P_TX_RATE                              (P_TX_RATE_0           ),//input [2:0]         
    .P_TX_BUSWIDTH                          (P_TX_BUSWIDTH_0       ),//input [2:0]         
    .P_TX_MARGIN                            (P_TX_MARGIN_0         ),//input [2:0]         
    .P_TX_PMA_RST                           (P_TX_PMA_RST_0        ),//input               
    .P_TX_LANE_PD_CLKPATH                   (P_TX_LANE_PD_CLKPATH_0),//input               
    .P_TX_LANE_PD_PISO                      (P_TX_LANE_PD_PISO_0   ),//input               
    .P_TX_LANE_PD_DRIVER                    (P_TX_LANE_PD_DRIVER_0 ),//input               
    .P_RX_RATE                              (P_RX_RATE_0           ),//input [2:0]         
    .P_RX_BUSWIDTH                          (P_RX_BUSWIDTH_0       ),//input [2:0]         
    .P_RX_HIGHZ                             (P_RX_HIGHZ_0          ),//input               
    .P_CIM_CLK_ALIGNER_RX                   (P_CIM_CLK_ALIGNER_RX_0),//input [7:0]         
    .P_CIM_CLK_ALIGNER_TX                   (P_CIM_CLK_ALIGNER_TX_0),//input [7:0]         
    .P_CIM_DYN_DLY_SEL_RX                   (P_CIM_DYN_DLY_SEL_RX_0),//input               
    .P_CIM_DYN_DLY_SEL_TX                   (P_CIM_DYN_DLY_SEL_TX_0),//input               
    .P_CIM_START_ALIGN_RX                   (P_CIM_START_ALIGN_RX_0),//input               
    .P_CIM_START_ALIGN_TX                   (P_CIM_START_ALIGN_TX_0),//input               
    //New Added                                      
    .MCB_RCLK                               (MCB_RCLK_0            ),//input               
    .SYNC                                   (SYNC_0                ),//input               
    .RATE_CHANGE                            (RATE_CHANGE_0         ),//input               
    .PLL_LOCK_SEL                           (PLL_LOCK_SEL_0        ),//input               
    //cin and cout                           
    .LANE_CIN_BUS_FORWARD                   (LANE_CIN_BUS_FORWARD_0),//input [18:0]        
    .APATTERN_STATUS_CIN                    (APATTERN_STATUS_CIN_0 ),//input               
    //From PLL                                  
    .CLK_TXP                                (CLK_TXP_0             ),//input               
    .CLK_TXN                                (CLK_TXN_0             ),//input               
    .CLK_RX0                                (CLK_RX0_0             ),//input               
    .CLK_RX90                               (CLK_RX90_0            ),//input               
    .CLK_RX180                              (CLK_RX180_0           ),//input               
    .CLK_RX270                              (CLK_RX270_0           ),//input               
    .PLL_PD_I                               (PLL_PD_I_0            ),//input               
    .PLL_RESET_I                            (PLL_RESET_I_0         ),//input               
    .PLL_REFCLK_I                           (PLL_REFCLK_I_0        ),//input               
    .PLL_RES_TRIM_I                         (PLL_RES_TRIM_I_0      ) //input [5:0]         
);
end
else begin:CHANNEL0_NULL //output default value to be done
    assign      P_TX_SDN_0                      = 1'b0 ;//output              
    assign      P_TX_SDP_0                      = 1'b0 ;//output              
    assign      P_PCS_RX_MCB_STATUS_0           = 1'b0 ;//output              
    assign      P_PCS_LSM_SYNCED_0              = 1'b0 ;//output              
    assign      P_CFG_READY_0                   = 1'b0 ;//output              
    assign      P_CFG_RDATA_0                   = 8'b0 ;//output [7:0]        
    assign      P_CFG_INT_0                     = 1'b0 ;//output              
    assign      P_RDATA_0                       = 47'b0;//output [46:0]       
    assign      P_RCLK2FABRIC_0                 = 1'b0 ;//output              
    assign      P_TCLK2FABRIC_0                 = 1'b0 ;//output              
    assign      P_RX_SIGDET_STATUS_0            = 1'b0 ;//output              
    assign      P_RX_SATA_COMINIT_0             = 1'b0 ;//output              
    assign      P_RX_SATA_COMWAKE_0             = 1'b0 ;//output              
    assign      P_RX_LS_DATA_0                  = 1'b0 ;//output              
    assign      P_RX_READY_0                    = 1'b0 ;//output              
    assign      P_TEST_STATUS_0                 = 20'b0;//output [19:0]       
    assign      P_TX_RXDET_STATUS_0             = 1'b0 ;//output              
    assign      P_CA_ALIGN_RX_0                 = 1'b0 ;//output              
    assign      P_CA_ALIGN_TX_0                 = 1'b0 ;//output              
    assign      PMA_RCLK_0                      = 1'b0 ;//output       	    
    assign      TXPCLK_PLL_0                    = 1'b0 ;//output              
    assign      LANE_COUT_BUS_FORWARD_0         = 19'b0;//output [18:0]       
    assign      APATTERN_STATUS_COUT_0          = 1'b0 ;//output              
end
endgenerate

//--------CHANNEL1 instance--------//
generate
if(CHANNEL1_EN == "TRUE") begin:CHANNEL1_ENABLE
GTP_HSSTLP_LANE#(
    .MUX_BIAS                                    (CH1_MUX_BIAS                                      ),//0 to 7; don't support simulation
    .PD_CLK                                      (CH1_PD_CLK                                        ),//0 to 1
    .REG_SYNC                                    (CH1_REG_SYNC                                      ),//0 to 1
    .REG_SYNC_OW                                 (CH1_REG_SYNC_OW                                   ),//0 to 1
    .PLL_LOCK_OW                                 (CH1_PLL_LOCK_OW                                   ),//0 to 1
    .PLL_LOCK_OW_EN                              (CH1_PLL_LOCK_OW_EN                                ),//0 to 1
    //pcs
    .PCS_SLAVE                                   (PCS_CH1_SLAVE                                     ),
    .PCS_BYPASS_WORD_ALIGN                       (PCS_CH1_BYPASS_WORD_ALIGN                         ),//TRUE, FALSE; for bypass word alignment
    .PCS_BYPASS_DENC                             (PCS_CH1_BYPASS_DENC                               ),//TRUE, FALSE; for bypass 8b/10b decoder
    .PCS_BYPASS_BONDING                          (PCS_CH1_BYPASS_BONDING                            ),//TRUE, FALSE; for bypass channel bonding
    .PCS_BYPASS_CTC                              (PCS_CH1_BYPASS_CTC                                ),//TRUE, FALSE; for bypass ctc
    .PCS_BYPASS_GEAR                             (PCS_CH1_BYPASS_GEAR                               ),//TRUE, FALSE; for bypass Rx Gear
    .PCS_BYPASS_BRIDGE                           (PCS_CH1_BYPASS_BRIDGE                             ),//TRUE, FALSE; for bypass Rx Bridge unit
    .PCS_BYPASS_BRIDGE_FIFO                      (PCS_CH1_BYPASS_BRIDGE_FIFO                        ),//TRUE, FALSE; for bypass Rx Bridge FIFO
    .PCS_DATA_MODE                               (PCS_CH1_DATA_MODE                                 ),//"X8","X10","X16","X20"
    .PCS_RX_POLARITY_INV                         (PCS_CH1_RX_POLARITY_INV                           ),//"DELAY","BIT_POLARITY_INVERION","BIT_REVERSAL","BOTH"
    .PCS_ALIGN_MODE                              (PCS_CH1_ALIGN_MODE                                ),//1GB, 10GB, RAPIDIO, OUTSIDE
    .PCS_SAMP_16B                                (PCS_CH1_SAMP_16B                                  ),//"X20",X16
    .PCS_FARLP_PWR_REDUCTION                     (PCS_CH1_FARLP_PWR_REDUCTION                       ),//TRUE, FALSE;
    .PCS_COMMA_REG0                              (PCS_CH1_COMMA_REG0                                ),//0 to 1023
    .PCS_COMMA_MASK                              (PCS_CH1_COMMA_MASK                                ),//0 to 1023
    .PCS_CEB_MODE                                (PCS_CH1_CEB_MODE                                  ),//"10GB" "RAPIDIO" "OUTSIDE"
    .PCS_CTC_MODE                                (PCS_CH1_CTC_MODE                                  ),//1SKIP, 2SKIP, PCIE_2BYTE, 4SKIP
    .PCS_A_REG                                   (PCS_CH1_A_REG                                     ),//0 to 255
    .PCS_GE_AUTO_EN                              (PCS_CH1_GE_AUTO_EN                                ),//TRUE, FALSE;
    .PCS_SKIP_REG0                               (PCS_CH1_SKIP_REG0                                 ),//0 to 1023
    .PCS_SKIP_REG1                               (PCS_CH1_SKIP_REG1                                 ),//0 to 1023
    .PCS_SKIP_REG2                               (PCS_CH1_SKIP_REG2                                 ),//0 to 1023
    .PCS_SKIP_REG3                               (PCS_CH1_SKIP_REG3                                 ),//0 to 1023
    .PCS_DEC_DUAL                                (PCS_CH1_DEC_DUAL                                  ),//TRUE, FALSE;
    .PCS_SPLIT                                   (PCS_CH1_SPLIT                                     ),//TRUE, FALSE;
    .PCS_FIFOFLAG_CTC                            (PCS_CH1_FIFOFLAG_CTC                              ),//TRUE, FALSE;
    .PCS_COMMA_DET_MODE                          (PCS_CH1_COMMA_DET_MODE                            ),//"RX_CLK_SLIP" "COMMA_PATTERN"
    .PCS_ERRDETECT_SILENCE                       (PCS_CH1_ERRDETECT_SILENCE                         ),//TRUE, FALSE;
    .PCS_PMA_RCLK_POLINV                         (PCS_CH1_PMA_RCLK_POLINV                           ),//"PMA_RCLK" "REVERSE_OF_PMA_RCLK"
    .PCS_PCS_RCLK_SEL                            (PCS_CH1_PCS_RCLK_SEL                              ),//"PMA_RCLK" "PMA_TCLK" "RCLK"
    .PCS_CB_RCLK_SEL                             (PCS_CH1_CB_RCLK_SEL                               ),//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK"
    .PCS_AFTER_CTC_RCLK_SEL                      (PCS_CH1_AFTER_CTC_RCLK_SEL                        ),//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK" "RCLK2"
    .PCS_RCLK_POLINV                             (PCS_CH1_RCLK_POLINV                               ),//"RCLK" "REVERSE_OF_RCLK"
    .PCS_BRIDGE_RCLK_SEL                         (PCS_CH1_BRIDGE_RCLK_SEL                           ),//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK" "RCLK"
    .PCS_PCS_RCLK_EN                             (PCS_CH1_PCS_RCLK_EN                               ),//TRUE, FALSE;
    .PCS_CB_RCLK_EN                              (PCS_CH1_CB_RCLK_EN                                ),//TRUE, FALSE;
    .PCS_AFTER_CTC_RCLK_EN                       (PCS_CH1_AFTER_CTC_RCLK_EN                         ),//TRUE, FALSE;
    .PCS_AFTER_CTC_RCLK_EN_GB                    (PCS_CH1_AFTER_CTC_RCLK_EN_GB                      ),//TRUE, FALSE;
    .PCS_PCS_RX_RSTN                             (PCS_CH1_PCS_RX_RSTN                               ),//TRUE, FALSE; for PCS Receiver Reset
    .PCS_PCIE_SLAVE                              (PCS_CH1_PCIE_SLAVE                                ),//"MASTER","SLAVE"
    .PCS_RX_64B66B_67B                           (PCS_CH1_RX_64B66B_67B                             ),//"NORMAL" "64B_66B" "64B_67B"
    .PCS_RX_BRIDGE_CLK_POLINV                    (PCS_CH1_RX_BRIDGE_CLK_POLINV                      ),//"RX_BRIDGE_CLK" "REVERSE_OF_RX_BRIDGE_CLK"
    .PCS_PCS_CB_RSTN                             (PCS_CH1_PCS_CB_RSTN                               ),//TRUE, FALSE; for PCS CB Reset
    .PCS_TX_BRIDGE_GEAR_SEL                      (PCS_CH1_TX_BRIDGE_GEAR_SEL                        ),//TRUE: tx gear priority, FALSE:tx bridge unit priority
    .PCS_TX_BYPASS_BRIDGE_UINT                   (PCS_CH1_TX_BYPASS_BRIDGE_UINT                     ),//TRUE, FALSE; for bypass 
    .PCS_TX_BYPASS_BRIDGE_FIFO                   (PCS_CH1_TX_BYPASS_BRIDGE_FIFO                     ),//TRUE, FALSE; for bypass Tx Bridge FIFO
    .PCS_TX_BYPASS_GEAR                          (PCS_CH1_TX_BYPASS_GEAR                            ),//TRUE, FALSE;
    .PCS_TX_BYPASS_ENC                           (PCS_CH1_TX_BYPASS_ENC                             ),//TRUE, FALSE;
    .PCS_TX_BYPASS_BIT_SLIP                      (PCS_CH1_TX_BYPASS_BIT_SLIP                        ),//TRUE, FALSE;
    .PCS_TX_GEAR_SPLIT                           (PCS_CH1_TX_GEAR_SPLIT                             ),//TRUE, FALSE;
    .PCS_TX_DRIVE_REG_MODE                       (PCS_CH1_TX_DRIVE_REG_MODE                         ),//"NO_CHANGE" "EN_POLARIY_REV" "EN_BIT_REV" "EN_BOTH"
    .PCS_TX_BIT_SLIP_CYCLES                      (PCS_CH1_TX_BIT_SLIP_CYCLES                        ),//o to 31
    .PCS_INT_TX_MASK_0                           (PCS_CH1_INT_TX_MASK_0                             ),//TRUE, FALSE;
    .PCS_INT_TX_MASK_1                           (PCS_CH1_INT_TX_MASK_1                             ),//TRUE, FALSE;
    .PCS_INT_TX_MASK_2                           (PCS_CH1_INT_TX_MASK_2                             ),//TRUE, FALSE;
    .PCS_INT_TX_CLR_0                            (PCS_CH1_INT_TX_CLR_0                              ),//TRUE, FALSE;
    .PCS_INT_TX_CLR_1                            (PCS_CH1_INT_TX_CLR_1                              ),//TRUE, FALSE;
    .PCS_INT_TX_CLR_2                            (PCS_CH1_INT_TX_CLR_2                              ),//TRUE, FALSE;
    .PCS_TX_PMA_TCLK_POLINV                      (PCS_CH1_TX_PMA_TCLK_POLINV                        ),//"PMA_TCLK" "REVERSE_OF_PMA_TCLK"
    .PCS_TX_PCS_CLK_EN_SEL                       (PCS_CH1_TX_PCS_CLK_EN_SEL                         ),//TRUE, FALSE;
    .PCS_TX_BRIDGE_TCLK_SEL                      (PCS_CH1_TX_BRIDGE_TCLK_SEL                        ),//"PCS_TCLK" "TCLK"
    .PCS_TX_TCLK_POLINV                          (PCS_CH1_TX_TCLK_POLINV                            ),//"TCLK" "REVERSE_OF_TCLK"
    .PCS_PCS_TCLK_SEL                            (PCS_CH1_PCS_TCLK_SEL                              ),//"PMA_TCLK" "TCLK"
    .PCS_TX_PCS_TX_RSTN                          (PCS_CH1_TX_PCS_TX_RSTN                            ),//TRUE, FALSE; for PCS Transmitter Reset
    .PCS_TX_SLAVE                                (PCS_CH1_TX_SLAVE                                  ),//"MASTER" "SLAVE"
    .PCS_TX_GEAR_CLK_EN_SEL                      (PCS_CH1_TX_GEAR_CLK_EN_SEL                        ),//TRUE, FALSE;
    .PCS_DATA_WIDTH_MODE                         (PCS_CH1_DATA_WIDTH_MODE                           ),//"X8" "X10" "X16" "X20"
    .PCS_TX_64B66B_67B                           (PCS_CH1_TX_64B66B_67B                             ),//"NORMAL" "64B_66B" "64B_67B"
    .PCS_GEAR_TCLK_SEL                           (PCS_CH1_GEAR_TCLK_SEL                             ),//"PMA_TCLK" "TCLK2"
    .PCS_TX_TCLK2FABRIC_SEL                      (PCS_CH1_TX_TCLK2FABRIC_SEL                        ),//TRUE, FALSE
    .PCS_TX_OUTZZ                                (PCS_CH1_TX_OUTZZ                                  ),//TRUE, FALSE
    .PCS_ENC_DUAL                                (PCS_CH1_ENC_DUAL                                  ),//TRUE, FALSE
    .PCS_TX_BITSLIP_DATA_MODE                    (PCS_CH1_TX_BITSLIP_DATA_MODE                      ),//"X10" "X20"
    .PCS_TX_BRIDGE_CLK_POLINV                    (PCS_CH1_TX_BRIDGE_CLK_POLINV                      ),//"TX_BRIDGE_CLK" "REVERSE_OF_TX_BRIDGE_CLK"
    .PCS_COMMA_REG1                              (PCS_CH1_COMMA_REG1                                ),//0 to 1023
    .PCS_RAPID_IMAX                              (PCS_CH1_RAPID_IMAX                                ),//0 to 7
    .PCS_RAPID_VMIN_1                            (PCS_CH1_RAPID_VMIN_1                              ),//0 to 255
    .PCS_RAPID_VMIN_2                            (PCS_CH1_RAPID_VMIN_2                              ),//0 to 255
    .PCS_RX_PRBS_MODE                            (PCS_CH1_RX_PRBS_MODE                              ),//DISABLE PRBS_7 PRBS_15 PRBS_23 PRBS_31
    .PCS_RX_ERRCNT_CLR                           (PCS_CH1_RX_ERRCNT_CLR                             ),//TRUE, FALSE
    .PCS_PRBS_ERR_LPBK                           (PCS_CH1_PRBS_ERR_LPBK                             ),//TRUE, FALSE
    .PCS_TX_PRBS_MODE                            (PCS_CH1_TX_PRBS_MODE                              ),//DISABLE PRBS_7 PRBS_15 PRBS_23 PRBS_31 LONG_1 LONG_0 20UI D10_2 PCIE
    .PCS_TX_INSERT_ER                            (PCS_CH1_TX_INSERT_ER                              ),//TRUE, FALSE
    .PCS_ENABLE_PRBS_GEN                         (PCS_CH1_ENABLE_PRBS_GEN                           ),//TRUE, FALSE
    .PCS_DEFAULT_RADDR                           (PCS_CH1_DEFAULT_RADDR                             ),//0 to 15
    .PCS_MASTER_CHECK_OFFSET                     (PCS_CH1_MASTER_CHECK_OFFSET                       ),//0 to 15
    .PCS_DELAY_SET                               (PCS_CH1_DELAY_SET                                 ),//0 to 15
    .PCS_SEACH_OFFSET                            (PCS_CH1_SEACH_OFFSET                              ),//"20BIT" 30BIT" "40BIT" "50BIT" "60BIT" "70BIT" "80BIT"
    .PCS_CEB_RAPIDLS_MMAX                        (PCS_CH1_CEB_RAPIDLS_MMAX                          ),//0 to 7
    .PCS_CTC_AFULL                               (PCS_CH1_CTC_AFULL                                 ),//0 to 31
    .PCS_CTC_AEMPTY                              (PCS_CH1_CTC_AEMPTY                                ),//0 to 31
    .PCS_CTC_CONTI_SKP_SET                       (PCS_CH1_CTC_CONTI_SKP_SET                         ),//0 to 1
    .PCS_FAR_LOOP                                (PCS_CH1_FAR_LOOP                                  ),//TRUE, FALSE
    .PCS_NEAR_LOOP                               (PCS_CH1_NEAR_LOOP                                 ),//TRUE, FALSE
    .PCS_PMA_TX2RX_PLOOP_EN                      (PCS_CH1_PMA_TX2RX_PLOOP_EN                        ),//TRUE, FALSE
    .PCS_PMA_TX2RX_SLOOP_EN                      (PCS_CH1_PMA_TX2RX_SLOOP_EN                        ),//TRUE, FALSE
    .PCS_PMA_RX2TX_PLOOP_EN                      (PCS_CH1_PMA_RX2TX_PLOOP_EN                        ),//TRUE, FALSE
    .PCS_INT_RX_MASK_0                           (PCS_CH1_INT_RX_MASK_0                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_1                           (PCS_CH1_INT_RX_MASK_1                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_2                           (PCS_CH1_INT_RX_MASK_2                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_3                           (PCS_CH1_INT_RX_MASK_3                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_4                           (PCS_CH1_INT_RX_MASK_4                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_5                           (PCS_CH1_INT_RX_MASK_5                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_6                           (PCS_CH1_INT_RX_MASK_6                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_7                           (PCS_CH1_INT_RX_MASK_7                             ),//TRUE, FALSE
    .PCS_INT_RX_CLR_0                            (PCS_CH1_INT_RX_CLR_0                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_1                            (PCS_CH1_INT_RX_CLR_1                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_2                            (PCS_CH1_INT_RX_CLR_2                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_3                            (PCS_CH1_INT_RX_CLR_3                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_4                            (PCS_CH1_INT_RX_CLR_4                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_5                            (PCS_CH1_INT_RX_CLR_5                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_6                            (PCS_CH1_INT_RX_CLR_6                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_7                            (PCS_CH1_INT_RX_CLR_7                              ),//TRUE, FALSE
    .PCS_CA_RSTN_RX                              (PCS_CH1_CA_RSTN_RX                                ),//TRUE, FALSE; for Rx CLK Aligner Reset
    .PCS_CA_DYN_DLY_EN_RX                        (PCS_CH1_CA_DYN_DLY_EN_RX                          ),//TRUE, FALSE
    .PCS_CA_DYN_DLY_SEL_RX                       (PCS_CH1_CA_DYN_DLY_SEL_RX                         ),//TRUE, FALSE
    .PCS_CA_RX                                   (PCS_CH1_CA_RX                                     ),//0 to 255
    .PCS_CA_RSTN_TX                              (PCS_CH1_CA_RSTN_TX                                ),//TRUE, FALSE
    .PCS_CA_DYN_DLY_EN_TX                        (PCS_CH1_CA_DYN_DLY_EN_TX                          ),//TRUE, FALSE
    .PCS_CA_DYN_DLY_SEL_TX                       (PCS_CH1_CA_DYN_DLY_SEL_TX                         ),//TRUE, FALSE
    .PCS_CA_TX                                   (PCS_CH1_CA_TX                                     ),//0 to 255
    .PCS_RXPRBS_PWR_REDUCTION                    (PCS_CH1_RXPRBS_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_WDALIGN_PWR_REDUCTION                   (PCS_CH1_WDALIGN_PWR_REDUCTION                     ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXDEC_PWR_REDUCTION                     (PCS_CH1_RXDEC_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXCB_PWR_REDUCTION                      (PCS_CH1_RXCB_PWR_REDUCTION                        ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXCTC_PWR_REDUCTION                     (PCS_CH1_RXCTC_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXGEAR_PWR_REDUCTION                    (PCS_CH1_RXGEAR_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXBRG_PWR_REDUCTION                     (PCS_CH1_RXBRG_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXTEST_PWR_REDUCTION                    (PCS_CH1_RXTEST_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXBRG_PWR_REDUCTION                     (PCS_CH1_TXBRG_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXGEAR_PWR_REDUCTION                    (PCS_CH1_TXGEAR_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXENC_PWR_REDUCTION                     (PCS_CH1_TXENC_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXBSLP_PWR_REDUCTION                    (PCS_CH1_TXBSLP_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXPRBS_PWR_REDUCTION                    (PCS_CH1_TXPRBS_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    //pma_rx                                                                                      
    .PMA_REG_RX_PD                               (PMA_CH1_REG_RX_PD                                 ),//ON, OFF;
    .PMA_REG_RX_PD_EN                            (PMA_CH1_REG_RX_PD_EN                              ),//TRUE, FALSE
    .PMA_REG_RX_RESERVED_2                       (PMA_CH1_REG_RX_RESERVED_2                         ),//TRUE, FALSE
    .PMA_REG_RX_RESERVED_3                       (PMA_CH1_REG_RX_RESERVED_3                         ),//TRUE, FALSE
    .PMA_REG_RX_DATAPATH_PD                      (PMA_CH1_REG_RX_DATAPATH_PD                        ),//ON, OFF;
    .PMA_REG_RX_DATAPATH_PD_EN                   (PMA_CH1_REG_RX_DATAPATH_PD_EN                     ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_PD                        (PMA_CH1_REG_RX_SIGDET_PD                          ),//ON, OFF;
    .PMA_REG_RX_SIGDET_PD_EN                     (PMA_CH1_REG_RX_SIGDET_PD_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_DCC_RST_N                        (PMA_CH1_REG_RX_DCC_RST_N                          ),//TRUE, FALSE;
    .PMA_REG_RX_DCC_RST_N_EN                     (PMA_CH1_REG_RX_DCC_RST_N_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_CDR_RST_N                        (PMA_CH1_REG_RX_CDR_RST_N                          ),//TRUE, FALSE;
    .PMA_REG_RX_CDR_RST_N_EN                     (PMA_CH1_REG_RX_CDR_RST_N_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_RST_N                     (PMA_CH1_REG_RX_SIGDET_RST_N                       ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_RST_N_EN                  (PMA_CH1_REG_RX_SIGDET_RST_N_EN                    ),//TRUE, FALSE;
    .PMA_REG_RXPCLK_SLIP                         (PMA_CH1_REG_RXPCLK_SLIP                           ),//TRUE, FALSE;
    .PMA_REG_RXPCLK_SLIP_OW                      (PMA_CH1_REG_RXPCLK_SLIP_OW                        ),//TRUE, FALSE;
    .PMA_REG_RX_PCLKSWITCH_RST_N                 (PMA_CH1_REG_RX_PCLKSWITCH_RST_N                   ),//TRUE, FALSE; for TX PMA Reset
    .PMA_REG_RX_PCLKSWITCH_RST_N_EN              (PMA_CH1_REG_RX_PCLKSWITCH_RST_N_EN                ),//TRUE, FALSE;
    .PMA_REG_RX_PCLKSWITCH                       (PMA_CH1_REG_RX_PCLKSWITCH                         ),//TRUE, FALSE;
    .PMA_REG_RX_PCLKSWITCH_EN                    (PMA_CH1_REG_RX_PCLKSWITCH_EN                      ),//TRUE, FALSE;
    .PMA_REG_RX_HIGHZ                            (PMA_CH1_REG_RX_HIGHZ                              ),//TRUE, FALSE;
    .PMA_REG_RX_HIGHZ_EN                         (PMA_CH1_REG_RX_HIGHZ_EN                           ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_CLK_WINDOW                (PMA_CH1_REG_RX_SIGDET_CLK_WINDOW                  ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_CLK_WINDOW_OW             (PMA_CH1_REG_RX_SIGDET_CLK_WINDOW_OW               ),//TRUE, FALSE;
    .PMA_REG_RX_PD_BIAS_RX                       (PMA_CH1_REG_RX_PD_BIAS_RX                         ),//TRUE, FALSE;
    .PMA_REG_RX_PD_BIAS_RX_OW                    (PMA_CH1_REG_RX_PD_BIAS_RX_OW                      ),//TRUE, FALSE;
    .PMA_REG_RX_RESET_N                          (PMA_CH1_REG_RX_RESET_N                            ),//TRUE, FALSE;
    .PMA_REG_RX_RESET_N_OW                       (PMA_CH1_REG_RX_RESET_N_OW                         ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_29_28                   (PMA_CH1_REG_RX_RESERVED_29_28                     ),//0 to 3
    .PMA_REG_RX_BUSWIDTH                         (PMA_CH1_REG_RX_BUSWIDTH                           ),//"8BIT" "10BIT" "16BIT" "20BIT"
    .PMA_REG_RX_BUSWIDTH_EN                      (PMA_CH1_REG_RX_BUSWIDTH_EN                        ),//TRUE, FALSE;
    .PMA_REG_RX_RATE                             (PMA_CH1_REG_RX_RATE                               ),//"DIV4" "DIV2" "DIV1" "MUL2"
    .PMA_REG_RX_RESERVED_36                      (PMA_CH1_REG_RX_RESERVED_36                        ),//TRUE, FALSE;
    .PMA_REG_RX_RATE_EN                          (PMA_CH1_REG_RX_RATE_EN                            ),//TRUE, FALSE;
    .PMA_REG_RX_RES_TRIM                         (PMA_CH1_REG_RX_RES_TRIM                           ),//0 to 63
    .PMA_REG_RX_RESERVED_44                      (PMA_CH1_REG_RX_RESERVED_44                        ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_45                      (PMA_CH1_REG_RX_RESERVED_45                        ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_STATUS_EN                 (PMA_CH1_REG_RX_SIGDET_STATUS_EN                   ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_48_47                   (PMA_CH1_REG_RX_RESERVED_48_47                     ),//0 to 3
    .PMA_REG_RX_ICTRL_SIGDET                     (PMA_CH1_REG_RX_ICTRL_SIGDET                       ),//0 to 15
    .PMA_REG_CDR_READY_THD                       (PMA_CH1_REG_CDR_READY_THD                         ),//0 to 4095
    .PMA_REG_RX_RESERVED_65                      (PMA_CH1_REG_RX_RESERVED_65                        ),//TRUE, FALSE;
    .PMA_REG_RX_PCLK_EDGE_SEL                    (PMA_CH1_REG_RX_PCLK_EDGE_SEL                      ),//"POS_EDGE" "NEG_EDGE"
    .PMA_REG_RX_PIBUF_IC                         (PMA_CH1_REG_RX_PIBUF_IC                           ),//0 to 3
    .PMA_REG_RX_RESERVED_69                      (PMA_CH1_REG_RX_RESERVED_69                        ),//TRUE, FALSE; 
    .PMA_REG_RX_DCC_IC_RX                        (PMA_CH1_REG_RX_DCC_IC_RX                          ),//0 to 3
    .PMA_REG_CDR_READY_CHECK_CTRL                (PMA_CH1_REG_CDR_READY_CHECK_CTRL                  ),//0 to 3
    .PMA_REG_RX_ICTRL_TRX                        (PMA_CH1_REG_RX_ICTRL_TRX                          ),//"87_5PCT" "100PCT" "112_5PCT" "125PCT"
    .PMA_REG_RX_RESERVED_77_76                   (PMA_CH1_REG_RX_RESERVED_77_76                     ),//0 to 3
    .PMA_REG_RX_RESERVED_79_78                   (PMA_CH1_REG_RX_RESERVED_79_78                     ),//0 to 3
    .PMA_REG_RX_RESERVED_81_80                   (PMA_CH1_REG_RX_RESERVED_81_80                     ),//0 to 3
    .PMA_REG_RX_ICTRL_PIBUF                      (PMA_CH1_REG_RX_ICTRL_PIBUF                        ),//"87_5PCT" "100PCT" "112_5PCT" "125PCT"
    .PMA_REG_RX_ICTRL_PI                         (PMA_CH1_REG_RX_ICTRL_PI                           ),//"87_5PCT" "100PCT" "112_5PCT" "125PCT"
    .PMA_REG_RX_ICTRL_DCC                        (PMA_CH1_REG_RX_ICTRL_DCC                          ),//"87_5PCT" "100PCT" "112_5PCT" "125PCT"
    .PMA_REG_RX_RESERVED_89_88                   (PMA_CH1_REG_RX_RESERVED_89_88                     ),//0 to 3
    .PMA_REG_TX_RATE                             (PMA_CH1_REG_TX_RATE                               ),//"DIV4" "DIV2" "DIV1" "MUL2"
    .PMA_REG_RX_RESERVED_92                      (PMA_CH1_REG_RX_RESERVED_92                        ),//TRUE, FALSE; 
    .PMA_REG_TX_RATE_EN                          (PMA_CH1_REG_TX_RATE_EN                            ),//TRUE, FALSE; 
    .PMA_REG_RX_TX2RX_PLPBK_RST_N                (PMA_CH1_REG_RX_TX2RX_PLPBK_RST_N                  ),//TRUE, FALSE; for tx2rx pma parallel loop back Reset
    .PMA_REG_RX_TX2RX_PLPBK_RST_N_EN             (PMA_CH1_REG_RX_TX2RX_PLPBK_RST_N_EN               ),//TRUE, FALSE; 
    .PMA_REG_RX_TX2RX_PLPBK_EN                   (PMA_CH1_REG_RX_TX2RX_PLPBK_EN                     ),//TRUE, FALSE; for tx2rx pma parallel loop back enable
    .PMA_REG_TXCLK_SEL                           (PMA_CH1_REG_TXCLK_SEL                             ),//"PLL" "RXCLK"
    .PMA_REG_RX_DATA_POLARITY                    (PMA_CH1_REG_RX_DATA_POLARITY                      ),//"NORMAL" "REVERSE"
    .PMA_REG_RX_ERR_INSERT                       (PMA_CH1_REG_RX_ERR_INSERT                         ),//TRUE, FALSE;
    .PMA_REG_UDP_CHK_EN                          (PMA_CH1_REG_UDP_CHK_EN                            ),//TRUE, FALSE;
    .PMA_REG_PRBS_SEL                            (PMA_CH1_REG_PRBS_SEL                              ),//"PRBS7" "PRBS15" "PRBS23" "PRBS31"
    .PMA_REG_PRBS_CHK_EN                         (PMA_CH1_REG_PRBS_CHK_EN                           ),//TRUE, FALSE;
    .PMA_REG_PRBS_CHK_WIDTH_SEL                  (PMA_CH1_REG_PRBS_CHK_WIDTH_SEL                    ),//"8BIT" "10BIT" "16BIT" "20BIT"
    .PMA_REG_BIST_CHK_PAT_SEL                    (PMA_CH1_REG_BIST_CHK_PAT_SEL                      ),//"PRBS" "CONSTANT"
    .PMA_REG_LOAD_ERR_CNT                        (PMA_CH1_REG_LOAD_ERR_CNT                          ),//TRUE, FALSE;
    .PMA_REG_CHK_COUNTER_EN                      (PMA_CH1_REG_CHK_COUNTER_EN                        ),//TRUE, FALSE;
    .PMA_REG_CDR_PROP_GAIN                       (PMA_CH1_REG_CDR_PROP_GAIN                         ),//0 to 7
    .PMA_REG_CDR_PROP_TURBO_GAIN                 (PMA_CH1_REG_CDR_PROP_TURBO_GAIN                   ),//0 to 7
    .PMA_REG_CDR_INT_GAIN                        (PMA_CH1_REG_CDR_INT_GAIN                          ),//0 to 7
    .PMA_REG_CDR_INT_TURBO_GAIN                  (PMA_CH1_REG_CDR_INT_TURBO_GAIN                    ),//0 to 7
    .PMA_REG_CDR_INT_SAT_MAX                     (PMA_CH1_REG_CDR_INT_SAT_MAX                       ),//0 to 1023
    .PMA_REG_CDR_INT_SAT_MIN                     (PMA_CH1_REG_CDR_INT_SAT_MIN                       ),//0 to 1023
    .PMA_REG_CDR_INT_RST                         (PMA_CH1_REG_CDR_INT_RST                           ),//TRUE, FALSE;
    .PMA_REG_CDR_INT_RST_OW                      (PMA_CH1_REG_CDR_INT_RST_OW                        ),//TRUE, FALSE;
    .PMA_REG_CDR_PROP_RST                        (PMA_CH1_REG_CDR_PROP_RST                          ),//TRUE, FALSE;
    .PMA_REG_CDR_PROP_RST_OW                     (PMA_CH1_REG_CDR_PROP_RST_OW                       ),//TRUE, FALSE;
    .PMA_REG_CDR_LOCK_RST                        (PMA_CH1_REG_CDR_LOCK_RST                          ),//TRUE, FALSE; for CDR LOCK Counter Reset
    .PMA_REG_CDR_LOCK_RST_OW                     (PMA_CH1_REG_CDR_LOCK_RST_OW                       ),//TRUE, FALSE;
    .PMA_REG_CDR_RX_PI_FORCE_SEL                 (PMA_CH1_REG_CDR_RX_PI_FORCE_SEL                   ),//0,1
    .PMA_REG_CDR_RX_PI_FORCE_D                   (PMA_CH1_REG_CDR_RX_PI_FORCE_D                     ),//0 to 255
    .PMA_REG_CDR_LOCK_TIMER                      (PMA_CH1_REG_CDR_LOCK_TIMER                        ),//"0_8U" "1_2U" "1_6U" "2_4U" 3_2U" "4_8U" "12_8U" "25_6U"
    .PMA_REG_CDR_TURBO_MODE_TIMER                (PMA_CH1_REG_CDR_TURBO_MODE_TIMER                  ),//0 to 3
    .PMA_REG_CDR_LOCK_VAL                        (PMA_CH1_REG_CDR_LOCK_VAL                          ),//TRUE, FALSE;
    .PMA_REG_CDR_LOCK_OW                         (PMA_CH1_REG_CDR_LOCK_OW                           ),//TRUE, FALSE;
    .PMA_REG_CDR_INT_SAT_DET_EN                  (PMA_CH1_REG_CDR_INT_SAT_DET_EN                    ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_AUTO_DIS                    (PMA_CH1_REG_CDR_SAT_AUTO_DIS                      ),//TRUE, FALSE;
    .PMA_REG_CDR_GAIN_AUTO                       (PMA_CH1_REG_CDR_GAIN_AUTO                         ),//TRUE, FALSE;
    .PMA_REG_CDR_TURBO_GAIN_AUTO                 (PMA_CH1_REG_CDR_TURBO_GAIN_AUTO                   ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_171_167                 (PMA_CH1_REG_RX_RESERVED_171_167                   ),//0 to 31
    .PMA_REG_RX_RESERVED_175_172                 (PMA_CH1_REG_RX_RESERVED_175_172                   ),//0 to 31
    .PMA_REG_CDR_SAT_DET_STATUS_EN               (PMA_CH1_REG_CDR_SAT_DET_STATUS_EN                 ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_STATUS_RESET_EN         (PMA_CH1_REG_CDR_SAT_DET_STATUS_RESET_EN           ),//TRUE, FALSE;
    .PMA_REG_CDR_PI_CTRL_RST                     (PMA_CH1_REG_CDR_PI_CTRL_RST                       ),//TRUE, FALSE;
    .PMA_REG_CDR_PI_CTRL_RST_OW                  (PMA_CH1_REG_CDR_PI_CTRL_RST_OW                    ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_RST                     (PMA_CH1_REG_CDR_SAT_DET_RST                       ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_RST_OW                  (PMA_CH1_REG_CDR_SAT_DET_RST_OW                    ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_STICKY_RST              (PMA_CH1_REG_CDR_SAT_DET_STICKY_RST                ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_STICKY_RST_OW           (PMA_CH1_REG_CDR_SAT_DET_STICKY_RST_OW             ),//TRUE, FALSE;
    .PMA_REG_CDR_SIGDET_STATUS_DIS               (PMA_CH1_REG_CDR_SIGDET_STATUS_DIS                 ),//TRUE, FALSE; for sigdet_status is 0 to reset cdr
    .PMA_REG_CDR_SAT_DET_TIMER                   (PMA_CH1_REG_CDR_SAT_DET_TIMER                     ),//0 to 3
    .PMA_REG_CDR_SAT_DET_STATUS_VAL              (PMA_CH1_REG_CDR_SAT_DET_STATUS_VAL                ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_STATUS_OW               (PMA_CH1_REG_CDR_SAT_DET_STATUS_OW                 ),//TRUE, FALSE;
    .PMA_REG_CDR_TURBO_MODE_EN                   (PMA_CH1_REG_CDR_TURBO_MODE_EN                     ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_190                     (PMA_CH1_REG_RX_RESERVED_190                       ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_193_191                 (PMA_CH1_REG_RX_RESERVED_193_191                   ),//0 to 7
    .PMA_REG_CDR_STATUS_FIFO_EN                  (PMA_CH1_REG_CDR_STATUS_FIFO_EN                    ),//TRUE, FALSE;
    .PMA_REG_PMA_TEST_SEL                        (PMA_CH1_REG_PMA_TEST_SEL                          ),//0,1
    .PMA_REG_OOB_COMWAKE_GAP_MIN                 (PMA_CH1_REG_OOB_COMWAKE_GAP_MIN                   ),//0 to 63
    .PMA_REG_OOB_COMWAKE_GAP_MAX                 (PMA_CH1_REG_OOB_COMWAKE_GAP_MAX                   ),//0 to 63
    .PMA_REG_OOB_COMINIT_GAP_MIN                 (PMA_CH1_REG_OOB_COMINIT_GAP_MIN                   ),//0 to 255
    .PMA_REG_OOB_COMINIT_GAP_MAX                 (PMA_CH1_REG_OOB_COMINIT_GAP_MAX                   ),//0 to 255
    .PMA_REG_RX_RESERVED_227_226                 (PMA_CH1_REG_RX_RESERVED_227_226                   ),//0 to 3
    .PMA_REG_COMWAKE_STATUS_CLEAR                (PMA_CH1_REG_COMWAKE_STATUS_CLEAR                  ),//0,1
    .PMA_REG_COMINIT_STATUS_CLEAR                (PMA_CH1_REG_COMINIT_STATUS_CLEAR                  ),//0,1
    .PMA_REG_RX_SYNC_RST_N_EN                    (PMA_CH1_REG_RX_SYNC_RST_N_EN                      ),//TRUE, FALSE;
    .PMA_REG_RX_SYNC_RST_N                       (PMA_CH1_REG_RX_SYNC_RST_N                         ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_233_232                 (PMA_CH1_REG_RX_RESERVED_233_232                   ),//0 to 3
    .PMA_REG_RX_RESERVED_235_234                 (PMA_CH1_REG_RX_RESERVED_235_234                   ),//0 to 3
    .PMA_REG_RX_SATA_COMINIT_OW                  (PMA_CH1_REG_RX_SATA_COMINIT_OW                    ),//TRUE, FALSE;
    .PMA_REG_RX_SATA_COMINIT                     (PMA_CH1_REG_RX_SATA_COMINIT                       ),//TRUE, FALSE;
    .PMA_REG_RX_SATA_COMWAKE_OW                  (PMA_CH1_REG_RX_SATA_COMWAKE_OW                    ),//TRUE, FALSE;
    .PMA_REG_RX_SATA_COMWAKE                     (PMA_CH1_REG_RX_SATA_COMWAKE                       ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_241_240                 (PMA_CH1_REG_RX_RESERVED_241_240                   ),//0 to 3
    .PMA_REG_RX_DCC_DISABLE                      (PMA_CH1_REG_RX_DCC_DISABLE                        ),//TRUE, FALSE; for rx dcc disable control
    .PMA_REG_RX_RESERVED_243                     (PMA_CH1_REG_RX_RESERVED_243                       ),//TRUE, FALSE;
    .PMA_REG_RX_SLIP_SEL_EN                      (PMA_CH1_REG_RX_SLIP_SEL_EN                        ),//TRUE, FALSE;
    .PMA_REG_RX_SLIP_SEL                         (PMA_CH1_REG_RX_SLIP_SEL                           ),//0 to 15
    .PMA_REG_RX_SLIP_EN                          (PMA_CH1_REG_RX_SLIP_EN                            ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_STATUS_SEL                (PMA_CH1_REG_RX_SIGDET_STATUS_SEL                  ),//0 to 7
    .PMA_REG_RX_SIGDET_FSM_RST_N                 (PMA_CH1_REG_RX_SIGDET_FSM_RST_N                   ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_254                     (PMA_CH1_REG_RX_RESERVED_254                       ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_STATUS                    (PMA_CH1_REG_RX_SIGDET_STATUS                      ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_VTH                       (PMA_CH1_REG_RX_SIGDET_VTH                         ),//"45MV" "54MV" "63MV" "72MV"
    .PMA_REG_RX_SIGDET_GRM                       (PMA_CH1_REG_RX_SIGDET_GRM                         ),//0,1,2,3
    .PMA_REG_RX_SIGDET_PULSE_EXT                 (PMA_CH1_REG_RX_SIGDET_PULSE_EXT                   ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_CH2_SEL                   (PMA_CH1_REG_RX_SIGDET_CH2_SEL                     ),//0,1
    .PMA_REG_RX_SIGDET_CH2_CHK_WINDOW            (PMA_CH1_REG_RX_SIGDET_CH2_CHK_WINDOW              ),//0 to 31
    .PMA_REG_RX_SIGDET_CHK_WINDOW_EN             (PMA_CH1_REG_RX_SIGDET_CHK_WINDOW_EN               ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_NOSIG_COUNT_SETTING       (PMA_CH1_REG_RX_SIGDET_NOSIG_COUNT_SETTING         ),//0 to 7
    .PMA_REG_SLIP_FIFO_INV_EN                    (PMA_CH1_REG_SLIP_FIFO_INV_EN                      ),//TRUE, FALSE;
    .PMA_REG_SLIP_FIFO_INV                       (PMA_CH1_REG_SLIP_FIFO_INV                         ),//"POS_EDGE" "NEG_EDGE"
    .PMA_REG_RX_SIGDET_OOB_DET_COUNT_VAL         (PMA_CH1_REG_RX_SIGDET_OOB_DET_COUNT_VAL           ),//0 to 31
    .PMA_REG_RX_SIGDET_4OOB_DET_SEL              (PMA_CH1_REG_RX_SIGDET_4OOB_DET_SEL                ),//0 to 7
    .PMA_REG_RX_RESERVED_285_283                 (PMA_CH1_REG_RX_RESERVED_285_283                   ),//0 to 7
    .PMA_REG_RX_RESERVED_286                     (PMA_CH1_REG_RX_RESERVED_286                       ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_IC_I                      (PMA_CH1_REG_RX_SIGDET_IC_I                        ),//0 to 15
    .PMA_REG_RX_OOB_DETECTOR_RESET_N_OW          (PMA_CH1_REG_RX_OOB_DETECTOR_RESET_N_OW            ),//TRUE, FALSE;
    .PMA_REG_RX_OOB_DETECTOR_RESET_N             (PMA_CH1_REG_RX_OOB_DETECTOR_RESET_N               ),//TRUE, FALSE;for rx oob detector Reset
    .PMA_REG_RX_OOB_DETECTOR_PD_OW               (PMA_CH1_REG_RX_OOB_DETECTOR_PD_OW                 ),//TRUE, FALSE;
    .PMA_REG_RX_OOB_DETECTOR_PD                  (PMA_CH1_REG_RX_OOB_DETECTOR_PD                    ),//TRUE, FALSE;for rx oob detector powerdown
    .PMA_REG_RX_LS_MODE_EN                       (PMA_CH1_REG_RX_LS_MODE_EN                         ),//TRUE, FALSE;for Enable Low-speed mode
    .PMA_REG_ANA_RX_EQ1_R_SET_FB_O_SEL           (PMA_CH1_REG_ANA_RX_EQ1_R_SET_FB_O_SEL             ),//TRUE, FALSE;
    .PMA_REG_ANA_RX_EQ2_R_SET_FB_O_SEL           (PMA_CH1_REG_ANA_RX_EQ2_R_SET_FB_O_SEL             ),//TRUE, FALSE;
    .PMA_REG_RX_EQ1_R_SET_TOP                    (PMA_CH1_REG_RX_EQ1_R_SET_TOP                      ),//0 to 3
    .PMA_REG_RX_EQ1_R_SET_FB                     (PMA_CH1_REG_RX_EQ1_R_SET_FB                       ),//0 to 15
    .PMA_REG_RX_EQ1_C_SET_FB                     (PMA_CH1_REG_RX_EQ1_C_SET_FB                       ),//0 to 15
    .PMA_REG_RX_EQ1_OFF                          (PMA_CH1_REG_RX_EQ1_OFF                            ),//TRUE, FALSE;
    .PMA_REG_RX_EQ2_R_SET_TOP                    (PMA_CH1_REG_RX_EQ2_R_SET_TOP                      ),//0 to 3
    .PMA_REG_RX_EQ2_R_SET_FB                     (PMA_CH1_REG_RX_EQ2_R_SET_FB                       ),//0 to 15
    .PMA_REG_RX_EQ2_C_SET_FB                     (PMA_CH1_REG_RX_EQ2_C_SET_FB                       ),//0 to 15
    .PMA_REG_RX_EQ2_OFF                          (PMA_CH1_REG_RX_EQ2_OFF                            ),//TRUE, FALSE;
    .PMA_REG_EQ_DAC                              (PMA_CH1_REG_EQ_DAC                                ),//0 to 63
    .PMA_REG_RX_ICTRL_EQ                         (PMA_CH1_REG_RX_ICTRL_EQ                           ),//TRUE, FALSE;
    .PMA_REG_EQ_DC_CALIB_EN                      (PMA_CH1_REG_EQ_DC_CALIB_EN                        ),//TRUE, FALSE;
    .PMA_REG_EQ_DC_CALIB_SEL                     (PMA_CH1_REG_EQ_DC_CALIB_SEL                       ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_337_330                 (PMA_CH1_REG_RX_RESERVED_337_330                   ),//0 to 255
    .PMA_REG_RX_RESERVED_345_338                 (PMA_CH1_REG_RX_RESERVED_345_338                   ),//0 to 255
    .PMA_REG_RX_RESERVED_353_346                 (PMA_CH1_REG_RX_RESERVED_353_346                   ),//0 to 255
    .PMA_REG_RX_RESERVED_361_354                 (PMA_CH1_REG_RX_RESERVED_361_354                   ),//0 to 255
    .PMA_CTLE_CTRL_REG_I                         (PMA_CH1_CTLE_CTRL_REG_I                           ),//0 to 15
    .PMA_CTLE_REG_FORCE_SEL_I                    (PMA_CH1_CTLE_REG_FORCE_SEL_I                      ),//TRUE, FALSE;for ctrl self-adaption adjust
    .PMA_CTLE_REG_HOLD_I                         (PMA_CH1_CTLE_REG_HOLD_I                           ),//TRUE, FALSE;
    .PMA_CTLE_REG_INIT_DAC_I                     (PMA_CH1_CTLE_REG_INIT_DAC_I                       ),//0 to 15
    .PMA_CTLE_REG_POLARITY_I                     (PMA_CH1_CTLE_REG_POLARITY_I                       ),//TRUE, FALSE;
    .PMA_CTLE_REG_SHIFTER_GAIN_I                 (PMA_CH1_CTLE_REG_SHIFTER_GAIN_I                   ),//0 to 7
    .PMA_CTLE_REG_THRESHOLD_I                    (PMA_CH1_CTLE_REG_THRESHOLD_I                      ),//0 to 4095
    .PMA_REG_RX_RES_TRIM_EN                      (PMA_CH1_REG_RX_RES_TRIM_EN                        ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_393_389                 (PMA_CH1_REG_RX_RESERVED_393_389                   ),//0 to 31
    .PMA_CFG_RX_LANE_POWERUP                     (PMA_CH1_CFG_RX_LANE_POWERUP                       ),//ON, OFF;for RX_LANE Power-up
    .PMA_CFG_RX_PMA_RSTN                         (PMA_CH1_CFG_RX_PMA_RSTN                           ),//TRUE, FALSE;for RX_PMA Reset
    .PMA_INT_PMA_RX_MASK_0                       (PMA_CH1_INT_PMA_RX_MASK_0                         ),//TRUE, FALSE;
    .PMA_INT_PMA_RX_CLR_0                        (PMA_CH1_INT_PMA_RX_CLR_0                          ),//TRUE, FALSE;
    .PMA_CFG_CTLE_ADP_RSTN                       (PMA_CH1_CFG_CTLE_ADP_RSTN                         ),//TRUE, FALSE;for ctrl Reset
    //pma_tx                                                                                      
    .PMA_REG_TX_PD                               (PMA_CH1_REG_TX_PD                                 ),//ON, OFF;for transmitter power down
    .PMA_REG_TX_PD_OW                            (PMA_CH1_REG_TX_PD_OW                              ),//TRUE, FALSE;
    .PMA_REG_TX_MAIN_PRE_Z                       (PMA_CH1_REG_TX_MAIN_PRE_Z                         ),//TRUE, FALSE;Enable EI for PCIE mode
    .PMA_REG_TX_MAIN_PRE_Z_OW                    (PMA_CH1_REG_TX_MAIN_PRE_Z_OW                      ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_TIMER_SEL                 (PMA_CH1_REG_TX_BEACON_TIMER_SEL                   ),//0 to 3
    .PMA_REG_TX_RXDET_REQ_OW                     (PMA_CH1_REG_TX_RXDET_REQ_OW                       ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_REQ                        (PMA_CH1_REG_TX_RXDET_REQ                          ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_EN_OW                     (PMA_CH1_REG_TX_BEACON_EN_OW                       ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_EN                        (PMA_CH1_REG_TX_BEACON_EN                          ),//TRUE, FALSE;
    .PMA_REG_TX_EI_EN_OW                         (PMA_CH1_REG_TX_EI_EN_OW                           ),//TRUE, FALSE;
    .PMA_REG_TX_EI_EN                            (PMA_CH1_REG_TX_EI_EN                              ),//TRUE, FALSE;
    .PMA_REG_TX_BIT_CONV                         (PMA_CH1_REG_TX_BIT_CONV                           ),//TRUE, FALSE;
    .PMA_REG_TX_RES_CAL                          (PMA_CH1_REG_TX_RES_CAL                            ),//0 to 63
    .PMA_REG_TX_RESERVED_19                      (PMA_CH1_REG_TX_RESERVED_19                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_25_20                   (PMA_CH1_REG_TX_RESERVED_25_20                     ),//0 to 63
    .PMA_REG_TX_RESERVED_33_26                   (PMA_CH1_REG_TX_RESERVED_33_26                     ),//0 to 255
    .PMA_REG_TX_RESERVED_41_34                   (PMA_CH1_REG_TX_RESERVED_41_34                     ),//0 to 255
    .PMA_REG_TX_RESERVED_49_42                   (PMA_CH1_REG_TX_RESERVED_49_42                     ),//0 to 255
    .PMA_REG_TX_RESERVED_57_50                   (PMA_CH1_REG_TX_RESERVED_57_50                     ),//0 to 255
    .PMA_REG_TX_SYNC_OW                          (PMA_CH1_REG_TX_SYNC_OW                            ),//TRUE, FALSE;
    .PMA_REG_TX_SYNC                             (PMA_CH1_REG_TX_SYNC                               ),//TRUE, FALSE;
    .PMA_REG_TX_PD_POST                          (PMA_CH1_REG_TX_PD_POST                            ),//ON, OFF;
    .PMA_REG_TX_PD_POST_OW                       (PMA_CH1_REG_TX_PD_POST_OW                         ),//TRUE, FALSE;
    .PMA_REG_TX_RESET_N_OW                       (PMA_CH1_REG_TX_RESET_N_OW                         ),//TRUE, FALSE;
    .PMA_REG_TX_RESET_N                          (PMA_CH1_REG_TX_RESET_N                            ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_64                      (PMA_CH1_REG_TX_RESERVED_64                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_65                      (PMA_CH1_REG_TX_RESERVED_65                        ),//TRUE, FALSE;
    .PMA_REG_TX_BUSWIDTH_OW                      (PMA_CH1_REG_TX_BUSWIDTH_OW                        ),//TRUE, FALSE;
    .PMA_REG_TX_BUSWIDTH                         (PMA_CH1_REG_TX_BUSWIDTH                           ),//"8BIT" "10BIT" "16BIT" "20BIT"
    .PMA_REG_PLL_READY_OW                        (PMA_CH1_REG_PLL_READY_OW                          ),//TRUE, FALSE;
    .PMA_REG_PLL_READY                           (PMA_CH1_REG_PLL_READY                             ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_72                      (PMA_CH1_REG_TX_RESERVED_72                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_73                      (PMA_CH1_REG_TX_RESERVED_73                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_74                      (PMA_CH1_REG_TX_RESERVED_74                        ),//TRUE, FALSE;
    .PMA_REG_EI_PCLK_DELAY_SEL                   (PMA_CH1_REG_EI_PCLK_DELAY_SEL                     ),//0 to 3
    .PMA_REG_TX_RESERVED_77                      (PMA_CH1_REG_TX_RESERVED_77                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_83_78                   (PMA_CH1_REG_TX_RESERVED_83_78                     ),//0 to 63
    .PMA_REG_TX_RESERVED_89_84                   (PMA_CH1_REG_TX_RESERVED_89_84                     ),//0 to 63
    .PMA_REG_TX_RESERVED_95_90                   (PMA_CH1_REG_TX_RESERVED_95_90                     ),//0 to 63
    .PMA_REG_TX_RESERVED_101_96                  (PMA_CH1_REG_TX_RESERVED_101_96                    ),//0 to 63
    .PMA_REG_TX_RESERVED_107_102                 (PMA_CH1_REG_TX_RESERVED_107_102                   ),//0 to 63
    .PMA_REG_TX_RESERVED_113_108                 (PMA_CH1_REG_TX_RESERVED_113_108                   ),//0 to 63
    .PMA_REG_TX_AMP_DAC0                         (PMA_CH1_REG_TX_AMP_DAC0                           ),//0 to 63
    .PMA_REG_TX_AMP_DAC1                         (PMA_CH1_REG_TX_AMP_DAC1                           ),//0 to 63
    .PMA_REG_TX_AMP_DAC2                         (PMA_CH1_REG_TX_AMP_DAC2                           ),//0 to 63
    .PMA_REG_TX_AMP_DAC3                         (PMA_CH1_REG_TX_AMP_DAC3                           ),//0 to 63
    .PMA_REG_TX_RESERVED_143_138                 (PMA_CH1_REG_TX_RESERVED_143_138                   ),//0 to 63
    .PMA_REG_TX_MARGIN                           (PMA_CH1_REG_TX_MARGIN                             ),//0 to 7
    .PMA_REG_TX_MARGIN_OW                        (PMA_CH1_REG_TX_MARGIN_OW                          ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_149_148                 (PMA_CH1_REG_TX_RESERVED_149_148                   ),//0 to 3
    .PMA_REG_TX_RESERVED_150                     (PMA_CH1_REG_TX_RESERVED_150                       ),//TRUE, FALSE;
    .PMA_REG_TX_SWING                            (PMA_CH1_REG_TX_SWING                              ),//TRUE, FALSE;
    .PMA_REG_TX_SWING_OW                         (PMA_CH1_REG_TX_SWING_OW                           ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_153                     (PMA_CH1_REG_TX_RESERVED_153                       ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_THRESHOLD                  (PMA_CH1_REG_TX_RXDET_THRESHOLD                    ),//"28MV" "56MV" "84MV" "112MV"
    .PMA_REG_TX_RESERVED_157_156                 (PMA_CH1_REG_TX_RESERVED_157_156                   ),//0 to 3
    .PMA_REG_TX_BEACON_OSC_CTRL                  (PMA_CH1_REG_TX_BEACON_OSC_CTRL                    ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_160_159                 (PMA_CH1_REG_TX_RESERVED_160_159                   ),//0 to 3
    .PMA_REG_TX_RESERVED_162_161                 (PMA_CH1_REG_TX_RESERVED_162_161                   ),//0 to 3
    .PMA_REG_TX_TX2RX_SLPBACK_EN                 (PMA_CH1_REG_TX_TX2RX_SLPBACK_EN                   ),//TRUE, FALSE;
    .PMA_REG_TX_PCLK_EDGE_SEL                    (PMA_CH1_REG_TX_PCLK_EDGE_SEL                      ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_STATUS_OW                  (PMA_CH1_REG_TX_RXDET_STATUS_OW                    ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_STATUS                     (PMA_CH1_REG_TX_RXDET_STATUS                       ),//TRUE, FALSE;
    .PMA_REG_TX_PRBS_GEN_EN                      (PMA_CH1_REG_TX_PRBS_GEN_EN                        ),//TRUE, FALSE;
    .PMA_REG_TX_PRBS_GEN_WIDTH_SEL               (PMA_CH1_REG_TX_PRBS_GEN_WIDTH_SEL                 ),//"8BIT" "10BIT" "16BIT" "20BIT"
    .PMA_REG_TX_PRBS_SEL                         (PMA_CH1_REG_TX_PRBS_SEL                           ),//"PRBS7" "PRBS15" "PRBS23" "PRBS31"
    .PMA_REG_TX_UDP_DATA_7_TO_0                  (PMA_CH1_REG_TX_UDP_DATA_7_TO_0                    ),//0 to 255
    .PMA_REG_TX_UDP_DATA_15_TO_8                 (PMA_CH1_REG_TX_UDP_DATA_15_TO_8                   ),//0 to 255
    .PMA_REG_TX_UDP_DATA_19_TO_16                (PMA_CH1_REG_TX_UDP_DATA_19_TO_16                  ),//0 to 15
    .PMA_REG_TX_RESERVED_192                     (PMA_CH1_REG_TX_RESERVED_192                       ),//TRUE, FALSE;
    .PMA_REG_TX_FIFO_WP_CTRL                     (PMA_CH1_REG_TX_FIFO_WP_CTRL                       ),//0 to 7
    .PMA_REG_TX_FIFO_EN                          (PMA_CH1_REG_TX_FIFO_EN                            ),//TRUE, FALSE;
    .PMA_REG_TX_DATA_MUX_SEL                     (PMA_CH1_REG_TX_DATA_MUX_SEL                       ),//0 to 3
    .PMA_REG_TX_ERR_INSERT                       (PMA_CH1_REG_TX_ERR_INSERT                         ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_203_200                 (PMA_CH1_REG_TX_RESERVED_203_200                   ),//0 to15
    .PMA_REG_TX_RESERVED_204                     (PMA_CH1_REG_TX_RESERVED_204                       ),//TRUE, FALSE;
    .PMA_REG_TX_SATA_EN                          (PMA_CH1_REG_TX_SATA_EN                            ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_207_206                 (PMA_CH1_REG_TX_RESERVED_207_206                   ),//0 to3
    .PMA_REG_RATE_CHANGE_TXPCLK_ON_OW            (PMA_CH1_REG_RATE_CHANGE_TXPCLK_ON_OW              ),//TRUE, FALSE;
    .PMA_REG_RATE_CHANGE_TXPCLK_ON               (PMA_CH1_REG_RATE_CHANGE_TXPCLK_ON                 ),//TRUE, FALSE;
    .PMA_REG_TX_CFG_POST1                        (PMA_CH1_REG_TX_CFG_POST1                          ),//0 to 31
    .PMA_REG_TX_CFG_POST2                        (PMA_CH1_REG_TX_CFG_POST2                          ),//0 to 31
    .PMA_REG_TX_DEEMP                            (PMA_CH1_REG_TX_DEEMP                              ),//0 to 3
    .PMA_REG_TX_DEEMP_OW                         (PMA_CH1_REG_TX_DEEMP_OW                           ),//TRUE, FALSE;for TX DEEMP Control
    .PMA_REG_TX_RESERVED_224_223                 (PMA_CH1_REG_TX_RESERVED_224_223                   ),//0 to 3
    .PMA_REG_TX_RESERVED_225                     (PMA_CH1_REG_TX_RESERVED_225                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_229_226                 (PMA_CH1_REG_TX_RESERVED_229_226                   ),//0 to 15
    .PMA_REG_TX_OOB_DELAY_SEL                    (PMA_CH1_REG_TX_OOB_DELAY_SEL                      ),//0 to 15
    .PMA_REG_TX_POLARITY                         (PMA_CH1_REG_TX_POLARITY                           ),//"NORMAL" "REVERSE"
    .PMA_REG_ANA_TX_JTAG_DATA_O_SEL              (PMA_CH1_REG_ANA_TX_JTAG_DATA_O_SEL                ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_236                     (PMA_CH1_REG_TX_RESERVED_236                       ),//TRUE, FALSE;
    .PMA_REG_TX_LS_MODE_EN                       (PMA_CH1_REG_TX_LS_MODE_EN                         ),//TRUE, FALSE;
    .PMA_REG_TX_JTAG_MODE_EN_OW                  (PMA_CH1_REG_TX_JTAG_MODE_EN_OW                    ),//TRUE, FALSE;
    .PMA_REG_TX_JTAG_MODE_EN                     (PMA_CH1_REG_TX_JTAG_MODE_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_JTAG_MODE_EN_OW                  (PMA_CH1_REG_RX_JTAG_MODE_EN_OW                    ),//TRUE, FALSE;
    .PMA_REG_RX_JTAG_MODE_EN                     (PMA_CH1_REG_RX_JTAG_MODE_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_JTAG_OE                          (PMA_CH1_REG_RX_JTAG_OE                            ),//TRUE, FALSE;
    .PMA_REG_RX_ACJTAG_VHYSTSEL                  (PMA_CH1_REG_RX_ACJTAG_VHYSTSEL                    ),//0 to 7
    .PMA_REG_TX_RES_CAL_EN                       (PMA_CH1_REG_TX_RES_CAL_EN                         ),//TRUE, FALSE;
    .PMA_REG_RX_TERM_MODE_CTRL                   (PMA_CH1_REG_RX_TERM_MODE_CTRL                     ),//0 to 7; for rx terminatin Control
    .PMA_REG_TX_RESERVED_251_250                 (PMA_CH1_REG_TX_RESERVED_251_250                   ),//0 to 7
    .PMA_REG_PLPBK_TXPCLK_EN                     (PMA_CH1_REG_PLPBK_TXPCLK_EN                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_253                     (PMA_CH1_REG_TX_RESERVED_253                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_254                     (PMA_CH1_REG_TX_RESERVED_254                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_255                     (PMA_CH1_REG_TX_RESERVED_255                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_256                     (PMA_CH1_REG_TX_RESERVED_256                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_257                     (PMA_CH1_REG_TX_RESERVED_257                       ),//TRUE, FALSE;
    .PMA_REG_TX_PH_SEL                           (PMA_CH1_REG_TX_PH_SEL                             ),//0 to 63
    .PMA_REG_TX_CFG_PRE                          (PMA_CH1_REG_TX_CFG_PRE                            ),//0 to 31
    .PMA_REG_TX_CFG_MAIN                         (PMA_CH1_REG_TX_CFG_MAIN                           ),//0 to 63
    .PMA_REG_CFG_POST                            (PMA_CH1_REG_CFG_POST                              ),//0 to 31
    .PMA_REG_PD_MAIN                             (PMA_CH1_REG_PD_MAIN                               ),//TRUE, FALSE;
    .PMA_REG_PD_PRE                              (PMA_CH1_REG_PD_PRE                                ),//TRUE, FALSE;
    .PMA_REG_TX_LS_DATA                          (PMA_CH1_REG_TX_LS_DATA                            ),//TRUE, FALSE;
    .PMA_REG_TX_DCC_BUF_SZ_SEL                   (PMA_CH1_REG_TX_DCC_BUF_SZ_SEL                     ),//0 to 3
    .PMA_REG_TX_DCC_CAL_CUR_TUNE                 (PMA_CH1_REG_TX_DCC_CAL_CUR_TUNE                   ),//0 to 63
    .PMA_REG_TX_DCC_CAL_EN                       (PMA_CH1_REG_TX_DCC_CAL_EN                         ),//TRUE, FALSE;
    .PMA_REG_TX_DCC_CUR_SS                       (PMA_CH1_REG_TX_DCC_CUR_SS                         ),//0 to 3
    .PMA_REG_TX_DCC_FA_CTRL                      (PMA_CH1_REG_TX_DCC_FA_CTRL                        ),//TRUE, FALSE;
    .PMA_REG_TX_DCC_RI_CTRL                      (PMA_CH1_REG_TX_DCC_RI_CTRL                        ),//TRUE, FALSE;
    .PMA_REG_ATB_SEL_2_TO_0                      (PMA_CH1_REG_ATB_SEL_2_TO_0                        ),//0 to 7
    .PMA_REG_ATB_SEL_9_TO_3                      (PMA_CH1_REG_ATB_SEL_9_TO_3                        ),//0 to 127
    .PMA_REG_TX_CFG_7_TO_0                       (PMA_CH1_REG_TX_CFG_7_TO_0                         ),//0 to 255
    .PMA_REG_TX_CFG_15_TO_8                      (PMA_CH1_REG_TX_CFG_15_TO_8                        ),//0 to 255
    .PMA_REG_TX_CFG_23_TO_16                     (PMA_CH1_REG_TX_CFG_23_TO_16                       ),//0 to 255
    .PMA_REG_TX_CFG_31_TO_24                     (PMA_CH1_REG_TX_CFG_31_TO_24                       ),//0 to 255
    .PMA_REG_TX_OOB_EI_EN                        (PMA_CH1_REG_TX_OOB_EI_EN                          ),//TRUE, FALSE; Enable OOB EI for SATA mode
    .PMA_REG_TX_OOB_EI_EN_OW                     (PMA_CH1_REG_TX_OOB_EI_EN_OW                       ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_EN_DELAYED                (PMA_CH1_REG_TX_BEACON_EN_DELAYED                  ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_EN_DELAYED_OW             (PMA_CH1_REG_TX_BEACON_EN_DELAYED_OW               ),//TRUE, FALSE;
    .PMA_REG_TX_JTAG_DATA                        (PMA_CH1_REG_TX_JTAG_DATA                          ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_TIMER_SEL                  (PMA_CH1_REG_TX_RXDET_TIMER_SEL                    ),//0 to 255
    .PMA_REG_TX_CFG1_7_0                         (PMA_CH1_REG_TX_CFG1_7_0                           ),//0 to 255
    .PMA_REG_TX_CFG1_15_8                        (PMA_CH1_REG_TX_CFG1_15_8                          ),//0 to 255
    .PMA_REG_TX_CFG1_23_16                       (PMA_CH1_REG_TX_CFG1_23_16                         ),//0 to 255
    .PMA_REG_TX_CFG1_31_24                       (PMA_CH1_REG_TX_CFG1_31_24                         ),//0 to 255
    .PMA_REG_CFG_LANE_POWERUP                    (PMA_CH1_REG_CFG_LANE_POWERUP                      ),//ON, OFF; for PMA_LANE powerup
    .PMA_REG_CFG_TX_LANE_POWERUP_CLKPATH         (PMA_CH1_REG_CFG_TX_LANE_POWERUP_CLKPATH           ),//TRUE, FALSE; for Pma tx lane clkpath powerup
    .PMA_REG_CFG_TX_LANE_POWERUP_PISO            (PMA_CH1_REG_CFG_TX_LANE_POWERUP_PISO              ),//TRUE, FALSE; for Pma tx lane piso powerup
    .PMA_REG_CFG_TX_LANE_POWERUP_DRIVER          (PMA_CH1_REG_CFG_TX_LANE_POWERUP_DRIVER            ) //TRUE, FALSE; for Pma tx lane driver powerup
) U_GTP_HSSTLP_LANE1 (
    //PAD
    .P_TX_SDN                               (P_TX_SDN_1            ),//output              
    .P_TX_SDP                               (P_TX_SDP_1            ),//output              
    //SRB related                           
    .P_PCS_RX_MCB_STATUS                    (P_PCS_RX_MCB_STATUS_1 ),//output              
    .P_PCS_LSM_SYNCED                       (P_PCS_LSM_SYNCED_1    ),//output              
    .P_CFG_READY                            (P_CFG_READY_1         ),//output              
    .P_CFG_RDATA                            (P_CFG_RDATA_1         ),//output [7:0]        
    .P_CFG_INT                              (P_CFG_INT_1           ),//output              
    .P_RDATA                                (P_RDATA_1             ),//output [46:0]       
    .P_RCLK2FABRIC                          (P_RCLK2FABRIC_1       ),//output              
    .P_TCLK2FABRIC                          (P_TCLK2FABRIC_1       ),//output              
    .P_RX_SIGDET_STATUS                     (P_RX_SIGDET_STATUS_1  ),//output              
    .P_RX_SATA_COMINIT                      (P_RX_SATA_COMINIT_1   ),//output              
    .P_RX_SATA_COMWAKE                      (P_RX_SATA_COMWAKE_1   ),//output              
    .P_RX_LS_DATA                           (P_RX_LS_DATA_1        ),//output              
    .P_RX_READY                             (P_RX_READY_1          ),//output              
    .P_TEST_STATUS                          (P_TEST_STATUS_1       ),//output [19:0]       
    .P_TX_RXDET_STATUS                      (P_TX_RXDET_STATUS_1   ),//output              
    .P_CA_ALIGN_RX                          (P_CA_ALIGN_RX_1       ),//output              
    .P_CA_ALIGN_TX                          (P_CA_ALIGN_TX_1       ),//output              
    //out                                    
    .PMA_RCLK                               (PMA_RCLK_1            ),//output       	    
    .TXPCLK_PLL                             (TXPCLK_PLL_1          ),//output              
    //cin and cout                           
    .LANE_COUT_BUS_FORWARD                  (LANE_COUT_BUS_FORWARD_1),//output [18:0]       
    .APATTERN_STATUS_COUT                   (APATTERN_STATUS_COUT_1),//output              
    //PAD                                     
    .P_RX_SDN                               (P_RX_SDN_1            ),//input               
    .P_RX_SDP                               (P_RX_SDP_1            ),//input               
    //SRB related                            
    .P_RX_CLK_FR_CORE                       (P_RX_CLK_FR_CORE_1    ),//input               
    .P_RCLK2_FR_CORE                        (P_RCLK2_FR_CORE_1     ),//input               
    .P_TX_CLK_FR_CORE                       (P_TX_CLK_FR_CORE_1    ),//input               
    .P_TCLK2_FR_CORE                        (P_TCLK2_FR_CORE_1     ),//input               
    .P_PCS_TX_RST                           (P_PCS_TX_RST_1        ),//input               
    .P_PCS_RX_RST                           (P_PCS_RX_RST_1        ),//input               
    .P_PCS_CB_RST                           (P_PCS_CB_RST_1        ),//input               
    .P_RXGEAR_SLIP                          (P_RXGEAR_SLIP_1       ),//input               
    .P_CFG_CLK                              (P_CFG_CLK_1           ),//input               
    .P_CFG_RST                              (P_CFG_RST_1           ),//input               
    .P_CFG_PSEL                             (P_CFG_PSEL_1          ),//input               
    .P_CFG_ENABLE                           (P_CFG_ENABLE_1        ),//input               
    .P_CFG_WRITE                            (P_CFG_WRITE_1         ),//input               
    .P_CFG_ADDR                             (P_CFG_ADDR_1          ),//input [11:0]        
    .P_CFG_WDATA                            (P_CFG_WDATA_1         ),//input [7:0]         
    .P_TDATA                                (P_TDATA_1             ),//input [45:0]        
    .P_PCS_WORD_ALIGN_EN                    (P_PCS_WORD_ALIGN_EN_1 ),//input               
    .P_RX_POLARITY_INVERT                   (P_RX_POLARITY_INVERT_1),//input               
    .P_CEB_ADETECT_EN                       (P_CEB_ADETECT_EN_1    ),//input               
    .P_PCS_MCB_EXT_EN                       (P_PCS_MCB_EXT_EN_1    ),//input               
    .P_PCS_NEAREND_LOOP                     (P_PCS_NEAREND_LOOP_1  ),//input               
    .P_PCS_FAREND_LOOP                      (P_PCS_FAREND_LOOP_1   ),//input               
    .P_PMA_NEAREND_PLOOP                    (P_PMA_NEAREND_PLOOP_1 ),//input               
    .P_PMA_NEAREND_SLOOP                    (P_PMA_NEAREND_SLOOP_1 ),//input               
    .P_PMA_FAREND_PLOOP                     (P_PMA_FAREND_PLOOP_1  ),//input               
                                                                 
    .P_LANE_PD                              (P_LANE_PD_1           ),//input               
    .P_LANE_RST                             (P_LANE_RST_1          ),//input               
    .P_RX_LANE_PD                           (P_RX_LANE_PD_1        ),//input               
    .P_RX_PMA_RST                           (P_RX_PMA_RST_1        ),//input               
    .P_CTLE_ADP_RST                         (P_CTLE_ADP_RST_1      ),//input               
    .P_TX_DEEMP                             (P_TX_DEEMP_1          ),//input [1:0]         
    .P_TX_LS_DATA                           (P_TX_LS_DATA_1        ),//input               
    .P_TX_BEACON_EN                         (P_TX_BEACON_EN_1      ),//input               
    .P_TX_SWING                             (P_TX_SWING_1          ),//input               
    .P_TX_RXDET_REQ                         (P_TX_RXDET_REQ_1      ),//input               
    .P_TX_RATE                              (P_TX_RATE_1           ),//input [2:0]         
    .P_TX_BUSWIDTH                          (P_TX_BUSWIDTH_1       ),//input [2:0]         
    .P_TX_MARGIN                            (P_TX_MARGIN_1         ),//input [2:0]         
    .P_TX_PMA_RST                           (P_TX_PMA_RST_1        ),//input               
    .P_TX_LANE_PD_CLKPATH                   (P_TX_LANE_PD_CLKPATH_1),//input               
    .P_TX_LANE_PD_PISO                      (P_TX_LANE_PD_PISO_1   ),//input               
    .P_TX_LANE_PD_DRIVER                    (P_TX_LANE_PD_DRIVER_1 ),//input               
    .P_RX_RATE                              (P_RX_RATE_1           ),//input [2:0]         
    .P_RX_BUSWIDTH                          (P_RX_BUSWIDTH_1       ),//input [2:0]         
    .P_RX_HIGHZ                             (P_RX_HIGHZ_1          ),//input               
    .P_CIM_CLK_ALIGNER_RX                   (P_CIM_CLK_ALIGNER_RX_1),//input [7:0]         
    .P_CIM_CLK_ALIGNER_TX                   (P_CIM_CLK_ALIGNER_TX_1),//input [7:0]         
    .P_CIM_DYN_DLY_SEL_RX                   (P_CIM_DYN_DLY_SEL_RX_1),//input               
    .P_CIM_DYN_DLY_SEL_TX                   (P_CIM_DYN_DLY_SEL_TX_1),//input               
    .P_CIM_START_ALIGN_RX                   (P_CIM_START_ALIGN_RX_1),//input               
    .P_CIM_START_ALIGN_TX                   (P_CIM_START_ALIGN_TX_1),//input               
    //New Added                                      
    .MCB_RCLK                               (MCB_RCLK_1            ),//input               
    .SYNC                                   (SYNC_1                ),//input               
    .RATE_CHANGE                            (RATE_CHANGE_1         ),//input               
    .PLL_LOCK_SEL                           (PLL_LOCK_SEL_1        ),//input               
    //cin and cout                           
    .LANE_CIN_BUS_FORWARD                   (LANE_CIN_BUS_FORWARD_1),//input [18:0]        
    .APATTERN_STATUS_CIN                    (APATTERN_STATUS_CIN_1 ),//input               
    //From PLL                                  
    .CLK_TXP                                (CLK_TXP_1             ),//input               
    .CLK_TXN                                (CLK_TXN_1             ),//input               
    .CLK_RX0                                (CLK_RX0_1             ),//input               
    .CLK_RX90                               (CLK_RX90_1            ),//input               
    .CLK_RX180                              (CLK_RX180_1           ),//input               
    .CLK_RX270                              (CLK_RX270_1           ),//input               
    .PLL_PD_I                               (PLL_PD_I_1            ),//input               
    .PLL_RESET_I                            (PLL_RESET_I_1         ),//input               
    .PLL_REFCLK_I                           (PLL_REFCLK_I_1        ),//input               
    .PLL_RES_TRIM_I                         (PLL_RES_TRIM_I_1      ) //input [5:0]         
);
end
else begin:CHANNEL1_NULL //output default value to be done
    assign      P_TX_SDN_1                      = 1'b0 ;//output              
    assign      P_TX_SDP_1                      = 1'b0 ;//output              
    assign      P_PCS_RX_MCB_STATUS_1           = 1'b0 ;//output              
    assign      P_PCS_LSM_SYNCED_1              = 1'b0 ;//output              
    assign      P_CFG_READY_1                   = 1'b0 ;//output              
    assign      P_CFG_RDATA_1                   = 8'b0 ;//output [7:0]        
    assign      P_CFG_INT_1                     = 1'b0 ;//output              
    assign      P_RDATA_1                       = 47'b0;//output [46:0]       
    assign      P_RCLK2FABRIC_1                 = 1'b0 ;//output              
    assign      P_TCLK2FABRIC_1                 = 1'b0 ;//output              
    assign      P_RX_SIGDET_STATUS_1            = 1'b0 ;//output              
    assign      P_RX_SATA_COMINIT_1             = 1'b0 ;//output              
    assign      P_RX_SATA_COMWAKE_1             = 1'b0 ;//output              
    assign      P_RX_LS_DATA_1                  = 1'b0 ;//output              
    assign      P_RX_READY_1                    = 1'b0 ;//output              
    assign      P_TEST_STATUS_1                 = 20'b0;//output [19:0]       
    assign      P_TX_RXDET_STATUS_1             = 1'b0 ;//output              
    assign      P_CA_ALIGN_RX_1                 = 1'b0 ;//output              
    assign      P_CA_ALIGN_TX_1                 = 1'b0 ;//output              
    assign      PMA_RCLK_1                      = 1'b0 ;//output       	    
    assign      TXPCLK_PLL_1                    = 1'b0 ;//output              
    assign      LANE_COUT_BUS_FORWARD_1         = 19'b0;//output [18:0]       
    assign      APATTERN_STATUS_COUT_1          = 1'b0 ;//output              
end
endgenerate

//--------CHANNEL2 instance--------//
generate
if(CHANNEL2_EN == "TRUE") begin:CHANNEL2_ENABLE
GTP_HSSTLP_LANE#(
    .MUX_BIAS                                    (CH2_MUX_BIAS                                      ),//0 to 7; don't support simulation
    .PD_CLK                                      (CH2_PD_CLK                                        ),//0 to 1
    .REG_SYNC                                    (CH2_REG_SYNC                                      ),//0 to 1
    .REG_SYNC_OW                                 (CH2_REG_SYNC_OW                                   ),//0 to 1
    .PLL_LOCK_OW                                 (CH2_PLL_LOCK_OW                                   ),//0 to 1
    .PLL_LOCK_OW_EN                              (CH2_PLL_LOCK_OW_EN                                ),//0 to 1
    //pcs
    .PCS_SLAVE                                   (PCS_CH2_SLAVE                                     ),
    .PCS_BYPASS_WORD_ALIGN                       (PCS_CH2_BYPASS_WORD_ALIGN                         ),//TRUE, FALSE; for bypass word alignment
    .PCS_BYPASS_DENC                             (PCS_CH2_BYPASS_DENC                               ),//TRUE, FALSE; for bypass 8b/10b decoder
    .PCS_BYPASS_BONDING                          (PCS_CH2_BYPASS_BONDING                            ),//TRUE, FALSE; for bypass channel bonding
    .PCS_BYPASS_CTC                              (PCS_CH2_BYPASS_CTC                                ),//TRUE, FALSE; for bypass ctc
    .PCS_BYPASS_GEAR                             (PCS_CH2_BYPASS_GEAR                               ),//TRUE, FALSE; for bypass Rx Gear
    .PCS_BYPASS_BRIDGE                           (PCS_CH2_BYPASS_BRIDGE                             ),//TRUE, FALSE; for bypass Rx Bridge unit
    .PCS_BYPASS_BRIDGE_FIFO                      (PCS_CH2_BYPASS_BRIDGE_FIFO                        ),//TRUE, FALSE; for bypass Rx Bridge FIFO
    .PCS_DATA_MODE                               (PCS_CH2_DATA_MODE                                 ),//"X8","X10","X16","X20"
    .PCS_RX_POLARITY_INV                         (PCS_CH2_RX_POLARITY_INV                           ),//"DELAY","BIT_POLARITY_INVERION","BIT_REVERSAL","BOTH"
    .PCS_ALIGN_MODE                              (PCS_CH2_ALIGN_MODE                                ),//1GB, 10GB, RAPIDIO, OUTSIDE
    .PCS_SAMP_16B                                (PCS_CH2_SAMP_16B                                  ),//"X20",X16
    .PCS_FARLP_PWR_REDUCTION                     (PCS_CH2_FARLP_PWR_REDUCTION                       ),//TRUE, FALSE;
    .PCS_COMMA_REG0                              (PCS_CH2_COMMA_REG0                                ),//0 to 1023
    .PCS_COMMA_MASK                              (PCS_CH2_COMMA_MASK                                ),//0 to 1023
    .PCS_CEB_MODE                                (PCS_CH2_CEB_MODE                                  ),//"10GB" "RAPIDIO" "OUTSIDE"
    .PCS_CTC_MODE                                (PCS_CH2_CTC_MODE                                  ),//1SKIP, 2SKIP, PCIE_2BYTE, 4SKIP
    .PCS_A_REG                                   (PCS_CH2_A_REG                                     ),//0 to 255
    .PCS_GE_AUTO_EN                              (PCS_CH2_GE_AUTO_EN                                ),//TRUE, FALSE;
    .PCS_SKIP_REG0                               (PCS_CH2_SKIP_REG0                                 ),//0 to 1023
    .PCS_SKIP_REG1                               (PCS_CH2_SKIP_REG1                                 ),//0 to 1023
    .PCS_SKIP_REG2                               (PCS_CH2_SKIP_REG2                                 ),//0 to 1023
    .PCS_SKIP_REG3                               (PCS_CH2_SKIP_REG3                                 ),//0 to 1023
    .PCS_DEC_DUAL                                (PCS_CH2_DEC_DUAL                                  ),//TRUE, FALSE;
    .PCS_SPLIT                                   (PCS_CH2_SPLIT                                     ),//TRUE, FALSE;
    .PCS_FIFOFLAG_CTC                            (PCS_CH2_FIFOFLAG_CTC                              ),//TRUE, FALSE;
    .PCS_COMMA_DET_MODE                          (PCS_CH2_COMMA_DET_MODE                            ),//"RX_CLK_SLIP" "COMMA_PATTERN"
    .PCS_ERRDETECT_SILENCE                       (PCS_CH2_ERRDETECT_SILENCE                         ),//TRUE, FALSE;
    .PCS_PMA_RCLK_POLINV                         (PCS_CH2_PMA_RCLK_POLINV                           ),//"PMA_RCLK" "REVERSE_OF_PMA_RCLK"
    .PCS_PCS_RCLK_SEL                            (PCS_CH2_PCS_RCLK_SEL                              ),//"PMA_RCLK" "PMA_TCLK" "RCLK"
    .PCS_CB_RCLK_SEL                             (PCS_CH2_CB_RCLK_SEL                               ),//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK"
    .PCS_AFTER_CTC_RCLK_SEL                      (PCS_CH2_AFTER_CTC_RCLK_SEL                        ),//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK" "RCLK2"
    .PCS_RCLK_POLINV                             (PCS_CH2_RCLK_POLINV                               ),//"RCLK" "REVERSE_OF_RCLK"
    .PCS_BRIDGE_RCLK_SEL                         (PCS_CH2_BRIDGE_RCLK_SEL                           ),//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK" "RCLK"
    .PCS_PCS_RCLK_EN                             (PCS_CH2_PCS_RCLK_EN                               ),//TRUE, FALSE;
    .PCS_CB_RCLK_EN                              (PCS_CH2_CB_RCLK_EN                                ),//TRUE, FALSE;
    .PCS_AFTER_CTC_RCLK_EN                       (PCS_CH2_AFTER_CTC_RCLK_EN                         ),//TRUE, FALSE;
    .PCS_AFTER_CTC_RCLK_EN_GB                    (PCS_CH2_AFTER_CTC_RCLK_EN_GB                      ),//TRUE, FALSE;
    .PCS_PCS_RX_RSTN                             (PCS_CH2_PCS_RX_RSTN                               ),//TRUE, FALSE; for PCS Receiver Reset
    .PCS_PCIE_SLAVE                              (PCS_CH2_PCIE_SLAVE                                ),//"MASTER","SLAVE"
    .PCS_RX_64B66B_67B                           (PCS_CH2_RX_64B66B_67B                             ),//"NORMAL" "64B_66B" "64B_67B"
    .PCS_RX_BRIDGE_CLK_POLINV                    (PCS_CH2_RX_BRIDGE_CLK_POLINV                      ),//"RX_BRIDGE_CLK" "REVERSE_OF_RX_BRIDGE_CLK"
    .PCS_PCS_CB_RSTN                             (PCS_CH2_PCS_CB_RSTN                               ),//TRUE, FALSE; for PCS CB Reset
    .PCS_TX_BRIDGE_GEAR_SEL                      (PCS_CH2_TX_BRIDGE_GEAR_SEL                        ),//TRUE: tx gear priority, FALSE:tx bridge unit priority
    .PCS_TX_BYPASS_BRIDGE_UINT                   (PCS_CH2_TX_BYPASS_BRIDGE_UINT                     ),//TRUE, FALSE; for bypass 
    .PCS_TX_BYPASS_BRIDGE_FIFO                   (PCS_CH2_TX_BYPASS_BRIDGE_FIFO                     ),//TRUE, FALSE; for bypass Tx Bridge FIFO
    .PCS_TX_BYPASS_GEAR                          (PCS_CH2_TX_BYPASS_GEAR                            ),//TRUE, FALSE;
    .PCS_TX_BYPASS_ENC                           (PCS_CH2_TX_BYPASS_ENC                             ),//TRUE, FALSE;
    .PCS_TX_BYPASS_BIT_SLIP                      (PCS_CH2_TX_BYPASS_BIT_SLIP                        ),//TRUE, FALSE;
    .PCS_TX_GEAR_SPLIT                           (PCS_CH2_TX_GEAR_SPLIT                             ),//TRUE, FALSE;
    .PCS_TX_DRIVE_REG_MODE                       (PCS_CH2_TX_DRIVE_REG_MODE                         ),//"NO_CHANGE" "EN_POLARIY_REV" "EN_BIT_REV" "EN_BOTH"
    .PCS_TX_BIT_SLIP_CYCLES                      (PCS_CH2_TX_BIT_SLIP_CYCLES                        ),//o to 31
    .PCS_INT_TX_MASK_0                           (PCS_CH2_INT_TX_MASK_0                             ),//TRUE, FALSE;
    .PCS_INT_TX_MASK_1                           (PCS_CH2_INT_TX_MASK_1                             ),//TRUE, FALSE;
    .PCS_INT_TX_MASK_2                           (PCS_CH2_INT_TX_MASK_2                             ),//TRUE, FALSE;
    .PCS_INT_TX_CLR_0                            (PCS_CH2_INT_TX_CLR_0                              ),//TRUE, FALSE;
    .PCS_INT_TX_CLR_1                            (PCS_CH2_INT_TX_CLR_1                              ),//TRUE, FALSE;
    .PCS_INT_TX_CLR_2                            (PCS_CH2_INT_TX_CLR_2                              ),//TRUE, FALSE;
    .PCS_TX_PMA_TCLK_POLINV                      (PCS_CH2_TX_PMA_TCLK_POLINV                        ),//"PMA_TCLK" "REVERSE_OF_PMA_TCLK"
    .PCS_TX_PCS_CLK_EN_SEL                       (PCS_CH2_TX_PCS_CLK_EN_SEL                         ),//TRUE, FALSE;
    .PCS_TX_BRIDGE_TCLK_SEL                      (PCS_CH2_TX_BRIDGE_TCLK_SEL                        ),//"PCS_TCLK" "TCLK"
    .PCS_TX_TCLK_POLINV                          (PCS_CH2_TX_TCLK_POLINV                            ),//"TCLK" "REVERSE_OF_TCLK"
    .PCS_PCS_TCLK_SEL                            (PCS_CH2_PCS_TCLK_SEL                              ),//"PMA_TCLK" "TCLK"
    .PCS_TX_PCS_TX_RSTN                          (PCS_CH2_TX_PCS_TX_RSTN                            ),//TRUE, FALSE; for PCS Transmitter Reset
    .PCS_TX_SLAVE                                (PCS_CH2_TX_SLAVE                                  ),//"MASTER" "SLAVE"
    .PCS_TX_GEAR_CLK_EN_SEL                      (PCS_CH2_TX_GEAR_CLK_EN_SEL                        ),//TRUE, FALSE;
    .PCS_DATA_WIDTH_MODE                         (PCS_CH2_DATA_WIDTH_MODE                           ),//"X8" "X10" "X16" "X20"
    .PCS_TX_64B66B_67B                           (PCS_CH2_TX_64B66B_67B                             ),//"NORMAL" "64B_66B" "64B_67B"
    .PCS_GEAR_TCLK_SEL                           (PCS_CH2_GEAR_TCLK_SEL                             ),//"PMA_TCLK" "TCLK2"
    .PCS_TX_TCLK2FABRIC_SEL                      (PCS_CH2_TX_TCLK2FABRIC_SEL                        ),//TRUE, FALSE
    .PCS_TX_OUTZZ                                (PCS_CH2_TX_OUTZZ                                  ),//TRUE, FALSE
    .PCS_ENC_DUAL                                (PCS_CH2_ENC_DUAL                                  ),//TRUE, FALSE
    .PCS_TX_BITSLIP_DATA_MODE                    (PCS_CH2_TX_BITSLIP_DATA_MODE                      ),//"X10" "X20"
    .PCS_TX_BRIDGE_CLK_POLINV                    (PCS_CH2_TX_BRIDGE_CLK_POLINV                      ),//"TX_BRIDGE_CLK" "REVERSE_OF_TX_BRIDGE_CLK"
    .PCS_COMMA_REG1                              (PCS_CH2_COMMA_REG1                                ),//0 to 1023
    .PCS_RAPID_IMAX                              (PCS_CH2_RAPID_IMAX                                ),//0 to 7
    .PCS_RAPID_VMIN_1                            (PCS_CH2_RAPID_VMIN_1                              ),//0 to 255
    .PCS_RAPID_VMIN_2                            (PCS_CH2_RAPID_VMIN_2                              ),//0 to 255
    .PCS_RX_PRBS_MODE                            (PCS_CH2_RX_PRBS_MODE                              ),//DISABLE PRBS_7 PRBS_15 PRBS_23 PRBS_31
    .PCS_RX_ERRCNT_CLR                           (PCS_CH2_RX_ERRCNT_CLR                             ),//TRUE, FALSE
    .PCS_PRBS_ERR_LPBK                           (PCS_CH2_PRBS_ERR_LPBK                             ),//TRUE, FALSE
    .PCS_TX_PRBS_MODE                            (PCS_CH2_TX_PRBS_MODE                              ),//DISABLE PRBS_7 PRBS_15 PRBS_23 PRBS_31 LONG_1 LONG_0 20UI D10_2 PCIE
    .PCS_TX_INSERT_ER                            (PCS_CH2_TX_INSERT_ER                              ),//TRUE, FALSE
    .PCS_ENABLE_PRBS_GEN                         (PCS_CH2_ENABLE_PRBS_GEN                           ),//TRUE, FALSE
    .PCS_DEFAULT_RADDR                           (PCS_CH2_DEFAULT_RADDR                             ),//0 to 15
    .PCS_MASTER_CHECK_OFFSET                     (PCS_CH2_MASTER_CHECK_OFFSET                       ),//0 to 15
    .PCS_DELAY_SET                               (PCS_CH2_DELAY_SET                                 ),//0 to 15
    .PCS_SEACH_OFFSET                            (PCS_CH2_SEACH_OFFSET                              ),//"20BIT" 30BIT" "40BIT" "50BIT" "60BIT" "70BIT" "80BIT"
    .PCS_CEB_RAPIDLS_MMAX                        (PCS_CH2_CEB_RAPIDLS_MMAX                          ),//0 to 7
    .PCS_CTC_AFULL                               (PCS_CH2_CTC_AFULL                                 ),//0 to 31
    .PCS_CTC_AEMPTY                              (PCS_CH2_CTC_AEMPTY                                ),//0 to 31
    .PCS_CTC_CONTI_SKP_SET                       (PCS_CH2_CTC_CONTI_SKP_SET                         ),//0 to 1
    .PCS_FAR_LOOP                                (PCS_CH2_FAR_LOOP                                  ),//TRUE, FALSE
    .PCS_NEAR_LOOP                               (PCS_CH2_NEAR_LOOP                                 ),//TRUE, FALSE
    .PCS_PMA_TX2RX_PLOOP_EN                      (PCS_CH2_PMA_TX2RX_PLOOP_EN                        ),//TRUE, FALSE
    .PCS_PMA_TX2RX_SLOOP_EN                      (PCS_CH2_PMA_TX2RX_SLOOP_EN                        ),//TRUE, FALSE
    .PCS_PMA_RX2TX_PLOOP_EN                      (PCS_CH2_PMA_RX2TX_PLOOP_EN                        ),//TRUE, FALSE
    .PCS_INT_RX_MASK_0                           (PCS_CH2_INT_RX_MASK_0                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_1                           (PCS_CH2_INT_RX_MASK_1                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_2                           (PCS_CH2_INT_RX_MASK_2                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_3                           (PCS_CH2_INT_RX_MASK_3                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_4                           (PCS_CH2_INT_RX_MASK_4                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_5                           (PCS_CH2_INT_RX_MASK_5                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_6                           (PCS_CH2_INT_RX_MASK_6                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_7                           (PCS_CH2_INT_RX_MASK_7                             ),//TRUE, FALSE
    .PCS_INT_RX_CLR_0                            (PCS_CH2_INT_RX_CLR_0                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_1                            (PCS_CH2_INT_RX_CLR_1                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_2                            (PCS_CH2_INT_RX_CLR_2                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_3                            (PCS_CH2_INT_RX_CLR_3                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_4                            (PCS_CH2_INT_RX_CLR_4                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_5                            (PCS_CH2_INT_RX_CLR_5                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_6                            (PCS_CH2_INT_RX_CLR_6                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_7                            (PCS_CH2_INT_RX_CLR_7                              ),//TRUE, FALSE
    .PCS_CA_RSTN_RX                              (PCS_CH2_CA_RSTN_RX                                ),//TRUE, FALSE; for Rx CLK Aligner Reset
    .PCS_CA_DYN_DLY_EN_RX                        (PCS_CH2_CA_DYN_DLY_EN_RX                          ),//TRUE, FALSE
    .PCS_CA_DYN_DLY_SEL_RX                       (PCS_CH2_CA_DYN_DLY_SEL_RX                         ),//TRUE, FALSE
    .PCS_CA_RX                                   (PCS_CH2_CA_RX                                     ),//0 to 255
    .PCS_CA_RSTN_TX                              (PCS_CH2_CA_RSTN_TX                                ),//TRUE, FALSE
    .PCS_CA_DYN_DLY_EN_TX                        (PCS_CH2_CA_DYN_DLY_EN_TX                          ),//TRUE, FALSE
    .PCS_CA_DYN_DLY_SEL_TX                       (PCS_CH2_CA_DYN_DLY_SEL_TX                         ),//TRUE, FALSE
    .PCS_CA_TX                                   (PCS_CH2_CA_TX                                     ),//0 to 255
    .PCS_RXPRBS_PWR_REDUCTION                    (PCS_CH2_RXPRBS_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_WDALIGN_PWR_REDUCTION                   (PCS_CH2_WDALIGN_PWR_REDUCTION                     ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXDEC_PWR_REDUCTION                     (PCS_CH2_RXDEC_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXCB_PWR_REDUCTION                      (PCS_CH2_RXCB_PWR_REDUCTION                        ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXCTC_PWR_REDUCTION                     (PCS_CH2_RXCTC_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXGEAR_PWR_REDUCTION                    (PCS_CH2_RXGEAR_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXBRG_PWR_REDUCTION                     (PCS_CH2_RXBRG_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXTEST_PWR_REDUCTION                    (PCS_CH2_RXTEST_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXBRG_PWR_REDUCTION                     (PCS_CH2_TXBRG_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXGEAR_PWR_REDUCTION                    (PCS_CH2_TXGEAR_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXENC_PWR_REDUCTION                     (PCS_CH2_TXENC_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXBSLP_PWR_REDUCTION                    (PCS_CH2_TXBSLP_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXPRBS_PWR_REDUCTION                    (PCS_CH2_TXPRBS_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    //pma_rx                                                                                      
    .PMA_REG_RX_PD                               (PMA_CH2_REG_RX_PD                                 ),//ON, OFF;
    .PMA_REG_RX_PD_EN                            (PMA_CH2_REG_RX_PD_EN                              ),//TRUE, FALSE
    .PMA_REG_RX_RESERVED_2                       (PMA_CH2_REG_RX_RESERVED_2                         ),//TRUE, FALSE
    .PMA_REG_RX_RESERVED_3                       (PMA_CH2_REG_RX_RESERVED_3                         ),//TRUE, FALSE
    .PMA_REG_RX_DATAPATH_PD                      (PMA_CH2_REG_RX_DATAPATH_PD                        ),//ON, OFF;
    .PMA_REG_RX_DATAPATH_PD_EN                   (PMA_CH2_REG_RX_DATAPATH_PD_EN                     ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_PD                        (PMA_CH2_REG_RX_SIGDET_PD                          ),//ON, OFF;
    .PMA_REG_RX_SIGDET_PD_EN                     (PMA_CH2_REG_RX_SIGDET_PD_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_DCC_RST_N                        (PMA_CH2_REG_RX_DCC_RST_N                          ),//TRUE, FALSE;
    .PMA_REG_RX_DCC_RST_N_EN                     (PMA_CH2_REG_RX_DCC_RST_N_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_CDR_RST_N                        (PMA_CH2_REG_RX_CDR_RST_N                          ),//TRUE, FALSE;
    .PMA_REG_RX_CDR_RST_N_EN                     (PMA_CH2_REG_RX_CDR_RST_N_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_RST_N                     (PMA_CH2_REG_RX_SIGDET_RST_N                       ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_RST_N_EN                  (PMA_CH2_REG_RX_SIGDET_RST_N_EN                    ),//TRUE, FALSE;
    .PMA_REG_RXPCLK_SLIP                         (PMA_CH2_REG_RXPCLK_SLIP                           ),//TRUE, FALSE;
    .PMA_REG_RXPCLK_SLIP_OW                      (PMA_CH2_REG_RXPCLK_SLIP_OW                        ),//TRUE, FALSE;
    .PMA_REG_RX_PCLKSWITCH_RST_N                 (PMA_CH2_REG_RX_PCLKSWITCH_RST_N                   ),//TRUE, FALSE; for TX PMA Reset
    .PMA_REG_RX_PCLKSWITCH_RST_N_EN              (PMA_CH2_REG_RX_PCLKSWITCH_RST_N_EN                ),//TRUE, FALSE;
    .PMA_REG_RX_PCLKSWITCH                       (PMA_CH2_REG_RX_PCLKSWITCH                         ),//TRUE, FALSE;
    .PMA_REG_RX_PCLKSWITCH_EN                    (PMA_CH2_REG_RX_PCLKSWITCH_EN                      ),//TRUE, FALSE;
    .PMA_REG_RX_HIGHZ                            (PMA_CH2_REG_RX_HIGHZ                              ),//TRUE, FALSE;
    .PMA_REG_RX_HIGHZ_EN                         (PMA_CH2_REG_RX_HIGHZ_EN                           ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_CLK_WINDOW                (PMA_CH2_REG_RX_SIGDET_CLK_WINDOW                  ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_CLK_WINDOW_OW             (PMA_CH2_REG_RX_SIGDET_CLK_WINDOW_OW               ),//TRUE, FALSE;
    .PMA_REG_RX_PD_BIAS_RX                       (PMA_CH2_REG_RX_PD_BIAS_RX                         ),//TRUE, FALSE;
    .PMA_REG_RX_PD_BIAS_RX_OW                    (PMA_CH2_REG_RX_PD_BIAS_RX_OW                      ),//TRUE, FALSE;
    .PMA_REG_RX_RESET_N                          (PMA_CH2_REG_RX_RESET_N                            ),//TRUE, FALSE;
    .PMA_REG_RX_RESET_N_OW                       (PMA_CH2_REG_RX_RESET_N_OW                         ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_29_28                   (PMA_CH2_REG_RX_RESERVED_29_28                     ),//0 to 3
    .PMA_REG_RX_BUSWIDTH                         (PMA_CH2_REG_RX_BUSWIDTH                           ),//"8BIT" "10BIT" "16BIT" "20BIT"
    .PMA_REG_RX_BUSWIDTH_EN                      (PMA_CH2_REG_RX_BUSWIDTH_EN                        ),//TRUE, FALSE;
    .PMA_REG_RX_RATE                             (PMA_CH2_REG_RX_RATE                               ),//"DIV4" "DIV2" "DIV1" "MUL2"
    .PMA_REG_RX_RESERVED_36                      (PMA_CH2_REG_RX_RESERVED_36                        ),//TRUE, FALSE;
    .PMA_REG_RX_RATE_EN                          (PMA_CH2_REG_RX_RATE_EN                            ),//TRUE, FALSE;
    .PMA_REG_RX_RES_TRIM                         (PMA_CH2_REG_RX_RES_TRIM                           ),//0 to 63
    .PMA_REG_RX_RESERVED_44                      (PMA_CH2_REG_RX_RESERVED_44                        ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_45                      (PMA_CH2_REG_RX_RESERVED_45                        ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_STATUS_EN                 (PMA_CH2_REG_RX_SIGDET_STATUS_EN                   ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_48_47                   (PMA_CH2_REG_RX_RESERVED_48_47                     ),//0 to 3
    .PMA_REG_RX_ICTRL_SIGDET                     (PMA_CH2_REG_RX_ICTRL_SIGDET                       ),//0 to 15
    .PMA_REG_CDR_READY_THD                       (PMA_CH2_REG_CDR_READY_THD                         ),//0 to 4095
    .PMA_REG_RX_RESERVED_65                      (PMA_CH2_REG_RX_RESERVED_65                        ),//TRUE, FALSE;
    .PMA_REG_RX_PCLK_EDGE_SEL                    (PMA_CH2_REG_RX_PCLK_EDGE_SEL                      ),//"POS_EDGE" "NEG_EDGE"
    .PMA_REG_RX_PIBUF_IC                         (PMA_CH2_REG_RX_PIBUF_IC                           ),//0 to 3
    .PMA_REG_RX_RESERVED_69                      (PMA_CH2_REG_RX_RESERVED_69                        ),//TRUE, FALSE; 
    .PMA_REG_RX_DCC_IC_RX                        (PMA_CH2_REG_RX_DCC_IC_RX                          ),//0 to 3
    .PMA_REG_CDR_READY_CHECK_CTRL                (PMA_CH2_REG_CDR_READY_CHECK_CTRL                  ),//0 to 3
    .PMA_REG_RX_ICTRL_TRX                        (PMA_CH2_REG_RX_ICTRL_TRX                          ),//"87_5PCT" "100PCT" "112_5PCT" "125PCT"
    .PMA_REG_RX_RESERVED_77_76                   (PMA_CH2_REG_RX_RESERVED_77_76                     ),//0 to 3
    .PMA_REG_RX_RESERVED_79_78                   (PMA_CH2_REG_RX_RESERVED_79_78                     ),//0 to 3
    .PMA_REG_RX_RESERVED_81_80                   (PMA_CH2_REG_RX_RESERVED_81_80                     ),//0 to 3
    .PMA_REG_RX_ICTRL_PIBUF                      (PMA_CH2_REG_RX_ICTRL_PIBUF                        ),//"87_5PCT" "100PCT" "112_5PCT" "125PCT"
    .PMA_REG_RX_ICTRL_PI                         (PMA_CH2_REG_RX_ICTRL_PI                           ),//"87_5PCT" "100PCT" "112_5PCT" "125PCT"
    .PMA_REG_RX_ICTRL_DCC                        (PMA_CH2_REG_RX_ICTRL_DCC                          ),//"87_5PCT" "100PCT" "112_5PCT" "125PCT"
    .PMA_REG_RX_RESERVED_89_88                   (PMA_CH2_REG_RX_RESERVED_89_88                     ),//0 to 3
    .PMA_REG_TX_RATE                             (PMA_CH2_REG_TX_RATE                               ),//"DIV4" "DIV2" "DIV1" "MUL2"
    .PMA_REG_RX_RESERVED_92                      (PMA_CH2_REG_RX_RESERVED_92                        ),//TRUE, FALSE; 
    .PMA_REG_TX_RATE_EN                          (PMA_CH2_REG_TX_RATE_EN                            ),//TRUE, FALSE; 
    .PMA_REG_RX_TX2RX_PLPBK_RST_N                (PMA_CH2_REG_RX_TX2RX_PLPBK_RST_N                  ),//TRUE, FALSE; for tx2rx pma parallel loop back Reset
    .PMA_REG_RX_TX2RX_PLPBK_RST_N_EN             (PMA_CH2_REG_RX_TX2RX_PLPBK_RST_N_EN               ),//TRUE, FALSE; 
    .PMA_REG_RX_TX2RX_PLPBK_EN                   (PMA_CH2_REG_RX_TX2RX_PLPBK_EN                     ),//TRUE, FALSE; for tx2rx pma parallel loop back enable
    .PMA_REG_TXCLK_SEL                           (PMA_CH2_REG_TXCLK_SEL                             ),//"PLL" "RXCLK"
    .PMA_REG_RX_DATA_POLARITY                    (PMA_CH2_REG_RX_DATA_POLARITY                      ),//"NORMAL" "REVERSE"
    .PMA_REG_RX_ERR_INSERT                       (PMA_CH2_REG_RX_ERR_INSERT                         ),//TRUE, FALSE;
    .PMA_REG_UDP_CHK_EN                          (PMA_CH2_REG_UDP_CHK_EN                            ),//TRUE, FALSE;
    .PMA_REG_PRBS_SEL                            (PMA_CH2_REG_PRBS_SEL                              ),//"PRBS7" "PRBS15" "PRBS23" "PRBS31"
    .PMA_REG_PRBS_CHK_EN                         (PMA_CH2_REG_PRBS_CHK_EN                           ),//TRUE, FALSE;
    .PMA_REG_PRBS_CHK_WIDTH_SEL                  (PMA_CH2_REG_PRBS_CHK_WIDTH_SEL                    ),//"8BIT" "10BIT" "16BIT" "20BIT"
    .PMA_REG_BIST_CHK_PAT_SEL                    (PMA_CH2_REG_BIST_CHK_PAT_SEL                      ),//"PRBS" "CONSTANT"
    .PMA_REG_LOAD_ERR_CNT                        (PMA_CH2_REG_LOAD_ERR_CNT                          ),//TRUE, FALSE;
    .PMA_REG_CHK_COUNTER_EN                      (PMA_CH2_REG_CHK_COUNTER_EN                        ),//TRUE, FALSE;
    .PMA_REG_CDR_PROP_GAIN                       (PMA_CH2_REG_CDR_PROP_GAIN                         ),//0 to 7
    .PMA_REG_CDR_PROP_TURBO_GAIN                 (PMA_CH2_REG_CDR_PROP_TURBO_GAIN                   ),//0 to 7
    .PMA_REG_CDR_INT_GAIN                        (PMA_CH2_REG_CDR_INT_GAIN                          ),//0 to 7
    .PMA_REG_CDR_INT_TURBO_GAIN                  (PMA_CH2_REG_CDR_INT_TURBO_GAIN                    ),//0 to 7
    .PMA_REG_CDR_INT_SAT_MAX                     (PMA_CH2_REG_CDR_INT_SAT_MAX                       ),//0 to 1023
    .PMA_REG_CDR_INT_SAT_MIN                     (PMA_CH2_REG_CDR_INT_SAT_MIN                       ),//0 to 1023
    .PMA_REG_CDR_INT_RST                         (PMA_CH2_REG_CDR_INT_RST                           ),//TRUE, FALSE;
    .PMA_REG_CDR_INT_RST_OW                      (PMA_CH2_REG_CDR_INT_RST_OW                        ),//TRUE, FALSE;
    .PMA_REG_CDR_PROP_RST                        (PMA_CH2_REG_CDR_PROP_RST                          ),//TRUE, FALSE;
    .PMA_REG_CDR_PROP_RST_OW                     (PMA_CH2_REG_CDR_PROP_RST_OW                       ),//TRUE, FALSE;
    .PMA_REG_CDR_LOCK_RST                        (PMA_CH2_REG_CDR_LOCK_RST                          ),//TRUE, FALSE; for CDR LOCK Counter Reset
    .PMA_REG_CDR_LOCK_RST_OW                     (PMA_CH2_REG_CDR_LOCK_RST_OW                       ),//TRUE, FALSE;
    .PMA_REG_CDR_RX_PI_FORCE_SEL                 (PMA_CH2_REG_CDR_RX_PI_FORCE_SEL                   ),//0,1
    .PMA_REG_CDR_RX_PI_FORCE_D                   (PMA_CH2_REG_CDR_RX_PI_FORCE_D                     ),//0 to 255
    .PMA_REG_CDR_LOCK_TIMER                      (PMA_CH2_REG_CDR_LOCK_TIMER                        ),//"0_8U" "1_2U" "1_6U" "2_4U" 3_2U" "4_8U" "12_8U" "25_6U"
    .PMA_REG_CDR_TURBO_MODE_TIMER                (PMA_CH2_REG_CDR_TURBO_MODE_TIMER                  ),//0 to 3
    .PMA_REG_CDR_LOCK_VAL                        (PMA_CH2_REG_CDR_LOCK_VAL                          ),//TRUE, FALSE;
    .PMA_REG_CDR_LOCK_OW                         (PMA_CH2_REG_CDR_LOCK_OW                           ),//TRUE, FALSE;
    .PMA_REG_CDR_INT_SAT_DET_EN                  (PMA_CH2_REG_CDR_INT_SAT_DET_EN                    ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_AUTO_DIS                    (PMA_CH2_REG_CDR_SAT_AUTO_DIS                      ),//TRUE, FALSE;
    .PMA_REG_CDR_GAIN_AUTO                       (PMA_CH2_REG_CDR_GAIN_AUTO                         ),//TRUE, FALSE;
    .PMA_REG_CDR_TURBO_GAIN_AUTO                 (PMA_CH2_REG_CDR_TURBO_GAIN_AUTO                   ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_171_167                 (PMA_CH2_REG_RX_RESERVED_171_167                   ),//0 to 31
    .PMA_REG_RX_RESERVED_175_172                 (PMA_CH2_REG_RX_RESERVED_175_172                   ),//0 to 31
    .PMA_REG_CDR_SAT_DET_STATUS_EN               (PMA_CH2_REG_CDR_SAT_DET_STATUS_EN                 ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_STATUS_RESET_EN         (PMA_CH2_REG_CDR_SAT_DET_STATUS_RESET_EN           ),//TRUE, FALSE;
    .PMA_REG_CDR_PI_CTRL_RST                     (PMA_CH2_REG_CDR_PI_CTRL_RST                       ),//TRUE, FALSE;
    .PMA_REG_CDR_PI_CTRL_RST_OW                  (PMA_CH2_REG_CDR_PI_CTRL_RST_OW                    ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_RST                     (PMA_CH2_REG_CDR_SAT_DET_RST                       ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_RST_OW                  (PMA_CH2_REG_CDR_SAT_DET_RST_OW                    ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_STICKY_RST              (PMA_CH2_REG_CDR_SAT_DET_STICKY_RST                ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_STICKY_RST_OW           (PMA_CH2_REG_CDR_SAT_DET_STICKY_RST_OW             ),//TRUE, FALSE;
    .PMA_REG_CDR_SIGDET_STATUS_DIS               (PMA_CH2_REG_CDR_SIGDET_STATUS_DIS                 ),//TRUE, FALSE; for sigdet_status is 0 to reset cdr
    .PMA_REG_CDR_SAT_DET_TIMER                   (PMA_CH2_REG_CDR_SAT_DET_TIMER                     ),//0 to 3
    .PMA_REG_CDR_SAT_DET_STATUS_VAL              (PMA_CH2_REG_CDR_SAT_DET_STATUS_VAL                ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_STATUS_OW               (PMA_CH2_REG_CDR_SAT_DET_STATUS_OW                 ),//TRUE, FALSE;
    .PMA_REG_CDR_TURBO_MODE_EN                   (PMA_CH2_REG_CDR_TURBO_MODE_EN                     ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_190                     (PMA_CH2_REG_RX_RESERVED_190                       ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_193_191                 (PMA_CH2_REG_RX_RESERVED_193_191                   ),//0 to 7
    .PMA_REG_CDR_STATUS_FIFO_EN                  (PMA_CH2_REG_CDR_STATUS_FIFO_EN                    ),//TRUE, FALSE;
    .PMA_REG_PMA_TEST_SEL                        (PMA_CH2_REG_PMA_TEST_SEL                          ),//0,1
    .PMA_REG_OOB_COMWAKE_GAP_MIN                 (PMA_CH2_REG_OOB_COMWAKE_GAP_MIN                   ),//0 to 63
    .PMA_REG_OOB_COMWAKE_GAP_MAX                 (PMA_CH2_REG_OOB_COMWAKE_GAP_MAX                   ),//0 to 63
    .PMA_REG_OOB_COMINIT_GAP_MIN                 (PMA_CH2_REG_OOB_COMINIT_GAP_MIN                   ),//0 to 255
    .PMA_REG_OOB_COMINIT_GAP_MAX                 (PMA_CH2_REG_OOB_COMINIT_GAP_MAX                   ),//0 to 255
    .PMA_REG_RX_RESERVED_227_226                 (PMA_CH2_REG_RX_RESERVED_227_226                   ),//0 to 3
    .PMA_REG_COMWAKE_STATUS_CLEAR                (PMA_CH2_REG_COMWAKE_STATUS_CLEAR                  ),//0,1
    .PMA_REG_COMINIT_STATUS_CLEAR                (PMA_CH2_REG_COMINIT_STATUS_CLEAR                  ),//0,1
    .PMA_REG_RX_SYNC_RST_N_EN                    (PMA_CH2_REG_RX_SYNC_RST_N_EN                      ),//TRUE, FALSE;
    .PMA_REG_RX_SYNC_RST_N                       (PMA_CH2_REG_RX_SYNC_RST_N                         ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_233_232                 (PMA_CH2_REG_RX_RESERVED_233_232                   ),//0 to 3
    .PMA_REG_RX_RESERVED_235_234                 (PMA_CH2_REG_RX_RESERVED_235_234                   ),//0 to 3
    .PMA_REG_RX_SATA_COMINIT_OW                  (PMA_CH2_REG_RX_SATA_COMINIT_OW                    ),//TRUE, FALSE;
    .PMA_REG_RX_SATA_COMINIT                     (PMA_CH2_REG_RX_SATA_COMINIT                       ),//TRUE, FALSE;
    .PMA_REG_RX_SATA_COMWAKE_OW                  (PMA_CH2_REG_RX_SATA_COMWAKE_OW                    ),//TRUE, FALSE;
    .PMA_REG_RX_SATA_COMWAKE                     (PMA_CH2_REG_RX_SATA_COMWAKE                       ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_241_240                 (PMA_CH2_REG_RX_RESERVED_241_240                   ),//0 to 3
    .PMA_REG_RX_DCC_DISABLE                      (PMA_CH2_REG_RX_DCC_DISABLE                        ),//TRUE, FALSE; for rx dcc disable control
    .PMA_REG_RX_RESERVED_243                     (PMA_CH2_REG_RX_RESERVED_243                       ),//TRUE, FALSE;
    .PMA_REG_RX_SLIP_SEL_EN                      (PMA_CH2_REG_RX_SLIP_SEL_EN                        ),//TRUE, FALSE;
    .PMA_REG_RX_SLIP_SEL                         (PMA_CH2_REG_RX_SLIP_SEL                           ),//0 to 15
    .PMA_REG_RX_SLIP_EN                          (PMA_CH2_REG_RX_SLIP_EN                            ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_STATUS_SEL                (PMA_CH2_REG_RX_SIGDET_STATUS_SEL                  ),//0 to 7
    .PMA_REG_RX_SIGDET_FSM_RST_N                 (PMA_CH2_REG_RX_SIGDET_FSM_RST_N                   ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_254                     (PMA_CH2_REG_RX_RESERVED_254                       ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_STATUS                    (PMA_CH2_REG_RX_SIGDET_STATUS                      ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_VTH                       (PMA_CH2_REG_RX_SIGDET_VTH                         ),//"45MV" "54MV" "63MV" "72MV"
    .PMA_REG_RX_SIGDET_GRM                       (PMA_CH2_REG_RX_SIGDET_GRM                         ),//0,1,2,3
    .PMA_REG_RX_SIGDET_PULSE_EXT                 (PMA_CH2_REG_RX_SIGDET_PULSE_EXT                   ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_CH2_SEL                   (PMA_CH2_REG_RX_SIGDET_CH2_SEL                     ),//0,1
    .PMA_REG_RX_SIGDET_CH2_CHK_WINDOW            (PMA_CH2_REG_RX_SIGDET_CH2_CHK_WINDOW              ),//0 to 31
    .PMA_REG_RX_SIGDET_CHK_WINDOW_EN             (PMA_CH2_REG_RX_SIGDET_CHK_WINDOW_EN               ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_NOSIG_COUNT_SETTING       (PMA_CH2_REG_RX_SIGDET_NOSIG_COUNT_SETTING         ),//0 to 7
    .PMA_REG_SLIP_FIFO_INV_EN                    (PMA_CH2_REG_SLIP_FIFO_INV_EN                      ),//TRUE, FALSE;
    .PMA_REG_SLIP_FIFO_INV                       (PMA_CH2_REG_SLIP_FIFO_INV                         ),//"POS_EDGE" "NEG_EDGE"
    .PMA_REG_RX_SIGDET_OOB_DET_COUNT_VAL         (PMA_CH2_REG_RX_SIGDET_OOB_DET_COUNT_VAL           ),//0 to 31
    .PMA_REG_RX_SIGDET_4OOB_DET_SEL              (PMA_CH2_REG_RX_SIGDET_4OOB_DET_SEL                ),//0 to 7
    .PMA_REG_RX_RESERVED_285_283                 (PMA_CH2_REG_RX_RESERVED_285_283                   ),//0 to 7
    .PMA_REG_RX_RESERVED_286                     (PMA_CH2_REG_RX_RESERVED_286                       ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_IC_I                      (PMA_CH2_REG_RX_SIGDET_IC_I                        ),//0 to 15
    .PMA_REG_RX_OOB_DETECTOR_RESET_N_OW          (PMA_CH2_REG_RX_OOB_DETECTOR_RESET_N_OW            ),//TRUE, FALSE;
    .PMA_REG_RX_OOB_DETECTOR_RESET_N             (PMA_CH2_REG_RX_OOB_DETECTOR_RESET_N               ),//TRUE, FALSE;for rx oob detector Reset
    .PMA_REG_RX_OOB_DETECTOR_PD_OW               (PMA_CH2_REG_RX_OOB_DETECTOR_PD_OW                 ),//TRUE, FALSE;
    .PMA_REG_RX_OOB_DETECTOR_PD                  (PMA_CH2_REG_RX_OOB_DETECTOR_PD                    ),//TRUE, FALSE;for rx oob detector powerdown
    .PMA_REG_RX_LS_MODE_EN                       (PMA_CH2_REG_RX_LS_MODE_EN                         ),//TRUE, FALSE;for Enable Low-speed mode
    .PMA_REG_ANA_RX_EQ1_R_SET_FB_O_SEL           (PMA_CH2_REG_ANA_RX_EQ1_R_SET_FB_O_SEL             ),//TRUE, FALSE;
    .PMA_REG_ANA_RX_EQ2_R_SET_FB_O_SEL           (PMA_CH2_REG_ANA_RX_EQ2_R_SET_FB_O_SEL             ),//TRUE, FALSE;
    .PMA_REG_RX_EQ1_R_SET_TOP                    (PMA_CH2_REG_RX_EQ1_R_SET_TOP                      ),//0 to 3
    .PMA_REG_RX_EQ1_R_SET_FB                     (PMA_CH2_REG_RX_EQ1_R_SET_FB                       ),//0 to 15
    .PMA_REG_RX_EQ1_C_SET_FB                     (PMA_CH2_REG_RX_EQ1_C_SET_FB                       ),//0 to 15
    .PMA_REG_RX_EQ1_OFF                          (PMA_CH2_REG_RX_EQ1_OFF                            ),//TRUE, FALSE;
    .PMA_REG_RX_EQ2_R_SET_TOP                    (PMA_CH2_REG_RX_EQ2_R_SET_TOP                      ),//0 to 3
    .PMA_REG_RX_EQ2_R_SET_FB                     (PMA_CH2_REG_RX_EQ2_R_SET_FB                       ),//0 to 15
    .PMA_REG_RX_EQ2_C_SET_FB                     (PMA_CH2_REG_RX_EQ2_C_SET_FB                       ),//0 to 15
    .PMA_REG_RX_EQ2_OFF                          (PMA_CH2_REG_RX_EQ2_OFF                            ),//TRUE, FALSE;
    .PMA_REG_EQ_DAC                              (PMA_CH2_REG_EQ_DAC                                ),//0 to 63
    .PMA_REG_RX_ICTRL_EQ                         (PMA_CH2_REG_RX_ICTRL_EQ                           ),//TRUE, FALSE;
    .PMA_REG_EQ_DC_CALIB_EN                      (PMA_CH2_REG_EQ_DC_CALIB_EN                        ),//TRUE, FALSE;
    .PMA_REG_EQ_DC_CALIB_SEL                     (PMA_CH2_REG_EQ_DC_CALIB_SEL                       ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_337_330                 (PMA_CH2_REG_RX_RESERVED_337_330                   ),//0 to 255
    .PMA_REG_RX_RESERVED_345_338                 (PMA_CH2_REG_RX_RESERVED_345_338                   ),//0 to 255
    .PMA_REG_RX_RESERVED_353_346                 (PMA_CH2_REG_RX_RESERVED_353_346                   ),//0 to 255
    .PMA_REG_RX_RESERVED_361_354                 (PMA_CH2_REG_RX_RESERVED_361_354                   ),//0 to 255
    .PMA_CTLE_CTRL_REG_I                         (PMA_CH2_CTLE_CTRL_REG_I                           ),//0 to 15
    .PMA_CTLE_REG_FORCE_SEL_I                    (PMA_CH2_CTLE_REG_FORCE_SEL_I                      ),//TRUE, FALSE;for ctrl self-adaption adjust
    .PMA_CTLE_REG_HOLD_I                         (PMA_CH2_CTLE_REG_HOLD_I                           ),//TRUE, FALSE;
    .PMA_CTLE_REG_INIT_DAC_I                     (PMA_CH2_CTLE_REG_INIT_DAC_I                       ),//0 to 15
    .PMA_CTLE_REG_POLARITY_I                     (PMA_CH2_CTLE_REG_POLARITY_I                       ),//TRUE, FALSE;
    .PMA_CTLE_REG_SHIFTER_GAIN_I                 (PMA_CH2_CTLE_REG_SHIFTER_GAIN_I                   ),//0 to 7
    .PMA_CTLE_REG_THRESHOLD_I                    (PMA_CH2_CTLE_REG_THRESHOLD_I                      ),//0 to 4095
    .PMA_REG_RX_RES_TRIM_EN                      (PMA_CH2_REG_RX_RES_TRIM_EN                        ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_393_389                 (PMA_CH2_REG_RX_RESERVED_393_389                   ),//0 to 31
    .PMA_CFG_RX_LANE_POWERUP                     (PMA_CH2_CFG_RX_LANE_POWERUP                       ),//ON, OFF;for RX_LANE Power-up
    .PMA_CFG_RX_PMA_RSTN                         (PMA_CH2_CFG_RX_PMA_RSTN                           ),//TRUE, FALSE;for RX_PMA Reset
    .PMA_INT_PMA_RX_MASK_0                       (PMA_CH2_INT_PMA_RX_MASK_0                         ),//TRUE, FALSE;
    .PMA_INT_PMA_RX_CLR_0                        (PMA_CH2_INT_PMA_RX_CLR_0                          ),//TRUE, FALSE;
    .PMA_CFG_CTLE_ADP_RSTN                       (PMA_CH2_CFG_CTLE_ADP_RSTN                         ),//TRUE, FALSE;for ctrl Reset
    //pma_tx                                                                                      
    .PMA_REG_TX_PD                               (PMA_CH2_REG_TX_PD                                 ),//ON, OFF;for transmitter power down
    .PMA_REG_TX_PD_OW                            (PMA_CH2_REG_TX_PD_OW                              ),//TRUE, FALSE;
    .PMA_REG_TX_MAIN_PRE_Z                       (PMA_CH2_REG_TX_MAIN_PRE_Z                         ),//TRUE, FALSE;Enable EI for PCIE mode
    .PMA_REG_TX_MAIN_PRE_Z_OW                    (PMA_CH2_REG_TX_MAIN_PRE_Z_OW                      ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_TIMER_SEL                 (PMA_CH2_REG_TX_BEACON_TIMER_SEL                   ),//0 to 3
    .PMA_REG_TX_RXDET_REQ_OW                     (PMA_CH2_REG_TX_RXDET_REQ_OW                       ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_REQ                        (PMA_CH2_REG_TX_RXDET_REQ                          ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_EN_OW                     (PMA_CH2_REG_TX_BEACON_EN_OW                       ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_EN                        (PMA_CH2_REG_TX_BEACON_EN                          ),//TRUE, FALSE;
    .PMA_REG_TX_EI_EN_OW                         (PMA_CH2_REG_TX_EI_EN_OW                           ),//TRUE, FALSE;
    .PMA_REG_TX_EI_EN                            (PMA_CH2_REG_TX_EI_EN                              ),//TRUE, FALSE;
    .PMA_REG_TX_BIT_CONV                         (PMA_CH2_REG_TX_BIT_CONV                           ),//TRUE, FALSE;
    .PMA_REG_TX_RES_CAL                          (PMA_CH2_REG_TX_RES_CAL                            ),//0 to 63
    .PMA_REG_TX_RESERVED_19                      (PMA_CH2_REG_TX_RESERVED_19                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_25_20                   (PMA_CH2_REG_TX_RESERVED_25_20                     ),//0 to 63
    .PMA_REG_TX_RESERVED_33_26                   (PMA_CH2_REG_TX_RESERVED_33_26                     ),//0 to 255
    .PMA_REG_TX_RESERVED_41_34                   (PMA_CH2_REG_TX_RESERVED_41_34                     ),//0 to 255
    .PMA_REG_TX_RESERVED_49_42                   (PMA_CH2_REG_TX_RESERVED_49_42                     ),//0 to 255
    .PMA_REG_TX_RESERVED_57_50                   (PMA_CH2_REG_TX_RESERVED_57_50                     ),//0 to 255
    .PMA_REG_TX_SYNC_OW                          (PMA_CH2_REG_TX_SYNC_OW                            ),//TRUE, FALSE;
    .PMA_REG_TX_SYNC                             (PMA_CH2_REG_TX_SYNC                               ),//TRUE, FALSE;
    .PMA_REG_TX_PD_POST                          (PMA_CH2_REG_TX_PD_POST                            ),//ON, OFF;
    .PMA_REG_TX_PD_POST_OW                       (PMA_CH2_REG_TX_PD_POST_OW                         ),//TRUE, FALSE;
    .PMA_REG_TX_RESET_N_OW                       (PMA_CH2_REG_TX_RESET_N_OW                         ),//TRUE, FALSE;
    .PMA_REG_TX_RESET_N                          (PMA_CH2_REG_TX_RESET_N                            ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_64                      (PMA_CH2_REG_TX_RESERVED_64                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_65                      (PMA_CH2_REG_TX_RESERVED_65                        ),//TRUE, FALSE;
    .PMA_REG_TX_BUSWIDTH_OW                      (PMA_CH2_REG_TX_BUSWIDTH_OW                        ),//TRUE, FALSE;
    .PMA_REG_TX_BUSWIDTH                         (PMA_CH2_REG_TX_BUSWIDTH                           ),//"8BIT" "10BIT" "16BIT" "20BIT"
    .PMA_REG_PLL_READY_OW                        (PMA_CH2_REG_PLL_READY_OW                          ),//TRUE, FALSE;
    .PMA_REG_PLL_READY                           (PMA_CH2_REG_PLL_READY                             ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_72                      (PMA_CH2_REG_TX_RESERVED_72                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_73                      (PMA_CH2_REG_TX_RESERVED_73                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_74                      (PMA_CH2_REG_TX_RESERVED_74                        ),//TRUE, FALSE;
    .PMA_REG_EI_PCLK_DELAY_SEL                   (PMA_CH2_REG_EI_PCLK_DELAY_SEL                     ),//0 to 3
    .PMA_REG_TX_RESERVED_77                      (PMA_CH2_REG_TX_RESERVED_77                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_83_78                   (PMA_CH2_REG_TX_RESERVED_83_78                     ),//0 to 63
    .PMA_REG_TX_RESERVED_89_84                   (PMA_CH2_REG_TX_RESERVED_89_84                     ),//0 to 63
    .PMA_REG_TX_RESERVED_95_90                   (PMA_CH2_REG_TX_RESERVED_95_90                     ),//0 to 63
    .PMA_REG_TX_RESERVED_101_96                  (PMA_CH2_REG_TX_RESERVED_101_96                    ),//0 to 63
    .PMA_REG_TX_RESERVED_107_102                 (PMA_CH2_REG_TX_RESERVED_107_102                   ),//0 to 63
    .PMA_REG_TX_RESERVED_113_108                 (PMA_CH2_REG_TX_RESERVED_113_108                   ),//0 to 63
    .PMA_REG_TX_AMP_DAC0                         (PMA_CH2_REG_TX_AMP_DAC0                           ),//0 to 63
    .PMA_REG_TX_AMP_DAC1                         (PMA_CH2_REG_TX_AMP_DAC1                           ),//0 to 63
    .PMA_REG_TX_AMP_DAC2                         (PMA_CH2_REG_TX_AMP_DAC2                           ),//0 to 63
    .PMA_REG_TX_AMP_DAC3                         (PMA_CH2_REG_TX_AMP_DAC3                           ),//0 to 63
    .PMA_REG_TX_RESERVED_143_138                 (PMA_CH2_REG_TX_RESERVED_143_138                   ),//0 to 63
    .PMA_REG_TX_MARGIN                           (PMA_CH2_REG_TX_MARGIN                             ),//0 to 7
    .PMA_REG_TX_MARGIN_OW                        (PMA_CH2_REG_TX_MARGIN_OW                          ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_149_148                 (PMA_CH2_REG_TX_RESERVED_149_148                   ),//0 to 3
    .PMA_REG_TX_RESERVED_150                     (PMA_CH2_REG_TX_RESERVED_150                       ),//TRUE, FALSE;
    .PMA_REG_TX_SWING                            (PMA_CH2_REG_TX_SWING                              ),//TRUE, FALSE;
    .PMA_REG_TX_SWING_OW                         (PMA_CH2_REG_TX_SWING_OW                           ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_153                     (PMA_CH2_REG_TX_RESERVED_153                       ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_THRESHOLD                  (PMA_CH2_REG_TX_RXDET_THRESHOLD                    ),//"28MV" "56MV" "84MV" "112MV"
    .PMA_REG_TX_RESERVED_157_156                 (PMA_CH2_REG_TX_RESERVED_157_156                   ),//0 to 3
    .PMA_REG_TX_BEACON_OSC_CTRL                  (PMA_CH2_REG_TX_BEACON_OSC_CTRL                    ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_160_159                 (PMA_CH2_REG_TX_RESERVED_160_159                   ),//0 to 3
    .PMA_REG_TX_RESERVED_162_161                 (PMA_CH2_REG_TX_RESERVED_162_161                   ),//0 to 3
    .PMA_REG_TX_TX2RX_SLPBACK_EN                 (PMA_CH2_REG_TX_TX2RX_SLPBACK_EN                   ),//TRUE, FALSE;
    .PMA_REG_TX_PCLK_EDGE_SEL                    (PMA_CH2_REG_TX_PCLK_EDGE_SEL                      ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_STATUS_OW                  (PMA_CH2_REG_TX_RXDET_STATUS_OW                    ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_STATUS                     (PMA_CH2_REG_TX_RXDET_STATUS                       ),//TRUE, FALSE;
    .PMA_REG_TX_PRBS_GEN_EN                      (PMA_CH2_REG_TX_PRBS_GEN_EN                        ),//TRUE, FALSE;
    .PMA_REG_TX_PRBS_GEN_WIDTH_SEL               (PMA_CH2_REG_TX_PRBS_GEN_WIDTH_SEL                 ),//"8BIT" "10BIT" "16BIT" "20BIT"
    .PMA_REG_TX_PRBS_SEL                         (PMA_CH2_REG_TX_PRBS_SEL                           ),//"PRBS7" "PRBS15" "PRBS23" "PRBS31"
    .PMA_REG_TX_UDP_DATA_7_TO_0                  (PMA_CH2_REG_TX_UDP_DATA_7_TO_0                    ),//0 to 255
    .PMA_REG_TX_UDP_DATA_15_TO_8                 (PMA_CH2_REG_TX_UDP_DATA_15_TO_8                   ),//0 to 255
    .PMA_REG_TX_UDP_DATA_19_TO_16                (PMA_CH2_REG_TX_UDP_DATA_19_TO_16                  ),//0 to 15
    .PMA_REG_TX_RESERVED_192                     (PMA_CH2_REG_TX_RESERVED_192                       ),//TRUE, FALSE;
    .PMA_REG_TX_FIFO_WP_CTRL                     (PMA_CH2_REG_TX_FIFO_WP_CTRL                       ),//0 to 7
    .PMA_REG_TX_FIFO_EN                          (PMA_CH2_REG_TX_FIFO_EN                            ),//TRUE, FALSE;
    .PMA_REG_TX_DATA_MUX_SEL                     (PMA_CH2_REG_TX_DATA_MUX_SEL                       ),//0 to 3
    .PMA_REG_TX_ERR_INSERT                       (PMA_CH2_REG_TX_ERR_INSERT                         ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_203_200                 (PMA_CH2_REG_TX_RESERVED_203_200                   ),//0 to15
    .PMA_REG_TX_RESERVED_204                     (PMA_CH2_REG_TX_RESERVED_204                       ),//TRUE, FALSE;
    .PMA_REG_TX_SATA_EN                          (PMA_CH2_REG_TX_SATA_EN                            ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_207_206                 (PMA_CH2_REG_TX_RESERVED_207_206                   ),//0 to3
    .PMA_REG_RATE_CHANGE_TXPCLK_ON_OW            (PMA_CH2_REG_RATE_CHANGE_TXPCLK_ON_OW              ),//TRUE, FALSE;
    .PMA_REG_RATE_CHANGE_TXPCLK_ON               (PMA_CH2_REG_RATE_CHANGE_TXPCLK_ON                 ),//TRUE, FALSE;
    .PMA_REG_TX_CFG_POST1                        (PMA_CH2_REG_TX_CFG_POST1                          ),//0 to 31
    .PMA_REG_TX_CFG_POST2                        (PMA_CH2_REG_TX_CFG_POST2                          ),//0 to 31
    .PMA_REG_TX_DEEMP                            (PMA_CH2_REG_TX_DEEMP                              ),//0 to 3
    .PMA_REG_TX_DEEMP_OW                         (PMA_CH2_REG_TX_DEEMP_OW                           ),//TRUE, FALSE;for TX DEEMP Control
    .PMA_REG_TX_RESERVED_224_223                 (PMA_CH2_REG_TX_RESERVED_224_223                   ),//0 to 3
    .PMA_REG_TX_RESERVED_225                     (PMA_CH2_REG_TX_RESERVED_225                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_229_226                 (PMA_CH2_REG_TX_RESERVED_229_226                   ),//0 to 15
    .PMA_REG_TX_OOB_DELAY_SEL                    (PMA_CH2_REG_TX_OOB_DELAY_SEL                      ),//0 to 15
    .PMA_REG_TX_POLARITY                         (PMA_CH2_REG_TX_POLARITY                           ),//"NORMAL" "REVERSE"
    .PMA_REG_ANA_TX_JTAG_DATA_O_SEL              (PMA_CH2_REG_ANA_TX_JTAG_DATA_O_SEL                ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_236                     (PMA_CH2_REG_TX_RESERVED_236                       ),//TRUE, FALSE;
    .PMA_REG_TX_LS_MODE_EN                       (PMA_CH2_REG_TX_LS_MODE_EN                         ),//TRUE, FALSE;
    .PMA_REG_TX_JTAG_MODE_EN_OW                  (PMA_CH2_REG_TX_JTAG_MODE_EN_OW                    ),//TRUE, FALSE;
    .PMA_REG_TX_JTAG_MODE_EN                     (PMA_CH2_REG_TX_JTAG_MODE_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_JTAG_MODE_EN_OW                  (PMA_CH2_REG_RX_JTAG_MODE_EN_OW                    ),//TRUE, FALSE;
    .PMA_REG_RX_JTAG_MODE_EN                     (PMA_CH2_REG_RX_JTAG_MODE_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_JTAG_OE                          (PMA_CH2_REG_RX_JTAG_OE                            ),//TRUE, FALSE;
    .PMA_REG_RX_ACJTAG_VHYSTSEL                  (PMA_CH2_REG_RX_ACJTAG_VHYSTSEL                    ),//0 to 7
    .PMA_REG_TX_RES_CAL_EN                       (PMA_CH2_REG_TX_RES_CAL_EN                         ),//TRUE, FALSE;
    .PMA_REG_RX_TERM_MODE_CTRL                   (PMA_CH2_REG_RX_TERM_MODE_CTRL                     ),//0 to 7; for rx terminatin Control
    .PMA_REG_TX_RESERVED_251_250                 (PMA_CH2_REG_TX_RESERVED_251_250                   ),//0 to 7
    .PMA_REG_PLPBK_TXPCLK_EN                     (PMA_CH2_REG_PLPBK_TXPCLK_EN                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_253                     (PMA_CH2_REG_TX_RESERVED_253                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_254                     (PMA_CH2_REG_TX_RESERVED_254                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_255                     (PMA_CH2_REG_TX_RESERVED_255                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_256                     (PMA_CH2_REG_TX_RESERVED_256                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_257                     (PMA_CH2_REG_TX_RESERVED_257                       ),//TRUE, FALSE;
    .PMA_REG_TX_PH_SEL                           (PMA_CH2_REG_TX_PH_SEL                             ),//0 to 63
    .PMA_REG_TX_CFG_PRE                          (PMA_CH2_REG_TX_CFG_PRE                            ),//0 to 31
    .PMA_REG_TX_CFG_MAIN                         (PMA_CH2_REG_TX_CFG_MAIN                           ),//0 to 63
    .PMA_REG_CFG_POST                            (PMA_CH2_REG_CFG_POST                              ),//0 to 31
    .PMA_REG_PD_MAIN                             (PMA_CH2_REG_PD_MAIN                               ),//TRUE, FALSE;
    .PMA_REG_PD_PRE                              (PMA_CH2_REG_PD_PRE                                ),//TRUE, FALSE;
    .PMA_REG_TX_LS_DATA                          (PMA_CH2_REG_TX_LS_DATA                            ),//TRUE, FALSE;
    .PMA_REG_TX_DCC_BUF_SZ_SEL                   (PMA_CH2_REG_TX_DCC_BUF_SZ_SEL                     ),//0 to 3
    .PMA_REG_TX_DCC_CAL_CUR_TUNE                 (PMA_CH2_REG_TX_DCC_CAL_CUR_TUNE                   ),//0 to 63
    .PMA_REG_TX_DCC_CAL_EN                       (PMA_CH2_REG_TX_DCC_CAL_EN                         ),//TRUE, FALSE;
    .PMA_REG_TX_DCC_CUR_SS                       (PMA_CH2_REG_TX_DCC_CUR_SS                         ),//0 to 3
    .PMA_REG_TX_DCC_FA_CTRL                      (PMA_CH2_REG_TX_DCC_FA_CTRL                        ),//TRUE, FALSE;
    .PMA_REG_TX_DCC_RI_CTRL                      (PMA_CH2_REG_TX_DCC_RI_CTRL                        ),//TRUE, FALSE;
    .PMA_REG_ATB_SEL_2_TO_0                      (PMA_CH2_REG_ATB_SEL_2_TO_0                        ),//0 to 7
    .PMA_REG_ATB_SEL_9_TO_3                      (PMA_CH2_REG_ATB_SEL_9_TO_3                        ),//0 to 127
    .PMA_REG_TX_CFG_7_TO_0                       (PMA_CH2_REG_TX_CFG_7_TO_0                         ),//0 to 255
    .PMA_REG_TX_CFG_15_TO_8                      (PMA_CH2_REG_TX_CFG_15_TO_8                        ),//0 to 255
    .PMA_REG_TX_CFG_23_TO_16                     (PMA_CH2_REG_TX_CFG_23_TO_16                       ),//0 to 255
    .PMA_REG_TX_CFG_31_TO_24                     (PMA_CH2_REG_TX_CFG_31_TO_24                       ),//0 to 255
    .PMA_REG_TX_OOB_EI_EN                        (PMA_CH2_REG_TX_OOB_EI_EN                          ),//TRUE, FALSE; Enable OOB EI for SATA mode
    .PMA_REG_TX_OOB_EI_EN_OW                     (PMA_CH2_REG_TX_OOB_EI_EN_OW                       ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_EN_DELAYED                (PMA_CH2_REG_TX_BEACON_EN_DELAYED                  ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_EN_DELAYED_OW             (PMA_CH2_REG_TX_BEACON_EN_DELAYED_OW               ),//TRUE, FALSE;
    .PMA_REG_TX_JTAG_DATA                        (PMA_CH2_REG_TX_JTAG_DATA                          ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_TIMER_SEL                  (PMA_CH2_REG_TX_RXDET_TIMER_SEL                    ),//0 to 255
    .PMA_REG_TX_CFG1_7_0                         (PMA_CH2_REG_TX_CFG1_7_0                           ),//0 to 255
    .PMA_REG_TX_CFG1_15_8                        (PMA_CH2_REG_TX_CFG1_15_8                          ),//0 to 255
    .PMA_REG_TX_CFG1_23_16                       (PMA_CH2_REG_TX_CFG1_23_16                         ),//0 to 255
    .PMA_REG_TX_CFG1_31_24                       (PMA_CH2_REG_TX_CFG1_31_24                         ),//0 to 255
    .PMA_REG_CFG_LANE_POWERUP                    (PMA_CH2_REG_CFG_LANE_POWERUP                      ),//ON, OFF; for PMA_LANE powerup
    .PMA_REG_CFG_TX_LANE_POWERUP_CLKPATH         (PMA_CH2_REG_CFG_TX_LANE_POWERUP_CLKPATH           ),//TRUE, FALSE; for Pma tx lane clkpath powerup
    .PMA_REG_CFG_TX_LANE_POWERUP_PISO            (PMA_CH2_REG_CFG_TX_LANE_POWERUP_PISO              ),//TRUE, FALSE; for Pma tx lane piso powerup
    .PMA_REG_CFG_TX_LANE_POWERUP_DRIVER          (PMA_CH2_REG_CFG_TX_LANE_POWERUP_DRIVER            ) //TRUE, FALSE; for Pma tx lane driver powerup
) U_GTP_HSSTLP_LANE2 (
    //PAD
    .P_TX_SDN                               (P_TX_SDN_2            ),//output              
    .P_TX_SDP                               (P_TX_SDP_2            ),//output              
    //SRB related                           
    .P_PCS_RX_MCB_STATUS                    (P_PCS_RX_MCB_STATUS_2 ),//output              
    .P_PCS_LSM_SYNCED                       (P_PCS_LSM_SYNCED_2    ),//output              
    .P_CFG_READY                            (P_CFG_READY_2         ),//output              
    .P_CFG_RDATA                            (P_CFG_RDATA_2         ),//output [7:0]        
    .P_CFG_INT                              (P_CFG_INT_2           ),//output              
    .P_RDATA                                (P_RDATA_2             ),//output [46:0]       
    .P_RCLK2FABRIC                          (P_RCLK2FABRIC_2       ),//output              
    .P_TCLK2FABRIC                          (P_TCLK2FABRIC_2       ),//output              
    .P_RX_SIGDET_STATUS                     (P_RX_SIGDET_STATUS_2  ),//output              
    .P_RX_SATA_COMINIT                      (P_RX_SATA_COMINIT_2   ),//output              
    .P_RX_SATA_COMWAKE                      (P_RX_SATA_COMWAKE_2   ),//output              
    .P_RX_LS_DATA                           (P_RX_LS_DATA_2        ),//output              
    .P_RX_READY                             (P_RX_READY_2          ),//output              
    .P_TEST_STATUS                          (P_TEST_STATUS_2       ),//output [19:0]       
    .P_TX_RXDET_STATUS                      (P_TX_RXDET_STATUS_2   ),//output              
    .P_CA_ALIGN_RX                          (P_CA_ALIGN_RX_2       ),//output              
    .P_CA_ALIGN_TX                          (P_CA_ALIGN_TX_2       ),//output              
    //out                                    
    .PMA_RCLK                               (PMA_RCLK_2            ),//output       	    
    .TXPCLK_PLL                             (TXPCLK_PLL_2          ),//output              
    //cin and cout                           
    .LANE_COUT_BUS_FORWARD                  (LANE_COUT_BUS_FORWARD_2),//output [18:0]       
    .APATTERN_STATUS_COUT                   (APATTERN_STATUS_COUT_2),//output              
    //PAD                                     
    .P_RX_SDN                               (P_RX_SDN_2            ),//input               
    .P_RX_SDP                               (P_RX_SDP_2            ),//input               
    //SRB related                            
    .P_RX_CLK_FR_CORE                       (P_RX_CLK_FR_CORE_2    ),//input               
    .P_RCLK2_FR_CORE                        (P_RCLK2_FR_CORE_2     ),//input               
    .P_TX_CLK_FR_CORE                       (P_TX_CLK_FR_CORE_2    ),//input               
    .P_TCLK2_FR_CORE                        (P_TCLK2_FR_CORE_2     ),//input               
    .P_PCS_TX_RST                           (P_PCS_TX_RST_2        ),//input               
    .P_PCS_RX_RST                           (P_PCS_RX_RST_2        ),//input               
    .P_PCS_CB_RST                           (P_PCS_CB_RST_2        ),//input               
    .P_RXGEAR_SLIP                          (P_RXGEAR_SLIP_2       ),//input               
    .P_CFG_CLK                              (P_CFG_CLK_2           ),//input               
    .P_CFG_RST                              (P_CFG_RST_2           ),//input               
    .P_CFG_PSEL                             (P_CFG_PSEL_2          ),//input               
    .P_CFG_ENABLE                           (P_CFG_ENABLE_2        ),//input               
    .P_CFG_WRITE                            (P_CFG_WRITE_2         ),//input               
    .P_CFG_ADDR                             (P_CFG_ADDR_2          ),//input [11:0]        
    .P_CFG_WDATA                            (P_CFG_WDATA_2         ),//input [7:0]         
    .P_TDATA                                (P_TDATA_2             ),//input [45:0]        
    .P_PCS_WORD_ALIGN_EN                    (P_PCS_WORD_ALIGN_EN_2 ),//input               
    .P_RX_POLARITY_INVERT                   (P_RX_POLARITY_INVERT_2),//input               
    .P_CEB_ADETECT_EN                       (P_CEB_ADETECT_EN_2    ),//input               
    .P_PCS_MCB_EXT_EN                       (P_PCS_MCB_EXT_EN_2    ),//input               
    .P_PCS_NEAREND_LOOP                     (P_PCS_NEAREND_LOOP_2  ),//input               
    .P_PCS_FAREND_LOOP                      (P_PCS_FAREND_LOOP_2   ),//input               
    .P_PMA_NEAREND_PLOOP                    (P_PMA_NEAREND_PLOOP_2 ),//input               
    .P_PMA_NEAREND_SLOOP                    (P_PMA_NEAREND_SLOOP_2 ),//input               
    .P_PMA_FAREND_PLOOP                     (P_PMA_FAREND_PLOOP_2  ),//input               
                                                                 
    .P_LANE_PD                              (P_LANE_PD_2           ),//input               
    .P_LANE_RST                             (P_LANE_RST_2          ),//input               
    .P_RX_LANE_PD                           (P_RX_LANE_PD_2        ),//input               
    .P_RX_PMA_RST                           (P_RX_PMA_RST_2        ),//input               
    .P_CTLE_ADP_RST                         (P_CTLE_ADP_RST_2      ),//input               
    .P_TX_DEEMP                             (P_TX_DEEMP_2          ),//input [1:0]         
    .P_TX_LS_DATA                           (P_TX_LS_DATA_2        ),//input               
    .P_TX_BEACON_EN                         (P_TX_BEACON_EN_2      ),//input               
    .P_TX_SWING                             (P_TX_SWING_2          ),//input               
    .P_TX_RXDET_REQ                         (P_TX_RXDET_REQ_2      ),//input               
    .P_TX_RATE                              (P_TX_RATE_2           ),//input [2:0]         
    .P_TX_BUSWIDTH                          (P_TX_BUSWIDTH_2       ),//input [2:0]         
    .P_TX_MARGIN                            (P_TX_MARGIN_2         ),//input [2:0]         
    .P_TX_PMA_RST                           (P_TX_PMA_RST_2        ),//input               
    .P_TX_LANE_PD_CLKPATH                   (P_TX_LANE_PD_CLKPATH_2),//input               
    .P_TX_LANE_PD_PISO                      (P_TX_LANE_PD_PISO_2   ),//input               
    .P_TX_LANE_PD_DRIVER                    (P_TX_LANE_PD_DRIVER_2 ),//input               
    .P_RX_RATE                              (P_RX_RATE_2           ),//input [2:0]         
    .P_RX_BUSWIDTH                          (P_RX_BUSWIDTH_2       ),//input [2:0]         
    .P_RX_HIGHZ                             (P_RX_HIGHZ_2          ),//input               
    .P_CIM_CLK_ALIGNER_RX                   (P_CIM_CLK_ALIGNER_RX_2),//input [7:0]         
    .P_CIM_CLK_ALIGNER_TX                   (P_CIM_CLK_ALIGNER_TX_2),//input [7:0]         
    .P_CIM_DYN_DLY_SEL_RX                   (P_CIM_DYN_DLY_SEL_RX_2),//input               
    .P_CIM_DYN_DLY_SEL_TX                   (P_CIM_DYN_DLY_SEL_TX_2),//input               
    .P_CIM_START_ALIGN_RX                   (P_CIM_START_ALIGN_RX_2),//input               
    .P_CIM_START_ALIGN_TX                   (P_CIM_START_ALIGN_TX_2),//input               
    //New Added                                      
    .MCB_RCLK                               (MCB_RCLK_2            ),//input               
    .SYNC                                   (SYNC_2                ),//input               
    .RATE_CHANGE                            (RATE_CHANGE_2         ),//input               
    .PLL_LOCK_SEL                           (PLL_LOCK_SEL_2        ),//input               
    //cin and cout                           
    .LANE_CIN_BUS_FORWARD                   (LANE_CIN_BUS_FORWARD_2),//input [18:0]        
    .APATTERN_STATUS_CIN                    (APATTERN_STATUS_CIN_2 ),//input               
    //From PLL                                  
    .CLK_TXP                                (CLK_TXP_2             ),//input               
    .CLK_TXN                                (CLK_TXN_2             ),//input               
    .CLK_RX0                                (CLK_RX0_2             ),//input               
    .CLK_RX90                               (CLK_RX90_2            ),//input               
    .CLK_RX180                              (CLK_RX180_2           ),//input               
    .CLK_RX270                              (CLK_RX270_2           ),//input               
    .PLL_PD_I                               (PLL_PD_I_2            ),//input               
    .PLL_RESET_I                            (PLL_RESET_I_2         ),//input               
    .PLL_REFCLK_I                           (PLL_REFCLK_I_2        ),//input               
    .PLL_RES_TRIM_I                         (PLL_RES_TRIM_I_2      ) //input [5:0]         
);
end
else begin:CHANNEL2_NULL //output default value to be done
    assign      P_TX_SDN_2                      = 1'b0 ;//output              
    assign      P_TX_SDP_2                      = 1'b0 ;//output              
    assign      P_PCS_RX_MCB_STATUS_2           = 1'b0 ;//output              
    assign      P_PCS_LSM_SYNCED_2              = 1'b0 ;//output              
    assign      P_CFG_READY_2                   = 1'b0 ;//output              
    assign      P_CFG_RDATA_2                   = 8'b0 ;//output [7:0]        
    assign      P_CFG_INT_2                     = 1'b0 ;//output              
    assign      P_RDATA_2                       = 47'b0;//output [46:0]       
    assign      P_RCLK2FABRIC_2                 = 1'b0 ;//output              
    assign      P_TCLK2FABRIC_2                 = 1'b0 ;//output              
    assign      P_RX_SIGDET_STATUS_2            = 1'b0 ;//output              
    assign      P_RX_SATA_COMINIT_2             = 1'b0 ;//output              
    assign      P_RX_SATA_COMWAKE_2             = 1'b0 ;//output              
    assign      P_RX_LS_DATA_2                  = 1'b0 ;//output              
    assign      P_RX_READY_2                    = 1'b0 ;//output              
    assign      P_TEST_STATUS_2                 = 20'b0;//output [19:0]       
    assign      P_TX_RXDET_STATUS_2             = 1'b0 ;//output              
    assign      P_CA_ALIGN_RX_2                 = 1'b0 ;//output              
    assign      P_CA_ALIGN_TX_2                 = 1'b0 ;//output              
    assign      PMA_RCLK_2                      = 1'b0 ;//output       	    
    assign      TXPCLK_PLL_2                    = 1'b0 ;//output              
    assign      LANE_COUT_BUS_FORWARD_2         = 19'b0;//output [18:0]       
    assign      APATTERN_STATUS_COUT_2          = 1'b0 ;//output              
end
endgenerate

//--------CHANNEL3 instance--------//
generate
if(CHANNEL3_EN == "TRUE") begin:CHANNEL3_ENABLE
GTP_HSSTLP_LANE#(
    .MUX_BIAS                                    (CH3_MUX_BIAS                                      ),//0 to 7; don't support simulation
    .PD_CLK                                      (CH3_PD_CLK                                        ),//0 to 1
    .REG_SYNC                                    (CH3_REG_SYNC                                      ),//0 to 1
    .REG_SYNC_OW                                 (CH3_REG_SYNC_OW                                   ),//0 to 1
    .PLL_LOCK_OW                                 (CH3_PLL_LOCK_OW                                   ),//0 to 1
    .PLL_LOCK_OW_EN                              (CH3_PLL_LOCK_OW_EN                                ),//0 to 1
    //pcs
    .PCS_SLAVE                                   (PCS_CH3_SLAVE                                     ),
    .PCS_BYPASS_WORD_ALIGN                       (PCS_CH3_BYPASS_WORD_ALIGN                         ),//TRUE, FALSE; for bypass word alignment
    .PCS_BYPASS_DENC                             (PCS_CH3_BYPASS_DENC                               ),//TRUE, FALSE; for bypass 8b/10b decoder
    .PCS_BYPASS_BONDING                          (PCS_CH3_BYPASS_BONDING                            ),//TRUE, FALSE; for bypass channel bonding
    .PCS_BYPASS_CTC                              (PCS_CH3_BYPASS_CTC                                ),//TRUE, FALSE; for bypass ctc
    .PCS_BYPASS_GEAR                             (PCS_CH3_BYPASS_GEAR                               ),//TRUE, FALSE; for bypass Rx Gear
    .PCS_BYPASS_BRIDGE                           (PCS_CH3_BYPASS_BRIDGE                             ),//TRUE, FALSE; for bypass Rx Bridge unit
    .PCS_BYPASS_BRIDGE_FIFO                      (PCS_CH3_BYPASS_BRIDGE_FIFO                        ),//TRUE, FALSE; for bypass Rx Bridge FIFO
    .PCS_DATA_MODE                               (PCS_CH3_DATA_MODE                                 ),//"X8","X10","X16","X20"
    .PCS_RX_POLARITY_INV                         (PCS_CH3_RX_POLARITY_INV                           ),//"DELAY","BIT_POLARITY_INVERION","BIT_REVERSAL","BOTH"
    .PCS_ALIGN_MODE                              (PCS_CH3_ALIGN_MODE                                ),//1GB, 10GB, RAPIDIO, OUTSIDE
    .PCS_SAMP_16B                                (PCS_CH3_SAMP_16B                                  ),//"X20",X16
    .PCS_FARLP_PWR_REDUCTION                     (PCS_CH3_FARLP_PWR_REDUCTION                       ),//TRUE, FALSE;
    .PCS_COMMA_REG0                              (PCS_CH3_COMMA_REG0                                ),//0 to 1023
    .PCS_COMMA_MASK                              (PCS_CH3_COMMA_MASK                                ),//0 to 1023
    .PCS_CEB_MODE                                (PCS_CH3_CEB_MODE                                  ),//"10GB" "RAPIDIO" "OUTSIDE"
    .PCS_CTC_MODE                                (PCS_CH3_CTC_MODE                                  ),//1SKIP, 2SKIP, PCIE_2BYTE, 4SKIP
    .PCS_A_REG                                   (PCS_CH3_A_REG                                     ),//0 to 255
    .PCS_GE_AUTO_EN                              (PCS_CH3_GE_AUTO_EN                                ),//TRUE, FALSE;
    .PCS_SKIP_REG0                               (PCS_CH3_SKIP_REG0                                 ),//0 to 1023
    .PCS_SKIP_REG1                               (PCS_CH3_SKIP_REG1                                 ),//0 to 1023
    .PCS_SKIP_REG2                               (PCS_CH3_SKIP_REG2                                 ),//0 to 1023
    .PCS_SKIP_REG3                               (PCS_CH3_SKIP_REG3                                 ),//0 to 1023
    .PCS_DEC_DUAL                                (PCS_CH3_DEC_DUAL                                  ),//TRUE, FALSE;
    .PCS_SPLIT                                   (PCS_CH3_SPLIT                                     ),//TRUE, FALSE;
    .PCS_FIFOFLAG_CTC                            (PCS_CH3_FIFOFLAG_CTC                              ),//TRUE, FALSE;
    .PCS_COMMA_DET_MODE                          (PCS_CH3_COMMA_DET_MODE                            ),//"RX_CLK_SLIP" "COMMA_PATTERN"
    .PCS_ERRDETECT_SILENCE                       (PCS_CH3_ERRDETECT_SILENCE                         ),//TRUE, FALSE;
    .PCS_PMA_RCLK_POLINV                         (PCS_CH3_PMA_RCLK_POLINV                           ),//"PMA_RCLK" "REVERSE_OF_PMA_RCLK"
    .PCS_PCS_RCLK_SEL                            (PCS_CH3_PCS_RCLK_SEL                              ),//"PMA_RCLK" "PMA_TCLK" "RCLK"
    .PCS_CB_RCLK_SEL                             (PCS_CH3_CB_RCLK_SEL                               ),//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK"
    .PCS_AFTER_CTC_RCLK_SEL                      (PCS_CH3_AFTER_CTC_RCLK_SEL                        ),//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK" "RCLK2"
    .PCS_RCLK_POLINV                             (PCS_CH3_RCLK_POLINV                               ),//"RCLK" "REVERSE_OF_RCLK"
    .PCS_BRIDGE_RCLK_SEL                         (PCS_CH3_BRIDGE_RCLK_SEL                           ),//"PMA_RCLK" "PMA_TCLK" "MCB_RCLK" "RCLK"
    .PCS_PCS_RCLK_EN                             (PCS_CH3_PCS_RCLK_EN                               ),//TRUE, FALSE;
    .PCS_CB_RCLK_EN                              (PCS_CH3_CB_RCLK_EN                                ),//TRUE, FALSE;
    .PCS_AFTER_CTC_RCLK_EN                       (PCS_CH3_AFTER_CTC_RCLK_EN                         ),//TRUE, FALSE;
    .PCS_AFTER_CTC_RCLK_EN_GB                    (PCS_CH3_AFTER_CTC_RCLK_EN_GB                      ),//TRUE, FALSE;
    .PCS_PCS_RX_RSTN                             (PCS_CH3_PCS_RX_RSTN                               ),//TRUE, FALSE; for PCS Receiver Reset
    .PCS_PCIE_SLAVE                              (PCS_CH3_PCIE_SLAVE                                ),//"MASTER","SLAVE"
    .PCS_RX_64B66B_67B                           (PCS_CH3_RX_64B66B_67B                             ),//"NORMAL" "64B_66B" "64B_67B"
    .PCS_RX_BRIDGE_CLK_POLINV                    (PCS_CH3_RX_BRIDGE_CLK_POLINV                      ),//"RX_BRIDGE_CLK" "REVERSE_OF_RX_BRIDGE_CLK"
    .PCS_PCS_CB_RSTN                             (PCS_CH3_PCS_CB_RSTN                               ),//TRUE, FALSE; for PCS CB Reset
    .PCS_TX_BRIDGE_GEAR_SEL                      (PCS_CH3_TX_BRIDGE_GEAR_SEL                        ),//TRUE: tx gear priority, FALSE:tx bridge unit priority
    .PCS_TX_BYPASS_BRIDGE_UINT                   (PCS_CH3_TX_BYPASS_BRIDGE_UINT                     ),//TRUE, FALSE; for bypass 
    .PCS_TX_BYPASS_BRIDGE_FIFO                   (PCS_CH3_TX_BYPASS_BRIDGE_FIFO                     ),//TRUE, FALSE; for bypass Tx Bridge FIFO
    .PCS_TX_BYPASS_GEAR                          (PCS_CH3_TX_BYPASS_GEAR                            ),//TRUE, FALSE;
    .PCS_TX_BYPASS_ENC                           (PCS_CH3_TX_BYPASS_ENC                             ),//TRUE, FALSE;
    .PCS_TX_BYPASS_BIT_SLIP                      (PCS_CH3_TX_BYPASS_BIT_SLIP                        ),//TRUE, FALSE;
    .PCS_TX_GEAR_SPLIT                           (PCS_CH3_TX_GEAR_SPLIT                             ),//TRUE, FALSE;
    .PCS_TX_DRIVE_REG_MODE                       (PCS_CH3_TX_DRIVE_REG_MODE                         ),//"NO_CHANGE" "EN_POLARIY_REV" "EN_BIT_REV" "EN_BOTH"
    .PCS_TX_BIT_SLIP_CYCLES                      (PCS_CH3_TX_BIT_SLIP_CYCLES                        ),//o to 31
    .PCS_INT_TX_MASK_0                           (PCS_CH3_INT_TX_MASK_0                             ),//TRUE, FALSE;
    .PCS_INT_TX_MASK_1                           (PCS_CH3_INT_TX_MASK_1                             ),//TRUE, FALSE;
    .PCS_INT_TX_MASK_2                           (PCS_CH3_INT_TX_MASK_2                             ),//TRUE, FALSE;
    .PCS_INT_TX_CLR_0                            (PCS_CH3_INT_TX_CLR_0                              ),//TRUE, FALSE;
    .PCS_INT_TX_CLR_1                            (PCS_CH3_INT_TX_CLR_1                              ),//TRUE, FALSE;
    .PCS_INT_TX_CLR_2                            (PCS_CH3_INT_TX_CLR_2                              ),//TRUE, FALSE;
    .PCS_TX_PMA_TCLK_POLINV                      (PCS_CH3_TX_PMA_TCLK_POLINV                        ),//"PMA_TCLK" "REVERSE_OF_PMA_TCLK"
    .PCS_TX_PCS_CLK_EN_SEL                       (PCS_CH3_TX_PCS_CLK_EN_SEL                         ),//TRUE, FALSE;
    .PCS_TX_BRIDGE_TCLK_SEL                      (PCS_CH3_TX_BRIDGE_TCLK_SEL                        ),//"PCS_TCLK" "TCLK"
    .PCS_TX_TCLK_POLINV                          (PCS_CH3_TX_TCLK_POLINV                            ),//"TCLK" "REVERSE_OF_TCLK"
    .PCS_PCS_TCLK_SEL                            (PCS_CH3_PCS_TCLK_SEL                              ),//"PMA_TCLK" "TCLK"
    .PCS_TX_PCS_TX_RSTN                          (PCS_CH3_TX_PCS_TX_RSTN                            ),//TRUE, FALSE; for PCS Transmitter Reset
    .PCS_TX_SLAVE                                (PCS_CH3_TX_SLAVE                                  ),//"MASTER" "SLAVE"
    .PCS_TX_GEAR_CLK_EN_SEL                      (PCS_CH3_TX_GEAR_CLK_EN_SEL                        ),//TRUE, FALSE;
    .PCS_DATA_WIDTH_MODE                         (PCS_CH3_DATA_WIDTH_MODE                           ),//"X8" "X10" "X16" "X20"
    .PCS_TX_64B66B_67B                           (PCS_CH3_TX_64B66B_67B                             ),//"NORMAL" "64B_66B" "64B_67B"
    .PCS_GEAR_TCLK_SEL                           (PCS_CH3_GEAR_TCLK_SEL                             ),//"PMA_TCLK" "TCLK2"
    .PCS_TX_TCLK2FABRIC_SEL                      (PCS_CH3_TX_TCLK2FABRIC_SEL                        ),//TRUE, FALSE
    .PCS_TX_OUTZZ                                (PCS_CH3_TX_OUTZZ                                  ),//TRUE, FALSE
    .PCS_ENC_DUAL                                (PCS_CH3_ENC_DUAL                                  ),//TRUE, FALSE
    .PCS_TX_BITSLIP_DATA_MODE                    (PCS_CH3_TX_BITSLIP_DATA_MODE                      ),//"X10" "X20"
    .PCS_TX_BRIDGE_CLK_POLINV                    (PCS_CH3_TX_BRIDGE_CLK_POLINV                      ),//"TX_BRIDGE_CLK" "REVERSE_OF_TX_BRIDGE_CLK"
    .PCS_COMMA_REG1                              (PCS_CH3_COMMA_REG1                                ),//0 to 1023
    .PCS_RAPID_IMAX                              (PCS_CH3_RAPID_IMAX                                ),//0 to 7
    .PCS_RAPID_VMIN_1                            (PCS_CH3_RAPID_VMIN_1                              ),//0 to 255
    .PCS_RAPID_VMIN_2                            (PCS_CH3_RAPID_VMIN_2                              ),//0 to 255
    .PCS_RX_PRBS_MODE                            (PCS_CH3_RX_PRBS_MODE                              ),//DISABLE PRBS_7 PRBS_15 PRBS_23 PRBS_31
    .PCS_RX_ERRCNT_CLR                           (PCS_CH3_RX_ERRCNT_CLR                             ),//TRUE, FALSE
    .PCS_PRBS_ERR_LPBK                           (PCS_CH3_PRBS_ERR_LPBK                             ),//TRUE, FALSE
    .PCS_TX_PRBS_MODE                            (PCS_CH3_TX_PRBS_MODE                              ),//DISABLE PRBS_7 PRBS_15 PRBS_23 PRBS_31 LONG_1 LONG_0 20UI D10_2 PCIE
    .PCS_TX_INSERT_ER                            (PCS_CH3_TX_INSERT_ER                              ),//TRUE, FALSE
    .PCS_ENABLE_PRBS_GEN                         (PCS_CH3_ENABLE_PRBS_GEN                           ),//TRUE, FALSE
    .PCS_DEFAULT_RADDR                           (PCS_CH3_DEFAULT_RADDR                             ),//0 to 15
    .PCS_MASTER_CHECK_OFFSET                     (PCS_CH3_MASTER_CHECK_OFFSET                       ),//0 to 15
    .PCS_DELAY_SET                               (PCS_CH3_DELAY_SET                                 ),//0 to 15
    .PCS_SEACH_OFFSET                            (PCS_CH3_SEACH_OFFSET                              ),//"20BIT" 30BIT" "40BIT" "50BIT" "60BIT" "70BIT" "80BIT"
    .PCS_CEB_RAPIDLS_MMAX                        (PCS_CH3_CEB_RAPIDLS_MMAX                          ),//0 to 7
    .PCS_CTC_AFULL                               (PCS_CH3_CTC_AFULL                                 ),//0 to 31
    .PCS_CTC_AEMPTY                              (PCS_CH3_CTC_AEMPTY                                ),//0 to 31
    .PCS_CTC_CONTI_SKP_SET                       (PCS_CH3_CTC_CONTI_SKP_SET                         ),//0 to 1
    .PCS_FAR_LOOP                                (PCS_CH3_FAR_LOOP                                  ),//TRUE, FALSE
    .PCS_NEAR_LOOP                               (PCS_CH3_NEAR_LOOP                                 ),//TRUE, FALSE
    .PCS_PMA_TX2RX_PLOOP_EN                      (PCS_CH3_PMA_TX2RX_PLOOP_EN                        ),//TRUE, FALSE
    .PCS_PMA_TX2RX_SLOOP_EN                      (PCS_CH3_PMA_TX2RX_SLOOP_EN                        ),//TRUE, FALSE
    .PCS_PMA_RX2TX_PLOOP_EN                      (PCS_CH3_PMA_RX2TX_PLOOP_EN                        ),//TRUE, FALSE
    .PCS_INT_RX_MASK_0                           (PCS_CH3_INT_RX_MASK_0                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_1                           (PCS_CH3_INT_RX_MASK_1                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_2                           (PCS_CH3_INT_RX_MASK_2                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_3                           (PCS_CH3_INT_RX_MASK_3                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_4                           (PCS_CH3_INT_RX_MASK_4                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_5                           (PCS_CH3_INT_RX_MASK_5                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_6                           (PCS_CH3_INT_RX_MASK_6                             ),//TRUE, FALSE
    .PCS_INT_RX_MASK_7                           (PCS_CH3_INT_RX_MASK_7                             ),//TRUE, FALSE
    .PCS_INT_RX_CLR_0                            (PCS_CH3_INT_RX_CLR_0                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_1                            (PCS_CH3_INT_RX_CLR_1                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_2                            (PCS_CH3_INT_RX_CLR_2                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_3                            (PCS_CH3_INT_RX_CLR_3                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_4                            (PCS_CH3_INT_RX_CLR_4                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_5                            (PCS_CH3_INT_RX_CLR_5                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_6                            (PCS_CH3_INT_RX_CLR_6                              ),//TRUE, FALSE
    .PCS_INT_RX_CLR_7                            (PCS_CH3_INT_RX_CLR_7                              ),//TRUE, FALSE
    .PCS_CA_RSTN_RX                              (PCS_CH3_CA_RSTN_RX                                ),//TRUE, FALSE; for Rx CLK Aligner Reset
    .PCS_CA_DYN_DLY_EN_RX                        (PCS_CH3_CA_DYN_DLY_EN_RX                          ),//TRUE, FALSE
    .PCS_CA_DYN_DLY_SEL_RX                       (PCS_CH3_CA_DYN_DLY_SEL_RX                         ),//TRUE, FALSE
    .PCS_CA_RX                                   (PCS_CH3_CA_RX                                     ),//0 to 255
    .PCS_CA_RSTN_TX                              (PCS_CH3_CA_RSTN_TX                                ),//TRUE, FALSE
    .PCS_CA_DYN_DLY_EN_TX                        (PCS_CH3_CA_DYN_DLY_EN_TX                          ),//TRUE, FALSE
    .PCS_CA_DYN_DLY_SEL_TX                       (PCS_CH3_CA_DYN_DLY_SEL_TX                         ),//TRUE, FALSE
    .PCS_CA_TX                                   (PCS_CH3_CA_TX                                     ),//0 to 255
    .PCS_RXPRBS_PWR_REDUCTION                    (PCS_CH3_RXPRBS_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_WDALIGN_PWR_REDUCTION                   (PCS_CH3_WDALIGN_PWR_REDUCTION                     ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXDEC_PWR_REDUCTION                     (PCS_CH3_RXDEC_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXCB_PWR_REDUCTION                      (PCS_CH3_RXCB_PWR_REDUCTION                        ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXCTC_PWR_REDUCTION                     (PCS_CH3_RXCTC_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXGEAR_PWR_REDUCTION                    (PCS_CH3_RXGEAR_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXBRG_PWR_REDUCTION                     (PCS_CH3_RXBRG_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_RXTEST_PWR_REDUCTION                    (PCS_CH3_RXTEST_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXBRG_PWR_REDUCTION                     (PCS_CH3_TXBRG_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXGEAR_PWR_REDUCTION                    (PCS_CH3_TXGEAR_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXENC_PWR_REDUCTION                     (PCS_CH3_TXENC_PWR_REDUCTION                       ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXBSLP_PWR_REDUCTION                    (PCS_CH3_TXBSLP_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    .PCS_TXPRBS_PWR_REDUCTION                    (PCS_CH3_TXPRBS_PWR_REDUCTION                      ),//"NORMAL" "POWER_REDUCTION"
    //pma_rx                                                                                      
    .PMA_REG_RX_PD                               (PMA_CH3_REG_RX_PD                                 ),//ON, OFF;
    .PMA_REG_RX_PD_EN                            (PMA_CH3_REG_RX_PD_EN                              ),//TRUE, FALSE
    .PMA_REG_RX_RESERVED_2                       (PMA_CH3_REG_RX_RESERVED_2                         ),//TRUE, FALSE
    .PMA_REG_RX_RESERVED_3                       (PMA_CH3_REG_RX_RESERVED_3                         ),//TRUE, FALSE
    .PMA_REG_RX_DATAPATH_PD                      (PMA_CH3_REG_RX_DATAPATH_PD                        ),//ON, OFF;
    .PMA_REG_RX_DATAPATH_PD_EN                   (PMA_CH3_REG_RX_DATAPATH_PD_EN                     ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_PD                        (PMA_CH3_REG_RX_SIGDET_PD                          ),//ON, OFF;
    .PMA_REG_RX_SIGDET_PD_EN                     (PMA_CH3_REG_RX_SIGDET_PD_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_DCC_RST_N                        (PMA_CH3_REG_RX_DCC_RST_N                          ),//TRUE, FALSE;
    .PMA_REG_RX_DCC_RST_N_EN                     (PMA_CH3_REG_RX_DCC_RST_N_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_CDR_RST_N                        (PMA_CH3_REG_RX_CDR_RST_N                          ),//TRUE, FALSE;
    .PMA_REG_RX_CDR_RST_N_EN                     (PMA_CH3_REG_RX_CDR_RST_N_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_RST_N                     (PMA_CH3_REG_RX_SIGDET_RST_N                       ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_RST_N_EN                  (PMA_CH3_REG_RX_SIGDET_RST_N_EN                    ),//TRUE, FALSE;
    .PMA_REG_RXPCLK_SLIP                         (PMA_CH3_REG_RXPCLK_SLIP                           ),//TRUE, FALSE;
    .PMA_REG_RXPCLK_SLIP_OW                      (PMA_CH3_REG_RXPCLK_SLIP_OW                        ),//TRUE, FALSE;
    .PMA_REG_RX_PCLKSWITCH_RST_N                 (PMA_CH3_REG_RX_PCLKSWITCH_RST_N                   ),//TRUE, FALSE; for TX PMA Reset
    .PMA_REG_RX_PCLKSWITCH_RST_N_EN              (PMA_CH3_REG_RX_PCLKSWITCH_RST_N_EN                ),//TRUE, FALSE;
    .PMA_REG_RX_PCLKSWITCH                       (PMA_CH3_REG_RX_PCLKSWITCH                         ),//TRUE, FALSE;
    .PMA_REG_RX_PCLKSWITCH_EN                    (PMA_CH3_REG_RX_PCLKSWITCH_EN                      ),//TRUE, FALSE;
    .PMA_REG_RX_HIGHZ                            (PMA_CH3_REG_RX_HIGHZ                              ),//TRUE, FALSE;
    .PMA_REG_RX_HIGHZ_EN                         (PMA_CH3_REG_RX_HIGHZ_EN                           ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_CLK_WINDOW                (PMA_CH3_REG_RX_SIGDET_CLK_WINDOW                  ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_CLK_WINDOW_OW             (PMA_CH3_REG_RX_SIGDET_CLK_WINDOW_OW               ),//TRUE, FALSE;
    .PMA_REG_RX_PD_BIAS_RX                       (PMA_CH3_REG_RX_PD_BIAS_RX                         ),//TRUE, FALSE;
    .PMA_REG_RX_PD_BIAS_RX_OW                    (PMA_CH3_REG_RX_PD_BIAS_RX_OW                      ),//TRUE, FALSE;
    .PMA_REG_RX_RESET_N                          (PMA_CH3_REG_RX_RESET_N                            ),//TRUE, FALSE;
    .PMA_REG_RX_RESET_N_OW                       (PMA_CH3_REG_RX_RESET_N_OW                         ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_29_28                   (PMA_CH3_REG_RX_RESERVED_29_28                     ),//0 to 3
    .PMA_REG_RX_BUSWIDTH                         (PMA_CH3_REG_RX_BUSWIDTH                           ),//"8BIT" "10BIT" "16BIT" "20BIT"
    .PMA_REG_RX_BUSWIDTH_EN                      (PMA_CH3_REG_RX_BUSWIDTH_EN                        ),//TRUE, FALSE;
    .PMA_REG_RX_RATE                             (PMA_CH3_REG_RX_RATE                               ),//"DIV4" "DIV2" "DIV1" "MUL2"
    .PMA_REG_RX_RESERVED_36                      (PMA_CH3_REG_RX_RESERVED_36                        ),//TRUE, FALSE;
    .PMA_REG_RX_RATE_EN                          (PMA_CH3_REG_RX_RATE_EN                            ),//TRUE, FALSE;
    .PMA_REG_RX_RES_TRIM                         (PMA_CH3_REG_RX_RES_TRIM                           ),//0 to 63
    .PMA_REG_RX_RESERVED_44                      (PMA_CH3_REG_RX_RESERVED_44                        ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_45                      (PMA_CH3_REG_RX_RESERVED_45                        ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_STATUS_EN                 (PMA_CH3_REG_RX_SIGDET_STATUS_EN                   ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_48_47                   (PMA_CH3_REG_RX_RESERVED_48_47                     ),//0 to 3
    .PMA_REG_RX_ICTRL_SIGDET                     (PMA_CH3_REG_RX_ICTRL_SIGDET                       ),//0 to 15
    .PMA_REG_CDR_READY_THD                       (PMA_CH3_REG_CDR_READY_THD                         ),//0 to 4095
    .PMA_REG_RX_RESERVED_65                      (PMA_CH3_REG_RX_RESERVED_65                        ),//TRUE, FALSE;
    .PMA_REG_RX_PCLK_EDGE_SEL                    (PMA_CH3_REG_RX_PCLK_EDGE_SEL                      ),//"POS_EDGE" "NEG_EDGE"
    .PMA_REG_RX_PIBUF_IC                         (PMA_CH3_REG_RX_PIBUF_IC                           ),//0 to 3
    .PMA_REG_RX_RESERVED_69                      (PMA_CH3_REG_RX_RESERVED_69                        ),//TRUE, FALSE; 
    .PMA_REG_RX_DCC_IC_RX                        (PMA_CH3_REG_RX_DCC_IC_RX                          ),//0 to 3
    .PMA_REG_CDR_READY_CHECK_CTRL                (PMA_CH3_REG_CDR_READY_CHECK_CTRL                  ),//0 to 3
    .PMA_REG_RX_ICTRL_TRX                        (PMA_CH3_REG_RX_ICTRL_TRX                          ),//"87_5PCT" "100PCT" "112_5PCT" "125PCT"
    .PMA_REG_RX_RESERVED_77_76                   (PMA_CH3_REG_RX_RESERVED_77_76                     ),//0 to 3
    .PMA_REG_RX_RESERVED_79_78                   (PMA_CH3_REG_RX_RESERVED_79_78                     ),//0 to 3
    .PMA_REG_RX_RESERVED_81_80                   (PMA_CH3_REG_RX_RESERVED_81_80                     ),//0 to 3
    .PMA_REG_RX_ICTRL_PIBUF                      (PMA_CH3_REG_RX_ICTRL_PIBUF                        ),//"87_5PCT" "100PCT" "112_5PCT" "125PCT"
    .PMA_REG_RX_ICTRL_PI                         (PMA_CH3_REG_RX_ICTRL_PI                           ),//"87_5PCT" "100PCT" "112_5PCT" "125PCT"
    .PMA_REG_RX_ICTRL_DCC                        (PMA_CH3_REG_RX_ICTRL_DCC                          ),//"87_5PCT" "100PCT" "112_5PCT" "125PCT"
    .PMA_REG_RX_RESERVED_89_88                   (PMA_CH3_REG_RX_RESERVED_89_88                     ),//0 to 3
    .PMA_REG_TX_RATE                             (PMA_CH3_REG_TX_RATE                               ),//"DIV4" "DIV2" "DIV1" "MUL2"
    .PMA_REG_RX_RESERVED_92                      (PMA_CH3_REG_RX_RESERVED_92                        ),//TRUE, FALSE; 
    .PMA_REG_TX_RATE_EN                          (PMA_CH3_REG_TX_RATE_EN                            ),//TRUE, FALSE; 
    .PMA_REG_RX_TX2RX_PLPBK_RST_N                (PMA_CH3_REG_RX_TX2RX_PLPBK_RST_N                  ),//TRUE, FALSE; for tx2rx pma parallel loop back Reset
    .PMA_REG_RX_TX2RX_PLPBK_RST_N_EN             (PMA_CH3_REG_RX_TX2RX_PLPBK_RST_N_EN               ),//TRUE, FALSE; 
    .PMA_REG_RX_TX2RX_PLPBK_EN                   (PMA_CH3_REG_RX_TX2RX_PLPBK_EN                     ),//TRUE, FALSE; for tx2rx pma parallel loop back enable
    .PMA_REG_TXCLK_SEL                           (PMA_CH3_REG_TXCLK_SEL                             ),//"PLL" "RXCLK"
    .PMA_REG_RX_DATA_POLARITY                    (PMA_CH3_REG_RX_DATA_POLARITY                      ),//"NORMAL" "REVERSE"
    .PMA_REG_RX_ERR_INSERT                       (PMA_CH3_REG_RX_ERR_INSERT                         ),//TRUE, FALSE;
    .PMA_REG_UDP_CHK_EN                          (PMA_CH3_REG_UDP_CHK_EN                            ),//TRUE, FALSE;
    .PMA_REG_PRBS_SEL                            (PMA_CH3_REG_PRBS_SEL                              ),//"PRBS7" "PRBS15" "PRBS23" "PRBS31"
    .PMA_REG_PRBS_CHK_EN                         (PMA_CH3_REG_PRBS_CHK_EN                           ),//TRUE, FALSE;
    .PMA_REG_PRBS_CHK_WIDTH_SEL                  (PMA_CH3_REG_PRBS_CHK_WIDTH_SEL                    ),//"8BIT" "10BIT" "16BIT" "20BIT"
    .PMA_REG_BIST_CHK_PAT_SEL                    (PMA_CH3_REG_BIST_CHK_PAT_SEL                      ),//"PRBS" "CONSTANT"
    .PMA_REG_LOAD_ERR_CNT                        (PMA_CH3_REG_LOAD_ERR_CNT                          ),//TRUE, FALSE;
    .PMA_REG_CHK_COUNTER_EN                      (PMA_CH3_REG_CHK_COUNTER_EN                        ),//TRUE, FALSE;
    .PMA_REG_CDR_PROP_GAIN                       (PMA_CH3_REG_CDR_PROP_GAIN                         ),//0 to 7
    .PMA_REG_CDR_PROP_TURBO_GAIN                 (PMA_CH3_REG_CDR_PROP_TURBO_GAIN                   ),//0 to 7
    .PMA_REG_CDR_INT_GAIN                        (PMA_CH3_REG_CDR_INT_GAIN                          ),//0 to 7
    .PMA_REG_CDR_INT_TURBO_GAIN                  (PMA_CH3_REG_CDR_INT_TURBO_GAIN                    ),//0 to 7
    .PMA_REG_CDR_INT_SAT_MAX                     (PMA_CH3_REG_CDR_INT_SAT_MAX                       ),//0 to 1023
    .PMA_REG_CDR_INT_SAT_MIN                     (PMA_CH3_REG_CDR_INT_SAT_MIN                       ),//0 to 1023
    .PMA_REG_CDR_INT_RST                         (PMA_CH3_REG_CDR_INT_RST                           ),//TRUE, FALSE;
    .PMA_REG_CDR_INT_RST_OW                      (PMA_CH3_REG_CDR_INT_RST_OW                        ),//TRUE, FALSE;
    .PMA_REG_CDR_PROP_RST                        (PMA_CH3_REG_CDR_PROP_RST                          ),//TRUE, FALSE;
    .PMA_REG_CDR_PROP_RST_OW                     (PMA_CH3_REG_CDR_PROP_RST_OW                       ),//TRUE, FALSE;
    .PMA_REG_CDR_LOCK_RST                        (PMA_CH3_REG_CDR_LOCK_RST                          ),//TRUE, FALSE; for CDR LOCK Counter Reset
    .PMA_REG_CDR_LOCK_RST_OW                     (PMA_CH3_REG_CDR_LOCK_RST_OW                       ),//TRUE, FALSE;
    .PMA_REG_CDR_RX_PI_FORCE_SEL                 (PMA_CH3_REG_CDR_RX_PI_FORCE_SEL                   ),//0,1
    .PMA_REG_CDR_RX_PI_FORCE_D                   (PMA_CH3_REG_CDR_RX_PI_FORCE_D                     ),//0 to 255
    .PMA_REG_CDR_LOCK_TIMER                      (PMA_CH3_REG_CDR_LOCK_TIMER                        ),//"0_8U" "1_2U" "1_6U" "2_4U" 3_2U" "4_8U" "12_8U" "25_6U"
    .PMA_REG_CDR_TURBO_MODE_TIMER                (PMA_CH3_REG_CDR_TURBO_MODE_TIMER                  ),//0 to 3
    .PMA_REG_CDR_LOCK_VAL                        (PMA_CH3_REG_CDR_LOCK_VAL                          ),//TRUE, FALSE;
    .PMA_REG_CDR_LOCK_OW                         (PMA_CH3_REG_CDR_LOCK_OW                           ),//TRUE, FALSE;
    .PMA_REG_CDR_INT_SAT_DET_EN                  (PMA_CH3_REG_CDR_INT_SAT_DET_EN                    ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_AUTO_DIS                    (PMA_CH3_REG_CDR_SAT_AUTO_DIS                      ),//TRUE, FALSE;
    .PMA_REG_CDR_GAIN_AUTO                       (PMA_CH3_REG_CDR_GAIN_AUTO                         ),//TRUE, FALSE;
    .PMA_REG_CDR_TURBO_GAIN_AUTO                 (PMA_CH3_REG_CDR_TURBO_GAIN_AUTO                   ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_171_167                 (PMA_CH3_REG_RX_RESERVED_171_167                   ),//0 to 31
    .PMA_REG_RX_RESERVED_175_172                 (PMA_CH3_REG_RX_RESERVED_175_172                   ),//0 to 31
    .PMA_REG_CDR_SAT_DET_STATUS_EN               (PMA_CH3_REG_CDR_SAT_DET_STATUS_EN                 ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_STATUS_RESET_EN         (PMA_CH3_REG_CDR_SAT_DET_STATUS_RESET_EN           ),//TRUE, FALSE;
    .PMA_REG_CDR_PI_CTRL_RST                     (PMA_CH3_REG_CDR_PI_CTRL_RST                       ),//TRUE, FALSE;
    .PMA_REG_CDR_PI_CTRL_RST_OW                  (PMA_CH3_REG_CDR_PI_CTRL_RST_OW                    ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_RST                     (PMA_CH3_REG_CDR_SAT_DET_RST                       ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_RST_OW                  (PMA_CH3_REG_CDR_SAT_DET_RST_OW                    ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_STICKY_RST              (PMA_CH3_REG_CDR_SAT_DET_STICKY_RST                ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_STICKY_RST_OW           (PMA_CH3_REG_CDR_SAT_DET_STICKY_RST_OW             ),//TRUE, FALSE;
    .PMA_REG_CDR_SIGDET_STATUS_DIS               (PMA_CH3_REG_CDR_SIGDET_STATUS_DIS                 ),//TRUE, FALSE; for sigdet_status is 0 to reset cdr
    .PMA_REG_CDR_SAT_DET_TIMER                   (PMA_CH3_REG_CDR_SAT_DET_TIMER                     ),//0 to 3
    .PMA_REG_CDR_SAT_DET_STATUS_VAL              (PMA_CH3_REG_CDR_SAT_DET_STATUS_VAL                ),//TRUE, FALSE;
    .PMA_REG_CDR_SAT_DET_STATUS_OW               (PMA_CH3_REG_CDR_SAT_DET_STATUS_OW                 ),//TRUE, FALSE;
    .PMA_REG_CDR_TURBO_MODE_EN                   (PMA_CH3_REG_CDR_TURBO_MODE_EN                     ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_190                     (PMA_CH3_REG_RX_RESERVED_190                       ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_193_191                 (PMA_CH3_REG_RX_RESERVED_193_191                   ),//0 to 7
    .PMA_REG_CDR_STATUS_FIFO_EN                  (PMA_CH3_REG_CDR_STATUS_FIFO_EN                    ),//TRUE, FALSE;
    .PMA_REG_PMA_TEST_SEL                        (PMA_CH3_REG_PMA_TEST_SEL                          ),//0,1
    .PMA_REG_OOB_COMWAKE_GAP_MIN                 (PMA_CH3_REG_OOB_COMWAKE_GAP_MIN                   ),//0 to 63
    .PMA_REG_OOB_COMWAKE_GAP_MAX                 (PMA_CH3_REG_OOB_COMWAKE_GAP_MAX                   ),//0 to 63
    .PMA_REG_OOB_COMINIT_GAP_MIN                 (PMA_CH3_REG_OOB_COMINIT_GAP_MIN                   ),//0 to 255
    .PMA_REG_OOB_COMINIT_GAP_MAX                 (PMA_CH3_REG_OOB_COMINIT_GAP_MAX                   ),//0 to 255
    .PMA_REG_RX_RESERVED_227_226                 (PMA_CH3_REG_RX_RESERVED_227_226                   ),//0 to 3
    .PMA_REG_COMWAKE_STATUS_CLEAR                (PMA_CH3_REG_COMWAKE_STATUS_CLEAR                  ),//0,1
    .PMA_REG_COMINIT_STATUS_CLEAR                (PMA_CH3_REG_COMINIT_STATUS_CLEAR                  ),//0,1
    .PMA_REG_RX_SYNC_RST_N_EN                    (PMA_CH3_REG_RX_SYNC_RST_N_EN                      ),//TRUE, FALSE;
    .PMA_REG_RX_SYNC_RST_N                       (PMA_CH3_REG_RX_SYNC_RST_N                         ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_233_232                 (PMA_CH3_REG_RX_RESERVED_233_232                   ),//0 to 3
    .PMA_REG_RX_RESERVED_235_234                 (PMA_CH3_REG_RX_RESERVED_235_234                   ),//0 to 3
    .PMA_REG_RX_SATA_COMINIT_OW                  (PMA_CH3_REG_RX_SATA_COMINIT_OW                    ),//TRUE, FALSE;
    .PMA_REG_RX_SATA_COMINIT                     (PMA_CH3_REG_RX_SATA_COMINIT                       ),//TRUE, FALSE;
    .PMA_REG_RX_SATA_COMWAKE_OW                  (PMA_CH3_REG_RX_SATA_COMWAKE_OW                    ),//TRUE, FALSE;
    .PMA_REG_RX_SATA_COMWAKE                     (PMA_CH3_REG_RX_SATA_COMWAKE                       ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_241_240                 (PMA_CH3_REG_RX_RESERVED_241_240                   ),//0 to 3
    .PMA_REG_RX_DCC_DISABLE                      (PMA_CH3_REG_RX_DCC_DISABLE                        ),//TRUE, FALSE; for rx dcc disable control
    .PMA_REG_RX_RESERVED_243                     (PMA_CH3_REG_RX_RESERVED_243                       ),//TRUE, FALSE;
    .PMA_REG_RX_SLIP_SEL_EN                      (PMA_CH3_REG_RX_SLIP_SEL_EN                        ),//TRUE, FALSE;
    .PMA_REG_RX_SLIP_SEL                         (PMA_CH3_REG_RX_SLIP_SEL                           ),//0 to 15
    .PMA_REG_RX_SLIP_EN                          (PMA_CH3_REG_RX_SLIP_EN                            ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_STATUS_SEL                (PMA_CH3_REG_RX_SIGDET_STATUS_SEL                  ),//0 to 7
    .PMA_REG_RX_SIGDET_FSM_RST_N                 (PMA_CH3_REG_RX_SIGDET_FSM_RST_N                   ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_254                     (PMA_CH3_REG_RX_RESERVED_254                       ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_STATUS                    (PMA_CH3_REG_RX_SIGDET_STATUS                      ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_VTH                       (PMA_CH3_REG_RX_SIGDET_VTH                         ),//"45MV" "54MV" "63MV" "72MV"
    .PMA_REG_RX_SIGDET_GRM                       (PMA_CH3_REG_RX_SIGDET_GRM                         ),//0,1,2,3
    .PMA_REG_RX_SIGDET_PULSE_EXT                 (PMA_CH3_REG_RX_SIGDET_PULSE_EXT                   ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_CH2_SEL                   (PMA_CH3_REG_RX_SIGDET_CH2_SEL                     ),//0,1
    .PMA_REG_RX_SIGDET_CH2_CHK_WINDOW            (PMA_CH3_REG_RX_SIGDET_CH2_CHK_WINDOW              ),//0 to 31
    .PMA_REG_RX_SIGDET_CHK_WINDOW_EN             (PMA_CH3_REG_RX_SIGDET_CHK_WINDOW_EN               ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_NOSIG_COUNT_SETTING       (PMA_CH3_REG_RX_SIGDET_NOSIG_COUNT_SETTING         ),//0 to 7
    .PMA_REG_SLIP_FIFO_INV_EN                    (PMA_CH3_REG_SLIP_FIFO_INV_EN                      ),//TRUE, FALSE;
    .PMA_REG_SLIP_FIFO_INV                       (PMA_CH3_REG_SLIP_FIFO_INV                         ),//"POS_EDGE" "NEG_EDGE"
    .PMA_REG_RX_SIGDET_OOB_DET_COUNT_VAL         (PMA_CH3_REG_RX_SIGDET_OOB_DET_COUNT_VAL           ),//0 to 31
    .PMA_REG_RX_SIGDET_4OOB_DET_SEL              (PMA_CH3_REG_RX_SIGDET_4OOB_DET_SEL                ),//0 to 7
    .PMA_REG_RX_RESERVED_285_283                 (PMA_CH3_REG_RX_RESERVED_285_283                   ),//0 to 7
    .PMA_REG_RX_RESERVED_286                     (PMA_CH3_REG_RX_RESERVED_286                       ),//TRUE, FALSE;
    .PMA_REG_RX_SIGDET_IC_I                      (PMA_CH3_REG_RX_SIGDET_IC_I                        ),//0 to 15
    .PMA_REG_RX_OOB_DETECTOR_RESET_N_OW          (PMA_CH3_REG_RX_OOB_DETECTOR_RESET_N_OW            ),//TRUE, FALSE;
    .PMA_REG_RX_OOB_DETECTOR_RESET_N             (PMA_CH3_REG_RX_OOB_DETECTOR_RESET_N               ),//TRUE, FALSE;for rx oob detector Reset
    .PMA_REG_RX_OOB_DETECTOR_PD_OW               (PMA_CH3_REG_RX_OOB_DETECTOR_PD_OW                 ),//TRUE, FALSE;
    .PMA_REG_RX_OOB_DETECTOR_PD                  (PMA_CH3_REG_RX_OOB_DETECTOR_PD                    ),//TRUE, FALSE;for rx oob detector powerdown
    .PMA_REG_RX_LS_MODE_EN                       (PMA_CH3_REG_RX_LS_MODE_EN                         ),//TRUE, FALSE;for Enable Low-speed mode
    .PMA_REG_ANA_RX_EQ1_R_SET_FB_O_SEL           (PMA_CH3_REG_ANA_RX_EQ1_R_SET_FB_O_SEL             ),//TRUE, FALSE;
    .PMA_REG_ANA_RX_EQ2_R_SET_FB_O_SEL           (PMA_CH3_REG_ANA_RX_EQ2_R_SET_FB_O_SEL             ),//TRUE, FALSE;
    .PMA_REG_RX_EQ1_R_SET_TOP                    (PMA_CH3_REG_RX_EQ1_R_SET_TOP                      ),//0 to 3
    .PMA_REG_RX_EQ1_R_SET_FB                     (PMA_CH3_REG_RX_EQ1_R_SET_FB                       ),//0 to 15
    .PMA_REG_RX_EQ1_C_SET_FB                     (PMA_CH3_REG_RX_EQ1_C_SET_FB                       ),//0 to 15
    .PMA_REG_RX_EQ1_OFF                          (PMA_CH3_REG_RX_EQ1_OFF                            ),//TRUE, FALSE;
    .PMA_REG_RX_EQ2_R_SET_TOP                    (PMA_CH3_REG_RX_EQ2_R_SET_TOP                      ),//0 to 3
    .PMA_REG_RX_EQ2_R_SET_FB                     (PMA_CH3_REG_RX_EQ2_R_SET_FB                       ),//0 to 15
    .PMA_REG_RX_EQ2_C_SET_FB                     (PMA_CH3_REG_RX_EQ2_C_SET_FB                       ),//0 to 15
    .PMA_REG_RX_EQ2_OFF                          (PMA_CH3_REG_RX_EQ2_OFF                            ),//TRUE, FALSE;
    .PMA_REG_EQ_DAC                              (PMA_CH3_REG_EQ_DAC                                ),//0 to 63
    .PMA_REG_RX_ICTRL_EQ                         (PMA_CH3_REG_RX_ICTRL_EQ                           ),//TRUE, FALSE;
    .PMA_REG_EQ_DC_CALIB_EN                      (PMA_CH3_REG_EQ_DC_CALIB_EN                        ),//TRUE, FALSE;
    .PMA_REG_EQ_DC_CALIB_SEL                     (PMA_CH3_REG_EQ_DC_CALIB_SEL                       ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_337_330                 (PMA_CH3_REG_RX_RESERVED_337_330                   ),//0 to 255
    .PMA_REG_RX_RESERVED_345_338                 (PMA_CH3_REG_RX_RESERVED_345_338                   ),//0 to 255
    .PMA_REG_RX_RESERVED_353_346                 (PMA_CH3_REG_RX_RESERVED_353_346                   ),//0 to 255
    .PMA_REG_RX_RESERVED_361_354                 (PMA_CH3_REG_RX_RESERVED_361_354                   ),//0 to 255
    .PMA_CTLE_CTRL_REG_I                         (PMA_CH3_CTLE_CTRL_REG_I                           ),//0 to 15
    .PMA_CTLE_REG_FORCE_SEL_I                    (PMA_CH3_CTLE_REG_FORCE_SEL_I                      ),//TRUE, FALSE;for ctrl self-adaption adjust
    .PMA_CTLE_REG_HOLD_I                         (PMA_CH3_CTLE_REG_HOLD_I                           ),//TRUE, FALSE;
    .PMA_CTLE_REG_INIT_DAC_I                     (PMA_CH3_CTLE_REG_INIT_DAC_I                       ),//0 to 15
    .PMA_CTLE_REG_POLARITY_I                     (PMA_CH3_CTLE_REG_POLARITY_I                       ),//TRUE, FALSE;
    .PMA_CTLE_REG_SHIFTER_GAIN_I                 (PMA_CH3_CTLE_REG_SHIFTER_GAIN_I                   ),//0 to 7
    .PMA_CTLE_REG_THRESHOLD_I                    (PMA_CH3_CTLE_REG_THRESHOLD_I                      ),//0 to 4095
    .PMA_REG_RX_RES_TRIM_EN                      (PMA_CH3_REG_RX_RES_TRIM_EN                        ),//TRUE, FALSE;
    .PMA_REG_RX_RESERVED_393_389                 (PMA_CH3_REG_RX_RESERVED_393_389                   ),//0 to 31
    .PMA_CFG_RX_LANE_POWERUP                     (PMA_CH3_CFG_RX_LANE_POWERUP                       ),//ON, OFF;for RX_LANE Power-up
    .PMA_CFG_RX_PMA_RSTN                         (PMA_CH3_CFG_RX_PMA_RSTN                           ),//TRUE, FALSE;for RX_PMA Reset
    .PMA_INT_PMA_RX_MASK_0                       (PMA_CH3_INT_PMA_RX_MASK_0                         ),//TRUE, FALSE;
    .PMA_INT_PMA_RX_CLR_0                        (PMA_CH3_INT_PMA_RX_CLR_0                          ),//TRUE, FALSE;
    .PMA_CFG_CTLE_ADP_RSTN                       (PMA_CH3_CFG_CTLE_ADP_RSTN                         ),//TRUE, FALSE;for ctrl Reset
    //pma_tx                                                                                      
    .PMA_REG_TX_PD                               (PMA_CH3_REG_TX_PD                                 ),//ON, OFF;for transmitter power down
    .PMA_REG_TX_PD_OW                            (PMA_CH3_REG_TX_PD_OW                              ),//TRUE, FALSE;
    .PMA_REG_TX_MAIN_PRE_Z                       (PMA_CH3_REG_TX_MAIN_PRE_Z                         ),//TRUE, FALSE;Enable EI for PCIE mode
    .PMA_REG_TX_MAIN_PRE_Z_OW                    (PMA_CH3_REG_TX_MAIN_PRE_Z_OW                      ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_TIMER_SEL                 (PMA_CH3_REG_TX_BEACON_TIMER_SEL                   ),//0 to 3
    .PMA_REG_TX_RXDET_REQ_OW                     (PMA_CH3_REG_TX_RXDET_REQ_OW                       ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_REQ                        (PMA_CH3_REG_TX_RXDET_REQ                          ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_EN_OW                     (PMA_CH3_REG_TX_BEACON_EN_OW                       ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_EN                        (PMA_CH3_REG_TX_BEACON_EN                          ),//TRUE, FALSE;
    .PMA_REG_TX_EI_EN_OW                         (PMA_CH3_REG_TX_EI_EN_OW                           ),//TRUE, FALSE;
    .PMA_REG_TX_EI_EN                            (PMA_CH3_REG_TX_EI_EN                              ),//TRUE, FALSE;
    .PMA_REG_TX_BIT_CONV                         (PMA_CH3_REG_TX_BIT_CONV                           ),//TRUE, FALSE;
    .PMA_REG_TX_RES_CAL                          (PMA_CH3_REG_TX_RES_CAL                            ),//0 to 63
    .PMA_REG_TX_RESERVED_19                      (PMA_CH3_REG_TX_RESERVED_19                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_25_20                   (PMA_CH3_REG_TX_RESERVED_25_20                     ),//0 to 63
    .PMA_REG_TX_RESERVED_33_26                   (PMA_CH3_REG_TX_RESERVED_33_26                     ),//0 to 255
    .PMA_REG_TX_RESERVED_41_34                   (PMA_CH3_REG_TX_RESERVED_41_34                     ),//0 to 255
    .PMA_REG_TX_RESERVED_49_42                   (PMA_CH3_REG_TX_RESERVED_49_42                     ),//0 to 255
    .PMA_REG_TX_RESERVED_57_50                   (PMA_CH3_REG_TX_RESERVED_57_50                     ),//0 to 255
    .PMA_REG_TX_SYNC_OW                          (PMA_CH3_REG_TX_SYNC_OW                            ),//TRUE, FALSE;
    .PMA_REG_TX_SYNC                             (PMA_CH3_REG_TX_SYNC                               ),//TRUE, FALSE;
    .PMA_REG_TX_PD_POST                          (PMA_CH3_REG_TX_PD_POST                            ),//ON, OFF;
    .PMA_REG_TX_PD_POST_OW                       (PMA_CH3_REG_TX_PD_POST_OW                         ),//TRUE, FALSE;
    .PMA_REG_TX_RESET_N_OW                       (PMA_CH3_REG_TX_RESET_N_OW                         ),//TRUE, FALSE;
    .PMA_REG_TX_RESET_N                          (PMA_CH3_REG_TX_RESET_N                            ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_64                      (PMA_CH3_REG_TX_RESERVED_64                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_65                      (PMA_CH3_REG_TX_RESERVED_65                        ),//TRUE, FALSE;
    .PMA_REG_TX_BUSWIDTH_OW                      (PMA_CH3_REG_TX_BUSWIDTH_OW                        ),//TRUE, FALSE;
    .PMA_REG_TX_BUSWIDTH                         (PMA_CH3_REG_TX_BUSWIDTH                           ),//"8BIT" "10BIT" "16BIT" "20BIT"
    .PMA_REG_PLL_READY_OW                        (PMA_CH3_REG_PLL_READY_OW                          ),//TRUE, FALSE;
    .PMA_REG_PLL_READY                           (PMA_CH3_REG_PLL_READY                             ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_72                      (PMA_CH3_REG_TX_RESERVED_72                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_73                      (PMA_CH3_REG_TX_RESERVED_73                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_74                      (PMA_CH3_REG_TX_RESERVED_74                        ),//TRUE, FALSE;
    .PMA_REG_EI_PCLK_DELAY_SEL                   (PMA_CH3_REG_EI_PCLK_DELAY_SEL                     ),//0 to 3
    .PMA_REG_TX_RESERVED_77                      (PMA_CH3_REG_TX_RESERVED_77                        ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_83_78                   (PMA_CH3_REG_TX_RESERVED_83_78                     ),//0 to 63
    .PMA_REG_TX_RESERVED_89_84                   (PMA_CH3_REG_TX_RESERVED_89_84                     ),//0 to 63
    .PMA_REG_TX_RESERVED_95_90                   (PMA_CH3_REG_TX_RESERVED_95_90                     ),//0 to 63
    .PMA_REG_TX_RESERVED_101_96                  (PMA_CH3_REG_TX_RESERVED_101_96                    ),//0 to 63
    .PMA_REG_TX_RESERVED_107_102                 (PMA_CH3_REG_TX_RESERVED_107_102                   ),//0 to 63
    .PMA_REG_TX_RESERVED_113_108                 (PMA_CH3_REG_TX_RESERVED_113_108                   ),//0 to 63
    .PMA_REG_TX_AMP_DAC0                         (PMA_CH3_REG_TX_AMP_DAC0                           ),//0 to 63
    .PMA_REG_TX_AMP_DAC1                         (PMA_CH3_REG_TX_AMP_DAC1                           ),//0 to 63
    .PMA_REG_TX_AMP_DAC2                         (PMA_CH3_REG_TX_AMP_DAC2                           ),//0 to 63
    .PMA_REG_TX_AMP_DAC3                         (PMA_CH3_REG_TX_AMP_DAC3                           ),//0 to 63
    .PMA_REG_TX_RESERVED_143_138                 (PMA_CH3_REG_TX_RESERVED_143_138                   ),//0 to 63
    .PMA_REG_TX_MARGIN                           (PMA_CH3_REG_TX_MARGIN                             ),//0 to 7
    .PMA_REG_TX_MARGIN_OW                        (PMA_CH3_REG_TX_MARGIN_OW                          ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_149_148                 (PMA_CH3_REG_TX_RESERVED_149_148                   ),//0 to 3
    .PMA_REG_TX_RESERVED_150                     (PMA_CH3_REG_TX_RESERVED_150                       ),//TRUE, FALSE;
    .PMA_REG_TX_SWING                            (PMA_CH3_REG_TX_SWING                              ),//TRUE, FALSE;
    .PMA_REG_TX_SWING_OW                         (PMA_CH3_REG_TX_SWING_OW                           ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_153                     (PMA_CH3_REG_TX_RESERVED_153                       ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_THRESHOLD                  (PMA_CH3_REG_TX_RXDET_THRESHOLD                    ),//"28MV" "56MV" "84MV" "112MV"
    .PMA_REG_TX_RESERVED_157_156                 (PMA_CH3_REG_TX_RESERVED_157_156                   ),//0 to 3
    .PMA_REG_TX_BEACON_OSC_CTRL                  (PMA_CH3_REG_TX_BEACON_OSC_CTRL                    ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_160_159                 (PMA_CH3_REG_TX_RESERVED_160_159                   ),//0 to 3
    .PMA_REG_TX_RESERVED_162_161                 (PMA_CH3_REG_TX_RESERVED_162_161                   ),//0 to 3
    .PMA_REG_TX_TX2RX_SLPBACK_EN                 (PMA_CH3_REG_TX_TX2RX_SLPBACK_EN                   ),//TRUE, FALSE;
    .PMA_REG_TX_PCLK_EDGE_SEL                    (PMA_CH3_REG_TX_PCLK_EDGE_SEL                      ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_STATUS_OW                  (PMA_CH3_REG_TX_RXDET_STATUS_OW                    ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_STATUS                     (PMA_CH3_REG_TX_RXDET_STATUS                       ),//TRUE, FALSE;
    .PMA_REG_TX_PRBS_GEN_EN                      (PMA_CH3_REG_TX_PRBS_GEN_EN                        ),//TRUE, FALSE;
    .PMA_REG_TX_PRBS_GEN_WIDTH_SEL               (PMA_CH3_REG_TX_PRBS_GEN_WIDTH_SEL                 ),//"8BIT" "10BIT" "16BIT" "20BIT"
    .PMA_REG_TX_PRBS_SEL                         (PMA_CH3_REG_TX_PRBS_SEL                           ),//"PRBS7" "PRBS15" "PRBS23" "PRBS31"
    .PMA_REG_TX_UDP_DATA_7_TO_0                  (PMA_CH3_REG_TX_UDP_DATA_7_TO_0                    ),//0 to 255
    .PMA_REG_TX_UDP_DATA_15_TO_8                 (PMA_CH3_REG_TX_UDP_DATA_15_TO_8                   ),//0 to 255
    .PMA_REG_TX_UDP_DATA_19_TO_16                (PMA_CH3_REG_TX_UDP_DATA_19_TO_16                  ),//0 to 15
    .PMA_REG_TX_RESERVED_192                     (PMA_CH3_REG_TX_RESERVED_192                       ),//TRUE, FALSE;
    .PMA_REG_TX_FIFO_WP_CTRL                     (PMA_CH3_REG_TX_FIFO_WP_CTRL                       ),//0 to 7
    .PMA_REG_TX_FIFO_EN                          (PMA_CH3_REG_TX_FIFO_EN                            ),//TRUE, FALSE;
    .PMA_REG_TX_DATA_MUX_SEL                     (PMA_CH3_REG_TX_DATA_MUX_SEL                       ),//0 to 3
    .PMA_REG_TX_ERR_INSERT                       (PMA_CH3_REG_TX_ERR_INSERT                         ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_203_200                 (PMA_CH3_REG_TX_RESERVED_203_200                   ),//0 to15
    .PMA_REG_TX_RESERVED_204                     (PMA_CH3_REG_TX_RESERVED_204                       ),//TRUE, FALSE;
    .PMA_REG_TX_SATA_EN                          (PMA_CH3_REG_TX_SATA_EN                            ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_207_206                 (PMA_CH3_REG_TX_RESERVED_207_206                   ),//0 to3
    .PMA_REG_RATE_CHANGE_TXPCLK_ON_OW            (PMA_CH3_REG_RATE_CHANGE_TXPCLK_ON_OW              ),//TRUE, FALSE;
    .PMA_REG_RATE_CHANGE_TXPCLK_ON               (PMA_CH3_REG_RATE_CHANGE_TXPCLK_ON                 ),//TRUE, FALSE;
    .PMA_REG_TX_CFG_POST1                        (PMA_CH3_REG_TX_CFG_POST1                          ),//0 to 31
    .PMA_REG_TX_CFG_POST2                        (PMA_CH3_REG_TX_CFG_POST2                          ),//0 to 31
    .PMA_REG_TX_DEEMP                            (PMA_CH3_REG_TX_DEEMP                              ),//0 to 3
    .PMA_REG_TX_DEEMP_OW                         (PMA_CH3_REG_TX_DEEMP_OW                           ),//TRUE, FALSE;for TX DEEMP Control
    .PMA_REG_TX_RESERVED_224_223                 (PMA_CH3_REG_TX_RESERVED_224_223                   ),//0 to 3
    .PMA_REG_TX_RESERVED_225                     (PMA_CH3_REG_TX_RESERVED_225                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_229_226                 (PMA_CH3_REG_TX_RESERVED_229_226                   ),//0 to 15
    .PMA_REG_TX_OOB_DELAY_SEL                    (PMA_CH3_REG_TX_OOB_DELAY_SEL                      ),//0 to 15
    .PMA_REG_TX_POLARITY                         (PMA_CH3_REG_TX_POLARITY                           ),//"NORMAL" "REVERSE"
    .PMA_REG_ANA_TX_JTAG_DATA_O_SEL              (PMA_CH3_REG_ANA_TX_JTAG_DATA_O_SEL                ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_236                     (PMA_CH3_REG_TX_RESERVED_236                       ),//TRUE, FALSE;
    .PMA_REG_TX_LS_MODE_EN                       (PMA_CH3_REG_TX_LS_MODE_EN                         ),//TRUE, FALSE;
    .PMA_REG_TX_JTAG_MODE_EN_OW                  (PMA_CH3_REG_TX_JTAG_MODE_EN_OW                    ),//TRUE, FALSE;
    .PMA_REG_TX_JTAG_MODE_EN                     (PMA_CH3_REG_TX_JTAG_MODE_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_JTAG_MODE_EN_OW                  (PMA_CH3_REG_RX_JTAG_MODE_EN_OW                    ),//TRUE, FALSE;
    .PMA_REG_RX_JTAG_MODE_EN                     (PMA_CH3_REG_RX_JTAG_MODE_EN                       ),//TRUE, FALSE;
    .PMA_REG_RX_JTAG_OE                          (PMA_CH3_REG_RX_JTAG_OE                            ),//TRUE, FALSE;
    .PMA_REG_RX_ACJTAG_VHYSTSEL                  (PMA_CH3_REG_RX_ACJTAG_VHYSTSEL                    ),//0 to 7
    .PMA_REG_TX_RES_CAL_EN                       (PMA_CH3_REG_TX_RES_CAL_EN                         ),//TRUE, FALSE;
    .PMA_REG_RX_TERM_MODE_CTRL                   (PMA_CH3_REG_RX_TERM_MODE_CTRL                     ),//0 to 7; for rx terminatin Control
    .PMA_REG_TX_RESERVED_251_250                 (PMA_CH3_REG_TX_RESERVED_251_250                   ),//0 to 7
    .PMA_REG_PLPBK_TXPCLK_EN                     (PMA_CH3_REG_PLPBK_TXPCLK_EN                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_253                     (PMA_CH3_REG_TX_RESERVED_253                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_254                     (PMA_CH3_REG_TX_RESERVED_254                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_255                     (PMA_CH3_REG_TX_RESERVED_255                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_256                     (PMA_CH3_REG_TX_RESERVED_256                       ),//TRUE, FALSE;
    .PMA_REG_TX_RESERVED_257                     (PMA_CH3_REG_TX_RESERVED_257                       ),//TRUE, FALSE;
    .PMA_REG_TX_PH_SEL                           (PMA_CH3_REG_TX_PH_SEL                             ),//0 to 63
    .PMA_REG_TX_CFG_PRE                          (PMA_CH3_REG_TX_CFG_PRE                            ),//0 to 31
    .PMA_REG_TX_CFG_MAIN                         (PMA_CH3_REG_TX_CFG_MAIN                           ),//0 to 63
    .PMA_REG_CFG_POST                            (PMA_CH3_REG_CFG_POST                              ),//0 to 31
    .PMA_REG_PD_MAIN                             (PMA_CH3_REG_PD_MAIN                               ),//TRUE, FALSE;
    .PMA_REG_PD_PRE                              (PMA_CH3_REG_PD_PRE                                ),//TRUE, FALSE;
    .PMA_REG_TX_LS_DATA                          (PMA_CH3_REG_TX_LS_DATA                            ),//TRUE, FALSE;
    .PMA_REG_TX_DCC_BUF_SZ_SEL                   (PMA_CH3_REG_TX_DCC_BUF_SZ_SEL                     ),//0 to 3
    .PMA_REG_TX_DCC_CAL_CUR_TUNE                 (PMA_CH3_REG_TX_DCC_CAL_CUR_TUNE                   ),//0 to 63
    .PMA_REG_TX_DCC_CAL_EN                       (PMA_CH3_REG_TX_DCC_CAL_EN                         ),//TRUE, FALSE;
    .PMA_REG_TX_DCC_CUR_SS                       (PMA_CH3_REG_TX_DCC_CUR_SS                         ),//0 to 3
    .PMA_REG_TX_DCC_FA_CTRL                      (PMA_CH3_REG_TX_DCC_FA_CTRL                        ),//TRUE, FALSE;
    .PMA_REG_TX_DCC_RI_CTRL                      (PMA_CH3_REG_TX_DCC_RI_CTRL                        ),//TRUE, FALSE;
    .PMA_REG_ATB_SEL_2_TO_0                      (PMA_CH3_REG_ATB_SEL_2_TO_0                        ),//0 to 7
    .PMA_REG_ATB_SEL_9_TO_3                      (PMA_CH3_REG_ATB_SEL_9_TO_3                        ),//0 to 127
    .PMA_REG_TX_CFG_7_TO_0                       (PMA_CH3_REG_TX_CFG_7_TO_0                         ),//0 to 255
    .PMA_REG_TX_CFG_15_TO_8                      (PMA_CH3_REG_TX_CFG_15_TO_8                        ),//0 to 255
    .PMA_REG_TX_CFG_23_TO_16                     (PMA_CH3_REG_TX_CFG_23_TO_16                       ),//0 to 255
    .PMA_REG_TX_CFG_31_TO_24                     (PMA_CH3_REG_TX_CFG_31_TO_24                       ),//0 to 255
    .PMA_REG_TX_OOB_EI_EN                        (PMA_CH3_REG_TX_OOB_EI_EN                          ),//TRUE, FALSE; Enable OOB EI for SATA mode
    .PMA_REG_TX_OOB_EI_EN_OW                     (PMA_CH3_REG_TX_OOB_EI_EN_OW                       ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_EN_DELAYED                (PMA_CH3_REG_TX_BEACON_EN_DELAYED                  ),//TRUE, FALSE;
    .PMA_REG_TX_BEACON_EN_DELAYED_OW             (PMA_CH3_REG_TX_BEACON_EN_DELAYED_OW               ),//TRUE, FALSE;
    .PMA_REG_TX_JTAG_DATA                        (PMA_CH3_REG_TX_JTAG_DATA                          ),//TRUE, FALSE;
    .PMA_REG_TX_RXDET_TIMER_SEL                  (PMA_CH3_REG_TX_RXDET_TIMER_SEL                    ),//0 to 255
    .PMA_REG_TX_CFG1_7_0                         (PMA_CH3_REG_TX_CFG1_7_0                           ),//0 to 255
    .PMA_REG_TX_CFG1_15_8                        (PMA_CH3_REG_TX_CFG1_15_8                          ),//0 to 255
    .PMA_REG_TX_CFG1_23_16                       (PMA_CH3_REG_TX_CFG1_23_16                         ),//0 to 255
    .PMA_REG_TX_CFG1_31_24                       (PMA_CH3_REG_TX_CFG1_31_24                         ),//0 to 255
    .PMA_REG_CFG_LANE_POWERUP                    (PMA_CH3_REG_CFG_LANE_POWERUP                      ),//ON, OFF; for PMA_LANE powerup
    .PMA_REG_CFG_TX_LANE_POWERUP_CLKPATH         (PMA_CH3_REG_CFG_TX_LANE_POWERUP_CLKPATH           ),//TRUE, FALSE; for Pma tx lane clkpath powerup
    .PMA_REG_CFG_TX_LANE_POWERUP_PISO            (PMA_CH3_REG_CFG_TX_LANE_POWERUP_PISO              ),//TRUE, FALSE; for Pma tx lane piso powerup
    .PMA_REG_CFG_TX_LANE_POWERUP_DRIVER          (PMA_CH3_REG_CFG_TX_LANE_POWERUP_DRIVER            ) //TRUE, FALSE; for Pma tx lane driver powerup
) U_GTP_HSSTLP_LANE3 (
    //PAD
    .P_TX_SDN                               (P_TX_SDN_3            ),//output              
    .P_TX_SDP                               (P_TX_SDP_3            ),//output              
    //SRB related                           
    .P_PCS_RX_MCB_STATUS                    (P_PCS_RX_MCB_STATUS_3 ),//output              
    .P_PCS_LSM_SYNCED                       (P_PCS_LSM_SYNCED_3    ),//output              
    .P_CFG_READY                            (P_CFG_READY_3         ),//output              
    .P_CFG_RDATA                            (P_CFG_RDATA_3         ),//output [7:0]        
    .P_CFG_INT                              (P_CFG_INT_3           ),//output              
    .P_RDATA                                (P_RDATA_3             ),//output [46:0]       
    .P_RCLK2FABRIC                          (P_RCLK2FABRIC_3       ),//output              
    .P_TCLK2FABRIC                          (P_TCLK2FABRIC_3       ),//output              
    .P_RX_SIGDET_STATUS                     (P_RX_SIGDET_STATUS_3  ),//output              
    .P_RX_SATA_COMINIT                      (P_RX_SATA_COMINIT_3   ),//output              
    .P_RX_SATA_COMWAKE                      (P_RX_SATA_COMWAKE_3   ),//output              
    .P_RX_LS_DATA                           (P_RX_LS_DATA_3        ),//output              
    .P_RX_READY                             (P_RX_READY_3          ),//output              
    .P_TEST_STATUS                          (P_TEST_STATUS_3       ),//output [19:0]       
    .P_TX_RXDET_STATUS                      (P_TX_RXDET_STATUS_3   ),//output              
    .P_CA_ALIGN_RX                          (P_CA_ALIGN_RX_3       ),//output              
    .P_CA_ALIGN_TX                          (P_CA_ALIGN_TX_3       ),//output              
    //out                                    
    .PMA_RCLK                               (PMA_RCLK_3            ),//output       	    
    .TXPCLK_PLL                             (TXPCLK_PLL_3          ),//output              
    //cin and cout                           
    .LANE_COUT_BUS_FORWARD                  (LANE_COUT_BUS_FORWARD_3),//output [18:0]       
    .APATTERN_STATUS_COUT                   (APATTERN_STATUS_COUT_3),//output              
    //PAD                                     
    .P_RX_SDN                               (P_RX_SDN_3            ),//input               
    .P_RX_SDP                               (P_RX_SDP_3            ),//input               
    //SRB related                            
    .P_RX_CLK_FR_CORE                       (P_RX_CLK_FR_CORE_3    ),//input               
    .P_RCLK2_FR_CORE                        (P_RCLK2_FR_CORE_3     ),//input               
    .P_TX_CLK_FR_CORE                       (P_TX_CLK_FR_CORE_3    ),//input               
    .P_TCLK2_FR_CORE                        (P_TCLK2_FR_CORE_3     ),//input               
    .P_PCS_TX_RST                           (P_PCS_TX_RST_3        ),//input               
    .P_PCS_RX_RST                           (P_PCS_RX_RST_3        ),//input               
    .P_PCS_CB_RST                           (P_PCS_CB_RST_3        ),//input               
    .P_RXGEAR_SLIP                          (P_RXGEAR_SLIP_3       ),//input               
    .P_CFG_CLK                              (P_CFG_CLK_3           ),//input               
    .P_CFG_RST                              (P_CFG_RST_3           ),//input               
    .P_CFG_PSEL                             (P_CFG_PSEL_3          ),//input               
    .P_CFG_ENABLE                           (P_CFG_ENABLE_3        ),//input               
    .P_CFG_WRITE                            (P_CFG_WRITE_3         ),//input               
    .P_CFG_ADDR                             (P_CFG_ADDR_3          ),//input [11:0]        
    .P_CFG_WDATA                            (P_CFG_WDATA_3         ),//input [7:0]         
    .P_TDATA                                (P_TDATA_3             ),//input [45:0]        
    .P_PCS_WORD_ALIGN_EN                    (P_PCS_WORD_ALIGN_EN_3 ),//input               
    .P_RX_POLARITY_INVERT                   (P_RX_POLARITY_INVERT_3),//input               
    .P_CEB_ADETECT_EN                       (P_CEB_ADETECT_EN_3    ),//input               
    .P_PCS_MCB_EXT_EN                       (P_PCS_MCB_EXT_EN_3    ),//input               
    .P_PCS_NEAREND_LOOP                     (P_PCS_NEAREND_LOOP_3  ),//input               
    .P_PCS_FAREND_LOOP                      (P_PCS_FAREND_LOOP_3   ),//input               
    .P_PMA_NEAREND_PLOOP                    (P_PMA_NEAREND_PLOOP_3 ),//input               
    .P_PMA_NEAREND_SLOOP                    (P_PMA_NEAREND_SLOOP_3 ),//input               
    .P_PMA_FAREND_PLOOP                     (P_PMA_FAREND_PLOOP_3  ),//input               
                                                                 
    .P_LANE_PD                              (P_LANE_PD_3           ),//input               
    .P_LANE_RST                             (P_LANE_RST_3          ),//input               
    .P_RX_LANE_PD                           (P_RX_LANE_PD_3        ),//input               
    .P_RX_PMA_RST                           (P_RX_PMA_RST_3        ),//input               
    .P_CTLE_ADP_RST                         (P_CTLE_ADP_RST_3      ),//input               
    .P_TX_DEEMP                             (P_TX_DEEMP_3          ),//input [1:0]         
    .P_TX_LS_DATA                           (P_TX_LS_DATA_3        ),//input               
    .P_TX_BEACON_EN                         (P_TX_BEACON_EN_3      ),//input               
    .P_TX_SWING                             (P_TX_SWING_3          ),//input               
    .P_TX_RXDET_REQ                         (P_TX_RXDET_REQ_3      ),//input               
    .P_TX_RATE                              (P_TX_RATE_3           ),//input [2:0]         
    .P_TX_BUSWIDTH                          (P_TX_BUSWIDTH_3       ),//input [2:0]         
    .P_TX_MARGIN                            (P_TX_MARGIN_3         ),//input [2:0]         
    .P_TX_PMA_RST                           (P_TX_PMA_RST_3        ),//input               
    .P_TX_LANE_PD_CLKPATH                   (P_TX_LANE_PD_CLKPATH_3),//input               
    .P_TX_LANE_PD_PISO                      (P_TX_LANE_PD_PISO_3   ),//input               
    .P_TX_LANE_PD_DRIVER                    (P_TX_LANE_PD_DRIVER_3 ),//input               
    .P_RX_RATE                              (P_RX_RATE_3           ),//input [2:0]         
    .P_RX_BUSWIDTH                          (P_RX_BUSWIDTH_3       ),//input [2:0]         
    .P_RX_HIGHZ                             (P_RX_HIGHZ_3          ),//input               
    .P_CIM_CLK_ALIGNER_RX                   (P_CIM_CLK_ALIGNER_RX_3),//input [7:0]         
    .P_CIM_CLK_ALIGNER_TX                   (P_CIM_CLK_ALIGNER_TX_3),//input [7:0]         
    .P_CIM_DYN_DLY_SEL_RX                   (P_CIM_DYN_DLY_SEL_RX_3),//input               
    .P_CIM_DYN_DLY_SEL_TX                   (P_CIM_DYN_DLY_SEL_TX_3),//input               
    .P_CIM_START_ALIGN_RX                   (P_CIM_START_ALIGN_RX_3),//input               
    .P_CIM_START_ALIGN_TX                   (P_CIM_START_ALIGN_TX_3),//input               
    //New Added                                      
    .MCB_RCLK                               (MCB_RCLK_3            ),//input               
    .SYNC                                   (SYNC_3                ),//input               
    .RATE_CHANGE                            (RATE_CHANGE_3         ),//input               
    .PLL_LOCK_SEL                           (PLL_LOCK_SEL_3        ),//input               
    //cin and cout                           
    .LANE_CIN_BUS_FORWARD                   (LANE_CIN_BUS_FORWARD_3),//input [18:0]        
    .APATTERN_STATUS_CIN                    (APATTERN_STATUS_CIN_3 ),//input               
    //From PLL                                  
    .CLK_TXP                                (CLK_TXP_3             ),//input               
    .CLK_TXN                                (CLK_TXN_3             ),//input               
    .CLK_RX0                                (CLK_RX0_3             ),//input               
    .CLK_RX90                               (CLK_RX90_3            ),//input               
    .CLK_RX180                              (CLK_RX180_3           ),//input               
    .CLK_RX270                              (CLK_RX270_3           ),//input               
    .PLL_PD_I                               (PLL_PD_I_3            ),//input               
    .PLL_RESET_I                            (PLL_RESET_I_3         ),//input               
    .PLL_REFCLK_I                           (PLL_REFCLK_I_3        ),//input               
    .PLL_RES_TRIM_I                         (PLL_RES_TRIM_I_3      ) //input [5:0]         
);
end
else begin:CHANNEL3_NULL //output default value to be done
    assign      P_TX_SDN_3                      = 1'b0 ;//output              
    assign      P_TX_SDP_3                      = 1'b0 ;//output              
    assign      P_PCS_RX_MCB_STATUS_3           = 1'b0 ;//output              
    assign      P_PCS_LSM_SYNCED_3              = 1'b0 ;//output              
    assign      P_CFG_READY_3                   = 1'b0 ;//output              
    assign      P_CFG_RDATA_3                   = 8'b0 ;//output [7:0]        
    assign      P_CFG_INT_3                     = 1'b0 ;//output              
    assign      P_RDATA_3                       = 47'b0;//output [46:0]       
    assign      P_RCLK2FABRIC_3                 = 1'b0 ;//output              
    assign      P_TCLK2FABRIC_3                 = 1'b0 ;//output              
    assign      P_RX_SIGDET_STATUS_3            = 1'b0 ;//output              
    assign      P_RX_SATA_COMINIT_3             = 1'b0 ;//output              
    assign      P_RX_SATA_COMWAKE_3             = 1'b0 ;//output              
    assign      P_RX_LS_DATA_3                  = 1'b0 ;//output              
    assign      P_RX_READY_3                    = 1'b0 ;//output              
    assign      P_TEST_STATUS_3                 = 20'b0;//output [19:0]       
    assign      P_TX_RXDET_STATUS_3             = 1'b0 ;//output              
    assign      P_CA_ALIGN_RX_3                 = 1'b0 ;//output              
    assign      P_CA_ALIGN_TX_3                 = 1'b0 ;//output              
    assign      PMA_RCLK_3                      = 1'b0 ;//output       	    
    assign      TXPCLK_PLL_3                    = 1'b0 ;//output              
    assign      LANE_COUT_BUS_FORWARD_3         = 19'b0;//output [18:0]       
    assign      APATTERN_STATUS_COUT_3          = 1'b0 ;//output              
end
endgenerate


endmodule
