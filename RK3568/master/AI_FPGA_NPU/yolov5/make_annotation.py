# -*- coding: utf-8 -*-
"""
将 CRPD / CCPD 绿牌数据整合为训练标注文件。

收集 DATA_ROOT 下所有数据子目录中的图片（含原 train/val/test），
统一按 9:1 划分为 CCPD_CRPD_train.txt / CCPD_CRPD_val.txt。

CRPD 标签格式（每行一个目标）：
    x1 y1 x2 y2 x3 y3 x4 y4 class 车牌号

CCPD 绿牌标签：编码在文件名中（train / val / test 全部纳入）。

生成的目标格式（每行一张图片）：
    图片绝对路径 xmin,ymin,xmax,ymax,class xmin,ymin,xmax,ymax,class ...

统一类别定义（4 类）：
    0 = 蓝牌        (CRPD type 0)
    1 = 黄牌        (CRPD type 1，丢弃 type 2 双行黄牌)
    2 = 绿牌        (CCPD2020 ccpd_green)
    3 = 特殊牌      (CRPD type 3)
"""

import os
import random

from utils.paths import DATA_ROOT

CRPD_SUBSETS = ["CRPD_single", "CRPD_double", "CRPD_multi"]
CRPD_SPLITS = ["train", "val", "test"]
CCPD_GREEN_DIR = os.path.join("CCPD2020", "ccpd_green")
CCPD_GREEN_SPLITS = ["train", "val", "test"]

TRAIN_RATIO = 0.9
SPLIT_SEED = 42
BLUE_MAX_IMAGES = 20000
BLUE_CLASS = 0
OUTPUTS = {
    "train": "CCPD_CRPD_train.txt",
    "val": "CCPD_CRPD_val.txt",
}

IMAGES_DIR = "images"
LABELS_DIR = "labels"
IMG_EXTS = (".jpg", ".jpeg", ".png", ".bmp")

CRPD_TYPE_MAP = {
    0: 0,
    1: 1,
    2: None,
    3: 3,
}

CCPD_GREEN_CLASS = 2


def quad_to_bbox(coords):
    xs = coords[0::2]
    ys = coords[1::2]
    return min(xs), min(ys), max(xs), max(ys)


def parse_crpd_label(label_path):
    boxes = []
    with open(label_path, "r", encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) < 9:
                continue
            try:
                coords = [int(round(float(p))) for p in parts[:8]]
                raw_type = int(float(parts[8]))
            except ValueError:
                continue
            cls = CRPD_TYPE_MAP.get(raw_type, None)
            if cls is None:
                continue
            xmin, ymin, xmax, ymax = quad_to_bbox(coords)
            boxes.append((xmin, ymin, xmax, ymax, cls))
    return boxes


def parse_ccpd_filename(fname):
    name = os.path.splitext(fname)[0]
    fields = name.split("-")
    if len(fields) < 4:
        return []
    try:
        lt, rb = fields[2].split("_")
        xmin, ymin = (int(v) for v in lt.split("&"))
        xmax, ymax = (int(v) for v in rb.split("&"))
    except (ValueError, IndexError):
        return []
    return [(xmin, ymin, xmax, ymax, CCPD_GREEN_CLASS)]


def boxes_to_str(img_path, boxes):
    box_strs = [f"{x1},{y1},{x2},{y2},{c}" for (x1, y1, x2, y2, c) in boxes]
    return img_path + " " + " ".join(box_strs)


def collect_crpd():
    entries, imgs, box_cnt, missing = [], 0, 0, 0
    for subset in CRPD_SUBSETS:
        for split in CRPD_SPLITS:
            images_dir = os.path.join(DATA_ROOT, subset, split, IMAGES_DIR)
            labels_dir = os.path.join(DATA_ROOT, subset, split, LABELS_DIR)
            if not os.path.isdir(images_dir):
                print(f"[跳过] 目录不存在: {images_dir}")
                continue
            split_imgs = 0
            for fname in sorted(os.listdir(images_dir)):
                if not fname.lower().endswith(IMG_EXTS):
                    continue
                stem = os.path.splitext(fname)[0]
                label_path = os.path.join(labels_dir, stem + ".txt")
                if not os.path.isfile(label_path):
                    missing += 1
                    continue
                boxes = parse_crpd_label(label_path)
                if not boxes:
                    continue
                entries.append((os.path.join(images_dir, fname), boxes))
                imgs += 1
                split_imgs += 1
                box_cnt += len(boxes)
            print(f"    CRPD/{subset}/{split}: 图片 {split_imgs}")
    return entries, imgs, box_cnt, missing


