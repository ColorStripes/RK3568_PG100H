module gen_traffic (
	input clk,    // Clock
	input rst,  // Synchronous reset active hign

	//cmd interface
	output        		cmd_valid		,
	output 		[31:0] 	cmd_addr		,
	output 		[31:0] 	cmd_len			,
	input 		      	cmd_ready		,

	//trans data in
	output 		[127:0] data_in      	,
	output      [15:0]  data_in_keep	,
	output         		data_in_valid	,
	input        		data_in_ready	
	
);
parameter len = 1024       ;
assign cmd_valid = 1'b1    ;
assign cmd_addr  = 32'd0;
assign cmd_len   = len - 1;

assign data_in_valid = 1'b1;

reg [7:0] cnt1;
always @(posedge clk)begin
	if(rst == 1'b1)begin
		cnt1 <= 8'd0;
	end
	else begin
		if((data_in_valid == 1'b1) && (data_in_ready == 1'b1))begin
			if(cnt1 == len - 8)begin
				cnt1 <= 8'd0;
			end
			else begin
				cnt1 <= cnt1 + 8'd8;
			end
		end
	end
end
reg [7:0] cnt2;
always @(posedge clk)begin
	if(rst == 1'b1)begin
		cnt2 <= 8'd1;
	end
	else begin
		if((data_in_valid == 1'b1) && (data_in_ready == 1'b1))begin
			if(cnt2 == (len - 7))begin
				cnt2 <= 8'd1;
			end
			else begin
				cnt2 <= cnt2 + 8'd8;
			end
		end
	end
end
reg [7:0] cnt3;
always @(posedge clk)begin
	if(rst == 1'b1)begin
		cnt3 <= 8'd2;
	end
	else begin
		if((data_in_valid == 1'b1) && (data_in_ready == 1'b1))begin
			if(cnt3 == (len - 6))begin
				cnt3 <= 8'd2;
			end
			else begin
				cnt3 <= cnt3 + 8'd8;
			end
		end
	end
end
reg [7:0] cnt4;
always @(posedge clk)begin
	if(rst == 1'b1)begin
		cnt4 <= 8'd3;
	end
	else begin
		if((data_in_valid == 1'b1) && (data_in_ready == 1'b1))begin
			if(cnt4 == (len - 5))begin
				cnt4 <= 8'd3;
			end
			else begin
				cnt4 <= cnt4 + 8'd8;
			end
		end
	end
end
reg [7:0] cnt5;
always @(posedge clk)begin
	if(rst == 1'b1)begin
		cnt5 <= 8'd4;
	end
	else begin
		if((data_in_valid == 1'b1) && (data_in_ready == 1'b1))begin
			if(cnt5 == (len - 4))begin
				cnt5 <= 8'd4;
			end
			else begin
				cnt5 <= cnt5 + 8'd8;
			end
		end
	end
end
reg [7:0] cnt6;
always @(posedge clk)begin
	if(rst == 1'b1)begin
		cnt6 <= 8'd5;
	end
	else begin
		if((data_in_valid == 1'b1) && (data_in_ready == 1'b1))begin
			if(cnt6 == (len - 3))begin
				cnt6 <= 8'd5;
			end
			else begin
				cnt6 <= cnt6 + 8'd8;
			end
		end
	end
end
reg [7:0] cnt7;
always @(posedge clk)begin
	if(rst == 1'b1)begin
		cnt7 <= 8'd6;
	end
	else begin
		if((data_in_valid == 1'b1) && (data_in_ready == 1'b1))begin
			if(cnt7 == len - 2)begin
				cnt7 <= 8'd6;
			end
			else begin
				cnt7 <= cnt7 + 8'd8;
			end
		end
	end
end
reg [31:0] cnt8;
always @(posedge clk)begin
	if(rst == 1'b1)begin
		cnt8 <= 32'd7;
	end
	else begin
		if((data_in_valid == 1'b1) && (data_in_ready == 1'b1))begin
			if(cnt8 == (len>>1) - 1)begin
				cnt8 <= 32'd7;
			end
			else begin
				cnt8 <= cnt8 + 32'd8;
			end
		end
	end
end
assign data_in = {{cnt8[7:0],cnt7,cnt6,cnt5,cnt4,cnt3,cnt2,cnt1},{cnt8[7:0],cnt7,cnt6,cnt5,cnt4,cnt3,cnt2,cnt1}};
assign data_in_keep = (cnt8 == (len>>1) - 1) ?16'h7fff: 16'hffff;

endmodule