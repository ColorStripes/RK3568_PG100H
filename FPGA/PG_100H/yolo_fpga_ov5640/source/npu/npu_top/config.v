///////////////////////////////////寄存器配置（寄存器的配置必须考虑所有模块）//////////////////////////////////////
`define CHA_PAR_IN              16                           //输入通道并行度
`define CHA_PAR_OUT             16                           //输出通道并行度
//图片数据//
`define MAX_IN_COL             640                          //输入的IMG的最大列数
`define MAX_IN_ROW             640                          //输入的IMG的最大行数
//图片通道//
`define CHA_IMG_IN             512                         //输入的IMG的最大通道数
`define CHA_IMG_OUT            512                         //输出的IMG的最大通道数
//尺度，zero，data数据位宽
`define INT                      8
`define SCALE_WIDTH             16                          //scale的位数
//weight数据
`define WEIGHT_LEN           131072
`define WEIGHT33_LEN         37268
`define WEIGHT_SUM           296960
//BIAS拼接个数
`define BIAS_NUM                 2
//DMA传输字节数
`define MAX_IN_LEN           10240                       //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
`define MAX_OUT_LEN          10240                       //此模块所接受的最大字节数  也就是一行*所有输出通道的字节数   不是！最大通道*最大行数=最大长度


///////////////////////////////////对外输出配置（配置必须考虑所有模块输出大小）//////////////////////////////////////
`define MAX_OUT_COL            320                                    //输出的IMG的最大列数
`define MAX_OUT_ROW            320                                    //输出的IMG的最大行数
`define READ_DELAY             1                                      //读出数据所需要的延迟




///////////////////////////////////CONV33配置//////////////////////////////////////
//并行度//
`define CONV33_CHA_PAR_IN           16                         //输入通道并行度
`define CONV33_CHA_PAR_OUT          8                          //输出通道并行度
//图片数据//        
`define CONV33_MAX_IN_COL           320                        //输入的IMG的最大列数
`define CONV33_MAX_IN_ROW           320                        //输入的IMG的最大行数
`define CONV33_MAX_OUT_COL          320                        //输出的IMG的最大列数
`define CONV33_MAX_OUT_ROW          320                        //输出的IMG的最大行数
//图片通道//        
`define CONV33_CHA_IMG_IN           128                        //输入的IMG的最大通道数
`define CONV33_CHA_IMG_OUT          256                        //输出的IMG的最大通道数
//weight数据
`define CONV33_WEIGHT_LEN           32768
`define CONV33_WEIGHT_SUM           296960
//偏置位宽//        
`define CONV33_BIAS_NUM             2                          //一行拼接的bias个数
//尺度位宽//        
`define CONV33_SCALE_WIDTH          16                         //scale的位数
//一行数据的最大字节数//        
`define CONV33_MAX_IN_LEN           5120                      //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
`define CONV33_MAX_OUT_LEN          5120                      //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
//conv的乘法器延迟          
`define CONV33_MUL_DELAY            4           


