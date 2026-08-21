/**
 * pci_dma_bridge.cpp — PCIe DMA 底层接口 (main_npu / dma_bridge_rga 共用)
 */

#include "../includes/pcie_dma_read_test.h"
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <cstdio>
#include <cerrno>
#include <cstring>

int pci_driver_fd = -1;
COMMAND_OPERATION command_operation;
DMA_OPERATION dma_operation;

int open_pci_driver(void)
{
    int fd = open(PCIE_DRIVER_FILE_PATH, O_RDWR);
    if (fd < 0) {
        perror("open pci driver fail");
        return -1;
    }
    return fd;
}


int pci_dma_single_write(int pci_driver_fd, uint32_t start_ddr3_addr, uint32_t mmp_offset, uint32_t total_size)
{
    dma_operation.offset_addr  = mmp_offset;
    dma_operation.ddr3_addr    = start_ddr3_addr;
    dma_operation.total_length = total_size;

    int ret = ioctl(pci_driver_fd, PCI_DMA_READ_CMD, &dma_operation);
    if (ret < 0) {
        printf("PCI_DMA_READ_CMD 失败! 目标地址: 0x%08X, 错误码: %d (%s)\n",
               start_ddr3_addr, errno, strerror(errno));
        return -1;
    }
    return 0;
}

int pci_dma_single_read(int pci_driver_fd, uint32_t start_ddr3_addr, uint32_t mmp_offset, uint32_t total_size)
{
    dma_operation.offset_addr  = mmp_offset;
    dma_operation.ddr3_addr    = start_ddr3_addr;
    dma_operation.total_length = total_size;

    int ret = ioctl(pci_driver_fd, PCI_DMA_WRITE_CMD, &dma_operation);
    if (ret < 0) {
        printf("PCI_DMA_WRITE_CMD 失败! 目标地址: 0x%08X, 错误码: %d (%s)\n",
               start_ddr3_addr, errno, strerror(errno));
        return -1;
    }
    return 0;
}

DMA_DATA pci_mmp(int pci_driver_fd, int cmd, uint32_t total_size_tx, uint32_t total_size_rx)
{
    DMA_DATA mmp = {};
    unsigned long page_size = getpagesize();
    unsigned long mmap_size_tx = (total_size_tx + page_size - 1) & ~(page_size - 1);
    unsigned long mmap_size_rx = (total_size_rx + page_size - 1) & ~(page_size - 1);

    if (cmd == 0) {
        mmp.write_buf = mmap(NULL, mmap_size_tx, PROT_READ | PROT_WRITE, MAP_SHARED, pci_driver_fd, 0);
        if (mmp.write_buf == MAP_FAILED)
            printf("mmap TX buffer failed!\n");
    } else if (cmd == 1) {
        mmp.read_buf = mmap(NULL, mmap_size_rx, PROT_READ | PROT_WRITE, MAP_SHARED, pci_driver_fd, RX_MMAP_OFFSET);
        if (mmp.read_buf == MAP_FAILED)
            printf("mmap RX buffer failed!\n");
    } else if (cmd == 3) {
        mmp.write_buf = mmap(NULL, mmap_size_tx, PROT_READ | PROT_WRITE, MAP_SHARED, pci_driver_fd, 0);
        if (mmp.write_buf == MAP_FAILED)
            printf("mmap TX buffer failed!\n");
        mmp.read_buf = mmap(NULL, mmap_size_rx, PROT_READ | PROT_WRITE, MAP_SHARED, pci_driver_fd, RX_MMAP_OFFSET);
        if (mmp.read_buf == MAP_FAILED)
            printf("mmap RX buffer failed!\n");
    }
    return mmp;
}

int pci_umap(int pci_driver_fd)
{
    dma_operation.cmd = 3;
    int ret = ioctl(pci_driver_fd, PCI_UMAP_ADDR_CMD, &dma_operation);
    if (ret < 0) {
        printf("PCI_UMAP_ADDR_CMD 释放缓存失败! 错误码: %d (%s)\n", errno, strerror(errno));
        return -1;
    }
    return 0;
}

int pci_map(int pci_driver_fd, int cmd, uint32_t total_size_tx, uint32_t total_size_rx)
{
    int ret;
    if (cmd == 0) {
        dma_operation.cmd = 0;
        dma_operation.total_length = total_size_tx;
        ret = ioctl(pci_driver_fd, PCI_MAP_ADDR_CMD, &dma_operation);
        if (ret < 0) {
            // EBUSY = 驱动 DMA 缓冲已被其他 .so 实例分配 (NPU/相机共享映射场景):
            // 不得 pci_umap (会释放他人正在使用的全局缓冲), 调用方自行 pci_mmp 复用。
            if (errno != EBUSY) pci_umap(pci_driver_fd);
            return -1;
        }
    } else if (cmd == 1) {
        dma_operation.cmd = 1;
        dma_operation.total_length = total_size_rx;
        ret = ioctl(pci_driver_fd, PCI_MAP_ADDR_CMD, &dma_operation);
        if (ret < 0) {
            // EBUSY = 驱动 DMA 缓冲已被其他 .so 实例分配 (NPU/相机共享映射场景):
            // 不得 pci_umap (会释放他人正在使用的全局缓冲), 调用方自行 pci_mmp 复用。
            if (errno != EBUSY) pci_umap(pci_driver_fd);
            return -1;
        }
    } else if (cmd == 3) {
        dma_operation.cmd = 0;
        dma_operation.total_length = total_size_tx;
        ret = ioctl(pci_driver_fd, PCI_MAP_ADDR_CMD, &dma_operation);
        if (ret < 0) {
            // EBUSY = 驱动 DMA 缓冲已被其他 .so 实例分配 (NPU/相机共享映射场景):
            // 不得 pci_umap (会释放他人正在使用的全局缓冲), 调用方自行 pci_mmp 复用。
            if (errno != EBUSY) pci_umap(pci_driver_fd);
            return -1;
        }

        dma_operation.cmd = 1;
        dma_operation.total_length = total_size_rx;
        ret = ioctl(pci_driver_fd, PCI_MAP_ADDR_CMD, &dma_operation);
        if (ret < 0) {
            // EBUSY = 驱动 DMA 缓冲已被其他 .so 实例分配 (NPU/相机共享映射场景):
            // 不得 pci_umap (会释放他人正在使用的全局缓冲), 调用方自行 pci_mmp 复用。
            if (errno != EBUSY) pci_umap(pci_driver_fd);
            return -1;
        }
    }
    return 0;
}
