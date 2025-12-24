#include <hardware/gpio.h>
#include <pico/time.h>
#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/spi.h"
#include <string.h>
#include "default8x16.h"


#define SPI_PORT spi1
#define PIN_MISO 12
#define PIN_CS   13
#define PIN_SCK  14
#define PIN_MOSI 15

#define MODE_DISABLED 0
#define MODE_TEXT     1
#define MODE_GRAPHICS 2

/* SPI protocol
    * Commands:
    * 0xH1 - Write sequential data to VRAM (after setting address). 
        Next byte is a low byte of amount of bytes to write, H is low nibble of high byte of amount of bytes to write.
        Following bytes are data to write.
    * 0x02 - Set VRAM address, following 2 bytes: high byte then low byte
    * 0xH3 - Set display mode (H - mode)
    * 0x04 - Read vcounter, send 2 dummy bytes, next 2 bytes are returned vcounter value
*/

/*
 * VRAM map for text mode h_res x v_res and 8x16 font, 4 bit color:
 * cols: abs(h_res / 8)
 * rows: abs(v_res / 16)
 *
 * Organization:
 * 0 - cols*rows-1 bytes: character codes
 * cols*rows - 2*cols*rows-1 bytes: color attributes (high nibble fg, low nibble bg)
 * 2*cols*rows bytes - 2*cols*rows+4096-1 bytes: font data (256 characters * 16 bytes each)

 * 1440x900 resolution:
 * cols = abs(1440/8) = 180
 * rows = abs(900/16) = 56
 * Organization:
 * 0 - 10079 bytes: character codes
 * 10080 - 20159 bytes: color attributes
 * 20160 - 24255 bytes: font data
 * 24256 - 24575 (end) bytes: unused
*/


// #### LOW LEVEL FUNCTIONS ####

void set_addr_to(uint16_t addr) {
    uint8_t cmd[] = {
        0x02,               // Set VRAM address command
        (addr >> 8) & 0xFF, // Address high byte
        addr & 0xFF         // Address low byte
    };
    spi_write_blocking(SPI_PORT, cmd, sizeof(cmd));
}

void write_data(uint8_t *data, size_t len) { // limit 4095 bytes
    // Prepare command byte
    len = len & 0x0FFF; // Ensure length is within 12 bits
    uint8_t cmd[2];
    cmd[0] = 0x01; // Write data command
    cmd[1] = len&0xFF;  // Length low byte 
    cmd[0] |= (len >> 8) << 4; // Low nibble of length high byte

    spi_write_blocking(SPI_PORT, cmd, sizeof(cmd));
    spi_write_blocking(SPI_PORT, data, len);
}

void set_display_mode(uint8_t mode) {
    uint8_t cmd = 0x03 | (mode << 4); // Set display mode command
    spi_write_blocking(SPI_PORT, &cmd, 1);
}

uint16_t read_vcounter() {
    uint8_t tx[4] = {0x04, 0x00, 0x00, 0x00};
    uint8_t rx[4] = {0};

    spi_write_read_blocking(SPI_PORT, tx, rx, 4);
    return (rx[1] << 8) | rx[2];
}

inline void select_sfgpu() {
    gpio_put(PIN_CS, 0);
}
inline void deselect_sfgpu() {
    gpio_put(PIN_CS, 1);
}


// #### MIDDLE LEVEL FUNCTIONS ####

void write_data_extended(uint8_t *data, size_t len) {
    while(len > 0) {
        size_t chunk_size = len > 4095 ? 4095 : len;
        write_data(data, chunk_size);
        data += chunk_size;
        len -= chunk_size;
    }
}

void wait_for_sync() {
    int vc = 0;
    while(!(vc > 500 && vc < 600)) {
        vc = read_vcounter();
    }
}

void write_repeated_characters(uint8_t character, size_t count) {
    const size_t buffer_size = 256;
    uint8_t buffer[buffer_size];
    for (size_t i = 0; i < buffer_size; i++) {
        buffer[i] = character;
    }

    while (count > 0) {
        size_t chunk_size = count > buffer_size ? buffer_size : count;
        write_data(buffer, chunk_size);
        count -= chunk_size;
    }
}


