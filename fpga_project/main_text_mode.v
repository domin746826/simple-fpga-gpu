`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:    21:46:07 04/27/2024
// Design Name:
// Module Name:    main
// Project Name:
// Target Devices:
// Tool versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

/*
Modes:

0x00 Text mode 1440x900, font Terminus ter-216n 8x16
180 cols 56 rows

Format: character, color
color: low nibble - foreground, high nibble - background

0x0000-0x2759 - text (10080 bytes)
0x2760-0x4EBF - fg/bg colors (10080 bytes)
0x4EC0-0x5EBF - font (4096 bytes)
0x5EC0-0x5ECF - color palette (16 colors, 6 bit each, two oldest bits unused)
0x5ED0-0x5F00 - registers and reserved (48 bytes)
text 180x56
*/

module main (
    input clk10m,
    output wire vsync_pin,
    output wire hsync_pin,
    output reg r0_pin,
    output reg r1_pin,
    output reg g0_pin,
    output reg g1_pin,
    output reg b0_pin,
    output reg b1_pin,

    input uart_rx,
    output reg led1,
    output wire led2

);

wire clk106_int;
wire clk106m;
wire dcm_locked;

DCM_SP #(
    .CLKFX_MULTIPLY(32),      // mnożnik
    .CLKFX_DIVIDE(3),         // dzielnik
    .CLKIN_PERIOD(100.0),     // okres wejściowego clk10m = 100 ns
    .CLK_FEEDBACK("NONE"),
    .STARTUP_WAIT("FALSE")
) dcm_sp_inst (
    .CLKFX(clk106_int),   // wygenerowany zegar ~106.67 MHz
    .CLKIN(clk10m),       // wejście 10 MHz
    .RST(1'b0),
    .LOCKED(dcm_locked),
    .CLK0(), .CLK2X(), .CLK90(), .CLK180(), .CLK270(),
    .CLKDV(), .CLKFX180(), .STATUS(), .PSCLK(), .PSEN(), .PSINCDEC(), .PSDONE()
);

// Bufor globalny
BUFG bufg_clk106 (.I(clk106_int), .O(clk106m));


wire [10:0] h_counter; // 0-1055
wire [9:0] v_counter; // 0-627

reg [14:0] vram_index = 20159;
wire [7:0] rx_byte;
reg rx_we = 0;

wire [7:0] vram_render_read;
reg [14:0] current_vram_read_addr = 0;

vram_24k vram (
    .render_data(vram_render_read),
    .render_addr(current_vram_read_addr),
    .render_clk(clk106m),

    .user_data_in(rx_byte),
    .user_data_out(),
    .user_we(rx_we),
    .user_addr(vram_index),
    .user_clk(clk106m)
);


wire can_color;
vga_gen vga_timing (
    .clk(clk106m),
    .en(dcm_locked),
    .vsync(vsync_pin),
    .hsync(hsync_pin),
    .can_color(can_color),
    .h_counter(h_counter),
    .v_counter(v_counter)
);

assign led2 = 1;

reg [7:0] h_text_pos = 0; // current rendered char x pos
reg [5:0] v_text_pos = 0; // current rendered char y pos


reg [7:0] ascii_code = 0;  // current rendered char fetched ascii code
reg [7:0] color_code = 0; // 0bffffbbbb current rendered char fetched color code

reg [2:0] font_render_cycle = 0;// current rendered char h pixel (0-7)
reg [3:0] font_v_line = 0; // current rendered char line (0-15)

reg [5:0] pixel_out;// = 6'b0;
reg [7:0] font_onerow_data = 0;
reg [7:0] color_code_dbuf = 0;

always @(posedge clk106m) begin
    if((h_counter < 1440 || h_counter > 1895)&&v_counter < 896) begin
        case (font_render_cycle)
            0: begin
                current_vram_read_addr <= h_text_pos + v_text_pos * 180;
            end
            1: begin end
            2: begin
                ascii_code <= vram_render_read;
                current_vram_read_addr <= current_vram_read_addr + 10080;
            end
            3: begin end
            4: begin
                color_code_dbuf <= vram_render_read;
                current_vram_read_addr <= 20160 + ascii_code * 16 + font_v_line;
            end
            5: begin end
            6: begin end
            7: begin
                font_onerow_data <= vram_render_read;
                color_code <= color_code_dbuf;
                h_text_pos <= h_text_pos + 1;
            end
        endcase
        font_render_cycle <= font_render_cycle + 1;
    end else begin
        font_render_cycle <= 0;
        h_text_pos <= 0;
        font_onerow_data <= 0;
        color_code <= 0;
        h_text_pos <= 0;
    end
    if (h_counter < 1440  && v_counter < 896) begin
        if(font_onerow_data[~font_render_cycle]) begin
            pixel_out <= {color_code[6], color_code[7], color_code[5], color_code[7], color_code[4], color_code[7]};
        end else begin
            pixel_out <= {color_code[2], color_code[3], color_code[1], color_code[3], color_code[0], color_code[3]};
        end

        r0_pin <= pixel_out[4];
        r1_pin <= pixel_out[5];
        g0_pin <= pixel_out[2];
        g1_pin <= pixel_out[3];
        b0_pin <= pixel_out[0];
        b1_pin <= pixel_out[1];

    end else begin
        r0_pin <= 0;
        r1_pin <= 0;
        g0_pin <= 0;
        g1_pin <= 0;
        b0_pin <= 0;
        b1_pin <= 0;


    end

    if(h_counter == 1860) begin

        if(v_counter == 931) begin
            font_v_line <= 0;
            v_text_pos <= 0;
        end else begin
            if(font_v_line == 15) begin
                v_text_pos <= v_text_pos + 1;
            end
            font_v_line <= font_v_line + 1;
        end
    end
end


wire rx_data_valid;
reg dataack_read = 1'b0;

uart_rx uart_rx_inst (
    .clk(clk106m),
    .rst(0),
    .rx(uart_rx),
    .data_ack(dataack_read),
    .data(rx_byte),
    .data_ready(rx_data_valid),
    .error()
);

reg rx_data_valid_prev = 0;

always @(posedge clk106m) begin
    rx_data_valid_prev <= rx_data_valid;
    if (rx_data_valid && !rx_data_valid_prev) begin
        dataack_read <= 1;
        rx_we <= 1;
        if (vram_index == 20159)
            vram_index <= 0;
        else
            vram_index <= vram_index + 1;

        led1 <= ~led1;
    end else begin
        // dataack_read <= 0;
        rx_we <= 0;
    end
end

endmodule
