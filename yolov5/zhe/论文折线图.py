import matplotlib.pyplot as plt

# 恢复默认设置
plt.rcParams.update(plt.rcParamsDefault)

# 1. 准备数据
x_labels = ['2', '4', '8', '16']
x_indices = range(len(x_labels))

local_prefetch = [53.5, 40.76, 23.08, 13.89]
global_prefetch = [50.08, 34.6, 19.37, 12.36]

# 2. 创建画布
fig, ax = plt.subplots(figsize=(8, 5), dpi=150)

# 3. 绘制折线
ax.plot(x_indices, local_prefetch, marker='o', markersize=8, linewidth=2.5,
        color='#2878B5', label='local circular prefetching')
ax.plot(x_indices, global_prefetch, marker='s', markersize=8, linewidth=2.5,
        color='#C82423', label='global one-time prefetching')

# 4. 添加数据标签
for i, (loc, glob) in enumerate(zip(local_prefetch, global_prefetch)):
    ax.text(x_indices[i], loc + 1.5, f"{loc:.2f}", ha='center', va='bottom', color='#2878B5', fontweight='bold')
    ax.text(x_indices[i], glob - 2.5, f"{glob:.2f}", ha='center', va='top', color='#C82423', fontweight='bold')

# 5. 设置横坐标
ax.set_xticks(x_indices)
ax.set_xticklabels(x_labels, fontsize=11)

# 6. 设置标题和轴标签
ax.set_title('Performance Comparison of Local and Global Prefetching', fontsize=16, pad=20, fontweight='bold')
ax.set_xlabel('Output Parallelism (Pₒᵤₜ)', fontsize=12, labelpad=10)
ax.set_ylabel('Inference Latency (ms)', fontsize=12, labelpad=10)

# ==================== 核心修改部分 ====================

# 【修改 1】拉伸 Y 轴的上下限范围 (从 5 到 62)
# 这样底部有足够的空间给 12.36，顶部有足够的空间给图例
ax.set_ylim(5, 62)

# =======================================================

# 7. 图表美化
ax.grid(True, axis='y', linestyle='--', alpha=0.7)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

# ==================== 核心修改部分 ====================

# 【修改 2】修改图例设置：开启边框(frameon=True)，填充纯白色(facecolor='white')，去掉边框线(edgecolor='none')
# 这样图例就像贴了一块白色的不透明胶布，能完美遮住穿过它的网格线
ax.legend(fontsize=11, frameon=True, facecolor='white', edgecolor='none', framealpha=1)

# =======================================================

# 8. 紧凑布局
plt.tight_layout()

# 9. 导出为高质量 PDF 文件
plt.savefig('Performance_Comparison.pdf', format='pdf', bbox_inches='tight')

# 10. 显示图表
plt.show()