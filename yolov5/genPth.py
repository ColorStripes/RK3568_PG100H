import torch
from collections import OrderedDict
yolov5n_weights = torch.load(r'model_data/yolov5_n_v6.1.pth', map_location="cpu")
my_weights = torch.load(r'logs/last_epoch_weightsmy.pth')
new_dict = OrderedDict()
for k, v in yolov5n_weights.items():

    if 'backbone.stem' in k:
        k = "backbone.conv1" + k[13:]
        new_dict[k] = v
    elif 'backbone.dark2.0' in k:
        k = "backbone.conv2" + k[16:]
        new_dict[k] = v
    elif 'backbone.dark2.1.cv1' in k:
        k = "backbone.conv3" + k[20:]
        new_dict[k] = v
    elif 'backbone.dark2.1.cv2' in k:
        k = "backbone.conv4" + k[20:]
        new_dict[k] = v
    elif 'backbone.dark2.1.cv3' in k:
        k = "backbone.conv7" + k[20:]
        new_dict[k] = v
    elif 'backbone.dark2.1.m.0.cv1' in k:
        k = "backbone.conv5" + k[24:]
        new_dict[k] = v
    elif 'backbone.dark2.1.m.0.cv2' in k:
        k = "backbone.conv6" + k[24:]
        new_dict[k] = v
    elif 'backbone.dark3.0' in k:
        k = "backbone.conv8" + k[16:]
        new_dict[k] = v
    elif 'backbone.dark3.1.cv1' in k:
        k = "backbone.conv9" + k[20:]
        new_dict[k] = v
    elif 'backbone.dark3.1.cv2' in k:
        k = "backbone.conv10" + k[20:]
        new_dict[k] = v
    elif 'backbone.dark3.1.cv3' in k:
        k = "backbone.conv15" + k[20:]
        new_dict[k] = v
    elif 'backbone.dark3.1.m.0.cv1' in k:
        k = "backbone.conv11" + k[24:]
        new_dict[k] = v
    elif 'backbone.dark3.1.m.0.cv2' in k:
        k = "backbone.conv12" + k[24:]
        new_dict[k] = v
    elif 'backbone.dark3.1.m.1.cv1' in k:
        k = "backbone.conv13" + k[24:]
        new_dict[k] = v
    elif 'backbone.dark3.1.m.1.cv2' in k:
        k = "backbone.conv14" + k[24:]
        new_dict[k] = v
    elif 'backbone.dark4.0' in k:
        k = "backbone.conv16" + k[16:]
        new_dict[k] = v
    elif 'backbone.dark4.1.cv1' in k:
        k = "backbone.conv17" + k[20:]
        new_dict[k] = v
    elif 'backbone.dark4.1.cv2' in k:
        k = "backbone.conv18" + k[20:]
        new_dict[k] = v
    elif 'backbone.dark4.1.cv3' in k:
        k = "backbone.conv25" + k[20:]
        new_dict[k] = v
    elif 'backbone.dark4.1.m.0.cv1' in k:
        k = "backbone.conv19" + k[24:]
        new_dict[k] = v
    elif 'backbone.dark4.1.m.0.cv2' in k:
        k = "backbone.conv20" + k[24:]
        new_dict[k] = v
    elif 'backbone.dark4.1.m.1.cv1' in k:
        k = "backbone.conv21" + k[24:]
        new_dict[k] = v
    elif 'backbone.dark4.1.m.1.cv2' in k:
        k = "backbone.conv22" + k[24:]
        new_dict[k] = v
    elif 'backbone.dark4.1.m.2.cv1' in k:
        k = "backbone.conv23" + k[24:]
        new_dict[k] = v
    elif 'backbone.dark4.1.m.2.cv2' in k:
        k = "backbone.conv24" + k[24:]
        new_dict[k] = v
    elif 'backbone.dark5.0' in k:
        k = "backbone.conv26" + k[16:]
        new_dict[k] = v
    elif 'backbone.dark5.1.cv1' in k:
        k = "backbone.conv27" + k[20:]
        new_dict[k] = v
    elif 'backbone.dark5.1.cv2' in k:
        k = "backbone.conv28" + k[20:]
        new_dict[k] = v
    elif 'backbone.dark5.1.cv3' in k:
        k = "backbone.conv31" + k[20:]
        new_dict[k] = v
    elif 'backbone.dark5.1.m.0.cv1' in k:
        k = "backbone.conv29" + k[24:]
        new_dict[k] = v
    elif 'backbone.dark5.1.m.0.cv2' in k:
        k = "backbone.conv30" + k[24:]
        new_dict[k] = v
    elif 'backbone.dark5.2.cv1' in k:
        k = "backbone.conv32" + k[20:]
        new_dict[k] = v
    elif 'backbone.dark5.2.cv2' in k:
        k = "backbone.conv33" + k[20:]
        new_dict[k] = v
    elif 'conv_for_feat3' in k:
        k = "backbone.conv34" + k[14:]
        new_dict[k] = v
    elif 'conv3_for_upsample1.cv1' in k:
        k = "backbone.conv35" + k[23:]
        new_dict[k] = v
    elif 'conv3_for_upsample1.cv2' in k:
        k = "backbone.conv36" + k[23:]
        new_dict[k] = v
    elif 'conv3_for_upsample1.cv3' in k:
        k = "backbone.conv39" + k[23:]
        new_dict[k] = v
    elif 'conv3_for_upsample1.m.0.cv1' in k:
        k = "backbone.conv37" + k[27:]
        new_dict[k] = v
    elif 'conv3_for_upsample1.m.0.cv2' in k:
        k = "backbone.conv38" + k[27:]
        new_dict[k] = v
    elif 'conv_for_feat2' in k:
        k = "backbone.conv40" + k[14:]
        new_dict[k] = v
    elif 'conv3_for_upsample2.cv1' in k:
        k = "backbone.conv41" + k[23:]
        new_dict[k] = v
    elif 'conv3_for_upsample2.cv2' in k:
        k = "backbone.conv42" + k[23:]
        new_dict[k] = v
    elif 'conv3_for_upsample2.cv3' in k:
        k = "backbone.conv45" + k[23:]
        new_dict[k] = v
    elif 'conv3_for_upsample2.m.0.cv1' in k:
        k = "backbone.conv43" + k[27:]
        new_dict[k] = v
    elif 'conv3_for_upsample2.m.0.cv2' in k:
        k = "backbone.conv44" + k[27:]
        new_dict[k] = v
    elif 'down_sample1' in k:
        k = "backbone.conv46" + k[12:]
        new_dict[k] = v
    elif 'conv3_for_downsample1.cv1' in k:
        k = "backbone.conv47" + k[25:]
        new_dict[k] = v
    elif 'conv3_for_downsample1.cv2' in k:
        k = "backbone.conv48" + k[25:]
        new_dict[k] = v
    elif 'conv3_for_downsample1.cv3' in k:
        k = "backbone.conv51" + k[25:]
        new_dict[k] = v
    elif 'conv3_for_downsample1.m.0.cv1' in k:
        k = "backbone.conv49" + k[29:]
        new_dict[k] = v
    elif 'conv3_for_downsample1.m.0.cv2' in k:
        k = "backbone.conv50" + k[29:]
        new_dict[k] = v
    elif 'down_sample2' in k:
        k = "backbone.conv52" + k[12:]
        new_dict[k] = v
    elif 'conv3_for_downsample2.cv1' in k:
        k = "backbone.conv53" + k[25:]
        new_dict[k] = v
    elif 'conv3_for_downsample2.cv2' in k:
        k = "backbone.conv54" + k[25:]
        new_dict[k] = v
    elif 'conv3_for_downsample2.cv3' in k:
        k = "backbone.conv57" + k[25:]
        new_dict[k] = v
    elif 'conv3_for_downsample2.m.0.cv1' in k:
        k = "backbone.conv55" + k[29:]
        new_dict[k] = v
    elif 'conv3_for_downsample2.m.0.cv2' in k:
        k = "backbone.conv56" + k[29:]
        new_dict[k] = v
    elif 'yolo_head_P3' in k:
        k = "conv3" + k[12:]
        new_dict[k] = v
    elif 'yolo_head_P4' in k:
        k = "conv2" + k[12:]
        new_dict[k] = v
    elif 'yolo_head_P5' in k:
        k = "conv1" + k[12:]
        new_dict[k] = v
    else:
        new_dict[k] = v


    # if 'backbone.dark2.1.m.0.cv2.' in k:
    #     k = "backbone.conv6."+ k[25:]
    #     new_dict[k] = v
    # else:
    #     new_dict[k] = v

print('len=', len(my_weights.keys()))
print('keys():', my_weights.keys())

print('len=', len(yolov5n_weights.keys()))
print('keys():', yolov5n_weights.keys())

print('len=', len(new_dict.keys()))
print('keys():', new_dict.keys())

torch.save(new_dict, r"model_data/yolov5_n_v6.1_n1.pth")
