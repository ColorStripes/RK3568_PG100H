import os

import cv2 as cv
import numpy as np
import torch
from torch.ao.quantization import QConfig, HistogramObserver, default_weight_observer

from nets.yolov5n import YoloV5n
from utils.paths import DATA_ROOT, ROOT
from utils.utils import get_anchors, get_classes, preprocess_input, show_config

anchors_path = 'model_data/yolo_anchors.txt'
anchors_mask = [[6, 7, 8], [3, 4, 5], [0, 1, 2]]
classes_path = 'model_data/CCPD_CRPD_classes.txt'
phi = 0
class_names, num_classes = get_classes(classes_path)
anchors, num_anchors = get_anchors(anchors_path)

state_dict = torch.load(os.path.join(ROOT, 'logs/best_epoch_weights.pth'))

model_fp32 = YoloV5n(num_classes)
model_fp32.load_state_dict(state_dict)
model_fp32.float()

model_fp32.eval().fuse_model()

model_fp32.qconfig = QConfig(
    activation=HistogramObserver.with_args(reduce_range=False),
    weight=default_weight_observer,
)

model_fp32_prepared = torch.quantization.prepare(model_fp32)

img_path = os.path.join(DATA_ROOT, 'CCPD_CRPD_val.txt')
epoch = 2000

with open(img_path, 'r') as f:
    for i in range(epoch):
        print('epoch : ' + str(i))
        line = f.readline()
        if not line:
            break
        path = line.split()[0]
        img = cv.imread(path)
        if img is None:
            continue
        img = cv.resize(img, (640, 640))
        img = cv.cvtColor(img, cv.COLOR_BGR2RGB)
        image_data = np.expand_dims(
            np.transpose(preprocess_input(np.array(img, dtype='float32')), (2, 0, 1)), 0
        )
        images = torch.from_numpy(image_data)
        model_fp32_prepared(images)

model_int8 = torch.quantization.convert(model_fp32_prepared)
print('model int8', model_int8)

torch.jit.save(torch.jit.script(model_int8.eval()), os.path.join(ROOT, 'model_data/ccpd_crpd_quant_jit.pth'))
torch.save(model_int8.state_dict(), os.path.join(ROOT, 'model_data/ccpd_crpd_quant.pth'))
print('已保存:', os.path.join(ROOT, 'model_data/ccpd_crpd_quant.pth'))
print('已保存:', os.path.join(ROOT, 'model_data/ccpd_crpd_quant_jit.pth'))