def collect_ccpd_green():
    entries, imgs, box_cnt = [], 0, 0
    for split in CCPD_GREEN_SPLITS:
        images_dir = os.path.join(DATA_ROOT, CCPD_GREEN_DIR, split)
        if not os.path.isdir(images_dir):
            print(f"[跳过] 目录不存在: {images_dir}")
            continue
        split_imgs = 0
        for fname in sorted(os.listdir(images_dir)):
            if not fname.lower().endswith(IMG_EXTS):
                continue
            boxes = parse_ccpd_filename(fname)
            if not boxes:
                continue
            entries.append((os.path.join(images_dir, fname), boxes))
            imgs += 1
            split_imgs += 1
            box_cnt += len(boxes)
        print(f"    CCPD/ccpd_green/{split}: 图片 {split_imgs}")
    return entries, imgs, box_cnt


def has_blue_plate(boxes):
    return any(cls == BLUE_CLASS for *_, cls in boxes)


def subsample_blue_entries(entries):
    """保留全部非蓝牌图片，含蓝牌图片随机下采样至 BLUE_MAX_IMAGES 张。"""
    blue_entries = [e for e in entries if has_blue_plate(e[1])]
    other_entries = [e for e in entries if not has_blue_plate(e[1])]

    if len(blue_entries) <= BLUE_MAX_IMAGES:
        return entries, len(blue_entries), 0

    rng = random.Random(SPLIT_SEED)
    sampled_blue = rng.sample(blue_entries, BLUE_MAX_IMAGES)
    removed = len(blue_entries) - BLUE_MAX_IMAGES
    return other_entries + sampled_blue, len(blue_entries), removed


def split_entries(entries):
    entries = list(entries)
    random.Random(SPLIT_SEED).shuffle(entries)
    train_end = int(len(entries) * TRAIN_RATIO)
    return entries[:train_end], entries[train_end:]


def write_split(entries, output_name):
    lines = [boxes_to_str(img_path, boxes) for img_path, boxes in entries]
    out_path = os.path.join(DATA_ROOT, output_name)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + ("\n" if lines else ""))
    box_cnt = sum(len(boxes) for _, boxes in entries)
    return out_path, len(entries), box_cnt


def main():
    print("收集全部数据...")
    crpd_entries, crpd_imgs, crpd_boxes, crpd_missing = collect_crpd()
    ccpd_entries, ccpd_imgs, ccpd_boxes = collect_ccpd_green()

    all_entries = crpd_entries + ccpd_entries
    all_entries, blue_before, blue_removed = subsample_blue_entries(all_entries)
    if blue_removed:
        print(f"\n蓝牌下采样: {blue_before} -> {BLUE_MAX_IMAGES} 张 (移除 {blue_removed})")

    train_entries, val_entries = split_entries(all_entries)

    train_path, train_imgs, train_boxes = write_split(train_entries, OUTPUTS["train"])
    val_path, val_imgs, val_boxes = write_split(val_entries, OUTPUTS["val"])
    total_boxes = train_boxes + val_boxes

    print()
    print(f"汇总: 图片 {len(all_entries)}, 目标 {total_boxes}")
    print(f"    CRPD  : 图片 {crpd_imgs}, 目标 {crpd_boxes}, 缺失标签 {crpd_missing}")
    print(f"    CCPD  : 图片 {ccpd_imgs}, 目标 {ccpd_boxes} (绿牌)")
    print()
    print(f"[train {TRAIN_RATIO:.0%}] -> {train_path}")
    print(f"    图片 {train_imgs}, 目标 {train_boxes}")
    print(f"[val {1 - TRAIN_RATIO:.0%}] -> {val_path}")
    print(f"    图片 {val_imgs}, 目标 {val_boxes}")
    print("完成。类别: 0=蓝牌 1=黄牌 2=绿牌 3=特殊牌")


if __name__ == "__main__":
    main()
