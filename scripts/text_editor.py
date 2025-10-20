#!/usr/bin/env python3
"""
it's vibecoded XDD

Edytor tekstu 180x56 z 16 kolorami - zapisuje dane w formacie binarnym gotowym do wysłania przez UART
"""

import curses
import os
import sys

# Paleta 16 kolorów w formacie 6-bitowym RGB
PALETTE_6BIT = [
    0x00,  # 0: czarny
    0x01,  # 1: ciemny niebieski
    0x04,  # 2: ciemny zielony
    0x05,  # 3: ciemny cyjan
    0x10,  # 4: ciemny czerwony
    0x11,  # 5: ciemny magenta
    0x14,  # 6: ciemny żółty
    0x15,  # 7: ciemny szary
    0x2A,  # 8: jasny szary
    0x2B,  # 9: jasny niebieski
    0x2E,  # 10: jasny zielony
    0x2F,  # 11: jasny cyjan
    0x3A,  # 12: jasny czerwony
    0x3B,  # 13: jasny magenta
    0x3E,  # 14: jasny żółty
    0x3F,  # 15: biały
]

# Mapowanie 16 kolorów na kolory 256-kolorowe w terminalu
COLOR_256_MAP = {
    0: 16,  # czarny
    1: 19,  # ciemny niebieski
    2: 34,  # ciemny zielony
    3: 37,  # ciemny cyjan
    4: 124,  # ciemny czerwony
    5: 127,  # ciemny magenta
    6: 130,  # ciemny żółty
    7: 59,  # ciemny szary
    8: 145,  # jasny szary
    9: 33,  # jasny niebieski
    10: 46,  # jasny zielony
    11: 51,  # jasny cyjan
    12: 196,  # jasny czerwony
    13: 201,  # jasny magenta
    14: 226,  # jasny żółty
    15: 15,  # biały
}


