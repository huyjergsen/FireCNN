def convert_txt_to_hex_lines(input_file, output_file):
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        for line in infile:
            # Bỏ dấu [ và ] và tách thành list số
            numbers = line.strip().replace('[', '').replace(']', '').split()
            # Convert từng số sang int rồi hex in hoa (2 ký tự)
            hex_values = [f"{int(float(num)):02X}" for num in numbers]
            # Gộp lại thành chuỗi và ghi ra file
            outfile.write(''.join(hex_values) + '\n')

convert_txt_to_hex_lines('D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/output_from_model/quant.txt', 'D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/software/rac/quant.txt')