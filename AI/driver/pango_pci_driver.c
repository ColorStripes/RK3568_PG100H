#include "pango_pci_driver.h"
#include "id_config.h"

//#define NDEBUG

#ifndef NDEBUG
#define LOG(msg ...) printk(KERN_ALERT msg)
#else
#define LOG(msg ...)
#endif

#define PCI_DRIVER_DEV_COUNT 1
#define PCI_DRIVER_DEV_NAME "pango_pci_driver"
#define IRQ_NAME0 "pango_pci_driver_irq0"
#define IRQ_NAME1 "pango_pci_driver_irq1"
#define IRQ_NAME2 "pango_pci_driver_irq2"
#define CAM_ACK  0x20000000
// #define CAM_SIZE  0x3f4800	//1080p	  
#define CAM_SIZE  0x1c2000  //720P
#define CAM_ADDR0  0x00000000  //ddr3的存储地址
#define CAM_ADDR1  0x003F4800  //ddr3的存储地址


#define MAX_CAM_BUFFS 2  // 假设有4个缓冲区

// 缓冲区地址数组
static uint32_t cam_buffer_addrs[MAX_CAM_BUFFS] = {
    CAM_ADDR0, CAM_ADDR1
};
// 对应 1st (0x1), 2nd (0x10), 3rd (0x100)
static const uint32_t ack_val_table[MAX_CAM_BUFFS] = {0x00000001, 0x00000010};

// DMA和Camera中断标志位
static atomic_t g_dma_flag = ATOMIC_INIT(0);    // 0:空闲, 1:普通DMA, 2:相机DMA
static atomic_t g_cam_flag = ATOMIC_INIT(0);    // 等待处理的相机中断计数
static atomic_t g_cam_done = ATOMIC_INIT(0);    // 已完成的总次数（或用于应用层同步）
static atomic_t read_img_num = ATOMIC_INIT(0); // 当前待填充的缓冲区索引 (0,1,2,3)
static atomic_t g_ack_num = ATOMIC_INIT(0);		//ACK应答次数
static atomic_t g_npu_flag = ATOMIC_INIT(0);    // 等待处理的NPU中断计数
static atomic_t g_npu_done = ATOMIC_INIT(0);    // NPU已完成的总次数（应用层同步用）
// MSI中断全局变量
msi_info_t g_msi;


struct file_operations pango_cdev_fops = {
	.owner   = THIS_MODULE,
	.llseek  = pango_cdev_llseek,
	.read    = pango_cdev_read,
	.write   = pango_cdev_write,
	.open    = pango_cdev_open,
	.unlocked_ioctl = pango_cdev_ioctl,
	.release = pango_cdev_release,
	.mmap  = pango_cdev_mmap,   // 关键：绑定 mmap 函数
};

struct PciDriverDevInfo pci_dev_info = {
	._dev            = 0,
	._dev_firstminor = 0,
	._dev_count      = PCI_DRIVER_DEV_COUNT,
	._dev_name       = PCI_DRIVER_DEV_NAME,
};

struct pci_device_id pci_pango_device_ids[] = {
	{ PCI_DEVICE(PCI_PANGO_DEFAULT_VENDOR_ID, PCI_PANGO_DEFAULT_DEVICE_ID) },
	{ 0, },
};

struct PciPango pci_info = {
	._pango_pci_driver = {
		._pci_bar     = 1,
		._pci_io_size = 0,
		._pci_io      = NULL,
		._pci_io_buff = NULL,
		._pci_driver  = {
			.name     = PCI_DRIVER_DEV_NAME,
			.id_table = pci_pango_device_ids,
			.probe    = pci_driver_probe,
			.remove   = pci_driver_remove,
		},
	},
	._cdev_class = NULL,
};


struct pci_dev *op_dev;

///////////////////////////////////////////////////////////////////////

loff_t pango_cdev_llseek(struct file *filp, loff_t off, int whence)
{
	struct PciPango *pci_pango = &pci_info;
	loff_t newpos = 0;
	
	//LOG("pango_cdev_llseek.\n");
	
	switch (whence)
	{
	case 0: /* SEEK_SET */
	{
		newpos = off;
	}
		break;
	case 1: /* SEEK_CUR */
	{
		newpos = filp->f_pos + off;
	}
		break;
	case 2: /* SEEK_END */
	{
		newpos = pci_pango->_pango_pci_driver._pci_io_size + off;
	}
		break;
	default: /* can't happen */
	{
		return -EINVAL;
	}	
		break;
	}
	
	if (newpos < 0)
	{
		return -EINVAL;
	}
	
	filp->f_pos = newpos;
	
	return newpos;
}

