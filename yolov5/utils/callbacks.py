import datetime
import os

import torch
import matplotlib
matplotlib.use('Agg')
import scipy.signal
from matplotlib import pyplot as plt
from torch.utils.tensorboard import SummaryWriter

import shutil
import numpy as np

from PIL import Image
from tqdm import tqdm
from .utils import cvtColor, preprocess_input, resize_image
from .utils_bbox import DecodeBox
from .utils_map import get_coco_map, get_map


def _box_iou(box_a, box_b):
    left = max(float(box_a[0]), float(box_b[0]))
    top = max(float(box_a[1]), float(box_b[1]))
    right = min(float(box_a[2]), float(box_b[2]))
    bottom = min(float(box_a[3]), float(box_b[3]))
    inter_w = max(0.0, right - left)
    inter_h = max(0.0, bottom - top)
    inter = inter_w * inter_h
    area_a = max(0.0, float(box_a[2]) - float(box_a[0])) * max(0.0, float(box_a[3]) - float(box_a[1]))
    area_b = max(0.0, float(box_b[2]) - float(box_b[0])) * max(0.0, float(box_b[3]) - float(box_b[1]))
    union = area_a + area_b - inter
    return inter / union if union > 0 else 0.0


def _pred_boxes_to_xyxy(pred_boxes):
    """NMS 输出为 top,left,bottom,right；标注为 left,top,right,bottom。"""
    if len(pred_boxes) == 0:
        return pred_boxes
    xyxy = np.empty_like(pred_boxes, dtype=float)
    xyxy[:, 0] = pred_boxes[:, 1]  # left
    xyxy[:, 1] = pred_boxes[:, 0]  # top
    xyxy[:, 2] = pred_boxes[:, 3]  # right
    xyxy[:, 3] = pred_boxes[:, 2]  # bottom
    return xyxy


def _match_image_metrics(gt_boxes, pred_boxes, pred_labels, iou_thresh):
    """按 GT 框一对一匹配，返回 (分类正确数, 检出数, GT 总数)。"""
    if len(gt_boxes) == 0:
        return 0, 0, 0

    pred_boxes = _pred_boxes_to_xyxy(pred_boxes)
    correct_cls = 0
    detected = 0
    used_pred = set()
    for gt in gt_boxes:
        best_iou = 0.0
        best_j = -1
        for j in range(len(pred_boxes)):
            if j in used_pred:
                continue
            iou = _box_iou(gt[:4], pred_boxes[j])
            if iou > best_iou:
                best_iou = iou
                best_j = j
        if best_iou >= iou_thresh and best_j >= 0:
            detected += 1
            used_pred.add(best_j)
            if int(pred_labels[best_j]) == int(gt[4]):
                correct_cls += 1
    return correct_cls, detected, len(gt_boxes)


class LossHistory():
    def __init__(self, log_dir, model, input_shape):
        self.log_dir    = log_dir
        self.losses     = []
        self.val_loss   = []
        
        os.makedirs(self.log_dir)
        self.writer     = SummaryWriter(self.log_dir)
        # DDP 下 add_graph 会在 rank0 长时间 trace 模型，其它 rank 卡在 DDP 初始化

    def append_loss(self, epoch, loss, val_loss):
        if not os.path.exists(self.log_dir):
            os.makedirs(self.log_dir)

        self.losses.append(loss)
        self.val_loss.append(val_loss)

        with open(os.path.join(self.log_dir, "epoch_loss.txt"), 'a') as f:
            f.write(str(loss))
            f.write("\n")
        with open(os.path.join(self.log_dir, "epoch_val_loss.txt"), 'a') as f:
            f.write(str(val_loss))
            f.write("\n")

        self.writer.add_scalar('loss', loss, epoch)
        self.writer.add_scalar('val_loss', val_loss, epoch)
        self.loss_plot()

    def loss_plot(self):
        iters = range(len(self.losses))

        plt.figure()
        plt.plot(iters, self.losses, 'red', linewidth = 2, label='train loss')
        plt.plot(iters, self.val_loss, 'coral', linewidth = 2, label='val loss')
        try:
            if len(self.losses) < 25:
                num = 5
            else:
                num = 15
            
            plt.plot(iters, scipy.signal.savgol_filter(self.losses, num, 3), 'green', linestyle = '--', linewidth = 2, label='smooth train loss')
            plt.plot(iters, scipy.signal.savgol_filter(self.val_loss, num, 3), '#8B4513', linestyle = '--', linewidth = 2, label='smooth val loss')
        except:
            pass

        plt.grid(True)
        plt.xlabel('Epoch')
        plt.ylabel('Loss')
        plt.legend(loc="upper right")

        plt.savefig(os.path.join(self.log_dir, "epoch_loss.png"))

        plt.cla()
        plt.close("all")

