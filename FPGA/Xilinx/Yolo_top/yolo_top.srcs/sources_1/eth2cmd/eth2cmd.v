module eth2cmd #(
    parameter AXI_DATA_WIDTH    = 32,
              AXI_ADDR_WIDTH    = 32,
              DDR_DATA_WIDTH_IN     = 128,
              DDR_DATA_WIDTH_OUT    = 128,
              INSTRUCTION_DATA_DEPTH = 64,
              DDR_DATA_DEPTH    = 512,
              NPU_LAYER = 88,
              LAYER_WIDTH = $clog2(NPU_LAYER),
              DEBUG = 1
)(
    input clk,
    input rst,


    input calculate_end,
    output calculate_end_receive,

    //eth用户数据
    //rx
    input  [7 : 0]   s_eth_axis_data  ,
    input            s_eth_axis_valid ,
    input            s_eth_axis_last  ,
    output           s_eth_axis_ready , 
    //tx
    output [7 : 0]   m_eth_axis_data  ,
    output           m_eth_axis_valid ,
    output           m_eth_axis_last  ,
    input            m_eth_axis_ready ,



    //REG的AXI_lite接口
    output                             m_axi_awvalid,
    input                              m_axi_awready, 
    output [AXI_ADDR_WIDTH-1 : 0]      m_axi_awaddr ,
 
 
    output                             m_axi_wvalid,
    input                              m_axi_wready, 
    output [AXI_DATA_WIDTH-1 : 0]      m_axi_wdata ,
    output [AXI_DATA_WIDTH/8-1 : 0]    m_axi_wstrb ,
 
    input                              m_axi_bvalid,
    output                             m_axi_bready,
    input [1 : 0]                      m_axi_bresp ,
 
    output                             m_axi_arvalid, 
    input                              m_axi_arready, 
    output  [AXI_ADDR_WIDTH-1 : 0]     m_axi_araddr,
 
 
    input                              m_axi_rvalid,
    output                             m_axi_rready, 
    input [AXI_DATA_WIDTH-1 : 0]       m_axi_rdata ,
    input [1 : 0]                      m_axi_rresp ,



    //从DDR拿数据
    output [AXI_ADDR_WIDTH-1 : 0]       s_ddr_cmd_addr  ,
    output [AXI_DATA_WIDTH-1 : 0]       s_ddr_cmd_len   ,
    output                              s_ddr_cmd_valid ,
    input                               s_ddr_cmd_ready ,
    input [DDR_DATA_WIDTH_OUT-1 : 0]    s_ddr_axis_data  ,
    input [DDR_DATA_WIDTH_OUT/8-1 : 0]  s_ddr_axis_keep  ,
    input                               s_ddr_axis_valid ,
    input                               s_ddr_axis_last  ,
    output                              s_ddr_axis_ready ,

    //发送给DDR
    output [AXI_ADDR_WIDTH-1 : 0]       m_ddr_cmd_addr   ,
    output [AXI_DATA_WIDTH-1 : 0]       m_ddr_cmd_len    ,
    output                              m_ddr_cmd_valid  ,
    input                               m_ddr_cmd_ready  ,
    output [DDR_DATA_WIDTH_IN-1 : 0]    m_ddr_axis_data  ,
    output [DDR_DATA_WIDTH_IN/8-1 : 0]  m_ddr_axis_keep  ,
    output                              m_ddr_axis_valid ,
    output                              m_ddr_axis_last  ,
    input                               m_ddr_axis_ready 

);



    wire [AXI_DATA_WIDTH-1 : 0] m_npu_instruction      ;
    wire                        m_npu_instruction_valid;
    wire                        m_npu_instruction_ready;
    wire                        fpga_start;
    wire                        fpga_end  ;
    wire [LAYER_WIDTH-1 : 0]    layer     ;

    wire [AXI_ADDR_WIDTH-1 : 0] m_npu_axis_addr ;
    wire [AXI_DATA_WIDTH-1 : 0] m_npu_axis_len  ;
    wire [7 : 0]                m_npu_axis_data ;
    wire                        m_npu_axis_valid;
    wire                        m_npu_axis_last ;
    wire                        m_npu_axis_ready;


    wire [AXI_ADDR_WIDTH-1 : 0] s_npu_axis_addr ;
    wire [AXI_DATA_WIDTH-1 : 0] s_npu_axis_len  ;
    wire                        s_npu_axis_req  ;
    wire [7 : 0]                s_npu_axis_data  ;
    wire                        s_npu_axis_valid ;
    wire                        s_npu_axis_last  ;
    wire                        s_npu_axis_ready ; 

    udp2npu_data #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .NPU_LAYER(NPU_LAYER),
        .DEBUG(DEBUG)
    )
    udp2npu_data(
        .clk(clk),
        .rst(rst),

        .calculate_end(calculate_end),
        .calculate_end_receive(calculate_end_receive),

        //eth用户数据
        //rx
        .s_eth_axis_data (s_eth_axis_data ) ,
        .s_eth_axis_valid(s_eth_axis_valid) ,
        .s_eth_axis_last (s_eth_axis_last ) ,
        .s_eth_axis_ready(s_eth_axis_ready) , 
        //tx
        .m_eth_axis_data (m_eth_axis_data ) ,
        .m_eth_axis_valid(m_eth_axis_valid) ,
        .m_eth_axis_last (m_eth_axis_last ) ,
        .m_eth_axis_ready(m_eth_axis_ready) ,


        //FPGA指令
        .m_npu_instruction      (m_npu_instruction      ),
        .m_npu_instruction_valid(m_npu_instruction_valid),
        .m_npu_instruction_ready(m_npu_instruction_ready),          //无反压信号 测试是否接收
       .fpga_start(fpga_start),
       .fpga_end(fpga_end),
       .layer(layer),

        //FPGA数据
        .s_npu_axis_addr (s_npu_axis_addr ) ,
        .s_npu_axis_len  (s_npu_axis_len  ) ,
        .s_npu_axis_req  (s_npu_axis_req  ) ,    //开始向DDR要数据
        .s_npu_axis_data (s_npu_axis_data ) ,
        .s_npu_axis_valid(s_npu_axis_valid) ,
        .s_npu_axis_last (s_npu_axis_last ) ,
        .s_npu_axis_ready(s_npu_axis_ready) , 

        .m_npu_axis_addr (m_npu_axis_addr ) ,
        .m_npu_axis_len  (m_npu_axis_len  ) ,
        .m_npu_axis_data (m_npu_axis_data ) ,
        .m_npu_axis_valid(m_npu_axis_valid) ,
        .m_npu_axis_last (m_npu_axis_last ) ,
        .m_npu_axis_ready(m_npu_axis_ready) 


    );



    instruction_buf #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .DATA_DEPTH(INSTRUCTION_DATA_DEPTH),          //缓存的指令数
        .NPU_LAYER(NPU_LAYER),
        .DEBUG(DEBUG)
    )
    instruction_buf(

        .clk(clk),
        .rst(rst),

        .calculate_end(calculate_end),
        .calculate_end_receive(calculate_end_receive),

        //instruction
        .s_npu_instruction      (m_npu_instruction      ),
        .s_npu_instruction_valid(m_npu_instruction_valid),
        .s_npu_instruction_ready(m_npu_instruction_ready),   
       .fpga_start(fpga_start),
       .fpga_end(fpga_end),
       .layer(layer),

        //REG的传输接口 （AXI_lite）
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready), 
        .m_axi_awaddr (m_axi_awaddr ),
    
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready), 
        .m_axi_wdata (m_axi_wdata ),
        .m_axi_wstrb (m_axi_wstrb ),
    
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp (m_axi_bresp ),
    
        .m_axi_arvalid(m_axi_arvalid), 
        .m_axi_arready(m_axi_arready), 
        .m_axi_araddr (m_axi_araddr ),
    
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready), 
        .m_axi_rdata (m_axi_rdata ),
        .m_axi_rresp (m_axi_rresp )   
    );




    eth2cmd_ddr #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        //向DDR写入的数据宽度
        .DATA_WIDTH_IN(DDR_DATA_WIDTH_IN ) ,
        .DATA_DEPTH   (DDR_DATA_DEPTH)
    )
    eth2cmd_ddr(
        .clk(clk),
        .rst(rst),

        .s_eth_axis_addr (m_npu_axis_addr ) ,
        .s_eth_axis_len  (m_npu_axis_len  ) ,
        .s_eth_axis_data (m_npu_axis_data ) ,
        .s_eth_axis_valid(m_npu_axis_valid) ,
        .s_eth_axis_last (m_npu_axis_last ) ,
        .s_eth_axis_ready(m_npu_axis_ready) ,


        .m_ddr_cmd_addr  (m_ddr_cmd_addr  ) ,
        .m_ddr_cmd_len   (m_ddr_cmd_len   ) ,
        .m_ddr_cmd_valid (m_ddr_cmd_valid ) ,
        .m_ddr_cmd_ready (m_ddr_cmd_ready ) ,
        .m_ddr_axis_data (m_ddr_axis_data ) ,
        .m_ddr_axis_keep (m_ddr_axis_keep ) ,
        .m_ddr_axis_valid(m_ddr_axis_valid) ,
        .m_ddr_axis_last (m_ddr_axis_last ) ,
        .m_ddr_axis_ready(m_ddr_axis_ready) 
    );



    wire [7 : 0]                s_npu_axis_data_pipe  ;
    wire                        s_npu_axis_valid_pipe ;
    wire                        s_npu_axis_last_pipe  ;
    wire                        s_npu_axis_ready_pipe ; 


    cmd_ddr2eth #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        //向DDR写入的数据宽度
        .DATA_WIDTH_OUT(DDR_DATA_WIDTH_OUT),
        .DATA_DEPTH(DDR_DATA_DEPTH * DDR_DATA_WIDTH_OUT / 8)
    )
    cmd_ddr2eth(
        .clk(clk),
        .rst(rst),

        .s_eth_axis_req  (s_npu_axis_req  ) ,
        .s_eth_axis_addr (s_npu_axis_addr ) ,
        .s_eth_axis_len  (s_npu_axis_len  ) ,
        .s_ddr_axis_data (s_ddr_axis_data ) ,
        .s_ddr_axis_keep (s_ddr_axis_keep ) ,
        .s_ddr_axis_valid(s_ddr_axis_valid) ,
        .s_ddr_axis_last (s_ddr_axis_last ) ,
        .s_ddr_axis_ready(s_ddr_axis_ready) ,


        .m_ddr_cmd_addr (s_ddr_cmd_addr ) ,
        .m_ddr_cmd_len  (s_ddr_cmd_len  ) ,
        .m_ddr_cmd_valid(s_ddr_cmd_valid) ,
        .m_ddr_cmd_ready(s_ddr_cmd_ready) ,
        .m_eth_axis_data (s_npu_axis_data_pipe ) ,
        .m_eth_axis_valid(s_npu_axis_valid_pipe) , 
        .m_eth_axis_last (s_npu_axis_last_pipe ) ,
        .m_eth_axis_ready(s_npu_axis_ready_pipe) 
    );


    pipe #(
        .WIDTH(9)
    )
    cmd_ddr2eth_pipe(
        .clk(clk),
        .rst(rst),

        .up_valid(s_npu_axis_valid_pipe),
        .up_ready(s_npu_axis_ready_pipe),
        .data_in ({s_npu_axis_last_pipe, s_npu_axis_data_pipe}),


        .down_valid(s_npu_axis_valid),
        .down_ready(s_npu_axis_ready),
        .data_out  ({s_npu_axis_last, s_npu_axis_data})
    );
    


endmodule