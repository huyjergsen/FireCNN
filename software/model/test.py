# import torch
# import torch.nn.functional as F
# import cv2
# from model import Model  
# from torch.quantization.observer import MovingAverageMinMaxObserver
# from torchvision import transforms



# transform = transforms.Compose([
#     #transforms.ToTensor(),
#     transforms.Lambda(lambda x: torch.from_numpy(x.transpose((2, 0, 1))).float())  # Chuyển từ numpy array sang Tensor, giữ nguyên giá trị
# ])

# def preprocess_image(image_path):
#     image = cv2.imread(image_path)
#     image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
#     image = transform(image)
#     image = image.unsqueeze(0)  
#     return image

# image_path = "../../../Dataset/dataset_train/test/Fire/8.jpg"  # Thay đường dẫn ảnh ở đây
# image_tensor = preprocess_image(image_path)

import torch
import torch.nn.functional as F
import cv2
from model import Model
from torch.quantization.observer import MovingAverageMinMaxObserver
from torchvision import transforms, datasets
from torch.utils.data import DataLoader
from sklearn.metrics import accuracy_score  # Để tính độ chính xác

# Định nghĩa phép biến đổi cho ảnh
transform = transforms.Compose([
    transforms.Lambda(lambda x: torch.from_numpy(x.transpose((2, 0, 1))).float())  # Chuyển từ numpy array sang Tensor, giữ nguyên giá trị
])

# Hàm tiền xử lý ảnh
def preprocess_image(image_path):
    image = cv2.imread(image_path)
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    image = transform(image)
    image = image.unsqueeze(0)  # Thêm batch dimension
    return image

# Tạo DataLoader cho tập kiểm tra
data_dir = "../../Dataset/Fire_Detection_Data" # Thư mục chứa tập kiểm tra

# Sử dụng ImageFolder để tải dữ liệu từ thư mục test
test_dataset = datasets.ImageFolder(root=f'{data_dir}/test', transform=transform)
test_loader = DataLoader(test_dataset, batch_size=32, shuffle=False)

# Khởi tạo mô hình
model = Model()

# Đảm bảo mô hình ở chế độ đánh giá (eval)
model.eval()

# Tải mô hình đã lượng tử hóa
model.load_state_dict(torch.load('fire_detection_quant.pth'))

# Chạy mô hình và tính độ chính xác trên tập test
true_labels = []
predicted_labels = []

with torch.no_grad():  # Không tính toán gradient khi test
    for images, labels in test_loader:
        # Chạy qua mô hình
        outputs = model(images)
        
        # Dự đoán nhãn
        _, predicted = torch.max(outputs, 1)
        
        # Lưu nhãn thật và dự đoán
        true_labels.extend(labels.numpy())
        predicted_labels.extend(predicted.numpy())

# Tính độ chính xác
accuracy = accuracy_score(true_labels, predicted_labels)
print(f"Accuracy on test set: {accuracy * 100:.2f}%")



