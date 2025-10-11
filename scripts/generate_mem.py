# 180000
#
color_pallette = [
    # Czerwone
    0b000000,  # 00 - czarny
    0b010000,  # 10 - lekko czerwony (R=1)
    0b100000,  # 20 - czerwony (R=2)
    0b110000,  # 30 - mocno czerwony (R=3)
    # Zielone
    0b000100,  # 04 - lekko zielony (G=1)
    0b001000,  # 08 - zielony (G=2)
    0b001100,  # 0C - mocno zielony (G=3)
    # Niebieskie
    0b000001,  # 01 - lekko niebieski (B=1)
    0b000010,  # 02 - niebieski (B=2)
    0b000011,  # 03 - mocno niebieski (B=3)
]


#
def push_colors(color1, color2, color3, color4, file):
    byte1 = color1 << 2 | color2 >> 4
    byte2 = color2 << 4 | color3 >> 2
    byte3 = color3 << 6 | color4
    byte1 = byte1 & 255
    byte2 = byte2 & 255
    byte3 = byte3 & 255

    file.write(f"{byte1:02X}\n")
    file.write(f"{byte2:02X}\n")
    file.write(f"{byte3:02X}\n")

    # Pełna sekwencja kolorów RRGGBB (6-bit)


buf = []


def push_color(color, file):
    buf.append(color)
    if len(buf) == 4:
        push_colors(buf[0], buf[1], buf[2], buf[3], file)
        buf.clear()


with open("vram_init.hex", "w") as f:
    for address in range(32768):
        v_pos = address // 200
        h_pos = address % 200

        # Wybierz kolor z sekwencji 10 kolorów
        color_index = h_pos % 10
        color_value = color_pallette[color_index]

        # Neguj co 10 linię (linie 9, 19, 29, ...)
        if v_pos % 10 == 9:
            # color_value = 0b111111 ^ color_value  # Negacja bitów
        push_color(color_value, f)

    f.close()
    print("Wygenerowano plik vram_init.hex")
