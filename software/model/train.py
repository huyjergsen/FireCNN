import os
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset
from torchvision import transforms
from torch.utils.tensorboard import SummaryWriter  # Import TensorBoard
from tqdm import tqdm  # Import tqdm
import cv2
from model import Model
from torchsummary import summary

# Transform cho hình ảnh (sửa lỗi Resampling)
transform = transforms.Compose([
    transforms.ToTensor(),
    #transforms.Lambda(lambda x: torch.from_numpy(x.transpose((2, 0, 1))).float())  # Chuyển từ numpy array sang Tensor, giữ nguyên giá trị
])

# Dataset Class
class FireDataset(Dataset):
    def __init__(self, root_dir, transform=None):
        self.root_dir = root_dir
        self.transform = transform
        self.image_paths = []
        self.labels = []

        # Duyệt qua các thư mục con và gán nhãn
        for label_idx, label_name in enumerate(["Fire", "no-Fire"]):
            folder_path = os.path.join(root_dir, label_name)
            for file_name in os.listdir(folder_path):
                if file_name.lower().endswith(".jpg"):
                    self.image_paths.append(os.path.join(folder_path, file_name))
                    self.labels.append(label_idx)

    def __len__(self):
        return len(self.image_paths)

    def __getitem__(self, idx):
        image = cv2.imread(self.image_paths[idx])
        image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)  # Chuyển sang RGB
        label = self.labels[idx]

        if self.transform:
            image = self.transform(image)

        # print(image)

        return image, label

# Dataloader
def get_dataloaders(data_dir, batch_size=32):
    train_data = FireDataset(os.path.join(data_dir, 'train'), transform=transform)
    val_data = FireDataset(os.path.join(data_dir, 'val'), transform=transform)

    train_loader = DataLoader(train_data, batch_size=batch_size, shuffle=True)
    val_loader = DataLoader(val_data, batch_size=batch_size, shuffle=False)

    return train_loader, val_loader

# Thêm hàm test mô hình
def test_model(model, test_loader, device):
    model.eval()  # Chuyển sang chế độ đánh giá
    correct = total = 0
    all_preds = []
    all_labels = []

    with torch.no_grad():
        for images, labels in tqdm(test_loader, desc="Testing Progress"):
            images, labels = images.to(device), labels.to(device)
            outputs = model(images)
            _, predicted = torch.max(outputs, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()

            # Lưu dự đoán và nhãn thật
            all_preds.extend(predicted.cpu().numpy())
            all_labels.extend(labels.cpu().numpy())

    accuracy = 100 * correct / total
    print(f"Test Accuracy: {accuracy:.2f}%")
    return accuracy, all_preds, all_labels

def train_model(model, train_loader, val_loader, device, writer, save_path, epochs=10, lr=0.001):
    model = model.to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=lr)

    global_step = 0  # Biến đếm cho TensorBoard
    best_val_loss = float('inf')

    for epoch in range(epochs):
        model.train()
        total_loss = 0

        # Tqdm progress bar cho Training
        train_pbar = tqdm(train_loader, desc=f"Epoch {epoch+1}/{epochs} [Training]")
        for batch_idx, (images, labels) in enumerate(train_pbar):
            images, labels = images.to(device), labels.to(device)

            # Log hình ảnh ở batch đầu tiên
            if epoch == 0 and batch_idx == 0:
                writer.add_images('Sample Training Images', images, global_step=epoch)

            # Forward pass
            outputs = model(images)
            loss = criterion(outputs, labels)

            # Backward pass
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

            total_loss += loss.item()
            train_pbar.set_postfix({"Loss": loss.item()})

            # Log Training Loss
            writer.add_scalar('Loss/Train', loss.item(), global_step)
            global_step += 1

        # Validation phase
        model.eval()
        correct, total = 0, 0
        val_loss = 0
        val_pbar = tqdm(val_loader, desc=f"Epoch {epoch+1}/{epochs} [Validation]")
        with torch.no_grad():
            for images, labels in val_pbar:
                images, labels = images.to(device), labels.to(device)
                outputs = model(images)
                loss = criterion(outputs, labels)
                val_loss += loss.item()

                _, predicted = torch.max(outputs, 1)
                total += labels.size(0)
                correct += (predicted == labels).sum().item()

        val_accuracy = 100 * correct / total
        print(f"\nEpoch [{epoch+1}/{epochs}], Loss: {total_loss:.4f}, Val Loss: {val_loss:.4f}, Val Accuracy: {val_accuracy:.2f}%")

        # Log Validation Loss và Accuracy
        writer.add_scalar('Loss/Validation', val_loss, epoch)
        writer.add_scalar('Accuracy/Validation', val_accuracy, epoch)

        # Lưu mô hình nếu val_loss thấp hơn best_val_loss
        if val_loss < best_val_loss:
            best_val_loss = val_loss
            torch.save(model.state_dict(), save_path)
            print(f"Best model saved with Val Loss: {best_val_loss:.4f}")
            best_model = model

    print("Training Complete!")
    return best_model

# Main Function
if __name__ == "__main__":
    # Khởi tạo thiết bị
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    # Load Data
    data_dir = "../../Dataset/Fire_Detection_Data"
    train_loader, val_loader = get_dataloaders(data_dir, batch_size=32)

    # Thêm tập test
    test_data = FireDataset(os.path.join(data_dir, 'test'), transform=transform)
    test_loader = DataLoader(test_data, batch_size=32, shuffle=False)

    # Khởi tạo TensorBoard
    writer = SummaryWriter(log_dir='runs/fire_detection')

    # Load Model
    model = Model()
    summary(model)
    model.eval()  # Chuyển mô hình sang chế độ eval trước khi fuse

    # Huấn luyện mô hình
    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    save_path = "fire_detection_sigmoid.pth"
    trained_model = train_model(model, train_loader, val_loader, device, writer, save_path, epochs=300, lr=0.001)

    # Đóng TensorBoard writer
    writer.close()

    # Lưu mô hình
    # torch.save(trained_model.state_dict(), )
    # print("Mô hình đã được lưu thành công!")

    # Test mô hình trên tập test
    print("Testing on test file...")
    test_accuracy, predictions, labels = test_model(trained_model, test_loader, device)

    # Xuất kết quả
    print(f"Final Test Accuracy: {test_accuracy:.2f}%")