static void ReadConfig(struct pci_dev * pdev)
{
	int i;
	u8 valb;
	u16 valw;
	u32 valdw;
	u8 id;
	u8 next;
	int pos;
	unsigned long reg_base, reg_len;

	/* Read PCI configuration space 读取PCI配置空间*/
	printk(KERN_INFO "PCI Configuration Space:\n");
	for(i=0; i< 1024; i++)
	{
		pci_read_config_dword(pdev, i*4, &valdw);
		command_operation.get_pci_dev_info.data[i] = valdw;
	}

	/* Now read each element - one at a time 现在读取每个元素——一次读取一个*/

	/* Read Vendor ID 读取厂商ID*/
	pci_read_config_word(pdev, PCI_VENDOR_ID, &valw);
	printk("Vendor ID: 0x%x, \n", valw);
	command_operation.get_pci_dev_info.vendor_id = valw;

	/* Read Device ID 读取设备ID*/
	pci_read_config_word(pdev, PCI_DEVICE_ID, &valw);
	printk("Device ID: 0x%x, \n", valw);
	command_operation.get_pci_dev_info.device_id = valw;

	/* Read Command Register 读取命令寄存器*/
	pci_read_config_word(pdev, PCI_COMMAND, &valw);
	printk("Cmd Reg: 0x%x, \n", valw);
	command_operation.get_pci_dev_info.cmd_reg = valw;

	/* Read Status Register 读取状态寄存器*/
	pci_read_config_word(pdev, PCI_STATUS, &valw);
	printk("Stat Reg: 0x%x, \n", valw);
	command_operation.get_pci_dev_info.status_reg = valw;

	/* Read Revision ID 阅读修订ID*/
	pci_read_config_byte(pdev, PCI_REVISION_ID, &valb);
	printk("Revision ID: 0x%x, \n", valb);
	command_operation.get_pci_dev_info.revision_id = valb;

	/* Read Class Code */
	/*
	pci_read_config_dword(pdev, PCI_CLASS_PROG, &valdw);
	printk("Class Code: 0x%lx, ", valdw);
	valdw &= 0x00ffffff;
	printk("Class Code: 0x%lx, ", valdw);
	*/
	/* Read Reg-level Programming Interface 读取reg级编程接口*/
	pci_read_config_byte(pdev, PCI_CLASS_PROG, &valb);
	printk("Class Prog: 0x%x, \n", valb);
	command_operation.get_pci_dev_info.class_prog = valb;

	/* Read Device Class */
	pci_read_config_word(pdev, PCI_CLASS_DEVICE, &valw);
	printk("Device Class: 0x%x, \n", valw);
	command_operation.get_pci_dev_info.class_device = valw;

	  /* Read Cache Line 读缓存线*/
	  pci_read_config_byte(pdev, PCI_CACHE_LINE_SIZE, &valb);
	  printk("Cache Line Size: 0x%x, \n", valb);
	
	  /* Read Latency Timer 读延迟计时器*/
	  pci_read_config_byte(pdev, PCI_LATENCY_TIMER, &valb);
	  printk("Latency Timer: 0x%x, \n", valb);
	
	  /* Read Header Type 读头类型*/
	  pci_read_config_byte(pdev, PCI_HEADER_TYPE, &valb);
	  printk("Header Type: 0x%x, \n", valb);
	
	  /* Read BIST */
	  pci_read_config_byte(pdev, PCI_BIST, &valb);
	  printk("BIST: 0x%x\n", valb);

	/* Read all 6 BAR registers 读取所有6个BAR寄存器*/
	for(i=0; i<=5; i++)
	{
		/* Physical address & length 物理地址和长度*/
		reg_base = pci_resource_start(pdev, i);
		reg_len = pci_resource_len(pdev, i);
		printk("BAR%d: Addr:0x%lx Len:0x%lx,  ", i, reg_base, reg_len);
		command_operation.get_pci_dev_info.bar[i].bar_base = reg_base;
		command_operation.get_pci_dev_info.bar[i].bar_len = reg_len;

		/* Flags */
		if((pci_resource_flags(pdev, i) & IORESOURCE_MEM))
		  printk("Region is for memory\n");
		else if((pci_resource_flags(pdev, i) & IORESOURCE_IO))
		  printk("Region is for I/O\n");
	}
	printk("\n");

	  /* Read CIS Pointer 读CIS指针*/
	  pci_read_config_dword(pdev, PCI_CARDBUS_CIS, &valdw);
	  printk("CardBus CIS Pointer: 0x%x, \n", valdw);
	
	  /* Read Subsystem Vendor ID 读取子系统供应商ID*/
	  pci_read_config_word(pdev, PCI_SUBSYSTEM_VENDOR_ID, &valw);
	  printk("Subsystem Vendor ID: 0x%x, \n", valw);
	
	  /* Read Subsystem Device ID 读取子系统设备ID*/
	  pci_read_config_word(pdev, PCI_SUBSYSTEM_ID, &valw);
	  printk("Subsystem Device ID: 0x%x\n", valw);
	
	  /* Read Expansion ROM Base Address 读取扩展ROM的基地地址*/
	  pci_read_config_dword(pdev, PCI_ROM_ADDRESS, &valdw);
	  printk("Expansion ROM Base Address: 0x%x\n", valdw);
	
	  /* Read IRQ Line 读IRQ线*/
	  pci_read_config_byte(pdev, PCI_INTERRUPT_LINE, &valb);
	  printk("IRQ Line: 0x%x, ", valb);
	
	  /* Read IRQ Pin 读IRQ引脚*/
	  pci_read_config_byte(pdev, PCI_INTERRUPT_PIN, &valb);
	  printk("IRQ Pin: 0x%x, ", valb);

	/* Read Min Gnt */
	pci_read_config_byte(pdev, PCI_MIN_GNT, &valb);
	printk("Min Gnt: 0x%x, ", valb);
	command_operation.get_pci_dev_info.min_gnt = valb;

	/* Read Max Lat */
	pci_read_config_byte(pdev, PCI_MAX_LAT, &valb);
	printk("Max Lat: 0x%x\n", valb);
	command_operation.get_pci_dev_info.max_lat = valb;
	
	if(pci_find_capability(pdev, PCI_CAP_ID_EXP))
	{
		pos = pci_find_capability(pdev, PCI_CAP_ID_EXP);
		pci_read_config_word(pdev, pos + PCI_EXP_LNKSTA, &valw);
		command_operation.get_pci_dev_info.link_speed = (valw & 0x0003);
		command_operation.get_pci_dev_info.link_width = (valw & 0x03f0) >> 4;
		printk("Link Speed: %d\n", command_operation.get_pci_dev_info.link_speed);
		printk("Link Width: x%d\n", command_operation.get_pci_dev_info.link_width);
		
		pci_read_config_word(pdev, pos + PCI_EXP_DEVCTL, &valw);
		command_operation.get_pci_dev_info.mps = 128 << ((valw & PCI_EXP_DEVCTL_PAYLOAD) >> 5);
		command_operation.get_pci_dev_info.mrrs = 128 << ((valw & PCI_EXP_DEVCTL_READRQ) >> 12);
		printk("MPS: %d\n", command_operation.get_pci_dev_info.mps);
		printk("MRRS: %d\n", command_operation.get_pci_dev_info.mrrs);
		
	}
	else
	{
		printk("Cannot find PCI Express Capabilities\n");
		command_operation.get_pci_dev_info.link_speed = 0;
		command_operation.get_pci_dev_info.link_width = 0;
		command_operation.get_pci_dev_info.mps = 0;
		command_operation.get_pci_dev_info.mrrs = 0;
	}

	pci_read_config_word(pdev, PCI_STATUS, &valw);
	command_operation.cap_info.cap_error = 0;
	if (!(valw & PCI_STATUS_CAP_LIST))
	{
		command_operation.cap_info.cap_status = 0;
	}
	else
	{
		command_operation.cap_info.cap_status = 1;
		for(i = 0; i < 256; i++)
		{
			command_operation.cap_info.cap_buf[i].flag = 0;
		}
		pci_read_config_byte(pdev, PCI_CAPABILITY_LIST, &valb);
		valb &= ~3;
		while(valb)
		{

			pci_read_config_byte(pdev, valb + PCI_CAP_LIST_ID, &id);		
			pci_read_config_byte(pdev, valb + PCI_CAP_LIST_NEXT, &next);
			next &= ~3;
			command_operation.cap_info.cap_buf[valb].flag = 1;
			command_operation.cap_info.cap_buf[valb].id = id;
			command_operation.cap_info.cap_buf[valb].addr_offset = valb;
			command_operation.cap_info.cap_buf[valb].next_offset = next;
			printk("cap id = %x; addr_offset = %x; next_offset = %x\n", id, valb, next);
			if(id == 0xff)
			{
				command_operation.cap_info.cap_error = 1;
				break;
			}
			valb = next;
		}
	}

}

ssize_t pango_cdev_read(struct file *filp, char __user *buf, size_t count, loff_t *f_pos)
{
	if (copy_to_user(buf, &command_operation, sizeof(COMMAND_OPERATION)))
		return -EFAULT;
	return 1;
}

ssize_t pango_cdev_write(struct file *filp, const char __user *buf, size_t count, loff_t *f_pos)
{
	return 1;
}

static void set_dma_w_r(unsigned int value, struct PciPango *pci_pango)
{
	iowrite32(value, pci_pango->_pango_pci_driver._pci_io + CMD_REG_OFFSET);
}

static void set_dma_addr(DMA_ADDR* dma_addr, struct PciPango *pci_pango)
{
	iowrite32(dma_addr->addr & 0x00000000ffffffff, pci_pango->_pango_pci_driver._pci_io + RW_ADDR_LO_OFFSET);
	if(dma_addr->addr_size)
		iowrite32(dma_addr->addr >> 32, pci_pango->_pango_pci_driver._pci_io + RW_ADDR_HI_OFFSET);
}

// [新增] 写入 DDR3 本地地址
static void set_ddr3_addr(unsigned int ddr3_addr, struct PciPango *pci_pango)
{
	iowrite32(ddr3_addr, pci_pango->_pango_pci_driver._pci_io + DDR3_ADDR_OFFSET);
}

// [新增] 写入总传输字节数（控制器自动分chunk，只在最后完成时发一次MSI）
static void set_total_length(unsigned int total_length, struct PciPango *pci_pango)
{
	iowrite32(total_length, pci_pango->_pango_pci_driver._pci_io + TOTAL_LENGTH_OFFSET);
}


