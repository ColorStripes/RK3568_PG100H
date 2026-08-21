// ==========================================
// 视频源参数选择：请保留其中一个，注释掉另一个
// ==========================================
 `define USE_OV5640
//`define USE_HDMI

module top #(
    parameter   MSI_NUM = 5,
    parameter   AXI_ID_LEN      = 4, 
                AXI_ID_M_LEN    = $clog2(7) + AXI_ID_LEN,
		        AXI_DATA_LEN    = 128, 
		        AXI_DATA_SIZE   = $clog2(AXI_DATA_LEN/8), 	        
		        AXI_STRB_LEN    = AXI_DATA_LEN / 8, 
                AXI_ADDR_WIDTH  = 32,  
                BURST_LEN = 16,

    //DDR3
    parameter  MEM_ROW_WIDTH    = 15         ,
               MEM_COLUMN_WIDTH = 10         ,
               MEM_BANK_WIDTH   = 3          ,
               MEM_DQ_WIDTH     = 16         ,
               MEM_DQS_WIDTH    = 2          ,
               CTRL_ADDR_WIDTH  = MEM_ROW_WIDTH + MEM_BANK_WIDTH + MEM_COLUMN_WIDTH
)(

    input                       free_clk        ,       //25MHZ
    input                       button_rst_n    ,

    ////////////////// PCIE ////////////////
    input                       perst_n         ,
    input                       ref_clk_n       ,      
    input                       ref_clk_p       ,      
    input           [1:0]       rxn             ,
    input           [1:0]       rxp             ,
    output  wire    [1:0]       txn             ,
    output  wire    [1:0]       txp             ,
    output wire                 ref_led         ,
    output wire                 pclk_led        ,
    // output wire                 smlh_link_up     ,
    // output wire                 rdlh_link_up     ,



    ////////////DDR3
    output                               mem_cs_n                  ,  
    output                               mem_rst_n                 ,
    output                               mem_ck                    ,
    output                               mem_ck_n                  ,
    output                               mem_cke                   ,
    output                               mem_ras_n                 ,
    output                               mem_cas_n                 ,
    output                               mem_we_n                  ,
    output                               mem_odt                   ,
    output      [MEM_ROW_WIDTH-1:0]      mem_a                     ,
    output      [MEM_BANK_WIDTH-1:0]     mem_ba                    ,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs                   ,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs_n                 ,
    inout       [MEM_DQ_WIDTH-1:0]       mem_dq                    ,
    output      [MEM_DQ_WIDTH/8-1:0]     mem_dm                    ,

    output reg                           heart_beat_led            ,

`ifdef USE_OV5640
    /////////////CAM
    input                                cmos1_pclk              , 
    input                                cmos1_vsync             , 
    input                                cmos1_href              , 
    input       [7 : 0]                  cmos1_data              , 
    output                               cmos1_rst_n             , 
    // output                               cmos1_pwdn              , 
    output                               cmos1_scl               , 
    inout                                cmos1_sda                 

`elsif USE_HDMI
    /////////////////////////  HDMI
    //ms72XX
    output            rstn_out,

    // FMC I2C 
    output            iic_scl,
    inout             iic_sda, 

    // output            iic_tx_scl,
    // inout             iic_tx_sda, 

    //HDMI IN
    input             pixclk_in ,                            
    input             vs_in     , 
    input             hs_in     , 
    input             de_in     ,
    input     [7:0]   r_in      , 
    input     [7:0]   g_in      , 
    input     [7:0]   b_in      
`endif
);

    wire clk_50m, clk_150m, clk_10m, locked;

    wire npu_clk, npu_rst;
    assign npu_clk = clk_150m;
    assign npu_rst = !locked;

///////////////////////////// AXI wires between crossbar and DDR3 ///////////////////////////
wire [27:0]                 ddr_axi_awaddr     /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_awuser_ap  ;
wire [AXI_ID_M_LEN-1:0]     ddr_axi_awuser_id  /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]                  ddr_axi_awlen      /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_awready    /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_awvalid    /* synthesis PAP_MARK_DEBUG="true" */;
wire [2:0]                  ddr_axi_awsize     /* synthesis PAP_MARK_DEBUG="true" */;
wire [1:0]                  ddr_axi_awburst    /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_awlock     ;
wire [3:0]                  ddr_axi_awcache    ;
wire [2:0]                  ddr_axi_awprot     ;
wire [3:0]                  ddr_axi_awqos      ;

wire [AXI_DATA_LEN-1:0]     ddr_axi_wdata      /* synthesis PAP_MARK_DEBUG="true" */;
wire [AXI_DATA_LEN-1:0]     ddr_axi_wdata_ddr3      ;
wire [AXI_STRB_LEN-1:0]     ddr_axi_wstrb      /* synthesis PAP_MARK_DEBUG="true" */;
wire [AXI_STRB_LEN-1:0]     ddr_axi_wstrb_ddr3      ;
wire                        ddr_axi_fifo_full/* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_wvalid     /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_wready_ddr3    ;
wire [AXI_ID_LEN-1:0]       ddr_axi_wusero_id  /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_wusero_last_ddr3;
wire                        ddr_axi_wlast      /* synthesis PAP_MARK_DEBUG="true" */;

wire [1:0]                  ddr_axi_bresp      /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_bvalid     /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_bready     /* synthesis PAP_MARK_DEBUG="true" */;
wire [AXI_ID_M_LEN-1:0]     ddr_axi_bid        /* synthesis PAP_MARK_DEBUG="true" */;



wire [27:0]                 ddr_axi_araddr     ;
wire                        ddr_axi_aruser_ap  ;
wire [AXI_ID_M_LEN-1:0]     ddr_axi_aruser_id  ;
wire [AXI_DATA_LEN-1:0]     ddr_axi_aruser     ;
wire [3:0]                  ddr_axi_arlen      ;
wire                        ddr_axi_arready    /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_arvalid    ;

wire [AXI_DATA_LEN-1:0]     ddr_axi_rdata      /* synthesis PAP_MARK_DEBUG="true" */;
wire [AXI_DATA_LEN-1:0]     ddr_axi_rdata_ddr3;
wire [AXI_ID_M_LEN-1:0]     ddr_axi_rid        /* synthesis PAP_MARK_DEBUG="true" */;
wire [AXI_ID_LEN-1:0]       ddr_axi_rid_ddr3;
wire                        ddr_axi_rlast      /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_rlast_ddr3;
wire                        ddr_axi_rvalid     /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_rvalid_ddr3;
wire                        ddr_axi_rready     /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_fifo_empty;





wire [2:0]                  ddr_axi_arsize     /* synthesis PAP_MARK_DEBUG="true" */;
wire [1:0]                  ddr_axi_arburst    /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_arlock     /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]                  ddr_axi_arcache    /* synthesis PAP_MARK_DEBUG="true" */;
wire [2:0]                  ddr_axi_arprot     /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]                  ddr_axi_arqos      /* synthesis PAP_MARK_DEBUG="true" */;
wire [1:0]                  ddr_axi_rresp      /* synthesis PAP_MARK_DEBUG="true" */;


wire [1:0]                  ddr_axi_buser      ;
wire [1:0]                  ddr_axi_ruser      ;
wire [1:0]                  ddr_axi_awuser     ;
wire [1:0]                  ddr_axi_wuser      ;


/////////////////////////////     DDR3   ///////////////////////////////////////////////////
parameter TH_1S = 27'd33000000;
reg  [26:0]                 cnt                        ;
always@(posedge core_clk or negedge ddr_init_done) begin
   if (!ddr_init_done)
      cnt <= 27'd0;
   else if ( cnt >= TH_1S )
      cnt <= 27'd0;
   else
      cnt <= cnt + 27'd1;
end

always @(posedge core_clk or negedge ddr_init_done) begin
   if (!ddr_init_done)
      heart_beat_led <= 1'd1;
   else if ( cnt >= TH_1S )
      heart_beat_led <= ~heart_beat_led;
end

wire [4:0] wr_water_level;
ddr_fifo16_w ddr_fifo16_w (
  .wr_data({ddr_axi_wstrb, ddr_axi_wdata}),              // input [143:0]
  .wr_en(ddr_axi_wvalid),                  // input
  .wr_water_level(wr_water_level),    // output [4:0]
  .full(ddr_axi_fifo_full),                    // output
  .almost_full(),      // output
  .rd_data({ddr_axi_wstrb_ddr3, ddr_axi_wdata_ddr3}),              // output [143:0]
  .rd_en(ddr_axi_wready_ddr3),                  // input
  .empty(),                  // output
  .almost_empty(),    // output
  .clk(axi_clk),                      // input
  .rst(axi_rst)                       // input
);



ddr_fifo16_r ddr_fifo16_r (
  .wr_data({ddr_axi_rid_ddr3, ddr_axi_rlast_ddr3, ddr_axi_rdata_ddr3}),              // input [132:0]
  .wr_en(ddr_axi_rvalid_ddr3),                  // input
  .full(),                    // output
  .almost_full(),      // output
  .rd_data({ddr_axi_rid[AXI_ID_LEN-1 : 0], ddr_axi_rlast, ddr_axi_rdata}),              // output [132:0]
  .rd_en(ddr_axi_rready),                  // input
  .empty(ddr_axi_fifo_empty),                  // output
  .almost_empty(),    // output
  .clk(axi_clk),                      // input
  .rst(axi_rst)                       // input
);
assign ddr_axi_rid[AXI_ID_M_LEN-1 : AXI_ID_LEN] = ddr_axi_ar_sid[AXI_ID_M_LEN-1 : AXI_ID_LEN];

reg ddr_axi_awvalid_ddr3;
always @(posedge axi_clk) begin
    if (axi_rst) begin
        ddr_axi_awvalid_ddr3 <= 1'b0;
    end 
    else if(ddr_axi_awvalid_ddr3 & ddr_axi_awready) begin
        ddr_axi_awvalid_ddr3 <= 1'b0;
    end
    else begin
        ddr_axi_awvalid_ddr3 <= ddr_axi_awvalid && (ddr_axi_awlen < wr_water_level);
    end
end


ddr3 #(
    .MEM_ROW_WIDTH              (MEM_ROW_WIDTH                ),
    .MEM_COLUMN_WIDTH           (MEM_COLUMN_WIDTH             ),
    .MEM_BANK_WIDTH             (MEM_BANK_WIDTH               ),
    .MEM_DQ_WIDTH               (MEM_DQ_WIDTH                 ),
    .MEM_DM_WIDTH               (MEM_DQS_WIDTH                ),
    .MEM_DQS_WIDTH              (MEM_DQS_WIDTH                ),
    .CTRL_ADDR_WIDTH            (CTRL_ADDR_WIDTH              )
  )
ddr3(
    .ref_clk                    (free_clk                     ),
    .resetn                     (button_rst_n                 ),

    .core_clk                   (core_clk                     ),
    .ddr_init_done              (ddr_init_done                ),

    .pll_lock                   (                             ),
    .phy_pll_lock               (                             ),
    .gpll_lock                  (                             ),
    .rst_gpll_lock              (                             ),
    .ddrphy_cpd_lock            (                             ),

    .axi_awaddr                 (ddr_axi_awaddr                ),
    .axi_awuser_ap              (ddr_axi_awuser_ap             ),//
    .axi_awuser_id              (ddr_axi_awuser_id             ),
    .axi_awlen                  (ddr_axi_awlen                 ),
    .axi_awready                (ddr_axi_awready               ),
    .axi_awvalid                (ddr_axi_awvalid_ddr3          ),

    .axi_wdata                  (ddr_axi_wdata_ddr3            ),
    .axi_wstrb                  (ddr_axi_wstrb_ddr3            ),
    .axi_wready                 (ddr_axi_wready_ddr3           ),
    .axi_wusero_id              (ddr_axi_wusero_id             ),
    .axi_wusero_last            (ddr_axi_wusero_last_ddr3      ),

    .axi_araddr                 (ddr_axi_araddr                ),
    .axi_aruser_ap              (ddr_axi_aruser_ap             ),//
    .axi_aruser_id              (ddr_axi_aruser_id             ),
    .axi_arlen                  (ddr_axi_arlen                 ),
    .axi_arready                (ddr_axi_arready               ),
    .axi_arvalid                (ddr_axi_arvalid & ddr_axi_fifo_empty ),

    .axi_rdata                  (ddr_axi_rdata_ddr3                 ),
    .axi_rid                    (ddr_axi_rid_ddr3                   ),
    .axi_rlast                  (ddr_axi_rlast_ddr3                 ),
    .axi_rvalid                 (ddr_axi_rvalid_ddr3                ),

    .apb_clk                    (1'b0                         ),
    .apb_rst_n                  (1'b0                         ),
    .apb_sel                    (1'b0                         ),
    .apb_enable                 (1'b0                         ),
    .apb_addr                   (8'd0                         ),
    .apb_write                  (1'b0                         ),
    .apb_ready                  (                             ),
    .apb_wdata                  (16'd0                        ),
    .apb_rdata                  (                             ),

    .mem_cs_n                   (mem_cs_n                     ),
    .mem_rst_n                  (mem_rst_n                    ),
    .mem_ck                     (mem_ck                       ),
    .mem_ck_n                   (mem_ck_n                     ),
    .mem_cke                    (mem_cke                      ),
    .mem_ras_n                  (mem_ras_n                    ),
    .mem_cas_n                  (mem_cas_n                    ),
    .mem_we_n                   (mem_we_n                     ),
    .mem_odt                    (mem_odt                      ),
    .mem_a                      (mem_a                        ),
    .mem_ba                     (mem_ba                       ),
    .mem_dqs                    (mem_dqs                      ),
    .mem_dqs_n                  (mem_dqs_n                    ),
    .mem_dq                     (mem_dq                       ),
    .mem_dm                     (mem_dm                       ),

    .dbg_gate_start             (1'b0                         ),
    .dbg_cpd_start              (1'b0                         ),
    .dbg_ddrphy_rst_n           (1'b1                         ),
    .dbg_gpll_scan_rst          (1'b0                         ),

    .samp_position_dyn_adj      (1'b0                         ),
    .init_samp_position_even    (16'd0                        ),
    .init_samp_position_odd     (16'd0                        ),

    .wrcal_position_dyn_adj     (1'b0                         ),
    .init_wrcal_position        (16'd0                        ),

    .force_read_clk_ctrl        (1'b0                         ),
    .init_slip_step             (8'd0                         ),
    .init_read_clk_ctrl         (6'd0                         ),

    .debug_calib_ctrl           (                             ),
    .dbg_dll_upd_state          (                             ),
    .dbg_slice_status           (                             ),
    .dbg_slice_state            (                             ),
    .debug_data                 (                             ),
    .debug_gpll_dps_phase       (                             ),

    .dbg_rst_dps_state          (                             ),
    .dbg_tran_err_rst_cnt       (                             ),
    .dbg_ddrphy_init_fail       (                             ),

    .debug_cpd_offset_adj       (1'b0                         ),
    .debug_cpd_offset_dir       (1'b0                         ),
    .debug_cpd_offset           (10'd0                        ),
    .debug_dps_cnt_dir0         (                             ),
    .debug_dps_cnt_dir1         (                             ),

    .ck_dly_en                  (1'b0                         ),
    .init_ck_dly_step           (8'd0                         ),
    .ck_dly_set_bin             (                             ),

    .align_error                (                             ),
    .debug_rst_state            (                             ),
    .debug_cpd_state            (                             )
  );

wire axi_clk;
wire axi_rst;
assign axi_clk = core_clk;
assign axi_rst = ~ddr_init_done;

/////////////////////////////////////// DDR3 B-Channel Bridge //////////////////////////////////////
reg  [AXI_ID_M_LEN-1 : AXI_ID_LEN]                  ddr_axi_aw_sid        ;//ddr_axi_awuser_id??3?
reg  [AXI_ID_M_LEN-1 : AXI_ID_LEN]                  ddr_axi_ar_sid        ;//ddr_axi_aruser_id??3?

// latch aw_sid on AW handshake
always @(posedge axi_clk) begin
    if (axi_rst) begin
        ddr_axi_aw_sid <= {(AXI_ID_M_LEN - AXI_ID_LEN){1'b0}};
    end 
    else if (ddr_axi_awvalid && ddr_axi_awready) begin
        ddr_axi_aw_sid <= ddr_axi_awuser_id[AXI_ID_M_LEN-1 : AXI_ID_LEN];
    end
end

// latch ar_sid on AR handshake
always @(posedge axi_clk) begin
    if (axi_rst) begin
        ddr_axi_ar_sid <= {(AXI_ID_M_LEN - AXI_ID_LEN){1'b0}};
    end 
    else if (ddr_axi_arvalid && ddr_axi_arready) begin
        ddr_axi_ar_sid <= ddr_axi_aruser_id[AXI_ID_M_LEN-1 : AXI_ID_LEN];
    end
end


reg                         ddr_axi_bvalid_int    ;
reg  [1:0]                  ddr_axi_bresp_int     ;
reg  [AXI_ID_M_LEN-1:0]     ddr_axi_bid_int       ;
always @(posedge axi_clk) begin
    if (axi_rst) begin
        ddr_axi_bvalid_int  <= 1'b0;
        ddr_axi_bresp_int   <= 2'b01;
        ddr_axi_bid_int <= {AXI_ID_M_LEN{1'b0}};
    end 
    else begin
        if (ddr_axi_wready_ddr3 && ddr_axi_wusero_last_ddr3) begin
            ddr_axi_bvalid_int <= 1'b1;
            ddr_axi_bresp_int  <= 2'b00;
            ddr_axi_bid_int <= {ddr_axi_aw_sid[AXI_ID_M_LEN-1 : AXI_ID_LEN], ddr_axi_wusero_id};
        end 
        else if (ddr_axi_bvalid && ddr_axi_bready) begin
            ddr_axi_bvalid_int <= 1'b0;
            ddr_axi_bresp_int  <= 2'b01;
            ddr_axi_bid_int <= {AXI_ID_M_LEN{1'b0}};
        end
    end
end

assign ddr_axi_bvalid = ddr_axi_bvalid_int;
assign ddr_axi_bresp  = ddr_axi_bresp_int;
assign ddr_axi_bid    = ddr_axi_bid_int;


/////////////////////////////     DDR3   ///////////////////////////////////////////////////
    wire       [AXI_ID_LEN-1:0]       pcie_axi_awid   ;
    wire       [31:0]                 pcie_axi_awaddr ;
    wire       [ 3:0]                 pcie_axi_awlen  ;
    wire       [ 2:0]                 pcie_axi_awsize ;
    wire       [ 1:0]                 pcie_axi_awburst;
    wire                              pcie_axi_awlock ;
    wire       [ 3:0]                 pcie_axi_awcache;
    wire       [ 2:0]                 pcie_axi_awprot ;
    wire       [ 3:0]                 pcie_axi_awqos  ;
    wire                              pcie_axi_awvalid;
    wire                              pcie_axi_awready;

    wire       [AXI_DATA_LEN-1:0]     pcie_axi_wdata  ;
    wire       [AXI_STRB_LEN-1:0]     pcie_axi_wstrb  ;
    wire                              pcie_axi_wlast  ;
    wire                              pcie_axi_wvalid ;
    wire                              pcie_axi_wready ;

    wire       [AXI_ID_LEN-1:0]       pcie_axi_bid    ;
    wire       [ 1:0]                 pcie_axi_bresp  ;
    wire                              pcie_axi_bvalid ;
    wire                              pcie_axi_bready ;

    wire       [AXI_ID_LEN-1:0]       pcie_axi_arid   ;
    wire       [31:0]                 pcie_axi_araddr ;
    wire       [ 3:0]                 pcie_axi_arlen  ;
    wire       [ 2:0]                 pcie_axi_arsize ;
    wire       [ 1:0]                 pcie_axi_arburst;
    wire                              pcie_axi_arlock ;
    wire       [ 3:0]                 pcie_axi_arcache;
    wire       [ 2:0]                 pcie_axi_arprot ;
    wire       [ 3:0]                 pcie_axi_arqos  ;
    wire                              pcie_axi_arvalid;
    wire                              pcie_axi_arready;

    wire       [AXI_ID_LEN-1:0]       pcie_axi_rid    ;
    wire       [AXI_DATA_LEN-1:0]     pcie_axi_rdata  ;
    wire       [ 1:0]                 pcie_axi_rresp  ;
    wire                              pcie_axi_rlast  ;
    wire                              pcie_axi_rvalid ;
    wire                              pcie_axi_rready ;

    wire                              pcie_clk        ;
    wire                              pcie_rst        ;

    wire [MSI_NUM-2 : 0]      msi_req       ;
    wire [MSI_NUM-2 : 0]      msi_grant     ;

    wire npu_msi_req, npu_msi_grant;

    assign msi_req = {1'd0, npu_msi_req, cam_irq};
    assign npu_msi_grant = msi_grant[2];

pcie_fifo #(
    .MSI_NUM(MSI_NUM)
)
pcie_fifo(    

    .button_rst_n(button_rst_n)    ,

    ////////////////// PCIE ////////////////
    .perst_n     (perst_n     )    ,
    .ref_clk_n   (ref_clk_n   )    ,      
    .ref_clk_p   (ref_clk_p   )    ,      
    .rxn         (rxn         )    ,
    .rxp         (rxp         )    ,
    .txn         (txn         )    ,
    .txp         (txp         )    ,
    .ref_led     (ref_led     )    ,
    .pclk_led    (pclk_led    )    ,
    // .smlh_link_up(smlh_link_up)    ,
    // .rdlh_link_up(rdlh_link_up)    ,

    .fifo_pcie_clk(pcie_clk   )    ,
    .fifo_pcie_rst(pcie_rst   )    ,

    .i_msi_req  (msi_req     )     ,
    .o_msi_grant(msi_grant   )     ,
    ///////////////// AXI FOR DDR3 //////////////////////////////
    .axi_clk(axi_clk),
    .axi_rst(axi_rst),

    .axi_awid   (pcie_axi_awid   )     ,
    .axi_awaddr (pcie_axi_awaddr )     ,
    .axi_awlen  (pcie_axi_awlen  )     ,
    .axi_awsize (pcie_axi_awsize )     ,
    .axi_awburst(pcie_axi_awburst)     ,
    .axi_awlock (pcie_axi_awlock )     ,
    .axi_awcache(pcie_axi_awcache)     ,
    .axi_awprot (pcie_axi_awprot )     ,
    .axi_awqos  (pcie_axi_awqos  )     ,
    .axi_awvalid(pcie_axi_awvalid)     ,
    .axi_awready(pcie_axi_awready)     ,
    
    .axi_wdata  (pcie_axi_wdata  )     ,
    .axi_wstrb  (pcie_axi_wstrb  )     ,
    .axi_wlast  (pcie_axi_wlast  )     ,
    .axi_wvalid (pcie_axi_wvalid )     ,
    .axi_wready (pcie_axi_wready )     ,
    
    .axi_bid    (pcie_axi_bid    )     ,
    .axi_bresp  (pcie_axi_bresp  )     ,
    .axi_bvalid (pcie_axi_bvalid )     ,
    .axi_bready (pcie_axi_bready )     ,
    
    .axi_arid   (pcie_axi_arid   )     ,
    .axi_araddr (pcie_axi_araddr )     ,
    .axi_arlen  (pcie_axi_arlen  )     ,
    .axi_arsize (pcie_axi_arsize )     ,
    .axi_arburst(pcie_axi_arburst)     ,
    .axi_arlock (pcie_axi_arlock )     ,
    .axi_arcache(pcie_axi_arcache)     ,
    .axi_arprot (pcie_axi_arprot )     ,
    .axi_arqos  (pcie_axi_arqos  )     ,
    .axi_arvalid(pcie_axi_arvalid)     ,
    .axi_arready(pcie_axi_arready)     ,
    
    .axi_rid    (pcie_axi_rid    )     ,
    .axi_rdata  (pcie_axi_rdata  )     ,
    .axi_rresp  (pcie_axi_rresp  )     ,
    .axi_rlast  (pcie_axi_rlast  )     ,
    .axi_rvalid (pcie_axi_rvalid )     ,
    .axi_rready (pcie_axi_rready )           
);


/////////////////////////////////   CMD    ////////////////////////////////////////////////
ov5640_clk ov5640_clk(
  .clkout2(clk_10m),
  .clkout1(clk_150m),      // output 150M
  .clkout0(clk_50m),      // output 50M

  .lock(locked),          // output
  .clkin1(free_clk)         // input
);

///////////////////////////// AXI-Lite wires for ovreg ///////////////////////////
wire [31:0]                 ovreg_axil_awaddr   ;
wire                        ovreg_axil_awvalid  ;
wire                        ovreg_axil_awready  ;
wire [31:0]                 ovreg_axil_wdata    ;
wire [3:0]                  ovreg_axil_wstrb    ;
wire                        ovreg_axil_wvalid   ;
wire                        ovreg_axil_wready   ;
wire [1:0]                  ovreg_axil_bresp    ;
wire                        ovreg_axil_bvalid   ;
wire                        ovreg_axil_bready   ;
wire [31:0]                 ovreg_axil_araddr   ;
wire                        ovreg_axil_arvalid  ;
wire                        ovreg_axil_arready  ;
wire [31:0]                 ovreg_axil_rdata    ;
wire [1:0]                  ovreg_axil_rresp    ;
wire                        ovreg_axil_rvalid   ;
wire                        ovreg_axil_rready   ;

///////////////////////////// ovreg_axi signals ///////////////////////////
wire [AXI_ID_M_LEN-1:0]     ovreg_axi_awid     ;
wire [31:0]                 ovreg_axi_awaddr   ;
wire [3:0]                  ovreg_axi_awlen    ;
wire [2:0]                  ovreg_axi_awsize   ;
wire [1:0]                  ovreg_axi_awburst  ;
wire                        ovreg_axi_awlock   ;
wire [3:0]                  ovreg_axi_awcache  ;
wire [2:0]                  ovreg_axi_awprot   ;
wire [3:0]                  ovreg_axi_awqos    ;
wire [3:0]                  ovreg_axi_awregion ;
wire                        ovreg_axi_awvalid  ;
wire                        ovreg_axi_awready  ;

wire [AXI_DATA_LEN-1:0]     ovreg_axi_wdata     ;
wire [AXI_STRB_LEN-1:0]     ovreg_axi_wstrb     ;
wire                        ovreg_axi_wlast     ;
wire                        ovreg_axi_wvalid    ;
wire                        ovreg_axi_wready    ;

wire [AXI_ID_M_LEN-1:0]     ovreg_axi_bid       ;
wire [1:0]                  ovreg_axi_bresp     ;
wire                        ovreg_axi_bvalid    ;
wire                        ovreg_axi_bready    ;

wire [AXI_ID_M_LEN-1:0]     ovreg_axi_arid     ;
wire [31:0]                 ovreg_axi_araddr   ;
wire [3:0]                  ovreg_axi_arlen    ;
wire [2:0]                  ovreg_axi_arsize   ;
wire [1:0]                  ovreg_axi_arburst  ;
wire                        ovreg_axi_arlock   ;
wire [3:0]                  ovreg_axi_arcache  ;
wire [2:0]                  ovreg_axi_arprot   ;
wire [3:0]                  ovreg_axi_arqos    ;
wire [3:0]                  ovreg_axi_arregion ;
wire                        ovreg_axi_arvalid  ;
wire                        ovreg_axi_arready  ;

wire [AXI_DATA_LEN-1:0]     ovreg_axi_rdata    ;
wire [AXI_ID_M_LEN-1:0]     ovreg_axi_rid      ;
wire [1:0]                  ovreg_axi_rresp    ;
wire                        ovreg_axi_rlast    ;
wire                        ovreg_axi_rvalid   ;
wire                        ovreg_axi_rready   ;


axi_to_axi_lite #(
    .AXI_ID_LEN(AXI_ID_M_LEN)
)
axi_to_axi_lite(
    .axi_clk(axi_clk),
    .axi_rst(axi_rst),
    // ==========================================
    // ??? AXI Slave  (128-bit)
    // ==========================================
    .s_axi_awid    (ovreg_axi_awid    ),
    .s_axi_awaddr  (ovreg_axi_awaddr  ),
    .s_axi_awlen   (ovreg_axi_awlen   ),
    .s_axi_awsize  (ovreg_axi_awsize  ),
    .s_axi_awburst (ovreg_axi_awburst ),
    .s_axi_awlock  (ovreg_axi_awlock  ),
    .s_axi_awcache (ovreg_axi_awcache ),
    .s_axi_awprot  (ovreg_axi_awprot  ),
    .s_axi_awqos   (ovreg_axi_awqos   ),
    .s_axi_awregion(ovreg_axi_awregion),
    .s_axi_awvalid (ovreg_axi_awvalid ),
    .s_axi_awready (ovreg_axi_awready ),

    .s_axi_wdata   (ovreg_axi_wdata  ),
    .s_axi_wstrb   (ovreg_axi_wstrb  ),
    .s_axi_wlast   (ovreg_axi_wlast  ),
    .s_axi_wvalid  (ovreg_axi_wvalid ),
    .s_axi_wready  (ovreg_axi_wready ),

    .s_axi_bid     (ovreg_axi_bid    ),
    .s_axi_bresp   (ovreg_axi_bresp  ),
    .s_axi_bvalid  (ovreg_axi_bvalid ),
    .s_axi_bready  (ovreg_axi_bready ),

    .s_axi_arid    (ovreg_axi_arid   ),
    .s_axi_araddr  (ovreg_axi_araddr ),
    .s_axi_arlen   (ovreg_axi_arlen  ),
    .s_axi_arsize  (ovreg_axi_arsize ),
    .s_axi_arburst (ovreg_axi_arburst),
    .s_axi_arlock  (ovreg_axi_arlock ),
    .s_axi_arcache (ovreg_axi_arcache),
    .s_axi_arprot  (ovreg_axi_arprot ),
    .s_axi_arqos   (ovreg_axi_arqos  ),
    .s_axi_arregion(ovreg_axi_arregion),
    .s_axi_arvalid (ovreg_axi_arvalid),
    .s_axi_arready (ovreg_axi_arready),

    .s_axi_rid     (ovreg_axi_rid    ),
    .s_axi_rdata   (ovreg_axi_rdata  ),
    .s_axi_rresp   (ovreg_axi_rresp  ),
    .s_axi_rlast   (ovreg_axi_rlast  ),
    .s_axi_rvalid  (ovreg_axi_rvalid ),
    .s_axi_rready  (ovreg_axi_rready ),


    // ==========================================
    // AXI-Lite Master  (32-bit)
    // ==========================================
    .m_axil_awaddr (ovreg_axil_awaddr ),
    .m_axil_awvalid(ovreg_axil_awvalid),
    .m_axil_awready(ovreg_axil_awready),

    .m_axil_wdata  (ovreg_axil_wdata  ),
    .m_axil_wstrb  (ovreg_axil_wstrb  ),
    .m_axil_wvalid (ovreg_axil_wvalid ),
    .m_axil_wready (ovreg_axil_wready ),

    .m_axil_bresp  (ovreg_axil_bresp  ),
    .m_axil_bvalid (ovreg_axil_bvalid ),
    .m_axil_bready (ovreg_axil_bready ),

    .m_axil_araddr (ovreg_axil_araddr ),
    .m_axil_arvalid(ovreg_axil_arvalid),
    .m_axil_arready(ovreg_axil_arready),

    .m_axil_rdata  (ovreg_axil_rdata  ),
    .m_axil_rresp  (ovreg_axil_rresp  ),
    .m_axil_rvalid (ovreg_axil_rvalid ),
    .m_axil_rready (ovreg_axil_rready )
);


wire [31 : 0]               cam_cmd_addr    /*synthesis PAP_MARK_DEBUG="1"*/;
wire [31 : 0]               cam_cmd_len     /*synthesis PAP_MARK_DEBUG="1"*/;
wire                        cam_cmd_valid   /*synthesis PAP_MARK_DEBUG="1"*/;
wire                        cam_cmd_ready   /*synthesis PAP_MARK_DEBUG="1"*/;

wire [AXI_DATA_LEN-1 : 0]   cam_s_data      /*synthesis PAP_MARK_DEBUG="1"*/;
wire                        cam_s_data_valid/*synthesis PAP_MARK_DEBUG="1"*/;
wire                        cam_s_data_last /*synthesis PAP_MARK_DEBUG="1"*/;
wire                        cam_s_data_ready/*synthesis PAP_MARK_DEBUG="1"*/;

wire [1 : 0]                cam_irq;     

`ifdef USE_OV5640
ov5640_top ov5640_top(
    .clk_50m       (clk_50m)        ,
    .clk_50m_rst_n (locked & button_rst_n)        ,
        
    .cam_pclk (cmos1_pclk )             ,  
    .cam_vsync(cmos1_vsync)             ,  
    .cam_href (cmos1_href )             ,  
    .cam_data (cmos1_data )             ,  
    .cam_rst_n(cmos1_rst_n)             ,  
    // .cam_pwdn (cmos1_pwdn )             ,  
    .cam_scl  (cmos1_scl  )             ,  
    .cam_sda  (cmos1_sda  )             ,  


    
    .s_axi_awvalid(ovreg_axil_awvalid)        ,
    .s_axi_awready(ovreg_axil_awready)        ,
    .s_axi_awaddr (ovreg_axil_awaddr )        ,

    .s_axi_wvalid (ovreg_axil_wvalid)         ,
    .s_axi_wready (ovreg_axil_wready)         ,
    .s_axi_wdata  (ovreg_axil_wdata )         ,
    .s_axi_wstrb  (ovreg_axil_wstrb )         ,

    .s_axi_bvalid (ovreg_axil_bvalid)         ,
    .s_axi_bready (ovreg_axil_bready)         ,
    .s_axi_bresp  (ovreg_axil_bresp )         ,

    .s_axi_arvalid(ovreg_axil_arvalid)        ,
    .s_axi_arready(ovreg_axil_arready)        ,
    .s_axi_araddr (ovreg_axil_araddr )        ,

    .s_axi_rvalid (ovreg_axil_rvalid )        ,
    .s_axi_rready (ovreg_axil_rready )        ,
    .s_axi_rdata  (ovreg_axil_rdata  )        ,
    .s_axi_rresp  (ovreg_axil_rresp  )        ,



    //AXI_stream
    .video_clk(axi_clk)      ,
    .video_rst(axi_rst)      ,
    .cam_cmd_addr (cam_cmd_addr )  ,
    .cam_cmd_len  (cam_cmd_len  )  ,
    .cam_cmd_valid(cam_cmd_valid)  ,
    .cam_cmd_ready(cam_cmd_ready)  ,

    .cam_s_data      (cam_s_data      ),
    .cam_s_data_valid(cam_s_data_valid),
    .cam_s_data_last (cam_s_data_last ),
    .cam_s_data_ready(cam_s_data_ready),

    //DMA?
    .xdma_clk (pcie_clk) ,
    .xdma_irq (cam_irq ) 

);
`elsif USE_HDMI
hdmi_top hdmi_top(
    .clk_10m(clk_10m)               ,
    .clk_10m_rst_n(locked & button_rst_n)         ,

    //HDMI接口

    //ms72XX
    .rstn_out(rstn_out),

    // FMC I2C 
    .iic_scl(iic_scl),
    .iic_sda(iic_sda), 

    // .iic_tx_scl(iic_tx_scl),
    // .iic_tx_sda(iic_tx_sda), 

    //HDMI IN
    .pixclk_in(pixclk_in),                            
    .vs_in(vs_in) , 
    .hs_in(hs_in) , 
    .de_in(de_in) ,
    .r_in (r_in ) , 
    .g_in (g_in ) , 
    .b_in (b_in ) ,  




    //摄像头控制寄存器
    .s_axi_awvalid(ovreg_axil_awvalid)        ,
    .s_axi_awready(ovreg_axil_awready)        ,
    .s_axi_awaddr (ovreg_axil_awaddr )        ,

    .s_axi_wvalid (ovreg_axil_wvalid)         ,
    .s_axi_wready (ovreg_axil_wready)         ,
    .s_axi_wdata  (ovreg_axil_wdata )         ,
    .s_axi_wstrb  (ovreg_axil_wstrb )         ,

    .s_axi_bvalid (ovreg_axil_bvalid)         ,
    .s_axi_bready (ovreg_axil_bready)         ,
    .s_axi_bresp  (ovreg_axil_bresp )         ,

    .s_axi_arvalid(ovreg_axil_arvalid)        ,
    .s_axi_arready(ovreg_axil_arready)        ,
    .s_axi_araddr (ovreg_axil_araddr )        ,

    .s_axi_rvalid (ovreg_axil_rvalid )        ,
    .s_axi_rready (ovreg_axil_rready )        ,
    .s_axi_rdata  (ovreg_axil_rdata  )        ,
    .s_axi_rresp  (ovreg_axil_rresp  )        ,



    //AXI_stream
    .video_clk(axi_clk)      ,
    .video_rst(axi_rst)      ,
    .cam_cmd_addr (cam_cmd_addr )  ,
    .cam_cmd_len  (cam_cmd_len  )  ,
    .cam_cmd_valid(cam_cmd_valid)  ,
    .cam_cmd_ready(cam_cmd_ready)  ,

    .cam_s_data      (cam_s_data      ),
    .cam_s_data_valid(cam_s_data_valid),
    .cam_s_data_last (cam_s_data_last ),
    .cam_s_data_ready(cam_s_data_ready),

    //DMA?
    .xdma_clk (pcie_clk) ,
    .xdma_irq (cam_irq ) 

);
`endif

wire [AXI_ID_LEN-1:0]   ov5640_axi_awid    /*synthesis PAP_MARK_DEBUG="1"*/;
wire [31:0]             ov5640_axi_awaddr  /*synthesis PAP_MARK_DEBUG="1"*/;
wire [3:0]              ov5640_axi_awlen   /*synthesis PAP_MARK_DEBUG="1"*/;
wire [2:0]              ov5640_axi_awsize  /*synthesis PAP_MARK_DEBUG="1"*/;
wire [1:0]              ov5640_axi_awburst /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    ov5640_axi_awlock  /*synthesis PAP_MARK_DEBUG="1"*/;
wire [3:0]              ov5640_axi_awcache /*synthesis PAP_MARK_DEBUG="1"*/;
wire [2:0]              ov5640_axi_awprot  /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    ov5640_axi_awvalid /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    ov5640_axi_awready /*synthesis PAP_MARK_DEBUG="1"*/;
wire [AXI_DATA_LEN-1:0] ov5640_axi_wdata   /*synthesis PAP_MARK_DEBUG="1"*/;
wire [AXI_STRB_LEN-1:0] ov5640_axi_wstrb   /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    ov5640_axi_wlast   /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    ov5640_axi_wvalid  /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    ov5640_axi_wready  /*synthesis PAP_MARK_DEBUG="1"*/;
wire [AXI_ID_LEN-1:0]   ov5640_axi_bid     /*synthesis PAP_MARK_DEBUG="1"*/;
wire [1:0]              ov5640_axi_bresp   /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    ov5640_axi_bvalid  /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    ov5640_axi_bready  /*synthesis PAP_MARK_DEBUG="1"*/;

axi_dma_write #(
	.BURST_LEN  (BURST_LEN)   ,
	.ID_WIDTH   (AXI_ID_LEN)  ,
	.DATA_WIDTH (AXI_DATA_LEN)
)
ov5640_axi_dma_write(
	.clk(axi_clk)                   ,
	.rst(axi_rst)                   ,

	.cmd_valid (cam_cmd_valid)      ,
	.cmd_addr  (cam_cmd_addr )      ,
	.cmd_len   (cam_cmd_len  )      ,
	.cmd_id    (4'b0001)            ,
	.cmd_ready (cam_cmd_ready)      ,

	.data_in       (cam_s_data          ),
	.data_in_keep  ({AXI_STRB_LEN{1'b1}}),
	.data_in_valid (cam_s_data_valid    ),
	.data_in_last  (),//(cam_s_data_last     ),
	.data_in_ready (cam_s_data_ready    ),

	.m_axi_awid    (ov5640_axi_awid    ),
	.m_axi_awaddr  (ov5640_axi_awaddr  ),
	.m_axi_awlen   (ov5640_axi_awlen   ),
	.m_axi_awsize  (ov5640_axi_awsize  ),
	.m_axi_awburst (ov5640_axi_awburst ),
	.m_axi_awlock  (ov5640_axi_awlock  ),
	.m_axi_awcache (ov5640_axi_awcache ),
	.m_axi_awprot  (ov5640_axi_awprot  ),
	.m_axi_awvalid (ov5640_axi_awvalid ),
	.m_axi_awready (ov5640_axi_awready ),
	.m_axi_wdata   (ov5640_axi_wdata   ),
	.m_axi_wstrb   (ov5640_axi_wstrb   ),
	.m_axi_wlast   (ov5640_axi_wlast   ),
	.m_axi_wvalid  (ov5640_axi_wvalid  ),
	.m_axi_wready  (ov5640_axi_wready  ),
	.m_axi_bid     (ov5640_axi_bid     ),
	.m_axi_bresp   (ov5640_axi_bresp   ),
	.m_axi_bvalid  (ov5640_axi_bvalid  ),
	.m_axi_bready  (ov5640_axi_bready  )
);

/////////////////////////////////////////////////////////////////////////////////////////////
wire [AXI_ID_LEN-1:0]   npu_reg_axi_awid    /*synthesis PAP_MARK_DEBUG="1"*/;
wire [31:0]             npu_reg_axi_awaddr  /*synthesis PAP_MARK_DEBUG="1"*/;
wire [3:0]              npu_reg_axi_awlen   /*synthesis PAP_MARK_DEBUG="1"*/;
wire [2:0]              npu_reg_axi_awsize  /*synthesis PAP_MARK_DEBUG="1"*/;
wire [1:0]              npu_reg_axi_awburst /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    npu_reg_axi_awlock  /*synthesis PAP_MARK_DEBUG="1"*/;
wire [3:0]              npu_reg_axi_awcache /*synthesis PAP_MARK_DEBUG="1"*/;
wire [2:0]              npu_reg_axi_awprot  /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    npu_reg_axi_awvalid /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    npu_reg_axi_awready /*synthesis PAP_MARK_DEBUG="1"*/;
wire [AXI_DATA_LEN-1:0] npu_reg_axi_wdata   /*synthesis PAP_MARK_DEBUG="1"*/;
wire [AXI_STRB_LEN-1:0] npu_reg_axi_wstrb   /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    npu_reg_axi_wlast   /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    npu_reg_axi_wvalid  /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    npu_reg_axi_wready  /*synthesis PAP_MARK_DEBUG="1"*/;
wire [AXI_ID_LEN-1:0]   npu_reg_axi_bid     /*synthesis PAP_MARK_DEBUG="1"*/;
wire [1:0]              npu_reg_axi_bresp   /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    npu_reg_axi_bvalid  /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    npu_reg_axi_bready  /*synthesis PAP_MARK_DEBUG="1"*/;

wire                    npu_req        ;
wire                    npu_req_receive;





    //CMD_S2MM CMDMM2S接口
    //in的输入
    wire [AXI_DATA_LEN-1 : 0]    cdc_s_data_0      ;
    wire                         cdc_s_valid_0     ;
    wire                         cdc_s_last_0      ;
    wire                         cdc_s_ready_0     ; 

    wire [AXI_ADDR_WIDTH-1 : 0]  cdc_s_cmd_addr_0  ;
    wire [AXI_ADDR_WIDTH-1 : 0]  cdc_s_cmd_len_0   ;
    wire                         cdc_s_cmd_valid_0 ;
    wire                         cdc_s_cmd_ready_0 ;
    //1
    wire [AXI_DATA_LEN-1 : 0]    cdc_s_data_1      ;
    wire                         cdc_s_valid_1     ;
    wire                         cdc_s_last_1      ;
    wire                         cdc_s_ready_1     ;

    wire [AXI_ADDR_WIDTH-1 : 0]  cdc_s_cmd_addr_1  ;
    wire [AXI_ADDR_WIDTH-1 : 0]  cdc_s_cmd_len_1   ;
    wire                         cdc_s_cmd_valid_1 ;
    wire                         cdc_s_cmd_ready_1 ;

    //2
    wire [AXI_DATA_LEN-1 : 0]    cdc_s_data_2      ;
    wire                         cdc_s_valid_2     ;
    wire                         cdc_s_last_2      ;
    wire                         cdc_s_ready_2     ;

    wire [AXI_ADDR_WIDTH-1 : 0]  cdc_s_cmd_addr_2  ;
    wire [AXI_ADDR_WIDTH-1 : 0]  cdc_s_cmd_len_2   ;
    wire                         cdc_s_cmd_valid_2 ;
    wire                         cdc_s_cmd_ready_2 ;

    //3
    wire [AXI_DATA_LEN-1 : 0]    cdc_s_data_3      ;
    wire                         cdc_s_valid_3     ;
    wire                         cdc_s_last_3      ;
    wire                         cdc_s_ready_3     ; 

    wire [AXI_ADDR_WIDTH-1 : 0]  cdc_s_cmd_addr_3  ;
    wire [AXI_ADDR_WIDTH-1 : 0]  cdc_s_cmd_len_3   ;
    wire                         cdc_s_cmd_valid_3 ;
    wire                         cdc_s_cmd_ready_3 ;

    //4
    wire [AXI_DATA_LEN-1 : 0]    cdc_s_data_4      ;
    wire                         cdc_s_valid_4     ;
    wire                         cdc_s_last_4      ;
    wire                         cdc_s_ready_4     ; 

    wire [AXI_ADDR_WIDTH-1 : 0]  cdc_s_cmd_addr_4  ;
    wire [AXI_ADDR_WIDTH-1 : 0]  cdc_s_cmd_len_4   ;
    wire                         cdc_s_cmd_valid_4 ;
    wire                         cdc_s_cmd_ready_4 ;

    //out的输出
    wire [AXI_DATA_LEN-1 : 0]    cdc_out_m_data      ;
    wire                         cdc_out_m_last      ;
    wire                         cdc_out_m_valid     ;
    wire                         cdc_out_m_ready     ; 

    wire [AXI_ADDR_WIDTH-1 : 0]  cdc_out_m_cmd_addr  ;
    wire [AXI_ADDR_WIDTH-1 : 0]  cdc_out_m_cmd_len   ;
    wire                         cdc_out_m_cmd_valid ;
    wire                         cdc_out_m_cmd_ready ;
    


npu_cdc_top npu_cdc_top(

    .npu_clk(npu_clk),
    .npu_rst(npu_rst),
 
    .axi_clk(axi_clk),
    .axi_rst(axi_rst),
    ///////////// NPU_CTL ///////////////////////////////////
    // AXI 写地址通道 (AW)
    .s_axi_awaddr (npu_reg_axi_awaddr ),
    .s_axi_awlen  (npu_reg_axi_awlen  ),    // 突发长度，支持 AXI4
    .s_axi_awsize (npu_reg_axi_awsize ),   // 突发大小
    .s_axi_awburst(npu_reg_axi_awburst),  // 突发类型
    .s_axi_awvalid(npu_reg_axi_awvalid),
    .s_axi_awready(npu_reg_axi_awready),
    // AXI 写数据通道 (W)
    .s_axi_wdata (npu_reg_axi_wdata ),
    .s_axi_wstrb (npu_reg_axi_wstrb ),    // 字节掩码
    .s_axi_wlast (npu_reg_axi_wlast ),    // 突发的最后一个数据标志
    .s_axi_wvalid(npu_reg_axi_wvalid),
    .s_axi_wready(npu_reg_axi_wready),
    // AXI 写响应通道 (B)
    .s_axi_bresp (npu_reg_axi_bresp ), 
    .s_axi_bvalid(npu_reg_axi_bvalid),
    .s_axi_bready(npu_reg_axi_bready),

    .npu_req        (npu_req        ) , 
    .npu_req_receive(npu_req_receive) ,   

    ///////////// NPU_TOP ///////////////////////////////////
    //CMD_S2MM CMDMM2S接口
    // in的输入 0
    .cdc_s_data_0       ( cdc_s_data_0        ),
    .cdc_s_valid_0      ( cdc_s_valid_0       ),
    .cdc_s_last_0       ( cdc_s_last_0        ),
    .cdc_s_ready_0      ( cdc_s_ready_0       ),
    .cdc_s_cmd_addr_0   ( cdc_s_cmd_addr_0    ),
    .cdc_s_cmd_len_0    ( cdc_s_cmd_len_0     ),
    .cdc_s_cmd_valid_0  ( cdc_s_cmd_valid_0   ),
    .cdc_s_cmd_ready_0  ( cdc_s_cmd_ready_0   ),

    // in的输入 1
    .cdc_s_data_1       ( cdc_s_data_1        ),
    .cdc_s_valid_1      ( cdc_s_valid_1       ),
    .cdc_s_last_1       ( cdc_s_last_1        ),
    .cdc_s_ready_1      ( cdc_s_ready_1       ),
    .cdc_s_cmd_addr_1   ( cdc_s_cmd_addr_1    ),
    .cdc_s_cmd_len_1    ( cdc_s_cmd_len_1     ),
    .cdc_s_cmd_valid_1  ( cdc_s_cmd_valid_1   ),
    .cdc_s_cmd_ready_1  ( cdc_s_cmd_ready_1   ),

    // in的输入 2
    .cdc_s_data_2       ( cdc_s_data_2        ),
    .cdc_s_valid_2      ( cdc_s_valid_2       ),
    .cdc_s_last_2       ( cdc_s_last_2        ),
    .cdc_s_ready_2      ( cdc_s_ready_2       ),
    .cdc_s_cmd_addr_2   ( cdc_s_cmd_addr_2    ),
    .cdc_s_cmd_len_2    ( cdc_s_cmd_len_2     ),
    .cdc_s_cmd_valid_2  ( cdc_s_cmd_valid_2   ),
    .cdc_s_cmd_ready_2  ( cdc_s_cmd_ready_2   ),

    // in的输入 3
    .cdc_s_data_3       ( cdc_s_data_3        ),
    .cdc_s_valid_3      ( cdc_s_valid_3       ),
    .cdc_s_last_3       ( cdc_s_last_3        ),
    .cdc_s_ready_3      ( cdc_s_ready_3       ),
    .cdc_s_cmd_addr_3   ( cdc_s_cmd_addr_3    ),
    .cdc_s_cmd_len_3    ( cdc_s_cmd_len_3     ),
    .cdc_s_cmd_valid_3  ( cdc_s_cmd_valid_3   ),
    .cdc_s_cmd_ready_3  ( cdc_s_cmd_ready_3   ),

    // in的输入 4
    .cdc_s_data_4       ( cdc_s_data_4        ),
    .cdc_s_valid_4      ( cdc_s_valid_4       ),
    .cdc_s_last_4       ( cdc_s_last_4        ),
    .cdc_s_ready_4      ( cdc_s_ready_4       ),
    .cdc_s_cmd_addr_4   ( cdc_s_cmd_addr_4    ),
    .cdc_s_cmd_len_4    ( cdc_s_cmd_len_4     ),
    .cdc_s_cmd_valid_4  ( cdc_s_cmd_valid_4   ),
    .cdc_s_cmd_ready_4  ( cdc_s_cmd_ready_4   ),

    // out的输出
    .cdc_out_m_data       ( cdc_out_m_data        ),
    .cdc_out_m_last       ( cdc_out_m_last        ),
    .cdc_out_m_valid      ( cdc_out_m_valid       ),
    .cdc_out_m_ready      ( cdc_out_m_ready       ),
    .cdc_out_m_cmd_addr   ( cdc_out_m_cmd_addr    ),
    .cdc_out_m_cmd_len    ( cdc_out_m_cmd_len     ),
    .cdc_out_m_cmd_valid  ( cdc_out_m_cmd_valid   ),
    .cdc_out_m_cmd_ready  ( cdc_out_m_cmd_ready   )

);


// ips2l_rst_sync_v1_3 #(
//     .DATA_WIDTH (1),
//     .DFT_VALUE  (1'b0)
// ) 
// npu_req_cdc (
//     .clk        (pcie_clk),         // 目标时钟：慢时钟
//     .rst_n      (!pcie_rst),
//     .sig_async  (npu_req),          // 来源：NPU拉高的请求
//     .sig_synced (npu_msi_req)   // 结果：安全进入 PCIe 域
// );


// ips2l_rst_sync_v1_3 #(
//     .DATA_WIDTH (1),
//     .DFT_VALUE  (1'b0)
// ) 
// npu_grant_cdc (
//     .clk        (npu_clk),         // 目标时钟：慢时钟
//     .rst_n      (!npu_rst),
//     .sig_async  (npu_msi_grant),          // 来源：NPU拉高的请求
//     .sig_synced (npu_req_receive)   // 结果：安全进入 PCIe 域
// );




    wire [AXI_ID_LEN-1:0]   npu_out_axi_awid    /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [31:0]             npu_out_axi_awaddr  /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [3:0]              npu_out_axi_awlen   /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [2:0]              npu_out_axi_awsize  /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [1:0]              npu_out_axi_awburst /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                    npu_out_axi_awlock  /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [3:0]              npu_out_axi_awcache /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [2:0]              npu_out_axi_awprot  /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                    npu_out_axi_awvalid /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                    npu_out_axi_awready /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [AXI_DATA_LEN-1:0] npu_out_axi_wdata   /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [AXI_STRB_LEN-1:0] npu_out_axi_wstrb   /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                    npu_out_axi_wlast   /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                    npu_out_axi_wvalid  /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                    npu_out_axi_wready  /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [AXI_ID_LEN-1:0]   npu_out_axi_bid     /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [1:0]              npu_out_axi_bresp   /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                    npu_out_axi_bvalid  /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                    npu_out_axi_bready  /*synthesis PAP_MARK_DEBUG="1"*/;


    wire    [AXI_ID_LEN-1:0]    npu_s0_axi_arid    ;
    wire    [31:0]              npu_s0_axi_araddr  ;
    wire    [3:0]               npu_s0_axi_arlen   ;
    wire    [2:0]               npu_s0_axi_arsize  ;
    wire    [1:0]               npu_s0_axi_arburst ;
    wire                        npu_s0_axi_arlock  ;
    wire    [3:0]               npu_s0_axi_arcache ;
    wire    [2:0]               npu_s0_axi_arprot  ;
    wire                        npu_s0_axi_arvalid ;
    wire                        npu_s0_axi_arready ;
    wire    [AXI_ID_LEN-1:0]    npu_s0_axi_rid     ;
    wire    [AXI_DATA_LEN-1:0]  npu_s0_axi_rdata   ;
    wire    [1:0]               npu_s0_axi_rresp   ;
    wire                        npu_s0_axi_rlast   ;
    wire                        npu_s0_axi_rvalid  ;
    wire                        npu_s0_axi_rready  ;

    axi_dma #(
        .BURST_LEN  (BURST_LEN)   ,
	    .ID_WIDTH   (AXI_ID_LEN)  ,
	    .DATA_WIDTH (AXI_DATA_LEN)
    )
    npu_s0_out_axi_dma(
    	.clk(axi_clk)                   ,
	    .rst(axi_rst)                   ,
 
  
        .write_cmd_valid(cdc_out_m_cmd_valid)            ,
        .write_cmd_ready(cdc_out_m_cmd_ready)            ,
        .write_cmd_addr (cdc_out_m_cmd_addr )            ,
        .write_cmd_len  (cdc_out_m_cmd_len  )            ,
        .write_cmd_id   (4'b0010            )            ,

        .data_in        (cdc_out_m_data      )            ,
        .data_in_keep   ({AXI_STRB_LEN{1'b1}})            ,
        .data_in_valid  (cdc_out_m_valid     )            ,
        .data_in_last   (cdc_out_m_last      )            ,
        .data_in_ready  (cdc_out_m_ready     )            ,	

        //trans data in
        .read_cmd_valid (cdc_s_cmd_valid_0   )            ,
        .read_cmd_addr  (cdc_s_cmd_addr_0    )            ,
        .read_cmd_len   (cdc_s_cmd_len_0     )            ,
        .read_cmd_id    (4'b0010             )            ,
        .read_cmd_ready (cdc_s_cmd_ready_0   )            ,

        .data_out       (cdc_s_data_0        )            ,
        .data_out_valid (cdc_s_valid_0       )            ,
        .data_out_last  (cdc_s_last_0        )            ,
        .data_out_ready (cdc_s_ready_0       )            ,


        .m_axi_awid   (npu_out_axi_awid   ) ,
        .m_axi_awaddr (npu_out_axi_awaddr ) ,
        .m_axi_awlen  (npu_out_axi_awlen  ) ,
        .m_axi_awsize (npu_out_axi_awsize ) ,
        .m_axi_awburst(npu_out_axi_awburst) ,
        .m_axi_awlock (npu_out_axi_awlock ) ,
        .m_axi_awcache(npu_out_axi_awcache) ,
        .m_axi_awprot (npu_out_axi_awprot ) ,
        .m_axi_awvalid(npu_out_axi_awvalid) ,
        .m_axi_awready(npu_out_axi_awready) ,
        .m_axi_wdata  (npu_out_axi_wdata  ) ,
        .m_axi_wstrb  (npu_out_axi_wstrb  ) ,
        .m_axi_wlast  (npu_out_axi_wlast  ) ,
        .m_axi_wvalid (npu_out_axi_wvalid ) ,
        .m_axi_wready (npu_out_axi_wready ) ,
        .m_axi_bid    (npu_out_axi_bid    ) ,
        .m_axi_bresp  (npu_out_axi_bresp  ) ,
        .m_axi_bvalid (npu_out_axi_bvalid ) ,
        .m_axi_bready (npu_out_axi_bready ) ,	

        .m_axi_arid   (npu_s0_axi_arid    ) ,
        .m_axi_araddr (npu_s0_axi_araddr  ) ,
        .m_axi_arlen  (npu_s0_axi_arlen   ) ,
        .m_axi_arsize (npu_s0_axi_arsize  ) ,
        .m_axi_arburst(npu_s0_axi_arburst ) ,
        .m_axi_arlock (npu_s0_axi_arlock  ) ,
        .m_axi_arcache(npu_s0_axi_arcache ) ,
        .m_axi_arprot (npu_s0_axi_arprot  ) ,
        .m_axi_arvalid(npu_s0_axi_arvalid ) ,
        .m_axi_arready(npu_s0_axi_arready ) ,
        .m_axi_rid    (npu_s0_axi_rid     ) ,
        .m_axi_rdata  (npu_s0_axi_rdata   ) ,
        .m_axi_rresp  (npu_s0_axi_rresp   ) ,
        .m_axi_rlast  (npu_s0_axi_rlast   ) ,
        .m_axi_rvalid (npu_s0_axi_rvalid  ) ,
        .m_axi_rready (npu_s0_axi_rready  )  
    );

    wire    [AXI_ID_LEN-1:0]    npu_s1_axi_arid    ;
    wire    [31:0]              npu_s1_axi_araddr  ;
    wire    [3:0]               npu_s1_axi_arlen   ;
    wire    [2:0]               npu_s1_axi_arsize  ;
    wire    [1:0]               npu_s1_axi_arburst ;
    wire                        npu_s1_axi_arlock  ;
    wire    [3:0]               npu_s1_axi_arcache ;
    wire    [2:0]               npu_s1_axi_arprot  ;
    wire                        npu_s1_axi_arvalid ;
    wire                        npu_s1_axi_arready ;
    wire    [AXI_ID_LEN-1:0]    npu_s1_axi_rid     ;
    wire    [AXI_DATA_LEN-1:0]  npu_s1_axi_rdata   ;
    wire    [1:0]               npu_s1_axi_rresp   ;
    wire                        npu_s1_axi_rlast   ;
    wire                        npu_s1_axi_rvalid  ;
    wire                        npu_s1_axi_rready  ;


    axi_dma_read #(
        .BURST_LEN  (BURST_LEN)   ,
	    .ID_WIDTH   (AXI_ID_LEN)  ,
	    .DATA_WIDTH (AXI_DATA_LEN)
	)
	npu_s1_axi_dma_read(
	    .clk(axi_clk)                   ,
	    .rst(axi_rst)                   ,
	
	    //cmd interface
	    .cmd_valid	(cdc_s_cmd_valid_1   )            ,
	    .cmd_addr	(cdc_s_cmd_addr_1    )            ,
	    .cmd_len	(cdc_s_cmd_len_1     )            ,
	    .cmd_id     (4'b0011             )            ,
	    .cmd_ready	(cdc_s_cmd_ready_1   )            ,
    
	    //trans data in    
	    .data_out      (cdc_s_data_1        )            ,
	    .data_out_valid(cdc_s_valid_1       )            ,
	    .data_out_last (cdc_s_last_1        )            ,
	    .data_out_ready(cdc_s_ready_1       )            ,

	    //axi r
        .m_axi_arid   (npu_s1_axi_arid    ) ,
        .m_axi_araddr (npu_s1_axi_araddr  ) ,
        .m_axi_arlen  (npu_s1_axi_arlen   ) ,
        .m_axi_arsize (npu_s1_axi_arsize  ) ,
        .m_axi_arburst(npu_s1_axi_arburst ) ,
        .m_axi_arlock (npu_s1_axi_arlock  ) ,
        .m_axi_arcache(npu_s1_axi_arcache ) ,
        .m_axi_arprot (npu_s1_axi_arprot  ) ,
        .m_axi_arvalid(npu_s1_axi_arvalid ) ,
        .m_axi_arready(npu_s1_axi_arready ) ,
        .m_axi_rid    (npu_s1_axi_rid     ) ,
        .m_axi_rdata  (npu_s1_axi_rdata   ) ,
        .m_axi_rresp  (npu_s1_axi_rresp   ) ,
        .m_axi_rlast  (npu_s1_axi_rlast   ) ,
        .m_axi_rvalid (npu_s1_axi_rvalid  ) ,
        .m_axi_rready (npu_s1_axi_rready  )  

    );




    wire    [AXI_ID_LEN-1:0]    npu_s2_axi_arid    ;
    wire    [31:0]              npu_s2_axi_araddr  ;
    wire    [3:0]               npu_s2_axi_arlen   ;
    wire    [2:0]               npu_s2_axi_arsize  ;
    wire    [1:0]               npu_s2_axi_arburst ;
    wire                        npu_s2_axi_arlock  ;
    wire    [3:0]               npu_s2_axi_arcache ;
    wire    [2:0]               npu_s2_axi_arprot  ;
    wire                        npu_s2_axi_arvalid ;
    wire                        npu_s2_axi_arready ;
    wire    [AXI_ID_LEN-1:0]    npu_s2_axi_rid     ;
    wire    [AXI_DATA_LEN-1:0]  npu_s2_axi_rdata   ;
    wire    [1:0]               npu_s2_axi_rresp   ;
    wire                        npu_s2_axi_rlast   ;
    wire                        npu_s2_axi_rvalid  ;
    wire                        npu_s2_axi_rready  ;


    axi_dma_read #(
        .BURST_LEN  (BURST_LEN)   ,
	    .ID_WIDTH   (AXI_ID_LEN)  ,
	    .DATA_WIDTH (AXI_DATA_LEN)
	)
	npu_s2_axi_dma_read(
	    .clk(axi_clk)                   ,
	    .rst(axi_rst)                   ,
	
	    //cmd interface
	    .cmd_valid	(cdc_s_cmd_valid_2   )            ,
	    .cmd_addr	(cdc_s_cmd_addr_2    )            ,
	    .cmd_len	(cdc_s_cmd_len_2     )            ,
	    .cmd_id     (4'b0100             )            ,
	    .cmd_ready	(cdc_s_cmd_ready_2   )            ,
    
	    //trans data in    
	    .data_out      (cdc_s_data_2        )            ,
	    .data_out_valid(cdc_s_valid_2       )            ,
	    .data_out_last (cdc_s_last_2        )            ,
	    .data_out_ready(cdc_s_ready_2       )            ,

	    //axi r
        .m_axi_arid   (npu_s2_axi_arid    ) ,
        .m_axi_araddr (npu_s2_axi_araddr  ) ,
        .m_axi_arlen  (npu_s2_axi_arlen   ) ,
        .m_axi_arsize (npu_s2_axi_arsize  ) ,
        .m_axi_arburst(npu_s2_axi_arburst ) ,
        .m_axi_arlock (npu_s2_axi_arlock  ) ,
        .m_axi_arcache(npu_s2_axi_arcache ) ,
        .m_axi_arprot (npu_s2_axi_arprot  ) ,
        .m_axi_arvalid(npu_s2_axi_arvalid ) ,
        .m_axi_arready(npu_s2_axi_arready ) ,
        .m_axi_rid    (npu_s2_axi_rid     ) ,
        .m_axi_rdata  (npu_s2_axi_rdata   ) ,
        .m_axi_rresp  (npu_s2_axi_rresp   ) ,
        .m_axi_rlast  (npu_s2_axi_rlast   ) ,
        .m_axi_rvalid (npu_s2_axi_rvalid  ) ,
        .m_axi_rready (npu_s2_axi_rready  )  

    );




    wire    [AXI_ID_LEN-1:0]    npu_s3_axi_arid    ;
    wire    [31:0]              npu_s3_axi_araddr  ;
    wire    [3:0]               npu_s3_axi_arlen   ;
    wire    [2:0]               npu_s3_axi_arsize  ;
    wire    [1:0]               npu_s3_axi_arburst ;
    wire                        npu_s3_axi_arlock  ;
    wire    [3:0]               npu_s3_axi_arcache ;
    wire    [2:0]               npu_s3_axi_arprot  ;
    wire                        npu_s3_axi_arvalid ;
    wire                        npu_s3_axi_arready ;
    wire    [AXI_ID_LEN-1:0]    npu_s3_axi_rid     ;
    wire    [AXI_DATA_LEN-1:0]  npu_s3_axi_rdata   ;
    wire    [1:0]               npu_s3_axi_rresp   ;
    wire                        npu_s3_axi_rlast   ;
    wire                        npu_s3_axi_rvalid  ;
    wire                        npu_s3_axi_rready  ;


    axi_dma_read #(
        .BURST_LEN  (BURST_LEN)   ,
	    .ID_WIDTH   (AXI_ID_LEN)  ,
	    .DATA_WIDTH (AXI_DATA_LEN)
	)
	npu_s3_axi_dma_read(
	    .clk(axi_clk)                   ,
	    .rst(axi_rst)                   ,
	
	    //cmd interface
	    .cmd_valid	(cdc_s_cmd_valid_3   )            ,
	    .cmd_addr	(cdc_s_cmd_addr_3    )            ,
	    .cmd_len	(cdc_s_cmd_len_3     )            ,
	    .cmd_id     (4'b0101             )            ,
	    .cmd_ready	(cdc_s_cmd_ready_3   )            ,
    
	    //trans data in    
	    .data_out      (cdc_s_data_3        )            ,
	    .data_out_valid(cdc_s_valid_3       )            ,
	    .data_out_last (cdc_s_last_3        )            ,
	    .data_out_ready(cdc_s_ready_3       )            ,

	    //axi r
        .m_axi_arid   (npu_s3_axi_arid    ) ,
        .m_axi_araddr (npu_s3_axi_araddr  ) ,
        .m_axi_arlen  (npu_s3_axi_arlen   ) ,
        .m_axi_arsize (npu_s3_axi_arsize  ) ,
        .m_axi_arburst(npu_s3_axi_arburst ) ,
        .m_axi_arlock (npu_s3_axi_arlock  ) ,
        .m_axi_arcache(npu_s3_axi_arcache ) ,
        .m_axi_arprot (npu_s3_axi_arprot  ) ,
        .m_axi_arvalid(npu_s3_axi_arvalid ) ,
        .m_axi_arready(npu_s3_axi_arready ) ,
        .m_axi_rid    (npu_s3_axi_rid     ) ,
        .m_axi_rdata  (npu_s3_axi_rdata   ) ,
        .m_axi_rresp  (npu_s3_axi_rresp   ) ,
        .m_axi_rlast  (npu_s3_axi_rlast   ) ,
        .m_axi_rvalid (npu_s3_axi_rvalid  ) ,
        .m_axi_rready (npu_s3_axi_rready  )  

    );




    wire    [AXI_ID_LEN-1:0]    npu_s4_axi_arid    ;
    wire    [31:0]              npu_s4_axi_araddr  ;
    wire    [3:0]               npu_s4_axi_arlen   ;
    wire    [2:0]               npu_s4_axi_arsize  ;
    wire    [1:0]               npu_s4_axi_arburst ;
    wire                        npu_s4_axi_arlock  ;
    wire    [3:0]               npu_s4_axi_arcache ;
    wire    [2:0]               npu_s4_axi_arprot  ;
    wire                        npu_s4_axi_arvalid ;
    wire                        npu_s4_axi_arready ;
    wire    [AXI_ID_LEN-1:0]    npu_s4_axi_rid     ;
    wire    [AXI_DATA_LEN-1:0]  npu_s4_axi_rdata   ;
    wire    [1:0]               npu_s4_axi_rresp   ;
    wire                        npu_s4_axi_rlast   ;
    wire                        npu_s4_axi_rvalid  ;
    wire                        npu_s4_axi_rready  ;


    axi_dma_read #(
        .BURST_LEN  (BURST_LEN)   ,
	    .ID_WIDTH   (AXI_ID_LEN)  ,
	    .DATA_WIDTH (AXI_DATA_LEN)
	)
	npu_s4_axi_dma_read(
	    .clk(axi_clk)                   ,
	    .rst(axi_rst)                   ,
	
	    //cmd interface
	    .cmd_valid	(cdc_s_cmd_valid_4   )            ,
	    .cmd_addr	(cdc_s_cmd_addr_4    )            ,
	    .cmd_len	(cdc_s_cmd_len_4     )            ,
	    .cmd_id     (4'b0110             )            ,
	    .cmd_ready	(cdc_s_cmd_ready_4   )            ,
    
	    //trans data in    
	    .data_out      (cdc_s_data_4        )            ,
	    .data_out_valid(cdc_s_valid_4       )            ,
	    .data_out_last (cdc_s_last_4        )            ,
	    .data_out_ready(cdc_s_ready_4       )            ,

	    //axi r
        .m_axi_arid   (npu_s4_axi_arid    ) ,
        .m_axi_araddr (npu_s4_axi_araddr  ) ,
        .m_axi_arlen  (npu_s4_axi_arlen   ) ,
        .m_axi_arsize (npu_s4_axi_arsize  ) ,
        .m_axi_arburst(npu_s4_axi_arburst ) ,
        .m_axi_arlock (npu_s4_axi_arlock  ) ,
        .m_axi_arcache(npu_s4_axi_arcache ) ,
        .m_axi_arprot (npu_s4_axi_arprot  ) ,
        .m_axi_arvalid(npu_s4_axi_arvalid ) ,
        .m_axi_arready(npu_s4_axi_arready ) ,
        .m_axi_rid    (npu_s4_axi_rid     ) ,
        .m_axi_rdata  (npu_s4_axi_rdata   ) ,
        .m_axi_rresp  (npu_s4_axi_rresp   ) ,
        .m_axi_rlast  (npu_s4_axi_rlast   ) ,
        .m_axi_rvalid (npu_s4_axi_rvalid  ) ,
        .m_axi_rready (npu_s4_axi_rready  )  

    );

///////////////////////////////////////////////////////////////////////////////////////////
axi_crossbar_7x3 #(
    //.DATA_WIDTH(AXI_DATA_LEN)
    .DATA_WIDTH(AXI_DATA_LEN),
    // M00 (DDR3) 的访问权限：
    // 读 DDR: 允许 PCIE(S00) 和 NPU所有通道(S02-S06)。禁止 Camera(S01)
    .M00_CONNECT_READ  (7'b1111101), 
    // 写 DDR: 允许 PCIE(S00), Camera(S01), NPU_S0(S02)。禁止 NPU_S1~S4(S03-S06)
    .M00_CONNECT_WRITE (7'b0000111),
    
    // M01 (OV5640 控制寄存器) 的访问权限：
    // 只有 PCIE (S00) 可以读写，彻底切断其他高速通道的干扰
    .M01_CONNECT_READ  (7'b0000001),
    .M01_CONNECT_WRITE (7'b0000001),
    
    // M02 (NPU 控制寄存器) 的访问权限：
    // 只有 PCIE (S00) 可以读写
    .M02_CONNECT_READ  (7'b0000001),
    .M02_CONNECT_WRITE (7'b0000001)
)
axi_crossbar_7x3
(
    .clk(axi_clk),
    .rst(axi_rst),

    /*
     * AXI slave interface
     */
    .s00_axi_awid   (pcie_axi_awid   ) ,
    .s00_axi_awaddr (pcie_axi_awaddr ) ,
    .s00_axi_awlen  (pcie_axi_awlen  ) ,
    .s00_axi_awsize (pcie_axi_awsize ) ,
    .s00_axi_awburst(pcie_axi_awburst) ,
    .s00_axi_awlock (pcie_axi_awlock ) ,
    .s00_axi_awcache(pcie_axi_awcache) ,
    .s00_axi_awprot (pcie_axi_awprot ) ,
    .s00_axi_awqos  (pcie_axi_awqos  ) ,
    .s00_axi_awvalid(pcie_axi_awvalid) ,
    .s00_axi_awready(pcie_axi_awready) ,
    .s00_axi_awuser () ,

    .s00_axi_wdata  (pcie_axi_wdata  ) ,
    .s00_axi_wstrb  (pcie_axi_wstrb  ) ,
    .s00_axi_wlast  (pcie_axi_wlast  ) ,
    .s00_axi_wready (pcie_axi_wready ) ,
    .s00_axi_wvalid (pcie_axi_wvalid ) ,
    .s00_axi_wuser  () ,

    .s00_axi_bid     (pcie_axi_bid   ),   
    .s00_axi_bresp   (pcie_axi_bresp ),
    .s00_axi_bvalid  (pcie_axi_bvalid),
    .s00_axi_bready  (pcie_axi_bready),
    .s00_axi_buser   (),

    .s00_axi_arid    (pcie_axi_arid   )     ,
    .s00_axi_araddr  (pcie_axi_araddr )     ,
    .s00_axi_arlen   (pcie_axi_arlen  )     ,
    .s00_axi_arsize  (pcie_axi_arsize )     ,
    .s00_axi_arburst (pcie_axi_arburst)     ,
    .s00_axi_arlock  (pcie_axi_arlock )     ,
    .s00_axi_arcache (pcie_axi_arcache)     ,
    .s00_axi_arprot  (pcie_axi_arprot )     ,
    .s00_axi_arqos   (pcie_axi_arqos  )     ,
    .s00_axi_arvalid (pcie_axi_arvalid)     ,
    .s00_axi_arready (pcie_axi_arready)     ,
    .s00_axi_aruser  (),

    .s00_axi_rid     (pcie_axi_rid    ),
    .s00_axi_rdata   (pcie_axi_rdata  ),
    .s00_axi_rresp   (pcie_axi_rresp  ),
    .s00_axi_rlast   (pcie_axi_rlast  ),
    .s00_axi_rvalid  (pcie_axi_rvalid ),
    .s00_axi_rready  (pcie_axi_rready ),
    .s00_axi_ruser   (),

    .s01_axi_awid    (ov5640_axi_awid    ),
    .s01_axi_awaddr  (ov5640_axi_awaddr  ),
    .s01_axi_awlen   (ov5640_axi_awlen   ),
    .s01_axi_awsize  (ov5640_axi_awsize  ),
    .s01_axi_awburst (ov5640_axi_awburst ),
    .s01_axi_awlock  (ov5640_axi_awlock  ),
    .s01_axi_awcache (ov5640_axi_awcache ),
    .s01_axi_awprot  (ov5640_axi_awprot  ),
    .s01_axi_awqos   (4'd0               ),
    .s01_axi_awvalid (ov5640_axi_awvalid ),
    .s01_axi_awready (ov5640_axi_awready ),
    .s01_axi_awuser  (               ),
    .s01_axi_wdata   (ov5640_axi_wdata   ),
    .s01_axi_wstrb   (ov5640_axi_wstrb   ),
    .s01_axi_wlast   (ov5640_axi_wlast   ),
    .s01_axi_wvalid  (ov5640_axi_wvalid  ),
    .s01_axi_wready  (ov5640_axi_wready  ),
    .s01_axi_wuser   (               ),
    .s01_axi_bid     (ov5640_axi_bid     ),
    .s01_axi_bresp   (ov5640_axi_bresp   ),
    .s01_axi_bvalid  (ov5640_axi_bvalid  ),
    .s01_axi_bready  (ov5640_axi_bready  ),
    .s01_axi_buser   (               ),
    .s01_axi_arid    (4'd0               ),
    .s01_axi_araddr  (32'd0              ),
    .s01_axi_arlen   (8'd0               ),
    .s01_axi_arsize  (3'd0               ),
    .s01_axi_arburst (2'd0               ),
    .s01_axi_arlock  (1'b0               ),
    .s01_axi_arcache (4'd0               ),
    .s01_axi_arprot  (3'd0               ),
    .s01_axi_arqos   (4'd0               ),
    .s01_axi_aruser  (1'b0               ),
    .s01_axi_arvalid (1'b0               ),
    .s01_axi_arready (),
    .s01_axi_rid     (),
    .s01_axi_rdata   (),
    .s01_axi_rresp   (),
    .s01_axi_rlast   (),
    .s01_axi_ruser   (),
    .s01_axi_rvalid  (),
    .s01_axi_rready  (1'b0               ),

    .s02_axi_awid   (npu_out_axi_awid   ),
    .s02_axi_awaddr (npu_out_axi_awaddr ),
    .s02_axi_awlen  (npu_out_axi_awlen  ),
    .s02_axi_awsize (npu_out_axi_awsize ),
    .s02_axi_awburst(npu_out_axi_awburst),
    .s02_axi_awlock (npu_out_axi_awlock ),
    .s02_axi_awcache(npu_out_axi_awcache),
    .s02_axi_awprot (npu_out_axi_awprot ),
    .s02_axi_awqos  (4'd0),
    .s02_axi_awuser (),
    .s02_axi_awvalid(npu_out_axi_awvalid),
    .s02_axi_awready(npu_out_axi_awready),
    .s02_axi_wdata  (npu_out_axi_wdata  ),
    .s02_axi_wstrb  (npu_out_axi_wstrb  ),
    .s02_axi_wlast  (npu_out_axi_wlast  ),
    .s02_axi_wvalid (npu_out_axi_wvalid ),
    .s02_axi_wready (npu_out_axi_wready ),
    .s02_axi_wuser  (),
    .s02_axi_bid    (npu_out_axi_bid    ),
    .s02_axi_bresp  (npu_out_axi_bresp  ),
    .s02_axi_bvalid (npu_out_axi_bvalid ),
    .s02_axi_bready (npu_out_axi_bready ),
    .s02_axi_buser  (),

    .s02_axi_arid   (npu_s0_axi_arid    ),
    .s02_axi_araddr (npu_s0_axi_araddr  ),
    .s02_axi_arlen  (npu_s0_axi_arlen   ),
    .s02_axi_arsize (npu_s0_axi_arsize  ),
    .s02_axi_arburst(npu_s0_axi_arburst ),
    .s02_axi_arlock (npu_s0_axi_arlock  ),
    .s02_axi_arcache(npu_s0_axi_arcache ),
    .s02_axi_arprot (npu_s0_axi_arprot  ),
    .s02_axi_arqos  (4'd0),
    .s02_axi_aruser (),
    .s02_axi_arvalid(npu_s0_axi_arvalid ),
    .s02_axi_arready(npu_s0_axi_arready ),
    .s02_axi_rid    (npu_s0_axi_rid     ),
    .s02_axi_rdata  (npu_s0_axi_rdata   ),
    .s02_axi_rresp  (npu_s0_axi_rresp   ),
    .s02_axi_rlast  (npu_s0_axi_rlast   ),
    .s02_axi_rvalid (npu_s0_axi_rvalid  ),
    .s02_axi_rready (npu_s0_axi_rready  ),
    .s02_axi_ruser  (),

    .s03_axi_awid(),
    .s03_axi_awaddr(),
    .s03_axi_awlen(),
    .s03_axi_awsize(),
    .s03_axi_awburst(),
    .s03_axi_awlock(),
    .s03_axi_awcache(),
    .s03_axi_awprot(),
    .s03_axi_awqos(),
    .s03_axi_awuser(),
    .s03_axi_awvalid(),
    .s03_axi_awready(),
    .s03_axi_wdata(),
    .s03_axi_wstrb(),
    .s03_axi_wlast(),
    .s03_axi_wuser(),
    .s03_axi_wvalid(),
    .s03_axi_wready(),
    .s03_axi_bid(),
    .s03_axi_bresp(),
    .s03_axi_buser(),
    .s03_axi_bvalid(),
    .s03_axi_bready(),
    .s03_axi_arid   (npu_s1_axi_arid    ),
    .s03_axi_araddr (npu_s1_axi_araddr  ),
    .s03_axi_arlen  (npu_s1_axi_arlen   ),
    .s03_axi_arsize (npu_s1_axi_arsize  ),
    .s03_axi_arburst(npu_s1_axi_arburst ),
    .s03_axi_arlock (npu_s1_axi_arlock  ),
    .s03_axi_arcache(npu_s1_axi_arcache ),
    .s03_axi_arprot (npu_s1_axi_arprot  ),
    .s03_axi_arqos  (4'd0),
    .s03_axi_aruser (),
    .s03_axi_arvalid(npu_s1_axi_arvalid ),
    .s03_axi_arready(npu_s1_axi_arready ),
    .s03_axi_rid    (npu_s1_axi_rid     ),
    .s03_axi_rdata  (npu_s1_axi_rdata   ),
    .s03_axi_rresp  (npu_s1_axi_rresp   ),
    .s03_axi_rlast  (npu_s1_axi_rlast   ),
    .s03_axi_rvalid (npu_s1_axi_rvalid  ),
    .s03_axi_rready (npu_s1_axi_rready  ),
    .s03_axi_ruser  (),

    .s04_axi_awid(),
    .s04_axi_awaddr(),
    .s04_axi_awlen(),
    .s04_axi_awsize(),
    .s04_axi_awburst(),
    .s04_axi_awlock(),
    .s04_axi_awcache(),
    .s04_axi_awprot(),
    .s04_axi_awqos(),
    .s04_axi_awuser(),
    .s04_axi_awvalid(),
    .s04_axi_awready(),
    .s04_axi_wdata(),
    .s04_axi_wstrb(),
    .s04_axi_wlast(),
    .s04_axi_wuser(),
    .s04_axi_wvalid(),
    .s04_axi_wready(),
    .s04_axi_bid(),
    .s04_axi_bresp(),
    .s04_axi_buser(),
    .s04_axi_bvalid(),
    .s04_axi_bready(),
    .s04_axi_arid   (npu_s2_axi_arid    ),
    .s04_axi_araddr (npu_s2_axi_araddr  ),
    .s04_axi_arlen  (npu_s2_axi_arlen   ),
    .s04_axi_arsize (npu_s2_axi_arsize  ),
    .s04_axi_arburst(npu_s2_axi_arburst ),
    .s04_axi_arlock (npu_s2_axi_arlock  ),
    .s04_axi_arcache(npu_s2_axi_arcache ),
    .s04_axi_arprot (npu_s2_axi_arprot  ),
    .s04_axi_arqos  (4'd0),
    .s04_axi_aruser (),
    .s04_axi_arvalid(npu_s2_axi_arvalid ),
    .s04_axi_arready(npu_s2_axi_arready ),
    .s04_axi_rid    (npu_s2_axi_rid     ),
    .s04_axi_rdata  (npu_s2_axi_rdata   ),
    .s04_axi_rresp  (npu_s2_axi_rresp   ),
    .s04_axi_rlast  (npu_s2_axi_rlast   ),
    .s04_axi_rvalid (npu_s2_axi_rvalid  ),
    .s04_axi_rready (npu_s2_axi_rready  ),
    .s04_axi_ruser  (),

    .s05_axi_awid(),
    .s05_axi_awaddr(),
    .s05_axi_awlen(),
    .s05_axi_awsize(),
    .s05_axi_awburst(),
    .s05_axi_awlock(),
    .s05_axi_awcache(),
    .s05_axi_awprot(),
    .s05_axi_awqos(),
    .s05_axi_awuser(),
    .s05_axi_awvalid(),
    .s05_axi_awready(),
    .s05_axi_wdata(),
    .s05_axi_wstrb(),
    .s05_axi_wlast(),
    .s05_axi_wuser(),
    .s05_axi_wvalid(),
    .s05_axi_wready(),
    .s05_axi_bid(),
    .s05_axi_bresp(),
    .s05_axi_buser(),
    .s05_axi_bvalid(),
    .s05_axi_bready(),
    .s05_axi_arid   (npu_s3_axi_arid    ),
    .s05_axi_araddr (npu_s3_axi_araddr  ),
    .s05_axi_arlen  (npu_s3_axi_arlen   ),
    .s05_axi_arsize (npu_s3_axi_arsize  ),
    .s05_axi_arburst(npu_s3_axi_arburst ),
    .s05_axi_arlock (npu_s3_axi_arlock  ),
    .s05_axi_arcache(npu_s3_axi_arcache ),
    .s05_axi_arprot (npu_s3_axi_arprot  ),
    .s05_axi_arqos  (4'd0),
    .s05_axi_aruser (),
    .s05_axi_arvalid(npu_s3_axi_arvalid ),
    .s05_axi_arready(npu_s3_axi_arready ),
    .s05_axi_rid    (npu_s3_axi_rid     ),
    .s05_axi_rdata  (npu_s3_axi_rdata   ),
    .s05_axi_rresp  (npu_s3_axi_rresp   ),
    .s05_axi_rlast  (npu_s3_axi_rlast   ),
    .s05_axi_rvalid (npu_s3_axi_rvalid  ),
    .s05_axi_rready (npu_s3_axi_rready  ),
    .s05_axi_ruser  (),

    .s06_axi_awid(),
    .s06_axi_awaddr(),
    .s06_axi_awlen(),
    .s06_axi_awsize(),
    .s06_axi_awburst(),
    .s06_axi_awlock(),
    .s06_axi_awcache(),
    .s06_axi_awprot(),
    .s06_axi_awqos(),
    .s06_axi_awuser(),
    .s06_axi_awvalid(),
    .s06_axi_awready(),
    .s06_axi_wdata(),
    .s06_axi_wstrb(),
    .s06_axi_wlast(),
    .s06_axi_wuser(),
    .s06_axi_wvalid(),
    .s06_axi_wready(),
    .s06_axi_bid(),
    .s06_axi_bresp(),
    .s06_axi_buser(),
    .s06_axi_bvalid(),
    .s06_axi_bready(),
    .s06_axi_arid   (npu_s4_axi_arid    ),
    .s06_axi_araddr (npu_s4_axi_araddr  ),
    .s06_axi_arlen  (npu_s4_axi_arlen   ),
    .s06_axi_arsize (npu_s4_axi_arsize  ),
    .s06_axi_arburst(npu_s4_axi_arburst ),
    .s06_axi_arlock (npu_s4_axi_arlock  ),
    .s06_axi_arcache(npu_s4_axi_arcache ),
    .s06_axi_arprot (npu_s4_axi_arprot  ),
    .s06_axi_arqos  (4'd0),
    .s06_axi_aruser (),
    .s06_axi_arvalid(npu_s4_axi_arvalid ),
    .s06_axi_arready(npu_s4_axi_arready ),
    .s06_axi_rid    (npu_s4_axi_rid     ),
    .s06_axi_rdata  (npu_s4_axi_rdata   ),
    .s06_axi_rresp  (npu_s4_axi_rresp   ),
    .s06_axi_rlast  (npu_s4_axi_rlast   ),
    .s06_axi_rvalid (npu_s4_axi_rvalid  ),
    .s06_axi_rready (npu_s4_axi_rready  ),
    .s06_axi_ruser  (),

    /*
     * AXI master interface
     */
    .m00_axi_awid    (ddr_axi_awuser_id              ),
    .m00_axi_awaddr  (ddr_axi_awaddr                 ),
    .m00_axi_awlen   (ddr_axi_awlen                  ),
    .m00_axi_awsize  (ddr_axi_awsize                 ),
    .m00_axi_awburst (ddr_axi_awburst                ),
    .m00_axi_awlock  (ddr_axi_awlock                 ),
    .m00_axi_awcache (ddr_axi_awcache                ),
    .m00_axi_awprot  (ddr_axi_awprot                 ),
    .m00_axi_awqos   (ddr_axi_awqos                  ),
    .m00_axi_awregion(),
    .m00_axi_awuser  (ddr_axi_awuser                 ),
    .m00_axi_awvalid (ddr_axi_awvalid                ),
    .m00_axi_awready (ddr_axi_awready                ),
    .m00_axi_wdata   (ddr_axi_wdata                  ),
    .m00_axi_wstrb   (ddr_axi_wstrb                  ),
    .m00_axi_wlast   (ddr_axi_wlast                  ),
    .m00_axi_wuser   (ddr_axi_wuser                  ),
    .m00_axi_wvalid  (ddr_axi_wvalid                 ),
    .m00_axi_wready  (!ddr_axi_fifo_full             ),
    .m00_axi_bid     (ddr_axi_bid                    ),
    .m00_axi_bresp   (ddr_axi_bresp                  ),
    .m00_axi_buser   (ddr_axi_buser                  ),
    .m00_axi_bvalid  (ddr_axi_bvalid                 ),
    .m00_axi_bready  (ddr_axi_bready                 ),
    .m00_axi_arid    (ddr_axi_aruser_id              ),
    .m00_axi_araddr  (ddr_axi_araddr                 ),
    .m00_axi_arlen   (ddr_axi_arlen                  ),
    .m00_axi_arsize  (ddr_axi_arsize                 ),
    .m00_axi_arburst (ddr_axi_arburst                ),
    .m00_axi_arlock  (ddr_axi_arlock                 ),
    .m00_axi_arcache (ddr_axi_arcache                ),
    .m00_axi_arprot  (ddr_axi_arprot                 ),
    .m00_axi_arqos   (ddr_axi_arqos                  ),
    .m00_axi_arregion(),
    .m00_axi_aruser  (ddr_axi_aruser                 ),
    .m00_axi_arvalid (ddr_axi_arvalid                ),
    .m00_axi_arready (ddr_axi_arready                ),
    .m00_axi_rid     (ddr_axi_rid                    ),
    .m00_axi_rdata   (ddr_axi_rdata                  ),
    .m00_axi_rresp   (2'b00                          ),
    .m00_axi_rlast   (ddr_axi_rlast                  ),
    .m00_axi_ruser   (ddr_axi_ruser                  ),
    .m00_axi_rvalid  (!ddr_axi_fifo_empty            ),
    .m00_axi_rready  (ddr_axi_rready                 ),





    .m01_axi_awid    (ovreg_axi_awid     ),
    .m01_axi_awaddr  (ovreg_axi_awaddr   ),
    .m01_axi_awlen   (ovreg_axi_awlen    ),
    .m01_axi_awsize  (ovreg_axi_awsize   ),
    .m01_axi_awburst (ovreg_axi_awburst  ),
    .m01_axi_awlock  (ovreg_axi_awlock   ),
    .m01_axi_awcache (ovreg_axi_awcache  ),
    .m01_axi_awprot  (ovreg_axi_awprot   ),
    .m01_axi_awqos   (ovreg_axi_awqos    ),
    .m01_axi_awregion(ovreg_axi_awregion),
    .m01_axi_awuser  (               ),
    .m01_axi_awvalid (ovreg_axi_awvalid  ),
    .m01_axi_awready (ovreg_axi_awready  ),
    .m01_axi_wdata   (ovreg_axi_wdata    ),
    .m01_axi_wstrb   (ovreg_axi_wstrb    ),
    .m01_axi_wlast   (ovreg_axi_wlast    ),
    .m01_axi_wuser   (               ),
    .m01_axi_wvalid  (ovreg_axi_wvalid   ),
    .m01_axi_wready  (ovreg_axi_wready   ),
    .m01_axi_bid     (ovreg_axi_bid      ),
    .m01_axi_bresp   (ovreg_axi_bresp    ),
    .m01_axi_buser   (               ),
    .m01_axi_bvalid  (ovreg_axi_bvalid   ),
    .m01_axi_bready  (ovreg_axi_bready   ),
    .m01_axi_arid    (ovreg_axi_arid     ),
    .m01_axi_araddr  (ovreg_axi_araddr   ),
    .m01_axi_arlen   (ovreg_axi_arlen    ),
    .m01_axi_arsize  (ovreg_axi_arsize   ),
    .m01_axi_arburst (ovreg_axi_arburst  ),
    .m01_axi_arlock  (ovreg_axi_arlock   ),
    .m01_axi_arcache (ovreg_axi_arcache  ),
    .m01_axi_arprot  (ovreg_axi_arprot   ),
    .m01_axi_arqos   (ovreg_axi_arqos    ),
    .m01_axi_arregion(ovreg_axi_arregion ),
    .m01_axi_aruser  (               ),
    .m01_axi_arvalid (ovreg_axi_arvalid  ),
    .m01_axi_arready (ovreg_axi_arready  ),
    .m01_axi_rid     (ovreg_axi_rid      ),
    .m01_axi_rdata   (ovreg_axi_rdata    ),
    .m01_axi_rresp   (ovreg_axi_rresp    ),
    .m01_axi_rlast   (ovreg_axi_rlast    ),
    .m01_axi_ruser   (              ),
    .m01_axi_rvalid  (ovreg_axi_rvalid   ),
    .m01_axi_rready  (ovreg_axi_rready   ),



    .m02_axi_awid    (npu_reg_axi_awid    ),
    .m02_axi_awaddr  (npu_reg_axi_awaddr  ),
    .m02_axi_awlen   (npu_reg_axi_awlen   ),
    .m02_axi_awsize  (npu_reg_axi_awsize  ),
    .m02_axi_awburst (npu_reg_axi_awburst ),
    .m02_axi_awlock  (npu_reg_axi_awlock  ),
    .m02_axi_awcache (npu_reg_axi_awcache ),
    .m02_axi_awprot  (npu_reg_axi_awprot  ),
    .m02_axi_awqos   (npu_reg_axi_awqos   ),
    .m02_axi_awregion(npu_reg_axi_awregion),
    .m02_axi_awvalid (npu_reg_axi_awvalid ),
    .m02_axi_awready (npu_reg_axi_awready ),
    .m02_axi_awuser  (  ),
    .m02_axi_wdata   (npu_reg_axi_wdata   ),
    .m02_axi_wstrb   (npu_reg_axi_wstrb   ),
    .m02_axi_wlast   (npu_reg_axi_wlast   ),
    .m02_axi_wvalid  (npu_reg_axi_wvalid  ),
    .m02_axi_wready  (npu_reg_axi_wready  ),
    .m02_axi_wuser   (  ),
    .m02_axi_bid     (npu_reg_axi_bid     ),
    .m02_axi_bresp   (npu_reg_axi_bresp   ),
    .m02_axi_bvalid  (npu_reg_axi_bvalid  ),
    .m02_axi_bready  (npu_reg_axi_bready  ),
    .m02_axi_buser   (  ),
    .m02_axi_arid    (npu_reg_axi_arid    ),
    .m02_axi_araddr  (npu_reg_axi_araddr  ),
    .m02_axi_arlen   (npu_reg_axi_arlen   ),
    .m02_axi_arsize  (npu_reg_axi_arsize  ),
    .m02_axi_arburst (npu_reg_axi_arburst ),
    .m02_axi_arlock  (npu_reg_axi_arlock  ),
    .m02_axi_arcache (npu_reg_axi_arcache ),
    .m02_axi_arprot  (npu_reg_axi_arprot  ),
    .m02_axi_arqos   (npu_reg_axi_arqos   ),
    .m02_axi_arregion(npu_reg_axi_arregion),
    .m02_axi_arvalid (npu_reg_axi_arvalid ),
    .m02_axi_arready (npu_reg_axi_arready ),
    .m02_axi_aruser  (  ),
    .m02_axi_rid     (npu_reg_axi_rid     ),
    .m02_axi_rdata   (npu_reg_axi_rdata   ),
    .m02_axi_rresp   (npu_reg_axi_rresp   ),
    .m02_axi_rlast   (npu_reg_axi_rlast   ),
    .m02_axi_ruser   (  ),
    .m02_axi_rvalid  (npu_reg_axi_rvalid  ),
    .m02_axi_rready  (npu_reg_axi_rready  )  




);

endmodule