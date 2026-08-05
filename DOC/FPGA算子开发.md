# FPGA算子开发

## 2025.4.24

打算重构conv33



## 4.25

重构了conv33_in_buff， m的输出不受下级模块影响，默认就是下级模块可以在当前模块发出数据就可以接受 

![微信图片_20250426172742(1)](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/%E5%BE%AE%E4%BF%A1%E5%9B%BE%E7%89%87_20250426172742(1).jpg)



## 4.26

![11](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/11.jpg)



## 4.27

conv33_out_buf

![image-20250427175221437](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250427175221437.png)





## 5.10

conv33_in_ctl

![image-20250510164314304](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250510164314304.png)

![image-20250510164301683](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250510164301683.png)





## 5.11

conv33_weight

权重的排布与python中  这个函数的排布一样

![image-20250511234425412](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250511234425412.png)

![微信图片_20250511234308](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/%E5%BE%AE%E4%BF%A1%E5%9B%BE%E7%89%87_20250511234308.jpg)



## 5.12

conv33_conv

mul_last 表示最后一组数据进入乘法器

![微信图片_20250512223108](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/%E5%BE%AE%E4%BF%A1%E5%9B%BE%E7%89%87_20250512223108.jpg)

![微信图片_20250512224521](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/%E5%BE%AE%E4%BF%A1%E5%9B%BE%E7%89%87_20250512224521.jpg)





## 5.13

conv33_add

量化前非负的原因：（f3必须为正）

![image-20250513174343473](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250513174343473.png)

![image-20250513172513192](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250513172513192.png)





这就使得f3必须为正  f3为负的部分全部被清零



若f3全部为正 ，映射到【0,255】范围，与verliog代码中f3量化前为正的行为相同。

![image-20250513175317871](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250513175317871.png)

若f3有负数 ，映射到【-128,127】范围，则verilog代码会把负值全部清0，然后映射正数到【128,255】。





### add的m_last在stride时提前拉高

![image-20250514120314902](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250514120314902.png)

![image-20250514120200437](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250514120200437.png)







## 5.14（conv33测试）

### 数据集VOC

![image-20251018200438401](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251018200438401.png)





voc的图片数据集分类

![image-20251018201918192](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251018201918192.png)

得到训练集和测试集的结果

![image-20251018211242604](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251018211242604.png)





聚类

![image-20251018202736713](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251018202736713.png)

聚类结果

![image-20251018203200266](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251018203200266.png)





### 训练

数据集和 anchors路径选择

![image-20251018204439894](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251018204439894.png)

预训练权重

![image-20251018204655016](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251018204655016.png)



以上训练是用yolo原有网络训练，但是我们网络模型进行了简化，用这个文件进行训练

预训练权重用的自定义的模型权重

![image-20251018205357892](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251018205357892.png)

修改类别

![image-20260710011124497](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260710011124497.png)

![image-20260306142115665](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260306142115665.png)

训练的结果在 logs下， best_epoch_weights.pth 就是现在训练后的权重

![image-20251018210406002](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251018210406002.png)



### 量化

根据模型进行量化

![image-20251018212752741](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251018212752741.png)



### 提取量化后的每层参数，只有conv的参数，pth格式

![image-20251018213430842](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251018213430842.png)

![image-20251018213649879](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251018213649879.png)

![image-20251018213800175](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251018213800175.png)



### 提取层计算的结果torch文件pth格式

先获取pytorch打包好的权重文件![image-20250514212637373](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250514212637373.png)这个文件是量化后的**权重**



将打包的文件从pth格式转化为npy格式![image-20250514213025027](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250514213025027.png)

![image-20251023220542373](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251023220542373.png)



### 获得python和verilog的对比文件

这个必须在预测阶段才能提取中间结果

预测文件为

![image-20251028215722748](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251028215722748.png)



新的导出npy方式

```python
python export_npy.py \
  --model-path model_data/ccpd_crpd_quant.pth \
  --image 1.jpg \
  --out-dir ./npy
```

保存每一层的卷积完的特征图int8数据![image-20250514222216032](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250514222216032.png)



### 将比较文件和权重，数据文件转化为txt

将每一层的数据进行转化

![image-20250516141538113](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250516141538113.png)



### 仿真拿到的txt权重 数据

参数数据在每个层的文件夹下面的parameter

![image-20250516141931999](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250516141931999.png)

![image-20250516141916737](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250516141916737.png)