// ///////////////MMP/////////////////////////////
// [新增] 用于记录动态分配的 DMA 内存大小 (按页对齐后的大小)
// 记录 TX (User -> FPGA) 缓冲区的真实分配大小
static size_t g_dma_alloc_size_r = 0; 
// 记录 RX (FPGA -> User) 缓冲区的真实分配大小
static size_t g_dma_alloc_size_w = 0;
int pango_cdev_mmap(struct file *filp, struct vm_area_struct *vma)
{
    // 获取用户请求映射的大小和偏移量
    unsigned long user_map_size = vma->vm_end - vma->vm_start;
    unsigned long offset = vma->vm_pgoff << PAGE_SHIFT; // 将页偏移转换为字节偏移
    int ret = 0;


    if (offset == 0) {
        // --- 映射 TX 缓冲区 (User -> FPGA, addr_r) ---
        if (!dma_info.addr_r.data_buf) {
            printk(KERN_ERR "TX buffer not allocated yet!\n");
            return -ENOMEM;
        }
        if (user_map_size > g_dma_alloc_size_r) {
            return -EINVAL;
        }
        ret = dma_mmap_coherent(&op_dev->dev, vma, 
                                dma_info.addr_r.data_buf, 
                                dma_info.addr_r.addr, 
                                g_dma_alloc_size_r);
    } 
    else if (offset == RX_MMAP_OFFSET) {
        // --- 映射 RX 缓冲区 (FPGA -> User, addr_w) ---
        if (!dma_info.addr_w.data_buf) {
            printk(KERN_ERR "RX buffer not allocated yet!\n");
            return -ENOMEM;
        }
        if (user_map_size > g_dma_alloc_size_w) {
            return -EINVAL;
        }
        
        // 【关键】重置 vma 的 offset，因为 dma_mmap_coherent 要求底层物理偏移从 0 开始
        vma->vm_pgoff = 0; 
        ret = dma_mmap_coherent(&op_dev->dev, vma, 
                                dma_info.addr_w.data_buf, 
                                dma_info.addr_w.addr, 
                                g_dma_alloc_size_w);
    } 
    else {
        printk(KERN_ERR "mmap failed: invalid offset. Use 0 for TX, %lu for RX\n", RX_MMAP_OFFSET);
        return -EINVAL;
    }

    if (ret < 0) {
        printk(KERN_ERR "dma_mmap_coherent failed: %d\n", ret);
        return ret;
    }

    printk(KERN_INFO "mmap successful: mapped %lu bytes (offset: %lu)\n", user_map_size, offset);
    return 0;
}