class EvalCallback():
    def __init__(self, net, input_shape, anchors, anchors_mask, class_names, num_classes, val_lines, log_dir, cuda, \
            map_out_path=".temp_map_out", max_boxes=100, confidence=0.05, nms_iou=0.5, letterbox_image=True, MINOVERLAP=0.5, eval_flag=True, period=1):
        super(EvalCallback, self).__init__()
        
        self.net                = net
        self.input_shape        = input_shape
        self.anchors            = anchors
        self.anchors_mask       = anchors_mask
        self.class_names        = class_names
        self.num_classes        = num_classes
        self.val_lines          = val_lines
        self.log_dir            = log_dir
        self.cuda               = cuda
        self.map_out_path       = map_out_path
        self.max_boxes          = max_boxes
        self.confidence         = confidence
        self.nms_iou            = nms_iou
        self.letterbox_image    = letterbox_image
        self.MINOVERLAP         = MINOVERLAP
        self.eval_flag          = eval_flag
        self.period             = period
        
        self.bbox_util          = DecodeBox(self.anchors, self.num_classes, (self.input_shape[0], self.input_shape[1]), self.anchors_mask)
        
        self.maps       = [0]
        self.epoches    = [0]
        self.accs       = [0]
        self.recalls    = [0]
        if self.eval_flag:
            with open(os.path.join(self.log_dir, "epoch_map.txt"), 'a') as f:
                f.write(str(0))
                f.write("\n")

    def predict_image(self, image):
        image_shape = np.array(np.shape(image)[0:2])
        image = cvtColor(image)
        image_data = resize_image(image, (self.input_shape[1], self.input_shape[0]), self.letterbox_image)
        image_data = np.expand_dims(
            np.transpose(preprocess_input(np.array(image_data, dtype="float32")), (2, 0, 1)), 0
        )

        with torch.no_grad():
            images = torch.from_numpy(image_data)
            if self.cuda:
                images = images.cuda()
            outputs = self.net(images)
            outputs = self.bbox_util.decode_box(outputs)
            results = self.bbox_util.non_max_suppression(
                torch.cat(outputs, 1),
                self.num_classes,
                self.input_shape,
                image_shape,
                self.letterbox_image,
                conf_thres=self.confidence,
                nms_thres=self.nms_iou,
            )

        if results[0] is None:
            return np.zeros((0, 4)), np.zeros((0,)), np.zeros((0,))

        top_label = np.array(results[0][:, 6], dtype='int32')
        top_conf = results[0][:, 4] * results[0][:, 5]
        top_boxes = results[0][:, :4]

        top_100 = np.argsort(top_conf)[::-1][:self.max_boxes]
        return top_boxes[top_100], top_conf[top_100], top_label[top_100]

    def get_map_txt(self, image_id, image, class_names, map_out_path, pred_boxes=None, pred_conf=None, pred_labels=None):
        if pred_boxes is None:
            pred_boxes, pred_conf, pred_labels = self.predict_image(image)

        f = open(os.path.join(map_out_path, "detection-results/"+image_id+".txt"), "w", encoding='utf-8')
        for i, c in enumerate(pred_labels):
            predicted_class = self.class_names[int(c)]
            if predicted_class not in class_names:
                continue
            top, left, bottom, right = pred_boxes[i]
            f.write(
                "%s %s %s %s %s %s\n"
                % (predicted_class, str(pred_conf[i])[:6], str(int(left)), str(int(top)), str(int(right)), str(int(bottom)))
            )
        f.close()
        return pred_boxes, pred_conf, pred_labels
    
    def on_epoch_end(self, epoch, model_eval):
        if epoch % self.period == 0 and self.eval_flag:
            self.net = model_eval
            if not os.path.exists(self.map_out_path):
                os.makedirs(self.map_out_path)
            if not os.path.exists(os.path.join(self.map_out_path, "ground-truth")):
                os.makedirs(os.path.join(self.map_out_path, "ground-truth"))
            if not os.path.exists(os.path.join(self.map_out_path, "detection-results")):
                os.makedirs(os.path.join(self.map_out_path, "detection-results"))
            print("Get map.")
            total_correct = 0
            total_detected = 0
            total_gt = 0
            pbar = tqdm(self.val_lines, desc=f"Eval Epoch {epoch}", postfix={})
            for annotation_line in pbar:
                line = annotation_line.split()
                image_id = os.path.basename(line[0]).split('.')[0]
                image = Image.open(line[0])
                gt_boxes = np.array([np.array(list(map(int, box.split(',')))) for box in line[1:]])
                pred_boxes, pred_conf, pred_labels = self.predict_image(image)
                self.get_map_txt(
                    image_id, image, self.class_names, self.map_out_path,
                    pred_boxes=pred_boxes, pred_conf=pred_conf, pred_labels=pred_labels,
                )
                with open(os.path.join(self.map_out_path, "ground-truth/"+image_id+".txt"), "w") as new_f:
                    for box in gt_boxes:
                        left, top, right, bottom, obj = box
                        obj_name = self.class_names[obj]
                        new_f.write("%s %s %s %s %s\n" % (obj_name, left, top, right, bottom))

                correct, detected, n_gt = _match_image_metrics(
                    gt_boxes, pred_boxes, pred_labels, self.MINOVERLAP
                )
                total_correct += correct
                total_detected += detected
                total_gt += n_gt
                if total_gt > 0:
                    pbar.set_postfix(
                        acc=f"{total_correct / total_gt:.3f}",
                        recall=f"{total_detected / total_gt:.3f}",
                    )

            epoch_acc = total_correct / total_gt if total_gt > 0 else 0.0
            epoch_recall = total_detected / total_gt if total_gt > 0 else 0.0

            print("Calculate Map.")
            try:
                temp_map = get_coco_map(class_names = self.class_names, path = self.map_out_path)[1]
            except:
                temp_map = get_map(self.MINOVERLAP, False, path = self.map_out_path)
            self.maps.append(temp_map)
            self.epoches.append(epoch)
            self.accs.append(epoch_acc)
            self.recalls.append(epoch_recall)

            with open(os.path.join(self.log_dir, "epoch_map.txt"), 'a') as f:
                f.write(str(temp_map))
                f.write("\n")
            with open(os.path.join(self.log_dir, "epoch_acc.txt"), 'a') as f:
                f.write(str(epoch_acc))
                f.write("\n")
            with open(os.path.join(self.log_dir, "epoch_recall.txt"), 'a') as f:
                f.write(str(epoch_recall))
                f.write("\n")
            plt.figure()
            plt.plot(self.epoches, self.maps, 'red', linewidth = 2, label='train map')

            plt.grid(True)
            plt.xlabel('Epoch')
            plt.ylabel('Map %s'%str(self.MINOVERLAP))
            plt.title('A Map Curve')
            plt.legend(loc="upper right")

            plt.savefig(os.path.join(self.log_dir, "epoch_map.png"))
            plt.cla()
            plt.close("all")

            print(
                "Get map done. mAP=%.4f acc=%.4f recall=%.4f"
                % (temp_map, epoch_acc, epoch_recall)
            )
            shutil.rmtree(self.map_out_path)