![image-20250516141742645](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250516141742645.png)

填个verilog TB的参数通过这个文件得来

![image-20250516142655286](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250516142655286.png)

### 仿真结果对比

![image-20250516142259967](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250516142259967.png)

![image-20250516142443566](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250516142443566.png)



### 上位机

#### 如果更换了量化权重

南无python中的每个层的参数scale zero   以及指令都需要重新生成 也就是需要重新运行 里面所有东西都需要重新生成![image-20251224151752485](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251224151752485.png)

#### VS层面

在python中的get_weight脚本中在加载量化权重的时候打断点debug  

![image-20251224151926944](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251224151926944.png)

查看三个head的scale和zero 交给VS的nms参数需要填写  但填写的是64位精度的 这就要我们在打包成npy之前打印scale的64位精度

![image-20251224155717649](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251224155717649.png)

![image-20251224152040203](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251224152040203.png)

还有将第一层的量化scale放到VS的load_img里面

![image-20251224161307762](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251224161307762.png)





python聚类的点 要复制到VS的地方

![image-20251224153237155](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251224153237155.png)

同样要是类别改变 那么类也需要改变

![image-20251224153318875](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251224153318875.png)





## 5.16

仿真  如果数据里面有高阻态Z  则经过reg不会传递给下一级  这个信号就卡死了

#### force

![image-20250514230004888](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250514230004888.png)

![image-20250514230141556](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250514230141556.png)

![image-20250514230159302](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250514230159302.png)



## 5.17

如果数据出现XXXXX   一般是reg的指针越界   很大情况是指针+1 但位数过多 +1后指针过界  要控制指针到达某个值时候 返回到0

![image-20250517212350464](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250517212350464.png)



r_ram_cnt   位数能表示的大于5  忘了回归指针了

![image-20250517225312058](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250517225312058.png)



测试完成  删除 out_buf中的 r_ready信号  多余



## 5.19

conv33算子利用率 z7100

![](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250519131026317.png)

![image-20250519131121100](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250519131121100.png)

![image-20250520154039885](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250520154039885.png)







8进4出

![image-20250519174003724](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250519174003724.png)

![image-20250519174020865](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250519174020865.png)



## 5.20

乘法策略更改：

这个解释是 为什么要加上C这个符号位补偿

![image-20250520173051729](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250520173051729.png)

![image-20250520173112316](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250520173112316.png)



1.2的conv_mul减少一半LUT

![image-20250520182409994](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250520182409994.png)



1.2无ip版本 下降更多

![image-20250521140455512](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250521140455512.png)





## 5.21（conv11）

conv33加入bias pingpang

![image-20250522003704231](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250522003704231.png)



## 5.23

对conv11的测试结果 1.1mul结果不准确  用1.2mul结果很准   

conv3层的数据和结果对不上 可能是python代码有问题  其他层没有问题

对conv11加上了bias 乒乓  

**修改并行度需要在top里更改才能看到，不能再tb_top里更改无效**





16进16出的情况下，1*1卷积消耗

![image-20250523205352549](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250523205352549.png)

### 

### 改进计划（已测试 无影响） conv33和conv11里面没设置呢

因为add里面的SCALE_MUL的DSP占用挺多的  DATA_WIDTH可以固定位DSP48E1的25位位宽  这样它就固定只使用1个DSP资源

![image-20250523231829749](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250523231829749.png)



可以固定位宽的主要原因是  这个数据的位宽是不超过25位的   如果IN_DATA_WIDTH大于等于25  就不能固定25位位宽进行，否则会使数据阶段，符号位消失

![image-20250523232511968](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250523232511968.png)





改进完之后的conv11消耗

![image-20250523235112960](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250523235112960.png)







## 5.25

完成了conv33和conv11的融合模块conv  修改了动态并行度的仿真  但是未综合测试  需要修改conv33的bias的拼接模式  python未调通

现在荣获模块在conv11上运行无误





## 5.26

**$clog2(1)  这边返回是0**真奇怪

添加了BIAS_NUM参数  指示一行拼接bias个数



conv完成所有测试

16进8出资源消耗：

![image-20250527000012617](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250527000012617.png)

![image-20250527000957990](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250527000957990.png)





## 5.27

conv8的python数据已经把bias数据拼接为一行2个





## 5.29

ADD算子建立  未测试



## 5.30

ADD算子测试完成