// #### HIGH LEVEL FUNCTIONS ####

void reset_text_screen(uint8_t color, char character) {
    const size_t vram_text_size = 10080;
    set_addr_to(0x0000);
    write_repeated_characters(character, vram_text_size);
    // set_addr_to(10080); // Color attribute area start
    write_repeated_characters(color, vram_text_size);
}

void init_gpu() {
     // cancel any ongoing command (as the write command can be up to 4095 bytes
     //  + one byte of write command and one byte of length)
    uint8_t zero = 0;
    for(int i = 0; i < 4097; i++)
        spi_write_blocking(SPI_PORT, &zero, 1);

    set_addr_to(20160); // set font address
    write_data_extended(default8x16_raw, default8x16_raw_len); // load font

    set_display_mode(MODE_TEXT); // set text mode
     // clear screen and colors
    reset_text_screen(0x80, ' ');
}

void print_to_screen_at(uint8_t x, uint8_t y, const char *text, uint8_t color) {
    if(x >= 180 || y >= 56) return; // out of bounds
    uint16_t address = y * 180 + x; // Assuming 180 characters per line (1440x900 timing)
    set_addr_to(address);
    
    size_t len = strlen(text);
    uint8_t cmd[2];
    write_data_extended((uint8_t *)text, len);
    set_addr_to(address+10080);
    write_repeated_characters(color, len);
}

