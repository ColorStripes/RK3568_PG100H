module axi_dma_read 
	#(
		parameter 		BURST_LEN 	= 8		,
		parameter       ID_WIDTH  	= 4		,
		parameter       DATA_WIDTH 	= 128	
	)
	(
	input 				clk 			,    // Clock
	input 				rst 			,    // Synchronous reset active high
	
	//cmd interface
	input        						    cmd_valid		,
	input 			[31:0] 				    cmd_addr		,
	input 			[31:0] 				    cmd_len			,
	input			[ID_WIDTH - 1:0]        cmd_id          ,
	output reg      					    cmd_ready		,
    
	//trans data in    
	output 			[DATA_WIDTH - 1:0] 	    data_out      	,
	output         						    data_out_valid	,
	output                                  data_out_last   ,
	input        						    data_out_ready	,

	//axi r
    output 	reg		[ID_WIDTH - 1:0]    	m_axi_arid 		,
    output 	reg		[31:0]  				m_axi_araddr	,
    output 	reg		[7:0]                 	m_axi_arlen		,
    output 			[2:0]                 	m_axi_arsize	,
    output 			[1:0]                 	m_axi_arburst	,
    output 			                      	m_axi_arlock	,
    output 			[3:0]                 	m_axi_arcache	,
    output 			[2:0]                 	m_axi_arprot	,
    output   reg                    		m_axi_arvalid	,	
    input                        			m_axi_arready	,
    input 			[ID_WIDTH - 1:0]   		m_axi_rid 		,
    input 			[DATA_WIDTH - 1:0]  	m_axi_rdata		,
    input 			[1:0]                	m_axi_rresp		,
    input                        			m_axi_rlast		,
    input                        			m_axi_rvalid 	,
    output                       			m_axi_rready

);


localparam AXI_BURST_SIZE = $clog2(DATA_WIDTH / 8); //log2(DATA_WIDTH / 8)

wire [ID_WIDTH - 1:0]   t_m_axi_rid    ;
wire [DATA_WIDTH - 1:0] t_m_axi_rdata  ;
wire [1:0]              t_m_axi_rresp  ;
wire                    t_m_axi_rlast  ;
wire                    t_m_axi_rvalid ;
wire                    t_m_axi_rready ;


//common para
assign m_axi_arsize 	= 		AXI_BURST_SIZE	;
assign m_axi_arburst 	= 		2'b01			;
assign m_axi_arlock 	= 		1'b0			;
assign m_axi_arcache 	= 		4'b0011			;
assign m_axi_arprot 	= 		3'b000			;


wire [7:0] burst_len    ;
wire [7:0] max_burst_len;

//cmd
reg [31:0] addr;
reg [31:0] len;
reg        trans;