修改output逻辑：加快req 但是出来的data不受状态机约束

```
    //下级数据请求信号   这样提高了速度 但是数据是不受状态机的RDATA约束
    reg fifo_req;
    always @(posedge clk ) begin
        if(rst)begin
            fifo_req <= 1'b0;
        end
        else if(wen) begin    //有数据进来就拉低
            fifo_req <= 1'b0;
        end
        else if(m_valid & m_ready & m_last) begin
            fifo_req <= 1'b1;
        end
        else if(empty) begin
            fifo_req <= 1'b1;
        end
    end
    
    assign ping_m_req = (r_ctl == 1'b0) ? fifo_req : 1'b0;
    assign pang_m_req = (r_ctl == 1'b1) ? fifo_req : 1'b0;

    wire [DATA_WIDTH : 0] din;
    assign din = (r_ctl == 1'b0) ? {ping_m_last, ping_m_data} : {pang_m_last, pang_m_data};
    wire wen = (r_ctl == 1'b0) ? ping_m_valid : pang_m_valid;




////////////////////////////////////////从ctl的FIFO读出到DMA/////////////////////////////

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
      .din(din),      // input wire [64 : 0] din
      .wr_en(wen),  // input wire wr_en
      .rd_en(ren),  // input wire rd_en
      .dout(dout),    // output wire [64 : 0] dout
      .full(full),    // output wire full
      .empty(empty)   // output wire empty
    );

    assign m_valid = !empty & (state == RDATA);
    assign m_last = dout[DATA_WIDTH];
    assign m_data = dout[DATA_WIDTH-1 : 0];

```

原本的output：受RDATA状态约束

```
    //下级数据请求信号
    reg fifo_req;
    always @(posedge clk ) begin
        if(rst)begin
            fifo_req <= 1'b0;
        end
        else if((state == WADDR) && (next_state == RDATA)) begin
            fifo_req <= 1'b1;
        end
        else if(wen) begin    //有数据进来就拉低
            fifo_req <= 1'b0;
        end
    end
    
    assign ping_m_req = (r_ctl == 1'b0) ? fifo_req : 1'b0;
    assign pang_m_req = (r_ctl == 1'b1) ? fifo_req : 1'b0;

    wire [DATA_WIDTH : 0] din;
    assign din = (r_ctl == 1'b0) ? {ping_m_last, ping_m_data} : {pang_m_last, pang_m_data};
    wire wen = (r_ctl == 1'b0) ? (ping_m_valid && (state == RDATA)) : (pang_m_valid && (state == RDATA));




////////////////////////////////////////////从ctl的FIFO读出到DMA/////////////////////////////////

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
      .din(din),      // input wire [64 : 0] din
      .wr_en(wen),  // input wire wr_en
      .rd_en(ren),  // input wire rd_en
      .dout(dout),    // output wire [64 : 0] dout
      .full(full),    // output wire full
      .empty(empty)   // output wire empty
    );

    assign m_valid = !empty;
    assign m_last = dout[DATA_WIDTH];
    assign m_data = dout[DATA_WIDTH-1 : 0];

```

![image-20250530234740244](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250530234740244.png)







## 6.1

对sync_fifo进行改进  让它用BRAM生成降低LUT

out_buf的LUT降低

![image-20250601210733919](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250601210733919.png)

​       

in_ctrl 的这两个参数才是DEPTH的深度  而不是最大通道*最大宽度  因为有点宽度小 通道多  字节数平衡

MAX_IN_LEN = 5120,             //此模块所接受的最大字节数  也就是一行*所有通道的字节数

DATA_DEPTH = MAX_IN_LEN / CHA_PAR_IN,     //数据深度  这里是 W*channal/输入并行度  RAM总容量应该大于一行数据所需字节个数

重新改这些





## 6.2

upsample结束

现在是2输入concat，需要22融合  提升速度的话要求4输入concat

![image-20250602153039132](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250602153039132.png)

最大池化完成





## 6.6

focus算子完成   

接受640*640 * 4（3+1） 补全一通道  

输出320 * 320 *  16 （12 + 4 ） 通道

![image-20250606001224395](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250606001224395.png)

AXI位宽128位固定 

 修改python内容:

