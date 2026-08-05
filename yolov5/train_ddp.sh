#!/bin/bash
# 4卡 DDP 训练启动脚本（Docker 环境需关闭 NCCL P2P/IB）
export NCCL_P2P_DISABLE=1
export NCCL_IB_DISABLE=1
export OMP_NUM_THREADS=1

CUDA_VISIBLE_DEVICES=0,1,2,3 torchrun --nproc_per_node=4 train_yolov5n.py
