module pcie_fifo #(
    parameter ADDR_WIDTH = 12,
              MSI_NUM = 5,

    parameter   AXI_ID_LEN      = 4, 
		        AXI_DATA_LEN    = 128, 
		        AXI_DATA_SIZE   = $clog2(AXI_DATA_LEN/8), 	        
		        AXI_STRB_LEN    = AXI_DATA_LEN / 8               


)(    

    input                       button_rst_n    ,

    ////////////////// PCIE ////////////////
    input                       perst_n         ,
    input                       ref_clk_n       ,      
    input                       ref_clk_p       ,      
    input           [1:0]       rxn             ,
    input           [1:0]       rxp             ,
    output wire     [1:0]       txn             ,
    output wire     [1:0]       txp             ,
    output wire                 ref_led         ,
    output wire                 pclk_led        ,
    output wire                 smlh_link_up    ,
    output wire                 rdlh_link_up    ,

    output wire                 fifo_pcie_clk   ,
    output wire                 fifo_pcie_rst   , 

    input  [MSI_NUM-2 : 0]      i_msi_req       ,
    output [MSI_NUM-2 : 0]      o_msi_grant     ,

    ///////////////// AXI FOR DDR3 //////////////////////////////
    input                               axi_clk,
    input                               axi_rst,

    output       [AXI_ID_LEN-1:0]       axi_awid        /* synthesis PAP_MARK_DEBUG="true" */,
    output       [31:0]                 axi_awaddr      /* synthesis PAP_MARK_DEBUG="true" */,
    output       [ 3:0]                 axi_awlen       /* synthesis PAP_MARK_DEBUG="true" */,
    output       [ 2:0]                 axi_awsize      /* synthesis PAP_MARK_DEBUG="true" */,
    output       [ 1:0]                 axi_awburst     /* synthesis PAP_MARK_DEBUG="true" */,
    output                              axi_awlock      /* synthesis PAP_MARK_DEBUG="true" */,
    output       [ 3:0]                 axi_awcache     /* synthesis PAP_MARK_DEBUG="true" */,
    output       [ 2:0]                 axi_awprot      /* synthesis PAP_MARK_DEBUG="true" */,
    output       [ 3:0]                 axi_awqos       /* synthesis PAP_MARK_DEBUG="true" */,
    output                              axi_awvalid     /* synthesis PAP_MARK_DEBUG="true" */,
    input                               axi_awready     /* synthesis PAP_MARK_DEBUG="true" */,
    
    output       [AXI_DATA_LEN-1:0]     axi_wdata       /* synthesis PAP_MARK_DEBUG="true" */,
    output       [AXI_STRB_LEN-1:0]     axi_wstrb       /* synthesis PAP_MARK_DEBUG="true" */,
    output                              axi_wlast       /* synthesis PAP_MARK_DEBUG="true" */,
    output                              axi_wvalid      /* synthesis PAP_MARK_DEBUG="true" */,
    input                               axi_wready      /* synthesis PAP_MARK_DEBUG="true" */,
    
    input        [AXI_ID_LEN-1:0]       axi_bid         /* synthesis PAP_MARK_DEBUG="true" */,
    input        [ 1:0]                 axi_bresp       /* synthesis PAP_MARK_DEBUG="true" */,
    input                               axi_bvalid      /* synthesis PAP_MARK_DEBUG="true" */,
    output                              axi_bready      /* synthesis PAP_MARK_DEBUG="true" */,
    
    output       [AXI_ID_LEN-1:0]       axi_arid        /* synthesis PAP_MARK_DEBUG="true" */,
    output       [31:0]                 axi_araddr      /* synthesis PAP_MARK_DEBUG="true" */,
    output       [ 3:0]                 axi_arlen       /* synthesis PAP_MARK_DEBUG="true" */,
    output       [ 2:0]                 axi_arsize      /* synthesis PAP_MARK_DEBUG="true" */,
    output       [ 1:0]                 axi_arburst     /* synthesis PAP_MARK_DEBUG="true" */,
    output                              axi_arlock      /* synthesis PAP_MARK_DEBUG="true" */,
    output       [ 3:0]                 axi_arcache     /* synthesis PAP_MARK_DEBUG="true" */,
    output       [ 2:0]                 axi_arprot      /* synthesis PAP_MARK_DEBUG="true" */,
    output       [ 3:0]                 axi_arqos       /* synthesis PAP_MARK_DEBUG="true" */,
    output                              axi_arvalid     /* synthesis PAP_MARK_DEBUG="true" */,
    input                               axi_arready     /* synthesis PAP_MARK_DEBUG="true" */,
    
    input        [AXI_ID_LEN-1:0]       axi_rid         /* synthesis PAP_MARK_DEBUG="true" */,
    input        [AXI_DATA_LEN-1:0]     axi_rdata       /* synthesis PAP_MARK_DEBUG="true" */,
    input        [ 1:0]                 axi_rresp       /* synthesis PAP_MARK_DEBUG="true" */,
    input                               axi_rlast       /* synthesis PAP_MARK_DEBUG="true" */,
    input                               axi_rvalid      /* synthesis PAP_MARK_DEBUG="true" */,
    output                              axi_rready      /* synthesis PAP_MARK_DEBUG="true" */

        
);