```python
def focus(path):
    #结果
    torch_path = r"F:\python\yolov5\npy\img.int.npy"
    torch_result = np.load(torch_path)
    torch_temp = np.full((1, 4, 320, 320), 0, dtype=int)
    torch_result = np.concatenate((torch_result, torch_temp), axis=1)
    torch_to_txt(path + r"\focus_torch.txt", torch_result)

    #初始图片处理
    img_path = r"F:\python\yolov5\npy\quant.int.npy"
    img = np.load(img_path)
    img_temp = np.full((1, 1, 640, 640), 0, dtype=int)
    img = np.concatenate((img, img_temp), axis=1)
    quant_to_txt(path + r"\focus_in_data.txt", img)          #保存特征图

```

![image-20250606001036336](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250606001036336.png)



起来吧 FPGA算子





## 6.7（FPGA算子融合）

```verilog
    //conv
    input          type             ,                   //1 is 1*1 ; 0 is 3*3
    input          start            ,
    input          stride           ,

    input  [COL_WIDTH : 0]   col_num          , //col_num = col
    input  [ROW_WIDTH : 0]   row_num          ,

    input  [CALULATE_CNT_WIDTH : 0]      calculate_num         ,
    input  [IN_CALULATE_CNT_WIDTH : 0]   calculate_cin_num     ,
    input  [OUT_CALULATE_CNT_WIDTH : 0]  calculate_cout_num    ,

    input  [CHA_IN_WIDTH : 0]   channel_in_num   ,
    input  [CHA_OUT_WIDTH : 0]  channel_out_num  ,

    input  [SCALE_WIDTH-1 : 0]  scale_3            ,
    input  [INT-1 : 0]  zero_1            ,
    input  [INT-1 : 0]  zero_3            ,

    input  [31:0]  s_addr      ,            //特征图数据输入地址
    input  [IN_LEN_WIDTH : 0]  in_col_channel_num  , //col_channel_num = col * channel



    input  [31:0]  m_addr      ,            //计算完成特征图数据输入地址
    input  [OUT_LEN_WIDTH : 0]  out_col_channel_num  , //col_channel_num = col * channel

    output         calculate_end         ,

    //focus
    input          start            ,
    input  [IN_LEN_WIDTH : 0]   in_col_channel_num   , //col_channel_num = col * channel
    input  [OUT_LEN_WIDTH : 0]  out_col_channel_num  , 
    input  [ROW_WIDTH : 0]      row_num          ,

    input  [31:0]  s_addr      ,            //特征图数据输入地址
    input  [31:0]  m_addr      ,            //计算完成特征图数据输入地址

    output         calculate_end         ,


    //cat_add
    input          start            ,
    input          type             ,

    input  [IN_LEN_WIDTH : 0]   in_col_channel_num   , //col_channel_num = col * channel
    input  [OUT_LEN_WIDTH : 0]  out_col_channel_num  , //type 1 is col_channel_num = col * channel * 2; type 0 is col_channel_num = col * channel
    input  [ROW_WIDTH : 0]     row_num          ,

    //输入通道计算次数
    input  [IN_CALULATE_CNT_WIDTH : 0] calculate_cin_num,


    input  [SCALE_WIDTH-1 : 0] scale_1,
    input  [SCALE_WIDTH-1 : 0] scale_2,
    input  [SCALE_WIDTH*2-1 : 0] scale_3,
    input  [INT-1 : 0] zero_1        ,
    input  [INT-1 : 0] zero_2        ,


    input  [31:0]  s_addr_0      ,            //特征图数据输入地址
    input  [31:0]  s_addr_1      ,            //特征图数据输入地址

    input  [31:0]  m_addr      ,            //计算完成特征图数据输入地址



    //sppf
    input          start            ,
    
    input  [COL_WIDTH : 0]   col_num          , //col_num = col
    input  [ROW_WIDTH : 0]   row_num          ,

    input  [IN_CALULATE_CNT_WIDTH : 0]   calculate_cin_num     ,
    input  [OUT_CALULATE_CNT_WIDTH : 0]  calculate_cout_num    ,

    input  [31:0]  s_addr      ,            //特征图数据输入地址
    input  [IN_LEN_WIDTH : 0]  in_col_channel_num  , //col_channel_num = col * channel


    input  [31:0]  m_addr      ,            //计算完成特征图数据输入地址
    input  [OUT_LEN_WIDTH : 0]  out_col_channel_num  , //col_channel_num = col * channel
```







## 6.9

进行out_buf共用

共用之前

focus资源：

![image-20250609214100482](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250609214100482.png)



conv资源：

