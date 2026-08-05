module out_buf_ctrl #(
    parameter AXI_DATA_WIDTH = 32,
              AXI_ADDR_WIDTH = 32,
    parameter CHA_PAR_OUT = 8,                                      //输出通道并行度
              CHA_IMG_OUT = 128,                                    //图片输出最大通道数
              INT = 8,                                              //每个数的位宽
              //conv
              CONV_CHA_PAR_OUT = 8,
              CONV_DATA_WIDTH  = CONV_CHA_PAR_OUT * INT,
              MAX_CALULATE_NUM = (CHA_IMG_OUT / CONV_CHA_PAR_OUT),       //计算次数
              CALULATE_CNT_WIDTH = $clog2(MAX_CALULATE_NUM),
              MAX_OUT_LEN = 5120,                                   //此模块所输出的最大字节数  也就是输出一行*通道的字节数
              LEN_WIDTH = $clog2(MAX_OUT_LEN),
              MAX_OUT_ROW = 320,                                    //输出的IMG的最大行数
              ROW_WIDTH = $clog2(MAX_OUT_ROW),
              DATA_WIDTH = CHA_PAR_OUT * INT,                       //数据传输位宽    输出并行度 * INT8
              DATA_DEPTH = MAX_OUT_LEN / CHA_PAR_OUT                //数据深度  这里是 W*channal/并行度  RAM总容量应该大于一行数据所需字节个数

)
(
    input         clk              ,
    input         rst              ,

    input         conv_start       ,
    input         start            ,
    input [6 : 0] type             ,
    input         stride           ,                            //0为1步长 1为2步长
    
    input  [AXI_ADDR_WIDTH-1 : 0]       base_addr,              //写内存的起始基地址
    input  [LEN_WIDTH : 0]              out_col_channel_num,    //m_data_len   输出一行的数据
    input  [ROW_WIDTH : 0]              row_num,
    input  [CALULATE_CNT_WIDTH : 0]     calculate_cout_num,     //输出通道计算次数=输出通道数/输出并行度    


    //当前模块接受数据
    //CHA_PAR_OUT个输出
    input  [DATA_WIDTH-1 : 0]         s_data  ,
    input                             s_valid,
    input                             s_last ,
    output                            s_req,                  //req是有数进就拉低请求的是一行 ready是有数进 请求的是一个 进到最后一个才拉低   


    //fifo向下级模块输出数据
    output [DATA_WIDTH-1 : 0]   m_data ,
    output                      m_last ,
    output                      m_valid,
    input                       m_ready, 

    //ping接受数据
    output [DATA_WIDTH-1 : 0]   ping_s_data    ,
    output                      ping_s_valid  ,
    output                      ping_s_last   ,
    input                       ping_s_req  ,

    //ping向fifo输出数据
    input  [DATA_WIDTH-1 : 0]   ping_m_data   ,
    input                       ping_m_valid  ,
    input                       ping_m_last   ,
    output                      ping_m_req    ,


    output [DATA_WIDTH-1 : 0]   pang_s_data    ,
    output                      pang_s_valid  ,
    output                      pang_s_last   ,
    input                       pang_s_req    ,


    input  [DATA_WIDTH-1 : 0]   pang_m_data   ,
    input                       pang_m_valid  ,
    input                       pang_m_last   ,
    output                      pang_m_req    ,
   

    //指令数据
    output  [AXI_ADDR_WIDTH-1 : 0]      cmd_addr      ,
    output  [AXI_DATA_WIDTH-1 : 0]      cmd_len       ,
    output                              cmd_valid     ,
    input                               cmd_ready     ,

    output                      calculate_end ,
    input                       calculate_end_receive             
);



    //状态机
    localparam IDLE = 4'b0001, WADDR = 4'b0010, RDATA = 4'b0100, WAIT = 4'b1000;
    reg [3 : 0] state, next_state;
    always @(posedge clk) begin
        if(rst) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case(state)
            IDLE:begin
                if(start) begin
                    next_state = WADDR;
                end
                else begin
                    next_state = IDLE;
                end
            end
            WADDR:begin                                     //告诉DMA从哪里读  W代表写给DMA
                if(cmd_valid & cmd_ready) begin
                    next_state = RDATA;
                end
                else begin
                    next_state = WADDR;
                end
            end
            RDATA:begin                                      //从当前模块读出往DMA中写数据
                if(m_valid & m_ready & m_last) begin         //FIFO读出最后一个才跳转  读fifo信号才有影响
                    next_state = WAIT;                      //所有状态机的跳转  往FIFO写的时候的last和valid都不会影响
                end
                else begin
                    next_state = RDATA;
                end
            end
            WAIT:begin
                if(row_cnt == row_num_r) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = WADDR;
                end
            end
            default:begin
                next_state = IDLE;
            end
        endcase
    end


