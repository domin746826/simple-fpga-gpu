from PIL import Image
import serial
import time
import numpy as np
import matplotlib.pyplot as plt

color_pallette = [
    (0, 0, 0),
    (0, 0, 85),
    (0, 0, 170),
    (0, 0, 255),
    (0, 85, 0),
    (0, 85, 85),
    (0, 85, 170),
    (0, 85, 255),
    (0, 170, 0),
    (0, 170, 85),
    (0, 170, 170),
    (0, 170, 255),
    (0, 255, 0),
    (0, 255, 85),
    (0, 255, 170),
    (0, 255, 255),
    (85, 0, 0),
    (85, 0, 85),
    (85, 0, 170),
    (85, 0, 255),
    (85, 85, 0),
    (85, 85, 85),
    (85, 85, 170),
    (85, 85, 255),
    (85, 170, 0),
    (85, 170, 85),
    (85, 170, 170),
    (85, 170, 255),
    (85, 255, 0),
    (85, 255, 85),
    (85, 255, 170),
    (85, 255, 255),
    (170, 0, 0),
    (170, 0, 85),
    (170, 0, 170),
    (170, 0, 255),
    (170, 85, 0),
    (170, 85, 85),
    (170, 85, 170),
    (170, 85, 255),
    (170, 170, 0),
    (170, 170, 85),
    (170, 170, 170),
    (170, 170, 255),
    (170, 255, 0),
    (170, 255, 85),
    (170, 255, 170),
    (170, 255, 255),
    (255, 0, 0),
    (255, 0, 85),
    (255, 0, 170),
    (255, 0, 255),
    (255, 85, 0),
    (255, 85, 85),
    (255, 85, 170),
    (255, 85, 255),
    (255, 170, 0),
    (255, 170, 85),
    (255, 170, 170),
    (255, 170, 255),
    (255, 255, 0),
    (255, 255, 85),
    (255, 255, 170),
    (255, 255, 255),
]


def rgb_to_6bit(r, g, b):
    distances = [0] * 64
    for i, (r2, g2, b2) in enumerate(color_pallette):
        distances[i] = (r - r2) ** 2 + (g - g2) ** 2 + (b - b2) ** 2
    return distances.index(min(distances))


def push_colors(color1, color2, color3, color4, ser):
    """Dokładnie taka sama funkcja jak w generatorze patternu"""
    byte1 = color1 << 2 | color2 >> 4
    byte2 = color2 << 4 | color3 >> 2
    byte3 = color3 << 6 | color4
    byte1 = byte1 & 255
    byte2 = byte2 & 255
    byte3 = byte3 & 255

    # Wysyłaj bajty bezpośrednio do portu szeregowego
    ser.write(bytes([byte1, byte2, byte3]))


def show_preview(output_indices, width, height):
    preview_pixels = []
    for idx in output_indices:
        r, g, b = color_pallette[idx]
        preview_pixels.append([r, g, b])

    preview_array = np.array(preview_pixels, dtype=np.uint8)
    preview_image = preview_array.reshape((height, width, 3))

    plt.figure(figsize=(8, 6))
    plt.imshow(preview_image)
    plt.title(f"Podgląd obrazu {width}x{height} z paletą 6-bit")
    plt.axis("off")
    plt.show()


def send_pixels_over_serial(infile, port, baudrate=1000000, delay=0.01):
    try:
        ser = serial.Serial(port, baudrate, timeout=1)
    except Exception as e:
        print("Błąd otwarcia portu: ", e)
        return
    if not ser.is_open:
        print("Port nie został otwarty.")
        return

    im = Image.open(infile)
    if im.size != (200, 150):
        raise ValueError("Obraz musi mieć rozmiar 200x150")
    im = im.convert("RGB")
    width, height = im.size

    pixels = list(im.getdata())
    matrix = [
        [list(pixels[y * width + x]) for x in range(width)] for y in range(height)
    ]
    output_indices = []
    threshold = 10

    for y in range(height):
        for x in range(width):
            oldpixel = matrix[y][x]
            r = int(round(oldpixel[0]))
            g = int(round(oldpixel[1]))
            b = int(round(oldpixel[2]))
            idx = rgb_to_6bit(r, g, b)
            quant = color_pallette[idx]
            output_indices.append(idx)

            err_r = r - quant[0]
            err_g = g - quant[1]
            err_b = b - quant[2]

            if max(abs(err_r), abs(err_g), abs(err_b)) >= threshold:

                def distribute(nx, ny, factor):
                    if 0 <= nx < width and 0 <= ny < height:
                        matrix[ny][nx][0] += err_r * factor
                        matrix[ny][nx][1] += err_g * factor
                        matrix[ny][nx][2] += err_b * factor

                distribute(x + 1, y, 7 / 16)
                distribute(x - 1, y + 1, 3 / 16)
                distribute(x, y + 1, 5 / 16)
                distribute(x + 1, y + 1, 1 / 16)

    print("Wyświetlanie podglądu obrazu...")
    show_preview(output_indices, width, height)

    # Używamy DOKŁADNIE tej samej logiki buforowania co w generatorze patternu
    buf = []

    def push_color(color, serial_port):
        buf.append(color)
        if len(buf) == 4:
            push_colors(buf[0], buf[1], buf[2], buf[3], serial_port)
            buf.clear()

    print(f"Wysyłanie {len(output_indices)} pikseli w pakietach 4→3 bajty...")

    total_pixels = len(output_indices)
    bytes_sent = 0
    pixels_sent = 0

    for color_value in output_indices:
        push_color(color_value, ser)
        pixels_sent += 1
        bytes_sent += 0.75  # 3 bajty na 4 piksele = 0.75 bajta na piksel

        if pixels_sent % 400 == 0:  # Co 400 pikseli wypisz postęp
            progress = (pixels_sent / total_pixels) * 100
            print(f"Postęp: {progress:.1f}%")

    # Jeśli zostały jakieś piksele w buforze, wyślij je z dopełnieniem
    if buf:
        while len(buf) < 4:
            buf.append(0)
        push_colors(buf[0], buf[1], buf[2], buf[3], ser)
        bytes_sent += 3

    ser.close()
    print(f"Obraz został wysłany! Wysłano {int(bytes_sent)} bajtów.")
    print(f"Oryginalnie: {total_pixels} pikseli = {total_pixels} bajtów")
    print(f"Po kompresji: {int(bytes_sent)} bajtów")
    print(f"Kompresja: {total_pixels / bytes_sent:.2f}:1")


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 3:
        print("Użycie: python push.py input.bmp port")
        print("Przykład: python push.py obraz.bmp COM3")
    else:
        send_pixels_over_serial(sys.argv[1], sys.argv[2])