![image-20250609220820923](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250609220820923.png)

cat_add:

![image-20250609223036762](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250609223036762.png)

sppf:

![image-20250609225204235](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250609225204235.png)





### 融合out_buf:

区别：

cat_add和conv:

buf：

![image-20250609232622385](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250609232622385.png)

out_ctrl：

![image-20250609233029091](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250609233029091.png)

![image-20250609233045434](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250609233045434.png)

top：和上面一样





conv和focus：

buf：与上一致

out_ctrl：与上一致

top：与上一致







conv和sppf：

buf：一致

out_ctrl：一致

top：一致





## 6.10

start信号的含义：

strat【0】 conv   1

strat【1】cat_add 2

strat【2】sppf 4

strat【3】upsample 8 

strat【4】focus 16



type信号的含义：

type【0】 conv33      1

type【1】 conv11       2

type【2】 add             4

type【3】 cat   			8

type【4】sppf			 16

type【5】upsample		32

type【6】focus				64





## 6.12

<img src="https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250612135331073.png" alt="image-20250612135331073" style="zoom:150%;" />





修改了scale_unsigned里面的32位乘法策略  让拆分乘法步骤让vivado综合成两个DSP资源 加法用了少量LUT实现

<img src="https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250613001056622.png" alt="image-20250613001056622" style="zoom:150%;" />



## 6.16

修改了conv_weight的存储策略  每次只取一小部分weight  这个模块需要bias_len来定位第一次取的长度

对应python也需要修改 这个是将weight文件重拍成小部分策略   这样每次取每个点的前cha_par_out个核的前cha_par_in个通道

![image-20250616234928762](C:/Users/14017/AppData/Roaming/Typora/typora-user-images/image-20250616234928762.png)









**现在目前所有的start都是一直拉高控制  但是各算子不是 需要调整各算子的start信号的策略**





## 6.17

weight换成输出并行度向DMA取回 

![image-20250617172558499](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250617172558499.png)

7ffffc9,0000306,000100b,000078f,7ffffc5,0000115,000014c,7ffff19,0000226,0000851,7fff777,0000f30,7fff98c,000008f,7fffdcf,7fff949

7ffffc9,0000306,000100b,000078f,7ffffc5,0000115,000014c,7ffff19,0000226,0000851,7fff777,0000f30,7fff98c,000008f,7fffdcf,7fff949





conv11出现问题  原因是我weight取回的数据时间太长  再我pingpang两组数据都用完了 一组数据还没回来     

修改：

![image-20250617231319873](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250617231319873.png)

![image-20250617231332327](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250617231332327.png)







![image-20250619175300558](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250619175300558.png)

## 6.20

### PCIE基础知识学习

虚拟地址即DMA地址映射

![img](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/v2-270862938a45ec1db7844b88acdbfa67_r.jpg)



## 6.22

### DDR基本知识

![image-20250622214503345](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250622214503345.png)

- DDR芯片到用户端的时钟是 4 ：1     也就是DDR3为800M时  用户端是200M  用户端最多只能是200M  当DDR3超出800M时 那就是DDR3的事情  用户端还是200M

- 对于上面的比例  则   用户端传输 128bit时   DDR3位宽是16bit  也就是8 ： 1的关系  为什么呢？

  200M * 128 == 800 * 2 * 16   DDR是上下时钟延都采样 就是数据速率是时钟速率的Double 

### MIG IP

![image-20250622215324763](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250622215324763.png)

Ultra这块板子用两个16bit合成一个32bit输出

![image-20250622215451728](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250622215451728.png)

芯片选择 ：MT40A512M16HA-083E



地址位宽： bank地址 + 行地址 + 列地址

容量：![image-20250622232022864](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250622232022864.png)



### AXI DataMover

![image-20250623160731175](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250623160731175.png)

字段映射：

USER：对于 MM2S 块，此字段中写入的值显示在 m_axi_mm2s_aruser 上，对于 S2MM 块，则显示在 m_axi_s2mm_awuser 上。

CACHE：  对于 MM2S 块，此字段中写入的值显示在 m_axi_mm2s_arcache 上，对于 S2MM 块，则显示在 m_axi_s2mm_awcache 上。

**上面两个信号一般不启用**   并且 不启用后是72位 （32位地址情况）

![image-20250625173158830](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250625173158830.png)

RSVD： 保留

