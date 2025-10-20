#!/usr/bin/env python3

FONT_FILE = "terminus.raw"   # plik czcionki raw
CHAR_WIDTH = 8
CHAR_HEIGHT = 16
COLS = 16   # 16 znaków w wierszu
ROWS = 16   # 16 wierszy = 256 znaków

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

def render_font(font_data):
    """Rysuje wszystkie 256 znaków w siatce 16×16"""
    for row in range(ROWS):
        # każdy wiersz czcionki to 16 wierszy pikseli
        for y in range(CHAR_HEIGHT):
            line = ""
            for col in range(COLS):
                code = row * COLS + col
                glyph = get_glyph(font_data, code)
                bits = f"{glyph[y]:08b}"
                line += "".join("█" if b == "1" else " " for b in bits) + "  "
            print(line)
        print()  # pusty wiersz po każdym bloku 16 znaków

if __name__ == "__main__":
    font = load_font(FONT_FILE)
    render_font(font)

