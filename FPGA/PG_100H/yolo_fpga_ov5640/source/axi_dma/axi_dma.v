module axi_dma 	#(

        parameter    BURST_LEN   = 8              ,
        parameter    ID_WIDTH    = 4              ,
        parameter    DATA_WIDTH  = 128            ,
        parameter    KEEP_WIDTH  = DATA_WIDTH / 8  
    )(
    input clk,    // Clock
    input rst,  // Asynchronous reset active high


    input                         write_cmd_valid                    ,
    input     [31:0]              write_cmd_addr                     ,
    input     [31:0]              write_cmd_len                      ,
    input     [ID_WIDTH - 1:0]    write_cmd_id                       ,
    output                        write_cmd_ready                    ,


    input     [DATA_WIDTH - 1:0]  data_in                           ,
    input     [KEEP_WIDTH - 1:0]  data_in_keep                      ,
    input                         data_in_valid                     ,
    output                        data_in_last                      ,
    output                        data_in_ready                     ,	
    //trans data in
    output    [DATA_WIDTH - 1:0]  data_out                          ,
    output                        data_out_valid                    ,
    output                        data_out_last                     ,
    input                         data_out_ready                    ,

    input                         read_cmd_valid                    ,
    input     [31:0]              read_cmd_addr                     ,
    input     [31:0]              read_cmd_len                      ,
    input     [ID_WIDTH - 1:0]    read_cmd_id                       ,
    output                        read_cmd_ready                    ,



    output    [ID_WIDTH - 1:0]    m_axi_awid    ,
    output    [31:0]              m_axi_awaddr  ,
    output    [7:0]               m_axi_awlen   ,
    output    [2:0]               m_axi_awsize  ,
    output    [1:0]               m_axi_awburst ,
    output                        m_axi_awlock  ,
    output    [3:0]               m_axi_awcache ,
    output    [2:0]               m_axi_awprot  ,
    output                        m_axi_awvalid ,
    input                         m_axi_awready ,
    output    [DATA_WIDTH - 1:0]  m_axi_wdata   ,
    output    [KEEP_WIDTH - 1:0]  m_axi_wstrb   ,
    output                        m_axi_wlast   ,
    output                        m_axi_wvalid  ,
    input                         m_axi_wready  ,
    input     [ID_WIDTH - 1:0]    m_axi_bid     ,
    input     [1:0]               m_axi_bresp   ,
    input                         m_axi_bvalid  ,
    output                        m_axi_bready  ,	

    output    [ID_WIDTH - 1:0]    m_axi_arid    ,
    output    [31:0]              m_axi_araddr  ,
    output    [7:0]               m_axi_arlen   ,
    output    [2:0]               m_axi_arsize  ,
    output    [1:0]               m_axi_arburst ,
    output                        m_axi_arlock  ,
    output    [3:0]               m_axi_arcache ,
    output    [2:0]               m_axi_arprot  ,
    output                        m_axi_arvalid ,	
    input                         m_axi_arready ,
    input     [ID_WIDTH - 1:0]    m_axi_rid     ,
    input     [DATA_WIDTH - 1:0]  m_axi_rdata   ,
    input     [1:0]               m_axi_rresp   ,
    input                         m_axi_rlast   ,
    input                         m_axi_rvalid  ,
    output                        m_axi_rready   
);


    axi_dma_write#(
        .BURST_LEN  (BURST_LEN ),
        .ID_WIDTH   (ID_WIDTH  ),
        .DATA_WIDTH (DATA_WIDTH),
        .KEEP_WIDTH (KEEP_WIDTH)	
    ) axi_dma_write_inst(
    .clk            (clk),    // Clock
    .rst            (rst),    // Synchronous reset active high
    
    //cmd interface
    .cmd_valid      (write_cmd_valid    ),
    .cmd_addr       (write_cmd_addr     ),
    .cmd_id         (write_cmd_id       ),
    .cmd_len        (write_cmd_len      ),
    .cmd_ready      (write_cmd_ready    ),

    //trans data in
    .data_in      	(data_in      ),
    .data_in_keep   (data_in_keep ),
    .data_in_valid  (data_in_valid),
    .data_in_last   (data_in_last ),
    .data_in_ready  (data_in_ready),

    //axi w
    .m_axi_awid     (m_axi_awid   ),
    .m_axi_awaddr   (m_axi_awaddr ),
    .m_axi_awlen    (m_axi_awlen  ),
    .m_axi_awsize   (m_axi_awsize ),
    .m_axi_awburst  (m_axi_awburst),
    .m_axi_awlock   (m_axi_awlock ),
    .m_axi_awcache  (m_axi_awcache),
    .m_axi_awprot   (m_axi_awprot ),
    .m_axi_awvalid  (m_axi_awvalid),
    .m_axi_awready  (m_axi_awready),
    .m_axi_wdata    (m_axi_wdata  ),
    .m_axi_wstrb    (m_axi_wstrb  ),
    .m_axi_wlast    (m_axi_wlast  ),
    .m_axi_wvalid   (m_axi_wvalid ),
    .m_axi_wready   (m_axi_wready ),
    .m_axi_bid      (m_axi_bid    ),
    .m_axi_bresp    (m_axi_bresp  ),
    .m_axi_bvalid   (m_axi_bvalid ),
    .m_axi_bready   (m_axi_bready )

);

axi_dma_read#(
        .BURST_LEN  (BURST_LEN ),
        .ID_WIDTH   (ID_WIDTH  ),
        .DATA_WIDTH (DATA_WIDTH)
) axi_dma_read_inst
(
    .clk             (clk),    // Clock
    .rst             (rst),    // Synchronous reset active high
    
    //cmd interface
    .cmd_valid      (read_cmd_valid  ),
    .cmd_addr       (read_cmd_addr   ),
    .cmd_id         (read_cmd_id     ),
    .cmd_len        (read_cmd_len    ),
    .cmd_ready      (read_cmd_ready  ),

    //trans data in
    .data_out       (data_out      ),
    .data_out_valid (data_out_valid),
    .data_out_last  (data_out_last ),
    .data_out_ready (data_out_ready),

    //axi r
    .m_axi_arid     (m_axi_arid    ),
    .m_axi_araddr   (m_axi_araddr  ),
    .m_axi_arlen    (m_axi_arlen   ),
    .m_axi_arsize   (m_axi_arsize  ),
    .m_axi_arburst  (m_axi_arburst ),
    .m_axi_arlock   (m_axi_arlock  ),
    .m_axi_arcache  (m_axi_arcache ),
    .m_axi_arprot   (m_axi_arprot  ),
    .m_axi_arvalid  (m_axi_arvalid ),	
    .m_axi_arready  (m_axi_arready ),
    .m_axi_rid      (m_axi_rid     ),
    .m_axi_rdata    (m_axi_rdata   ),
    .m_axi_rresp    (m_axi_rresp   ),
    .m_axi_rlast    (m_axi_rlast   ),
    .m_axi_rvalid   (m_axi_rvalid  ),
    .m_axi_rready   (m_axi_rready  )

);


endmodule 