module eth # (
    parameter REPEAT_TIME = 16'hFFFF,           //重发ARP广播的间隔时间
              REPEAT_CNT  = 2,                  //重发ARP广播的次数
              //MAC的失效时间和存储数量
              INVALID_TIME = 32'hFFFF_FFFF,
              CACHE_SIZE = 16,
              //支持的以太网缓存深度
              TX_FIFO_DEPTH = 512,
              RX_FIFO_DEPTH = 512,
              //支持的用户数据缓存的最大数据深度
              TX_DATA_DEPTH = 2048,                          
              RX_DATA_DEPTH = 2048,
              READ_DELAY = 1
)(
    input clk,              //用户时钟
    input rst,

    //本地信息
    input  [47 : 0] loca_mac    ,
    input  [31 : 0] loca_ip     ,
    input  [15 : 0] loca_port   ,
    //目的信息
    input  [31 : 0] dst_ip      ,
    input  [15 : 0] dst_port    ,



    //用户数据
    //tx用户数据输
    input  [7 : 0]   s_axis_data  ,
    input            s_axis_valid ,
    input            s_axis_last  ,
    output           s_axis_ready , 
    //rx
    //用户数据发出
    output  [7 : 0]  m_axis_data  ,
    output           m_axis_valid ,
    output           m_axis_last  ,
    input            m_axis_ready ,

    //rgmii  tx
    output         rgmii_tx_clk ,       
    output         rgmii_tx_ctl ,
    output [3 : 0] rgmii_tx_data,

    //rgmii  rx
    input          rgmii_rx_clk ,       //eth时钟
    input          rgmii_rx_ctl ,
    input  [3 : 0] rgmii_rx_data,

    output         phy_rst_n


);


    // wire rgmii_rx_clk_ibuf;
    // IBUF ibuf_clk(
    //     .I(rgmii_rx_clk),
    //     .O(rgmii_rx_clk_ibuf)
    // );

    // wire rgmii_rx_ctl_buf;
    // IBUF ibuf_ctl(
    //     .I(rgmii_rx_ctl),
    //     .O(rgmii_rx_ctl_ibuf)
    // );

    // wire [3 : 0] rgmii_rx_data_ibuf;
    // IBUF ibuf_data1(
    //     .I(rgmii_rx_data[0]),
    //     .O(rgmii_rx_data_ibuf[0])
    // );

    //     IBUF ibuf_data2(
    //     .I(rgmii_rx_data[1]),
    //     .O(rgmii_rx_data_ibuf[1])
    // );

    //     IBUF ibuf_data3(
    //     .I(rgmii_rx_data[2]),
    //     .O(rgmii_rx_data_ibuf[2])
    // );

    //     IBUF ibuf_data4(
    //     .I(rgmii_rx_data[3]),
    //     .O(rgmii_rx_data_ibuf[3])
    // );




    assign phy_rst_n = ~rst;



    
    //eth所有时钟都用phy芯片的接受时钟
    assign gmii_tx_clk = gmii_rx_clk;

    //时钟管理
    wire gmii_clk_90, clk_ref;
    clk_wiz_ddr clk_90(
        //这里是iddr参考时钟
        .clk_out2(clk_ref),
        //这里是oddr 和 iddr 采集数据时时钟相移90
        .clk_out1(gmii_clk_90),     

        .clk_in1 (gmii_tx_clk)
    ); 

    // wire gmii_clk_90, clk_ref;
    // clk_wiz_ddr clk_90(
    //     //这里是iddr参考时钟
    //     .clk_out3(clk_ref),
    //     //这里是oddr 和 iddr 采集数据时时钟相移90
    //     .clk_out2(gmii_clk_90),     
    //     .clk_out1(gmii_tx_clk),     

    //     .clk_in1 (clk)
    // ); 

    wire rst_eth, rst_ref;

    async_rst #(
        .RESET_NUM(2),
        .RESET_CNT(16)
    )
    async_rst(
        //原始时钟复位信号
        .reset(rst),

        //想要同步到的时钟和复位信号
        .clk({gmii_tx_clk, clk_ref}),
        .rst({rst_eth, rst_ref})
    );



    // reset_eth reset_eth (
    //   .slowest_sync_clk(gmii_tx_clk),          // input wire slowest_sync_clk
    //   .ext_reset_in(rst),                  // input wire ext_reset_in
    //   .aux_reset_in(),                  // input wire aux_reset_in
    //   .mb_debug_sys_rst(),          // input wire mb_debug_sys_rst
    //   .dcm_locked(),                      // input wire dcm_locked
    //   .mb_reset(),                          // output wire mb_reset
    //   .bus_struct_reset(),          // output wire [0 : 0] bus_struct_reset
    //   .peripheral_reset(rst_eth),          // output wire [0 : 0] peripheral_reset
    //   .interconnect_aresetn(),  // output wire [0 : 0] interconnect_aresetn
    //   .peripheral_aresetn()      // output wire [0 : 0] peripheral_aresetn
    // );



    (* IODELAY_GROUP = "rgmii_delay" *) 
    IDELAYCTRL #(
        .SIM_DEVICE("ULTRASCALE")  // Set the device version for simulation functionality (ULTRASCALE)
    )
    IDELAYCTRL_inst(
        .RDY(),                      // 1-bit output: Ready output
        .REFCLK(clk_ref),            //延迟控制器（需300HZ以上参考时钟）
        .RST(rst_ref)                // 1-bit input: Active high reset input
    );




    wire         gmii_rx_clk ;
    wire         gmii_rx_dv  ;
    wire         gmii_rx_er  ;
    wire [7 : 0] gmii_rx_data;



    rgmii2gmii #(
        .DEVICE  ("XILINX"         ),
        .ZYQN_MOD("ULTRASCALE_PLUS"),
        .DDR_PRIM("IODDR"          ) 
    )
    rgmii2gmii_inst(
        // .clk_ref(clk_ref),
        // .rst(rst),
        .rgmii_rx_clk (rgmii_rx_clk),
        .rgmii_rx_ctl (rgmii_rx_ctl),
        .rgmii_rx_data(rgmii_rx_data), 


        .gmii_rx_clk (gmii_rx_clk ),
        .gmii_rx_dv  (gmii_rx_dv  ),
        .gmii_rx_er  (gmii_rx_er  ),
        .gmii_rx_data(gmii_rx_data)
    );


    wire [7 : 0]  rx_fifo_data ;
    wire          rx_fifo_valid;
    wire          rx_fifo_last ;
    wire          rx_fifo_user ;
    wire          rx_fifo_ready;


    gmii2axis # (
        .DATA_DEPTH(RX_DATA_DEPTH + 54)
    )
    gmii2axis_inst(

        .rst(rst_eth)         ,
        //gmii接口 
        .gmii_rx_clk (gmii_rx_clk ),
        .gmii_rx_dv  (gmii_rx_dv  ),
        .gmii_rx_er  (gmii_rx_er  ),
        .gmii_rx_data(gmii_rx_data),   


        .m_axis_data (rx_fifo_data ) ,
        .m_axis_valid(rx_fifo_valid) ,
        .m_axis_last (rx_fifo_last ) ,
        .m_axis_user (rx_fifo_user ) 

    );


   wire         rx_mac_valid;
   wire [7 : 0] rx_mac_data ;
   wire         rx_mac_error;
   wire         rx_mac_last ;
   wire         rx_mac_ready;


    async_fifo #(
        .FIFO_DEPTH(RX_FIFO_DEPTH),
        .FIFO_WIDTH(9)                                  //LAST + USER + DATA
    )
    async_fifo_rx(
        .rst(rst_eth),          //对应
        .wr_clk(gmii_rx_clk),   //对应

        .rd_clk(clk),  //user

        .s_axis_valid(rx_fifo_valid),
        .s_axis_data ({rx_fifo_user, rx_fifo_data} ),
        .s_axis_last (rx_fifo_last ),
        .s_axis_ready(rx_fifo_ready ),

        .m_axis_valid(rx_mac_valid),
        .m_axis_data ({rx_mac_error, rx_mac_data} ),
        .m_axis_last (rx_mac_last ),
        .m_axis_ready(rx_mac_ready)
    );




    wire         tx_mac_valid;
    wire [7 : 0] tx_mac_data ;
    wire         tx_mac_last ;
    wire         tx_mac_ready;


    wire [7 : 0] m_axis_data_pipe ;    
    wire         m_axis_valid_pipe;
    wire         m_axis_last_pipe ;
    wire         m_axis_ready_pipe;
    

    eth_axi # (
        .REPEAT_TIME(REPEAT_TIME),           //重发ARP广播的间隔时间
        .REPEAT_CNT(REPEAT_CNT),                  //重发ARP广播的次数
        .INVALID_TIME(INVALID_TIME),
        .CACHE_SIZE(CACHE_SIZE),
        .TX_DATA_DEPTH(TX_DATA_DEPTH),                         //支持缓存的最大数据深度 
        .RX_DATA_DEPTH(RX_DATA_DEPTH),
        .READ_DELAY(READ_DELAY)
    )
    eth_axi_inst(
    .clk(clk),  //user
    .rst(rst),

    //本地信息
    .loca_mac (loca_mac )   ,
    .loca_ip  (loca_ip  )   ,
    .loca_port(loca_port)   ,
    //目的信息
    .dst_ip  (dst_ip  )    ,
    .dst_port(dst_port)    ,


    //用户数据
    //tx用户数据输
    .s_axis_data (s_axis_data ) ,
    .s_axis_valid(s_axis_valid) ,
    .s_axis_last (s_axis_last ) ,
    .s_axis_ready(s_axis_ready) , 
    //rx
    //用户数据发出
    .m_axis_data (m_axis_data_pipe ) ,
    .m_axis_valid(m_axis_valid_pipe) ,
    .m_axis_last (m_axis_last_pipe ) ,
    .m_axis_ready(m_axis_ready_pipe) ,


    //gmii
    //进入mac层解析 rx
    .s_gmii_axis_data (rx_mac_data ) ,
    .s_gmii_axis_valid(rx_mac_valid) , 
    .s_gmii_axis_last (rx_mac_last ) ,
    .s_gmii_axis_ready(rx_mac_ready) , 
    .s_gmii_axis_error(rx_mac_error) ,    //phy的er信号   
    //mac层输出  tx
    .m_gmii_axis_data (tx_mac_data ) ,    
    .m_gmii_axis_valid(tx_mac_valid) ,
    .m_gmii_axis_last (tx_mac_last ) ,
    .m_gmii_axis_ready(tx_mac_ready) 

    );




   wire         tx_fifo_valid;
   wire [7 : 0] tx_fifo_data ;
   wire         tx_fifo_last ;
   wire         tx_fifo_ready;


    async_fifo #(
        .FIFO_DEPTH(TX_FIFO_DEPTH),
        .FIFO_WIDTH(8)                                  
    )
    async_fifo_tx(
        .rst(rst),              //对应
        .wr_clk(clk),  //user   //对应

        .rd_clk(gmii_tx_clk),

        .s_axis_valid(tx_mac_valid),
        .s_axis_data (tx_mac_data ),  //LAST + DATA
        .s_axis_last (tx_mac_last ),
        .s_axis_ready(tx_mac_ready),

        .m_axis_valid(tx_fifo_valid),
        .m_axis_data (tx_fifo_data ),
        .m_axis_last (tx_fifo_last ),
        .m_axis_ready(tx_fifo_ready)
    );



    wire         gmii_tx_clk ;
    wire         gmii_tx_en  ;
    wire         gmii_tx_er  ;
    wire [7 : 0] gmii_tx_data;


    axis2gmii # (
        .DATA_DEPTH(TX_DATA_DEPTH + 54)
    )
    axis2gmii_inst(
        .s_axis_valid(tx_fifo_valid) ,
        .s_axis_data (tx_fifo_data ) ,
        .s_axis_last (tx_fifo_last ) ,
        .s_axis_ready(tx_fifo_ready) ,

        .rst(rst_eth)         ,
        //gmii接口 
        .gmii_tx_clk (gmii_tx_clk ),
        .gmii_tx_en  (gmii_tx_en  ),
        .gmii_tx_er  (gmii_tx_er  ),
        .gmii_tx_data(gmii_tx_data)
    );



    gmii2rgmii #(
        .DEVICE  ("XILINX"         ),
        .ZYQN_MOD("ULTRASCALE_PLUS"),
        .DDR_PRIM("IODDR"          ) 
    )
    gmii2rgmii_inst(
        // .rst(rst),
        .gmii_tx_clk (gmii_clk_90 ),
        .gmii_tx_en  (gmii_tx_en  ),
        .gmii_tx_er  (gmii_tx_er  ),
        .gmii_tx_data(gmii_tx_data), 

        .rgmii_tx_clk (rgmii_tx_clk ),
        .rgmii_tx_ctl (rgmii_tx_ctl ),
        .rgmii_tx_data(rgmii_tx_data)
    );




    pipe #(
        .WIDTH(9)
    )
    eth_pipe(
        .clk(clk),
        .rst(rst),

        .up_valid(m_axis_valid_pipe),
        .up_ready(m_axis_ready_pipe),
        .data_in ({m_axis_last_pipe, m_axis_data_pipe}),


        .down_valid(m_axis_valid),
        .down_ready(m_axis_ready),
        .data_out  ({m_axis_last, m_axis_data})
    );


endmodule