/**************************************************************************
** 函数名称:    pango_cdev_ioctl
** 函数功能:    写数据，将应用层传递过来的数据先复制到内核中然后再对数据进行解析
** 输入参数:    *file：文件描述词
**          cmd：操作命令(cmd的最高位表示寄存器读写操作指令，0：读操作；1：写操作)
**          arg：读取数据宽度
** 输出参数:    无
** 返回参数:操作结果
****************************************************************************/
DMA_ADDR temp_dma_addr_w;
DMA_ADDR temp_dma_addr_r;
long pango_cdev_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
	struct PciPango *pci_pango = &pci_info;
	unsigned char dest_buf[100];
	unsigned int temp_data = 0;
	unsigned int i = 0;
	if(down_interruptible(&pci_pango->_sem))
	{
		printk(KERN_ALERT "********* pango_cdev_read interruptible *********\n");
		return -ERESTARTSYS;
	}
	switch(cmd)
	{
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		case PCI_READ_DATA_CMD:	
			if (copy_from_user(&config_operation,(COMMAND_OPERATION*)arg, sizeof(COMMAND_OPERATION))){
				return -EFAULT;
			}
			pci_read_config_dword(op_dev, config_operation.addr, &config_operation.data);
			if (copy_to_user((COMMAND_OPERATION*)arg, &config_operation, sizeof(COMMAND_OPERATION))){
				return -EFAULT;
			}
		break;
		
		case PCI_WRITE_DATA_CMD:	
			if (copy_from_user(&config_operation,(COMMAND_OPERATION*)arg, sizeof(COMMAND_OPERATION))){
				return -EFAULT;
			}
			pci_write_config_dword(op_dev, config_operation.addr, config_operation.data);
		break;
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

		// 为DMA分配内核和映射地址
		case PCI_MAP_ADDR_CMD:
			spin_lock(&dma_info.addr_r.lock);
			//内核里面的dma_operation更新
			size_t head_size = offsetof(DMA_OPERATION, data);
            // 拷贝参数，速度极快，且允许缺页休眠
            if (copy_from_user(&dma_operation, (DMA_OPERATION*)arg, head_size)) {
                spin_unlock(&dma_info.addr_r.lock);
                return -EFAULT;
            }
			// spin_lock(&dma_info.addr_r.lock);
			//分配的内核大小
			// [修改] 使用 total_length (bytes) 分配缓冲区，不再使用 current_len * 4
            // total_length 由应用层设置，表示总传输字节数
            // 分配大小按4字节对齐后按页对齐
            unsigned int alloc_bytes = dma_operation.total_length;
			// 假设 cmd == 0 代表分配 TX 缓冲区 (发给 FPGA, addr_r)
            if (dma_operation.cmd == 0) {
                if (dma_info.addr_r.data_buf) {
                    printk(KERN_ERR "TX Buffer already allocated!\n");
                    spin_unlock(&dma_info.addr_r.lock);
                    return -EBUSY;
                }
                g_dma_alloc_size_r = PAGE_ALIGN(alloc_bytes);
                dma_info.addr_r.data_buf = dma_alloc_coherent(&op_dev->dev, 
                                                             g_dma_alloc_size_r, 
                                                             &dma_info.addr_r.addr, 
                                                             GFP_KERNEL);
                dma_info.addr_r.addr_size = ((dma_info.addr_r.addr >> 32) > 0) ? 1 : 0;
                printk(KERN_INFO "Allocated TX Buffer: %zu bytes (total_length=%u bytes)\n", g_dma_alloc_size_r, alloc_bytes);
            }
            // 假设 cmd == 1 代表分配 RX 缓冲区 (接收 FPGA, addr_w)
            else if (dma_operation.cmd == 1) {
                if (dma_info.addr_w.data_buf) {
                    printk(KERN_ERR "RX Buffer already allocated!\n");
                    spin_unlock(&dma_info.addr_r.lock);
                    return -EBUSY;
                }
                g_dma_alloc_size_w = PAGE_ALIGN(alloc_bytes);
                dma_info.addr_w.data_buf = dma_alloc_coherent(&op_dev->dev, 
                                                             g_dma_alloc_size_w, 
                                                             &dma_info.addr_w.addr, 
                                                             GFP_KERNEL);
                dma_info.addr_w.addr_size = ((dma_info.addr_w.addr >> 32) > 0) ? 1 : 0;
                printk(KERN_INFO "Allocated RX Buffer: %zu bytes (total_length=%u bytes)\n", g_dma_alloc_size_w, alloc_bytes);
            }
            else {
                printk(KERN_ERR "Invalid cmd for allocation\n");
                spin_unlock(&dma_info.addr_r.lock);
                return -EINVAL;
            }
			spin_unlock(&dma_info.addr_r.lock);
		break;
		// 从用户态写入内核态 （MMP下废弃）
		case PCI_WRITE_TO_KERNEL_CMD:	
			spin_lock(&dma_info.addr_r.lock);
			// 更新操作长度
			if (get_user(dma_operation.current_len, &(((DMA_OPERATION *)arg)->current_len))) {
    			return -EFAULT; 
			}
			
			//直接从用户态拿数据过来
			// 第一步：安全地把用户态的“指针变量本身”搬进内核
			unsigned char *write_data_ptr; 
			// 使用 get_user 读取用户态指针的值（这是安全的做法）
			if (get_user(write_data_ptr, &(((DMA_OPERATION *)arg)->data.write_buf))) {
			    return -EFAULT;
			}
			// 第二步：拿着刚刚搬进来的指针，再去搬运真实的数据
			if (copy_from_user(dma_info.addr_r.data_buf, write_data_ptr, dma_operation.current_len * 4)) {
			    return -EFAULT;
			}

			// spin_lock(&dma_info.addr_r.lock);

			//设置dma_reg寄存器的TLP包长度【9:0】
			dma_info.cmd.data.length = dma_operation.current_len - 1;
			//允许中断
			// dma_info.cmd.data.msi_enable = 1;
			
			spin_unlock(&dma_info.addr_r.lock);
		break;
		// 从内核 写给 FPGA     在这个命令前指定ddr3操作地址
		case PCI_DMA_READ_CMD:

		int ret_r = wait_event_interruptible_timeout(g_msi.queue, 
		                                            atomic_cmpxchg(&g_dma_flag, 0, 1) == 0, 
		                                            msecs_to_jiffies(800));
		if (ret_r == 0) {
		    printk(KERN_ERR "PCI_DMA_READ Error: Timeout waiting for DMA engine idle [g_dma_flag=%d, g_cam_flag=%d, g_cam_done=%d, g_ack_num=%d]\n",
		           atomic_read(&g_dma_flag), atomic_read(&g_cam_flag), atomic_read(&g_cam_done), atomic_read(&g_ack_num));
		    up(&pci_pango->_sem);
		    return -ETIMEDOUT;
		} else if (ret_r < 0) {
		    printk(KERN_ERR "PCI_DMA_READ Error: Interrupted by signal [g_dma_flag=%d, g_cam_flag=%d, g_cam_done=%d, g_ack_num=%d]\n",
		           atomic_read(&g_dma_flag), atomic_read(&g_cam_flag), atomic_read(&g_cam_done), atomic_read(&g_ack_num));
		    up(&pci_pango->_sem);
		    return -ERESTARTSYS;
		}


			spin_lock(&dma_info.addr_r.lock);
			//内核里面的dma_operation更新
			size_t head_size_r = offsetof(DMA_OPERATION, data);
            // 拷贝参数，速度极快，且允许缺页休眠
            if (copy_from_user(&dma_operation, (DMA_OPERATION*)arg, head_size_r)) {
                return -EFAULT;
            }

			// [修改] TLP 长度 = min(total_length, MAX_TRANSFER_SIZE)
			// 后续 DMA 引擎直接用 o_req_length 作为传输 DW 数
			// total_size >= MAX_TRANSFER_SIZE 时，cap 到引擎最大能力，避免引擎超限死锁
			dma_info.cmd.data.length = (dma_operation.total_length >= MAX_TRANSFER_SIZE) ?
                               (MAX_TRANSFER_SIZE / 4) : (dma_operation.total_length / 4);
			//允许中断
			// dma_info.cmd.data.msi_enable = 1;
			//DMA读操作，DMA将数据读入到FPGA设备
			dma_info.cmd.data.op_type = 0;

			// [修改] 先写 DDR3 地址和长度，再写 TOTAL_LENGTH（触发控制器开始自动 chunk 循环）
			// [修改] DDR3 地址由 total_length 推导，不再需要单独写入 ddr3_length
			set_ddr3_addr(dma_operation.ddr3_addr, pci_pango);

			temp_dma_addr_r = dma_info.addr_r;
            temp_dma_addr_r.addr = temp_dma_addr_r.addr + dma_operation.offset_addr;
            set_dma_addr(&temp_dma_addr_r, pci_pango);

			// 最后写 TOTAL_LENGTH，触发控制器开始自动分chunk循环
			set_total_length(dma_operation.total_length, pci_pango);
			// 写 CMD_REG 启动 DMA（此时 FPGA 已准备好所有参数）
			set_dma_w_r(dma_info.cmd.value, pci_pango);
			spin_unlock(&dma_info.addr_r.lock);


			int old_r = atomic_read(&g_msi.count);

		    // 进程在这里休眠，直到以下两个条件之一发生：
		    // 1. 中断计数器改变（说明 pango_irq_handler 被执行了，FPGA发了中断）
		    // 2. 超时（100毫秒）
		    ret_r = wait_event_interruptible_timeout(g_msi.queue, 
		        atomic_read(&g_msi.count) != old_r, 
				msecs_to_jiffies(800));
			
		    if (ret_r == 0) {
		        printk(KERN_ERR "PCI_DMA_READ Error: Timeout waiting for MSI interrupt [g_msi.count=%d, g_dma_flag=%d, g_cam_flag=%d, g_cam_done=%d, g_ack_num=%d]\n",
		               atomic_read(&g_msi.count), atomic_read(&g_dma_flag), atomic_read(&g_cam_flag), atomic_read(&g_cam_done), atomic_read(&g_ack_num));
		        up(&pci_pango->_sem);
		        return -ETIMEDOUT;
		    }
		break;


		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// FPGA往内核写数据		ddr3地址 长度
		case PCI_DMA_WRITE_CMD:
			
		int ret_w = wait_event_interruptible_timeout(g_msi.queue, 
		                                            atomic_cmpxchg(&g_dma_flag, 0, 1) == 0, 
		                                            msecs_to_jiffies(800));
		if (ret_w == 0) {
		    printk(KERN_ERR "PCI_DMA_WRITE Error: Timeout waiting for DMA engine idle [g_dma_flag=%d, g_cam_flag=%d, g_cam_done=%d, g_ack_num=%d]\n",
		           atomic_read(&g_dma_flag), atomic_read(&g_cam_flag), atomic_read(&g_cam_done), atomic_read(&g_ack_num));
		    up(&pci_pango->_sem);
		    return -ETIMEDOUT;
		} else if (ret_w < 0) {
		    printk(KERN_ERR "PCI_DMA_WRITE Error: Interrupted by signal [g_dma_flag=%d, g_cam_flag=%d, g_cam_done=%d, g_ack_num=%d]\n",
		           atomic_read(&g_dma_flag), atomic_read(&g_cam_flag), atomic_read(&g_cam_done), atomic_read(&g_ack_num));
		    up(&pci_pango->_sem);
		    return -ERESTARTSYS;
		}

			spin_lock(&dma_info.addr_w.lock);
			//内核里面的dma_operation更新
			size_t head_size_w = offsetof(DMA_OPERATION, data);
            // 拷贝参数，速度极快，且允许缺页休眠
            if (copy_from_user(&dma_operation, (DMA_OPERATION*)arg, head_size_w)) {
                return -EFAULT;
            }
			// spin_lock(&dma_info.addr_w.lock);
			dma_info.cmd.data.op_type = 1;										/* DMA写操作，DMA将数据写入到内核 */
			// [修改] TLP 长度 = min(total_length, MAX_TRANSFER_SIZE)
			// 后续 DMA 引擎直接用 o_req_length 作为传输 DW 数
			// total_size >= MAX_TRANSFER_SIZE 时，cap 到引擎最大能力，避免引擎超限死锁
			dma_info.cmd.data.length = (dma_operation.total_length >= MAX_TRANSFER_SIZE) ?
                               (MAX_TRANSFER_SIZE / 4) : (dma_operation.total_length / 4);
			set_ddr3_addr(dma_operation.ddr3_addr, pci_pango);
			temp_dma_addr_w = dma_info.addr_w;
			temp_dma_addr_w.addr = temp_dma_addr_w.addr + dma_operation.offset_addr;
            set_dma_addr(&temp_dma_addr_w, pci_pango);
			// set_dma_addr(&dma_info.addr_w, pci_pango);						//内核实际物理地址告诉DMA

			// 最后写 TOTAL_LENGTH，触发控制器开始自动分chunk循环
			set_total_length(dma_operation.total_length, pci_pango);
			set_dma_w_r(dma_info.cmd.value, pci_pango);						//将配置写入DMA的 cmd_reg
			spin_unlock(&dma_info.addr_w.lock);

			int old_w = atomic_read(&g_msi.count);

		    // 进程在这里休眠，直到以下两个条件之一发生：
		    // 1. 中断计数器改变（说明 pango_irq_handler 被执行了，FPGA发了中断）
		    // 2. 超时（100毫秒）
		    ret_w = wait_event_interruptible_timeout(g_msi.queue, 
		        atomic_read(&g_msi.count) != old_w, 
				msecs_to_jiffies(800));
			
		    if (ret_w == 0) {
		        printk(KERN_ERR "PCI_DMA_WRITE Error: Timeout waiting for MSI interrupt [g_msi.count=%d, g_dma_flag=%d, g_cam_flag=%d, g_cam_done=%d, g_ack_num=%d]\n",
		               atomic_read(&g_msi.count), atomic_read(&g_dma_flag), atomic_read(&g_cam_flag), atomic_read(&g_cam_done), atomic_read(&g_ack_num));
		        up(&pci_pango->_sem);
		        return -ETIMEDOUT;
		    }
		break;
		// 内核态 往 CPU写数据 （MMP下废弃）
		case PCI_READ_FROM_KERNEL_CMD:										
			spin_lock(&dma_info.addr_w.lock);
			// 第一步：安全地把用户态的“指针变量本身”搬进内核
			unsigned char *read_data_ptr; 
			// 使用 get_user 读取用户态指针的值（这是安全的做法）
			if (get_user(read_data_ptr, &(((DMA_OPERATION *)arg)->data.read_buf))) {
			    return -EFAULT;
			}
			if (copy_to_user(read_data_ptr, dma_info.addr_w.data_buf, dma_operation.current_len * 4)) {
				spin_unlock(&dma_info.addr_r.lock);
			    return -EFAULT;
			}
			spin_unlock(&dma_info.addr_w.lock);
		break;
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


		case PCI_UMAP_ADDR_CMD:
			spin_lock(&dma_info.addr_r.lock);
			//获得操作指令
			if (get_user(dma_operation.cmd, &(((DMA_OPERATION *)arg)->cmd))) {
    			return -EFAULT; 
			}
			//清空对应内核空间
			if (dma_operation.cmd == 0) {
				dma_free_coherent(&op_dev->dev, g_dma_alloc_size_r, dma_info.addr_r.data_buf, dma_info.addr_r.addr);
				dma_info.addr_r.data_buf = NULL;
			}
			else if (dma_operation.cmd == 1) {
    			dma_free_coherent(&op_dev->dev, g_dma_alloc_size_w, dma_info.addr_w.data_buf, dma_info.addr_w.addr);
				dma_info.addr_w.data_buf = NULL;
			}
			else if (dma_operation.cmd == 3) {
				dma_free_coherent(&op_dev->dev, g_dma_alloc_size_r, dma_info.addr_r.data_buf, dma_info.addr_r.addr);
				dma_info.addr_r.data_buf = NULL;
    			dma_free_coherent(&op_dev->dev, g_dma_alloc_size_w, dma_info.addr_w.data_buf, dma_info.addr_w.addr);
				dma_info.addr_w.data_buf = NULL;
			}
			spin_unlock(&dma_info.addr_r.lock);
		break;
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		case PCI_PERFORMANCE_START_CMD:
			spin_lock(&performance_config.addr.lock);
			if (copy_from_user(&performance_operation,(PERFORMANCE_OPERATION*)arg, sizeof(PERFORMANCE_OPERATION))){
				spin_unlock(&performance_config.addr.lock);
				return -EFAULT;
			}
			performance_config.addr.data_buf = dma_alloc_coherent(&op_dev->dev,
                                                        DMA_MAX_PACKET_SIZE*10*2,
                                                        &performance_config.addr.addr,
                                                        GFP_KERNEL);
			for(i = 0; i < (DMA_MAX_PACKET_SIZE*10)/16; i++)
			{
				memset(dest_buf, 0, sizeof(dest_buf));
				temp_data = i;
				dest_buf[0] = (unsigned char)temp_data;
				dest_buf[1] = (unsigned char)(temp_data >> 8);
				dest_buf[2] = (unsigned char)(temp_data >> 16);
				dest_buf[3] = (unsigned char)(temp_data >> 24);
				memcpy(performance_config.addr.data_buf + i*16, dest_buf, 16);
			}

			performance_config.addr.addr_size = ((performance_config.addr.addr >> 32) > 0) ? 1 : 0;
			performance_config.cmd.data.length = performance_operation.current_len - 1;
			performance_config.cmd.data.addr_type = performance_config.addr.addr_size;
			performance_config.cmd.data.op_type = performance_operation.cmd;
			set_dma_w_r(performance_config.cmd.value, pci_pango);
			set_dma_addr(&performance_config.addr, pci_pango);
			printk("addr_size = %d;     current_len = %d(dw)\n", (performance_config.addr.addr_size) ? 64 : 32, performance_operation.current_len);
			printk("operation cmd = 0x%02x; dma_addr  = 0x%llx \n", performance_operation.cmd, performance_config.addr.addr);
			spin_unlock(&performance_config.addr.lock);
		break;

		case PCI_PERFORMANCE_END_CMD:
			spin_lock(&performance_config.addr.lock);
			if(!memcmp(performance_config.addr.data_buf, performance_config.addr.data_buf + DMA_MAX_PACKET_SIZE*10, DMA_MAX_PACKET_SIZE*10))
			{
				performance_operation.cmp_flag = 1;
			}
			else
			{
				performance_operation.cmp_flag = 0;
			}
			if (copy_to_user((PERFORMANCE_OPERATION*)arg, &performance_operation, sizeof(PERFORMANCE_OPERATION))){
				return -EFAULT;
			}
			dma_free_coherent(&op_dev->dev, DMA_MAX_PACKET_SIZE*10*2, performance_config.addr.data_buf, performance_config.addr.addr);
			performance_config.addr.data_buf = NULL;
			spin_unlock(&performance_config.addr.lock);
		break;



		case PCI_MSI_WAIT_CMD:
		{
		    // 记录当前的中断计数
			int old = atomic_read(&g_msi.count);

		    // 进程在这里休眠，直到以下两个条件之一发生：
		    // 1. 中断计数器改变（说明 pango_irq_handler 被执行了，FPGA发了中断）
		    // 2. 超时（100毫秒）
		    int ret = wait_event_interruptible_timeout(g_msi.queue, 
		        atomic_read(&g_msi.count) != old, 
				msecs_to_jiffies(800));
			
		    if (ret == 0) {
		        printk(KERN_ERR "PCI_MSI_WAIT Error: Timeout waiting for MSI interrupt [g_msi.count=%d, g_dma_flag=%d, g_cam_flag=%d, g_cam_done=%d, g_ack_num=%d]\n",
		               atomic_read(&g_msi.count), atomic_read(&g_dma_flag), atomic_read(&g_cam_flag), atomic_read(&g_cam_done), atomic_read(&g_ack_num));
		        up(&pci_pango->_sem);
		        return -ETIMEDOUT;
		    }
		}
		break;


		case PCI_GET_IMG:
        {
			// printk(KERN_ERR "PCI_GET_IMG IN:[g_cam_done=%d, g_dma_flag=%d, g_cam_flag=%d, g_ack_num=%d]\n",
            //                atomic_read(&g_cam_done), atomic_read(&g_dma_flag), atomic_read(&g_cam_flag), atomic_read(&g_ack_num));
            int ret_cam;
            // int current_idx;
            // uint32_t current_ack_val;

            // --- 1. 等待采集完成中断 ---
            ret_cam = wait_event_interruptible_timeout(g_msi.queue, 
                                                       atomic_read(&g_cam_done) > 0, 
                                                       msecs_to_jiffies(1000));
            if (ret_cam <= 0) {
                if (ret_cam == 0)
                    printk(KERN_ERR "PCI_GET_IMG Error: Timeout waiting for image capture [g_cam_done=%d, g_dma_flag=%d, g_cam_flag=%d, g_ack_num=%d]\n",
                           atomic_read(&g_cam_done), atomic_read(&g_dma_flag), atomic_read(&g_cam_flag), atomic_read(&g_ack_num));
                else
                    printk(KERN_ERR "PCI_GET_IMG Error: Interrupted by signal while waiting for image [g_cam_done=%d, g_dma_flag=%d, g_cam_flag=%d, g_ack_num=%d]\n",
                           atomic_read(&g_cam_done), atomic_read(&g_dma_flag), atomic_read(&g_cam_flag), atomic_read(&g_ack_num));
                
                up(&pci_pango->_sem);
                return (ret_cam == 0) ? -ETIMEDOUT : -ERESTARTSYS;
            }
            atomic_dec(&g_cam_done);

            // // --- 2. 获取当前索引并确定应答数值 ---
            // // 假设你之前定义了 static atomic_t g_ack_num = ATOMIC_INIT(0);
            // current_idx = atomic_read(&g_ack_num);
            // current_ack_val = ack_val_table[current_idx]; // 确保不越界

            // // --- 3. 抢占 DMA 锁 ---
            // ret_cam = wait_event_interruptible_timeout(g_msi.queue, 
            //                                            atomic_cmpxchg(&g_dma_flag, 0, 1) == 0, 
            //                                            msecs_to_jiffies(800));
            // if (ret_cam <= 0) {
            //     if (ret_cam == 0)
            //         printk(KERN_ERR "PCI_GET_IMG Error: Timeout waiting for DMA engine idle [g_dma_flag=%d, g_cam_flag=%d, g_cam_done=%d, g_ack_num=%d]\n",
            //                atomic_read(&g_dma_flag), atomic_read(&g_cam_flag), atomic_read(&g_cam_done), atomic_read(&g_ack_num));
            //     else
            //         printk(KERN_ERR "PCI_GET_IMG Error: Interrupted by signal while waiting for DMA lock [g_dma_flag=%d, g_cam_flag=%d, g_cam_done=%d, g_ack_num=%d]\n",
            //                atomic_read(&g_dma_flag), atomic_read(&g_cam_flag), atomic_read(&g_cam_done), atomic_read(&g_ack_num));
                
            //     up(&pci_pango->_sem);
            //     return (ret_cam == 0) ? -ETIMEDOUT : -ERESTARTSYS;
            // }

            // // --- 4. 准备数据：写入对应索引的应答值 ---
            // if (dma_info.addr_r.data_buf) {
            //     // 根据逻辑：第1次写0x1, 第2次0x10...
            //     *(uint32_t *)(dma_info.addr_r.data_buf) = current_ack_val;
            //     printk(KERN_INFO "PCI_GET_IMG: Buffer[%d] AckValue=0x%08x\n", current_idx, current_ack_val);
            // } 
			// else {
			// 	printk(KERN_ERR "PCI_GET_IMG Error: TX data_buf is NULL [g_dma_flag=%d, g_cam_flag=%d, g_cam_done=%d, g_ack_num=%d]\n",
            //            atomic_read(&g_dma_flag), atomic_read(&g_cam_flag), atomic_read(&g_cam_done), atomic_read(&g_ack_num));
            //     atomic_set(&g_dma_flag, 0);
            //     up(&pci_pango->_sem);
            //     return -ENOMEM;
            // }

            // // --- 5. 配置并启动 DMA ---
			// spin_lock(&dma_info.addr_r.lock);
            // dma_operation.ddr3_addr    = CAM_ACK; // 目标寄存器地址
            // dma_operation.total_length = 4;
            // dma_info.cmd.data.op_type  = 0;      // Host to FPGA
			// dma_info.cmd.data.length = (dma_operation.total_length >= MAX_TRANSFER_SIZE) ?
            //                   (MAX_TRANSFER_SIZE / 4) : (dma_operation.total_length / 4);
            // set_ddr3_addr(dma_operation.ddr3_addr, pci_pango);
            // set_dma_addr(&dma_info.addr_r, pci_pango);
            // set_total_length(dma_operation.total_length, pci_pango);

            // int old_msi = atomic_read(&g_msi.count);
            // set_dma_w_r(dma_info.cmd.value, pci_pango);
			// spin_unlock(&dma_info.addr_r.lock);

            // // 等待传输完成
            // ret_cam = wait_event_interruptible_timeout(g_msi.queue, 
            //                                            atomic_read(&g_msi.count) != old_msi, 
            //                                            msecs_to_jiffies(100));
            
            // if (ret_cam > 0) {
            //     // 成功：索引更新
            //     atomic_set(&g_ack_num, (current_idx + 1) % MAX_CAM_BUFFS);
            // } else {
            //     if (ret_cam == 0)
            //         printk(KERN_ERR "PCI_GET_IMG Error: Timeout waiting for ACK DMA transfer done [g_msi.count=%d, g_dma_flag=%d, g_cam_flag=%d, g_cam_done=%d, g_ack_num=%d]\n",
            //                atomic_read(&g_msi.count), atomic_read(&g_dma_flag), atomic_read(&g_cam_flag), atomic_read(&g_cam_done), atomic_read(&g_ack_num));
            //     else
            //         printk(KERN_ERR "PCI_GET_IMG Error: Interrupted by signal while waiting for ACK DMA [g_dma_flag=%d, g_cam_flag=%d, g_cam_done=%d, g_ack_num=%d]\n",
            //                atomic_read(&g_dma_flag), atomic_read(&g_cam_flag), atomic_read(&g_cam_done), atomic_read(&g_ack_num));
                
            //     atomic_set(&g_dma_flag, 0);
            //     up(&pci_pango->_sem);
            //     return (ret_cam == 0) ? -ETIMEDOUT : -ERESTARTSYS;
            // }
        }
        break;
	}
	
	up (&pci_pango->_sem);
    return 0;
}


