//ov5640写使能控制和写地址控制
module ov5640_reg #(
    parameter BASE_ADDR = 32'h2000_0000,
    // parameter AXI_REG_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 32
) (
    input             clk                   ,
    input             rst                   ,

    input                             s_axi_awvalid         ,
    output                            s_axi_awready         ,
    input  [AXI_ADDR_WIDTH-1 : 0]     s_axi_awaddr          ,

    input                             s_axi_wvalid          ,
    output                            s_axi_wready          ,
    input  [AXI_ADDR_WIDTH-1 : 0]     s_axi_wdata           ,
    input  [AXI_ADDR_WIDTH/8-1 : 0]   s_axi_wstrb           ,

    output                            s_axi_bvalid          ,
    input                             s_axi_bready          ,
    output [ 1 : 0]                   s_axi_bresp           ,

    input                             s_axi_arvalid         ,
    output                            s_axi_arready         ,
    input  [AXI_ADDR_WIDTH-1 : 0]     s_axi_araddr          ,

    output                            s_axi_rvalid          ,
    input                             s_axi_rready          ,
    output [AXI_ADDR_WIDTH-1 : 0]     s_axi_rdata           ,
    output [ 1 : 0]                   s_axi_rresp           ,


    output reg [AXI_ADDR_WIDTH-1 : 0] cam_addr_1            ,
    output reg [AXI_ADDR_WIDTH-1 : 0] cam_addr_2            ,        
    output reg [1 : 0]                xdma_ack              ,
    output reg                        cam_en                
);

//寄存器地址
localparam REG_ACK       = BASE_ADDR + 32'h00;
localparam REG_CAM_EN    = BASE_ADDR + 32'h40;
localparam REG_CAM_ADDR_1= BASE_ADDR + 32'h80;
localparam REG_CAM_ADDR_2= BASE_ADDR + 32'hc0;

    reg bvalid        ;
    reg data_out_valid;

    reg rvalid;
    reg [AXI_ADDR_WIDTH-1 : 0] rdata ;

    //XDAM应答
    always @(posedge clk) begin
        if((s_axi_awvalid & s_axi_awready) && (s_axi_wvalid & s_axi_wready) && (s_axi_awaddr == REG_ACK))begin
            xdma_ack <= s_axi_wdata[1 : 0];
        end
        else begin
            xdma_ack <= 2'b0;
        end
    end

    //摄像头使能
    always @(posedge clk) begin
        if((s_axi_awvalid & s_axi_awready) && (s_axi_wvalid & s_axi_wready) && (s_axi_awaddr == REG_CAM_EN))begin
            cam_en <= s_axi_wdata[0];
        end
    end

    //图片地址1
    always @(posedge clk) begin
        if((s_axi_awvalid & s_axi_awready) && (s_axi_wvalid & s_axi_wready) && (s_axi_awaddr == REG_CAM_ADDR_1))begin
            cam_addr_1 <= s_axi_wdata;
        end
    end

    //图片地址2
    always @(posedge clk) begin
        if((s_axi_awvalid & s_axi_awready) && (s_axi_wvalid & s_axi_wready) && (s_axi_awaddr == REG_CAM_ADDR_2))begin
            cam_addr_2 <= s_axi_wdata;
        end
    end

    //因为就一个读寄存器，所以这里就没有判断读地址
    reg r_state;
    always @(posedge clk) begin
        if(rst)begin
            r_state <= 1'b0;
        end
        else begin
            if(s_axi_arvalid & s_axi_arready) begin
                r_state <= 1'b1;
            end
            else if(s_axi_rvalid & s_axi_rready) begin
                r_state <= 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if(rst)begin
            data_out_valid <= 1'b0;
        end
        else begin
            if(s_axi_arvalid & s_axi_arready)begin
                data_out_valid <= 1'b1;
            end
            else begin
                data_out_valid <= 1'b0;
            end
        end
    end


    // 增加一个暂存读地址的寄存器
    reg [AXI_ADDR_WIDTH-1:0] raddr_reg;
    always @(posedge clk) begin
        if (s_axi_arvalid & s_axi_arready) begin
            raddr_reg <= s_axi_araddr; // 握手成功瞬间，锁存主机发来的读地址
        end
    end


    always @(posedge clk) begin
        if(rst)begin
            rvalid <= 1'b0;
            rdata  <= {AXI_ADDR_WIDTH{1'b0}}; // 注意：rdata 位宽应该是 32，不是 1
        end
        else begin
            if(data_out_valid) begin
                rvalid <= 1'b1;
                // 根据刚才锁存的读地址，返回对应寄存器的真实值
                case(raddr_reg)
                    REG_ACK:        rdata <= {{AXI_ADDR_WIDTH-2{1'b0}}, xdma_ack};
                    REG_CAM_EN:     rdata <= {{AXI_ADDR_WIDTH-1{1'b0}}, cam_en};
                    REG_CAM_ADDR_1: rdata <= cam_addr_1;
                    REG_CAM_ADDR_2: rdata <= cam_addr_2;
                    default:        rdata <= {AXI_ADDR_WIDTH{1'b1}}; // 读到非法地址返回特殊标记，方便 debug
                endcase
            end
            else if(s_axi_rvalid & s_axi_rready)begin
                rvalid <= 1'b0;
                // rdata 保持不变即可，直到下一次读请求
            end
        end
    end


    always @(posedge clk) begin
        if(rst)begin
            bvalid <= 1'b0;
        end
        else begin
            if((s_axi_awvalid & s_axi_awready) && (s_axi_wvalid & s_axi_wready))begin
                bvalid <= 1'b1;
            end
            else if(bvalid & s_axi_bready)begin
                bvalid <= 1'b0;
            end
        end
    end

    assign s_axi_awready = s_axi_awvalid & s_axi_wvalid;
    assign s_axi_wready  = s_axi_awvalid & s_axi_wvalid;
    
    assign s_axi_arready = s_axi_arvalid & (r_state == 1'b0);
    assign s_axi_rvalid  = rvalid        ;
    assign s_axi_rdata   = rdata         ;
    assign s_axi_rresp   = 2'b00         ;
    
    assign s_axi_bvalid = bvalid;
    assign s_axi_bresp  = 2'b00 ;


endmodule