//----------------------------------------
// CPU --> FPGA RX FIFO
//----------------------------------------

wire    [31:0]              fpga_ddr3_addr   ;              //rx
wire    [31:0]              fpga_ddr3_length ;              //rx
wire    [31:0]              fpga_ddr3_total_length ;        //tx

wire                        mrd_rx_busy;
wire                        fpga_rx_clk_en   ;
wire     [ADDR_WIDTH-1:0]   fpga_rx_addr     ;
wire     [127:0]            fpga_rx_data     ;
reg                         mrd_rx_busy_r    ;
wire                        mrd_rx_falling   ;
// reg                         mrd_rx_rase      ;
reg                         fpga_rx_clk_en_r ;
reg     [ADDR_WIDTH-1:0]    fpga_rx_addr_r   ;


// mrd_rx_busy falling edge detection
always @(posedge fifo_pcie_clk or posedge fifo_pcie_rst) begin
    if (fifo_pcie_rst) begin
        mrd_rx_busy_r <= 1'b0;
    end 
    else begin
        mrd_rx_busy_r <= mrd_rx_busy;
        // mrd_rx_rase   <= ~mrd_rx_busy_r & mrd_rx_busy;
    end
end
assign mrd_rx_falling = mrd_rx_busy_r & ~mrd_rx_busy;

////////////////////////////////////////
localparam S_DATA_WRY_IDLE   = 1'd0;
localparam S_DATA_WRY_CHECK  = 1'd1;
reg  data_wry_state;
reg  data_wry_state_next;
always @(posedge fifo_pcie_clk or posedge fifo_pcie_rst) begin
    if (fifo_pcie_rst) begin
        data_wry_state <= S_DATA_WRY_IDLE;
    end else begin
        data_wry_state <= data_wry_state_next;
    end
end

always @(*) begin
    case (data_wry_state)
        S_DATA_WRY_IDLE:  data_wry_state_next = mrd_rx_falling  ? S_DATA_WRY_CHECK : S_DATA_WRY_IDLE;
        S_DATA_WRY_CHECK: data_wry_state_next = fifo_rx_almost_full ? S_DATA_WRY_CHECK : S_DATA_WRY_IDLE;
        default:          data_wry_state_next = S_DATA_WRY_IDLE;
    endcase
end

reg fpga_data_valid_pulse;
always @(posedge fifo_pcie_clk or posedge fifo_pcie_rst) begin
    if (fifo_pcie_rst) begin
        fpga_data_valid_pulse <= 1'b0;
    end 
    else begin
        fpga_data_valid_pulse <= ((data_wry_state == S_DATA_WRY_CHECK) && !fifo_rx_almost_full) ;
    end
end
wire fpga_data_valid;
assign fpga_data_valid = fpga_data_valid_pulse;