void ascii_demo() {
    // Box-drawing chars: ╔═╗║╚╝╦╩│╠╣╬
    const uint8_t box_chars[] = {201, 205, 187, 186, 200, 188, 203, 202, 179, 204, 185, 206};
    // Indices: 0:╔ 1:═ 2:╗ 3:║ 4:╚ 5:╝ 6:╦ 7:╩ 8:│ 9:╠ 10:╣ 11:╬
    
    uint16_t col_width = 18;
    uint16_t start_x = (180 - col_width * 8) / 2-1;
    uint16_t start_y = 3;
    
    // Draw top border
    char top_border[180] = {0};
    int pos = 0;
    top_border[pos++] = box_chars[0]; // ╔
    for (int c = 0; c < 8; c++) {
        for (int i = 0; i < col_width - 1; i++) {
            top_border[pos++] = box_chars[1]; // ═
        }
        if (c < 7) {
            top_border[pos++] = box_chars[6]; // ╦
        }
    }
    top_border[pos++] = box_chars[2]; // ╗
    top_border[pos] = 0;
    print_to_screen_at(start_x - 1, start_y - 1, top_border, 0x0F);
    
    // Draw table rows
    for (uint8_t row = 0; row < 32; row++) {
        char line[180] = {0};
        int lpos = 0;
        line[lpos++] = box_chars[3]; // ║
        for (uint8_t col = 0; col < 8; col++) {
            uint8_t code = row + col * 32;
            char buffer[22];
            snprintf(buffer, sizeof(buffer), "%3d %02X %c", code, code, code);
            int len = strlen(buffer);
            for (int i = 0; i < len; i++) {
                line[lpos++] = buffer[i];
            }
            for (int i = len; i < col_width - 1; i++) {
                line[lpos++] = ' ';
            }
            if (col < 7) {
                line[lpos++] = box_chars[8]; // │
            } else {
                line[lpos++] = box_chars[3]; // ║
            }
        }
        line[lpos] = 0;
        uint8_t color = (row % 2 == 0) ? 0x0A : 0x0B;
        print_to_screen_at(start_x - 1, start_y + row, line, color);
    }
    
    // Draw bottom border
    char bottom_border[180] = {0};
    pos = 0;
    bottom_border[pos++] = box_chars[4]; // ╚
    for (int c = 0; c < 8; c++) {
        for (int i = 0; i < col_width - 1; i++) {
            bottom_border[pos++] = box_chars[1]; // ═
        }
        if (c < 7) {
            bottom_border[pos++] = box_chars[7]; // ╩
        }
    }
    bottom_border[pos++] = box_chars[5]; // ╝
    bottom_border[pos] = 0;
    print_to_screen_at(start_x - 1, start_y + 32, bottom_border, 0x0F);
    

    
    uint16_t color_col_width = 9;
    uint16_t color_start_x = (180 - color_col_width * 8) / 2-1;
    uint16_t color_start_y = 40;
    
    // First row (colors 0-7)
    // Top border
    char color_top[180] = {0};
    pos = 0;
    color_top[pos++] = box_chars[0]; // ╔
    for (int c = 0; c < 8; c++) {
        for (int i = 0; i < color_col_width - 1; i++) {
            color_top[pos++] = box_chars[1]; // ═
        }
        if (c < 7) {
            color_top[pos++] = box_chars[6]; // ╦
        }
    }
    color_top[pos++] = box_chars[2]; // ╗
    color_top[pos] = 0;
    print_to_screen_at(color_start_x - 1, color_start_y - 1, color_top, 0x0F);
    
    // Color blocks 0-7
    for (int c = 0; c < 8; c++) {
        int segment_start = 1 + c * color_col_width;
        int segment_len = color_col_width - 1;
        char segment[20] = {0};
        for (int i = 0; i < segment_len; i++) {
            segment[i] = 219; // █
        }
        print_to_screen_at(color_start_x - 1 + segment_start, color_start_y, segment, (c << 4) | c);
    }
    // Borders for row 1
    char sep[2] = {box_chars[3], 0}; // ║
    print_to_screen_at(color_start_x - 1, color_start_y, sep, 0x0F);
    for (int c = 0; c < 7; c++) {
        char vsep[2] = {box_chars[8], 0}; // │
        print_to_screen_at(color_start_x - 1 + 1 + (c + 1) * color_col_width - 1, color_start_y, vsep, 0x0F);
    }
    print_to_screen_at(color_start_x - 1 + 8 * color_col_width, color_start_y, sep, 0x0F);
    
    // Hex labels 0-7
    char hex_line1[180] = {0};
    int cpos = 0;
    hex_line1[cpos++] = box_chars[3]; // ║
    const char* hex_chars = "0123456789ABCDEF";
    for (int c = 0; c < 8; c++) {
        int padding = (color_col_width - 2) / 2;
        for (int i = 0; i < padding; i++) hex_line1[cpos++] = ' ';
        hex_line1[cpos++] = hex_chars[c];
        for (int i = padding + 1; i < color_col_width - 1; i++) hex_line1[cpos++] = ' ';
        hex_line1[cpos++] = (c < 7) ? box_chars[8] : box_chars[3];
    }
    hex_line1[cpos] = 0;
    print_to_screen_at(color_start_x - 1, color_start_y + 1, hex_line1, 0x0F);
    
    // Middle connector: ╠═══╬═══╣
    char mid_connector[180] = {0};
    pos = 0;
    mid_connector[pos++] = box_chars[9]; // ╠
    for (int c = 0; c < 8; c++) {
        for (int i = 0; i < color_col_width - 1; i++) {
            mid_connector[pos++] = box_chars[1]; // ═
        }
        if (c < 7) {
            mid_connector[pos++] = box_chars[11]; // ╬
        }
    }
    mid_connector[pos++] = box_chars[10]; // ╣
    mid_connector[pos] = 0;
    print_to_screen_at(color_start_x - 1, color_start_y + 2, mid_connector, 0x0F);
    
    // Second row (colors 8-F)
    uint16_t row2_y = color_start_y + 3;
    
    // Color blocks 8-F
    for (int c = 0; c < 8; c++) {
        int color_idx = 8 + c;
        int segment_start = 1 + c * color_col_width;
        int segment_len = color_col_width - 1;
        char segment[20] = {0};
        for (int i = 0; i < segment_len; i++) {
            segment[i] = 219; // █
        }
        print_to_screen_at(color_start_x - 1 + segment_start, row2_y, segment, (color_idx << 4) | color_idx);
    }
    // Borders for row 2
    print_to_screen_at(color_start_x - 1, row2_y, sep, 0x0F);
    for (int c = 0; c < 7; c++) {
        char vsep[2] = {box_chars[8], 0}; // │
        print_to_screen_at(color_start_x - 1 + 1 + (c + 1) * color_col_width - 1, row2_y, vsep, 0x0F);
    }
    print_to_screen_at(color_start_x - 1 + 8 * color_col_width, row2_y, sep, 0x0F);
    
    // Hex labels 8-F
    char hex_line2[180] = {0};
    cpos = 0;
    hex_line2[cpos++] = box_chars[3]; // ║
    for (int c = 0; c < 8; c++) {
        int padding = (color_col_width - 2) / 2;
        for (int i = 0; i < padding; i++) hex_line2[cpos++] = ' ';
        hex_line2[cpos++] = hex_chars[8 + c];
        for (int i = padding + 1; i < color_col_width - 1; i++) hex_line2[cpos++] = ' ';
        hex_line2[cpos++] = (c < 7) ? box_chars[8] : box_chars[3];
    }
    hex_line2[cpos] = 0;
    print_to_screen_at(color_start_x - 1, row2_y + 1, hex_line2, 0x0F);
    
    // Bottom border
    char color_bottom[180] = {0};
    pos = 0;
    color_bottom[pos++] = box_chars[4]; // ╚
    for (int c = 0; c < 8; c++) {
        for (int i = 0; i < color_col_width - 1; i++) {
            color_bottom[pos++] = box_chars[1]; // ═
        }
        if (c < 7) {
            color_bottom[pos++] = box_chars[7]; // ╩
        }
    }
    color_bottom[pos++] = box_chars[5]; // ╝
    color_bottom[pos] = 0;
    print_to_screen_at(color_start_x - 1, row2_y + 2, color_bottom, 0x0F);

    print_to_screen_at(81, start_y-1, "  ASCII TABLE  ", 0x0F);

    print_to_screen_at(81, color_start_y-1, "  COLOR PALETTE  ", 0x0F);


    // === FOOTER ===
    print_to_screen_at(74, 49, "\xC9\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xBB", 0x0F); // ╔═══════════════════════╗
    print_to_screen_at(74, 50, "\xBA     simple fpga gpu       \xBA", 0x0f); // ║  simple fpga gpu     ║
    print_to_screen_at(74, 51, "\xBA       ~domin746826        \xBA", 0x0f); // ║    ~domin746826      ║
    print_to_screen_at(74, 52, "\xC8\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xBC", 0x0F); // ╚═══════════════════════╝
}

