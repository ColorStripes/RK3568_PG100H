//发送CMD命令
module ov5640_ddr_w_ctrl #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_LEN_WIDTH  = 32,
    parameter CAM_DATA_LEN   = 172800 //1280*720*3/16
)(
    input          axi_clk        ,
    input          axi_rst        ,

    input  [AXI_ADDR_WIDTH-1 : 0]      cam_data_addr_1,
    input  [AXI_ADDR_WIDTH-1 : 0]      cam_data_addr_2,
    input  [$clog2(CAM_DATA_LEN) : 0]  cam_data_len   , //以16字节为单位
    
    input          s_vsync        ,

    input          axi_data_valid ,
    input          axi_data_last  , 
    input          axi_data_ready ,

    output [AXI_ADDR_WIDTH-1 : 0]  axi_cmd_addr   /*synthesis PAP_MARK_DEBUG="1"*/,
    output [AXI_LEN_WIDTH-1 : 0]   axi_cmd_len    /*synthesis PAP_MARK_DEBUG="1"*/,
    output reg                     axi_cmd_valid  /*synthesis PAP_MARK_DEBUG="1"*/,
    input                          axi_cmd_ready  /*synthesis PAP_MARK_DEBUG="1"*/,

    output [1 : 0]   xdma_req       ,
    input  [1 : 0]   xdma_ack       
);

    localparam IDLE = 3'b001;
    localparam ADDR = 3'b010;
    localparam DATA = 3'b100;

    reg [2 : 0] curr_state/*synthesis PAP_MARK_DEBUG="1"*/;
    reg [2 : 0] next_state;

    reg [1 : 0] axi_vsync_ff/*synthesis PAP_MARK_DEBUG="1"*/;
    reg axi_vsync_rise/*synthesis PAP_MARK_DEBUG="1"*/;

    
    reg [AXI_ADDR_WIDTH-1 : 0] cmd_addr;


    //状态机
    always @(posedge axi_clk) begin
        if(axi_rst)begin
            curr_state <= IDLE;
        end
        else begin
            curr_state <= next_state;
        end
    end

    always @(*) begin
        case (curr_state)
            IDLE: begin
                if(axi_vsync_rise)begin
                    next_state = ADDR;
                end
                else begin
                    next_state = IDLE;
                end
            end 
            ADDR: begin
                if(axi_cmd_ready & axi_cmd_valid)begin
                    next_state = DATA;
                end
                else begin
                    next_state = ADDR;
                end
            end
            DATA: begin
                if(axi_data_valid & axi_data_ready & axi_data_last)begin
                    next_state = IDLE;
                end
                else begin
                    next_state = DATA;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    

    always @(posedge axi_clk) begin
        if(axi_rst)begin
            axi_vsync_ff <= 2'b0;
        end
        else begin
            axi_vsync_ff <= {axi_vsync_ff[0], s_vsync};
        end
    end

    always @(posedge axi_clk) begin
        if(axi_rst)begin
            axi_vsync_rise <= 1'b0;
        end
        else begin
            axi_vsync_rise <= axi_vsync_ff[0] & (~axi_vsync_ff[1]);
        end
    end

    reg w_ping;
    always @(posedge axi_clk) begin
        if(axi_rst)begin
            w_ping <= 1'b0;
        end
        else begin
            if(axi_data_valid & axi_data_ready & axi_data_last)begin
                w_ping <= ~w_ping;
            end
        end
    end


    always @(posedge axi_clk) begin
        if(axi_rst)begin
            axi_cmd_valid <= 1'b0;
        end
        else begin
            if((curr_state == IDLE) && (axi_vsync_rise))begin
                axi_cmd_valid <= 1'b1;
            end
            else if(axi_cmd_valid & axi_cmd_ready)begin
                axi_cmd_valid <= 1'b0;
            end
        end
    end


    always @(posedge axi_clk) begin
        if(w_ping)begin
            cmd_addr <= cam_data_addr_2; 
        end
        else begin
            cmd_addr <= cam_data_addr_1; 
        end
    end

    assign axi_cmd_addr = cmd_addr;
    assign axi_cmd_len  = {{AXI_LEN_WIDTH-4-$clog2(CAM_DATA_LEN){1'd0}}, cam_data_len, 4'b0};


    //XDMA乒乓请求
    reg [1 : 0] s_xdma_req;
    always @(posedge axi_clk) begin
        if(axi_rst)begin
            s_xdma_req <= 2'b0;
        end
        else begin
            if(axi_data_valid & axi_data_ready & axi_data_last)begin
                if(w_ping)begin
                    s_xdma_req[1] <= 1'b1;
                end
                else begin
                    s_xdma_req[0] <= 1'b1;
                end
            end
            else begin
                if(xdma_ack[0]) begin
                    s_xdma_req[0] <= 1'b0;
                end
                if(xdma_ack[1]) begin
                    s_xdma_req[1] <= 1'b0;
                end
            end
        end
    end

    assign xdma_req = s_xdma_req;




endmodule