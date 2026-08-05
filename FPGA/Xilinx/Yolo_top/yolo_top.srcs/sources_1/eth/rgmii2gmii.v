`timescale 1ns / 1ps
module rgmii2gmii #(
    parameter DEVICE     = "XILINX",
    parameter ZYQN_MOD   = "ULTRASCALE_PLUS",
    parameter DDR_PRIM   = "IODDR" 
)(
    // input         clk_ref,
    // input         rst,
    input         rgmii_rx_clk,
    input         rgmii_rx_ctl,
    input [3 : 0] rgmii_rx_data, 

    output         gmii_rx_clk,
    output         gmii_rx_dv,
    output         gmii_rx_er,
    output [7 : 0] gmii_rx_data
);

    

    // wire rgmii_rx_clk_buf;
    // BUFIO BUFIO_inst (
    //   .I            (rgmii_rx_clk),      // 1-bit input: Clock input
    //   .O            (rgmii_rx_clk_buf)      // 1-bit output: Clock output
    // );  



    // 从外部引脚接入的时钟 进入全局缓冲
    wire rgmii_rx_clk_gbuf;
    BUFG BUFG_eth(
        .I(rgmii_rx_clk),
        .O(rgmii_rx_clk_gbuf)
    );

    //clk
    assign gmii_rx_clk = rgmii_rx_clk_gbuf;
    


    //单边的rgmii变gmii数据
    //双边沿采样 上升沿D->Q1 下降沿D->Q2  
    genvar i;
    generate
        for(i = 0; i < 4; i = i + 1) begin
            iddr #(
                .DEVICE   (DEVICE),
                .ZYQN_MOD (ZYQN_MOD),
                .DDR_PRIM (DDR_PRIM)
            )
            iddr_data(
               .Q1(gmii_rx_data[i]),   
               .Q2(gmii_rx_data[i+4]), 
               .C(rgmii_rx_clk_gbuf),   
               .D(rgmii_rx_data[i]), 
               .R(1'b0)  
            );
        end
    endgenerate

    wire dv_xor_er;
    //gmii_en 和 gmii_er信息
    iddr #(
        .DEVICE   (DEVICE),
        .ZYQN_MOD (ZYQN_MOD),
        .DDR_PRIM (DDR_PRIM)
    )
    iddr_ctl(
        .Q1(gmii_rx_dv),   
        .Q2(dv_xor_er), 
        .C(rgmii_rx_clk_gbuf),   
        .D(rgmii_rx_ctl), 
        .R(1'b0)  
    );
    assign gmii_rx_er = dv_xor_er ^ gmii_rx_dv;



endmodule
