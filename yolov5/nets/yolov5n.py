import torch
import torch.nn as nn
import torch.nn.quantized
import numpy as np

SAVE_NUMPY = False

class BasicConv(nn.Module):

    def __init__(self, in_channels, out_channels, kernel_size, stride=1):
        super(BasicConv, self).__init__()
        self.conv = nn.Conv2d(in_channels, out_channels, kernel_size, stride, (kernel_size // 2), bias=False)
        self.bn = nn.BatchNorm2d(out_channels)
        self.activation = nn.ReLU()

    def forward(self, x):
        x = self.conv(x)
        x = self.bn(x)
        x = self.activation(x)
        return x


class Focus(nn.Module):

    def __init__(self):
        super(Focus, self).__init__()

    def forward(self, x):
        return torch.cat([
            x[..., ::2, ::2],
            x[..., 1::2, ::2],
            x[..., ::2, 1::2],
            x[..., 1::2, 1::2],
        ], 1)


class BackBone(nn.Module):
    __constants__ = [
     "SAVE_NUMPY"]

    def __init__(self):
        self.SAVE_NUMPY = SAVE_NUMPY
        super().__init__()
        self.focus = Focus()
        self.conv1 = BasicConv(12, 16, 3, 1)
        self.conv2 = BasicConv(16, 32, 3, 2)
        self.conv3 = BasicConv(32, 16, 1, 1)
        self.conv4 = BasicConv(32, 16, 1, 1)
        self.conv5 = BasicConv(16, 16, 1, 1)
        self.conv6 = BasicConv(16, 16, 3, 1)
        self.conv7 = BasicConv(32, 32, 1, 1)
        self.conv8 = BasicConv(32, 64, 3, 2)
        self.conv9 = BasicConv(64, 32, 1, 1)
        self.conv10 = BasicConv(64, 32, 1, 1)
        self.conv11 = BasicConv(32, 32, 1, 1)
        self.conv12 = BasicConv(32, 32, 3, 1)
        self.conv13 = BasicConv(32, 32, 1, 1)
        self.conv14 = BasicConv(32, 32, 3, 1)
        self.conv15 = BasicConv(64, 64, 1, 1)
        self.conv16 = BasicConv(64, 128, 3, 2)
        self.conv17 = BasicConv(128, 64, 1, 1)
        self.conv18 = BasicConv(128, 64, 1, 1)
        self.conv19 = BasicConv(64, 64, 1, 1)
        self.conv20 = BasicConv(64, 64, 3, 1)
        self.conv21 = BasicConv(64, 64, 1, 1)
        self.conv22 = BasicConv(64, 64, 3, 1)
        self.conv23 = BasicConv(64, 64, 1, 1)
        self.conv24 = BasicConv(64, 64, 3, 1)
        self.conv25 = BasicConv(128, 128, 1, 1)
        self.conv26 = BasicConv(128, 256, 3, 2)
        self.conv27 = BasicConv(256, 128, 1, 1)
        self.conv28 = BasicConv(256, 128, 1, 1)
        self.conv29 = BasicConv(128, 128, 1, 1)
        self.conv30 = BasicConv(128, 128, 3, 1)
        self.conv31 = BasicConv(256, 256, 1, 1)
        self.conv32 = BasicConv(256, 128, 1, 1)
        self.maxpool = nn.MaxPool2d(kernel_size=5, stride=1, padding=2)
        self.conv33 = BasicConv(512, 256, 1, 1)
        self.conv34 = BasicConv(256, 128, 1, 1)
        self.upsample = nn.Upsample(scale_factor=2, mode="nearest")
        self.conv35 = BasicConv(256, 64, 1, 1)
        self.conv36 = BasicConv(256, 64, 1, 1)
        self.conv37 = BasicConv(64, 64, 1, 1)
        self.conv38 = BasicConv(64, 64, 3, 1)
        self.conv39 = BasicConv(128, 128, 1, 1)
        self.conv40 = BasicConv(128, 64, 1, 1)
        self.conv41 = BasicConv(128, 32, 1, 1)
        self.conv42 = BasicConv(128, 32, 1, 1)
        self.conv43 = BasicConv(32, 32, 1, 1)
        self.conv44 = BasicConv(32, 32, 3, 1)
        self.conv45 = BasicConv(64, 64, 1, 1)
        self.conv46 = BasicConv(64, 64, 3, 2)
        self.conv47 = BasicConv(128, 64, 1, 1)
        self.conv48 = BasicConv(128, 64, 1, 1)
        self.conv49 = BasicConv(64, 64, 1, 1)
        self.conv50 = BasicConv(64, 64, 3, 1)
        self.conv51 = BasicConv(128, 128, 1, 1)
        self.conv52 = BasicConv(128, 128, 3, 2)
        self.conv53 = BasicConv(256, 128, 1, 1)
        self.conv54 = BasicConv(256, 128, 1, 1)
        self.conv55 = BasicConv(128, 128, 1, 1)
        self.conv56 = BasicConv(128, 128, 3, 1)
        self.conv57 = BasicConv(256, 256, 1, 1)
        self.float_fun_add0 = nn.quantized.FloatFunctional()
        self.float_fun_add1 = nn.quantized.FloatFunctional()
        self.float_fun_add2 = nn.quantized.FloatFunctional()
        self.float_fun_add3 = nn.quantized.FloatFunctional()
        self.float_fun_add4 = nn.quantized.FloatFunctional()
        self.float_fun_add5 = nn.quantized.FloatFunctional()
        self.float_fun_add6 = nn.quantized.FloatFunctional()
        self.float_fun_cat0 = nn.quantized.FloatFunctional()
        self.float_fun_cat1 = nn.quantized.FloatFunctional()
        self.float_fun_cat2 = nn.quantized.FloatFunctional()
        self.float_fun_cat3 = nn.quantized.FloatFunctional()
        self.float_fun_cat4 = nn.quantized.FloatFunctional()
        self.float_fun_cat5 = nn.quantized.FloatFunctional()
        self.float_fun_cat6 = nn.quantized.FloatFunctional()
        self.float_fun_cat7 = nn.quantized.FloatFunctional()
        self.float_fun_cat8 = nn.quantized.FloatFunctional()
        self.float_fun_cat9 = nn.quantized.FloatFunctional()
        self.float_fun_cat10 = nn.quantized.FloatFunctional()
        self.float_fun_cat11 = nn.quantized.FloatFunctional()
        self.float_fun_cat12 = nn.quantized.FloatFunctional()

    def forward(self, x):
        if self.SAVE_NUMPY:
            np.save("./npy/quant.int", x.int_repr())
        x = self.focus(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img.int", x.int_repr())
        x = self.conv1(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv1.int", x.int_repr())
        x = self.conv2(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv2.int", x.int_repr())
        x1 = self.conv3(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv3.int", x1.int_repr())
        x2 = self.conv4(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv4.int", x2.int_repr())
        x = self.conv5(x1)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv5.int", x.int_repr())
        x = self.conv6(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv6.int", x.int_repr())
        x = self.float_fun_add0.add(x, x1)
        if self.SAVE_NUMPY:
            np.save("./npy/add0.int", x.int_repr())
        x = self.float_fun_cat0.cat((x2, x), 1)
        if self.SAVE_NUMPY:
            np.save("./npy/cat0.int", x.int_repr())
        x = self.conv7(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv7.int", x.int_repr())
        x = self.conv8(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv8.int", x.int_repr())
        x1 = self.conv9(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv9.int", x1.int_repr())
        x2 = self.conv10(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv10.int", x2.int_repr())
        x = self.conv11(x1)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv11.int", x.int_repr())
        x = self.conv12(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv12.int", x.int_repr())
        x1 = self.float_fun_add1.add(x, x1)
        if self.SAVE_NUMPY:
            np.save("./npy/add1.int", x1.int_repr())
        x = self.conv13(x1)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv13.int", x.int_repr())
        x = self.conv14(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv14.int", x.int_repr())
        x = self.float_fun_add2.add(x, x1)
        if self.SAVE_NUMPY:
            np.save("./npy/add2.int", x.int_repr())
        x = self.float_fun_cat1.cat((x2, x), 1)
        if self.SAVE_NUMPY:
            np.save("./npy/cat1.int", x.int_repr())
        feat2 = self.conv15(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv15.int", feat2.int_repr())
        x = self.conv16(feat2)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv16.int", x.int_repr())
        x1 = self.conv17(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv17.int", x1.int_repr())
        x2 = self.conv18(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv18.int", x2.int_repr())
        x = self.conv19(x1)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv19.int", x.int_repr())
        x = self.conv20(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv20.int", x.int_repr())
        x1 = self.float_fun_add3.add(x, x1)
        if self.SAVE_NUMPY:
            np.save("./npy/add3.int", x1.int_repr())
        x = self.conv21(x1)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv21.int", x.int_repr())
        x = self.conv22(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv22.int", x.int_repr())
        x1 = self.float_fun_add4.add(x, x1)
        if self.SAVE_NUMPY:
            np.save("./npy/add4.int", x1.int_repr())
        x = self.conv23(x1)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv23.int", x.int_repr())
        x = self.conv24(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv24.int", x.int_repr())
        x = self.float_fun_add5.add(x, x1)
        if self.SAVE_NUMPY:
            np.save("./npy/add5.int", x.int_repr())
        x = self.float_fun_cat2.cat((x2, x), 1)
        if self.SAVE_NUMPY:
            np.save("./npy/cat2.int", x.int_repr())
        feat1 = self.conv25(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv25.int", feat1.int_repr())
        x = self.conv26(feat1)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv26.int", x.int_repr())
        x1 = self.conv27(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv27.int", x1.int_repr())
        x2 = self.conv28(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv28.int", x2.int_repr())
        x = self.conv29(x1)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv29.int", x.int_repr())
        x = self.conv30(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv30.int", x.int_repr())
        x = self.float_fun_add6.add(x, x1)
        if self.SAVE_NUMPY:
            np.save("./npy/add6.int", x.int_repr())
        x = self.float_fun_cat3.cat((x2, x), 1)
        if self.SAVE_NUMPY:
            np.save("./npy/cat3.int", x.int_repr())
        x = self.conv31(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv31.int", x.int_repr())
        x1 = self.conv32(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv32.int", x1.int_repr())
        x2 = self.maxpool(x1)
        if self.SAVE_NUMPY:
            np.save("./npy/max1.int", x2.int_repr())
        x3 = self.maxpool(x2)
        if self.SAVE_NUMPY:
            np.save("./npy/max2.int", x3.int_repr())
        x4 = self.maxpool(x3)
        if self.SAVE_NUMPY:
            np.save("./npy/max3.int", x4.int_repr())
        x = self.float_fun_cat4.cat((x4, x3, x2, x1), 1)
        if self.SAVE_NUMPY:
            np.save("./npy/cat4.int", x.int_repr())
        x = self.conv33(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv33.int", x.int_repr())
        p3 = self.conv34(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv34.int", p3.int_repr())
        x = self.upsample(p3)
        if self.SAVE_NUMPY:
            np.save("./npy/upsample_0.int", x.int_repr())
        x = self.float_fun_cat5.cat([x, feat1], 1)
        if self.SAVE_NUMPY:
            np.save("./npy/cat5.int", x.int_repr())
        x1 = self.conv35(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv35.int", x1.int_repr())
        x2 = self.conv36(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv36.int", x2.int_repr())
        x = self.conv37(x1)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv37.int", x.int_repr())
        x = self.conv38(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv38.int", x.int_repr())
        x = self.float_fun_cat6.cat((x2, x), 1)
        if self.SAVE_NUMPY:
            np.save("./npy/cat6.int", x.int_repr())
        x = self.conv39(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv39.int", x.int_repr())
        p4 = self.conv40(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv40.int", p4.int_repr())
        x = self.upsample(p4)
        if self.SAVE_NUMPY:
            np.save("./npy/upsample_1.int", x.int_repr())
        x = self.float_fun_cat7.cat([feat2, x], 1)
        if self.SAVE_NUMPY:
            np.save("./npy/cat7.int", x.int_repr())
        x1 = self.conv41(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv41.int", x1.int_repr())
        x2 = self.conv42(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv42.int", x2.int_repr())
        x = self.conv43(x1)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv43.int", x.int_repr())
        x = self.conv44(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv44.int", x.int_repr())
        x = self.float_fun_cat8.cat((x2, x), 1)
        if self.SAVE_NUMPY:
            np.save("./npy/cat8.int", x.int_repr())
        head3 = self.conv45(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv45.int", head3.int_repr())
        x = self.conv46(head3)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv46.int", x.int_repr())
        x = self.float_fun_cat9.cat([x, p4], 1)
        if self.SAVE_NUMPY:
            np.save("./npy/cat9.int", x.int_repr())
        x1 = self.conv47(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv47.int", x1.int_repr())
        x2 = self.conv48(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv48.int", x2.int_repr())
        x = self.conv49(x1)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv49.int", x.int_repr())
        x = self.conv50(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv50.int", x.int_repr())
        x = self.float_fun_cat10.cat((x2, x), 1)
        if self.SAVE_NUMPY:
            np.save("./npy/cat10.int", x.int_repr())
        head2 = self.conv51(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv51.int", head2.int_repr())
        x = self.conv52(head2)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv52.int", x.int_repr())
        x = self.float_fun_cat11.cat([x, p3], 1)
        if self.SAVE_NUMPY:
            np.save("./npy/cat11.int", x.int_repr())
        x1 = self.conv53(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv53.int", x1.int_repr())
        x2 = self.conv54(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv54.int", x2.int_repr())
        x = self.conv55(x1)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv55.int", x.int_repr())
        x = self.conv56(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv56.int", x.int_repr())
        x = self.float_fun_cat12.cat((x2, x), 1)
        if self.SAVE_NUMPY:
            np.save("./npy/cat12.int", x.int_repr())
        head1 = self.conv57(x)
        if self.SAVE_NUMPY:
            np.save("./npy/img_conv57.int", head1.int_repr())
        return (
         head1, head2, head3)


class YoloV5n(nn.Module):
    __constants__ = [
     "SAVE_NUMPY"]

    def __init__(self, num_classes):
        self.SAVE_NUMPY = SAVE_NUMPY
        super(YoloV5n, self).__init__()
        self.backbone = BackBone()
        self.conv1 = nn.Conv2d(256, ((5 + num_classes) * 3), 1, 1, bias=False)
        self.conv2 = nn.Conv2d(128, ((5 + num_classes) * 3), 1, 1, bias=False)
        self.conv3 = nn.Conv2d(64, ((5 + num_classes) * 3), 1, 1, bias=False)
        self.quant = torch.quantization.QuantStub()
        self.dequant = torch.quantization.DeQuantStub()

    def forward(self, x):
        x = self.quant(x)
        head1, head2, head3 = self.backbone(x)
        out1 = self.conv1(head1)
        if self.SAVE_NUMPY:
            np.save("./npy/out1.int", out1.int_repr())
        out2 = self.conv2(head2)
        if self.SAVE_NUMPY:
            np.save("./npy/out2.int", out2.int_repr())
        out3 = self.conv3(head3)
        if self.SAVE_NUMPY:
            np.save("./npy/out3.int", out3.int_repr())
        out1 = self.dequant(out1)
        out2 = self.dequant(out2)
        out3 = self.dequant(out3)
        return (out1, out2, out3)

    def fuse_model(self):
        for m in self.modules():
            if isinstance(m, BasicConv):
                torch.quantization.fuse_modules(m, [["conv", "bn"]], inplace=True)
