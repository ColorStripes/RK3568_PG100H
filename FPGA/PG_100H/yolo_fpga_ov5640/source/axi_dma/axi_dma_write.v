module axi_dma_write
	#(
		parameter 		BURST_LEN 	= 8		,
		parameter       ID_WIDTH  	= 4		,
		parameter       DATA_WIDTH 	= 128	,
		parameter       KEEP_WIDTH  = DATA_WIDTH / 8	
	)
	(
	input 				clk 			,    // Clock
	input 				rst 			,    // Synchronous reset active high
	
	//cmd interface
	input       	 					cmd_valid		,
	input 			[31:0] 				cmd_addr		,
	input 			[31:0] 				cmd_len			,
	input			[ID_WIDTH - 1:0]    cmd_id          ,
	output reg  	    				cmd_ready		,

	//trans data in
	input 			[DATA_WIDTH - 1:0]  data_in      	,
	input			[KEEP_WIDTH - 1:0]	data_in_keep	,
	input         						data_in_valid	,
	output reg                          data_in_last    ,
	output        						data_in_ready	,

	//axi w
	output reg		[ID_WIDTH - 1:0]   			m_axi_awid   	,
	output reg		[31:0]  					m_axi_awaddr 	,
	output reg		[7:0]   					m_axi_awlen  	,
	output 			[2:0]   					m_axi_awsize 	,
	output 			[1:0]   					m_axi_awburst	,
	output 		    	    					m_axi_awlock 	,
	output 			[3:0]   					m_axi_awcache	,
	output 			[2:0]   					m_axi_awprot	,
	output reg		        					m_axi_awvalid	,
	input  		 	        					m_axi_awready	,
	output 			[DATA_WIDTH - 1:0] 			m_axi_wdata		,
	output 			[KEEP_WIDTH - 1:0]  		m_axi_wstrb		,
	output 			        					m_axi_wlast		,
	output 			        					m_axi_wvalid	,
	input  			        					m_axi_wready	,
	input  			[ID_WIDTH - 1:0]   			m_axi_bid  		,
	input  			[1:0]   					m_axi_bresp 	,
	input  			        					m_axi_bvalid	,
	output 			        					m_axi_bready	

);


localparam AXI_BURST_SIZE = $clog2(KEEP_WIDTH); //log2(DATA_WIDTH / 8)

wire [DATA_WIDTH - 1:0] 		t_m_axi_wdata;	
wire [KEEP_WIDTH - 1:0]  		t_m_axi_wstrb;	
wire         					t_m_axi_wlast;	
wire         					t_m_axi_wvalid;
wire         					t_m_axi_wready;

//common para
assign m_axi_awsize 	= 		AXI_BURST_SIZE	;
assign m_axi_awburst 	= 		2'b01			;
assign m_axi_awlock 	= 		1'b0			;
assign m_axi_awcache 	= 		4'b0011			;
assign m_axi_awprot 	= 		3'b000			;


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
		if((m_axi_awvalid == 1'b1) && (m_axi_awready == 1'b1))begin
			addr <= addr + ((m_axi_awlen + 1'b1) << AXI_BURST_SIZE);
		end
	end
end

always @(posedge clk) begin 
	if((cmd_ready == 1'b1) && (cmd_valid == 1'b1))begin
		len <= cmd_len[31:AXI_BURST_SIZE] + (|cmd_len[AXI_BURST_SIZE - 1:0]);
	end
	else begin
		if((m_axi_awvalid == 1'b1) && (m_axi_awready == 1'b1))begin
			len <= len - (m_axi_awlen + 1'b1);
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
			if((m_axi_bready == 1'b1) && (m_axi_bvalid == 1'b1) && (len == 32'd0))begin
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
		if((m_axi_awvalid == 1'b1) && (m_axi_awready == 1'b1))begin
			burst_trans <= 1'b1;
		end
		else begin
			// if((m_axi_wvalid == 1'b1) && (m_axi_wready == 1'b1) && (m_axi_wlast == 1'b1))begin
			if((m_axi_bvalid == 1'b1) && (m_axi_bready == 1'b1))begin
				burst_trans <= 1'b0;
			end
		end
	end
end
always @(posedge clk)begin
	if(rst == 1'b1)begin
		m_axi_awvalid <= 1'b0;
	end
	else begin
		if((m_axi_awvalid == 1'b1) && (m_axi_awready == 1'b1))begin
			m_axi_awvalid <= 1'b0;
		end
		else begin
			if((burst_trans == 1'b0) && (len != 32'd0))begin
				m_axi_awvalid <= 1'b1;
			end
		end
	end
end

always @(posedge clk)begin
	m_axi_awlen <= max_burst_len - 8'd1;
end
always @(posedge clk)begin
	m_axi_awaddr <= addr;
end
always @(posedge clk) begin 
	if((cmd_ready == 1'b1) && (cmd_valid == 1'b1))begin
		m_axi_awid <= cmd_id;
	end
end
//w
reg [7:0] act_burst_len;
always@ (posedge clk)begin
	if(rst == 1'b1)begin
		act_burst_len <= 8'd0;
	end
	else begin
		if((m_axi_awvalid == 1'b1) && (m_axi_awready == 1'b1))begin
			act_burst_len <= m_axi_awlen + 8'd1;
		end
		else begin
			if((t_m_axi_wvalid == 1'b1) && (t_m_axi_wready == 1'b1))begin
				act_burst_len <= act_burst_len - 8'd1;
			end
		end
	end
end

stream_pipe #(
  .DATA_WIDTH 	(DATA_WIDTH+1+KEEP_WIDTH)	
) stream_pipe_3(
  .dataIn_valid     (t_m_axi_wvalid),
  .dataIn_ready     (t_m_axi_wready),
  .dataIn_payload   ({t_m_axi_wdata, t_m_axi_wstrb, t_m_axi_wlast}),
  .dataOut_valid    (m_axi_wvalid),
  .dataOut_ready    (m_axi_wready),
  .dataOut_payload  ({m_axi_wdata, m_axi_wstrb, m_axi_wlast}),
  .clk              (clk),
  .reset            (rst)
);

assign data_in_ready = t_m_axi_wready  && act_burst_len > 8'd0;
assign t_m_axi_wvalid  = data_in_valid && act_burst_len > 8'd0;
assign t_m_axi_wdata   = data_in;
assign t_m_axi_wlast   = act_burst_len == 8'd1;
assign t_m_axi_wstrb   = data_in_keep;

//b
reg w_done;
always @(posedge clk) begin
	if(rst == 1'b1) begin
		w_done <= 1'b0;
	end
	else begin
		if((t_m_axi_wvalid == 1'b1) && (t_m_axi_wready == 1'b1) && (t_m_axi_wlast == 1'b1)) begin
			w_done <= 1'b1;
		end
		else begin
			if((m_axi_bvalid == 1'b1) && (m_axi_bready == 1'b1)) begin
				w_done <= 1'b0;
			end
		end
	end
end
assign m_axi_bready = w_done;

always @(posedge clk ) begin
	if(rst == 1'b1)begin
		data_in_last <= 1'b0;
	end
	else begin
		data_in_last <= (m_axi_bvalid == 1'b1) && (m_axi_bready == 1'b1) && (len == 32'd0);
	end
end

endmodule 