int pango_cdev_open(struct inode *inode, struct file *filp)
{
// 【修复 1】每次启动应用，强制重置所有驱动状态，对齐应用的 buffer_index = 0
    atomic_set(&g_dma_flag, 0);
    atomic_set(&g_cam_flag, 0);
    atomic_set(&g_cam_done, 0);
	atomic_set(&g_npu_flag, 0);
	atomic_set(&g_npu_done, 0);
    
    // 强制内核的 buffer 索引归零，严格对齐 main.cpp 中的 buffer_index = 0
    atomic_set(&read_img_num, 0);
    atomic_set(&g_ack_num, 0);
    
    // 清空休眠队列中的残留信号
    wake_up_all(&g_msi.queue);
	return 0;
}

int pango_cdev_release(struct inode *inode, struct file *filp)
{
	LOG("pango_cdev_release.\n");

    // 【修复 3】如果用户态程序异常崩溃没有发 UMAP，这里自动兜底清理
    if (dma_info.addr_r.data_buf) {
        dma_free_coherent(&op_dev->dev, g_dma_alloc_size_r, dma_info.addr_r.data_buf, dma_info.addr_r.addr);
        dma_info.addr_r.data_buf = NULL;
    }
    if (dma_info.addr_w.data_buf) {
        dma_free_coherent(&op_dev->dev, g_dma_alloc_size_w, dma_info.addr_w.data_buf, dma_info.addr_w.addr);
        dma_info.addr_w.data_buf = NULL;
    }

    // 清理标志位，彻底停止底层逻辑运作
    atomic_set(&g_cam_flag, 0);
    atomic_set(&g_cam_done, 0);
	atomic_set(&g_npu_flag, 0);
    atomic_set(&g_npu_done, 0);
	atomic_set(&read_img_num, 0);
    atomic_set(&g_ack_num, 0);
	return 0;
}



