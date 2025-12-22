#!/usr/bin/env python3
"""
Skrypt do generowania pliku z bajtami hex (jeden bajt na linie) z plików binarnych
dla projektu VGA: tekst, kolory, font i paleta
Obsługiwane rozdzielczości: 1440x900, 1024x768, 800x600
"""

import sys
import os
import argparse

# Definicje rozdzielczości (szerokość_px, wysokość_px, szerokość_znaków, wysokość_znaków)
# Znaki mają rozmiar 8x16 pikseli
RESOLUTIONS = {
    "1440x900": (1440, 900, 180, 56),   # 1440/8=180, 900/16=56
    "1024x768": (1024, 768, 128, 48),   # 1024/8=128, 768/16=48
    "800x600": (800, 600, 100, 37),     # 800/8=100, 600/16=37
}

# Stałe rozmiary
FONT_SIZE = 4096      # 256 znaków * 16 bajtów
PALETTE_SIZE = 16     # 16 kolorów * 1 bajt
DEFAULT_TOTAL_SIZE = 24576  # Domyślny rozmiar z paddingiem


def read_binary_file(filename, default_size=None, default_value=0):
    """
    Czyta plik binarny, jeśli nie istnieje - tworzy domyślną zawartość
    """
    if os.path.exists(filename):
        with open(filename, "rb") as f:
            data = f.read()
        print(f"Wczytano {len(data)} bajtów z {filename}")
        return bytearray(data)
    else:
        print(f"Plik {filename} nie istnieje, używam domyślnych wartości")
        if default_size:
            return bytearray([default_value] * default_size)
        else:
            return bytearray()


def generate_hex_file(output_filename, text_file, color_file, font_file, palette_file, resolution="1440x900", total_size=None):
    """
    Generuje kompletny plik z bajtami hex (jeden bajt na linie) z podanych plików binarnych
    """
    
    # Pobierz parametry rozdzielczości
    if resolution not in RESOLUTIONS:
        print(f"Nieznana rozdzielczość: {resolution}, używam 1440x900")
        resolution = "1440x900"
    
    px_w, px_h, text_cols, text_rows = RESOLUTIONS[resolution]
    text_area_size = text_cols * text_rows
    
    print(f"Rozdzielczość: {resolution} ({text_cols}x{text_rows} znaków = {text_area_size} bajtów tekstu/kolorów)")

    # 1. Tekst (text_area_size bajtów)
    text_data = read_binary_file(text_file, text_area_size, 0x20)  # Domyślnie spacje

    # 2. Kolory (text_area_size bajtów)
    color_data = read_binary_file(color_file, text_area_size, 0xF0)

    # 3. Font (4096 bajtów)
    font_data = read_binary_file(font_file, FONT_SIZE, 0x00)

    # 4. Paleta kolorów (16 bajtów)
    palette_data = read_binary_file(palette_file, PALETTE_SIZE, 0x00)

    # Oblicz całkowity rozmiar bez paddingu
    data_size = text_area_size * 2 + FONT_SIZE + PALETTE_SIZE
    
    # Jeśli nie podano total_size, użyj domyślnego 24576
    if total_size is None:
        total_size = DEFAULT_TOTAL_SIZE
    
    if total_size < data_size:
        print(f"OSTRZEŻENIE: total_size ({total_size}) mniejszy niż dane ({data_size}), zwiększam")
        total_size = data_size
    
    padding_size = total_size - data_size

    # Sprawdź rozmiary i dopasuj jeśli potrzeba
    if len(text_data) != text_area_size:
        print(f"OSTRZEŻENIE: Tekst ma {len(text_data)} bajtów, oczekiwano {text_area_size}")
        text_data = (
            text_data[:text_area_size]
            if len(text_data) > text_area_size
            else text_data + bytearray([0x20] * (text_area_size - len(text_data)))
        )

    if len(color_data) != text_area_size:
        print(f"OSTRZEŻENIE: Kolory mają {len(color_data)} bajtów, oczekiwano {text_area_size}")
        color_data = (
            color_data[:text_area_size]
            if len(color_data) > text_area_size
            else color_data + bytearray([0xF0] * (text_area_size - len(color_data)))
        )

    if len(font_data) != FONT_SIZE:
        print(f"OSTRZEŻENIE: Font ma {len(font_data)} bajtów, oczekiwano {FONT_SIZE}")
        font_data = (
            font_data[:FONT_SIZE]
            if len(font_data) > FONT_SIZE
            else font_data + bytearray([0x00] * (FONT_SIZE - len(font_data)))
        )

    if len(palette_data) != PALETTE_SIZE:
        print(f"OSTRZEŻENIE: Paleta ma {len(palette_data)} bajtów, oczekiwano {PALETTE_SIZE}")
        palette_data = (
            palette_data[:PALETTE_SIZE]
            if len(palette_data) > PALETTE_SIZE
            else palette_data + bytearray([0x00] * (PALETTE_SIZE - len(palette_data)))
        )

    # Padding
    padding_data = bytearray(padding_size)
    if padding_size > 0:
        print(f"Dodano {padding_size} bajtów wypełnienia zerami")

    # Połącz wszystkie dane w kolejności jak w specyfikacji
    complete_data = text_data + color_data + font_data + palette_data + padding_data

    # Zapisz jako plik z jednym bajtem hex na linie
    with open(output_filename, "w") as f:
        for byte in complete_data:
            f.write(f"{byte:02X}\n")

    print(f"\nWygenerowano plik: {output_filename}")
    print(f"Rozmiar danych: {len(complete_data)} bajtów")
    print(f" - Tekst: {len(text_data)} bajtów (offset 0x0000)")
    print(f" - Kolory: {len(color_data)} bajtów (offset 0x{text_area_size:04X})")
    print(f" - Font: {len(font_data)} bajtów (offset 0x{text_area_size*2:04X})")
    print(f" - Paleta: {len(palette_data)} bajtów (offset 0x{text_area_size*2 + FONT_SIZE:04X})")
    if padding_size > 0:
        print(f" - Wypełnienie: {padding_size} bajtów")


