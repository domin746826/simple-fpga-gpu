#!/usr/bin/env python3

FONT_FILE = "terminus.raw"   # plik z czcionką
CHAR_WIDTH = 8
CHAR_HEIGHT = 16

def load_font(path):
    with open(path, "rb") as f:
        data = f.read()
    if len(data) != 256 * CHAR_HEIGHT:
        raise ValueError(f"Zły rozmiar pliku: {len(data)} bajtów (oczekiwane {256*CHAR_HEIGHT})")
    return data

def get_glyph(font_data, char_code):
    """Zwraca tablicę 16 bajtów dla danego kodu ASCII"""
    start = char_code * CHAR_HEIGHT
    end = start + CHAR_HEIGHT
    return font_data[start:end]

def print_glyph(glyph):
    """Wyświetla 8x16 znak (# = 1, . = 0)"""
    for row in glyph:
        bits = f"{row:08b}"  # zamień na binarny string
        line = "".join("#" if b == "1" else "." for b in bits)
        print(line)

if __name__ == "__main__":
    font = load_font(FONT_FILE)
    ch = input("Podaj znak do wyświetlenia: ")
    if not ch:
        exit(0)
    code = ord(ch[0])
    glyph = get_glyph(font, code)
    print_glyph(glyph)

