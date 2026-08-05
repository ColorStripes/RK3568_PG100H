module ip_checksum(
  input           clk            ,
  input           rst            ,

  input           en             ,

  input   [3:0]   IP_ver         ,
  input   [3:0]   IP_hdr_len     ,
  input   [7:0]   IP_tos         ,
  input   [15:0]  IP_total_len   ,
  input   [15:0]  IP_id          ,
  input           IP_rsv         ,
  input           IP_df          ,
  input           IP_mf          ,
  input   [12:0]  IP_frag_offset ,
  input   [7:0]   IP_ttl         ,
  input   [7:0]   IP_protocol    ,
  output  [15:0]  checksum       ,
  input   [31:0]  src_ip         ,
  input   [31:0]  dst_ip         

     
);

  reg  [19 : 0] suma;
  wire [16 : 0] sumb;

  always@(posedge clk) begin
        if(rst) begin
            suma <= 32'd0;
        end
        else if(en) begin
            suma <= 20'd0 + {4'd0, IP_ver, IP_hdr_len, IP_tos} + {4'd0, IP_total_len} + {4'd0, IP_id} + {4'd0, IP_rsv, IP_df, IP_mf, IP_frag_offset} 
                    + {4'd0, IP_ttl, IP_protocol} + {4'd0, src_ip[31:16]} + {4'd0, src_ip[15:0]} + {4'd0, dst_ip[31:16]} + {4'd0, dst_ip[15:0]};
        end
  end


  assign sumb = suma[19 : 16] + suma[15 : 0];
  assign checksum = ~(sumb[16] + sumb[15 : 0]);


endmodule