TAG：此字段是用户分配给命令的任意值。TAG 流经 DataMover 执行管道，并插入到命令的相应状态字中

SADDR：此字段指示用于命令请求的传输的内存映射端的起始地址  **这个会根据AXI的寻址地址空间增长而增长**

DRR：地址对齐DRE

EOF：帧结束

DSA：仅当关联命令的 DRR 位也设置为 1 时，才使用该字段。这个 6 位字段表示可选 DRE 的 MM2S 流数据通道的参考对齐。该值是 byte-lane relative。值为 0 表示字节通道 0（最低有效字节）是参考字节通道;值 1 表示字节通道 1，依此类推。有效值取决于流数据通道的参数化数据宽度。例如，一个 32 位宽的数据通道只有 4 字节的通道位置，因此 DSA 字段只能有 0 到 3 的值。

TYPR：此字段确定 AXI4 访问的类型。将此项设置为 1 将启用 INCR。值 0 启用 FIXED 地址 AXI4 事务。

BTT：此 23 位字段表示要传输的总字节数。传输范围为 1 到 8,388,607 字节。不允许值为 0，这会导致 DataMover 出现内部错误。数据移动器实际使用的 BTT 位数分别由 MM2S 和 S2MM 的“BTT 字段宽度”参数控制。



（**Indeterminate BTT**这是S2MM特有的模式，在不确定突发长度的情况下使用，命令就不用传输BTT位）



![image-20250624141531987](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250624141531987.png)

![image-20250624141502461](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250624141502461.png)

![image-20250624155009172](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250624155009172.png)



#### BTT错误

![image-20250626131056478](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250626131056478.png)



STS有时候会报内部错误  原因就是BTT所指示的字节数和keep&data联合起来送入的字节数不匹配



### AXI_DAM

有考虑过这个  但是他不支持我们写入CMD命令





### axi_interconnect

![image-20250623231845693](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250623231845693.png)

可以跨时钟域传输数据   可以传输不一样的带宽数据

但是需要配置M主机的clk   还有每个S从机的CLK分别是多少  复位信号





## 6.27

封装ip

![image-20250627005824570](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250627005824570.png)

rst极性修改：

![image-20250627221411880](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250627221411880.png)





## 6.28

#### 以太网部署

![image-20250628212702486](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250628212702486.png)

![image-20250628214715643](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250628214715643.png)

![image-20250628214108258](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250628214108258.png)

![image-20250628214324258](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250628214324258.png)

![image-20250701214415015](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250701214415015.png)

![image-20250628181110781](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250628181110781.png)

![image-20250628181159880](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250628181159880.png)

![image-20250628223942003](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250628223942003.png)

![image-20250628182121710](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250628182121710.png)

![image-20250628182734974](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250628182734974.png)



MAC地址段： 赛灵思：00_0a_35_xxxxxx





IP报文：

![image-20250630150301269](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250630150301269.png)



![image-20250701220847053](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250701220847053.png)

![image-20250701221230121](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250701221230121.png)

![image-20250701221254293](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250701221254293.png)







UDP报文

![image-20250703211109086](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250703211109086.png)





### IODDR

两种模式：

**此图是输入的时序：rx**

![image-20250629171556867](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250629171556867.png)

![image-20250629171526209](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250629171526209.png)

**此图是输除的时序：tx**

![image-20250629171739161](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250629171739161.png)

![image-20250629171811185](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250629171811185.png)





### PHY芯片时序

![image-20250913195558422](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250913195558422.png)



 默认TX的时钟和数据是同步的

RX时钟比数据要晚1.2ns

![image-20250913210501158](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250913210501158.png)



PHY芯片短包能发送 长报UDP截断 是因为时序不满足  主时钟报红色 会导致认为的是300M 但实际291长包叠加会导致时序偏移采样出错

![image-20250916212318161](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250916212318161.png)



## 7.3

**重大发现：** 

仿真中时序逻辑仿真成组合逻辑：

没有用非阻塞赋值仿真信号

