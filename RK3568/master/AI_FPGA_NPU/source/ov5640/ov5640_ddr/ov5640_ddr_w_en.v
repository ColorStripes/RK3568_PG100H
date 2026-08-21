module ov5640_ddr_w_en #(
    parameter DATA_WIDTH = 24
)(
    input          axi_clk      ,
    input          axi_rst      ,

    input          axi_cam_en   ,

    input  [DATA_WIDTH-1 : 0]  s_data       ,
    input                      s_data_valid ,
    input                      s_hsync      ,
    input                      s_vsync      ,

    output [DATA_WIDTH-1 : 0]  m_data       ,
    output                     m_data_valid ,
    output                     m_hsync      ,
    output                     m_vsync      
);

localparam IDLE = 2'b01;
localparam DATA = 2'b10;

reg [1:0] curr_state;
reg [1:0] next_state;

reg [1:0] s_vsync_ff;
reg       s_vsync_rise;

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
            if(s_vsync_rise & axi_cam_en) begin
                next_state = DATA;
            end
            else begin
                next_state = IDLE;
            end
        end 
        DATA: begin
            if(s_vsync_rise) begin
                if(axi_cam_en) begin
                    next_state = DATA;
                end
                else begin
                    next_state = IDLE;
                end
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
        s_vsync_ff <= 2'b0;
    end
    else begin
        s_vsync_ff <= {s_vsync_ff[0], s_vsync};
    end
end

always @(posedge axi_clk) begin
    if(axi_rst)begin
        s_vsync_rise <= 1'b0;
    end
    else begin
        s_vsync_rise <= s_vsync_ff[0] & (~s_vsync_ff[1]);
    end
end

assign m_data       = s_data;
assign m_data_valid = s_data_valid & (curr_state == DATA);

assign m_vsync = s_vsync_rise & axi_cam_en;
    
endmodule