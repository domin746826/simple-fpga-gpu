from PIL import Image
import serial
import time
import numpy as np

import matplotlib.pyplot as plt

color_pallette = [
    (0, 0, 0),  # Czarny
    (0, 0, 85),  # Granatowy
    (0, 0, 170),  # Granatowy
    (0, 0, 255),  # Niebieski
    (0, 85, 0),  # Zielony
    (0, 85, 85),  # Cyjan
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
    # Konwertuj każdy kanał z zakresu 0-255 do 2-bitów (0-3)

    distances = [0] * 64
    for i, (r2, g2, b2) in enumerate(color_pallette):
        distances[i] = (r - r2) ** 2 + (g - g2) ** 2 + (b - b2) ** 2
    return distances.index(min(distances))


def show_preview(output_indices, width, height):
    """Wyświetl podgląd obrazu na podstawie indeksów kolorów"""
    # Konwertuj indeksy na kolory RGB
    preview_pixels = []
    for idx in output_indices:
        r, g, b = color_pallette[idx]
        preview_pixels.append([r, g, b])

    # Przekształć na array numpy i zmień kształt
    preview_array = np.array(preview_pixels, dtype=np.uint8)
    preview_image = preview_array.reshape((height, width, 3))

    # Wyświetl obraz
    plt.figure(figsize=(8, 6))
    plt.imshow(preview_image)
    plt.title(f"Podgląd obrazu {width}x{height} z paletą 6-bit")
    plt.axis("off")
    plt.show()


def send_pixels_over_serial(infile, port, baudrate=1000000, delay=0.01):
    # Open serial port with error checking
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
    # Build a 2D matrix of pixels as mutable float lists
    pixels = list(im.getdata())
    matrix = [
        [list(pixels[y * width + x]) for x in range(width)] for y in range(height)
    ]
    output_indices = []
    threshold = 10  # minimal error threshold to apply dithering

    for y in range(height):
        for x in range(width):
            oldpixel = matrix[y][x]
            r = int(round(oldpixel[0]))
            g = int(round(oldpixel[1]))
            b = int(round(oldpixel[2]))
            idx = rgb_to_6bit(r, g, b)
            quant = color_pallette[idx]
            output_indices.append(idx)
            # Calculate quantization error
            err_r = r - quant[0]
            err_g = g - quant[1]
            err_b = b - quant[2]
            # Adaptive dithering: diffuse error only if difference is significant
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

    # Wyświetl podgląd przed wysłaniem
    print("Wyświetlanie podglądu obrazu...")
    show_preview(output_indices, width, height)

    # Send each pixel's 6-bit value over serial
    print(f"Wysyłanie {len(output_indices)} pikseli...")
    for idx in output_indices:
        ser.write(bytearray([idx]))
        # time.sleep(delay)
    ser.close()
    print("Obraz został wysłany!")


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 3:
        print("Użycie: python push.py input.bmp port")
    else:
        send_pixels_over_serial(sys.argv[1], sys.argv[2])
