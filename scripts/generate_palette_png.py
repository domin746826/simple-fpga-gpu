#!/usr/bin/env python3
"""
Skrypt generujący paletę 64 kolorów 6-bit jako obraz PNG.
Każdy kolor ma 16x16 pikseli.
Format 6-bit: 2 bity R, 2 bity G, 2 bity B (RRGGBB)
"""

from PIL import Image, ImageDraw, ImageFont
import argparse
import os


def color_6bit_to_rgb(color_6bit):
    """
    Konwertuje kolor 6-bitowy (RRGGBB) na pełny RGB 24-bit.
    2 bity na kanał (0-3) -> 8 bitów (0-255)
    """
    r = (color_6bit >> 4) & 0x03  # bity 5-4
    g = (color_6bit >> 2) & 0x03  # bity 3-2
    b = color_6bit & 0x03         # bity 1-0
    
    # Skalowanie 2-bit (0-3) do 8-bit (0-255)
    # 0 -> 0, 1 -> 85, 2 -> 170, 3 -> 255
    r8 = r * 85
    g8 = g * 85
    b8 = b * 85
    
    return (r8, g8, b8)


def generate_palette_image(cell_size=16, show_numbers=False, output_file="palette_6bit.png"):
    """
    Generuje obraz z paletą 64 kolorów.
    Układ: 4 kwadraty 4x4 obok siebie
    - Każdy kwadrat ma inne R (0, 1, 2, 3)
    - W kwadracie: X = G (0-3), Y = B (0-3)
    """
    # 4 kwadraty obok siebie, każdy 4x4
    squares = 4  # R = 0, 1, 2, 3
    cols_per_square = 4  # G = 0, 1, 2, 3
    rows = 4  # B = 0, 1, 2, 3
    
    total_cols = squares * cols_per_square  # 16
    
    width = total_cols * cell_size
    height = rows * cell_size
    
    img = Image.new("RGB", (width, height), (0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Próbuj załadować font dla numerów
    font = None
    if show_numbers:
        try:
            # Próbuj różne fonty
            for font_path in [
                "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
                "/usr/share/fonts/TTF/DejaVuSansMono.ttf",
                "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
            ]:
                if os.path.exists(font_path):
                    font = ImageFont.truetype(font_path, cell_size // 2)
                    break
            if font is None:
                font = ImageFont.load_default()
        except:
            font = ImageFont.load_default()
    
    for r in range(4):  # R = 0, 1, 2, 3 (każdy kwadrat)
        for g in range(4):  # G = 0, 1, 2, 3 (kolumna w kwadracie)
            for b in range(4):  # B = 0, 1, 2, 3 (wiersz)
                # Oblicz indeks koloru 6-bit: RRGGBB
                color_idx = (r << 4) | (g << 2) | b
                
                # Pozycja na obrazie
                col = r * cols_per_square + g
                row = b
                
                x0 = col * cell_size
                y0 = row * cell_size
                x1 = x0 + cell_size
                y1 = y0 + cell_size
                
                rgb = color_6bit_to_rgb(color_idx)
                draw.rectangle([x0, y0, x1 - 1, y1 - 1], fill=rgb)
                
                if show_numbers and font:
                    # Wybierz kontrastowy kolor tekstu
                    brightness = (rgb[0] + rgb[1] + rgb[2]) / 3
                    text_color = (0, 0, 0) if brightness > 127 else (255, 255, 255)
                    
                    text = f"{color_idx:02X}"
                    # Wyśrodkuj tekst
                    bbox = draw.textbbox((0, 0), text, font=font)
                    text_w = bbox[2] - bbox[0]
                    text_h = bbox[3] - bbox[1]
                    text_x = x0 + (cell_size - text_w) // 2
                    text_y = y0 + (cell_size - text_h) // 2
                    draw.text((text_x, text_y), text, fill=text_color, font=font)
    
    # Dodaj separatory między kwadratami (opcjonalnie)
    separator_color = (128, 128, 128)
    for i in range(1, squares):
        x = i * cols_per_square * cell_size
        draw.line([(x, 0), (x, height - 1)], fill=separator_color, width=1)
    
    img.save(output_file)
    print(f"Zapisano paletę do: {output_file}")
    print(f"Rozmiar obrazu: {width}x{height} pikseli")
    print(f"Komórka: {cell_size}x{cell_size} pikseli")
    print(f"Układ: 4 kwadraty 4x4 (R=0,1,2,3), X=G, Y=B")
    
    return img


def generate_palette_strip(cell_size=16, output_file="palette_6bit_strip.png"):
    """
    Generuje poziomy pasek z 64 kolorami (1 rząd).
    """
    cols = 64
    rows = 1
    
    width = cols * cell_size
    height = rows * cell_size
    
    img = Image.new("RGB", (width, height), (0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    for color_idx in range(64):
        x0 = color_idx * cell_size
        y0 = 0
        x1 = x0 + cell_size
        y1 = cell_size
        
        rgb = color_6bit_to_rgb(color_idx)
        draw.rectangle([x0, y0, x1 - 1, y1 - 1], fill=rgb)
    
    img.save(output_file)
    print(f"Zapisano pasek palety do: {output_file}")
    print(f"Rozmiar obrazu: {width}x{height} pikseli")
    
    return img


def print_palette_info():
    """Wypisuje informacje o wszystkich kolorach palety."""
    print("Paleta 6-bit (64 kolory):")
    print("=" * 50)
    print(f"{'Idx':>3} {'Hex':>4} {'Binary':>8} {'R':>3} {'G':>3} {'B':>3}  RGB24")
    print("-" * 50)
    
    for i in range(64):
        r = (i >> 4) & 0x03
        g = (i >> 2) & 0x03
        b = i & 0x03
        r8, g8, b8 = color_6bit_to_rgb(i)
        binary = f"{i:06b}"
        print(f"{i:3d} 0x{i:02X}  {binary}  {r:3d} {g:3d} {b:3d}  #{r8:02X}{g8:02X}{b8:02X}")


def main():
    parser = argparse.ArgumentParser(
        description="Generuje obraz PNG z paletą 64 kolorów 6-bit",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Format koloru 6-bit: RRGGBB (2 bity na kanał)
  - R: bity 5-4 (0-3)
  - G: bity 3-2 (0-3)  
  - B: bity 1-0 (0-3)

Przykłady:
  %(prog)s                           # Domyślna siatka 8x8
  %(prog)s -s 32                     # Większe komórki 32x32
  %(prog)s -n                        # Z numerami hex
  %(prog)s --strip                   # Poziomy pasek
  %(prog)s -i                        # Wypisz info o kolorach
"""
    )
    
    parser.add_argument(
        "-o", "--output",
        default="palette_6bit.png",
        help="Nazwa pliku wyjściowego (domyślnie: palette_6bit.png)"
    )
    parser.add_argument(
        "-s", "--size",
        type=int,
        default=16,
        help="Rozmiar komórki w pikselach (domyślnie: 16)"
    )
    parser.add_argument(
        "-n", "--numbers",
        action="store_true",
        help="Wyświetl numery hex na każdym kolorze"
    )
    parser.add_argument(
        "--strip",
        action="store_true",
        help="Generuj poziomy pasek zamiast siatki"
    )
    parser.add_argument(
        "-i", "--info",
        action="store_true",
        help="Wypisz informacje o kolorach i wyjdź"
    )
    
    args = parser.parse_args()
    
    if args.info:
        print_palette_info()
        return
    
    if args.strip:
        generate_palette_strip(args.size, args.output)
    else:
        generate_palette_image(args.size, args.numbers, args.output)


if __name__ == "__main__":
    main()
