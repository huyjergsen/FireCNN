import os
import cv2

# Đường dẫn thư mục gốc và thư mục đích
source_dir = "../../Dataset/dataset_raw"
output_dir = "../../Dataset/dataset_train"
target_size = (128, 128)

# Hàm xử lý và đổi tên file ảnh
def process_and_rename_images(source_path, output_path):
    os.makedirs(output_path, exist_ok=True)  # Tạo thư mục đích nếu chưa có
    file_counter = 1  # Khởi tạo bộ đếm file

    # Duyệt qua tất cả file trong thư mục nguồn
    for file_name in os.listdir(source_path):
        if file_name.lower().endswith(('.jpg', '.jpeg', '.png')):
            img_path = os.path.join(source_path, file_name)
            image = cv2.imread(img_path)

            if image is not None:
                # Resize ảnh về kích thước mục tiêu
                resized_image = cv2.resize(image, target_size)

                # Đổi tên file: 1.jpg, 2.jpg, ...
                new_file_name = f"{file_counter}.jpg"
                save_path = os.path.join(output_path, new_file_name)

                # Lưu ảnh đã resize
                cv2.imwrite(save_path, resized_image)

                # Tăng bộ đếm file
                file_counter += 1

# Duyệt qua các thư mục con (train, test, val) và (Fire, no-Fire)
for split in ["train", "test", "val"]:
    for label in ["Fire", "no-Fire"]:
        source_path = os.path.join(source_dir, split, label)
        output_path = os.path.join(output_dir, split, label)

        # Xử lý ảnh trong thư mục
        process_and_rename_images(source_path, output_path)

print("Thư mục 'datatotrain' đã được tạo hoàn tất với các ảnh resize và đổi tên!")