always @(posedge clk) begin 
	if((cmd_ready == 1'b1) && (cmd_valid == 1'b1))begin
		addr <= cmd_addr;
	end
	else begin
		if((m_axi_arvalid == 1'b1) && (m_axi_arready == 1'b1))begin
			addr <= addr + ((m_axi_arlen + 1'b1) << AXI_BURST_SIZE);
		end
	end
end

always @(posedge clk) begin 
	if((cmd_ready == 1'b1) && (cmd_valid == 1'b1))begin
		len <= cmd_len[31:AXI_BURST_SIZE] + (|cmd_len[AXI_BURST_SIZE - 1:0]);
	end
	else begin
		if((m_axi_arvalid == 1'b1) && (m_axi_arready == 1'b1))begin
			len <= len - (m_axi_arlen + 1'b1);
		end
	end
end
always @(posedge clk)begin
	if(rst == 1'b1)begin
		trans <= 1'b0;
	end
	else begin
		if((cmd_ready == 1'b1) && (cmd_valid == 1'b1))begin
			trans <= 1'b1;
		end
		else begin
			if((t_m_axi_rvalid == 1'b1) && (t_m_axi_rready == 1'b1) && (t_m_axi_rlast == 1'b1) && (len == 32'd0))begin
				trans <= 1'b0;
			end
		end
	end
end

always @(posedge  clk)begin
	if(rst == 1'b1)begin
		cmd_ready <= 1'b0;
	end
	else begin
		if(trans == 1'b0)begin
			if((cmd_ready == 1'b1) && (cmd_valid == 1'b1))begin
				cmd_ready <= 1'b0;
			end
			else begin
				cmd_ready <= 1'b1;
			end
		end
		else begin
			cmd_ready <= 1'b0;
		end
	end
end

//aw

reg burst_trans;
assign burst_len     = len > BURST_LEN ? BURST_LEN : len;
assign max_burst_len = (((addr & 12'hfff) + (burst_len << AXI_BURST_SIZE )) >> 12)  != 0 ? (13'h1000 - (addr & 12'hfff)) >> AXI_BURST_SIZE : burst_len;
always@(posedge clk)begin
	if(rst == 1'b1)begin
		burst_trans <= 1'b0;
	end
	else begin
		if((m_axi_arvalid == 1'b1) && (m_axi_arready == 1'b1))begin
			burst_trans <= 1'b1;
		end
		else begin
			if((t_m_axi_rvalid == 1'b1) && (t_m_axi_rready == 1'b1) && (t_m_axi_rlast == 1'b1))begin
				burst_trans <= 1'b0;
			end
		end
	end
end
always @(posedge clk)begin
	if(rst == 1'b1)begin
		m_axi_arvalid <= 1'b0;
	end
	else begin
		if((m_axi_arvalid == 1'b1) && (m_axi_arready == 1'b1))begin
			m_axi_arvalid <= 1'b0;
		end
		else begin
			if((burst_trans == 1'b0) && (len != 32'd0))begin
				m_axi_arvalid <= 1'b1;
			end
		end
	end
end

always @(posedge clk)begin
	m_axi_arlen <= max_burst_len - 8'd1;
end
always @(posedge clk)begin
	m_axi_araddr <= addr;
end
always @(posedge clk) begin 
	if((cmd_ready == 1'b1) && (cmd_valid == 1'b1))begin
		m_axi_arid <= cmd_id;
	end
end

//w
reg [7:0] act_burst_len;
always@ (posedge clk)begin
	if(rst == 1'b1)begin
		act_burst_len <= 8'd0;
	end
	else begin
		if((m_axi_arvalid == 1'b1) && (m_axi_arready == 1'b1))begin
			act_burst_len <= m_axi_arlen + 8'd1;
		end
		else begin
			if((t_m_axi_rvalid == 1'b1) && (t_m_axi_rready == 1'b1))begin
				act_burst_len <= act_burst_len - 8'd1;
			end
		end
	end
end

assign t_m_axi_rready = data_out_ready && act_burst_len > 8'd0;
assign data_out_valid = t_m_axi_rvalid && act_burst_len > 8'd0;
assign data_out = t_m_axi_rdata;
assign data_out_last = (t_m_axi_rvalid == 1'b1) && (t_m_axi_rready == 1'b1) && (t_m_axi_rlast == 1'b1) && (len == 32'd0);


stream_pipe #(
  .DATA_WIDTH 	(DATA_WIDTH+1+2+ID_WIDTH)	
) stream_pipe_1(
  .dataIn_valid     (m_axi_rvalid),
  .dataIn_ready     (m_axi_rready),
  .dataIn_payload   ({m_axi_rdata, m_axi_rid, m_axi_rresp, m_axi_rlast}),
  .dataOut_valid    (t_m_axi_rvalid),
  .dataOut_ready    (t_m_axi_rready),
  .dataOut_payload  ({t_m_axi_rdata, t_m_axi_rid, t_m_axi_rresp, t_m_axi_rlast}),
  .clk              (clk),
  .reset            (rst)
);

endmodule 