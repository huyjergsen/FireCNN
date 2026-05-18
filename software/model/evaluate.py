import torch
import torch.nn.functional as F
import cv2
from model import Model  
from torch.quantization.observer import MovingAverageMinMaxObserver
from torchvision import transforms

model = Model()

model.qconfig = torch.quantization.QConfig(
    activation=torch.quantization.MinMaxObserver.with_args(qscheme=torch.per_tensor_symmetric, dtype=torch.quint8),
    weight=torch.quantization.MinMaxObserver.with_args(qscheme=torch.per_tensor_symmetric, dtype=torch.qint8)
)

torch.quantization.prepare(model, inplace=True)
torch.quantization.convert(model, inplace=True)
model.load_state_dict(torch.load('fire_detection_quant.pth')) 

model.eval()

transform = transforms.Compose([
    transforms.ToTensor(),
    #transforms.Lambda(lambda x: torch.from_numpy(x.transpose((2, 0, 1))).float())  # Chuyển từ numpy array sang Tensor, giữ nguyên giá trị
])

def preprocess_image(image_path):
    image = cv2.imread(image_path)
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    image = transform(image)
    image = image.unsqueeze(0)  
    return image

# 3. Hàm dự đoán
def predict(image_tensor, model):
    with torch.no_grad():
        outputs = model(image_tensor)
        probs = F.softmax(outputs, dim=1)  # Xác suất cho mỗi lớp
        probs = probs.squeeze()  # Bỏ batch dimension
        return probs
    
def test_all_images_from_file(list_path_file, model):
    with open(list_path_file, 'r') as f:
        image_paths = [line.strip() for line in f if line.strip()]
     
    for image_path in image_paths:
        image_path = hex_path.replace("Fire_Detection_Hex", "Fire_Detection_Data")
        image_path = image_path.replace(".txt", ".jpg")

        # 4. Kiểm tra trên một ảnh cụ thể
        image_tensor = preprocess_image(image_path)

        probs = predict(image_tensor, model)

        predicted_class = torch.argmax(probs).item()  # Lấy chỉ số lớp có xác suất cao nhất

        print(predicted_class)

        # # 5. In kết quả
        # class_names = ['Fire', 'No-Fire']
        # for idx, prob in enumerate(probs):
        #     print(f"{class_names[idx]}: {prob.item() * 100:.2f}%")

test_all_images_from_file("../txt/dataset.txt", model)


#________________#

# from matplotlib import transforms
# import numpy as np
# import torch
# import torch.nn as nn
# from model import Model
# from torchsummary import summary
# from torch.quantization.observer import MovingAverageMinMaxObserver
# from torchvision import datasets, transforms
# from torch.utils.data import DataLoader


# def evaluate (model, criterion, data_loader):
#     loss = 0.0
#     accuracy = 0.0

#     model.eval()
#     with torch.no_grad():
#         for data, label in data_loader:
#             out = model(data)

#             loss += criterion(out, label).item()
#             pred = out.data.max(1, keepdim=True)[1]
#             accuracy += pred.eq(label.data.view_as(pred)).sum()

#     loss /= len(data_loader.dataset)
#     accuracy /= len(data_loader.dataset)

#     return loss, accuracy


# if __name__ == '__main__':

#     transform = transforms.Compose([
#         transforms.Lambda(lambda img: torch.from_numpy(np.array(img)).permute(2, 0, 1).float())  # PIL -> NumPy -> Tensor, giữ nguyên giá trị
#         #transforms.Lambda(lambda x: torch.from_numpy(x.transpose((2, 0, 1))).float())
#     ])
#     criterion = nn.CrossEntropyLoss()
    
    
#     data_dir = 'D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/archive/Fire_Detection_Data'

#     test_dataset = datasets.ImageFolder(root=f'{data_dir}/test', transform=transform)
#     batch_size = 32
#     test_loader = DataLoader(test_dataset, batch_size=batch_size, shuffle=False)
        
#     model = Model()

#     # Cấu hình lượng tử hóa cho mô hình
#     model.qconfig = torch.quantization.QConfig(
#     activation=MovingAverageMinMaxObserver.with_args(qscheme=torch.per_tensor_symmetric, dtype=torch.quint8),
#     weight=MovingAverageMinMaxObserver.with_args(qscheme=torch.per_tensor_symmetric, dtype=torch.qint8)
#     )

#     # Chuẩn bị mô hình cho lượng tử hóa và chuyển sang lượng tử hóa
#     torch.quantization.prepare(model, inplace=True)
#     torch.quantization.convert(model, inplace=True)

#     # Tải mô hình đã huấn luyện
#     model.load_state_dict(torch.load('fire_detection_quant.pth')) 

#     # Đưa mô hình vào chế độ đánh giá (evaluation mode)
#     model.eval()

#     loss, accuracy = evaluate(model, criterion, test_loader)
#     print('Test set: Avg. loss: {:.4f}, Accuracy: {}/{} ({:.0f}%)'.format(loss, accuracy, len(test_loader.dataset), 100.*accuracy))

#     torch.save(model.state_dict(), f'fire_detection_quant.pth')
#     summary(model, (3, 128, 128))
    
