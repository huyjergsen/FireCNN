import torch.nn as nn
import torch.nn.functional as F
from torch.ao.quantization import QuantStub, DeQuantStub
from torchinfo import summary
import numpy as np
import torch
from fxpmath import Fxp

a = 0

def save_pixel(x, filename='pixel_values.txt'):
    with open(filename, 'w') as f:
        # Lặp qua tất cả các vị trí (h, w)
        for h in range(x.shape[2]):  # Chiều cao
            for w in range(x.shape[3]):  # Chiều rộng
                # Lấy giá trị của tất cả các kênh tại vị trí (w, h)
                pixel_values = x[:, :, h, w].cpu().numpy()  # Tensor -> NumPy Array
                
                # Chuyển các giá trị thành chuỗi và ghi vào file
                f.write(' '.join(map(str, pixel_values)) + '\n')  # Ghi một dòng chứa các giá trị pixel

def save_pixel_hex(x, filename='pixel_values.txt'):
    with open(filename, 'w') as f:
        # Lặp qua tất cả các vị trí (h, w)
        # for h in range(x.shape[2] - 1, -1, -1):  # Chiều cao
        #     for w in range(x.shape[3] - 1, -1, -1):  # Chiều rộng
        for h in range(x.shape[2]):  # Chiều cao
            for w in range(x.shape[3]):  # Chiều rộng
                # Lấy giá trị của tất cả các kênh tại vị trí (w, h)
                pixel_values = x[:, :, h, w].cpu().numpy()  # Tensor -> NumPy Array

                #pixel_values = pixel_values[::-1]  # Đảo ngược kênh (channel)
                
                # Chuyển các giá trị pixel thành dạng hex
                hex_values = [hex(int(value))[2:].zfill(2) for value in pixel_values.flatten()[::-1]]  # Dùng flatten() để chuyển thành một mảng 1 chiều

                # Ghi các giá trị hex vào file, cách nhau bởi dấu cách
                f.write(' '.join(hex_values) + '\n')  # Ghi một dòng chứa các giá trị hex của pixel

def save_pixel2(x, filename='pixel_values.txt'):
    with open(filename, 'w') as f:
        # Lặp qua tất cả các vị trí (h, w)
        for h in range(x.shape[1]):  # Chiều cao
                # Lấy giá trị của tất cả các kênh tại vị trí (w, h)
                pixel_values = x[:, h].cpu().numpy()  # Tensor -> NumPy Array
                
                # Chuyển các giá trị thành chuỗi và ghi vào file
                f.write(' '.join(map(str, pixel_values)) + '\n')  # Ghi một dòng chứa các giá trị pixel

def save_pixel_hex2(x, filename='pixel_values.txt'):
    with open(filename, 'w') as f:
        # Lặp qua tất cả các vị trí (h, w)
        # for h in range(x.shape[2] - 1, -1, -1):  # Chiều cao
        #     for w in range(x.shape[3] - 1, -1, -1):  # Chiều rộng
        for h in range(x.shape[1]):  # Chiều cao
                # Lấy giá trị của tất cả các kênh tại vị trí (w, h)
                pixel_values = x[:, h].cpu().numpy()  # Tensor -> NumPy Array

                #pixel_values = pixel_values[::-1]  # Đảo ngược kênh (channel)
                
                # Chuyển các giá trị pixel thành dạng hex
                hex_values = [hex(int(value))[2:].zfill(2) for value in pixel_values.flatten()[::-1]]  # Dùng flatten() để chuyển thành một mảng 1 chiều

                # Ghi các giá trị hex vào file, cách nhau bởi dấu cách
                f.write(' '.join(hex_values) + '\n')  # Ghi một dòng chứa các giá trị hex của pixel