///////////////////////////////////CONV11配置//////////////////////////////////////
//并行度//
`define CONV11_CHA_PAR_IN           16                         //输入通道并行度
`define CONV11_CHA_PAR_OUT          2                          //输出通道并行度
//图片数据//        
`define CONV11_MAX_IN_COL           160                        //输入的IMG的最大列数
`define CONV11_MAX_IN_ROW           160                        //输入的IMG的最大行数
`define CONV11_MAX_OUT_COL          160                        //输出的IMG的最大列数
`define CONV11_MAX_OUT_ROW          160                        //输出的IMG的最大行数
//图片通道//        
`define CONV11_CHA_IMG_IN           512                        //输入的IMG的最大通道数
`define CONV11_CHA_IMG_OUT          256                        //输出的IMG的最大通道数
//weight数据
`define CONV11_WEIGHT_LEN           131072
`define CONV11_WEIGHT_SUM           133120
//偏置位宽//        
`define CONV11_BIAS_NUM             2                          //一行拼接的bias个数
//尺度位宽//        
`define CONV11_SCALE_WIDTH          16                         //scale的位数
//一行数据的最大字节数//        
`define CONV11_MAX_IN_LEN           10240                     //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
`define CONV11_MAX_OUT_LEN          6000                      //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
//conv的乘法器延迟          
`define CONV11_MUL_DELAY            4           



///////////////////////////////////CONV配置//////////////////////////////////////
//并行度//
`define CONV_CHA_PAR_IN           16                         //输入通道并行度
`define CONV_CHA_PAR_OUT          2                          //输出通道并行度
//图片数据//        
`define CONV_MAX_IN_COL           320                        //输入的IMG的最大列数
`define CONV_MAX_IN_ROW           320                        //输入的IMG的最大行数
`define CONV_MAX_OUT_COL          320                        //输出的IMG的最大列数
`define CONV_MAX_OUT_ROW          320                        //输出的IMG的最大行数
//图片通道//        
`define CONV_CHA_IMG_IN           512                        //输入的IMG的最大通道数
`define CONV_CHA_IMG_OUT          256                        //输出的IMG的最大通道数
//weight数据
`define CONV_WEIGHT_LEN           131072
`define CONV_WEIGHT33_LEN         32768
`define CONV_WEIGHT_SUM           296960
//偏置位宽//        
`define CONV_BIAS_NUM             2                          //一行拼接的bias个数
//尺度位宽//        
`define CONV_SCALE_WIDTH          16                         //scale的位数
//一行数据的最大字节数//        
`define CONV_MAX_IN_LEN           10240                      //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
`define CONV_MAX_OUT_LEN          10240                       //此模块所接受的最大字节数  也就是一行*所有输出通道的字节数   不是！最大通道*最大行数=最大长度
//conv的乘法器延迟          
`define CONV_MUL_DELAY            4                         




///////////////////////////////////CAT_ADD配置//////////////////////////////////////
//并行度//
`define CAT_ADD_CHA_PAR_IN       16                     //输入通道并行度
//图片数据// 
`define CAT_ADD_MAX_IN_ROW       160                    //输入的IMG的最大行数
//图片通道// 
`define CAT_ADD_CHA_IMG_IN       256                   //输入的IMG的最大通道数
//尺度位宽// 
`define CAT_ADD_SCALE_WIDTH      16                     //scale的位数
`define CAT_ADD_SCALE_FRACTION_WIDTH  15                //scale的小数位数
//一行数据的最大字节数// 
`define CAT_ADD_MAX_IN_LEN       5120                  //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
//读出数据所需要的延迟 
`define CAT_ADD_READ_DELAY       1                      
//乘法器延迟  
`define CAT_ADD_MUL_DELAY        4


///////////////////////////////////SPPF配置//////////////////////////////////////
//并行度//
`define SPPF_CHA_PAR_IN        16                       //输入通道并行度
`define SPPF_CHA_PAR_OUT       16                       //输出通道并行度
//图片数据//
`define SPPF_MAX_IN_COL        20                       //输入的IMG的最大列数
`define SPPF_MAX_IN_ROW        20                       //输入的IMG的最大行数
//图片通道//
`define SPPF_CHA_IMG_IN        128                      //输入的IMG的最大通道数
//一行数据的最大字节数//       
`define SPPF_MAX_IN_LEN        2560                     //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度

///////////////////////////////////FOCUS配置//////////////////////////////////////
//并行度//
`define FOCUS_CHA_PAR_IN        16                   //输入通道并行度
`define FOCUS_CHA_PAR_OUT       16                   //输出通道并行度
//图片数据//
`define FOCUS_MAX_IN_ROW        640                   //输入的IMG的最大行数
//图片通道//
`define FOCUS_CHA_IMG_IN        3                    //输入的IMG的最大通道数
//一行数据的最大字节数//
`define FOCUS_MAX_IN_LEN        2560                   //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
 //读出数据所需要的延迟
`define FOCUS_READ_DELAY        1         


///////////////////////////////////UPSAMPLE配置//////////////////////////////////////
//并行度//
`define UPSAMPLE_CHA_PAR_IN     16                      //输入通道并行度
//图片数据// 
`define UPSAMPLE_MAX_IN_ROW     40                     //输入的IMG的最大行数
//图片通道//  
`define UPSAMPLE_CHA_IMG_IN     128                     //输入的IMG的最大通道数
//一行数据的最大字节数//  
`define UPSAMPLE_MAX_IN_LEN     2560                    //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
//读出数据所需要的延迟  
`define UPSAMPLE_READ_DELAY     1          