import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.ao.quantization import QuantStub, DeQuantStub


class ConvBN(nn.Sequential):
    def __init__(self, in_channels=1, out_channels=32, kernel_size=3, stride=1, padding=1):
        super(ConvBN, self).__init__(
            nn.Conv2d(in_channels=in_channels, out_channels=out_channels, kernel_size=kernel_size, stride=stride, padding=padding, dilation=1, bias=True, padding_mode='zeros'),
            nn.BatchNorm2d(out_channels, momentum=0.1)
        )


class fire_detec_net (nn.Module):
    def __init__(self):
        super(fire_detec_net, self).__init__()
        self.conv1 = ConvBN(in_channels=4, out_channels=16, kernel_size=3, stride=1, padding=1)
        self.conv2 = ConvBN(in_channels=16, out_channels=16, kernel_size=3, stride=1, padding=1)
        self.pool = nn.MaxPool2d((2, 2))
        self.flatten = nn.Flatten()
        self.fc1 = nn.Linear(16*60*60, 128)
        self.fc2 = nn.Linear(128, 3)
        self.sigmoid = nn.Sigmoid()
        self.softmax = nn.Softmax(dim=1)
        self.drop = nn.Dropout(p=0.2)
        self.quant = QuantStub()
        self.dequant = DeQuantStub()

    def forward(self, x):
        x = self.quant(x)
        x = self.conv1(x)
        x = self.sigmoid(x)
        x = self.conv2(x)
        x = self.sigmoid(x)
        x = self.pool(x)
        x = self.flatten(x)
        x = self.drop(x)
        x = self.fc1(x)
        x = self.sigmoid(x)
        x = self.drop(x)
        x = self.fc2(x)
        x = self.dequant(x)
        print(x)
        x = self.softmax(x)
        return x

    def fuse_model(self):
        self.eval()
        for m in self.modules():
            if type(m) == ConvBN:
                torch.ao.quantization.fuse_modules(m, ['0', '1'], inplace=True)


class mnist (nn.Module):
    def __init__(self):
        super(mnist, self).__init__()
        self.net= fire_detec_net()

    def fuse(self):  # fuse model Conv2d() + BatchNorm2d() layers
        print('Fusing layers... ')
        for m in self.net.modules():
            if type(m) is ConvBN and hasattr(m, 'bn'):
                m.conv = fuse_conv_and_bn(m.conv, m.bn)  # update conv
                delattr(m, 'bn')  # remove batchnorm
                m.forward = m.fuseforward  # update forward
        # info(model)
        return self
    
    def dl_nofuse(self):  # fuse model Conv2d() + BatchNorm2d() layers
        print('Fusing layers... ')
        for m in self.net.modules():
            if type(m) is ConvBN and hasattr(m, 'bn'):
                # m.conv = fuse_conv_and_bn(m.conv, m.bn)  # update conv
                delattr(m, 'bn')  # remove batchnorm
                m.forward = m.fuseforward  # update forward
        # info(model)
        return self
    
    def forward(self,x):
        return self.net(x)
    
    def fuse_model(self):
        self.eval()
        for m in self.net.modules():
            if type(m) == ConvBN:
                torch.ao.quantization.fuse_modules(m, ['0', '1'], inplace=True)
    

def info(model, verbose=False):
    n_p = sum(x.numel() for x in model.parameters())  # number parameters
    n_g = sum(x.numel() for x in model.parameters() if x.requires_grad)  # number gradients
    if verbose:
        print('%5s %40s %9s %12s %20s %10s %10s' % ('layer', 'name', 'gradient', 'parameters', 'shape', 'mu', 'sigma'))
        for i, (name, p) in enumerate(model.named_parameters()):
            name = name.replace('module_list.', '')
            print('%5g %40s %9s %12g %20s %10.3g %10.3g' %
                  (i, name, p.requires_grad, p.numel(), list(p.shape), p.mean(), p.std()))

    print(f"Model Summary: {len(list(model.modules()))} layers, {n_p} parameters, {n_g}")


def fuse_conv_and_bn(conv, bn):
    fusedconv = nn.Conv2d(conv.in_channels,
                          conv.out_channels,
                          kernel_size=conv.kernel_size,
                          stride=conv.stride,
                          padding=conv.padding,
                          groups=conv.groups,
                          bias=True).requires_grad_(False).to(conv.weight.device)

    # prepare filters
    w_conv = conv.weight.clone().view(conv.out_channels, -1)
    w_bn = torch.diag(bn.weight.div(torch.sqrt(bn.eps + bn.running_var)))
    fusedconv.weight.copy_(torch.mm(w_bn, w_conv).view(fusedconv.weight.shape))

    # prepare spatial bias
    b_conv = torch.zeros(conv.weight.size(0), device=conv.weight.device) if conv.bias is None else conv.bias
    b_bn = bn.bias - bn.weight.mul(bn.running_mean).div(torch.sqrt(bn.running_var + bn.eps))
    fusedconv.bias.copy_(torch.mm(w_bn, b_conv.reshape(-1, 1)).reshape(-1) + b_bn)

    return fusedconv