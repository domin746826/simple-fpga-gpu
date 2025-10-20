#!/usr/bin/env python3
"""
Konwerter obrazka na ASCII art 180x56 z 16 kolorami i wysyłka przez UART
Używa pełnego zakresu znaków ASCII (0-255) i zaawansowanej konwersji kolorów
"""

import sys
import serial
import argparse
import cv2
import numpy as np

# 16-kolorowa paleta w formacie 6-bitowym RGB (2 bity na kanał)
PALETTE_6BIT = [
    0x00,  # 000000 - czarny
    0x01,  # 000001 - ciemny niebieski
    0x04,  # 000100 - ciemny zielony
    0x05,  # 000101 - ciemny cyjan
    0x10,  # 010000 - ciemny czerwony
    0x11,  # 010001 - ciemny magenta
    0x14,  # 010100 - ciemny żółty
    0x15,  # 010101 - ciemny szary
    0x2A,  # 101010 - jasny szary
    0x2B,  # 101011 - jasny niebieski
    0x2E,  # 101110 - jasny zielony
    0x2F,  # 101111 - jasny cyjan
    0x3A,  # 111010 - jasny czerwony
    0x3B,  # 111011 - jasny magenta
    0x3E,  # 111110 - jasny żółty
    0x3F,  # 111111 - biały
]


def rgb_to_6bit(r, g, b):
    """
    Konwertuje kolor RGB 8-bit na 6-bit (2 bity na kanał)
    """
    r_2bit = (r >> 6) & 0x03
    g_2bit = (g >> 6) & 0x03
    b_2bit = (b >> 6) & 0x03

    return (r_2bit << 4) | (g_2bit << 2) | b_2bit


def find_closest_color(r, g, b, palette):
    """
    Znajduje najbliższy kolor w palecie używając dystansu RGB
    """
    min_dist = float("inf")
    best_color = 0

    for i, palette_color in enumerate(palette):
        # Konwertuj kolor 6-bit na RGB
        pr = ((palette_color >> 4) & 0x03) * 85
        pg = ((palette_color >> 2) & 0x03) * 85
        pb = (palette_color & 0x03) * 85

        # Oblicz dystans w przestrzeni RGB - używamy liczb całkowitych
        r_int = int(r)
        g_int = int(g)
        b_int = int(b)
        dist = (r_int - pr) ** 2 + (g_int - pg) ** 2 + (b_int - pb) ** 2

        if dist < min_dist:
            min_dist = dist
            best_color = i

    return best_color


def apply_simple_dither(img, palette):
    """
    Stosuje prosty dithering do obrazu - naprawiona wersja bez przepełnień
    """
    height, width = img.shape[:2]
    # Konwertuj na float dla obliczeń
    img_dithered = img.astype(np.float32)

    for y in range(height):
        for x in range(width):
            r, g, b = img_dithered[y, x]

            # Znajdź najbliższy kolor w palecie
            color_idx = find_closest_color(r, g, b, palette)
            palette_color = palette[color_idx]

            # Konwertuj z powrotem na RGB
            new_r = ((palette_color >> 4) & 0x03) * 85
            new_g = ((palette_color >> 2) & 0x03) * 85
            new_b = (palette_color & 0x03) * 85

            # Oblicz błąd kwantyzacji
            error_r = float(r - new_r)
            error_g = float(g - new_g)
            error_b = float(b - new_b)

            # Rozprowadź błąd na sąsiednie piksele z zabezpieczeniem przed przepełnieniem
            if x + 1 < width:
                img_dithered[y, x + 1] = np.clip(
                    img_dithered[y, x + 1]
                    + [error_r * 7 / 16, error_g * 7 / 16, error_b * 7 / 16],
                    0,
                    255,
                )
            if y + 1 < height:
                if x > 0:
                    img_dithered[y + 1, x - 1] = np.clip(
                        img_dithered[y + 1, x - 1]
                        + [error_r * 3 / 16, error_g * 3 / 16, error_b * 3 / 16],
                        0,
                        255,
                    )
                img_dithered[y + 1, x] = np.clip(
                    img_dithered[y + 1, x]
                    + [error_r * 5 / 16, error_g * 5 / 16, error_b * 5 / 16],
                    0,
                    255,
                )
                if x + 1 < width:
                    img_dithered[y + 1, x + 1] = np.clip(
                        img_dithered[y + 1, x + 1]
                        + [error_r * 1 / 16, error_g * 1 / 16, error_b * 1 / 16],
                        0,
                        255,
                    )

    # Przycięcie wartości do zakresu 0-255 i konwersja z powrotem do uint8
    return np.clip(img_dithered, 0, 255).astype(np.uint8)


