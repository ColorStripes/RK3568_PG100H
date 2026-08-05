module app_width_convert (
    input               clk                 ,
    input               rst                 ,

    
    input   [28 : 0 ]   s_app_addr          ,
    input   [2 : 0  ]   s_app_cmd           ,
    input               s_app_en            ,
    input   [511 : 0]   s_app_wdf_data      ,
    input               s_app_wdf_end       ,
    input   [63 : 0 ]   s_app_wdf_mask      ,
    input               s_app_wdf_wren      ,
    output  [511 : 0]   s_app_rd_data       ,
    output              s_app_rd_data_end   ,
    output              s_app_rd_data_valid ,
    output              s_app_rdy           ,
    output              s_app_wdf_rdy       ,     

    output  [28 : 0 ]   m_app_addr          ,
    output  [2 : 0  ]   m_app_cmd           ,
    output              m_app_en            ,
    output  [255 : 0]   m_app_wdf_data      ,
    output              m_app_wdf_end       ,
    output  [31 : 0 ]   m_app_wdf_mask      ,
    output              m_app_wdf_wren      ,
    input   [255 : 0]   m_app_rd_data       ,
    input               m_app_rd_data_end   ,
    input               m_app_rd_data_valid ,
    input               m_app_rdy           ,
    input               m_app_wdf_rdy          
);

localparam IDLE       = 4'b0001;
localparam WRITE_ADDR = 4'b0010;
localparam WRITE      = 4'b0100;
localparam READ       = 4'b1000;

reg [3:0] curr_state;
reg [3:0] next_state;

reg [28:0] app_addr;
reg [28:0] app_addr_a32;
reg [511:0] app_wdata;
reg [63:0]  app_mask ;

reg  [1:0]   w_addr_flag;
reg  [1:0]   w_data_flag;
wire [28:0]  waddr   ;
wire [255:0] wdata   ;
wire [31:0]  wmask   ;

reg          r_flag  ;
wire [28:0]  raddr   ;

reg [511:0] r_data ;
reg         r_valid;
reg [1:0]   r_d_c  ;

always @(posedge clk ) begin
    if(rst == 1'b1)begin
        curr_state <= IDLE;
    end
    else begin
        curr_state <= next_state;
    end
end

always @(*) begin
    case (curr_state)
        IDLE: begin
            if((s_app_en == 1'b1) && (s_app_cmd == 3'b001))begin
                next_state = READ;
            end
            else if((s_app_en == 1'b1) && (s_app_cmd == 3'b000))begin
                if(s_app_wdf_wren == 1'b1)begin
                    next_state = WRITE;
                end
                else begin
                    next_state = WRITE_ADDR;
                end
            end
        end
        WRITE_ADDR: begin
            if(s_app_wdf_wren == 1'b1)begin
                next_state = WRITE;
            end
            else begin
                next_state = WRITE_ADDR;
            end
        end
        WRITE: begin
            if((w_addr_flag == 2'd2) && (w_data_flag == 2'd2))begin
                next_state = IDLE;
            end
            else begin
                next_state = WRITE;
            end
        end
        READ: begin
            if((r_flag == 1'b1) && (m_app_rdy == 1'b1))begin
                next_state = IDLE;
            end
            else begin
                next_state = READ;
            end
        end
        default: begin
            next_state = IDLE;
        end
    endcase
end

assign s_app_rdy = (curr_state == IDLE);
assign s_app_wdf_rdy = (curr_state == IDLE) || (curr_state == WRITE_ADDR);

always @(posedge clk ) begin
    if(rst == 1'b1)begin
        app_addr <= 29'd0;
        app_addr_a32 <= 29'd0;
    end
    else begin
        if((s_app_rdy == 1'b1) && (s_app_en == 1'b1))begin
            app_addr <= s_app_addr;
            app_addr_a32 <= s_app_addr + 29'd32;
        end
    end
end

always @(posedge clk ) begin
    if(rst == 1'b1)begin
        app_wdata <= 512'd0;
        app_mask  <= 64'd0;
    end
    else begin
        if((s_app_wdf_rdy == 1'b1) && (s_app_wdf_wren == 1'b1))begin
            app_wdata <= s_app_wdf_data;
            app_mask  <= s_app_wdf_mask;
        end
    end
end

always @(posedge clk ) begin
    if(rst == 1'b1)begin
        w_addr_flag <= 2'b0;
    end
    else begin
        if(curr_state == IDLE)begin
            w_addr_flag <= 2'b0;
        end
        else begin
            if((curr_state == WRITE) && (m_app_rdy == 1'b1) && ((m_app_en == 1'b1)))begin
                w_addr_flag <= w_addr_flag + 2'd1;
            end
        end
    end
end

always @(posedge clk ) begin
    if(rst == 1'b1)begin
        w_data_flag <= 2'b0;
    end
    else begin
        if(curr_state == IDLE)begin
            w_data_flag <= 2'b0;
        end
        else begin
            if((curr_state == WRITE) && (m_app_wdf_rdy == 1'b1) && (m_app_wdf_wren == 1'b1))begin
                w_data_flag <= w_data_flag + 2'd1;
            end
        end
    end
end

always @(posedge clk ) begin
    if(rst == 1'b1)begin
        r_flag <= 1'b0;
    end
    else begin
        if(curr_state == IDLE)begin
            r_flag <= 1'b0;
        end
        else begin
            if((curr_state == READ) && (m_app_rdy == 1'b1))begin
                r_flag <= !r_flag;
            end
        end
    end
end
 
assign waddr = w_addr_flag == 2'b0 ? app_addr : app_addr_a32;
assign wdata = w_data_flag == 2'b0 ? app_wdata[255:0] : app_wdata[511:256];
assign wmask = w_data_flag == 2'b0 ? app_mask[31:0] : app_mask[63:32];

assign raddr = r_flag == 1'b0 ? app_addr : app_addr_a32;

assign m_app_addr     = (curr_state == WRITE) ? waddr : raddr;
assign m_app_cmd      = (curr_state == WRITE) ? 3'b000 : 3'b001;
assign m_app_en       = ((curr_state == WRITE) && (w_addr_flag < 2'd2)) || (curr_state == READ);
assign m_app_wdf_data = wdata;
assign m_app_wdf_end  = (curr_state == WRITE) && (w_data_flag < 2'd2);
assign m_app_wdf_mask = wmask;
assign m_app_wdf_wren = (curr_state == WRITE) && (w_data_flag < 2'd2);

always @(posedge clk ) begin
    if(rst == 1'b1)begin
        r_d_c <= 2'b0;
    end
    else begin
        if(m_app_rd_data_valid == 1'b1)begin
            if(r_d_c == 2'b1)begin
                r_d_c <= 2'd0;
            end
            else begin
                r_d_c <= r_d_c + 1'b1;
            end
        end
    end
end

always @(posedge clk ) begin
    if(rst == 1'b1)begin
        r_data <= 512'd0;
    end
    else begin
        if(m_app_rd_data_valid == 1'b1)begin
            r_data <= {m_app_rd_data, r_data[511:256]};
        end
    end
end

always @(posedge clk ) begin
    if(rst == 1'b1)begin
        r_valid <= 1'b0;
    end
    else begin
        r_valid <= (m_app_rd_data_valid == 1'b1) && (r_d_c == 1'b1);
    end
end

assign s_app_rd_data       = r_data ;
assign s_app_rd_data_end   = r_valid;
assign s_app_rd_data_valid = r_valid;
    
endmodule