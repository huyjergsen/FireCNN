import cv2
import numpy as np

# Mở ảnh
image = cv2.imread("/home/quoc/Projects/top_KLTN/Dataset/dataset_train/test/Fire/1.jpg")

# Chuyển ảnh từ BGR (OpenCV mặc định) sang RGB
image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

# Hiển thị ảnh
cv2.imshow("Image with RGB", image)
cv2.waitKey(0)
cv2.destroyAllWindows()