def main():
    parser = argparse.ArgumentParser(
        description="Generuje plik hex z danymi dla trybu tekstowego VGA",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Dostępne rozdzielczości:
  1440x900  - 180x56 znaków = 10080 bajtów tekstu/kolorów
  1024x768  - 128x48 znaków = 6144 bajtów tekstu/kolorów
  800x600   - 100x37 znaków = 3700 bajtów tekstu/kolorów

Struktura pliku wyjściowego:
  [tekst] [kolory] [font 4096B] [paleta 16B] [padding opcjonalny]

Przykłady:
  %(prog)s output.hex text.bin colors.bin font.bin palette.bin
  %(prog)s -r 1024x768 output.hex text.bin colors.bin font.bin palette.bin
  %(prog)s -r 800x600 --total-size 16384 output.hex text.bin colors.bin font.bin palette.bin
"""
    )
    
    parser.add_argument("output", help="Plik wyjściowy .hex")
    parser.add_argument("text", help="Plik binarny z tekstem")
    parser.add_argument("colors", help="Plik binarny z kolorami")
    parser.add_argument("font", help="Plik binarny z fontem (4096 bajtów)")
    parser.add_argument("palette", help="Plik binarny z paletą (16 bajtów)")
    
    parser.add_argument(
        "-r", "--resolution",
        choices=list(RESOLUTIONS.keys()),
        default="1440x900",
        help="Rozdzielczość ekranu (domyślnie: 1440x900)"
    )
    parser.add_argument(
        "-t", "--total-size",
        type=int,
        default=DEFAULT_TOTAL_SIZE,
        help=f"Całkowity rozmiar pliku wyjściowego z paddingiem (domyślnie: {DEFAULT_TOTAL_SIZE})"
    )
    parser.add_argument(
        "-l", "--list",
        action="store_true",
        help="Wyświetl dostępne rozdzielczości i wyjdź"
    )
    
    args = parser.parse_args()
    
    if args.list:
        print("Dostępne rozdzielczości:")
        print("-" * 60)
        for res, (px_w, px_h, text_w, text_h) in RESOLUTIONS.items():
            text_size = text_w * text_h
            total_min = text_size * 2 + FONT_SIZE + PALETTE_SIZE
            print(f"  {res:10s} - {text_w:3d}x{text_h:2d} znaków")
            print(f"             tekst/kolory: {text_size:5d} bajtów każdy")
            print(f"             minimum total: {total_min:5d} bajtów")
            print()
        sys.exit(0)

    generate_hex_file(
        args.output, 
        args.text, 
        args.colors, 
        args.font, 
        args.palette, 
        args.resolution,
        args.total_size
    )


if __name__ == "__main__":
    main()