class FireDetec(nn.Module):
    def __init__(self):
        super(FireDetec, self).__init__()
        self.tanh = nn.Sigmoid()
        self.conv1 = nn.Conv2d(in_channels=3, out_channels=4, kernel_size=3, stride=1, padding=1)
        self.pool1 = nn.MaxPool2d(kernel_size=2, stride=2)
        self.conv2 = nn.Conv2d(in_channels=4, out_channels=4, kernel_size=3, stride=1, padding=1)
        self.pool2 = nn.MaxPool2d(kernel_size=2, stride=2)
        self.conv3 = nn.Conv2d(in_channels=4, out_channels=8, kernel_size=3, stride=1, padding=1)
        self.pool3 = nn.MaxPool2d(kernel_size=2, stride=2)
        self.conv4 = nn.Conv2d(in_channels=8, out_channels=8, kernel_size=3, stride=1, padding=1)
        self.pool4 = nn.MaxPool2d(kernel_size=2, stride=2)
        self.conv5 = nn.Conv2d(in_channels=8, out_channels=16, kernel_size=3, stride=1, padding=1)
        self.pool5 = nn.MaxPool2d(kernel_size=2, stride=2)
        self.flatten = nn.Flatten()
        self.fc = nn.Linear(16 * 4 * 4, 2)
        self.dropout = nn.Dropout(p=0.2)
        self.quant = QuantStub()
        self.dequant = DeQuantStub()

    def forward(self, x):
        if a == 1: save_pixel(x, "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/input.txt")
        # Quantization
        x = self.quant(x)
        if a == 1: print("Scale:", x.q_scale())
        if a == 1: print("Zero point:", x.q_zero_point())
        if a == 1: save_pixel(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/quant.txt")
        if a == 1: save_pixel(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/quant.txt")
        x = self.conv1(x)
        if a == 1: save_pixel(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/conv1.txt")
        if a == 1: save_pixel(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/conv1.txt")
        x = self.tanh(x)
        if a == 1: print("Scale:", x.q_scale())
        if a == 1: print("Zero point:", x.q_zero_point())
        if a == 1: save_pixel(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/act1.txt")
        if a == 1: save_pixel(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/act1.txt")
        if a == 1: save_pixel_hex(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_hex/act1.txt")
        x = self.pool1(x)
        if a == 1: print("Scale:", x.q_scale())
        if a == 1: print("Zero point:", x.q_zero_point())
        if a == 1: save_pixel(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/pool1.txt")
        if a == 1: save_pixel(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/pool1.txt")
        if a == 1: save_pixel_hex(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_hex/pool1.txt")
        x = self.dropout(x)
        x = self.conv2(x)
        if a == 1: save_pixel(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/conv2.txt")
        if a == 1: save_pixel(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/conv2.txt")
        if a == 1: save_pixel_hex(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_hex/conv2.txt")
        x = self.tanh(x)
        if a == 1: print("Scale:", x.q_scale())
        if a == 1: print("Zero point:", x.q_zero_point())
        if a == 1: save_pixel(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/act2.txt")
        if a == 1: save_pixel(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/act2.txt")
        if a == 1: save_pixel_hex(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_hex/act2.txt")
        x = self.pool2(x)
        if a == 1: print("Scale:", x.q_scale())
        if a == 1: print("Zero point:", x.q_zero_point())
        if a == 1: save_pixel(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/pool2.txt")
        if a == 1: save_pixel(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/pool2.txt")
        if a == 1: save_pixel_hex(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_hex/pool2.txt")
        x = self.conv3(x)
        if a == 1: save_pixel(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/conv3.txt")
        if a == 1: save_pixel(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/conv3.txt")
        if a == 1: save_pixel_hex(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_hex/conv3.txt")
        x = self.tanh(x)
        if a == 1: print("Scale:", x.q_scale())
        if a == 1: print("Zero point:", x.q_zero_point())
        if a == 1: save_pixel(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/act3.txt")
        if a == 1: save_pixel(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/act3.txt")
        if a == 1: save_pixel_hex(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_hex/act3.txt")
        x = self.pool3(x)
        if a == 1: print("Scale:", x.q_scale())
        if a == 1: print("Zero point:", x.q_zero_point())
        if a == 1: save_pixel(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/pool3.txt")
        if a == 1: save_pixel(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/pool3.txt")
        if a == 1: save_pixel_hex(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_hex/pool3.txt")
        x = self.conv4(x)
        if a == 1: save_pixel(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/conv4.txt")
        if a == 1: save_pixel(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/conv4.txt")
        if a == 1: save_pixel_hex(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_hex/conv4.txt")
        x = self.tanh(x)
        if a == 1: print("Scale:", x.q_scale())
        if a == 1: print("Zero point:", x.q_zero_point())
        if a == 1: save_pixel(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/act4.txt")
        if a == 1: save_pixel(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/act4.txt")
        if a == 1: save_pixel_hex(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_hex/act4.txt")
        x = self.pool4(x)
        if a == 1: print("Scale:", x.q_scale())
        if a == 1: print("Zero point:", x.q_zero_point())
        if a == 1: save_pixel(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/pool4.txt")
        if a == 1: save_pixel(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/pool4.txt")
        if a == 1: save_pixel_hex(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_hex/pool4.txt")
        x = self.conv5(x)
        if a == 1: save_pixel(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/conv5.txt")
        if a == 1: save_pixel(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/conv5.txt")
        if a == 1: save_pixel_hex(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_hex/conv5.txt")
        x = self.tanh(x)
        if a == 1: print("Scale:", x.q_scale())
        if a == 1: print("Zero point:", x.q_zero_point())
        if a == 1: save_pixel(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/act5.txt")
        if a == 1: save_pixel(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/act5.txt")
        if a == 1: save_pixel_hex(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_hex/act5.txt")
        x = self.pool5(x)
        if a == 1: print("Scale:", x.q_scale())
        if a == 1: print("Zero point:", x.q_zero_point())
        if a == 1: save_pixel(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/pool5.txt")
        if a == 1: save_pixel(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/pool5.txt")
        if a == 1: save_pixel_hex(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_hex/pool5.txt")
        x = self.dropout(x)
        # Sixth Layer 4x4 -> Flatten() -> FC
        x = self.flatten(x)
        if a == 1: print("Scale:", x.q_scale())
        if a == 1: print("Zero point:", x.q_zero_point())
        if a == 1: save_pixel2(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/flatten.txt")
        if a == 1: save_pixel2(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/flatten.txt")
        #if a == 1: save_pixel_hex(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_hex/flatten.txt")
        x = self.fc(x)
        if a == 1: print("Scale:", x.q_scale())
        if a == 1: print("Zero point:", x.q_zero_point())
        if a == 1: save_pixel2(self.dequant(x), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/fc.txt")
        if a == 1: save_pixel2(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_quant/fc.txt")
        if a == 1: save_pixel2(x.int_repr(), "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_hex/fc.txt")
        # Dequantization
        x = self.dequant(x)
        if a == 1: save_pixel2(x, "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_dequant/dequant.txt")
        return F.softmax(x, dim=1)

class Model (nn.Module):
    def __init__(self):
        super(Model, self).__init__()
        self.net= FireDetec()
    
    def forward(self,x):
        return self.net(x)

def info(model, verbose=False):
    n_p = sum(p.numel() for p in model.parameters())
    n_g = sum(p.numel() for p in model.parameters() if p.requires_grad)
    if verbose:
        print(f'{"Layer":<5} {"Name":<40} {"Gradient":<9} {"Parameters":<12} {"Shape":<20} {"Mean":<10} {"Std":<10}')
        for i, (name, p) in enumerate(model.named_parameters()):
            print(f'{i:<5} {name:<40} {str(p.requires_grad):<9} {p.numel():<12} {str(list(p.shape)):<20} {p.mean():.3g} {p.std():.3g}')
    print(f"Model Summary: {len(list(model.modules()))} layers, {n_p} parameters, {n_g} gradients")


if __name__ == '__main__':
    model = Model()
    model.eval()

    summary(model)