int main()
{
    stdio_init_all();

    gpio_init(PICO_DEFAULT_LED_PIN);
    gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);

    spi_init(SPI_PORT, 20000*1000);
    gpio_set_function(PIN_MISO, GPIO_FUNC_SPI);
    gpio_set_dir(PIN_CS, GPIO_OUT);
    gpio_set_function(PIN_SCK,  GPIO_FUNC_SPI);
    gpio_set_function(PIN_MOSI, GPIO_FUNC_SPI);
    
    // Enable pull-up on MISO in case FPGA is not driving
    gpio_pull_up(PIN_MISO);
    deselect_sfgpu();
    
    sleep_ms(5000); // wait for fpga and monitor

    select_sfgpu();
    init_gpu();
    wait_for_sync();
    reset_text_screen(0x91, ' ');


    char pattern_char[2] = " "; // background pattern
    for (int y = 0; y <= 56; y++) {
        for (int x = 0; x <= 179; x += 2) { 
            if ((x / 2 + y) % 2 == 0) {
                pattern_char[0] = '/'; 
            } else {
                pattern_char[0] = '\\';
            }
            print_to_screen_at(x, y, pattern_char, 0x91);
        }
    }

    ascii_demo();
    deselect_sfgpu();


    sleep_ms(20000);

    uint8_t i = 0;
    while (true) {

        select_sfgpu();
        wait_for_sync();
        reset_text_screen(i, i);
        deselect_sfgpu();

        i++;
        sleep_ms(800);

    }
}
