#!/usr/bin/env python3
"""
Skrypt do generowania pliku z bajtami hex (jeden bajt na linie) z plików binarnych
dla projektu VGA: tekst, kolory, font i paleta - razem 24576 bajtów
"""

import sys
import os


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


def generate_hex_file(output_filename, text_file, color_file, font_file, palette_file):
    """
    Generuje kompletny plik z bajtami hex (jeden bajt na linie) z podanych plików binarnych
    """

    # 1. Tekst (10080 bajtów)
    text_data = read_binary_file(text_file, 10080, 0x20)  # Domyślnie spacje

    # 2. Kolory (10080 bajtów)
    color_data = read_binary_file(color_file, 10080, 0xF0)

    # 3. Font (4096 bajtów)
    font_data = read_binary_file(font_file, 4096, 0x00)

    # 4. Paleta kolorów (16 bajtów)
    palette_data = read_binary_file(palette_file, 16, 0x00)

    # 5. Wypełnienie zerami do 24576 bajtów
    total_size = 24576
    current_size = len(text_data) + len(color_data) + len(font_data) + len(palette_data)
    padding_size = total_size - current_size

    if padding_size < 0:
        print(f"OSTRZEŻENIE: Dane przekraczają rozmiar {total_size} bajtów, przycinam")
        # Przycinamy dane do wymaganego rozmiaru
        text_data = text_data[:10080]
        color_data = color_data[:10080]
        font_data = font_data[:4096]
        palette_data = palette_data[:16]
        padding_size = 0
    else:
        padding_data = bytearray(padding_size)
        print(f"Dodano {padding_size} bajtów wypełnienia zerami")

    # Sprawdź rozmiary i dopasuj jeśli potrzeba
    if len(text_data) != 10080:
        print(f"OSTRZEŻENIE: Tekst ma {len(text_data)} bajtów, oczekiwano 10080")
        text_data = (
            text_data[:10080]
            if len(text_data) > 10080
            else text_data + bytearray([0x20] * (10080 - len(text_data)))
        )

    if len(color_data) != 10080:
        print(f"OSTRZEŻENIE: Kolory mają {len(color_data)} bajtów, oczekiwano 10080")
        color_data = (
            color_data[:10080]
            if len(color_data) > 10080
            else color_data + bytearray([0xF0] * (10080 - len(color_data)))
        )

    if len(font_data) != 4096:
        print(f"OSTRZEŻENIE: Font ma {len(font_data)} bajtów, oczekiwano 4096")
        font_data = (
            font_data[:4096]
            if len(font_data) > 4096
            else font_data + bytearray([0x00] * (4096 - len(font_data)))
        )

    if len(palette_data) != 16:
        print(f"OSTRZEŻENIE: Paleta ma {len(palette_data)} bajtów, oczekiwano 16")
        palette_data = (
            palette_data[:16]
            if len(palette_data) > 16
            else palette_data + bytearray([0x00] * (16 - len(palette_data)))
        )

    # Oblicz ponownie rozmiar paddingu po ewentualnych korektach
    current_size = len(text_data) + len(color_data) + len(font_data) + len(palette_data)
    padding_size = total_size - current_size
    padding_data = bytearray(padding_size)

    # Połącz wszystkie dane w kolejności jak w specyfikacji
    complete_data = text_data + color_data + font_data + palette_data + padding_data

    # Zapisz jako plik z jednym bajtem hex na linie
    with open(output_filename, "w") as f:
        for byte in complete_data:
            f.write(f"{byte:02X}\n")

    print(f"\nWygenerowano plik: {output_filename}")
    print(f"Rozmiar danych: {len(complete_data)} bajtów")
    print(f" - Tekst: {len(text_data)} bajtów")
    print(f" - Kolory: {len(color_data)} bajtów")
    print(f" - Font: {len(font_data)} bajtów")
    print(f" - Paleta: {len(palette_data)} bajtów")
    print(f" - Wypełnienie: {padding_size} bajtów")


def main():
    if len(sys.argv) < 5:
        print(
            "Użycie: python build_hex.py <output.hex> <text.bin> <colors.bin> <font.bin> <palette.bin>"
        )
        print(
            "  output.hex  - nazwa pliku wyjściowego (bajt hex pod bajtem, 24576 bajtów)"
        )
        print("  text.bin    - plik binarny z tekstem (10080 bajtów)")
        print("  colors.bin  - plik binarny z kolorami (10080 bajtów)")
        print("  font.bin    - plik binarny z fontem (4096 bajtów)")
        print("  palette.bin - plik binarny z paletą (16 bajtów)")
        print("\nPrzykład:")
        print(
            "  python build_hex.py output.hex text.bin colors.bin font.bin palette.bin"
        )
        sys.exit(1)

    output_file = sys.argv[1]
    text_file = sys.argv[2]
    color_file = sys.argv[3]
    font_file = sys.argv[4]
    palette_file = sys.argv[5]

    generate_hex_file(output_file, text_file, color_file, font_file, palette_file)


if __name__ == "__main__":
    main()