def apply_ordered_dither(img, palette):
    """
    Alternatywna metoda: dithering z użyciem matrycy Bayer'a - szybsza i bez przepełnień
    """
    height, width = img.shape[:2]

    # Matryca Bayer'a 4x4 dla ditheringu
    bayer_matrix = (
        np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
    )  # Normalizacja do 0-1

    img_dithered = img.copy()

    for y in range(height):
        for x in range(width):
            r, g, b = img_dithered[y, x]

            # Dodaj szum ditheringu oparty na matrycy Bayer'a
            threshold = bayer_matrix[y % 4, x % 4] * 64 - 32  # -32 do +32

            r_dithered = np.clip(r + threshold, 0, 255)
            g_dithered = np.clip(g + threshold, 0, 255)
            b_dithered = np.clip(b + threshold, 0, 255)

            # Znajdź najbliższy kolor dla ditherowanych wartości
            color_idx = find_closest_color(r_dithered, g_dithered, b_dithered, palette)
            palette_color = palette[color_idx]

            # Konwertuj z powrotem na RGB
            new_r = ((palette_color >> 4) & 0x03) * 85
            new_g = ((palette_color >> 2) & 0x03) * 85
            new_b = (palette_color & 0x03) * 85

            img_dithered[y, x] = [new_r, new_g, new_b]

    return img_dithered


def image_to_ascii_art(
    image_path, width=180, height=56, use_dithering=True, dither_type="floyd"
):
    """
    Konwertuje obrazek na ASCII art z zaawansowaną kwantyzacją kolorów
    """
    # Wczytaj obrazek
    img = cv2.imread(image_path)
    if img is None:
        raise ValueError(f"Nie można wczytać obrazka: {image_path}")

    # Konwertuj BGR na RGB
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    # Przeskaluj do docelowego rozmiaru
    img_resized = cv2.resize(img, (width, height), interpolation=cv2.INTER_AREA)

    if use_dithering:
        if dither_type == "ordered":
            # Zastosuj dithering z matrycą Bayer'a
            img_processed = apply_ordered_dither(img_resized, PALETTE_6BIT)
        else:
            # Zastosuj dithering Floyd-Steinberg
            img_processed = apply_simple_dither(img_resized, PALETTE_6BIT)
    else:
        # Prosta kwantyzacja bez ditheringu
        img_processed = img_resized.copy()
        # Dla każdego piksela znajdź najbliższy kolor
        for y in range(height):
            for x in range(width):
                r, g, b = img_processed[y, x]
                color_idx = find_closest_color(r, g, b, PALETTE_6BIT)
                palette_color = PALETTE_6BIT[color_idx]
                new_r = ((palette_color >> 4) & 0x03) * 85
                new_g = ((palette_color >> 2) & 0x03) * 85
                new_b = (palette_color & 0x03) * 85
                img_processed[y, x] = [new_r, new_g, new_b]

    # Konwersja do skali szarości dla ASCII
    gray = cv2.cvtColor(img_resized, cv2.COLOR_RGB2GRAY)

    ascii_data = bytearray()
    color_data = bytearray()

    for y in range(height):
        for x in range(width):
            r, g, b = img_processed[y, x]

            # Znajdź najbliższy kolor w palecie
            color_idx = find_closest_color(r, g, b, PALETTE_6BIT)

            # Znak ASCII na podstawie jasności - użyj pełnego zakresu 0-255
            ascii_char = gray[y, x]
            ascii_data.append(ascii_char)

            # Kolor
            color_data.append(color_idx)

    return ascii_data, color_data