static int set_dma_mask(struct pci_dev *pdev)
{
    if(!pdev)
    {
        LOG("Invalid pdev\n");
        return -EINVAL;
    }

    LOG("sizeof(dma_addr_t) == %ld\n", sizeof(dma_addr_t));

    /* 64-bit addressing capability for XDMA? */
    if (!dma_set_mask(&pdev->dev, DMA_BIT_MASK(64))) {
        /* query for DMA transfer */
        /* @see Documentation/DMA-mapping.txt */
        LOG("pci_set_dma_mask()\n");
        /* use 64-bit DMA */
        LOG("Using a 64-bit DMA mask.\n");
        /* use 32-bit DMA for descriptors */
        dma_set_coherent_mask(&pdev->dev, DMA_BIT_MASK(64));
        /* use 64-bit DMA, 32-bit for consistent */
    } 
	else if (!dma_set_mask(&pdev->dev, DMA_BIT_MASK(32))) {
        LOG("Could not set 64-bit DMA mask.\n");
        dma_set_coherent_mask(&pdev->dev, DMA_BIT_MASK(32));
        /* use 32-bit DMA */
        LOG("Using a 32-bit DMA mask.\n");
    } else {
        LOG("No suitable DMA possible.\n");
        return -EINVAL;
    }

    return 0;
}


static void pci_keep_intx_enabled(struct pci_dev *pdev)
{
    unsigned short pcmd, pcmd_new;

    pci_read_config_word(pdev, PCI_COMMAND, &pcmd);
    pcmd_new = pcmd & ~PCI_COMMAND_INTX_DISABLE;
    if (pcmd_new != pcmd) {
        LOG("%s: clear INTX_DISABLE, 0x%x -> 0x%x.\n",
            dev_name(&pdev->dev), pcmd, pcmd_new);
        pci_write_config_word(pdev, PCI_COMMAND, pcmd_new);
    }

    LOG("pci_keep_intx_enabled.\n");
}