class TextEditor:
    def __init__(self, stdscr):
        self.stdscr = stdscr
        self.width = 180
        self.height = 56
        self.text = [[" " for _ in range(self.width)] for _ in range(self.height)]
        self.colors = [
            [0x0F for _ in range(self.width)] for _ in range(self.height)
        ]  # domyślnie biały na czarnym

        self.cursor_x = 0
        self.cursor_y = 0
        self.current_fg = 15  # biały
        self.current_bg = 0  # czarny
        self.mode = "EDIT"  # EDIT lub COMMAND

        # Inicjalizacja kolorów curses
        self.init_colors()

    def init_colors(self):
        if not curses.has_colors():
            return

        curses.start_color()
        curses.use_default_colors()

        # Sprawdź czy terminal obsługuje 256 kolorów
        if curses.COLORS >= 256:
            self.init_256_colors()
        else:
            self.init_16_colors()

    def init_256_colors(self):
        """Inicjalizacja 256 kolorów - tworzymy pary kolorów dla wszystkich kombinacji"""
        # Tworzymy pary kolorów dla wszystkich kombinacji 16x16
        self.color_pairs = {}
        pair_id = 1
        for fg in range(16):
            for bg in range(16):
                # Używamy mapowania na kolory 256
                curses.init_pair(pair_id, COLOR_256_MAP[fg], COLOR_256_MAP[bg])
                self.color_pairs[(fg, bg)] = pair_id
                pair_id += 1

    def init_16_colors(self):
        """Inicjalizacja 16 kolorów - używamy standardowych kolorów curses"""
        self.color_pairs = {}
        pair_id = 1

        # Mapowanie na 8 kolorów curses z atrybutami
        color_map = {
            0: (curses.COLOR_BLACK, 0),
            1: (curses.COLOR_BLUE, 0),
            2: (curses.COLOR_GREEN, 0),
            3: (curses.COLOR_CYAN, 0),
            4: (curses.COLOR_RED, 0),
            5: (curses.COLOR_MAGENTA, 0),
            6: (curses.COLOR_YELLOW, 0),
            7: (curses.COLOR_WHITE, 0),
            8: (curses.COLOR_WHITE, curses.A_BOLD),
            9: (curses.COLOR_BLUE, curses.A_BOLD),
            10: (curses.COLOR_GREEN, curses.A_BOLD),
            11: (curses.COLOR_CYAN, curses.A_BOLD),
            12: (curses.COLOR_RED, curses.A_BOLD),
            13: (curses.COLOR_MAGENTA, curses.A_BOLD),
            14: (curses.COLOR_YELLOW, curses.A_BOLD),
            15: (curses.COLOR_WHITE, curses.A_BOLD),
        }

        for fg in range(16):
            for bg in range(16):
                fg_color, fg_attr = color_map[fg]
                bg_color, bg_attr = color_map[bg]
                curses.init_pair(pair_id, fg_color, bg_color)
                self.color_pairs[(fg, bg)] = (pair_id, fg_attr | bg_attr)
                pair_id += 1

    def get_color_attr(self, fg, bg):
        """Pobierz atrybuty kolorów dla danej pary foreground/background"""
        if curses.COLORS >= 256:
            pair_id = self.color_pairs.get((fg, bg), 1)
            return curses.color_pair(pair_id)
        else:
            pair_id, attr = self.color_pairs.get((fg, bg), (1, 0))
            return curses.color_pair(pair_id) | attr

    def draw_interface(self):
        self.stdscr.clear()
        height, width = self.stdscr.getmaxyx()

        # Rysuj tekst z kolorami
        for y in range(min(self.height, height - 3)):
            for x in range(min(self.width, width - 1)):
                try:
                    char = self.text[y][x]
                    color_code = self.colors[y][x]
                    fg = (color_code >> 4) & 0x0F
                    bg = color_code & 0x0F

                    if curses.has_colors():
                        color_attr = self.get_color_attr(fg, bg)
                        self.stdscr.addch(y, x, char, color_attr)
                    else:
                        self.stdscr.addch(y, x, char)
                except curses.error:
                    pass

        # Rysuj pasek statusu
        status_line = height - 2
        if status_line >= 0:
            mode_str = f"Mode: {self.mode}"
            color_str = f"FG: {self.current_fg:2d} BG: {self.current_bg:2d}"
            pos_str = f"Pos: {self.cursor_x:3d},{self.cursor_y:3d}"

            # Pokaż aktualny kolor
            color_demo = "█"
            try:
                color_attr = self.get_color_attr(self.current_fg, self.current_bg)
                self.stdscr.addstr(status_line, 0, mode_str, curses.A_REVERSE)
                self.stdscr.addstr(status_line, 15, color_str, curses.A_REVERSE)
                self.stdscr.addstr(status_line, 40, pos_str, curses.A_REVERSE)
                self.stdscr.addstr(
                    status_line, 60, color_demo, color_attr | curses.A_REVERSE
                )
            except curses.error:
                pass

            # Instrukcje
            if self.mode == "EDIT":
                help_str = (
                    "F1:Command Mode  Arrows:Move  Backspace:Delete  Enter:New Line"
                )
            else:  # COMMAND mode
                help_str = (
                    "F1:Edit Mode  S:Save  Q:Quit  F/B:Change Color  C:Clear Screen"
                )

            if height - 1 >= 0:
                try:
                    self.stdscr.addstr(height - 1, 0, help_str[: width - 1])
                except curses.error:
                    pass

        # Ustaw kursor
        try:
            self.stdscr.move(self.cursor_y, self.cursor_x)
        except curses.error:
            pass

        self.stdscr.refresh()

    def handle_edit_mode(self, key):
        if key == curses.KEY_F1:
            self.mode = "COMMAND"
        elif key == curses.KEY_UP:
            self.cursor_y = max(0, self.cursor_y - 1)
        elif key == curses.KEY_DOWN:
            self.cursor_y = min(self.height - 1, self.cursor_y + 1)
        elif key == curses.KEY_LEFT:
            self.cursor_x = max(0, self.cursor_x - 1)
        elif key == curses.KEY_RIGHT:
            self.cursor_x = min(self.width - 1, self.cursor_x + 1)
        elif key == 127 or key == curses.KEY_BACKSPACE:  # Backspace
            if self.cursor_x > 0:
                self.cursor_x -= 1
                self.text[self.cursor_y][self.cursor_x] = " "
            elif self.cursor_y > 0:
                self.cursor_y -= 1
                self.cursor_x = self.width - 1
                self.text[self.cursor_y][self.cursor_x] = " "
        elif key == ord("\n") or key == ord("\r"):  # Enter
            self.cursor_y = min(self.height - 1, self.cursor_y + 1)
            self.cursor_x = 0
        elif 32 <= key <= 126:  # Znaki drukowalne
            self.text[self.cursor_y][self.cursor_x] = chr(key)
            # Ustaw kolor dla tego znaku
            self.colors[self.cursor_y][self.cursor_x] = (
                self.current_fg << 4
            ) | self.current_bg
            self.cursor_x += 1
            if self.cursor_x >= self.width:
                self.cursor_x = 0
                self.cursor_y = min(self.height - 1, self.cursor_y + 1)

    def handle_command_mode(self, key):
        if key == curses.KEY_F1:
            self.mode = "EDIT"
        elif key == ord("s") or key == ord("S"):
            self.save_files()
        elif key == ord("q") or key == ord("Q"):
            return "QUIT"
        elif key == ord("f") or key == ord("F"):
            self.current_fg = (self.current_fg + 1) % 16
        elif key == ord("b") or key == ord("B"):
            self.current_bg = (self.current_bg + 1) % 16
        elif key == ord("c") or key == ord("C"):
            self.clear_screen()
        elif key == ord("l") or key == ord("L"):
            self.load_files()

    def clear_screen(self):
        """Wyczyść cały ekran"""
        for y in range(self.height):
            for x in range(self.width):
                self.text[y][x] = " "
                self.colors[y][x] = (self.current_fg << 4) | self.current_bg
        self.cursor_x = 0
        self.cursor_y = 0

    def save_files(self):
        """Zapisz pliki text.bin i colors.bin"""
        try:
            # Zapisz tekst (10080 bajtów)
            with open("text.bin", "wb") as f:
                for y in range(self.height):
                    for x in range(self.width):
                        f.write(bytes([ord(self.text[y][x])]))

            # Zapisz kolory (10080 bajtów)
            with open("colors.bin", "wb") as f:
                for y in range(self.height):
                    for x in range(self.width):
                        f.write(bytes([self.colors[y][x]]))

            # Zapisz również jako jeden plik do wysłania (20160 bajtów)
            with open("output.bin", "wb") as f:
                for y in range(self.height):
                    for x in range(self.width):
                        f.write(bytes([ord(self.text[y][x])]))
                for y in range(self.height):
                    for x in range(self.width):
                        f.write(bytes([self.colors[y][x]]))

            # Pokazuj komunikat
            height, width = self.stdscr.getmaxyx()
            if height - 3 >= 0:
                msg = "Files saved successfully! Press any key."
                try:
                    self.stdscr.addstr(height - 3, 0, msg[: width - 1])
                    self.stdscr.refresh()
                    self.stdscr.getch()
                except curses.error:
                    pass

            return True
        except Exception as e:
            height, width = self.stdscr.getmaxyx()
            if height - 3 >= 0:
                msg = f"Error saving files: {e} Press any key."
                try:
                    self.stdscr.addstr(height - 3, 0, msg[: width - 1])
                    self.stdscr.refresh()
                    self.stdscr.getch()
                except curses.error:
                    pass
            return False

    def load_files(self):
        """Wczytaj istniejące pliki jeśli istnieją"""
        try:
            if os.path.exists("text.bin"):
                with open("text.bin", "rb") as f:
                    data = f.read()
                    for i, byte in enumerate(data):
                        if i < self.width * self.height:
                            y = i // self.width
                            x = i % self.width
                            self.text[y][x] = chr(byte)

            if os.path.exists("colors.bin"):
                with open("colors.bin", "rb") as f:
                    data = f.read()
                    for i, byte in enumerate(data):
                        if i < self.width * self.height:
                            y = i // self.width
                            x = i % self.width
                            self.colors[y][x] = byte

            # Pokazuj komunikat
            height, width = self.stdscr.getmaxyx()
            if height - 3 >= 0:
                msg = "Files loaded successfully! Press any key."
                try:
                    self.stdscr.addstr(height - 3, 0, msg[: width - 1])
                    self.stdscr.refresh()
                    self.stdscr.getch()
                except curses.error:
                    pass
            return True
        except:
            # Pokazuj komunikat błędu
            height, width = self.stdscr.getmaxyx()
            if height - 3 >= 0:
                msg = "Error loading files or files don't exist. Press any key."
                try:
                    self.stdscr.addstr(height - 3, 0, msg[: width - 1])
                    self.stdscr.refresh()
                    self.stdscr.getch()
                except curses.error:
                    pass
            return False

    def run(self):
        self.load_files()

        while True:
            self.draw_interface()
            key = self.stdscr.getch()

            if self.mode == "EDIT":
                self.handle_edit_mode(key)
            elif self.mode == "COMMAND":
                result = self.handle_command_mode(key)
                if result == "QUIT":
                    break


def main(stdscr):
    curses.curs_set(1)  # Pokazuj kursor
    stdscr.keypad(True)  # Włącz obsługę klawiszy specjalnych

    # Sprawdź rozmiar terminala
    height, width = stdscr.getmaxyx()
    if height < 60 or width < 185:
        stdscr.addstr(0, 0, "Terminal too small! Minimum size: 185x60")
        stdscr.addstr(1, 0, f"Current size: {width}x{height}")
        stdscr.addstr(2, 0, "Press any key to exit...")
        stdscr.getch()
        return

    editor = TextEditor(stdscr)
    editor.run()

    # Zapisz przy wyjściu
    editor.save_files()


if __name__ == "__main__":
    try:
        curses.wrapper(main)
    except KeyboardInterrupt:
        print("\nProgram interrupted by user")
    except Exception as e:
        print(f"Error: {e}")
