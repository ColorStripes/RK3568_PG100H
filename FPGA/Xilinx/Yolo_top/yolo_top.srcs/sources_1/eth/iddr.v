module iddr #(
    parameter DEVICE     = "XILINX",
    parameter ZYQN_MOD   = "ULTRASCALE_PLUS",
    parameter DDR_PRIM   = "IODDR" 
) (
   //  input  clk_ref,
    input  C,
    input  D  ,
    input  R ,

    output Q1,
    output Q2 
);



   generate
        if(ZYQN_MOD == "ULTRASCALE_PLUS") begin

            //延迟
            wire D_f;
            (* IODELAY_GROUP = "rgmii_delay" *) 
            IDELAYE3 #(
               .CASCADE("NONE"),               // Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
               .DELAY_FORMAT("TIME"),          // Units of the DELAY_VALUE (COUNT, TIME)
               .DELAY_SRC("IDATAIN"),          // Delay input (DATAIN, IDATAIN)
               .DELAY_TYPE("FIXED"),           // Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
               .DELAY_VALUE(600),              // Input delay value setting
               .IS_CLK_INVERTED(1'b0),         // Optional inversion for CLK
               .IS_RST_INVERTED(1'b0),         // Optional inversion for RST
               .REFCLK_FREQUENCY(500.0),       // IDELAYCTRL clock input frequency in MHz (200.0-800.0)
               .SIM_DEVICE("ULTRASCALE_PLUS"), // Set the device version for simulation functionality (ULTRASCALE,
                                               // ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
               .UPDATE_MODE("ASYNC")           // Determines when updates to the delay will take effect (ASYNC, MANUAL,
                                               // SYNC)
            )
            IDELAYE3_inst (
               .CASC_OUT(),          // 1-bit output: Cascade delay output to ODELAY input cascade
               .CNTVALUEOUT(),       // 9-bit output: Counter value output
               .DATAOUT(D_f),             //输出数据
               .CASC_IN(),           // 1-bit input: Cascade delay input from slave ODELAY CASCADE_OUT
               .CASC_RETURN(),       // 1-bit input: Cascade delay returning from slave ODELAY DATAOUT
               .CE(1'b0),                   // 1-bit input: Active-High enable increment/decrement input
               .CLK(C),                 // 1-bit input: Clock input
               .CNTVALUEIN(9'd0),   // 9-bit input: Counter value input
               .DATAIN(1'b0),                //内部输入数据
               .EN_VTC(1'b1),           // 1-bit input: Keep delay constant over VT
               .IDATAIN(D),                 //外部引脚输入数据
               .INC(1'b0),                 // 1-bit input: Increment / Decrement tap delay input
               .LOAD(1'b0),               // 1-bit input: Load DELAY_VALUE input
               .RST(1'b0)                  // 1-bit input: Asynchronous Reset to the DELAY_VALUE
            );


            IDDRE1 #(
               .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"), // IDDRE1 mode (OPPOSITE_EDGE, SAME_EDGE, SAME_EDGE_PIPELINED)
               .IS_CB_INVERTED(1'b1),          // Optional inversion for CB
               .IS_C_INVERTED(1'b0)            // Optional inversion for C
            )
            IDDRE1_inst (
               .Q1(Q1), // 1-bit output: Registered parallel output 1
               .Q2(Q2), // 1-bit output: Registered parallel output 2
               .C(C),   // 1-bit input: High-speed clock
               .CB(C), // 1-bit input: Inversion of High-speed clock C
               .D(D_f),   // 1-bit input: Serial Data Input
               .R(R)    // 1-bit input: Active-High Async Reset
            );
        end
        else if(ZYQN_MOD == "ULTRASCALE") begin

            IDDRE1 #(
               .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"), // IDDRE1 mode (OPPOSITE_EDGE, SAME_EDGE, SAME_EDGE_PIPELINED)
               .IS_CB_INVERTED(1'b1),          // Optional inversion for CB
               .IS_C_INVERTED(1'b0)            // Optional inversion for C
            )
            IDDRE1_inst (
               .Q1(Q1), // 1-bit output: Registered parallel output 1
               .Q2(Q2), // 1-bit output: Registered parallel output 2
               .C(C),   // 1-bit input: High-speed clock
               .CB(C), // 1-bit input: Inversion of High-speed clock C
               .D(D_f),   // 1-bit input: Serial Data Input
               .R(R)    // 1-bit input: Active-High Async Reset
            );
        end
        else if(ZYQN_MOD == "7000") begin
            IDDR #(
               .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"), // "OPPOSITE_EDGE", "SAME_EDGE" or "SAME_EDGE_PIPELINED"  
               .INIT_Q1(1'b0), // Initial value of Q1: 1'b0 or 1'b1
               .INIT_Q2(1'b0), // Initial value of Q2: 1'b0 or 1'b1
               .SRTYPE("SYNC") // Set/Reset type: "SYNC" or "ASYNC" 
            ) 
            IDDR_inst (
               .Q1(Q1), // 1-bit output for positive edge of clock
               .Q2(Q2), // 1-bit output for negative edge of clock
               .C(C),   // 1-bit clock input
               .CE(1'b1), // 1-bit clock enable input
               .D(D_f),   // 1-bit DDR data input
               .R(R),   // 1-bit reset
               .S(1'b0)    // 1-bit set
            );
        end
    endgenerate
    


endmodule