void read_img(void)
{
    int curr_idx;
    uint32_t target_addr;
	struct PciPango *pci_pango = &pci_info;


    // 1. 获取当前缓冲区索引
    curr_idx = atomic_read(&read_img_num);
    target_addr = cam_buffer_addrs[curr_idx];

    // printk(KERN_INFO "read_img(): filling buffer [%d] at addr 0x%08x\n", curr_idx, target_addr);

	// spin_lock(&dma_info.addr_w.lock);
    // 2. 配置 DMA 寄存器
    dma_operation.ddr3_addr   = target_addr;
    dma_operation.offset_addr = CAM_SIZE * curr_idx;
    dma_operation.total_length = CAM_SIZE;
    
    dma_info.cmd.data.op_type = 1; // 写操作
	//先发按页对齐的字节数
    dma_info.cmd.data.length = (dma_operation.total_length >= MAX_TRANSFER_SIZE) ?
                               (MAX_TRANSFER_SIZE / 4) : (dma_operation.total_length / 4);

    set_ddr3_addr(dma_operation.ddr3_addr, pci_pango);
    
    temp_dma_addr_w = dma_info.addr_w;
	temp_dma_addr_w.addr = temp_dma_addr_w.addr + dma_operation.offset_addr;
    
    set_dma_addr(&temp_dma_addr_w, pci_pango);
    set_total_length(dma_operation.total_length, pci_pango);
    
    // 触发硬件开始工作
    set_dma_w_r(dma_info.cmd.value, pci_pango);
	// spin_unlock(&dma_info.addr_w.lock);

    // 3. 更新索引，指向下一个缓冲区 (实现 0->1->2->3->0)
    // 使用取模运算保证循环
    atomic_set(&read_img_num, (curr_idx + 1) % MAX_CAM_BUFFS);
			
}


void read_npu(void)
{
    struct PciPango *pci_pango = &pci_info;

    // 1. 配置 DMA 寄存器：指定源地址和目标偏移
    dma_operation.ddr3_addr   = 0x40000000;    // NPU 在 FPGA 的物理地址
    dma_operation.offset_addr = 0x384000;      // 搬运至内核 RX 缓冲区的偏移位置
    
    // 注意：您未在需求中说明 NPU 数据的大小！
    // 必须将这里的 0x1000 替换为您实际需要搬运的字节数 (例如 NPU_DATA_SIZE)
    dma_operation.total_length = 0x99CF0;       
    
    dma_info.cmd.data.op_type = 1; // 写操作：FPGA 写入 内核

    // 2. 发送按页对齐的字节数
    dma_info.cmd.data.length = (dma_operation.total_length >= MAX_TRANSFER_SIZE) ?
                               (MAX_TRANSFER_SIZE / 4) : (dma_operation.total_length / 4);

    set_ddr3_addr(dma_operation.ddr3_addr, pci_pango);
    
    temp_dma_addr_w = dma_info.addr_w;
    temp_dma_addr_w.addr = temp_dma_addr_w.addr + dma_operation.offset_addr;
    
    set_dma_addr(&temp_dma_addr_w, pci_pango);
    set_total_length(dma_operation.total_length, pci_pango);
    
    // 3. 触发硬件开始工作
    set_dma_w_r(dma_info.cmd.value, pci_pango);
}


//中断处理函数 DMA
static irqreturn_t pango_irq_handler0(int irq, void *dev_id)
{
    int old_state;

    // 1. 释放 DMA 锁定状态
    old_state = atomic_xchg(&g_dma_flag, 0);
    
    if (old_state == 1) {
        atomic_inc(&g_msi.count);
    }
	else if (old_state == 2) {
        atomic_inc(&g_cam_done);     // 相机搬运完成
    } 
	else if (old_state == 3) {
        atomic_inc(&g_npu_done);     // 新增：NPU搬运完成
    }

    // 2. 调度排队请求（这里默认 Camera 优先级高于 NPU，你可以根据需要对调）
    //注意：如果有请求，重新抢占 DMA (0 -> 2)
    if (atomic_read(&g_cam_flag) > 0) {
        // 【修复 2.2】处理排队中断时，同样检测内存是否有效
        if (!dma_info.addr_w.data_buf) {
            atomic_set(&g_cam_flag, 0); // 内存无效，直接清空排队
        }
		else if (atomic_cmpxchg(&g_dma_flag, 0, 2) == 0) {
            atomic_dec(&g_cam_flag); // 消耗一个排队请求
            read_img();
        }
    } 
    // 新增：如果相机没排队，检查 NPU 是否有排队
    else if (atomic_read(&g_npu_flag) > 0) {
		if (!dma_info.addr_w.data_buf) {
            atomic_set(&g_npu_flag, 0); // 内存无效，直接清空排队
        }
        else if (atomic_cmpxchg(&g_dma_flag, 0, 3) == 0) {
            atomic_dec(&g_npu_flag); 
            read_npu();
        }
    }

    wake_up_interruptible(&g_msi.queue);
    return IRQ_HANDLED;
}

//摄像头处理函数
static irqreturn_t pango_irq_handler1(int irq, void *dev_id)
{
	// printk(KERN_ERR "pango_irq_handler1: [g_dma_flag=%d, g_cam_flag=%d, g_cam_done=%d, g_ack_num=%d]\n",
    //                        atomic_read(&g_dma_flag), atomic_read(&g_cam_flag), atomic_read(&g_cam_done), atomic_read(&g_ack_num));
   
	// 如果 DMA 内存已被释放或尚未映射，说明 App 没在运行，直接丢弃该中断
    if (!dma_info.addr_w.data_buf) {
        return IRQ_HANDLED;
    }
	// 尝试抢占 DMA 权限
    if (atomic_cmpxchg(&g_dma_flag, 0, 2) == 0) {
        // DMA 空闲，立即开始 read_img
        read_img();
    } 
    else {
        // DMA 正忙，增加排队计数
        atomic_inc(&g_cam_flag);
    }
	
    return IRQ_HANDLED;
}



// =====================================================================
// 第3个中断处理函数：用于 NPU 数据搬运
// =====================================================================
static irqreturn_t pango_irq_handler2(int irq, void *dev_id)
{
	if (!dma_info.addr_w.data_buf) {
        return IRQ_HANDLED;
    }
    // 尝试抢占 DMA 权限，并将状态设为 3 (NPU)
    if (atomic_cmpxchg(&g_dma_flag, 0, 3) == 0) {
        // DMA 空闲，立即开始 read_npu
        read_npu();
    } 
    else {
        // DMA 正忙，增加 NPU 的排队计数
        atomic_inc(&g_npu_flag);
    }
    
    return IRQ_HANDLED;
}


///////////////////////////////////////////////////////////////////////

