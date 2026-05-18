import os
import random

# Thư mục gốc
base_dir = "D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/archive/dataset_hex/test"
output_file = "../txt/dataset.txt"

# Duyệt qua tất cả các tệp trong thư mục 'test'
file_paths = []
for root, dirs, files in os.walk(base_dir):
    for file in files:
        # Tạo đường dẫn đầy đủ và chuyển \ thành /
        full_path = os.path.join(root, file).replace('\\', '/')
        file_paths.append(full_path)

# Xáo trộn các đường dẫn
random.shuffle(file_paths)

# Ghi các đường dẫn xáo trộn vào tệp output
with open(output_file, "w") as f:
    for path in file_paths:
        f.write(path + "\n")

print(f"Đã lưu các đường dẫn xáo trộn vào {output_file}")