[(4 封私信) 急问！为什么FPGA的<=语句在这种情况下不延迟一拍？ - 知乎 (zhihu.com)](https://www.zhihu.com/question/279664328)

[小梅哥Verilog语法常见知识讲解_哔哩哔哩_bilibili](https://www.bilibili.com/video/BV1HT4y1f7Rz/?spm_id_from=333.999.0.0&vd_source=e7edfd809b7893b3db9fc076565313c3)







## 7.24

UDP开发优化：

在mac_tx中加入乒乓缓存，FIFO边读边写，在fifo输出完后，状态机FINISH转移。这就导致必须FIFO清空才能进行下一次数据接入，否则有可能导致fifo溢出，接收两次报文的空闲周期很长。所以引入乒乓。

![image-20250724175046662](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250724175046662.png)





我在udp模块中预留了可变loca——ip接口

![image-20250724215216891](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250724215216891.png)





![image-20250730232451248](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250730232451248.png)

![image-20250813035632635](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250813035632635.png)





## 8.20

调试UDP  ila没了 时钟不稳定问题  还有就是上电后等一会儿再烧录

每次调试 要按rst键位保证UPD的上升沿采样稳定  要不采样的分隔符是DD





## 8.22

罪魁祸首是  网线是百兆的呜呜呜  只有千兆网线才能通过千兆测试  D5采样成DD是因为百兆网线的数据长度长  上升沿和下降沿都采样到一个数据

![image-20250822022225056](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250822022225056.png)



破文档数据写错了

![image-20250823132330381](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250823132330381.png)





## 9.12（IP打包引用）

![image-20250912215125861](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250912215125861.png)

![image-20250912215146861](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250912215146861.png)





移植Block design

原工程下打开Block

```tcl
write_bd_tcl ./my_bd.tcl
```

目的工程

```tcl
source ./my_bd.tcl
```





![image-20250917175956984](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250917175956984.png)



UDP用户数据缓存的地址位数不够达到16位的len长度 所以一直不会last

![image-20250918210022138](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250918210022138.png)





## 9.19

因为empty要在读取之后才拉高 导致valid晚拉低一个时钟周期 会多读多有一个有效数据一个数据

![image-20250919202203874](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250919202203874.png)

修改：

![image-20250919201602649](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250919201602649.png)





## 9.22

第一次综合

![image-20250922192400272](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250922192400272.png)





## 9.29

python以conv8为例修改 顺序不能变

![image-20250929193921123](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20250929193921123.png)





## 10.5

修改out_buf  这么写是因为conv的输出并行度 和 输出并行度 不一样 导致spram有一半没用 深度按原始conv输出并行度算

![image-20251005191155356](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251005191155356.png)





## 10.9

仲裁策略修改 因为data interconnect的策略是优先级相同，所以在in_ctr里面加入判断是否可以接受数据 才发送有效cmd

![image-20251009153118560](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251009153118560.png)

同样的out_ctrl 如果fifo不是空的 就可向外发送有效CMD

![image-20251009153259096](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251009153259096.png)



但是weight的数据cmd的发出 状态机已经判断可以容纳数据所以不用

![image-20251009153508037](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251009153508037.png)





## 10.21

中间有几天没更新了 因为调试的过程总是痛苦的  我有好几天找不到bug在哪里  因为在datamover里面的CMD通道ready不拉高不是我能控制的  秉持着官方IP没错的前提下 上板插入ILA探针终于找到了我datamover cmd STS通道问题



探针只是一直在M_AXI报overflow

![image-20251021160730366](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251021160730366.png)



实际上主要问题是我在自定义IP核里面 cmd通道在STS通道数据还没有回来的时候 直接把cmd_valid直接传给下级也就是datamover  导致datamover传递多次cmd命令，但数据值传递一次 所以datamover卡死，所以改动就是让自定义模块传递给下级的指令受状态机控制

![image-20251021161140988](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251021161140988.png)





### IP重新打包

搜索要打包的IP 点击如下 在新建工程里修改源码不会修改原有GUI

![image-20251021171858866](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251021171858866.png)



## 10.22

这样才能被识别

![image-20251022173614953](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251022173614953.png)

![image-20251023225856293](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251023225856293.png)



## 10.25

cat_add 的last改为 读取了last才拉高 没读取不拉高

![image-20251025202708395](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251025202708395.png)



受cat的整数1影响 加入小数位数选取

![image-20251025202757809](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251025202757809.png)





## 10.30

npu_ddr_all的资源占用

![image-20251030192757548](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251030192757548.png)





npu_ddr

![image-20251030210112715](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251030210112715.png)





## 11.4

更新了目前可上板验证的版本yolo_top  包括两种Block design

npu_ddr_all 有三个完整的AXI_datamover也就是三对CMD写入读出

npu_ddr_all 有两个个完整的AXI_datamover和一个M2SS  也就是两对CMD写入读出  和 一对CMD读

有两个自定义IP S2MM_CMD 和MM2S_CMD



此外python方面weight是16进8出的排列方式



上位机方面 有逐层验证的版本debug版 和 一次性执行所有指令的版本







clk_ddr: 125Mh进入时钟

![image-20251104180011299](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251104180011299.png)





## 11.19

更新让所有层计算结束后 再向PC传递04

要设置总共所有算子的启动次数

![image-20251119152334450](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251119152334450.png)

这个开启的话就是FPGA自己控制 如果这层结束就开始下一层计算  

![image-20251119152451263](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251119152451263.png)

Debug版本可以不启动这个 然后可以软件控制开始计算  取出每一层的结果对比







### 目前有两种控制方式

- 第一种： 软件控制每层指令读取![image-20251119155415329](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20251119155415329.png)每层结束都重新开始指令加载

- 第二种：识别到每层结束，自己开始读取下一层指令







## 12.21

instruction 先进来的是高位

ddr 先进来的是低位



## 12.28

时序优化

report_qor_assessmnet





# HPPY_NEW YEAR

## 1.3

算子并行

start信号的含义：

strat【0】 conv  1

strat【1】cat_add 2

strat【2】sppf 4

strat【3】upsample 8 

strat【4】focus 16

strat【5】conv2 32





type信号的含义：

type【0】 conv33      1

type【1】 conv11       2

type【2】 add             4

type【3】 cat   			8

type【4】sppf			 16

type【5】upsample		32

type【6】focus				64

type【7】cat_add 旁路   128

未并行前

![image-20260104155942389](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260104155942389.png)







## 1.18

双算子指令生成 

![image-20260118222556251](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260118222556251.png)



### 双算子问题

红色指令与蓝色指令冲突，红色的是conv cat需要的数据地址 要保留，add却先修改了 将add的输出地址改为要保留的第一个conv的虚拟地址（黄色）

![image-20260124163530764](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260124163530764.png)



模型冲突：

cat和add的0通道 是承接conv的  但是python中模型的concat和add的1通道是承接conv的，且concat 0和1通道拼接顺序和权重要匹配





## 1.24

python模型不变

临时交换cat的两个输入数据接口

![image-20260125003226562](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260125003226562.png)



## 1.25

python模型更改

目前并行cat 0通道与conv相接  

conv conv cat 只能与1通道相连 conv conv add是0通道相连的







# 3.4

为了三算子并行不停止指令，因为cat也是基础指令，所以识别是不是并行的type 并行type指令依然发送



![image-20260304194153087](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260304194153087.png)

![image-20260308200828847](C:/Users/14017/AppData/Roaming/Typora/typora-user-images/image-20260308200828847.png)



# 3.9

conv_mul的精度进行了调整

![image-20260313151848631](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260313151848631.png)



out_buf进行了无间隔调度 不用乒乓调度 让计算请求一直拉高

![image-20260313152002780](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260313152002780.png)



# 3.11

对指令缓存模块增加重新回读功能 只用输入一次指令就可以多次运算

![image-20260313152622710](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260313152622710.png)



为udp2npu添加FPGA的时钟计数器  计数值会打包进以太网END信号的后4字节中

![image-20260313152731073](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260313152731073.png)



**关键修改**

这里传入模型的总层数，可以配置网络模型层数

![image-20260313152802802](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260313152802802.png)



# 3.13

将原本的weight_len改为weight_sum

weight_len的含义改变，变成卷积核的一个点的所有的字节，这是为了匹配一次性拿取全部的权重数据 因此排布方式也要改变



**改变了权重量化方式**

原本是节省型量化 0-127  现在是0-255

![image-20260313213518575](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260313213518575.png)





# 3.14

修改sppf和conv循环行队列里面的valid的延迟策略，这样的话可以应对计算req一直拉高的情况 而导致的 数据valid的拉低间隔短 导致与行数据填充的延迟valid与数据刚进来的valid相与 导致下级误判valid拉高

![image-20260314194215280](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260314194215280.png)





# AN5642

![image-20260316204640425](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260316204640425.png)





![image-20260316204817399](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260316204817399.png)

 ![image-20260316205648195](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260316205648195.png)

![image-20260316211111690](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260316211111690.png)

![image-20260316234622980](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260316234622980.png)



I2C状态机1-

![image-20260317134138589](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260317134138589.png)
