`timescale 1ns / 1ps
module gmii2rgmii #(
    parameter DEVICE     = "XILINX",
    parameter ZYQN_MOD   = "ULTRASCALE_PLUS",
    parameter DDR_PRIM   = "IODDR" 
)(
    // input         rst,
    input         gmii_tx_clk,
    input         gmii_tx_en,
    input         gmii_tx_er,
    input [7 : 0] gmii_tx_data, 

    output          rgmii_tx_clk,
    output          rgmii_tx_ctl,
    output  [3 : 0] rgmii_tx_data
);

    // wire gmii_tx_clk_90;

    // clk_wiz_oddr clk_90(
    //     .clk_out1(gmii_tx_clk_90),     // output clk_out1

    //     .clk_in1 (gmii_tx_clk)
    // ); 

    // assign gmii_clk = gmii_tx_clk_90;

    // wire gmii_tx_clk_buf;
    // BUFG BUFG_TX (
    //   .I            (gmii_tx_clk),      // 1-bit input: Clock input
    //   .O            (gmii_tx_clk_buf)      // 1-bit output: Clock output
    // );  


    //单边的gmii变rgmii数据
    //双边沿采样 上升沿D1->Q 下降沿D2->Q  
    genvar i;
    generate
        for(i = 0; i < 4; i = i + 1) begin
            oddr #(
                .DEVICE   (DEVICE),
                .ZYQN_MOD (ZYQN_MOD),
                .DDR_PRIM (DDR_PRIM),
                .DELAY("FALSE")
            )
            oddr_data(
               .Q(rgmii_tx_data[i]),   // 1-bit output: Data output to IOB
               .C(gmii_tx_clk),   // 1-bit input: High-speed clock input
               .D1(gmii_tx_data[i]), // 1-bit input: Parallel data input 1
               .D2(gmii_tx_data[i+4]), // 1-bit input: Parallel data input 2
               .SR(1'b0)  // 1-bit input: Active-High Async Reset
            );
        end
    endgenerate

    //rgmii_ctl信息
    oddr #(
        .DEVICE   (DEVICE),
        .ZYQN_MOD (ZYQN_MOD),
        .DDR_PRIM (DDR_PRIM),
        .DELAY("FALSE")
    )
    oddr_ctl(
       .Q(rgmii_tx_ctl),   
       .C(gmii_tx_clk),   
       .D1(gmii_tx_en), 
       .D2(gmii_tx_en ^ gmii_tx_er), // gmii_tx_er==0 no error and en==1 is transform
       .SR(1'b0)  // 1-bit input: Active-High Async Reset
    );

    //rgmii_clk信息
    oddr #(
        .DEVICE   (DEVICE),
        .ZYQN_MOD (ZYQN_MOD),
        .DDR_PRIM (DDR_PRIM),
        .DELAY("FALSE")
    )
    oddr_clk(
       .Q(rgmii_tx_clk),   
       .C(gmii_tx_clk),   
       .D1(1'b1), 
       .D2(1'b0), 
       .SR(1'b0)  // 1-bit input: Active-High Async Reset
    );

endmodule
