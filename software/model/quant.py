from matplotlib import transforms
import numpy as np
import torch
import torch.nn as nn
from model import Model
from torchsummary import summary
from torch.quantization.observer import MovingAverageMinMaxObserver
from torchvision import datasets, transforms
from torch.utils.data import DataLoader


def evaluate (model, criterion, data_loader):
    loss = 0.0
    accuracy = 0.0

    model.eval()
    with torch.no_grad():
        for data, label in data_loader:
            out = model(data)

            loss += criterion(out, label).item()
            pred = out.data.max(1, keepdim=True)[1]
            accuracy += pred.eq(label.data.view_as(pred)).sum()

    loss /= len(data_loader.dataset)
    accuracy /= len(data_loader.dataset)

    return loss, accuracy


if __name__ == '__main__':

    learning_rate = 0.001

    transform = transforms.Compose([
        transforms.ToTensor(),
        #transforms.Lambda(lambda img: torch.from_numpy(np.array(img)).permute(2, 0, 1).float())  # PIL -> NumPy -> Tensor, giữ nguyên giá trị
    ])
    criterion = nn.CrossEntropyLoss()
    
    
    data_dir = "../../Dataset/Fire_Detection_Data"

    # Tạo Dataset cho từng tập dữ liệu
    test_dataset = datasets.ImageFolder(root=f'{data_dir}/test', transform=transform)
    train_dataset = datasets.ImageFolder(root=f'{data_dir}/train', transform=transform)
    # Tạo DataLoader
    batch_size = 32
    test_loader = DataLoader(test_dataset, batch_size=batch_size, shuffle=False)
    train_loader = DataLoader(test_dataset, batch_size=batch_size, shuffle=False)
        
    model = Model()    

    model.eval()
    model.load_state_dict(torch.load(f'./fire_detection_sigmoid.pth', map_location='cpu'))
    
    model.qconfig = torch.quantization.QConfig(
        activation=MovingAverageMinMaxObserver.with_args(qscheme=torch.per_tensor_affine, dtype=torch.quint8),
        weight=MovingAverageMinMaxObserver.with_args(qscheme=torch.per_tensor_symmetric, dtype=torch.qint8)
    )
    print(model.qconfig)

    

    torch.quantization.prepare(model, inplace=True)
    print('Post Training Quantization Prepare')

    evaluate(model, criterion, train_loader)
    print('Post Training Quantization: Calibration done')

    torch.quantization.convert(model, inplace=True)
    print('Post Training Quantization: Convert done')

    loss, accuracy = evaluate(model, criterion, test_loader)
    print('Test set: Avg. loss: {:.4f}, Accuracy: {}/{} ({:.0f}%)'.format(loss, accuracy, len(test_loader.dataset), 100.*accuracy))

    torch.save(model.state_dict(), f'fire_detection_quant.pth')
    summary(model, (3, 128, 128))
    