def send_uart_data(ascii_data, color_data, port="/dev/ttyUSB0", baudrate=115200):
    """
    Wysyła dane przez UART - 20160 bajtów (10080 ASCII + 10080 kolorów)
    """
    combined_data = ascii_data + color_data

    if len(combined_data) != 20160:
        print(f"OSTRZEŻENIE: Rozmiar danych {len(combined_data)} != 20160 bajtów")

    try:
        with serial.Serial(port, baudrate, timeout=1) as ser:
            chunk_size = 1024
            total_sent = 0

            print(f"Wysyłanie {len(combined_data)} bajtów przez {port}...")

            for i in range(0, len(combined_data), chunk_size):
                chunk = combined_data[i : i + chunk_size]
                sent = ser.write(chunk)
                total_sent += sent
                print(f"Wysłano {total_sent}/{len(combined_data)} bajtów")

            print(f"Wysłano łącznie {total_sent} bajtów")

    except serial.SerialException as e:
        print(f"Błąd UART: {e}")
        return False

    return True


def preview_ascii_art(ascii_data, color_data, width=180, height=56):
    """
    Podgląd ASCII art w konsoli z kolorami ANSI
    """
    # Mapowanie kolorów 6-bit na kody ANSI
    color_to_ansi = {
        0: 0,  # czarny
        1: 4,  # ciemny niebieski
        2: 2,  # ciemny zielony
        3: 6,  # ciemny cyjan
        4: 1,  # ciemny czerwony
        5: 5,  # ciemny magenta
        6: 3,  # ciemny żółty
        7: 7,  # ciemny szary
        8: 8,  # jasny szary
        9: 12,  # jasny niebieski
        10: 10,  # jasny zielony
        11: 14,  # jasny cyjan
        12: 9,  # jasny czerwony
        13: 13,  # jasny magenta
        14: 11,  # jasny żółty
        15: 15,  # biały
    }

    print("\n--- PODGLĄD ASCII ART (pierwsze 20x80) ---")
    for y in range(min(20, height)):
        line = ""
        for x in range(min(80, width)):
            idx = y * width + x
            ascii_char = chr(ascii_data[idx] if 32 <= ascii_data[idx] <= 126 else 46)
            color_idx = color_data[idx]
            ansi_code = color_to_ansi[color_idx]

            # Kod ANSI dla koloru tekstu
            line += f"\033[38;5;{ansi_code}m{ascii_char}\033[0m"
        print(line)
    print("-------------------------\n")


def main():
    parser = argparse.ArgumentParser(
        description="Konwertuj obrazek na ASCII art i wyślij przez UART"
    )
    parser.add_argument("image", help="Ścieżka do obrazka")
    parser.add_argument("port", help="Port UART (np. /dev/ttyUSB0)")
    parser.add_argument(
        "--baudrate", "-b", type=int, default=115200, help="Prędkość UART"
    )
    parser.add_argument("--no-dither", action="store_true", help="Wyłącz dithering")
    parser.add_argument(
        "--dither-type",
        choices=["floyd", "ordered"],
        default="ordered",
        help="Typ ditheringu",
    )
    parser.add_argument(
        "--preview", "-p", action="store_true", help="Pokaż podgląd w konsoli"
    )

    args = parser.parse_args()

    try:
        print(f"Konwertowanie {args.image} na ASCII art 180x56...")

        ascii_data, color_data = image_to_ascii_art(
            args.image, use_dithering=not args.no_dither, dither_type=args.dither_type
        )

        print(f"Rozmiar danych ASCII: {len(ascii_data)} bajtów")
        print(f"Rozmiar danych kolorów: {len(color_data)} bajtów")
        print(f"Razem: {len(ascii_data) + len(color_data)} bajtów")

        if args.preview:
            preview_ascii_art(ascii_data, color_data)

        print(f"Wysyłanie przez UART {args.port}...")
        success = send_uart_data(ascii_data, color_data, args.port, args.baudrate)

        if success:
            print("Wysyłanie zakończone pomyślnie!")
        else:
            print("Błąd podczas wysyłania!")

    except Exception as e:
        print(f"Błąd: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
