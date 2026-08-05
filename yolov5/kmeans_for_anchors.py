#-------------------------------------------------------------------------------------------------------#
#   kmeans会对数据集中的框进行聚类，生成 yolo_anchors.txt
#-------------------------------------------------------------------------------------------------------#
import matplotlib.pyplot as plt
import numpy as np
import os
from PIL import Image
from tqdm import tqdm

from utils.paths import DATA_ROOT


def cas_ratio(box, cluster):
    ratios_of_box_cluster = box / cluster
    ratios_of_cluster_box = cluster / box
    ratios = np.concatenate([ratios_of_box_cluster, ratios_of_cluster_box], axis=-1)
    return np.max(ratios, -1)


def avg_ratio(box, cluster):
    return np.mean([np.min(cas_ratio(box[i], cluster)) for i in range(box.shape[0])])


def kmeans(box, k):
    row = box.shape[0]
    distance = np.empty((row, k))
    last_clu = np.zeros((row,))

    np.random.seed()

    cluster = box[np.random.choice(row, k, replace=False)]

    iter = 0
    while True:
        for i in range(row):
            distance[i] = cas_ratio(box[i], cluster)

        near = np.argmin(distance, axis=1)

        if (last_clu == near).all():
            break

        for j in range(k):
            cluster[j] = np.median(box[near == j], axis=0)

        last_clu = near
        if iter % 5 == 0:
            print('iter: {:d}. avg_ratio:{:.2f}'.format(iter, avg_ratio(box, cluster)))
        iter += 1

    return cluster, near


def load_data(path):
    data = []
    with open(path, encoding='utf-8') as f:
        lines = [l.strip() for l in f if l.strip()]

    for line in tqdm(lines):
        parts = line.split()
        img_path = parts[0]
        boxes = parts[1:]
        if len(boxes) == 0:
            continue

        try:
            with Image.open(img_path) as img:
                width, height = img.size
        except (FileNotFoundError, OSError):
            continue
        if height <= 0 or width <= 0:
            continue

        for box in boxes:
            v = box.split(',')
            if len(v) < 4:
                continue
            xmin, ymin, xmax, ymax = (float(v[0]), float(v[1]), float(v[2]), float(v[3]))
            w = (xmax - xmin) / width
            h = (ymax - ymin) / height
            if w <= 0 or h <= 0:
                continue
            data.append([w, h])
    return np.array(data)


if __name__ == '__main__':
    np.random.seed(0)
    input_shape = [640, 640]
    anchors_num = 9
    path = os.path.join(DATA_ROOT, 'CCPD_CRPD_train.txt')

    print('Load annotations.')
    data = load_data(path)
    print('Load annotations done.')

    print('K-means boxes.')
    cluster, near = kmeans(data, anchors_num)
    print('K-means boxes done.')
    data = data * np.array([input_shape[1], input_shape[0]])
    cluster = cluster * np.array([input_shape[1], input_shape[0]])

    for j in range(anchors_num):
        plt.scatter(data[near == j][:, 0], data[near == j][:, 1])
        plt.scatter(cluster[j][0], cluster[j][1], marker='x', c='black')
    plt.savefig("kmeans_for_anchors.jpg")
    plt.show()
    print('Save kmeans_for_anchors.jpg in root dir.')

    cluster = cluster[np.argsort(cluster[:, 0] * cluster[:, 1])]
    print('avg_ratio:{:.2f}'.format(avg_ratio(data, cluster)))
    print(cluster)

    with open("model_data/yolo_anchors.txt", 'w') as f:
        row = np.shape(cluster)[0]
        for i in range(row):
            if i == 0:
                x_y = "%d,%d" % (cluster[i][0], cluster[i][1])
            else:
                x_y = ", %d,%d" % (cluster[i][0], cluster[i][1])
            f.write(x_y)