//////////////////////////////////////////////////////行列控制////////////////////////////////////////////////////////
    //行控制
    reg [ROW_WIDTH : 0] row_cnt;
    always @(posedge clk ) begin
        if(rst) begin
            row_cnt <= 0;
        end
        else if(state == IDLE) begin
            row_cnt <= 0;
        end
        else if(m_last & m_valid & m_ready) begin
            row_cnt <= row_cnt + 1;
        end
    end

    reg [ROW_WIDTH : 0] row_num_r;
    always @(posedge clk ) begin
        if(start) begin
            if(type[6]) begin
                row_num_r <= row_num[ROW_WIDTH : 1];
            end
            else if(type[5]) begin
                row_num_r <= {row_num, 1'b0};
            end
            else if(type[0] && stride) begin
                row_num_r <= row_num[ROW_WIDTH : 1];
            end
            else begin
                row_num_r <= row_num;
            end 
        end
    end


/////////////////////////////////CMD命令///////////////////////////////////////////
    //内存写地址定位
    reg [31 : 0] data_addr;
    always @(posedge clk) begin
        if(start) begin
            data_addr <= base_addr;
        end
        else if(cmd_valid & cmd_ready) begin
            data_addr <= data_addr + out_col_channel_num;
        end
    end
    assign cmd_addr = data_addr;

    reg cmd_valid_r;
    always @(posedge clk ) begin
        if(rst) begin
            cmd_valid_r <= 1'b0;
        end
        else if(!empty && (next_state == WADDR)) begin
            cmd_valid_r <= 1'b1;
        end
        else if(cmd_valid & cmd_ready) begin
            cmd_valid_r <= 1'b0;
        end    
    end
    assign cmd_valid = cmd_valid_r;

    reg [LEN_WIDTH : 0] cmd_len_r;
    always @(posedge clk ) begin
        if(start)begin
            cmd_len_r <= out_col_channel_num;
        end
    end
    assign cmd_len = cmd_len_r;


///////////////////////////////计算信号相关////////////////////////////////////////
    //计算次数控制
    (*mark_debug = "true"*)reg [CALULATE_CNT_WIDTH : 0]  calculate_cout_cnt;
    always @(posedge clk ) begin
        if(rst) begin
            calculate_cout_cnt <= 0;
        end
        // else if(start) begin
        //     calculate_cout_cnt <= 0;
        // end
        else if(s_last & s_valid) begin
            if(calculate_cout_cnt == calculate_cout_num_r - 1) begin
                calculate_cout_cnt <= 0;
            end
            else begin
                calculate_cout_cnt <= calculate_cout_cnt + 1;
            end
        end
    end

    (*mark_debug = "true"*)reg [CALULATE_CNT_WIDTH : 0]  calculate_cout_num_r;
    always @(posedge clk ) begin
        if(start)begin
            calculate_cout_num_r <= calculate_cout_num;
        end
    end




    





////////////////////////////////////////////从上级读入到乒乓BUF/////////////////////////////////////////////////////////////////
    //写控制器
    (*mark_debug = "true"*)reg w_ctl;
    always @(posedge clk ) begin
        if(rst) begin
            w_ctl <= 1'b0;
        end
        else if(s_last && s_valid && (calculate_cout_cnt == calculate_cout_num_r - 1)) begin
            w_ctl <= !w_ctl;
        end
    end


    //分频器  为了使valid出现1010这样交替的频率
    reg s_valid_d;
    always @(posedge clk) begin
        if(rst)begin
            s_valid_d <= 1'b0;
        end
        else begin
            s_valid_d <= s_valid;
        end
    end

    reg alter_cross;
    always @(posedge clk) begin
        if(rst) begin
            alter_cross <= 1'b1;
        end
        else if(stride) begin
            if(s_valid) begin
                if(~s_valid_d) begin
                    alter_cross <= 1'b0;
                end
                else begin
                    alter_cross <= !alter_cross;
                end
            end
        end
        else begin
            alter_cross <= 1'b1;
        end
    end

    

    assign ping_s_data = (w_ctl == 1'b0) ? s_data : 0;
    assign ping_s_valid = (w_ctl == 1'b0) ? s_valid & alter_cross : 1'd0;
    assign ping_s_last  = (w_ctl == 1'b0) ? s_last & ping_s_valid : 1'd0;


    assign pang_s_data = (w_ctl == 1'b1) ? s_data : 0;
    assign pang_s_valid = (w_ctl == 1'b1) ? s_valid & alter_cross : 1'd0;
    assign pang_s_last  = (w_ctl == 1'b1) ? s_last & pang_s_valid : 1'd0;

    // assign s_req = (w_ctl == 1'b0) ? ping_s_req : pang_s_req;
    assign s_req = ping_s_req | pang_s_req;

    // assign ping_s_data = (w_ctl == 1'b0) ? s_data : 0;
    // assign ping_s_valid = (w_ctl == 1'b0) ? s_valid : 1'd0;
    // assign ping_s_last  = (w_ctl == 1'b0) ? s_last & ping_s_valid : 1'd0;


    // assign pang_s_data = (w_ctl == 1'b1) ? s_data : 0;
    // assign pang_s_valid = (w_ctl == 1'b1) ? s_valid : 1'd0;
    // assign pang_s_last  = (w_ctl == 1'b1) ? s_last & pang_s_valid : 1'd0;

    // assign s_req = (w_ctl == 1'b0) ? ping_s_req : pang_s_req;
    


////////////////////////////////////////////从乒乓BUF读入到ctl的FIFO/////////////////////////////////////////////////////////////////

    //读控制器
    (*mark_debug = "true"*)reg r_ctl;
    always @(posedge clk ) begin
        if(rst) begin
            r_ctl <= 1'b0;
        end
        else if(wen & din[DATA_WIDTH])begin
            r_ctl <= !r_ctl;
        end
    end

    // //下级数据请求信号
    // reg fifo_req;
    // always @(posedge clk ) begin
    //     if(rst)begin
    //         fifo_req <= 1'b0;
    //     end
    //     else if((state == WADDR) && (next_state == RDATA)) begin
    //         fifo_req <= 1'b1;
    //     end
    //     else if(wen) begin    //有数据进来就拉低
    //         fifo_req <= 1'b0;
    //     end
    // end

    
    
    // assign ping_m_req = (r_ctl == 1'b0) ? fifo_req && (state == RDATA) : 1'b0;
    // assign pang_m_req = (r_ctl == 1'b1) ? fifo_req && (state == RDATA) : 1'b0;

    // wire [DATA_WIDTH : 0] din;
    // assign din = (r_ctl == 1'b0) ? {ping_m_last, ping_m_data} : {pang_m_last, pang_m_data};
    // wire wen = (r_ctl == 1'b0) ? (ping_m_valid && (state == RDATA)) : (pang_m_valid && (state == RDATA));


    //FIFO堵塞控制
    localparam ADDR_WIDTH = $clog2(DATA_DEPTH);
    // reg [ADDR_WIDTH-1 : 0] fifo_cnt;
    // always @(posedge clk) begin
    //     if(rst)begin
    //         fifo_cnt <= {ADDR_WIDTH{1'b0}};
    //     end
    //     else if(wen & ~ren)begin
    //         fifo_cnt <= fifo_cnt + 1'b1;
    //     end
    //     else if(~wen & ren)begin
    //         fifo_cnt <= fifo_cnt - 1'b1;
    //     end
    // end

    wire [ADDR_WIDTH : 0] fifo_cnt;
    //下级数据请求信号   这样提高了速度 但是数据是不受状态机的RDATA约束
    reg fifo_req;
    always @(posedge clk ) begin
        if(rst)begin
            fifo_req <= 1'b0;
        end
        else if(wen) begin    //有数据进来就拉低
            fifo_req <= 1'b0;
        end
        // else if(fifo_cnt < (DATA_DEPTH-2)) begin
        else if(DATA_DEPTH - fifo_cnt >= out_col_channel_num/CHA_PAR_OUT) begin
            fifo_req <= 1'b1;
        end
        // else if(empty) begin
        //     fifo_req <= 1'b1;
        // end
    end
    
    assign ping_m_req = (r_ctl == 1'b0) ? fifo_req : 1'b0;
    assign pang_m_req = (r_ctl == 1'b1) ? fifo_req : 1'b0;




    wire [DATA_WIDTH-1 : 0] data;
    assign data = (r_ctl == 1'b0) ? ping_m_data : pang_m_data;
    wire valid = (r_ctl == 1'b0) ? ping_m_valid : pang_m_valid;
    wire last  = (r_ctl == 1'b0) ? ping_m_last : pang_m_last;

    localparam CNT_WIDTH = ((CHA_PAR_OUT / CONV_CHA_PAR_OUT) == 1) ? 1 : $clog2(CHA_PAR_OUT / CONV_CHA_PAR_OUT);
    reg [CNT_WIDTH-1 : 0] conv_cnt;
    always @(posedge clk) begin
        if(rst) begin
            conv_cnt <= 0;
        end
        else if(conv_start) begin
            if(DATA_WIDTH == CONV_DATA_WIDTH) begin
                conv_cnt <= 0;
            end
            else if(valid) begin
                conv_cnt <= conv_cnt + 1'b1;
            end
        end
        else begin
            conv_cnt <= 0;
        end
    end

    reg [DATA_WIDTH-1 : 0] conv_data;
    always @(posedge clk) begin
        if(conv_start) begin
           if(DATA_WIDTH == CONV_DATA_WIDTH) begin
                conv_data <= data;
            end
            else if(valid) begin
                conv_data <= {data, conv_data[DATA_WIDTH-1 : CONV_DATA_WIDTH]};
            end 
        end
        else begin
            conv_data <= data;
        end
    end

    reg conv_valid;
    always @(posedge clk) begin
        if(rst) begin
            conv_valid <= 1'b0;
        end
        else if(conv_start) begin
            if(conv_cnt == (CHA_PAR_OUT / CONV_CHA_PAR_OUT)-1)begin
                conv_valid <= valid;
            end
            else begin
                conv_valid <= 1'b0;
            end
        end
        else begin
            conv_valid <= valid;
        end
    end

    reg conv_last;
    always @(posedge clk) begin
        conv_last <= last;
    end





    // wire [DATA_WIDTH : 0] din;
    // assign din = {conv_last, conv_data};
    // wire wen = conv_valid;
    reg                  wen;
    always @(posedge clk) begin
        if (rst) begin
            wen <= 1'b0;
        end 
        else begin
            wen <= conv_valid;
        end
    end

    reg [DATA_WIDTH : 0] din;
    always @(posedge clk) begin
        din <= {conv_last, conv_data};
    end



    // wire [DATA_WIDTH : 0] din;
    // assign din = (r_ctl == 1'b0) ? {ping_m_last, ping_m_data} : {pang_m_last, pang_m_data};
    // wire wen = (r_ctl == 1'b0) ? ping_m_valid : pang_m_valid;








////////////////////////////////////////////从ctl的FIFO读出到DMA/////////////////////////////////////////////////////////////////

    //这里用了0延迟同步FIFO 因为DMA的ready不是一直拉高的  在DMAready拉低的情况下要反压ren使地址不能输出
    //如果读有延迟 ready反压的时候 radd已经出去的 但ready是反压的上一个raadr 就使得raddr有一个地址的数据没有被DMA接受
    
    wire [DATA_WIDTH : 0] dout;
    wire ren = m_valid & m_ready;
    sync_fifo  #(
        .DATA_WIDTH(DATA_WIDTH + 1),
        .DATA_DEPTH(DATA_DEPTH)
    ) 
    sync_fifo_inst(
      .clk(clk),      // input wire clk
      .rst(rst),     // input wire rst
      .fifo_cnt(fifo_cnt),
      .din(din),      // input wire [64 : 0] din
      .wr_en(wen),  // input wire wr_en
      .rd_en(ren),  // input wire rd_en
      .dout(dout),    // output wire [64 : 0] dout
      .full(full),    // output wire full
      .empty(empty)   // output wire empty
    );

    assign m_valid = !empty & (state == RDATA);
    assign m_last = dout[DATA_WIDTH] & m_valid;
    assign m_data = dout[DATA_WIDTH-1 : 0];








    ///////////////////////////////////结束信号/////////////////////////////////////////////////
    // assign calculate_end  = ((state == WAIT) && (next_state == IDLE)) ? 1'b1 : 1'b0;

    reg calculate_end_r;
    always @(posedge clk) begin
        if(rst) begin
            calculate_end_r <= 1'b0;
        end
        else if(calculate_end & calculate_end_receive) begin
            calculate_end_r <= 1'b0;
        end
        else if((state == WAIT) && (next_state == IDLE)) begin
            calculate_end_r <= 1'b1;
        end
    end
    assign calculate_end = calculate_end_r;

endmodule