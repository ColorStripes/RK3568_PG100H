module axi_lite_interdace # (
    parameter AXI_DATA_WIDTH    = 32,
    parameter AXI_ADDR_WIDTH    = 32

)(
    input                               clk,
    input                               rst,

    
	output                               wen,   
    output reg [AXI_ADDR_WIDTH-1:0]      waddr,     
    output     [AXI_DATA_WIDTH-1:0]      wdata,  


    // Advanced extensible Interface
    input                               s_axi_awvalid,
    output                              s_axi_awready, 
    input [AXI_ADDR_WIDTH-1 : 0]        s_axi_awaddr,


    input                               s_axi_wvalid,
    output                              s_axi_wready, 
    input [AXI_DATA_WIDTH-1 : 0]        s_axi_wdata,
    input [AXI_DATA_WIDTH/8-1 : 0]      s_axi_wstrb,

    output                              s_axi_bvalid,
    input                               s_axi_bready,
    output  [1 : 0]                     s_axi_bresp,

    input                               s_axi_arvalid, 
    output                              s_axi_arready, 
    input   [AXI_ADDR_WIDTH-1:0]        s_axi_araddr,


    output                              s_axi_rvalid,//read data
    input                               s_axi_rready, 
    output  [AXI_DATA_WIDTH-1:0]        s_axi_rdata,
    output  [1 : 0]                     s_axi_rresp

);





    
    // handshake
    wire aw_hs  = s_axi_awvalid & s_axi_awready; 
    wire w_hs   = s_axi_wvalid  & s_axi_wready;
    wire b_hs   = s_axi_bvalid  & s_axi_bready;
    // ------------------State Machine------------------
    reg [1:0] w_state;
    localparam W_IDLE = 2'b00, W_ADDR = 2'b01, W_WRITE = 2'b10, W_RESP = 2'b11;
    // Wirte State Machine
    always @(posedge clk) begin
        if (rst) begin
            w_state <= W_IDLE;
        end
        else begin
            case (w_state)
                W_IDLE:begin 
                    w_state <= W_ADDR;   
                end              
                W_ADDR:begin
                    if (aw_hs)   
                        w_state <= W_WRITE;
                end  
                W_WRITE:begin
                    if (w_hs)  
                        w_state <= W_RESP;
                end 
                W_RESP:begin
                    if (b_hs) 
                        w_state <= W_ADDR;
                end    
            endcase
        end
    end



    // ------------------Write Transaction------------------
    assign s_axi_awready  = (w_state == W_ADDR);
    always @(posedge clk) begin
        if(rst) begin
            waddr <= 0;
        end
        else if(aw_hs) begin
            waddr <= s_axi_awaddr;
        end
    end

    assign s_axi_wready = (w_state == W_WRITE);
    assign wen = w_hs;
    genvar i;
    for(i = 0; i < AXI_DATA_WIDTH/8; i = i+1) begin
        assign wdata[i*8 +: 8] = s_axi_wdata[i*8 +: 8] & {8{s_axi_wstrb[i]}};
    end
    
    
    localparam AXI_BRESP_TYPE_OK = 2'b00, AXI_BRESP_TYPE_EXOK = 2'b01;// AXI_BRESP_TYPE_SLVERR = 2'b10, AXI_BRESP_TYPE_DECERR = 2'b11;
    assign s_axi_bresp   = AXI_BRESP_TYPE_OK;
    assign s_axi_bvalid  = (w_state == W_RESP);







    // // handshake
    // wire ar_hs  = s_axi_arvalid & s_axi_arready; 
    // wire r_hs   = s_axi_rvalid  & s_axi_rready;
    // // ------------------State Machine------------------
    // reg [1:0] r_state;
    // localparam R_IDLE = 2'b00, R_ADDR = 2'b01, R_READ = 2'b10;
    // // Wirte State Machine
    // always @(posedge clk) begin
    //     if (rst) begin
    //         r_state <= R_IDLE;
    //     end
    //     else begin
    //         case (r_state)
    //             R_IDLE:begin 
    //                 r_state <= R_ADDR;   
    //             end              
    //             R_ADDR:begin
    //                 if (ar_hs)   
    //                     r_state <= R_READ;
    //             end  
    //             R_READ:begin
    //                 if (r_hs)  
    //                     r_state <= R_ADDR;
    //             end 
    //         endcase
    //     end
    // end


    // // ------------------Read Transaction------------------
    // assign s_axi_arready = (r_state == R_ADDR);
    // assign s_axi_rvalid  = (r_state == R_READ);
    // assign s_axi_rdata  = 0;
    // localparam AXI_RRESP_TYPE_OK = 2'b00, AXI_RRESP_TYPE_EXOK = 2'b01;// AXI_RRESP_TYPE_SLVERR = 2'b10, AXI_RRESP_TYPE_DECERR = 2'b11;
    // assign s_axi_rresp  = AXI_RRESP_TYPE_OK;






endmodule