///////////////////////////////////////////////
wire [31:0] total_beats    /* synthesis PAP_MARK_DEBUG="true" */;
assign total_beats     = (fpga_ddr3_length[31:4] + |fpga_ddr3_length[3:0]);  // ceil(len/16)
wire [31:0] dma_total_beats/* synthesis PAP_MARK_DEBUG="true" */;
assign dma_total_beats = (fpga_ddr3_total_length[31:4] + |fpga_ddr3_total_length[3:0]);  // ceil(len/16)
reg [31 : 0] rx_cnt;        //总传输字数计数器
always @(posedge fifo_pcie_clk or posedge fifo_pcie_rst) begin
    if (fifo_pcie_rst) begin
        fpga_rx_clk_en_r <= 1'b0;
        fpga_rx_addr_r   <= {ADDR_WIDTH{1'b0}};
        rx_cnt <= 32'd0;
    end 
    else if (fpga_data_valid) begin
        fpga_rx_clk_en_r <= 1'b1;
        fpga_rx_addr_r   <= {ADDR_WIDTH{1'b0}};
        if(rx_cnt == dma_total_beats) begin
            rx_cnt <= 32'd0;
        end
    end 
    else if (fpga_rx_clk_en_r) begin
        if (fpga_rx_addr_r == total_beats - 1) begin
            fpga_rx_clk_en_r <= 1'b0;
        end 
        fpga_rx_addr_r <= fpga_rx_addr_r + 1'b1;
        rx_cnt <= rx_cnt + 1'b1;
    end 
end
assign fpga_rx_clk_en = fpga_rx_clk_en_r;
assign fpga_rx_addr   = fpga_rx_addr_r;


reg fpga_rx_clk_en_d;
always @(posedge fifo_pcie_clk or posedge fifo_pcie_rst) begin
    if (fifo_pcie_rst) begin
        fpga_rx_clk_en_d <= 1'b0;
    end
    else begin
        fpga_rx_clk_en_d <= fpga_rx_clk_en_r;
    end
end

reg fpga_rx_done/* synthesis PAP_MARK_DEBUG="true" */;
always @(posedge fifo_pcie_clk or posedge fifo_pcie_rst) begin
    if (fifo_pcie_rst) begin
        fpga_rx_done <= 1'b0;
    end
    else if (fpga_data_valid) begin
        fpga_rx_done <= 1'b0;
    end
    else if(fpga_rx_addr_r == total_beats) begin
        if(rx_cnt == dma_total_beats) begin
            fpga_rx_done <= fifo_rx_empty;
        end
        else begin
            fpga_rx_done <= 1'b1;
        end
    end
end

//////////////tx/////////////////
wire                        mwr_tx_busy                ;
wire                        fpga_data_ready            ;
wire                        fpga_tx_done               ;
wire                        fpga_tx_clk_en             ;
wire     [ADDR_WIDTH-1:0]   fpga_tx_addr               /* synthesis PAP_MARK_DEBUG="true" */;
wire     [127:0]            fpga_tx_data               ;


pango_pcie_top #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .MSI_NUM(MSI_NUM)
)
pango_pcie_top(
    .button_rst_n(button_rst_n)    ,
    .perst_n     (perst_n     )    ,
    .ref_clk_n   (ref_clk_n)      ,
    .ref_clk_p   (ref_clk_p)      ,
    .rxn         (rxn)        ,
    .rxp         (rxp)        ,
    .txn         (txn)        ,
    .txp         (txp)        ,
    .ref_led     (ref_led     )    ,
    .pclk_led    (pclk_led    )    ,
    .smlh_link_up(smlh_link_up)    ,
    .rdlh_link_up(rdlh_link_up)    ,

    .i_msi_req  (i_msi_req    )    ,
    .o_msi_grant(o_msi_grant  )    ,

    .fpga_ddr3_addr   (fpga_ddr3_addr   ),
    .fpga_ddr3_length (fpga_ddr3_length ),
    .fpga_ddr3_total_length(fpga_ddr3_total_length),
    //FPGA --> CPU
    .fpga_tx_done     (fpga_tx_done     ),     
    .mwr_tx_busy      (mwr_tx_busy      ),
    .fpga_data_ready  (fpga_data_ready  ),     
    .fpga_tx_clk_en   (fpga_tx_clk_en   ),
    .fpga_tx_addr     (fpga_tx_addr     ),      //没用
    .fpga_tx_data     (fpga_tx_data     ),
    //CPU --> FPGA
    .fpga_rx_done     (fpga_rx_done     ),     
    .mrd_rx_busy      (mrd_rx_busy      ),
    .fpga_rx_clk_en   (fpga_rx_clk_en   ),
    .fpga_rx_addr     (fpga_rx_addr     ),
    .fpga_rx_data     (fpga_rx_data     ),

    .fifo_pcie_clk    (fifo_pcie_clk)    ,
    .fifo_pcie_rst    (fifo_pcie_rst)
);




wire [127:0] fifo_rx_data /* synthesis PAP_MARK_DEBUG="true" */;
wire         fifo_rx_empty/* synthesis PAP_MARK_DEBUG="true" */;
wire         fifo_rx_rd_en/* synthesis PAP_MARK_DEBUG="true" */;
wire [9 : 0] fifo_rx_water_level;

pcie_rx_fifo pcie_rx_fifo (
  .wr_clk       (fifo_pcie_clk      ),
  .wr_rst       (fifo_pcie_rst      ),
  .wr_en        (fpga_rx_clk_en_d   ),
  .wr_data      (fpga_rx_data       ),
  .wr_full      (                   ),
  .almost_full  (fifo_rx_almost_full),
  .rd_clk       (axi_clk            ),
  .rd_rst       (axi_rst            ),
  .rd_en        (fifo_rx_rd_en      ),
  .rd_data      (fifo_rx_data       ),
  .rd_empty     (fifo_rx_empty      ),
  .rd_water_level(fifo_rx_water_level),    // output [9:0]
  .almost_empty (                   )
);



// 突发参数计算

wire [31:0] last_beat_bytes/* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] last_beat_strb /* synthesis PAP_MARK_DEBUG="true" */;

assign last_beat_bytes = |fpga_ddr3_total_length[3:0] ? fpga_ddr3_total_length[3:0] : 32'd16;

// 最后 beat 的字节掩码
assign last_beat_strb  = (last_beat_bytes == 32'd1)  ? 16'b0000_0000_0000_0001 :
                         (last_beat_bytes == 32'd2)  ? 16'b0000_0000_0000_0011 :
                         (last_beat_bytes == 32'd3)  ? 16'b0000_0000_0000_0111 :
                         (last_beat_bytes == 32'd4)  ? 16'b0000_0000_0000_1111 :
                         (last_beat_bytes == 32'd5)  ? 16'b0000_0000_0001_1111 :
                         (last_beat_bytes == 32'd6)  ? 16'b0000_0000_0011_1111 :
                         (last_beat_bytes == 32'd7)  ? 16'b0000_0000_0111_1111 :
                         (last_beat_bytes == 32'd8)  ? 16'b0000_0000_1111_1111 :
                         (last_beat_bytes == 32'd9)  ? 16'b0000_0001_1111_1111 :
                         (last_beat_bytes == 32'd10) ? 16'b0000_0011_1111_1111 :
                         (last_beat_bytes == 32'd11) ? 16'b0000_0111_1111_1111 :
                         (last_beat_bytes == 32'd12) ? 16'b0000_1111_1111_1111 :
                         (last_beat_bytes == 32'd13) ? 16'b0001_1111_1111_1111 :
                         (last_beat_bytes == 32'd14) ? 16'b0011_1111_1111_1111 :
                         (last_beat_bytes == 32'd15) ? 16'b0111_1111_1111_1111 :
                                                       16'b1111_1111_1111_1111 ;




//====================================================
// AXI Write Interface Logic (With B channel)
//====================================================

localparam S_IDLE       = 3'd0;
localparam S_ADDR_SEND  = 3'd1;
localparam S_WDATA_SEND = 3'd2;
localparam S_BRESP_WAIT = 3'd3;
localparam S_WRITW_DATA = 3'd4;
// With B channel - after WLAST, wait for BVALID before next burst

reg  [2:0] state/* synthesis PAP_MARK_DEBUG="true" */;
reg  [2:0] next;

reg  [31:0]  cur_addr;
reg  [15:0]  cur_strb;
reg  [31:0]  beats_remain/* synthesis PAP_MARK_DEBUG="true" */;
reg  [3:0]   wbeat_cnt;

//----------- State Transition ----------
always @(posedge axi_clk) begin
    if (axi_rst)
        state <= S_IDLE;
    else
        state <= next;
end

always @(*) begin
    case (state)
        S_IDLE:       next = ((!fifo_rx_empty) && (fifo_rx_water_level > burst_len))  ? S_ADDR_SEND : S_IDLE;
        S_ADDR_SEND:  next = (axi_awvalid && axi_awready) ? S_WDATA_SEND : S_ADDR_SEND;
        S_WDATA_SEND: next = (axi_wvalid && axi_wready && axi_wlast) ? S_BRESP_WAIT : S_WDATA_SEND;
        S_BRESP_WAIT: next = (axi_bvalid && axi_bready && axi_bid == 4'b0000) ? ((beats_remain == 32'd0) ? S_IDLE : S_WRITW_DATA) : S_BRESP_WAIT;
        S_WRITW_DATA: next = ((fifo_rx_water_level > burst_len) && !axi_b_resp_error) ? S_ADDR_SEND : S_WRITW_DATA;
        default:      next = S_IDLE;
    endcase
end

//----------- Burst Length & Address Calculation ----------
always @(posedge axi_clk) begin
    if (axi_rst) begin
        cur_addr     <= 32'd0;
        cur_strb     <= 16'hFFFF;
        beats_remain <= 32'd0;
    end
    else if (state == S_IDLE && !fifo_rx_empty) begin
        cur_addr     <= {(fpga_ddr3_addr >> AXI_DATA_SIZE), {AXI_DATA_SIZE{1'b0}}};  // Convert DW addr to byte addr
        cur_strb     <= last_beat_strb;
        beats_remain <= dma_total_beats;
    end
    else if (state == S_WDATA_SEND && axi_wvalid && axi_wready && axi_wlast) begin
        cur_addr     <= cur_addr + ((axi_awlen + 4'd1) << 4);  // Advance by (beats sent * 16 bytes)
        beats_remain <= beats_remain - (axi_awlen + 4'd1);
    end
end

wire [3:0] burst_len = (beats_remain >= 32'd16) ? 4'd15 :
                       (beats_remain[3:0] == 4'd0) ? 4'd15 :
                       (beats_remain[3:0] - 4'd1);

wire [31:0] burst_addr = cur_addr;

assign axi_awlen      = burst_len;
assign axi_awaddr     = burst_addr;
assign axi_awsize     = AXI_DATA_SIZE;   // 4 (16 bytes per beat)
assign axi_awburst    = 2'b01;           // INCR burst
assign axi_awlock     = 1'b0;
assign axi_awcache    = 4'b0010;         // Normal non-cacheable
assign axi_awprot     = 3'b000;
assign axi_awqos      = 4'd0;
assign axi_awuser_ap  = 1'b0;
assign axi_awuser_id  = 4'd0;
assign axi_awid       = 4'd0;

assign axi_awvalid = (state == S_ADDR_SEND);// && !aw_sent;

// // AW handshake tracking
// always @(posedge axi_clk) begin
//     if (axi_rst)
//         aw_sent <= 1'b0;
//     else if (state == S_INIT)
//         aw_sent <= 1'b0;
//     else if (state == S_ADDR_SEND && axi_awvalid && axi_awready)
//         aw_sent <= 1'b1;
// end

// W beat counter
always @(posedge axi_clk) begin
    if (axi_rst)
        wbeat_cnt <= 4'd0;
    else if (state == S_BRESP_WAIT)
        wbeat_cnt <= 4'd0;
    else if (state == S_WDATA_SEND && axi_wvalid && axi_wready)
        wbeat_cnt <= wbeat_cnt + 4'd1;
end

wire is_last_beat    = (wbeat_cnt == burst_len);            //因为预期取 所以少读一个
wire is_last_overall = (beats_remain <= (axi_awlen + 4'd1));
wire wlast           = is_last_beat && is_last_overall;


//----------- FIFO Read Enable ----------
reg prefetch;
always @(posedge axi_clk) begin
    if (axi_rst) 
        prefetch <= 1'b0;
    else if(axi_awvalid && axi_awready)
        prefetch <= (burst_len == 0);
    else
        prefetch <= 1'b0;
end

assign fifo_rx_rd_en =  (axi_wready && !is_last_beat) | prefetch; //&& !wlast_sent;(state == S_WDATA_SEND) &&

reg axi_wvalid_r;
always @(posedge axi_clk) begin
    axi_wvalid_r <= fifo_rx_rd_en;
end

assign axi_wvalid = axi_wvalid_r;
assign axi_wlast  = is_last_beat;
assign axi_wstrb  = wlast ? cur_strb : 16'hFFFF;
assign axi_wdata  = fifo_rx_data;

//----------- B Channel (Write Response) ----------
assign axi_bready = (state == S_BRESP_WAIT);

// Optional: track B response errors
reg axi_b_resp_error;
always @(posedge axi_clk) begin
    if (axi_rst)
        axi_b_resp_error <= 1'b0;
    else if (axi_bvalid && axi_bready && axi_bid == 4'b0000)
        axi_b_resp_error <= (axi_bresp != 2'b00);  // 2'b00 = OKAY
end



// //----------- Write Done Pulse ----------
// reg write_done_r;
// always @(posedge axi_clk) begin
//     if (axi_rst)
//         write_done_r <= 1'b0;
//     else if (state == S_WRITW_DONE && (beats_remain == 32'd0))
//         write_done_r <= 1'b1;
//     else if((state == S_IDLE) && (fifo_rx_water_level > burst_len))
//         write_done_r <= 1'b0;
// end


//====================================================
// AXI Write Interface Logic - END (With B channel)
//====================================================




////////////////////////////////////////////////////////////////////////
wire         fifo_tx_empty/* synthesis PAP_MARK_DEBUG="true" */;
wire [9 : 0] fifo_tx_water_level/* synthesis PAP_MARK_DEBUG="true" */;
wire         fifo_tx_almost_full/* synthesis PAP_MARK_DEBUG="true" */;
wire full/* synthesis PAP_MARK_DEBUG="true" */;
pcie_tx_fifo pcie_tx_fifo (
  .wr_clk       (axi_clk            ),
  .wr_rst       (axi_rst            ),
  .wr_en        (fifo_tx_wr_en      ),
  .wr_data      (fifo_tx_wr_data    ),
  .wr_full      (full                ),
  .almost_full  (fifo_tx_almost_full ),
  .rd_clk       (fifo_pcie_clk       ),
  .rd_rst       (fifo_pcie_rst       ),
  .rd_en        (fpga_tx_clk_en      ),
  .rd_data      (fpga_tx_data        ),
  .rd_empty     (fifo_tx_empty       ),
  .rd_water_level(fifo_tx_water_level),
  .almost_empty (                    )
);





////////////////////////////////////////////////////////////////////////
// FPGA --> CPU TX Data Ready Logic
////////////////////////////////////////////////////////////////////////
wire  mwr_tx_busy_rising /* synthesis PAP_MARK_DEBUG="true" */;
reg  mwr_tx_busy_d;
always @(posedge fifo_pcie_clk or posedge fifo_pcie_rst) begin
    if (fifo_pcie_rst) begin
        mwr_tx_busy_d <= 1'b0;
    end else begin
        mwr_tx_busy_d <= mwr_tx_busy;
    end
end
assign mwr_tx_busy_rising = ~mwr_tx_busy_d & mwr_tx_busy;

localparam S_DATA_RDY_IDLE   = 1'd0;
localparam S_DATA_RDY_CHECK  = 1'd1;
reg  data_rdy_state;
reg  data_rdy_state_next;
always @(posedge fifo_pcie_clk or posedge fifo_pcie_rst) begin
    if (fifo_pcie_rst) begin
        data_rdy_state <= S_DATA_RDY_IDLE;
    end else begin
        data_rdy_state <= data_rdy_state_next;
    end
end

always @(*) begin
    case (data_rdy_state)
        S_DATA_RDY_IDLE:  data_rdy_state_next = mwr_tx_busy_rising  ? S_DATA_RDY_CHECK : S_DATA_RDY_IDLE;
        S_DATA_RDY_CHECK: data_rdy_state_next = (!fifo_tx_empty && (fifo_tx_water_level >= total_beats[9:0]))
                                               ? S_DATA_RDY_IDLE : S_DATA_RDY_CHECK;
        default:          data_rdy_state_next = S_DATA_RDY_IDLE;
    endcase
end

reg fpga_data_ready_r;
always @(posedge fifo_pcie_clk or posedge fifo_pcie_rst) begin
    if (fifo_pcie_rst) begin
        fpga_data_ready_r <= 1'b0;
    end
    else if(mwr_tx_busy_rising) begin
        fpga_data_ready_r <= 1'b0;
    end
    else if(data_rdy_state == S_DATA_RDY_CHECK) begin
        fpga_data_ready_r <= (!fifo_tx_empty && (fifo_tx_water_level >= total_beats[9:0])) ;
    end
end

assign fpga_data_ready = fpga_data_ready_r;

////////////////////////////////////////////////////////////////////////
// FPGA --> CPU TX Done Logic
////////////////////////////////////////////////////////////////////////
reg  [31:0] tx_cnt/* synthesis PAP_MARK_DEBUG="true" */;  //总操作beat数
reg  [31:0] tx_beat_cnt/* synthesis PAP_MARK_DEBUG="true" */;
reg        fpga_tx_done_r;

always @(posedge fifo_pcie_clk or posedge fifo_pcie_rst) begin
    if (fifo_pcie_rst) begin
        tx_beat_cnt    <= 32'd0;
    end 
    else if(tx_beat_cnt == total_beats) begin
        tx_beat_cnt <= 32'd0;
    end
    else if (fpga_tx_clk_en) begin
        tx_beat_cnt  <= tx_beat_cnt + 1'd1; 
    end
end

always @(posedge fifo_pcie_clk or posedge fifo_pcie_rst) begin
    if (fifo_pcie_rst) begin
        fpga_tx_done_r <= 1'b0;
    end
    else if(tx_beat_cnt == total_beats) begin
        fpga_tx_done_r <= 1'b1;
    end
    else if(mwr_tx_busy_rising) begin
        fpga_tx_done_r <= 1'b0;
    end
end
assign fpga_tx_done = fpga_tx_done_r;



always @(posedge fifo_pcie_clk or posedge fifo_pcie_rst) begin
    if (fifo_pcie_rst) begin
        tx_cnt <= 32'd0;
    end 
    else if (tx_cnt == dma_total_beats) begin
        tx_cnt <= 32'd0;
    end 
    else if (fpga_tx_clk_en) begin
        tx_cnt <= tx_cnt + 1'd1; 
    end
end

///////////////////////// AXI_read ////////////////////////////////

//====================================================
// AXI Read Interface Logic
//====================================================
reg tx_runing;
always @(posedge fifo_pcie_clk or posedge fifo_pcie_rst) begin
    if (fifo_pcie_rst) begin
        tx_runing <= 1'b0;
    end
    else if(tx_cnt == dma_total_beats) begin
        tx_runing <= 1'b0;
    end
    else if(mwr_tx_busy_rising) begin
        tx_runing <= 1'b1;
    end
end


//----------- CDC: tx_runing from fifo_pcie_clk to axi_clk ----------
reg tx_runing_axi;
reg tx_runing_axi_d1;
reg tx_runing_axi_d2;
always @(posedge axi_clk or posedge axi_rst) begin
    if (axi_rst) begin
        tx_runing_axi   <= 1'b0;
        tx_runing_axi_d1 <= 1'b0;
        tx_runing_axi_d2 <= 1'b0;
    end else begin
        tx_runing_axi    <= tx_runing;
        tx_runing_axi_d1 <= tx_runing_axi;
        tx_runing_axi_d2 <= tx_runing_axi_d1;
    end
end

wire tx_runing_axi_rising = tx_runing_axi_d1 && ~tx_runing_axi_d2;

//----------- Read Start & Base Address Latch ----------
reg [31:0] r_cur_addr;
reg [31:0] read_beats_remain /* synthesis PAP_MARK_DEBUG="true" */;
reg        read_started /* synthesis PAP_MARK_DEBUG="true" */;

always @(posedge axi_clk or posedge axi_rst) begin
    if (axi_rst) begin
        read_beats_remain <= 32'd0;
        read_started      <= 1'b0;
    end
    else if (tx_runing_axi_rising) begin
        read_beats_remain <= dma_total_beats;
        read_started      <= 1'b1;
    end
    else if (axi_rvalid && axi_rready && axi_rlast && (axi_rid == 4'b0000)) begin
        read_beats_remain <= read_beats_remain - (axi_arlen + 4'd1);
    end
    else if (read_started && read_beats_remain == 32'd0) begin
        read_started <= 1'b0;
    end
end


/////////////////////////////////////////
// reg test /* synthesis PAP_MARK_DEBUG="true" */;
// always @(posedge axi_clk or posedge axi_rst) begin
//     if (axi_rst) begin
//         test <= 1'b0;
//     end
//     else if(axi_rvalid && axi_rready && (axi_araddr > 32'h1c2000 + 32'h003F8400)) begin
//         test <= 1'b1;
//     end
// end
//////////////////////////////////////////

// Current address update
always @(posedge axi_clk or posedge axi_rst) begin
    if (axi_rst) begin
        r_cur_addr <= 32'd0;
    end
    else if (tx_runing_axi_rising) begin
        r_cur_addr <= {(fpga_ddr3_addr >> AXI_DATA_SIZE), {AXI_DATA_SIZE{1'b0}}};
    end
    else if (axi_rvalid && axi_rready && axi_rlast && (axi_rid == 4'b0000)) begin
        r_cur_addr <= r_cur_addr + ((axi_arlen + 4'd1) << 4);  // Advance by beats * 16 bytes
    end
end

//----------- Read Address State Machine ----------
localparam R_IDLE       = 2'd0;
localparam R_ADDR_SEND  = 2'd1;
localparam R_DATA_WAIT  = 2'd2;
localparam R_DONE       = 2'd3;

reg [1:0] r_state/* synthesis PAP_MARK_DEBUG="true" */;
reg [1:0] r_next;


always @(posedge axi_clk or posedge axi_rst) begin
    if (axi_rst)
        r_state <= R_IDLE;
    else
        r_state <= r_next;
end

always @(*) begin
    case (r_state)
        R_IDLE:      r_next = (read_started && !fifo_tx_almost_full) ? R_ADDR_SEND : R_IDLE;
        R_ADDR_SEND: r_next = (axi_arvalid && axi_arready) ? R_DATA_WAIT : R_ADDR_SEND;
        R_DATA_WAIT: r_next = (axi_rvalid && axi_rready && axi_rlast && (axi_rid == 4'b0000)) ? R_DONE : R_DATA_WAIT;
        R_DONE:      r_next = (read_beats_remain == 32'd0) ? R_IDLE : (fifo_tx_almost_full ? R_DONE : R_ADDR_SEND);
        default:     r_next = R_IDLE;
    endcase
end


//----------- Burst Length Calculation ----------
wire [3:0] r_burst_len = (read_beats_remain >= 32'd16) ? 4'd15 :
                          (read_beats_remain[3:0] == 4'd0) ? 4'd15 :
                          (read_beats_remain[3:0] - 4'd1);

//----------- AR Signal Assignments ----------
assign axi_arlen      = r_burst_len;
assign axi_araddr     = r_cur_addr;
assign axi_arsize     = AXI_DATA_SIZE;   // 4 (16 bytes per beat)
assign axi_arburst    = 2'b01;           // INCR burst
assign axi_arlock     = 1'b0;
assign axi_arcache    = 4'b0010;         // Normal non-cacheable
assign axi_arprot     = 3'b000;
assign axi_arqos      = 4'd0;
assign axi_aruser_ap  = 1'b0;
assign axi_aruser_id  = 4'd0;
assign axi_arid       = 4'd0;

// reg ar_sent;
// always @(posedge axi_clk or posedge axi_rst) begin
//     if (axi_rst)
//         ar_sent <= 1'b0;
//     else if (r_state == R_INIT)
//         ar_sent <= 1'b0;
//     else if (r_state == R_ADDR_SEND && axi_arvalid && axi_arready)
//         ar_sent <= 1'b1;
// end

assign axi_arvalid = (r_state == R_ADDR_SEND);// && !ar_sent;

//----------- RREADY & FIFO Write ----------
assign axi_rready = (r_state == R_DATA_WAIT);

//----------- FIFO Write Interface ----------
reg  fifo_tx_wr_en;
reg  [127:0] fifo_tx_wr_data;


always @(posedge axi_clk or posedge axi_rst) begin
    if (axi_rst) begin
        fifo_tx_wr_en    <= 1'b0;
        fifo_tx_wr_data  <= 128'd0;
    end
    else begin
        fifo_tx_wr_en    <= axi_rvalid && axi_rready && (axi_rid == 4'b0000);
        fifo_tx_wr_data  <= axi_rdata;
    end
end

// //----------- Read Done Tracking ----------
// reg read_done_r;
// always @(posedge axi_clk or posedge axi_rst) begin
//     if (axi_rst)
//         read_done_r <= 1'b0;
//     else if (r_state == R_DATA_WAIT && axi_rvalid && axi_rready && axi_rlast && (read_beats_remain == 32'd0))
//         read_done_r <= 1'b1;
//     else
//         read_done_r <= 1'b0;
// end

//====================================================
// AXI Read Interface Logic - END
//====================================================

endmodule
