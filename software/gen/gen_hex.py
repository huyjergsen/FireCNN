import os
import torch
from PIL import Image
from torchvision import transforms
import numpy as np
import cv2

# Transform chuyển ảnh từ HWC numpy -> tensor CHW float
transform = transforms.Compose([
    transforms.Lambda(lambda x: torch.from_numpy(np.array(x).transpose((2, 0, 1))).float())
])

def tensor_to_hex_lines(image):
    # tensor: [C, H, W]
    c, h, w = image.shape
    print(c, h, w)
    lines = []
    for i in range(h):
        for j in range(w):
            r = int(image[0, i, j])
            g = int(image[1, i, j])
            b = int(image[2, i, j])
            hex_pixel = f"{b:02X}{g:02X}{r:02X}"
            lines.append(hex_pixel)
    return lines

def process_image_to_hex(image_path):
    image = cv2.imread(image_path)
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    image = transform(image)
    return tensor_to_hex_lines(image)

def process_folder(input_dir, output_dir):
    for root, dirs, files in os.walk(input_dir):
        for file in files:
            if file.lower().endswith('.png') or file.lower().endswith('.jpg'):
                input_path = os.path.join(root, file)
                relative_path = os.path.relpath(input_path, input_dir)
                output_path = os.path.join(output_dir, os.path.splitext(relative_path)[0] + '.txt')

                os.makedirs(os.path.dirname(output_path), exist_ok=True)

                hex_pixels = process_image_to_hex(input_path)
                with open(output_path, 'w') as f:
                    f.write('\n'.join(hex_pixels))

if __name__ == "__main__":
    folder_A = "../../archive/Fire_Detection_Data" # Đường dẫn thư mục gốc chứa ảnh gốc
    folder_B = "../../archive/dataset_hex" # Thư mục lưu kết quả hex txt

    process_folder(folder_A, folder_B)