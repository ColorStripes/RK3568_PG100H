#ifndef _CONFIG_GUI_H
#define _CONFIG_GUI_H

#include <stdio.h>      // C 标准输入输出，例如 printf / FILE
#include <stdint.h>     // 定宽整数类型，例如 uint32_t
#include <iostream>     // C++ 标准输入输出流，例如 cout / cin
#include <stdlib.h>     // 标准库函数，例如 malloc / free / exit
#include <string.h>     // 字符串处理函数，例如 memset / memcpy / strcmp
#include <unistd.h>     // UNIX/Linux 常用系统调用，如 read / write / close / usleep
#include <fcntl.h>      // 文件控制选项，如 open 的 O_RDWR / O_RDONLY 等
#include <sys/ioctl.h>  // ioctl 系统调用及相关宏定义
#include <time.h>       // 时间相关结构与函数，如 nanosleep / timespec
#include <pthread.h>    // POSIX 线程库
#include <sys/mman.h>   // 内存映射相关接口，如 mmap / munmap


#ifdef __cplusplus      // 如果当前头文件被 C++ 编译器编译

#define RX_MMAP_OFFSET (1 * 1024 * 1024UL)

extern "C" {            // 告诉 C++ 编译器：下面这些符号按 C 的方式导出，避免名字重整
#endif

#define NO_TEST                              // 测试开关宏：定义了但当前没附带具体值，通常用于条件编译
#define DEBUG                                // 调试开关宏：用于控制调试输出
//#define WIDGET_SPACE                       // 预留宏：控制 GUI 布局/控件间距，当前注释掉

#define PCIE_DRIVER_FILE_PATH           "/dev/pango_pci_driver" // PCIe 驱动设备节点路径
#define MEM_FILE_PATH                   "/dev/mem"              // 物理内存设备节点路径，用于直接 mmap 物理地址
#define VEISION                         "Pango PCIe Test v1.0"  // 软件版本字符串（这里宏名应为 VERSION，当前拼写是 VEISION）

#define TYPE                            'S'                     // ioctl 命令类型号，作为 _IOWR 的第一个参数
#define PCI_READ_DATA_CMD               _IOWR(TYPE, 0, int)     // ioctl：读取 PCI 配置空间/寄存器数据
#define PCI_WRITE_DATA_CMD              _IOWR(TYPE, 1, int)     // ioctl：写 PCI 配置空间/寄存器数据
#define PCI_MAP_ADDR_CMD                _IOWR(TYPE, 2, int)     // ioctl：申请 DMA 缓冲区并建立地址映射
#define PCI_WRITE_TO_KERNEL_CMD         _IOWR(TYPE, 3, int)     // ioctl：把用户态写缓冲拷到内核 DMA 缓冲
#define PCI_DMA_READ_CMD                _IOWR(TYPE, 4, int)     // ioctl：启动一次 DMA 读（通常是主机->设备）
#define PCI_DMA_WRITE_CMD               _IOWR(TYPE, 5, int)     // ioctl：启动一次 DMA 写（通常是设备->主机）
#define PCI_READ_FROM_KERNEL_CMD        _IOWR(TYPE, 6, int)     // ioctl：把内核 DMA 缓冲的数据拷回用户态
#define PCI_UMAP_ADDR_CMD               _IOWR(TYPE, 7, int)     // ioctl：释放 DMA 缓冲和地址映射
#define PCI_PERFORMANCE_START_CMD       _IOWR(TYPE, 8, int)     // ioctl：启动性能测试
#define PCI_PERFORMANCE_END_CMD         _IOWR(TYPE, 9, int)     // ioctl：结束性能测试并返回结果
#define PCI_MSI_WAIT_CMD                _IOWR(TYPE, 10, int)    // ioctl：等待 MSI 中断（实际中断，非轮询）
#define PCI_SET_CAM_CONFIG              _IOWR(TYPE, 11, int)						/* DMA自动搬运数据的设置 */
#define PCI_GET_IMG						_IOWR(TYPE, 12, int)						/* 获取图片数据 */
#define GPIO_CTRL  						_IOWR(TYPE, 13, int)						/*GPIO控制*/
#define PWM_CTRL  						_IOWR(TYPE, 14, int)						/*PWM控制*/
//NPU
#define PCI_GET_NPU                     _IOWR(TYPE, 15, int)                        /* 等待NPU推理完成（中断驱动，替代轮询） */



#define MAX_BLOCK_SIZE                  1024    // 单次块传输/缓存块的最大 DWORD 数
#define LINK_OK                         0x11    // 链路正常标志值
#define CRC_OK                          0xa00   // CRC 正确标志值
#define CRC_ERROR                       0xe00   // CRC 错误标志值
#define CRC_REPEAT                      0xf00   // CRC 重复/重复校验异常标志值
#define AXI_CONNECT_USER                0xa     // AXI 方向/连接到用户侧的标志
#define AXI_CONNECT_SWITCH              0xf     // AXI 方向/连接到交换侧的标志
#define LOAD_DATA_FINISH                0xa0    // 数据加载完成标志
#define LOAD_DATA_UNFINISH              0x00    // 数据加载未完成标志
#define BAR_OFFSET_1                    0x00    // BAR 偏移 1，通常用于窗口 1/寄存器块 1
#define BAR_OFFSET_2                    0x10    // BAR 偏移 2
#define BAR_OFFSET_3                    0x20    // BAR 偏移 3
#define PEFORMANCE_STATUS_OFFSET        0x00    // 性能测试状态寄存器偏移
#define PEFORMANCE_WRITE_CNT_OFFSET     0x04    // 性能测试写计数寄存器偏移
#define PEFORMANCE_READ_CNT_OFFSET      0x08    // 性能测试读计数寄存器偏移
#define PEFORMANCE_ERROR_CNT_OFFSET     0x0c    // 性能测试错误计数寄存器偏移
#define PEFORMANCE_DATA_CNT_OFFSET      0x10    // 性能测试数据量计数寄存器偏移

#define PAGE_ROUND_DOWN(x)              ((x) & ~(getpagesize() - 1))                  // 地址向下按页对齐
#define PAGE_ROUND_UP(x)                (PAGE_ROUND_DOWN((x) + getpagesize() - 1))    // 地址/长度向上按页对齐
#define file_len(len)                   ((len)%4 == 0 ? (len)/4 : ((len)/4)+1)        // 将字节长度换算为 DWORD 数（4字节对齐，向上取整）
#define BOOL_SWITCH(flag)               (((flag) == true) ? false : true)             // 布尔值翻转宏：true->false, false->true
#define DMA_MAX_PACKET_SIZE             4096                                           // DMA 单包最大字节数
#define DMA_MIN_PACKET_SIZE             4                                              // DMA 单包最小字节数

// 全局变量只做声明，不在头文件初始化！！！
// 下面这些 extern 表示：变量实体定义在某个 .c / .cpp 文件里，这里只是给其他源码文件引用

extern int pci_driver_fd;           // PCIe 驱动设备文件描述符
extern char *bit_file_name;         // bit 文件名（通常用于 FPGA 配置文件名）
extern char *dma_write_file_name;   // DMA 写入文件名
extern char *button_info;           // GUI 按钮信息/提示字符串




// 定义 C_GPIO 结构体，支持端口号、电平以及预留的 PWM 字段
typedef struct _C_GPIO_ {
    unsigned int gpio_num;      // GPIO 端口号 (从用户态传入)
    unsigned int level;         // 电平状态：0 或 1 (从用户态传入)
    
    // 以后可能更新的 PWM 命令内容预留
    unsigned int pwm_enable;    // PWM 使能开关 (0: 关闭, 1: 开启)
    unsigned int pwm_period;    // PWM 周期
    unsigned int pwm_duty;      // PWM 占空比
} C_GPIO;


// 摄像机参数配置结构体
#define MAX_SUPPORTED_CAM_BUFFS 4
typedef struct _CAM_CONFIG_ {
    unsigned int cam_size;                                  // 单帧相机数据大小 (例如 0x3f4800)
    unsigned int read_size;                                 // 单次 DMA 读取大小 (例如 0x3f4800)
    unsigned int buff_count;                                // 实际使用的缓冲区数量 (例如 2)
    unsigned int cam_buffer_addrs[MAX_SUPPORTED_CAM_BUFFS]; // 各个缓冲区的 DDR3 物理地址
} CAM_CONFIG;




typedef enum _OPERATION_NUM_ {
    write_num = 0,   // 写操作编号
    read_num,        // 读操作编号
    w_r_num,         // 读写混合/循环读写操作编号
    info_num,        // 设备信息读取编号
    tandem_num,      // 串行加载/级联加载编号
    performance_num  // 性能测试编号
} op_num;

enum bar_num {
    Bar0 = 0,  // BAR0
    Bar1,      // BAR1
    Bar2,      // BAR2
    Bar3,      // BAR3
    Bar4,      // BAR4
    Bar5       // BAR5
};

typedef struct _BAR_INFO_ {
    unsigned long bar_base;   // BAR 基地址（物理地址）
    unsigned long bar_len;    // BAR 长度（资源大小）
} BAR_BASE_INFO;

typedef struct _CAP_INFO_ {
    unsigned char flag;         // 当前 capability 节点是否有效
    unsigned char id;           // capability ID
    unsigned char addr_offset;  // 当前 capability 在配置空间中的偏移
    unsigned char next_offset;  // 下一个 capability 的偏移
} CAP_INFO;

typedef struct _CAP_LIST_ {
    unsigned char cap_status;   // capability list 是否存在：0不存在，1存在
    unsigned char cap_error;    // capability 链表解析是否出错
    CAP_INFO cap_buf[256];      // capability 缓冲区，按偏移索引保存各 capability 信息
} CAP_LIST;

typedef struct _PCI_INFO_ {
    unsigned int vendor_id;         // Vendor ID，厂商 ID
    unsigned int device_id;         // Device ID，设备 ID
    unsigned int cmd_reg;           // PCI Command 寄存器值
    unsigned int status_reg;        // PCI Status 寄存器值
    unsigned int revision_id;       // 修订版本号
    unsigned int class_prog;        // 编程接口字段
    unsigned int class_device;      // 设备类
    BAR_BASE_INFO bar[6];           // 6 个 BAR 的基址和长度信息
    unsigned int min_gnt;           // Min_Gnt
    unsigned int max_lat;           // Max_Lat
    unsigned int link_speed;        // PCIe 链路速率（如 Gen1/2/3/...）
    unsigned int link_width;        // PCIe 链路宽度（如 x1/x4/x8）
    unsigned int mps;               // Max Payload Size，最大负载
    unsigned int mrrs;              // Max Read Request Size，最大读请求大小
    unsigned int data[1024];        // 原始 PCI 配置空间缓存（按 dword 保存）
} PCI_DEVICE_INFO;

typedef struct _LOAD_DATA_ {
    unsigned int num_words;                     // 当前 block 中的有效 DWORD 数
    unsigned int block_words[MAX_BLOCK_SIZE];   // 数据块内容
} LOAD_DATA_INFO;

typedef struct _PCI_LOAD_ {
    unsigned char link_status;     // 链路状态
    unsigned int  crc;             // CRC 校验结果
    unsigned char axi_direction;   // AXI 方向/连接状态
    unsigned char load_status;     // 加载状态：完成/未完成
    unsigned int total_num_words;  // 累积总 DWORD 数
    LOAD_DATA_INFO data_block;     // 当前加载数据块
} PCI_LOAD_INFO;

typedef struct _COMMAND_ {
    unsigned char w_r;                  // 读写方向/类型标志
    unsigned char step;                 // 步长/步进值
    unsigned int addr;                  // 地址
    unsigned int data;                  // 数据
    unsigned int cnt;                   // 次数/计数
    unsigned int delay;                 // 延迟时间
    PCI_DEVICE_INFO get_pci_dev_info;   // PCI 设备信息
    CAP_LIST cap_info;                  // capability 列表信息
    PCI_LOAD_INFO load_info;            // 加载/传输状态信息
} COMMAND_OPERATION;

extern COMMAND_OPERATION command_operation;  // 全局命令操作结构体

typedef struct _CONFIG_ {
    unsigned int addr;   // 配置空间/寄存器地址
    unsigned int data;   // 配置空间/寄存器数据
} CONFIG_OPERATION;

extern COMMAND_OPERATION config_operation;   // 全局配置操作结构体（这里类型写成了 COMMAND_OPERATION，命名上容易让人误解）

typedef struct _FILE_INFO_ {
    FILE* _pg_load_file;             // 文件句柄
    unsigned int *file_data_buffer;  // 文件数据缓存（按 unsigned int 组织）
    unsigned int file_total_bytes;   // 文件总字节数
    unsigned int file_total_dws;     // 文件总 DWORD 数
    unsigned int file_blocks_integer;   // 能完整分成多少整块
    unsigned int file_blocks_remainder; // 最后剩余不满一块的数据量
} FILE_INFO;

extern FILE_INFO load_file_info;      // 加载文件信息
extern FILE_INFO dma_write_file_info; // DMA 写文件信息
// GTK 依赖的结构体 — 仅在 GTK GUI 工程中使用，DMA 桥接编译时禁用
#if 0
typedef struct _SCREEN_INFO_ {
    int num;                                     // 控件/页面编号
    char * name;                                 // 控件名称
    unsigned int type;                           // 控件类型
    int parent;                                  // 父控件编号
    unsigned int width;                          // 宽度
    unsigned int height;                         // 高度
    unsigned int gint_x;                         // GTK 界面中的 x 坐标
    unsigned int gint_y;                         // GTK 界面中的 y 坐标
    int active;                                  // 是否激活/启用
    gboolean (*callback)(GtkWidget*, void *);    // 回调函数指针
    char * detailed_signal;                      // GTK 信号名，例如 "clicked" / "activate"
    gpointer Data;                               // 传给回调函数的用户数据
} SCREEN_INFO;

typedef struct _ENTRY_INFO_ {
    int num;   // 控件编号
    int id;    // 信号连接后的 handler ID 或内部标识 ID
} ENTRY_INFO;

typedef struct _HANDLER_ID_ {
    ENTRY_INFO pio;          // PIO 控件/信号 ID
    ENTRY_INFO config;       // 配置控件/信号 ID
    ENTRY_INFO start;        // 开始按钮/信号 ID
    ENTRY_INFO end;          // 结束按钮/信号 ID
    ENTRY_INFO alloc_mem;    // 分配内存控件/信号 ID
    ENTRY_INFO offset_addr;  // 偏移地址控件/信号 ID
    ENTRY_INFO data_length;  // 数据长度控件/信号 ID
    ENTRY_INFO packet_size;  // 包大小控件/信号 ID
} HANDLER_ID;
#endif

typedef struct _DEV_MEM_ {
    off_t offset;   // 映射偏移（物理地址偏移）
    size_t len;     // 映射长度
    void *vaddr;    // 映射后的虚拟地址
} DEV_MEM;

extern DEV_MEM map_dev_mem;  // /dev/mem 映射后的设备内存信息

typedef struct _PIO_PAGE_INFO_ {
    unsigned char bar;   // 当前选择的 BAR 号
    unsigned char w_r;   // 读/写标志
    unsigned int addr;   // 访问地址
    unsigned int data;   // 访问数据
    unsigned int cnt;    // 操作次数
    unsigned int delay;  // 两次操作之间的延迟
} PIO_INFO;

extern PIO_INFO pio_page_info;  // PIO 页面/界面的当前配置信息

typedef struct _BUTTON_FLAG_ {
    bool free_time;          // 自由运行/自由时间模式按钮状态
    bool pio;                // PIO 按钮状态
    bool dma_auto;           // DMA 自动测试按钮状态
    bool close_file;         // 关闭文件按钮状态
    bool manual_start;       // 手动开始按钮状态
    bool performance_start;  // 性能测试开始按钮状态
} BUTTON_FLAG;

extern BUTTON_FLAG button_flag;  // 全局按钮状态集合

typedef struct _ID_ {
    unsigned char id;        // ID 编号
    unsigned char *id_info;  // 对应 ID 的描述字符串
} ID_INFO;

typedef struct _DMA_DATA_ {
//     unsigned char read_buf[DMA_MAX_PACKET_SIZE];   // DMA 读回来的数据缓冲区
//     unsigned char write_buf[DMA_MAX_PACKET_SIZE];  // DMA 要写出去的数据缓冲区
    void *read_buf;   // 这是一个指针变量
    void *write_buf;  // 这也是一个指针变量
} DMA_DATA;

typedef struct _DMA_OPERATION_
{
	unsigned int current_len;   // 当前 DMA 传输长度，通常以 DWORD 为单位
	unsigned int offset_addr;   // 内核物理地址偏移
	unsigned int cmd;           // DMA 命令字/操作类型 0写 1读
	unsigned int ddr3_addr;     // FPGA DDR3 物理起始地址
    unsigned int total_length;   // 总传输字节数（控制器自动分chunk，只在最后完成时发一次MSI）
	DMA_DATA data;              // DMA 读写缓冲区
}DMA_OPERATION;

extern DMA_OPERATION dma_operation;  // 全局 DMA 操作结构体

typedef struct _DMA_AUTO_ {
    unsigned int test_num;      // 自动测试次数
    unsigned int start;         // 起始长度/起始参数
    unsigned int end;           // 结束长度/结束参数
    unsigned int step;          // 步长
    unsigned int write_cnt;     // 写次数统计
    unsigned int read_cnt;      // 读次数统计
    unsigned int error_cnt;     // 错误次数统计
    unsigned int step_add_cnt;  // 步进累加计数
} DMA_AUTO;

extern DMA_AUTO dma_auto_info;  // DMA 自动测试信息

typedef struct _DMA_MANUAL_ {
    unsigned int allocate_mem_size;  // 手动模式下申请的 DMA 缓冲大小
    unsigned int offset_addr;        // 手动模式下的地址偏移
    unsigned int data_length;        // 手动模式下的数据长度
} DMA_MANUAL;

extern DMA_MANUAL dma_manual_info;   // DMA 手动测试信息

typedef struct _PERFORMANCE_OPERATION_ {
    unsigned int current_len;  // 当前性能测试的数据长度
    unsigned int cmd;          // 性能测试命令类型
    unsigned char cmp_flag;    // 比较结果标志：测试前后数据是否一致
} PERFORMANCE_OPERATION;

extern PERFORMANCE_OPERATION performance_operation;  // 全局性能测试操作结构体

typedef struct _PERFORMANCE_DATA_ {
    float w_throughput;          // 写吞吐率
    float r_throughput;          // 读吞吐率
    float w_bandwidth;           // 写带宽
    float r_bandwidth;           // 读带宽
    unsigned char dma_w_status;  // DMA 写状态
    unsigned char dma_r_status;  // DMA 读状态
    unsigned char busy_w_status; // 写通道 busy 状态
    unsigned char busy_r_status; // 读通道 busy 状态
    unsigned int w_total_cnt;    // 写总次数
    unsigned int w_invalid_cnt;  // 写无效次数
    unsigned int w_error_cnt;    // 写错误次数
    unsigned int r_total_cnt;    // 读总次数
    unsigned int r_invalid_cnt;  // 读无效次数
    unsigned int r_error_cnt;    // 读错误次数
} PERFORMANCE_DATA;

extern PERFORMANCE_DATA performance_data;  // 全局性能统计数据

#ifdef __cplusplus
}
#endif

// =========================================================================
// PCIe 底层桥接函数（定义于 sources/pci_dma_bridge.cpp，各模块共用）
// 保持 C++ 链接（不加 extern "C"），与定义文件一致
// =========================================================================
#ifdef __cplusplus
int open_pci_driver(void);
int pci_dma_single_write(int pci_driver_fd, uint32_t start_ddr3_addr, uint32_t mmp_offset, uint32_t total_size);
int pci_dma_single_read(int pci_driver_fd, uint32_t start_ddr3_addr, uint32_t mmp_offset, uint32_t total_size);
DMA_DATA pci_mmp(int pci_driver_fd, int cmd, uint32_t total_size_tx, uint32_t total_size_rx);
int pci_umap(int pci_driver_fd);
int pci_map(int pci_driver_fd, int cmd, uint32_t total_size_tx, uint32_t total_size_rx);
#endif

#endif // _CONFIG_GUI_H