int pci_driver_probe(struct pci_dev *dev, const struct pci_device_id *device_id)
{
	int result = 0;
	unsigned long bar_address = 0;
	int ret = 0;
	LOG("pci_driver_probe.\n");
	
    LOG("dev vendor : 0x%x, device : 0x%x\n", dev->vendor, dev->device);
	
    result = pci_enable_device(dev);									//PCIE设备使能，初始化memory和IO类型的BAR
    LOG("pci_enable_device result : %d\n", result);
	
	if(result != 0)
	{
		goto fail_enable_device;
	}


	// 1. 配置当前设备 (Endpoint) 的最大载荷与读请求大小
	pcie_set_mps(dev, 256);
	pcie_set_readrq(dev, 1024);
	
	// 2. 嵌套调用 pci_upstream_bridge(dev) 获取并配置上游桥设备 (Root Port)
	if (pci_upstream_bridge(dev)) {
	    pcie_set_mps(pci_upstream_bridge(dev), 256);
	    pcie_set_readrq(pci_upstream_bridge(dev), 1024);
	}
	
	// 打印最终生效的参数进行确认
	printk(KERN_INFO "PCIe Link: MPS=%d, MRRS=%d\n", pcie_get_mps(dev), pcie_get_readrq(dev));
    // ------------------------------------


	//辅助函数用于检查总线是否可以接收给定大小的总线地址(mask)，如果可以，则通知总线层给定的外围设备将使用该大小的总线地址。
	result = set_dma_mask(dev);
	
	if(result != 0)
	{
		goto fail_set_dma_mask;
	}
	
	ReadConfig(dev);
	op_dev = dev;
	pci_set_master(dev);												//设定设备工作在总线主设备模式
	//通知内核该设备对应的IO端口和内存资源已经使用，其他的PCI设备不要再使用这个区域
	//获得当前pci设备对应的IO端口和IO内存的基址。
    result = pci_request_region(dev, pci_info._pango_pci_driver._pci_bar, NULL);
    LOG("pci_request_region result : %d\n", result);
	
	if(result != 0)
	{
		goto fail_request_region;
	}
	
	pci_info._pango_pci_driver._pci_io_size = pci_resource_len(dev, pci_info._pango_pci_driver._pci_bar);		//获取bar的物理地址范围
	bar_address = pci_resource_start(dev, pci_info._pango_pci_driver._pci_bar);									//获取bar的物理地址
	pci_info._pango_pci_driver._pci_io      = ioremap(bar_address, pci_info._pango_pci_driver._pci_io_size); 	//将bar的物理地址进行虚拟地址映射
	pci_info._pango_pci_driver._pci_io_buff = kmalloc(pci_info._pango_pci_driver._pci_io_size, GFP_KERNEL);
	
    result = pci_info._pango_pci_driver._pci_io != NULL ? 0 : -1;
    LOG("ioremap result : %d\n", result);
    
	pci_keep_intx_enabled(dev);

	// 初始化等待队列和计数器
	atomic_set(&g_msi.count, 0);
	init_waitqueue_head(&g_msi.queue);

	// MSI中断
	// 1. 申请MSI中断向量
    ret = pci_alloc_irq_vectors(dev, 1, 5, PCI_IRQ_MSI);
    if (ret < 0) {
        printk(KERN_ERR "MSI vector alloc failed: %d\n", ret);
        // 可以降级尝试INTx
        goto fail_msi;
    }

    // 注册中断服务函数  请把这个 dev（PCI设备）申请到的第 0 个MSI 中断的号码给我
    ret = request_irq(pci_irq_vector(dev, 0), pango_irq_handler0, 0, IRQ_NAME0, dev);
    if (ret) {
        printk(KERN_ERR "request_irq0 MSI failed: %d\n", ret);
        pci_free_irq_vectors(dev);
        goto fail_irq;
    }
    printk(KERN_INFO "MSI Interrupt0 registered.\n");

	ret = request_irq(pci_irq_vector(dev, 1), pango_irq_handler1, 0, IRQ_NAME1, dev);
    if (ret) {
        printk(KERN_ERR "request_irq1 MSI failed: %d\n", ret);
        pci_free_irq_vectors(dev);
        goto fail_irq;
    }
    printk(KERN_INFO "MSI Interrupt1 registered.\n");
	

	ret = request_irq(pci_irq_vector(dev, 2), pango_irq_handler2, 0, IRQ_NAME2, dev);
    if (ret) {
        printk(KERN_ERR "request_irq2 MSI failed: %d\n", ret);
        pci_free_irq_vectors(dev);
        goto fail_irq;
    }
    printk(KERN_INFO "MSI Interrupt2 registered.\n");

	return result;

fail_irq:
	return ret;
fail_msi:
    // release/disable处理
    return ret;

fail_request_region:
    pci_clear_master(dev);
    LOG("pci_clear_master\n");
	
fail_set_dma_mask:
    pci_disable_device(dev);
    LOG("pci_disable_device\n");

fail_enable_device:
	
	return result;
}

void pci_driver_remove(struct pci_dev *dev)
{
	// 注销绑定的中断服务函数
    free_irq(pci_irq_vector(dev, 0), dev);
	free_irq(pci_irq_vector(dev, 1), dev);
	free_irq(pci_irq_vector(dev, 2), dev);
	//释放分配的 MSI 中断向量
    pci_free_irq_vectors(dev);
	//强制唤醒所有队列里的进程
    wake_up_all(&g_msi.queue);
	
	kfree(pci_info._pango_pci_driver._pci_io_buff);
	
    iounmap(pci_info._pango_pci_driver._pci_io);
    LOG("iounmap\n");
	
    pci_release_region(dev, pci_info._pango_pci_driver._pci_bar);
    LOG("pci_release_region\n");
	
    pci_clear_master(dev);
    LOG("pci_clear_master\n");
	
    pci_disable_device(dev);
    LOG("pci_disable_device\n");
	
	LOG("pci_driver_remove.\n");
}

///////////////////////////////////////////////////////////////////////

int init_pango_cdev(struct cdev *pango_cdev)
{
	int result = 0;
	
	LOG("init_pango_cdev.\n");
	
	result = alloc_chrdev_region(&pci_dev_info._dev, pci_dev_info._dev_firstminor, pci_dev_info._dev_count, pci_dev_info._dev_name);
	
	LOG("*********alloc_chrdev_region, result : %d\n", result);
	
	if(result < 0)
	{
		return result;
	}
	
	cdev_init(pango_cdev, &pango_cdev_fops);
	
	pango_cdev->owner = THIS_MODULE;
	pango_cdev->ops   = &pango_cdev_fops;
	
	result = cdev_add(pango_cdev, pci_dev_info._dev, pci_dev_info._dev_count);							//关联设备号
	
	LOG("init pango_cdev result : %d\n", result);
	
	return result;
}

void exit_pango_cdev(struct cdev *pango_cdev)
{
	cdev_del(pango_cdev);
	
	unregister_chrdev_region(pci_dev_info._dev, pci_dev_info._dev_count);
	
	LOG("exit cdev.\n");
}

int init_pango_pci_driver(struct pci_driver *pango_pci_driver)
{
	int result = 0;
	
	LOG("init_pango_pci_driver.\n");
	
	result = pci_register_driver(pango_pci_driver);						//注册PCI驱动
	
	LOG("*********pci_register_driver, result : %d\n", result);
	
	return result;
}

void exit_pango_pci_driver(struct pci_driver *pango_pci_driver)
{
	pci_unregister_driver(pango_pci_driver);
	
	LOG("exit pci pango driver.\n");
}


int init_pango_cdev_class(void)
{
    pci_info._cdev_class = class_create(THIS_MODULE, pci_dev_info._dev_name);
    if (IS_ERR(pci_info._cdev_class))
        return PTR_ERR(pci_info._cdev_class);
    
    device_create(pci_info._cdev_class, NULL, pci_dev_info._dev, NULL, "%s", pci_dev_info._dev_name);
    return 0;
}

void exit_pango_cdev_class(void)
{
	LOG("device_destroy\n");

	device_destroy(pci_info._cdev_class, pci_dev_info._dev);
	
	LOG("class_destroy\n");
	class_destroy(pci_info._cdev_class);
	
	pci_info._cdev_class = NULL;
	
	LOG("exit cdev class.\n");
}

///////////////////////////////////////////////////////////////////////

int __init init_pci_pango(void)
{
	int result = 0;
	
	LOG("init_pci_pango.\n");
	
	result = init_pango_cdev(&pci_info._cdev);						//申请主设备号
	LOG("init cdev result : %d\n", result);
	
	result = init_pango_pci_driver(&pci_info._pango_pci_driver._pci_driver);
	LOG("init pci result : %d\n", result);
	
	sema_init(&pci_info._sem, 1);
	LOG("sema_init.\n");
	
	result = init_pango_cdev_class();
	LOG("init cdev class result : %d\n", result);
	
	return result;
}

void __exit exit_pci_pango(void)
{
	exit_pango_cdev_class();
	
	exit_pango_pci_driver(&pci_info._pango_pci_driver._pci_driver);
	
	exit_pango_cdev(&pci_info._cdev);
	
	LOG("exit_pci_pango.\n");
}

module_init(init_pci_pango);
module_exit(exit_pci_pango);


/* 添加模块描述信息 */
/* 添加模块描述信息 */

MODULE_AUTHOR("Pango, lxg.");                                                          /* 作者信息 */
MODULE_DESCRIPTION("Pango pci driver");                                                /* 模块介绍信息 */
MODULE_LICENSE("GPL v2");                                                              /* 模块许可证 */
MODULE_ALIAS("pango pci driver");                                                      /* 模块的别名信息 */


