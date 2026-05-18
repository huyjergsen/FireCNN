with open('D:/DA1-DA2-KLTN/Verification-Methodology/KLTN/FireCNN/archive/dataset_hex/test/Fire/debug.txt', 'w') as file:
    for x in range(0, 128):
        for y in range(0, 128):
            file.write( "0000" + hex(y+1)[2:].zfill(2) + '\n')