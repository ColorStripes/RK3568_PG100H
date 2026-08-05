module oddr #(
    parameter DEVICE     = "XILINX",
    parameter ZYQN_MOD   = "ULTRASCALE_PLUS",
    parameter DDR_PRIM   = "IODDR" ,
    parameter DELAY      = "TRUE"
) (
    input  C,
    input  D1 ,
    input  D2 ,
    input  SR ,

    output Q 
);





    generate
        if(DELAY == "TRUE") begin                       //ÑÓ³ÙODDR
            //ÑÓ³Ù
            wire Q_f;
            if(ZYQN_MOD == "ULTRASCALE_PLUS") begin

                (* IODELAY_GROUP = "rgmii_delay" *) 
                ODELAYE3 #(
                   .CASCADE("NONE"),               // Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
                   .DELAY_FORMAT("TIME"),          // (COUNT, TIME)
                   .DELAY_TYPE("FIXED"),           // Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
                   .DELAY_VALUE(0),                // Output delay tap setting
                   .IS_CLK_INVERTED(1'b0),         // Optional inversion for CLK
                   .IS_RST_INVERTED(1'b0),         // Optional inversion for RST
                   .REFCLK_FREQUENCY(500.0),       // IDELAYCTRL clock input frequency in MHz (200.0-800.0).
                   .SIM_DEVICE("ULTRASCALE_PLUS"), // Set the device version for simulation functionality (ULTRASCALE,
                                                   // ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
                   .UPDATE_MODE("ASYNC")           // Determines when updates to the delay will take effect (ASYNC, MANUAL,
                                                   // SYNC)
                )
                ODELAYE3_inst (
                   .CASC_OUT(),       // 1-bit output: Cascade delay output to IDELAY input cascade
                   .CNTVALUEOUT(), // 9-bit output: Counter value output
                   .DATAOUT(Q),         // 1-bit output: Delayed data from ODATAIN input port
                   .CASC_IN(),         // 1-bit input: Cascade delay input from slave IDELAY CASCADE_OUT
                   .CASC_RETURN(), // 1-bit input: Cascade delay returning from slave IDELAY DATAOUT
                   .CE(1'b0),                   // 1-bit input: Active-High enable increment/decrement input
                   .CLK(C),                 // 1-bit input: Clock input
                   .CNTVALUEIN(9'd0),   // 9-bit input: Counter value input
                   .EN_VTC(1'b1),           // 1-bit input: Keep delay constant over VT
                   .INC(1'b0),                 // 1-bit input: Increment/Decrement tap delay input
                   .LOAD(1'b0),               // 1-bit input: Load DELAY_VALUE input
                   .ODATAIN(Q_f),         // 1-bit input: Data input
                   .RST(1'b0)                  // 1-bit input: Asynchronous Reset to the DELAY_VALUE
                );

                ODDRE1 #(
                   .IS_C_INVERTED(1'b0),           // Optional inversion for C
                   .IS_D1_INVERTED(1'b0),          // Unsupported, do not use
                   .IS_D2_INVERTED(1'b0),          // Unsupported, do not use
                   .SIM_DEVICE("ULTRASCALE_PLUS"), // Set the device version for simulation functionality (ULTRASCALE,
                                                   // ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
                   .SRVAL(1'b1)                    // Initializes the ODDRE1 Flip-Flops to the specified value (1'b0, 1'b1)
                )
                ODDRE1_data_inst(
                   .Q(Q_f),   // 1-bit output: Data output to IOB
                   .C(C),   // 1-bit input: High-speed clock input
                   .D1(D1), // 1-bit input: Parallel data input 1
                   .D2(D2), // 1-bit input: Parallel data input 2
                   .SR(SR)  // 1-bit input: Active-High Async Reset
                );
            end
            else if(ZYQN_MOD == "ULTRASCALE") begin
                ODDRE1 #(
                   .IS_C_INVERTED(1'b0),      // Optional inversion for C
                   .IS_D1_INVERTED(1'b0),     // Unsupported, do not use
                   .IS_D2_INVERTED(1'b0),     // Unsupported, do not use
                   .SIM_DEVICE("ULTRASCALE"), // Set the device version for simulation functionality (ULTRASCALE)
                   .SRVAL(1'b0)               // Initializes the ODDRE1 Flip-Flops to the specified value (1'b0, 1'b1)
                )
                ODDRE1_inst(
                   .Q(Q_f),   // 1-bit output: Data output to IOB
                   .C(C),   // 1-bit input: High-speed clock input
                   .D1(D1), // 1-bit input: Parallel data input 1
                   .D2(D2), // 1-bit input: Parallel data input 2
                   .SR(SR)  // 1-bit input: Active-High Async Reset
                );
            end
            else if(ZYQN_MOD == "7000") begin
                ODDR #(
                    .DDR_CLK_EDGE  ("SAME_EDGE"),  // "OPPOSITE_EDGE" or "SAME_EDGE" 
                    .INIT          (1'b0),         // Initial value of Q: 1'b0 or 1'b1
                    .SRTYPE        ("SYNC")        // Set/Reset type: "SYNC" or "ASYNC" 
                ) 
                ODDR_inst(
                    .Q             (Q_f), // 1-bit DDR output
                    .C             (C),  // 1-bit clock input
                    .CE            (1'b1),         // 1-bit clock enable input
                    .D1            (D1),   // 1-bit data input (positive edge)
                    .D2            (D2),   // 1-bit data input (negative edge)
                    .R             (SR),         // 1-bit reset
                    .S             (1'b0)          // 1-bit set
                );
            end
        end
        else begin                                 //ÎÞÑÓ³ÙODDR
            if(ZYQN_MOD == "ULTRASCALE_PLUS") begin
                ODDRE1 #(
                   .IS_C_INVERTED(1'b0),           // Optional inversion for C
                   .IS_D1_INVERTED(1'b0),          // Unsupported, do not use
                   .IS_D2_INVERTED(1'b0),          // Unsupported, do not use
                   .SIM_DEVICE("ULTRASCALE_PLUS"), // Set the device version for simulation functionality (ULTRASCALE,
                                                   // ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
                   .SRVAL(1'b1)                    // Initializes the ODDRE1 Flip-Flops to the specified value (1'b0, 1'b1)
                )
                ODDRE1_data_inst(
                   .Q(Q),   // 1-bit output: Data output to IOB
                   .C(C),   // 1-bit input: High-speed clock input
                   .D1(D1), // 1-bit input: Parallel data input 1
                   .D2(D2), // 1-bit input: Parallel data input 2
                   .SR(SR)  // 1-bit input: Active-High Async Reset
                );
            end
            else if(ZYQN_MOD == "ULTRASCALE") begin
                ODDRE1 #(
                   .IS_C_INVERTED(1'b0),      // Optional inversion for C
                   .IS_D1_INVERTED(1'b0),     // Unsupported, do not use
                   .IS_D2_INVERTED(1'b0),     // Unsupported, do not use
                   .SIM_DEVICE("ULTRASCALE"), // Set the device version for simulation functionality (ULTRASCALE)
                   .SRVAL(1'b0)               // Initializes the ODDRE1 Flip-Flops to the specified value (1'b0, 1'b1)
                )
                ODDRE1_inst(
                   .Q(Q),   // 1-bit output: Data output to IOB
                   .C(C),   // 1-bit input: High-speed clock input
                   .D1(D1), // 1-bit input: Parallel data input 1
                   .D2(D2), // 1-bit input: Parallel data input 2
                   .SR(SR)  // 1-bit input: Active-High Async Reset
                );
            end
            else if(ZYQN_MOD == "7000") begin
                ODDR #(
                    .DDR_CLK_EDGE  ("SAME_EDGE"),  // "OPPOSITE_EDGE" or "SAME_EDGE" 
                    .INIT          (1'b0),         // Initial value of Q: 1'b0 or 1'b1
                    .SRTYPE        ("SYNC")        // Set/Reset type: "SYNC" or "ASYNC" 
                ) 
                ODDR_inst(
                    .Q             (Q), // 1-bit DDR output
                    .C             (C),  // 1-bit clock input
                    .CE            (1'b1),         // 1-bit clock enable input
                    .D1            (D1),   // 1-bit data input (positive edge)
                    .D2            (D2),   // 1-bit data input (negative edge)
                    .R             (SR),         // 1-bit reset
                    .S             (1'b0)          // 1-bit set
                );
            end
        end
    endgenerate
    


endmodule