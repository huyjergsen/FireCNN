from PIL import Image
import cv2
import numpy as np

img_data = np.zeros((128, 128, 3), dtype=np.uint8)

def txt_to_image(file_name="input_data.txt", image_name="output_image.png"):
    # Khởi tạo mảng ảnh (128x128, 3 kênh RGB)
    
    with open(file_name, 'r') as f:
        for line in f:
            # Dòng có dạng: (x, y) 80 82 80
            # Ví dụ: "(0, 0) 80 82 80"
            #print(line)
            parts = line.strip().split()


            # Lấy vị trí pixel (x, y) từ phần đầu (x và y được phân tách bằng dấu cách)
            x = int(parts[0][1:-1])
            y = int(parts[1][:-1])

            # Lấy giá trị RGB từ phần còn lại và chuyển từ hex sang int
            r = int(parts[2], 16)
            g = int(parts[3], 16)
            b = int(parts[4], 16)

            if x+y==0: print(parts[0], parts[1], r,g,b) 

            # Gán giá trị vào mảng ảnh
            img_data[x, y] = [r, g, b]

    # Tạo ảnh từ mảng và lưu lại
    print(img_data[0,0])
    cv2.imshow("Image with RGB", img_data)
    cv2.waitKey(0)
    cv2.destroyAllWindows()
    img = Image.fromarray(img_data)
    img.save(image_name)
    #print(f"Image saved as {image_name}")

txt_to_image("test_img.txt", "output_image.jpg")

# import numpy as np
# from PIL import Image

# def txt_to_image(file_name="input_data.txt", image_name="output_image.png", width=128, height=128):
#     # Khởi tạo mảng ảnh (128x128, 3 kênh RGB)
#     img_data = np.zeros((height, width, 3), dtype=np.uint8)
    
#     with open(file_name, 'r') as f:
#         line_idx = 0  # Dùng để theo dõi dòng đang đọc
#         for line in f:
#             # Dòng có dạng: 000300, 010600, 000403, ...
#             hex_str = line.strip()

#             # Tách thành 3 phần tử hex, mỗi phần là một giá trị RGB
#             r = int(hex_str[0:2], 16)  # Chuyển "00" -> 0
#             g = int(hex_str[2:4], 16)  # Chuyển "03" -> 3
#             b = int(hex_str[4:6], 16)  # Chuyển "00" -> 0
            
#             # Tính toán vị trí (x, y) từ line_idx
#             x = line_idx % width  # Lấy phần dư khi chia cho chiều rộng ảnh
#             y = line_idx // width  # Lấy số nguyên khi chia cho chiều rộng ảnh
            
#             # Gán giá trị RGB vào mảng ảnh
#             img_data[y, x] = [r, g, b]

#             line_idx += 1  # Tiến tới dòng tiếp theo

#     # Tạo ảnh từ mảng và lưu lại
#     img = Image.fromarray(img_data)
#     img.save(image_name)
#     print(f"Image saved as {image_name}")

# txt_to_image("D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/archive/dataset_hex/test/Fire/8.txt", "output2_image.jpg",128, 128)